param(
  [Parameter(Mandatory=$true)][string]$ProcessName,
  [Parameter(Mandatory=$true)][string]$Out,
  [string]$Title = "",
  [int]$TimeoutSec = 20,
  [string]$Size = ""
)
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class DpiAware {
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr v);
  public static void Make() {
    try { SetProcessDpiAwarenessContext(new IntPtr(-4)); } catch {}
  }
}
"@
[DpiAware]::Make()
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class Shot {
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd, IntPtr hdc, uint flags);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out RECT r);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr hwnd, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr hwnd, ref POINT p);
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hwnd);
  [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr hwnd);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hwnd, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr p);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
  public delegate bool EnumProc(IntPtr hwnd, IntPtr p);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  public static IntPtr FindWindow(uint pid, string title) {
    IntPtr found = IntPtr.Zero;
    EnumWindows((h, p) => {
      uint wp; GetWindowThreadProcessId(h, out wp);
      if (wp == pid && IsWindowVisible(h)) {
        var sb = new StringBuilder(512); GetWindowText(h, sb, 512);
        if (title == "" || sb.ToString().Contains(title)) { found = h; return false; }
      }
      return true;
    }, IntPtr.Zero);
    return found;
  }
}
"@
$deadline = (Get-Date).AddSeconds($TimeoutSec)
$hwnd = [IntPtr]::Zero
while ((Get-Date) -lt $deadline) {
  $p = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
  if ($p) {
    $hwnd = if ($Title -ne "") { [Shot]::FindWindow([uint32]$p.Id, $Title) } else { $p.MainWindowHandle }
    if ($hwnd -ne [IntPtr]::Zero) { break }
  }
  Start-Sleep -Milliseconds 300
}
if ($hwnd -eq [IntPtr]::Zero) { Write-Error "no window for $ProcessName"; exit 1 }
$r = New-Object Shot+RECT
[Shot]::GetWindowRect($hwnd, [ref]$r) | Out-Null
$w = $r.Right - $r.Left; $h = $r.Bottom - $r.Top
if ($w -le 0 -or $h -le 0) { Write-Error "bad rect"; exit 1 }
$bmp = New-Object System.Drawing.Bitmap($w, $h)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc()
$ok = [Shot]::PrintWindow($hwnd, $hdc, 2)
$g.ReleaseHdc($hdc)
$g.Dispose()
if (-not $ok) { $bmp.Dispose(); Write-Error "PrintWindow failed"; exit 1 }
# crop to the client area so frameless chrome lines up 1:1
$cr = New-Object Shot+RECT
[Shot]::GetClientRect($hwnd, [ref]$cr) | Out-Null
if ($Size -ne "") {
  $sw = [int]($Size.Split("x")[0]); $sh = [int]($Size.Split("x")[1])
  $c = New-Object System.Drawing.Bitmap($sw, $sh)
  $cg = [System.Drawing.Graphics]::FromImage($c)
  $cg.DrawImage($bmp, (New-Object System.Drawing.Rectangle(0,0,$sw,$sh)), (New-Object System.Drawing.Rectangle(0,0,$sw,$sh)), [System.Drawing.GraphicsUnit]::Pixel)
  $cg.Dispose(); $bmp.Dispose()
  $c.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
  $w = $sw; $h = $sh
  $c.Dispose()
} elseif ($cr.Right -gt 0 -and $cr.Bottom -gt 0 -and ($cr.Right -lt $w -or $cr.Bottom -lt $h)) {
  $pt = New-Object Shot+POINT
  [Shot]::ClientToScreen($hwnd, [ref]$pt) | Out-Null
  $ox = $pt.X - $r.Left; $oy = $pt.Y - $r.Top
  $c = New-Object System.Drawing.Bitmap($cr.Right, $cr.Bottom)
  $cg = [System.Drawing.Graphics]::FromImage($c)
  $cg.DrawImage($bmp, (New-Object System.Drawing.Rectangle(0,0,$cr.Right,$cr.Bottom)), (New-Object System.Drawing.Rectangle($ox,$oy,$cr.Right,$cr.Bottom)), [System.Drawing.GraphicsUnit]::Pixel)
  $cg.Dispose()
  $bmp.Dispose()
  $c.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
  $w = $cr.Right; $h = $cr.Bottom
  $c.Dispose()
} else {
  $bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
}
Write-Output "$Out ${w}x${h}"


