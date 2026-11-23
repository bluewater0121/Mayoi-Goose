param([string]$Image, [int]$Y, [int]$X0 = 0, [int]$X1 = 0, [int]$Step = 1)
Add-Type -AssemblyName System.Drawing
$bmp = [System.Drawing.Bitmap]::FromFile($Image)
if ($X1 -le 0) { $X1 = $bmp.Width }
$last = ""; $start = $X0
for ($x = $X0; $x -lt $X1; $x += $Step) {
  $c = $bmp.GetPixel($x, $Y)
  $hex = "#{0:x2}{1:x2}{2:x2}" -f $c.R, $c.G, $c.B
  if ($hex -ne $last) {
    if ($last -ne "") { "{0,4}..{1,4} {2}" -f $start, ($x-$Step), $last }
    $last = $hex; $start = $x
  }
}
"{0,4}..{1,4} {2}" -f $start, ($X1-1), $last
$bmp.Dispose()
