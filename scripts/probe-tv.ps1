[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory = $false)]
    [string]$TvIp
)

if (-not $TvIp) {
    Write-Host "Nenhum IP informado. Uso: .\scripts\probe-tv.ps1 -TvIp <IP_DA_TV>" -ForegroundColor Yellow
    $TvIp = Read-Host "Digite o endereco IP da sua TV Samsung na rede local"
}

if (-not $TvIp) {
    Write-Host "Operacao cancelada. Nenhum IP fornecido." -ForegroundColor Red
    exit 1
}

Write-Host "`n=======================================================" -ForegroundColor Cyan
Write-Host " Sondagem de Diagnostico - Samsung Tizen ($TvIp)" -ForegroundColor Cyan
Write-Host "=======================================================`n" -ForegroundColor Cyan

$results = [System.Collections.Generic.List[PSCustomObject]]::new()

function Add-Result($test, $target, $status, $details) {
    $results.Add([PSCustomObject]@{
        Teste    = $test
        Alvo     = $target
        Status   = $status
        Detalhes = $details
    })
}

# 1. Ping basico
Write-Host "[1/6] Testando conectividade ICMP (Ping)..." -NoNewline
try {
    $ping = Test-Connection -ComputerName $TvIp -Count 1 -Quiet -TimeoutSeconds 2
    if ($ping) {
        Write-Host " [OK]" -ForegroundColor Green
        Add-Result "Ping ICMP" "$TvIp" "OK" "Resposta recebida"
    } else {
        Write-Host " [FALHOU]" -ForegroundColor Red
        Add-Result "Ping ICMP" "$TvIp" "FALHA" "Sem resposta (verifique se a TV esta ligada)"
    }
} catch {
    Write-Host " [ERRO]" -ForegroundColor Red
    Add-Result "Ping ICMP" "$TvIp" "ERRO" $_.Exception.Message
}

# 2. Informacoes da TV via API REST (porta 8001 /api/v2/)
Write-Host "[2/6] Consultando /api/v2/ (Porta 8001)..." -NoNewline
try {
    $infoUri = "http://${TvIp}:8001/api/v2/"
    $res = Invoke-RestMethod -Uri $infoUri -Method Get -TimeoutSec 4 -ErrorAction Stop
    Write-Host " [OK]" -ForegroundColor Green
    $name = if ($res.name) { $res.name } else { $res.device.name }
    $model = $res.device.modelName
    $year = if ($res.device.model -match "^(\d{2})_") { "20" + $matches[1] } else { "N/A" }
    $os = $res.device.OS
    $power = $res.device.PowerState
    $mac = if ($res.device.wifiMac) { $res.device.wifiMac } else { $res.device.mac }
    
    Add-Result "Info TV" "/api/v2/" "OK" "Nome: '$name' | Modelo: $model ($year) | OS: $os | Power: $power | MAC: $mac"
    Write-Host "  -> Modelo: $model ($year) | OS: $os | Power: $power" -ForegroundColor Gray
} catch {
    Write-Host " [FALHOU]" -ForegroundColor Red
    Add-Result "Info TV" "/api/v2/" "FALHA" $_.Exception.Message
}

# 3. Teste do Media Renderer UPnP (Porta 9197 /dmr)
Write-Host "[3/6] Verificando UPnP Media Renderer (Porta 9197)..." -NoNewline
try {
    $dmrUri = "http://${TvIp}:9197/dmr"
    $resDmr = Invoke-WebRequest -Uri $dmrUri -Method Get -TimeoutSec 3 -ErrorAction Stop
    if ($resDmr.StatusCode -eq 200) {
        Write-Host " [OK]" -ForegroundColor Green
        Add-Result "UPnP DLNA" ":9197/dmr" "OK" "Servico de midia/volume ativo (XML recebido)"
    } else {
        Write-Host " [HTTP $($resDmr.StatusCode)]" -ForegroundColor Yellow
        Add-Result "UPnP DLNA" ":9197/dmr" "AVISO" "Status HTTP $($resDmr.StatusCode)"
    }
} catch {
    Write-Host " [FALHOU]" -ForegroundColor Yellow
    Add-Result "UPnP DLNA" ":9197/dmr" "INACESSIVEL" "Nao respondeu na porta 9197"
}

# 4. Teste de porta WebSocket SmartView (Porta 8002 TLS)
Write-Host "[4/6] Verificando porta WebSocket SmartView (8002 TCP)..." -NoNewline
try {
    $tcp = New-Object System.Net.Sockets.TcpClient
    $iar = $tcp.BeginConnect($TvIp, 8002, $null, $null)
    $success = $iar.AsyncWaitHandle.WaitOne(3000, $false)
    if ($success -and $tcp.Connected) {
        $tcp.EndConnect($iar)
        $tcp.Close()
        Write-Host " [OK]" -ForegroundColor Green
        Add-Result "WebSocket" ":8002 TCP" "OK" "Porta TLS aberta e aceitando conexoes"
    } else {
        $tcp.Close()
        Write-Host " [FECHADA]" -ForegroundColor Red
        Add-Result "WebSocket" ":8002 TCP" "FALHA" "Porta fechada ou sem conexao"
    }
} catch {
    Write-Host " [ERRO]" -ForegroundColor Red
    Add-Result "WebSocket" ":8002 TCP" "ERRO" $_.Exception.Message
}

# 5. Teste de Consulta de Aplicativo REST (/api/v2/applications/111299001912 - YouTube)
Write-Host "[5/6] Consultando status do app YouTube (/api/v2/applications/)..." -NoNewline
try {
    $ytUri = "http://${TvIp}:8001/api/v2/applications/111299001912"
    $ytRes = Invoke-RestMethod -Uri $ytUri -Method Get -TimeoutSec 3 -ErrorAction Stop
    Write-Host " [OK]" -ForegroundColor Green
    $running = $ytRes.running
    $visible = $ytRes.visible
    $version = $ytRes.version
    Add-Result "Status App" "YouTube (REST)" "OK" "Running: $running | Visible: $visible | Ver: $version"
    Write-Host "  -> Running: $running | Visible: $visible | Versao: $version" -ForegroundColor Gray
} catch {
    $errCode = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
    if ($errCode -eq 404) {
        Write-Host " [404]" -ForegroundColor Yellow
        Add-Result "Status App" "YouTube (REST)" "NAO_INSTALADO_OU_REST_FECHADO" "Retornou 404 Not Found"
    } else {
        Write-Host " [FALHOU: $($_.Exception.Message)]" -ForegroundColor Yellow
        Add-Result "Status App" "YouTube (REST)" "FALHA" $_.Exception.Message
    }
}

# 6. Teste de Abertura de App via REST POST (dry run / teste simples)
Write-Host "[6/6] Testando endpoint REST POST para abertura..." -NoNewline
try {
    $postUri = "http://${TvIp}:8001/api/v2/applications/111299001912"
    # Faz uma requisicao POST para verificar se o endpoint esta habilitado
    # Em Tizen 2020, se aceitar, pode abrir o YouTube ou retornar 200/204
    Write-Host " [TESTANDO POST]" -ForegroundColor Gray -NoNewline
    $postRes = Invoke-WebRequest -Uri $postUri -Method Post -TimeoutSec 4 -ErrorAction Stop
    Write-Host " [SUCESSO $($postRes.StatusCode)]" -ForegroundColor Green
    Add-Result "Launch REST" "POST /applications" "OK" "TV aceitou POST com codigo $($postRes.StatusCode)"
} catch {
    $postStatus = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 0 }
    Write-Host " [HTTP $postStatus]" -ForegroundColor Yellow
    Add-Result "Launch REST" "POST /applications" "HTTP_$postStatus" $_.Exception.Message
}

Write-Host "`n-------------------------------------------------------" -ForegroundColor Cyan
Write-Host " RESUMO DOS RESULTADOS DA SONDAGEM" -ForegroundColor Cyan
Write-Host "-------------------------------------------------------" -ForegroundColor Cyan
$results | Format-Table -AutoSize
