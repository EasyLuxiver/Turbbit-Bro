# Phase H 最终几何：整张解法矩阵 55 组重跑（四片并行）
# 用法：powershell -NoProfile -File docs\reports\logs\phase-h\run_matrix_final.ps1
$root = 'D:\GAMESTUDIO\TURBBIT'
$godot = 'D:\Godot_v4.7-stable_win64_console.exe'
$logdir = Join-Path $root 'docs\reports\logs\phase-h'
$shards = @(
    @('00', '13', 'a'),
    @('14', '27', 'b'),
    @('28', '40', 'c'),
    @('41', '54', 'd')
)
$procs = @()
foreach ($s in $shards) {
    $log = Join-Path $logdir ("matrix-final-{0}.log" -f $s[2])
    $err = Join-Path $logdir ("matrix-final-{0}.err.log" -f $s[2])
    $procs += Start-Process -FilePath $godot -PassThru -NoNewWindow -RedirectStandardOutput $log `
        -RedirectStandardError $err `
        -ArgumentList @('--headless', '--path', $root, 'res://scenes/stage4_solution_audit.tscn',
            '--', '--from', $s[0], '--to', $s[1])
}
foreach ($p in $procs) { $p.WaitForExit() }
foreach ($s in $shards) {
    $log = Join-Path $logdir ("matrix-final-{0}.log" -f $s[2])
    $done = Select-String -Path $log -Pattern 'SOLUTION AUDIT: DONE' -Quiet
    $nosol = (Select-String -Path $log -Pattern 'AUDIT no_solution=' | ForEach-Object { $_.Line }) -join ' | '
    "shard {0}-{1}: done={2} {3}" -f $s[0], $s[1], $done, $nosol
}
