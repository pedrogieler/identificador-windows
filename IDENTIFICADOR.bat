@echo off
setlocal EnableExtensions DisableDelayedExpansion
title --- AUDITORIA DE HARDWARE E SISTEMA ---
color 0F
chcp 65001 >nul
set "AUDITORIA_BAT=%~f0"
fltmc >nul 2>&1
if not errorlevel 1 goto executar
echo.
echo ==========================================================
echo          SOLICITANDO PERMISSAO DE ADMINISTRADOR
echo ==========================================================
echo Confirme a solicitacao do Windows.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
 "try {" ^
 " $q=[char]34;" ^
 " $args='/d /s /c '+$q+$q+$env:AUDITORIA_BAT+$q+$q;" ^
 " Start-Process -FilePath $env:ComSpec -ArgumentList $args -Verb RunAs -ErrorAction Stop;" ^
 "} catch {" ^
 " Write-Host ('ERRO: '+$_.Exception.Message) -ForegroundColor Red;" ^
 " exit 1;" ^
 "}"
if errorlevel 1 pause
exit /b
:executar
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
 "try {" ^
 " $text=[IO.File]::ReadAllText($env:AUDITORIA_BAT);" ^
 " $marker='# INICIO_'+'POWERSHELL';" ^
 " $pos=$text.IndexOf($marker);" ^
 " if($pos -lt 0){throw 'Bloco PowerShell nao encontrado.'};" ^
 " & ([scriptblock]::Create($text.Substring($pos+$marker.Length)));" ^
 "} catch {" ^
 " Write-Host ('ERRO: '+$_.Exception.Message) -ForegroundColor Red;" ^
 " exit 1;" ^
 "}"
if errorlevel 1 pause
endlocal
exit /b

# INICIO_POWERSHELL
$ErrorActionPreference = 'Stop'
$script:LarguraAlvo = 120
$script:Fonte = 24
$script:FonteAutomatica = $true
$script:Pagina = 0
$script:Paginas = 1
$script:Mensagem = ''
$script:AvisoFonte = ''
$script:NativeOK = $false
$script:VT = $false

# CONTROLE NATIVO DA FONTE
try {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class AuditHUD
{
    [StructLayout(LayoutKind.Sequential)]
    public struct COORD { public short X; public short Y; }
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    public struct FONT {
        public uint cbSize;
        public uint nFont;
        public COORD dwFontSize;
        public int FontFamily;
        public int FontWeight;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)]
        public string FaceName;
    }
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetStdHandle(int id);
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("kernel32.dll")]
    public static extern bool GetConsoleMode(IntPtr handle, out uint mode);
    [DllImport("kernel32.dll")]
    public static extern bool SetConsoleMode(IntPtr handle, uint mode);
    [DllImport("kernel32.dll")]
    public static extern COORD GetLargestConsoleWindowSize(IntPtr handle);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    private static extern bool SetCurrentConsoleFontEx(IntPtr handle, bool maximumWindow, ref FONT font);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    private static extern bool GetCurrentConsoleFontEx(IntPtr handle, bool maximumWindow, ref FONT font);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr window, int command);
    public static int SetFont(int height) {
        FONT font = new FONT();
        font.cbSize = (uint)Marshal.SizeOf(typeof(FONT));
        font.FaceName = "Consolas";
        font.FontFamily = 54;
        font.FontWeight = 400;
        font.dwFontSize.X = 0;
        font.dwFontSize.Y = (short)height;
        IntPtr handle = GetStdHandle(-11);
        if (!SetCurrentConsoleFontEx(handle, false, ref font)) return 0;
        FONT actual = new FONT();
        actual.cbSize = (uint)Marshal.SizeOf(typeof(FONT));
        if (!GetCurrentConsoleFontEx(handle, false, ref actual)) return 0;
        return actual.dwFontSize.Y;
    }
}
'@
    $script:Handle = [AuditHUD]::GetStdHandle(-11)
    $script:NativeOK = $true
    [uint32]$mode = 0
    if ([AuditHUD]::GetConsoleMode($script:Handle, [ref]$mode)) {
        $script:VT = [AuditHUD]::SetConsoleMode($script:Handle, ($mode -bor 4))
    }
} catch { $script:AvisoFonte = 'Ajuste automatico de fonte indisponivel.' }

# FORMATACAO
function V($Value) {
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return 'Nao disponivel' }
    return (([string]$Value) -replace '[\x00-\x1F\x7F]', ' ').Trim()
}
function GB($Value) {
    if ($null -eq $Value) { return 'N/D' }
    return ('{0:N2}' -f ([double]$Value / 1GB))
}
function Linha {
    param([string]$Texto = '', [string]$Cor = 'White')
    [pscustomobject]@{ Texto = $Texto; Cor = $Cor }
}
function Adicionar {
    param([string]$Lado, [string]$Texto, [string]$Cor = 'White')
    $item = Linha $Texto $Cor
    if ($Lado -eq 'E') { $script:Esquerda.Add($item) } else { $script:Direita.Add($item) }
}
function Campo {
    param([string]$Lado, [string]$Rotulo, $Valor, [string]$Cor = 'White')
    Adicionar $Lado ('{0,-18}: {1}' -f $Rotulo, (V $Valor)) $Cor
}
function Titulo {
    param([string]$Lado, [string]$Texto, [string]$Cor)
    Adicionar $Lado ('[ '+$Texto+' ]') $Cor
}
function Quebrar {
    param($Itens, [int]$Largura)
    foreach ($item in $Itens) {
        $text = [string]$item.Texto
        if ($text.Length -eq 0) { Linha '' $item.Cor; continue }
        while ($text.Length -gt $Largura) {
            $cut = $text.LastIndexOf(' ', $Largura - 1)
            if ($cut -lt [int]($Largura / 2)) { $cut = $Largura }
            Linha ($text.Substring(0, $cut).TrimEnd()) $item.Cor
            $text = '  '+$text.Substring($cut).TrimStart()
        }
        Linha $text $item.Cor
    }
}
function Escrever {
    param([string]$Texto, [string]$Cor = 'White')
    if ($Cor -eq 'AzulClaro') {
        if ($script:VT) {
            $esc = [string][char]27
            Write-Host ($esc+'[38;2;145;180;255m'+$Texto+$esc+'[0m') -NoNewline
        } else { Write-Host $Texto -ForegroundColor White -NoNewline }
        return
    }
    Write-Host $Texto -ForegroundColor $Cor -NoNewline
}

# IDENTIFICACAO SEGURA DE SSD/HD
function NormalizarSerie($Valor) {
    if ($null -eq $Valor) { return '' }
    $serie = (([string]$Valor) -replace '[\s\x00]', '').ToUpperInvariant()
    if ($serie -match '^(0+|UNKNOWN|NONE|NA|N/A|NOTAVAILABLE)$') { return '' }
    return $serie
}
function TipoArmazenamento {
    param($Disco, $DiscosWin32, $DiscosStorage)
    $serie = NormalizarSerie $Disco.SerialNumber
    if ([string]::IsNullOrWhiteSpace($serie)) { return 'Nao identificado' }
    $origens = @($DiscosWin32 | Where-Object { (NormalizarSerie $_.SerialNumber) -eq $serie })
    $destinos = @($DiscosStorage | Where-Object { (NormalizarSerie $_.SerialNumber) -eq $serie })
    if ($origens.Count -ne 1 -or $destinos.Count -ne 1) { return 'Nao identificado' }
    $fisico = $destinos[0]
    if ($null -eq $Disco.Size -or $null -eq $fisico.Size) { return 'Nao identificado' }
    $diferenca = [math]::Abs([double]$Disco.Size - [double]$fisico.Size)
    if ($diferenca -gt 1MB) { return 'Nao identificado' }
    switch ([int]$fisico.MediaType) {
        3 { return 'HD' }
        4 { return 'SSD' }
        default { return 'Nao identificado' }
    }
}

# COLETA DAS INFORMACOES
function Coletar {
    Clear-Host
    Write-Host 'Coletando informacoes da maquina...' -ForegroundColor Cyan
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $cpu = @(Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue)
    $board = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue | Select-Object -First 1
    $bios = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue | Select-Object -First 1
    $ram = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue)
    $disks = @(Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue)
    $volumes = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue)
    $nets = @(Get-CimInstance Win32_NetworkAdapterConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.IPEnabled })
    $storageDisks = @()
    try {
        $storageDisks = @(Get-CimInstance -Namespace 'root/Microsoft/Windows/Storage' -ClassName MSFT_PhysicalDisk -ErrorAction Stop)
    } catch { $storageDisks = @() }
    $script:Esquerda = New-Object 'System.Collections.Generic.List[object]'
    $script:Direita = New-Object 'System.Collections.Generic.List[object]'
    $script:DataColeta = Get-Date

    Titulo E 'IDENTIFICACAO DA MAQUINA E REDE' Yellow
    Campo E 'Nome do Computador' $env:COMPUTERNAME Green
    Campo E 'Usuario Ativo' $cs.UserName Green
    Campo E 'Conta Completa' ([Security.Principal.WindowsIdentity]::GetCurrent().Name)
    foreach ($n in $nets) {
        Campo E 'Adaptador' $n.Description
        $ips = @($n.IPAddress | Where-Object { $_ -match '^\d{1,3}(\.\d{1,3}){3}$' })
        if ($ips.Count -gt 0) {
            foreach ($ip in $ips) { Campo E 'Endereco IPv4' $ip Green }
        } else { Campo E 'Endereco IPv4' 'Nao disponivel' Green }
        $tipo = if ($n.DHCPEnabled) { 'DHCP (Automatico)' } else { 'IP Fixo (Manual)' }
        Campo E 'Tipo de Conexao' $tipo
        Campo E 'Gateway' ($n.DefaultIPGateway -join ', ')
        Campo E 'Endereco MAC' $n.MACAddress
    }
    if ($nets.Count -eq 0) { Adicionar E 'Nenhum adaptador IP ativo encontrado.' }
    Adicionar E ''

    Titulo E 'SISTEMA OPERACIONAL' Cyan
    Campo E 'Sistema' $os.Caption Green
    Campo E 'Versao' $os.Version
    Campo E 'Build' $os.BuildNumber
    Campo E 'Arquitetura' $os.OSArchitecture Green
    $boot = if ($os.LastBootUpTime) { $os.LastBootUpTime.ToString('dd/MM/yyyy HH:mm:ss') } else { 'Nao disponivel' }
    Campo E 'Ativo desde' $boot
    Adicionar E ''
    Titulo E 'PLACA-MAE E BIOS' AzulClaro
    Campo E 'Fabricante' $board.Manufacturer
    Campo E 'Modelo da Placa' $board.Product
    Campo E 'Numero de Serie' $bios.SerialNumber
    Campo E 'Fabricante BIOS' $bios.Manufacturer
    Campo E 'Versao BIOS' $bios.SMBIOSBIOSVersion

    Titulo D 'PROCESSADOR (CPU)' Red
    foreach ($c in $cpu) {
        Campo D 'Modelo' $c.Name Green
        Campo D 'Nucleos Fisicos' $c.NumberOfCores
        Campo D 'Threads' $c.NumberOfLogicalProcessors
        $uso = if ($null -ne $c.LoadPercentage) { [string]$c.LoadPercentage+'%' } else { 'Nao disponivel' }
        $freq = if ($null -ne $c.MaxClockSpeed) { [string]$c.MaxClockSpeed+' MHz' } else { 'Nao disponivel' }
        Campo D 'Uso Atual' $uso
        Campo D 'Frequencia Max.' $freq
    }
    if ($cpu.Count -eq 0) { Adicionar D 'Dados do processador nao disponiveis.' }
    Adicionar D ''
    Titulo D 'MEMORIA RAM INSTALADA' Magenta
    if ($ram.Count -gt 0) {
        $total = ($ram | Measure-Object Capacity -Sum).Sum
        Campo D 'Memoria RAM Total' ((GB $total)+' GB') Green
        Campo D 'Modulos Instalados' $ram.Count
        $i = 0
        foreach ($m in $ram) {
            $i++
            $speed = if ($m.Speed) { [string]$m.Speed+' MHz' } else { 'Velocidade N/D' }
            $info = (GB $m.Capacity)+' GB | '+$speed+' | '+(V $m.Manufacturer)
            Campo D ('Modulo '+$i) $info
        }
    } else {
        Campo D 'Memoria RAM Total' 'Nao disponivel' Green
        Campo D 'Modulos Instalados' 'Nao disponivel'
    }
    $livre = if ($null -ne $os.FreePhysicalMemory) { '{0:N2} GB' -f ($os.FreePhysicalMemory / 1MB) } else { 'Nao disponivel' }
    Campo D 'RAM Disponivel' $livre
    Adicionar D ''
    Titulo D 'ARMAZENAMENTO E ESPACO LIVRE' Yellow
    foreach ($d in $disks) {
        $tipoDisco = TipoArmazenamento -Disco $d -DiscosWin32 $disks -DiscosStorage $storageDisks
        Campo D 'Disco Fisico' $d.Model Green
        Campo D 'Capacidade' ((GB $d.Size)+' GB') Green
        Campo D 'Tipo Armazenamento' $tipoDisco Green
        Campo D 'Interface' $d.InterfaceType
    }
    if ($disks.Count -eq 0) { Adicionar D 'Dados dos discos fisicos nao disponiveis.' }
    foreach ($v in $volumes) {
        Campo D 'Particao' $v.DeviceID
        Adicionar D ('  Total: '+(GB $v.Size)+' GB | Livre: '+(GB $v.FreeSpace)+' GB')
    }
    if ($volumes.Count -eq 0) { Adicionar D 'Nenhuma unidade local encontrada.' }
    $script:Pagina = 0
}

# AJUSTE DA FONTE E DO BUFFER
function AjustarTela {
    param([bool]$Automatico = $true)
    $script:AvisoFonte = ''
    if (-not $script:NativeOK) { $script:AvisoFonte = 'Fonte automatica indisponivel neste console.'; return }
    if ($env:WT_SESSION) { $script:AvisoFonte = 'Windows Terminal: ajuste a fonte com Ctrl + roda do mouse.'; return }
    $window = [AuditHUD]::GetConsoleWindow()
    try {
        if ($window -ne [IntPtr]::Zero) { [void][AuditHUD]::ShowWindow($window, 9) }
        [Console]::SetWindowSize([math]::Min(80, [Console]::WindowWidth), [math]::Min(20, [Console]::WindowHeight))
        [Console]::SetWindowPosition(0, 0)
        $coluna = [int][math]::Floor(($script:LarguraAlvo - 5) / 2)
        $e = @(Quebrar $script:Esquerda $coluna)
        $d = @(Quebrar $script:Direita $coluna)
        $linhas = [math]::Max($e.Count, $d.Count) + 8
        $tamanhos = if ($Automatico) { @(32, 30, 28, 26, 24, 22, 20, 18) } else { @($script:Fonte) }
        $aplicou = $false
        foreach ($size in $tamanhos) {
            $real = [AuditHUD]::SetFont([int]$size)
            if ($real -le 0) { continue }
            $aplicou = $true
            $script:Fonte = $real
            $max = [AuditHUD]::GetLargestConsoleWindowSize($script:Handle)
            if (-not $Automatico -or ($max.X -ge $script:LarguraAlvo -and $max.Y -ge $linhas)) { break }
        }
        if (-not $aplicou) { $script:AvisoFonte = 'O Windows nao aceitou a alteracao da fonte.' }
        $max = [AuditHUD]::GetLargestConsoleWindowSize($script:Handle)
        if ($max.X -gt 0 -and $max.Y -gt 0) {
            $w = [int]$max.X
            $h = [int]$max.Y
            [Console]::SetBufferSize([math]::Max([Console]::BufferWidth, $w), [math]::Max([Console]::BufferHeight, $h))
            [Console]::SetWindowSize($w, $h)
        }
        if ($window -ne [IntPtr]::Zero) { [void][AuditHUD]::ShowWindow($window, 3) }
        try {
            [Console]::SetWindowPosition(0, 0)
            [Console]::SetBufferSize([Console]::WindowWidth, [Console]::WindowHeight)
        } catch { }
    } catch { $script:AvisoFonte = 'Nao foi possivel concluir o ajuste da janela.' }
    finally {
        if ($window -ne [IntPtr]::Zero) { [void][AuditHUD]::ShowWindow($window, 3) }
    }
    $script:Pagina = 0
}

# EXIBICAO DO PAINEL
function Mostrar {
    Clear-Host
    $disponivel = [Console]::WindowWidth - 1
    $altura = [Console]::WindowHeight
    if ($disponivel -lt 55 -or $altura -lt 15) {
        Write-Host 'Amplie a janela ou pressione F para reajustar.' -ForegroundColor Yellow
        Write-Host '[F] Ajustar  [-] Reduzir fonte  [X] Sair'
        $script:Paginas = 1
        return
    }
    $largura = [math]::Min($script:LarguraAlvo, $disponivel)
    $duasColunas = $largura -ge 100
    if ($duasColunas) {
        $coluna = [int][math]::Floor(($largura - 5) / 2)
        $e = @(Quebrar $script:Esquerda $coluna)
        $d = @(Quebrar $script:Direita $coluna)
        $total = [math]::Max($e.Count, $d.Count)
        $largura = 2 * $coluna + 5
    } else {
        $coluna = $largura - 2
        $itens = @($script:Esquerda.ToArray()) + @(Linha '') + @($script:Direita.ToArray())
        $e = @(Quebrar $itens $coluna)
        $d = @()
        $total = $e.Count
    }
    $margem = [int][math]::Floor(($disponivel - $largura) / 2)
    $recuo = ' ' * [math]::Max(0, $margem)
    $porPagina = [math]::Max(1, $altura - 8)
    $script:Paginas = [math]::Max(1, [int][math]::Ceiling($total / [double]$porPagina))
    if ($script:Pagina -ge $script:Paginas) { $script:Pagina = 0 }
    $titulo = 'AUDITORIA DE HARDWARE E SISTEMA'
    $central = ' ' * [math]::Max(0, [int][math]::Floor(($largura - $titulo.Length) / 2))
    Write-Host ($recuo+$central+$titulo) -ForegroundColor Cyan
    $sub = 'Administrador | Coleta: '+$script:DataColeta.ToString('dd/MM/yyyy HH:mm:ss')
    Write-Host ($recuo+$sub) -ForegroundColor White
    Write-Host ($recuo+('=' * $largura)) -ForegroundColor Cyan
    $inicio = $script:Pagina * $porPagina
    $quantidade = [math]::Min($porPagina, $total - $inicio)
    for ($row = 0; $row -lt $quantidade; $row++) {
        $idx = $inicio + $row
        $left = if ($idx -lt $e.Count) { $e[$idx] } else { Linha '' }
        Escrever ($recuo+' ')
        Escrever $left.Texto.PadRight($coluna) $left.Cor
        if ($duasColunas) {
            Escrever ' | ' DarkGray
            $right = if ($idx -lt $d.Count) { $d[$idx] } else { Linha '' }
            Escrever $right.Texto.PadRight($coluna) $right.Cor
        }
        Write-Host ''
    }
    Write-Host ($recuo+('=' * $largura)) -ForegroundColor Cyan
    Escrever $recuo
    Escrever '[A] Atualizar   ' Yellow
    Escrever '[F] Ajustar tela   ' Cyan
    Escrever '[X] Sair' Red
    Write-Host ''
    Escrever $recuo
    Escrever '[+] Aumentar fonte   [-] Diminuir fonte' Green
    Write-Host ''
    $status = if ($script:Paginas -gt 1) { '[N/P] Paginas | '+($script:Pagina + 1)+' de '+$script:Paginas } else { 'Painel completo' }
    if ($script:AvisoFonte) { $status += ' | '+$script:AvisoFonte } else { $status += ' | Consolas '+$script:Fonte }
    if ($script:Mensagem) { $status = $script:Mensagem }
    if ($status.Length -gt $largura) { $status = $status.Substring(0, $largura - 3)+'...' }
    Escrever ($recuo+$status) White
}

# EXECUCAO E MENU POR TECLA
try {
    [Console]::BackgroundColor = [ConsoleColor]::Black
    [Console]::ForegroundColor = [ConsoleColor]::White
    Coletar
    AjustarTela $true
    $sair = $false
    while (-not $sair) {
        Mostrar
        $key = [Console]::ReadKey($true)
        $char = [string]$key.KeyChar
        $script:Mensagem = ''
        if ($char -eq '+' -or $char -eq '=' -or $key.Key -eq [ConsoleKey]::Add) {
            $script:FonteAutomatica = $false
            $script:Fonte = [math]::Min(40, $script:Fonte + 2)
            AjustarTela $false
            continue
        }
        if ($char -eq '-' -or $key.Key -eq [ConsoleKey]::Subtract) {
            $script:FonteAutomatica = $false
            $script:Fonte = [math]::Max(14, $script:Fonte - 2)
            AjustarTela $false
            continue
        }
        switch ($key.Key) {
            'A' {
                try {
                    Coletar
                    if ($script:FonteAutomatica) { AjustarTela $true }
                } catch { $script:Mensagem = 'Falha ao atualizar: '+$_.Exception.Message }
            }
            'F' { $script:FonteAutomatica = $true; AjustarTela $true }
            'N' { if ($script:Pagina -lt ($script:Paginas - 1)) { $script:Pagina++ } }
            'P' { if ($script:Pagina -gt 0) { $script:Pagina-- } }
            'RightArrow' { if ($script:Pagina -lt ($script:Paginas - 1)) { $script:Pagina++ } }
            'LeftArrow' { if ($script:Pagina -gt 0) { $script:Pagina-- } }
            'X' { $sair = $true }
        }
    }
} finally { [Console]::ResetColor() }
