param([string]$OutDir)
# Рисует иконку «две карты веером на зелёном сукне».
# Всё задаётся в координатах 108×108 (сетка адаптивной иконки Android).
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'

function P([double]$x,[double]$y){ New-Object System.Drawing.PointF([single]$x,[single]$y) }

function RoundRect([double]$x,[double]$y,[double]$w,[double]$h,[double]$r){
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = 2*$r
  $p.AddArc([single]$x,[single]$y,[single]$d,[single]$d,180,90)
  $p.AddArc([single]($x+$w-$d),[single]$y,[single]$d,[single]$d,270,90)
  $p.AddArc([single]($x+$w-$d),[single]($y+$h-$d),[single]$d,[single]$d,0,90)
  $p.AddArc([single]$x,[single]($y+$h-$d),[single]$d,[single]$d,90,90)
  $p.CloseFigure(); $p
}

# Масть в рамке (x,y,w,h); контуры в единичном квадрате.
function SuitPath([string]$suit,[double]$x,[double]$y,[double]$w,[double]$h){
  $q = { param($u,$v) P ($x+$u*$w) ($y+$v*$h) }
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  if ($suit -eq 'heart') {
    $p.AddBezier((& $q .5 1), (& $q .16 .74), (& $q 0 .54), (& $q 0 .31))
    $p.AddBezier((& $q 0 .31), (& $q 0 .13), (& $q .12 0), (& $q .27 0))
    $p.AddBezier((& $q .27 0), (& $q .38 0), (& $q .46 .07), (& $q .5 .18))
    $p.AddBezier((& $q .5 .18), (& $q .54 .07), (& $q .62 0), (& $q .73 0))
    $p.AddBezier((& $q .73 0), (& $q .88 0), (& $q 1 .13), (& $q 1 .31))
    $p.AddBezier((& $q 1 .31), (& $q 1 .54), (& $q .84 .74), (& $q .5 1))
  } else {
    $p.AddBezier((& $q .5 0), (& $q .84 .28), (& $q 1 .44), (& $q 1 .62))
    $p.AddBezier((& $q 1 .62), (& $q 1 .77), (& $q .89 .86), (& $q .75 .86))
    $p.AddBezier((& $q .75 .86), (& $q .65 .86), (& $q .57 .81), (& $q .53 .73))
    $p.AddBezier((& $q .53 .73), (& $q .55 .87), (& $q .6 .95), (& $q .7 1))
    $p.AddLine((& $q .7 1), (& $q .3 1))
    $p.AddBezier((& $q .3 1), (& $q .4 .95), (& $q .45 .87), (& $q .47 .73))
    $p.AddBezier((& $q .47 .73), (& $q .43 .81), (& $q .35 .86), (& $q .25 .86))
    $p.AddBezier((& $q .25 .86), (& $q .11 .86), (& $q 0 .77), (& $q 0 .62))
    $p.AddBezier((& $q 0 .62), (& $q 0 .44), (& $q .16 .28), (& $q .5 0))
  }
  $p.CloseFigure(); $p
}

# Карта 30×42 с центром в (0,0) текущих координат.
function DrawCard($g,[string]$suit){
  $w=30; $h=42; $x=-$w/2; $y=-$h/2
  $shadow = RoundRect ($x+0.8) ($y+1.6) $w $h 3.6
  $g.FillPath((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(70,0,0,0))), $shadow)
  $card = RoundRect $x $y $w $h 3.6
  $g.FillPath([System.Drawing.Brushes]::White, $card)
  $g.DrawPath((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(40,0,0,0), 0.5)), $card)
  $col = if ($suit -eq 'heart') { [System.Drawing.Color]::FromArgb(198,40,40) } else { [System.Drawing.Color]::FromArgb(17,17,17) }
  $br = New-Object System.Drawing.SolidBrush($col)
  # «A» в углу и маленькая масть под ней
  $font = New-Object System.Drawing.Font('Arial', [single]7.5, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
  $g.DrawString('A', $font, $br, (P ($x+1.6) ($y+1.2)))
  $g.FillPath($br, (SuitPath $suit ($x+2.6) ($y+9.6) 4.2 5))
  # большая масть по центру
  $g.FillPath($br, (SuitPath $suit -8.2 -9.5 16.4 19))
}

# Две карты веером; область 108×108 переносится в рамку (ox,oy,size).
function DrawCards($g,[double]$ox,[double]$oy,[double]$size){
  $s = $size/108
  $st = $g.Save()
  $g.TranslateTransform([single]$ox,[single]$oy)
  $g.ScaleTransform([single]$s,[single]$s)
  $c1 = $g.Save(); $g.TranslateTransform(42,56); $g.RotateTransform(-15); $g.ScaleTransform(0.88,0.88); DrawCard $g 'spade'; $g.Restore($c1)
  $c2 = $g.Save(); $g.TranslateTransform(65,54); $g.RotateTransform(12);  $g.ScaleTransform(0.88,0.88); DrawCard $g 'heart'; $g.Restore($c2)
  $g.Restore($st)
}

function NewCanvas([int]$px){
  $bmp = New-Object System.Drawing.Bitmap($px,$px,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
  $g.InterpolationMode = 'HighQualityBicubic'; $g.PixelOffsetMode = 'HighQuality'
  $g.Clear([System.Drawing.Color]::Transparent)
  @($bmp,$g)
}

function Felt($g,[int]$px,[double]$radius){
  $rect = New-Object System.Drawing.RectangleF(0,0,$px,$px)
  $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect,
    [System.Drawing.Color]::FromArgb(36,124,68), [System.Drawing.Color]::FromArgb(26,94,52), [single]90)
  if ($radius -gt 0) { $g.FillPath($br, (RoundRect 0 0 $px $px $radius)) } else { $g.FillRectangle($br, $rect) }
}

function SavePng($bmp,$g,[string]$path){
  New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
}

$dens = [ordered]@{ mdpi=1; hdpi=1.5; xhdpi=2; xxhdpi=3; xxxhdpi=4 }
foreach ($d in $dens.Keys) {
  $k = $dens[$d]
  # Адаптивная иконка (Android 8+): передний план 108dp, фон — цвет.
  $fg = [int](108*$k); $bmp,$g = NewCanvas $fg
  DrawCards $g 0 0 $fg
  SavePng $bmp $g "$OutDir\res\mipmap-$d\ic_launcher_foreground.png"
  # Старая иконка 48dp: сукно со скруглением, карты крупнее.
  $lg = [int](48*$k); $bmp,$g = NewCanvas $lg
  Felt $g $lg ($lg*0.18)
  DrawCards $g (-$lg*0.30) (-$lg*0.30) ($lg*1.6)
  SavePng $bmp $g "$OutDir\res\mipmap-$d\ic_launcher.png"
}
# Иконка для магазина 512×512 (квадрат, маску накладывает Google Play).
$bmp,$g = NewCanvas 512
Felt $g 512 0
DrawCards $g (-512*0.30) (-512*0.30) (512*1.6)
SavePng $bmp $g "$OutDir\store\icon_512.png"
