Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public class Win2 { [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
public static void Tap(byte vk){ keybd_event(vk,0,0,UIntPtr.Zero); System.Threading.Thread.Sleep(90); keybd_event(vk,0,2,UIntPtr.Zero);} }
'@
$game = Get-Process | Where-Object { $_.MainWindowTitle -like "*Turbbit Bro!*" } | Select-Object -First 1
if (-not $game) { Write-Output "NO_GAME"; exit 2 }
$h=$game.MainWindowHandle; [void][Win2]::SetForegroundWindow($h); Start-Sleep -Milliseconds 400
function T([byte]$vk){ if([Win2]::GetForegroundWindow() -ne $h){Write-Output "FOCUS_LOST";exit 3}; [Win2]::Tap($vk); Start-Sleep -Milliseconds 220 }
function Shot($n){$b=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds;$bmp=New-Object System.Drawing.Bitmap $b.Width,$b.Height;$g=[System.Drawing.Graphics]::FromImage($bmp);$g.CopyFromScreen($b.Location,[System.Drawing.Point]::Empty,$b.Size);$bmp.Save((Join-Path "D:\GAMESTUDIO\TURBBIT\screenshots" $n));Write-Output ("SHOT "+$n)}
Shot "win-06-race.png"
T 0x10
T 0x28
T 0x26
T 0x10
Shot "win-07-controls.png"
T 0x1B
Shot "win-08-pause.png"
T 0x1B
T 0x52
Start-Sleep -Milliseconds 700
Shot "win-09-retry.png"
Write-Output "DONE"
