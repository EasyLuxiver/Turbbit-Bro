# Phase J 容差扫描：只跑每组设计答案方案，lead 从 400 扫到 40（三片并行）
# 用法：powershell -NoProfile -File docs\reports\logs\phase-j\run_tolerance.ps1
$root = 'D:\GAMESTUDIO\TURBBIT'
$godot = 'D:\Godot_v4.7-stable_win64_console.exe'
$logdir = Join-Path $root 'docs\reports\logs\phase-j'
New-Item -ItemType Directory -Force -Path $logdir | Out-Null
$shards = @(
    @('00', '18', 'a'),
    @('19', '36', 'b'),
    @('37', '54', 'c')
)
$procs = @()
foreach ($s in $shards) {
    $log = Join-Path $logdir ("tol-{0}.log" -f $s[2])
    $err = Join-Path $logdir ("tol-{0}.err.log" -f $s[2])
    $procs += Start-Process -FilePath $godot -PassThru -NoNewWindow -RedirectStandardOutput $log `
        -RedirectStandardError $err `
        -ArgumentList @('--headless', '--path', $root, 'res://scenes/stage4_solution_audit.tscn',
            '--', '--tolerance', '--from', $s[0], '--to', $s[1])
}
foreach ($p in $procs) { $p.WaitForExit() }
foreach ($s in $shards) {
    $log = Join-Path $logdir ("tol-{0}.log" -f $s[2])
    $done = Select-String -Path $log -Pattern 'SOLUTION AUDIT: DONE' -Quiet
    "shard {0}-{1}: done={2}" -f $s[0], $s[1], $done
}
