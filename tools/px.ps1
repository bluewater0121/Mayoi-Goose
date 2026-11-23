param([string]$Image, [string]$Points)
Add-Type -AssemblyName System.Drawing
$bmp = [System.Drawing.Bitmap]::FromFile($Image)
foreach ($p in $Points.Split(';')) {
  if ($p.Trim() -eq '') { continue }
  $xy = $p.Split(',')
  $x = [int]$xy[0]; $y = [int]$xy[1]
  $c = $bmp.GetPixel($x, $y)
  "{0},{1} = #{2:x2}{3:x2}{4:x2}" -f $x, $y, $c.R, $c.G, $c.B
}
$bmp.Dispose()
