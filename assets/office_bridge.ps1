#Requires -Version 5.1
<#
    Ponte do Conversor de Arquivos para o que só existe via COM/WIC no Windows:
    Word, Excel, PowerPoint, Acrobat, leitura de HEIC/HEIF e o atalho
    "Enviar para".

    Fica em execução durante um lote e conversa por uma caixa de mensagens em
    arquivos (o stdin do PowerShell 5.1 perde linhas quando o processo é
    iniciado pelo Dart):
      pedido   : <Mailbox>\req_N.json   { action, in, out, fmt, ... }
      resposta : <Mailbox>\resp_N.json  { ok, data | error, code }
    Os dois lados gravam como .tmp e renomeiam, então nunca leem pela metade.
    A ação "close" fecha os aplicativos e encerra; a ponte também encerra
    sozinha se o processo ParentPid (o app) deixar de existir.

    Não acessa a rede e não lê nada além dos arquivos indicados em cada pedido.
#>
param(
    [Parameter(Mandatory = $true)][string]$Mailbox,
    [int]$ParentPid = 0
)

$ErrorActionPreference = 'Stop'
$AcrobatBrokenCode = 'ACROBAT_BROKEN'
$script:ErrorCode = $null

# Rastreamento opcional para depuração: defina CONVERSOR_BRIDGE_LOG com o
# caminho de um arquivo de texto.
function Write-Trace([string]$text) {
    if ($env:CONVERSOR_BRIDGE_LOG) {
        try { Add-Content -LiteralPath $env:CONVERSOR_BRIDGE_LOG -Value ((Get-Date -Format 'HH:mm:ss.fff') + '  ' + $text) } catch { }
    }
}

function Release-Com($obj) {
    if ($obj) { try { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($obj) } catch { } }
}

function Get-ErrorMessage($err) {
    $e = $err.Exception
    while ($e.InnerException) { $e = $e.InnerException }
    return $e.Message
}

# ---------------------------------------------------------------------------
# Acrobat (Pro/Standard): PDF -> DOCX, XLSX, PPTX
# ---------------------------------------------------------------------------
function ConvertTo-AcrobatPath([string]$p) {
    # O JavaScript do Acrobat usa caminhos no formato /C/pasta/arquivo.docx
    if ($p.StartsWith('\\')) { return '/' + $p.Substring(2).Replace('\', '/') }
    return '/' + $p.Replace(':', '').Replace('\', '/')
}

function Stop-AcrobatBroken {
    $script:AcrobatBroken = $true
    $script:ErrorCode = $AcrobatBrokenCode
    throw 'O Acrobat instalado não permite automação (normalmente é o Acrobat Reader gratuito ou um Acrobat sem licença Pro/Standard ativa).'
}

function Convert-WithAcrobat([string]$in, [string]$out, [string]$fmt) {
    $ids = @{
        docx = 'com.adobe.acrobat.docx'
        xlsx = 'com.adobe.acrobat.xlsx'
        pptx = 'com.adobe.acrobat.pptx'
    }
    if (-not $ids.ContainsKey($fmt)) { throw "O Acrobat não exporta para $fmt." }
    if ($script:AcrobatBroken) { Stop-AcrobatBroken }
    try {
        if (-not $script:AcroApp) {
            $script:AcroApp = New-Object -ComObject AcroExch.App
            try { [void]$script:AcroApp.Hide() } catch { }
        }
        $pd = New-Object -ComObject AcroExch.PDDoc
    } catch {
        Stop-AcrobatBroken
    }
    $js = $null
    try {
        if (-not $pd.Open($in)) { throw 'O Acrobat não conseguiu abrir o PDF (protegido por senha ou corrompido).' }
        $js = $pd.GetJSObject()
        if (-not $js) { Stop-AcrobatBroken }
        [void][System.__ComObject].InvokeMember('saveAs', [Reflection.BindingFlags]::InvokeMethod, $null, $js,
            @((ConvertTo-AcrobatPath $out), $ids[$fmt]))
    } finally {
        try { [void]$pd.Close() } catch { }
        Release-Com $js
        Release-Com $pd
    }
}

# ---------------------------------------------------------------------------
# Word
# ---------------------------------------------------------------------------
function Get-Word {
    if (-not $script:Word) {
        $script:Word = New-Object -ComObject Word.Application
        $script:Word.Visible = $false
        $script:Word.DisplayAlerts = 0                          # wdAlertsNone
        try { $script:Word.AutomationSecurity = 3 } catch { }   # macros desativadas
        try { $script:Word.Options.ConfirmConversions = $false } catch { }
    }
    return $script:Word
}

function Convert-WithWord([string]$in, [string]$out, [string]$fmt) {
    $formats = @{ docx = 16; doc = 0; odt = 23; rtf = 6 }
    $word = Get-Word
    $doc = $word.Documents.Open($in, $false, $true, $false)   # ConfirmConversions, ReadOnly, AddToRecentFiles
    try {
        switch ($fmt) {
            'pdf' {
                # Fidelidade máxima, com marcadores a partir dos títulos
                $doc.ExportAsFixedFormat($out, 17, $false, 0, 0, 1, 1, 0, $true, $true, 1, $true, $true, $false)
            }
            'txt' {
                $m = [Type]::Missing
                $doc.SaveAs2($out, 2, $m, $m, $false, $m, $m, $m, $m, $m, $m, 65001)   # texto UTF-8
            }
            default {
                if (-not $formats.ContainsKey($fmt)) { throw "O Word não exporta para $fmt." }
                $doc.SaveAs2($out, $formats[$fmt])
            }
        }
    } finally {
        try { $doc.Close(0) } catch { }
        Release-Com $doc
    }
}

# ---------------------------------------------------------------------------
# Excel
# ---------------------------------------------------------------------------
function Get-Excel {
    if (-not $script:Excel) {
        $script:Excel = New-Object -ComObject Excel.Application
        $script:Excel.Visible = $false
        $script:Excel.DisplayAlerts = $false
        $script:Excel.ScreenUpdating = $false
        try { $script:Excel.AutomationSecurity = 3 } catch { }
    }
    return $script:Excel
}

function Convert-WithExcel([string]$in, [string]$out, [string]$fmt) {
    $xl = Get-Excel
    $wb = $xl.Workbooks.Open($in, 0, $true)    # UpdateLinks=0, ReadOnly
    try {
        switch ($fmt) {
            'pdf' { $wb.ExportAsFixedFormat(0, $out) }
            'xlsx' { $wb.SaveAs($out, 51) }
            'xls' { $wb.SaveAs($out, 56) }
            'ods' { $wb.SaveAs($out, 60) }
            'csv' { try { $wb.SaveAs($out, 62) } catch { $wb.SaveAs($out, 6) } }   # CSV UTF-8 (fallback CSV comum)
            default { throw "O Excel não exporta para $fmt." }
        }
    } finally {
        try { $wb.Close($false) } catch { }
        Release-Com $wb
    }
}

# ---------------------------------------------------------------------------
# PowerPoint
# ---------------------------------------------------------------------------
function Get-PowerPoint {
    if (-not $script:PowerPoint) { $script:PowerPoint = New-Object -ComObject PowerPoint.Application }
    return $script:PowerPoint
}

function Convert-WithPowerPoint([string]$in, [string]$out, [string]$fmt) {
    $formats = @{ pdf = 32; pptx = 24; odp = 35; ppt = 1 }
    if (-not $formats.ContainsKey($fmt)) { throw "O PowerPoint não exporta para $fmt." }
    $pp = Get-PowerPoint
    $pres = $pp.Presentations.Open($in, -1, 0, 0)   # ReadOnly, Untitled=false, sem janela
    try { $pres.SaveAs($out, $formats[$fmt]) }
    finally {
        try { $pres.Close() } catch { }
        Release-Com $pres
    }
}

# Apresentação de exemplo para o autoteste (PPTX e PPT).
function New-SampleSlides([string]$pptx, [string]$ppt) {
    $pp = Get-PowerPoint
    $pres = $pp.Presentations.Add(0)
    try {
        $s1 = $pres.Slides.Add(1, 1)
        $s1.Shapes.Item(1).TextFrame.TextRange.Text = 'Teste do Conversor'
        $s1.Shapes.Item(2).TextFrame.TextRange.Text = 'Apresentação de exemplo com acentuação'
        $s2 = $pres.Slides.Add(2, 2)
        $s2.Shapes.Item(1).TextFrame.TextRange.Text = 'Segundo slide'
        $s2.Shapes.Item(2).TextFrame.TextRange.Text = "Item um`rItem dois`rItem três"
        $pres.SaveAs($pptx, 24)
        if ($ppt) { $pres.SaveAs($ppt, 1) }
    } finally {
        try { $pres.Close() } catch { }
        Release-Com $pres
    }
}

# ---------------------------------------------------------------------------
# Imagens via WIC (HEIC/HEIF e o que o decodificador em Dart não ler) -> PNG
# ---------------------------------------------------------------------------
function Get-Orientation($frame) {
    try {
        $md = $frame.Metadata -as [System.Windows.Media.Imaging.BitmapMetadata]
        if ($md) {
            foreach ($q in '/app1/ifd/{ushort=274}', '/ifd/{ushort=274}') {
                try { if ($md.ContainsQuery($q)) { return [int]$md.GetQuery($q) } } catch { }
            }
        }
    } catch { }
    return 1
}

function Use-Orientation($frame) {
    $o = Get-Orientation $frame
    if ($o -le 1 -or $o -gt 8) { return $frame }
    $g = New-Object System.Windows.Media.TransformGroup
    $flipH = { $g.Children.Add((New-Object System.Windows.Media.ScaleTransform(-1, 1))) }
    $rot = { param($a) $g.Children.Add((New-Object System.Windows.Media.RotateTransform($a))) }
    switch ($o) {
        2 { & $flipH }
        3 { & $rot 180 }
        4 { $g.Children.Add((New-Object System.Windows.Media.ScaleTransform(1, -1))) }
        5 { & $flipH; & $rot 270 }
        6 { & $rot 90 }
        7 { & $flipH; & $rot 90 }
        8 { & $rot 270 }
    }
    $tb = New-Object System.Windows.Media.Imaging.TransformedBitmap($frame, $g)
    $tb.Freeze()
    return $tb
}

function Convert-WicToPng([string]$in, [string]$out) {
    Add-Type -AssemblyName PresentationCore, WindowsBase
    $bytes = [IO.File]::ReadAllBytes($in)
    $ms = New-Object IO.MemoryStream(, $bytes)
    try {
        $opts = [System.Windows.Media.Imaging.BitmapCreateOptions]'PreservePixelFormat, IgnoreColorProfile'
        $dec = [System.Windows.Media.Imaging.BitmapDecoder]::Create($ms, $opts,
            [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
    } catch {
        $ext = [IO.Path]::GetExtension($in).ToLowerInvariant()
        if ($ext -in '.webp', '.heic', '.heif') {
            throw "O Windows não conseguiu ler $ext. Instale 'Extensões de Imagem WebP' / 'Extensões de Imagem HEIF' (e 'Extensões de Vídeo HEVC' para HEIC) pela Microsoft Store."
        }
        throw 'Não foi possível ler a imagem (arquivo corrompido ou formato não suportado).'
    }
    $frame = Use-Orientation $dec.Frames[0]
    $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
    $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($frame))
    $fs = [IO.File]::Create($out)
    try { $enc.Save($fs) } finally { $fs.Dispose() }
}

# ---------------------------------------------------------------------------
# Atalho "Enviar para" do Explorer
# ---------------------------------------------------------------------------
function Install-SendTo([string]$exe) {
    $sendTo = [Environment]::GetFolderPath('SendTo')
    $shell = New-Object -ComObject WScript.Shell
    try {
        $path = Join-Path $sendTo 'Conversor de Arquivos.lnk'
        $lnk = $shell.CreateShortcut($path)
        $lnk.TargetPath = $exe
        $lnk.WorkingDirectory = [IO.Path]::GetDirectoryName($exe)
        $lnk.IconLocation = "$exe,0"
        $lnk.Description = 'Converter com o Conversor de Arquivos'
        $lnk.Save()
        Release-Com $lnk
        return @{ path = $path }
    } finally { Release-Com $shell }
}

# ---------------------------------------------------------------------------
# Fechamento: só encerra o aplicativo se o usuário não tiver nada aberto nele
# ---------------------------------------------------------------------------
function Close-Engines {
    if ($script:AcroApp) {
        try { if ($script:AcroApp.GetNumAVDocs() -eq 0) { [void]$script:AcroApp.Exit() } } catch { }
        Release-Com $script:AcroApp; $script:AcroApp = $null
    }
    if ($script:Word) {
        try {
            $count = $script:Word.Documents.Count
            Write-Trace "Word: $count documento(s) abertos no fechamento"
            # Quit(0) falha: o parâmetro é por referência no COM do Word.
            # Sem documentos abertos não há o que salvar, então sem argumento.
            if ($count -eq 0) { $script:Word.Quit() }
        } catch { Write-Trace "Word.Quit falhou: $(Get-ErrorMessage $_)" }
        Release-Com $script:Word; $script:Word = $null
    }
    if ($script:Excel) {
        try { if ($script:Excel.Workbooks.Count -eq 0) { $script:Excel.Quit() } } catch { }
        Release-Com $script:Excel; $script:Excel = $null
    }
    if ($script:PowerPoint) {
        try { if ($script:PowerPoint.Presentations.Count -eq 0) { $script:PowerPoint.Quit() } } catch { }
        Release-Com $script:PowerPoint; $script:PowerPoint = $null
    }
    [GC]::Collect(); [GC]::WaitForPendingFinalizers()
}

function Invoke-Action($req) {
    switch ($req.action) {
        'ping' { return @{ version = $PSVersionTable.PSVersion.ToString() } }
        # Conversões não devolvem dados: descarta qualquer saída do COM.
        'word' { $null = Convert-WithWord $req.in $req.out $req.fmt }
        'excel' { $null = Convert-WithExcel $req.in $req.out $req.fmt }
        'powerpoint' { $null = Convert-WithPowerPoint $req.in $req.out $req.fmt }
        'acrobat' { $null = Convert-WithAcrobat $req.in $req.out $req.fmt }
        'wic' { $null = Convert-WicToPng $req.in $req.out }
        'sendto' { return (Install-SendTo $req.exe) }
        'sample-slides' { $null = New-SampleSlides $req.pptx $req.ppt }
        default { throw "Ação desconhecida: $($req.action)" }
    }
    return $null
}

# ---------------------------------------------------------------------------
# Laço principal: caixa de mensagens em arquivos
# ---------------------------------------------------------------------------
$utf8 = New-Object Text.UTF8Encoding($false)
if (-not $Mailbox -or -not [IO.Directory]::Exists($Mailbox)) { throw 'Pasta da caixa de mensagens não encontrada.' }

function Test-ParentAlive {
    if ($ParentPid -le 0) { return $true }
    return [bool](Get-Process -Id $ParentPid -ErrorAction SilentlyContinue)
}

$next = 1
$idleTicks = 0
try {
    while ($true) {
        $reqPath = Join-Path $Mailbox "req_$next.json"
        if (-not [IO.File]::Exists($reqPath)) {
            Start-Sleep -Milliseconds 40
            # A cada ~2 s confere se o app ainda está aberto.
            $idleTicks++
            if ($idleTicks -ge 50) {
                $idleTicks = 0
                if (-not (Test-ParentAlive)) { Write-Trace 'app encerrado; saindo'; break }
            }
            continue
        }
        $idleTicks = 0
        $script:ErrorCode = $null
        $resp = @{ ok = $true }
        $close = $false
        try {
            $req = ConvertFrom-Json ([IO.File]::ReadAllText($reqPath, $utf8))
            Write-Trace "pedido $next : $($req.action)"
            if ($req.action -eq 'close') { $close = $true }
            else {
                $data = Invoke-Action $req
                if ($data) { $resp.data = $data }
            }
        } catch {
            $resp = @{ ok = $false; error = (Get-ErrorMessage $_); code = $script:ErrorCode }
        }
        try { [IO.File]::Delete($reqPath) } catch { }
        Write-Trace "concluído $next : ok=$($resp.ok) $($resp.error)"
        if ($close) { break }
        $json = ConvertTo-Json $resp -Compress -Depth 4
        $tmp = Join-Path $Mailbox "resp_$next.tmp"
        [IO.File]::WriteAllText($tmp, $json, $utf8)
        [IO.File]::Move($tmp, (Join-Path $Mailbox "resp_$next.json"))
        $next++
    }
} finally {
    Close-Engines
    Write-Trace 'ponte encerrada'
}
