param([string]$Image, [int]$X0, [int]$X1, [int]$Y0, [int]$Y1, [int]$Bg = -1, [int]$Tol = 6)
Add-Type -AssemblyName System.Drawing
$bmp = [System.Drawing.Bitmap]::FromFile($Image)
if ($Bg -lt 0) { $c = $bmp.GetPixel($X0, $Y0); $Bg = ($c.R -shl 16) -bor ($c.G -shl 8) -bor $c.B }
$rows = @()
for ($y = $Y0; $y -lt $Y1; $y++) {
  $n = 0
  for ($x = $X0; $x -lt $X1; $x++) {
    $c = $bmp.GetPixel($x, $y)
    $v = ($c.R -shl 16) -bor ($c.G -shl 8) -bor $c.B
    $dr = [math]::Abs((($v -shr 16) -band 255) - (($Bg -shr 16) -band 255))
    $dg = [math]::Abs((($v -shr 8) -band 255) - (($Bg -shr 8) -band 255))
    $db = [math]::Abs(($v -band 255) - ($Bg -band 255))
    if (($dr + $dg + $db) -gt $Tol) { $n++ }
  }
  $rows += ,@($y, $n)
}
$inBand = $false; $start = 0; $max = 0
foreach ($r in $rows) {
  if ($r[1] -gt 0 -and -not $inBand) { $inBand = $true; $start = $r[0]; $max = $r[1] }
  elseif ($r[1] -gt 0 -and $inBand) { if ($r[1] -gt $max) { $max = $r[1] } }
  elseif ($r[1] -eq 0 -and $inBand) { $inBand = $false; "band {0}..{1} h={2} max={3}" -f $start, ($r[0]-1), ($r[0]-$start), $max }
}
if ($inBand) { "band {0}..{1} h={2} max={3}" -f $start, ($Y1-1), ($Y1-$start), $max }
$bmp.Dispose()
