<#
    Gera os ícones do app e as imagens do instalador a partir de um PNG
    quadrado com fundo transparente (de preferência 512x512).

      powershell -ExecutionPolicy Bypass -File tool\make_icons.ps1 [-Source assets\branding\app_icon.png]

    Saídas:
      windows\runner\resources\app_icon.ico   (256, 128, 64, 48, 32, 24, 16 px)
      installer\wizard-small.bmp / -2x.bmp     (canto das telas do instalador)
      installer\wizard-large.bmp / -2x.bmp     (lateral das telas de boas-vindas e fim)
#>
param([string]$Source = 'assets\branding\app_icon.png')

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot
$src = [Drawing.Image]::FromFile((Resolve-Path (Join-Path $root $Source)))

function New-Canvas([int]$w, [int]$h, $background) {
    $bmp = New-Object Drawing.Bitmap $w, $h, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [Drawing.Drawing2D.CompositingQuality]::HighQuality
    if ($background) { $g.Clear($background) } else { $g.Clear([Drawing.Color]::Transparent) }
    return @{ Bitmap = $bmp; Graphics = $g }
}

function Get-PngBytes([int]$size) {
    $c = New-Canvas $size $size $null
    if ($size -le 24) {
        # Nos tamanhos pequenos o círculo tracejado vira um risco: usa só os
        # documentos do centro, ampliados (recorte proporcional ao PNG).
        $k = $src.Width / 512.0
        $crop = New-Object Drawing.Rectangle ([int](128 * $k)), ([int](75 * $k)), ([int](275 * $k)), ([int](341 * $k))
        $w = [int][Math]::Round($size * 275 / 341)
        $dest = New-Object Drawing.Rectangle ([int](($size - $w) / 2)), 0, $w, $size
        $c.Graphics.DrawImage($src, $dest, $crop, [Drawing.GraphicsUnit]::Pixel)
    } else {
        $c.Graphics.DrawImage($src, 0, 0, $size, $size)
    }
    $ms = New-Object IO.MemoryStream
    $c.Bitmap.Save($ms, [Drawing.Imaging.ImageFormat]::Png)
    $c.Graphics.Dispose(); $c.Bitmap.Dispose()
    return , $ms.ToArray()
}

# --- ICO com PNG embutido em cada tamanho ------------------------------------
$sizes = 256, 128, 64, 48, 32, 24, 16
$images = foreach ($s in $sizes) { , (Get-PngBytes $s) }
$icoPath = Join-Path $root 'windows\runner\resources\app_icon.ico'
$fs = [IO.File]::Create($icoPath)
try {
    $w = New-Object IO.BinaryWriter($fs)
    $w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$sizes.Count)
    $offset = 6 + 16 * $sizes.Count
    for ($i = 0; $i -lt $sizes.Count; $i++) {
        $dim = if ($sizes[$i] -ge 256) { 0 } else { $sizes[$i] }
        $w.Write([byte]$dim); $w.Write([byte]$dim); $w.Write([byte]0); $w.Write([byte]0)
        $w.Write([uint16]1); $w.Write([uint16]32)
        $w.Write([uint32]$images[$i].Length); $w.Write([uint32]$offset)
        $offset += $images[$i].Length
    }
    foreach ($img in $images) { $w.Write([byte[]]$img) }
    $w.Flush()
} finally { $fs.Dispose() }

# --- Imagens do instalador (BMP 24 bits, fundo branco) ----------------------
function Save-Bmp([int]$w, [int]$h, [int]$iconSize, [int]$iconTop, $background, [string]$name) {
    $c = New-Canvas $w $h $background
    $x = [int](($w - $iconSize) / 2)
    $y = if ($iconTop -ge 0) { $iconTop } else { [int](($h - $iconSize) / 2) }
    $c.Graphics.DrawImage($src, $x, $y, $iconSize, $iconSize)
    $rgb = $c.Bitmap.Clone((New-Object Drawing.Rectangle 0, 0, $w, $h), [Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $rgb.Save((Join-Path $root "installer\$name"), [Drawing.Imaging.ImageFormat]::Bmp)
    $rgb.Dispose(); $c.Graphics.Dispose(); $c.Bitmap.Dispose()
}

$white = [Drawing.Color]::White
$side = [Drawing.Color]::FromArgb(0xEE, 0xF3, 0xFB)
Save-Bmp 55 55 49 -1 $white 'wizard-small.bmp'
Save-Bmp 110 110 98 -1 $white 'wizard-small-2x.bmp'
Save-Bmp 164 314 120 70 $side 'wizard-large.bmp'
Save-Bmp 328 628 240 140 $side 'wizard-large-2x.bmp'

$src.Dispose()
Write-Host "Ícones gerados a partir de $Source"
