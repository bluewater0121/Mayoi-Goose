param([string]$Image, [int]$X, [int]$Y0 = 0, [int]$Y1 = 0)
Add-Type -AssemblyName System.Drawing
$bmp = [System.Drawing.Bitmap]::FromFile($Image)
if ($Y1 -le 0) { $Y1 = $bmp.Height }
$last = ""; $start = $Y0
for ($y = $Y0; $y -lt $Y1; $y++) {
  $c = $bmp.GetPixel($X, $y)
  $hex = "#{0:x2}{1:x2}{2:x2}" -f $c.R, $c.G, $c.B
  if ($hex -ne $last) {
    if ($last -ne "") { "{0,4}..{1,4} {2}" -f $start, ($y-1), $last }
    $last = $hex; $start = $y
  }
}
"{0,4}..{1,4} {2}" -f $start, ($Y1-1), $last
$bmp.Dispose()
