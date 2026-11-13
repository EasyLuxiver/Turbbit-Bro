# TBB-LONGRUN-PLAYABILITY-01 reminder.
# Does NOT start an agent, a Godot process, or a second task instance.
# It reads LONGRUN_STATE.md, checks the lock, writes a log line, shows a popup,
# and opens RESUME_PROMPT.md so a human / new session can resume.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\longrun_reminder.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File tools\longrun_reminder.ps1 -Test -NoOpen
#
# Exit codes: 0 = reminder shown, 2 = state file missing, 3 = unexpected error.

param(
    [switch]$Test,
    [switch]$NoOpen,
    [int]$PopupSeconds = 60
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$taskDir = Join-Path $root 'docs\reports\longrun'
$statePath = Join-Path $taskDir 'LONGRUN_STATE.md'
$resumePath = Join-Path $taskDir 'RESUME_PROMPT.md'
$logPath = Join-Path $taskDir 'reminder.log'
$lockPath = Join-Path $taskDir '.lock'

function Write-ReminderLog([string]$Message) {
    $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
}

try {
    if (-not (Test-Path -LiteralPath $taskDir)) {
        New-Item -ItemType Directory -Path $taskDir -Force | Out-Null
    }

    # ---- Lock: a live PID means another run owns the project. ----
    $lockText = 'none'
    if (Test-Path -LiteralPath $lockPath) {
        $raw = (Get-Content -LiteralPath $lockPath -Raw).Trim()
        $parts = $raw -split '\s+'
        if ($parts.Count -ge 1 -and $parts[0] -match '^\d+$') {
            $lockPid = [int]$parts[0]
            $proc = Get-Process -Id $lockPid -ErrorAction SilentlyContinue
            if ($null -ne $proc) {
                $lockText = "RUNNING pid=$lockPid"
            } else {
                $lockText = "STALE pid=$lockPid (process gone)"
            }
        } else {
            $lockText = 'UNREADABLE'
        }
    }

    # ---- State / heartbeat. ----
    if (-not (Test-Path -LiteralPath $statePath)) {
        Write-ReminderLog 'state file missing'
        $stateText = 'STATE FILE MISSING'
        $stateStatus = 'MISSING'
        $lastUpdated = 'unknown'
        $nextTask = 'unknown'
    } else {
        $stateText = Get-Content -LiteralPath $statePath -Raw
        $stateStatus = if ($stateText -match '(?m)^STATUS:\s*(\S+)') { $matches[1] } else { 'UNKNOWN' }
        $lastUpdated = if ($stateText -match '(?m)^LAST_UPDATED:\s*(.+)$') { $matches[1].Trim() } else { 'unknown' }
        $nextTask = if ($stateText -match '(?m)^NEXT:\s*(.+)$') { $matches[1].Trim() } else { 'missing NEXT line' }
    }

    $heartbeat = 'unparseable'
    if ($lastUpdated -ne 'unknown') {
        try {
            $t = [datetime]::ParseExact($lastUpdated, 'yyyy-MM-dd HH:mm', $null)
            $ageMin = [math]::Round(((Get-Date) - $t).TotalMinutes, 0)
            $heartbeat = "$lastUpdated ($ageMin min ago)"
        } catch {
            $heartbeat = "$lastUpdated (unparseable)"
        }
    }

    # ---- Message. ----
    if ($stateStatus -eq 'COMPLETE') {
        $head = 'Task is COMPLETE - do not restart it.'
        $action = 'No resume needed.'
    } elseif ($lockText -like 'RUNNING*') {
        $head = 'Task may already be RUNNING.'
        $action = 'Do NOT start a second instance. Check the lock/process first.'
    } elseif ($lockText -like 'STALE*' -or $lockText -eq 'UNREADABLE') {
        $head = 'Lock is stale; no live worker detected.'
        $action = 'Remove the stale lock, then resume from RESUME_PROMPT.md.'
    } else {
        $head = 'No live worker; task is stopped or not started.'
        $action = 'Open RESUME_PROMPT.md and continue from NEXT.'
    }

    $shortNext = $nextTask
    if ($shortNext.Length -gt 220) { $shortNext = $shortNext.Substring(0, 220) + '...' }

    $body = @"
TBB-LONGRUN-PLAYABILITY-01 reminder

$head
$action

STATUS      : $stateStatus
LAST_UPDATE : $heartbeat
LOCK        : $lockText

NEXT:
$shortNext

State  : $statePath
Resume : $resumePath
Log    : $logPath

This reminder does not start any process.
"@

    Write-ReminderLog ("TEST={0} status={1} lock={2} head={3}" -f $Test, $stateStatus, $lockText, $head)

    if (-not $NoOpen -and (Test-Path -LiteralPath $resumePath)) {
        Start-Process -FilePath $resumePath
    }

    $wsh = New-Object -ComObject WScript.Shell
    [void]$wsh.Popup($body, $PopupSeconds, 'Turbbit longrun reminder', 64)
    Write-ReminderLog 'popup dismissed'
    exit 0
} catch {
    try { Write-ReminderLog ("ERROR " + $_.Exception.Message) } catch { }
    exit 3
}
