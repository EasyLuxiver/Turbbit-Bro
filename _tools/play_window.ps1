param([string]$ShotDir = "D:\GAMESTUDIO\TURBBIT\screenshots")
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class Win {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  public static void Tap(byte vk) { keybd_event(vk,0,0,UIntPtr.Zero); System.Threading.Thread.Sleep(70); keybd_event(vk,0,2,UIntPtr.Zero); }
}
'@
$game = Get-Process | Where-Object { $_.MainWindowTitle -eq "Turbbit Bro! (DEBUG)" } | Select-Object -First 1
if (-not $game) {
  $p = Start-Process -FilePath "D:\Godot_v4.7-stable_win64_console.exe" -ArgumentList "--path","D:\GAMESTUDIO\TURBBIT","--resolution","1280x720" -PassThru
  Start-Sleep -Seconds 5
  $game = Get-Process | Where-Object { $_.MainWindowTitle -eq "Turbbit Bro! (DEBUG)" } | Select-Object -First 1
}
if (-not $game) { Write-Output "NO_GAME_WINDOW"; exit 2 }
$hwnd = $game.MainWindowHandle
[void][Win]::SetForegroundWindow($hwnd)
Start-Sleep -Milliseconds 500
$fg = [Win]::GetForegroundWindow()
Write-Output ("game_pid={0} hwnd={1} fg={2} focused={3}" -f $game.Id,$hwnd,$fg,($fg -eq $hwnd))
if ($fg -ne $hwnd) { Write-Output "FOCUS_FAILED"; exit 3 }
function Shot($name) {
  $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
  $bmp = New-Object System.Drawing.Bitmap $b.Width,$b.Height
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($b.Location,[System.Drawing.Point]::Empty,$b.Size)
  $p = Join-Path $ShotDir $name
  $bmp.Save($p)
  Write-Output ("SHOT " + $p)
}
function Tap([byte]$vk) {
  $fg = [Win]::GetForegroundWindow()
  if ($fg -ne $hwnd) { Write-Output "FOCUS_LOST_BEFORE_SEND"; exit 4 }
  [Win]::Tap($vk)
  Start-Sleep -Milliseconds 180
}
Shot "win-01-menu.png"
Tap 0x0D
Start-Sleep -Milliseconds 800
Shot "win-02-start.png"
for ($i=0; $i -lt 6; $i++) { Tap 0x1B; Start-Sleep -Milliseconds 200 }
Shot "win-03-comic.png"
Tap 0x4B
Start-Sleep -Milliseconds 1200
Shot "win-04-tutorial.png"
Tap 0x4B
Start-Sleep -Milliseconds 2200
Shot "win-05-after-k.png"
Write-Output "DONE"
