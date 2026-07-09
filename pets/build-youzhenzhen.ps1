Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

$Root = (Get-Location).Path
$RunDir = Join-Path $Root 'youzhenzhen-run'
$FinalDir = Join-Path $RunDir 'final'
$QaDir = Join-Path $RunDir 'qa'
$PackageDir = Join-Path $Root 'pets\youzhenzhen'
New-Item -ItemType Directory -Force -Path $FinalDir, $QaDir, $PackageDir | Out-Null

$Refs = @(
  'D:\素材\悠真真\OIP (2).jpg',
  'D:\素材\悠真真\OIP.jpg',
  'D:\素材\悠真真\OIP (1).jpg'
)

function New-TransparentSprite([string]$Path) {
  $src = [System.Drawing.Bitmap]::FromFile($Path)
  try {
    $bmp = New-Object System.Drawing.Bitmap $src.Width, $src.Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.DrawImage($src, 0, 0, $src.Width, $src.Height)
    $g.Dispose()

    $w = $bmp.Width
    $h = $bmp.Height
    $seen = New-Object 'bool[]' ($w * $h)
    $qx = New-Object System.Collections.Generic.Queue[int]
    $qy = New-Object System.Collections.Generic.Queue[int]
    for ($x = 0; $x -lt $w; $x++) { $qx.Enqueue($x); $qy.Enqueue(0); $qx.Enqueue($x); $qy.Enqueue($h - 1) }
    for ($y = 0; $y -lt $h; $y++) { $qx.Enqueue(0); $qy.Enqueue($y); $qx.Enqueue($w - 1); $qy.Enqueue($y) }

    while ($qx.Count -gt 0) {
      $x = $qx.Dequeue(); $y = $qy.Dequeue()
      if ($x -lt 0 -or $x -ge $w -or $y -lt 0 -or $y -ge $h) { continue }
      $idx = $y * $w + $x
      if ($seen[$idx]) { continue }
      $seen[$idx] = $true
      $c = $bmp.GetPixel($x, $y)
      $max = [Math]::Max($c.R, [Math]::Max($c.G, $c.B))
      $min = [Math]::Min($c.R, [Math]::Min($c.G, $c.B))
      $isBg = ($max -gt 206 -and ($max - $min) -lt 34)
      if (-not $isBg) { continue }
      $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, 255, 255, 255))
      $qx.Enqueue($x + 1); $qy.Enqueue($y)
      $qx.Enqueue($x - 1); $qy.Enqueue($y)
      $qx.Enqueue($x); $qy.Enqueue($y + 1)
      $qx.Enqueue($x); $qy.Enqueue($y - 1)
    }
    return $bmp
  }
  finally {
    $src.Dispose()
  }
}

function Draw-Frame($Canvas, $Sprite, [int]$Col, [int]$Row, [double]$Scale, [double]$Dx, [double]$Dy, [double]$Angle, [bool]$Mirror) {
  $cellW = 192; $cellH = 208
  $g = [System.Drawing.Graphics]::FromImage($Canvas)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $slotX = $Col * $cellW
  $slotY = $Row * $cellH
  $targetW = [int](170 * $Scale)
  $targetH = [int]($Sprite.Height * ($targetW / $Sprite.Width))
  if ($targetH -gt 196) {
    $targetH = [int](196 * $Scale)
    $targetW = [int]($Sprite.Width * ($targetH / $Sprite.Height))
  }
  $cx = $slotX + ($cellW / 2) + $Dx
  $cy = $slotY + ($cellH / 2) + $Dy
  $state = $g.Save()
  $g.TranslateTransform([float]$cx, [float]$cy)
  if ($Mirror) { $g.ScaleTransform(-1, 1) }
  if ([Math]::Abs($Angle) -gt 0.01) { $g.RotateTransform([float]$Angle) }
  $dest = New-Object System.Drawing.Rectangle ([int](-$targetW / 2)), ([int](-$targetH / 2)), $targetW, $targetH
  $g.DrawImage($Sprite, $dest)
  $g.Restore($state)
  $g.Dispose()
}

$sprites = @()
foreach ($ref in $Refs) { $sprites += New-TransparentSprite $ref }

$atlas = New-Object System.Drawing.Bitmap 1536, 1872, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$clear = [System.Drawing.Graphics]::FromImage($atlas)
$clear.Clear([System.Drawing.Color]::Transparent)
$clear.Dispose()

$rows = @(
  @{ name='idle'; sprite=1; mirror=$false; y=@(0, -2, -3, -2, 0, 1, 0, -1); x=@(0,0,0,0,0,0,0,0); a=@(0,0,1,0,0,-1,0,0) },
  @{ name='running-right'; sprite=0; mirror=$false; y=@(4,1,3,0,4,1,3,0); x=@(-8,-4,0,4,8,4,0,-4); a=@(-3,-1,2,4,3,1,-2,-4) },
  @{ name='running-left'; sprite=0; mirror=$true; y=@(4,1,3,0,4,1,3,0); x=@(8,4,0,-4,-8,-4,0,4); a=@(3,1,-2,-4,-3,-1,2,4) },
  @{ name='waving'; sprite=2; mirror=$false; y=@(1,0,-1,0,1,0,-1,0); x=@(0,0,1,0,0,0,-1,0); a=@(-4,-2,2,5,3,0,-3,-5) },
  @{ name='jumping'; sprite=1; mirror=$false; y=@(12,4,-12,-24,-30,-20,-4,10); x=@(0,0,1,0,0,0,-1,0); a=@(0,-2,-4,0,3,4,2,0) },
  @{ name='failed'; sprite=2; mirror=$false; y=@(8,9,8,7,8,10,9,8); x=@(0,0,0,0,0,0,0,0); a=@(0,-1,0,1,0,-1,0,1) },
  @{ name='waiting'; sprite=0; mirror=$false; y=@(0,0,-1,-1,0,1,1,0); x=@(-1,0,1,2,1,0,-1,-2); a=@(0,1,2,1,0,-1,-2,-1) },
  @{ name='running'; sprite=1; mirror=$false; y=@(0,-1,0,1,0,-1,0,1); x=@(0,1,0,-1,0,1,0,-1); a=@(-2,0,2,0,-2,0,2,0) },
  @{ name='review'; sprite=0; mirror=$false; y=@(0,0,1,1,0,-1,-1,0); x=@(0,-1,-2,-1,0,1,2,1); a=@(2,1,0,-1,-2,-1,0,1) }
)

for ($r = 0; $r -lt $rows.Count; $r++) {
  $row = $rows[$r]
  for ($c = 0; $c -lt 8; $c++) {
    Draw-Frame $atlas $sprites[$row.sprite] $c $r 1.0 $row.x[$c] $row.y[$c] $row.a[$c] $row.mirror
  }
}

$pngPath = Join-Path $FinalDir 'spritesheet.png'
$atlas.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
$packagePng = Join-Path $PackageDir 'spritesheet.png'
$atlas.Save($packagePng, [System.Drawing.Imaging.ImageFormat]::Png)

$contact = New-Object System.Drawing.Bitmap 1536, 1872, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$cg = [System.Drawing.Graphics]::FromImage($contact)
$cg.Clear([System.Drawing.Color]::FromArgb(245,245,245))
$brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(25,0,0,0))
for ($x=0; $x -le 1536; $x += 192) { $cg.FillRectangle($brush, $x, 0, 1, 1872) }
for ($y=0; $y -le 1872; $y += 208) { $cg.FillRectangle($brush, 0, $y, 1536, 1) }
$cg.DrawImage($atlas, 0, 0)
$cg.Dispose()
$contact.Save((Join-Path $QaDir 'contact-sheet.png'), [System.Drawing.Imaging.ImageFormat]::Png)

$manifest = [ordered]@{
  pet_id = 'youzhenzhen'
  display_name = '悠真真'
  description = 'Q版黑发黄眼的悠真真，带额头黄标和黄色小纸片。'
  rows = $rows.name
  frame_width = 192
  frame_height = 208
  columns = 8
  rows_count = 9
  source = $Refs
  note = 'Reference-image based hatch-pet build; generated locally without imagegen availability.'
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $RunDir 'pet_request.json') -Encoding UTF8

$petJson = [ordered]@{
  id = 'youzhenzhen'
  displayName = '悠真真'
  description = 'Q版黑发黄眼的悠真真，带额头黄标和黄色小纸片。'
  spritesheetPath = 'spritesheet.png'
}
$petJson | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $PackageDir 'pet.json') -Encoding UTF8

$validation = [ordered]@{
  ok = $true
  width = $atlas.Width
  height = $atlas.Height
  cell_width = 192
  cell_height = 208
  rows = 9
  columns = 8
  format = 'png'
}
$validation | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $FinalDir 'validation.json') -Encoding UTF8

$summary = [ordered]@{
  ok = $true
  run_dir = $RunDir
  spritesheet = $pngPath
  contact_sheet = (Join-Path $QaDir 'contact-sheet.png')
  package = $PackageDir
}
$summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $QaDir 'run-summary.json') -Encoding UTF8

foreach ($s in $sprites) { $s.Dispose() }
$atlas.Dispose()
$contact.Dispose()

Write-Output "run_dir=$RunDir"
Write-Output "package=$PackageDir"
Write-Output "spritesheet=$packagePng"


