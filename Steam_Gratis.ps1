# Header:
# dev: Herzz09
# data: 13/10/2026
# nome: Steam_Gratis.ps1

####################################################################################################################################
#Requires -Version 5.1
<#
.SYNOPSIS
    Lista jogos, DLCs e pacotes gratis na Steam: fim de semana gratis, 100% de desconto e free-to-play.
#>

####################################################################################################################################

####################################################################################################################################
############################↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓##############################################
############################→→→→→→→→→→→→→→→   PRESSIONE F5 PARA COMEÇAR   ←←←←←←←←←←←←←←←###########################################
############################↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑##############################################
####################################################################################################################################

####################################################################################################################################
# ===== 1. Define as paginas de busca =====
param(
    [int]$PaginasGratis = 2,   # paginas da lista "gratis" (50 itens cada)
    [int]$PaginasScan   = 2,   # paginas de promocoes varridas atras de fins de semana gratis
    [int]$Lote          = 10   # paginas de jogos baixadas ao mesmo tempo
)

####################################################################################################################################
# ===== 2. Titulo inicial =====
Clear-Host
if (-not $psISE) {("`n" * 2)} else {Write-Host ""}
if ($PSStyle) { $PSStyle.Progress.View = 'Classic' }
Write-Host ("`n" * 4)
Write-Host "`n  BUSCANDO JOGOS GRATIS NA STEAM" -ForegroundColor Green
Write-Host "  $('-' * 30)`n" -ForegroundColor DarkGray

####################################################################################################################################
# ===== 3.Infraestrutura =====
Add-Type -AssemblyName System.Net.Http
$Chrome = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
$Versao = if (Test-Path $Chrome) { (Get-Item $Chrome).VersionInfo.ProductVersion } else { '130.0.0.0' }
$Client = New-Object System.Net.Http.HttpClient -Property @{ Timeout = [TimeSpan]::FromSeconds(30) }
@{ 'User-Agent' = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$Versao Safari/537.36"
   'Cookie'     = 'birthtime=631152001; lastagecheckage=1-0-1990; wants_mature_content=1; timezoneOffset=-10800,0'
}.GetEnumerator() | ForEach-Object { [void]$Client.DefaultRequestHeaders.TryAddWithoutValidation($_.Key, $_.Value) }

####################################################################################################################################
# ===== 4. Converte \u00e9 (formato JSON) no caractere real =====
$RxUni = [regex]'\\u([0-9a-fA-F]{4})'
$EvUni = [System.Text.RegularExpressions.MatchEvaluator]{ param($m) [string][char][Convert]::ToInt32($m.Groups[1].Value, 16) }

####################################################################################################################################
# ===== 5. Define as funções e a animação =====

$Giro = '|', '/', '-', '\'
$n    = 0

function Barra($Texto, $Feito, $Total) {
    $script:n++
    $Pct = if ($Total) { [Math]::Min(100, [Math]::Floor(100 * $Feito / $Total)) } else { 0 }
    Write-Progress -Activity 'Buscando itens gratis na Steam' -Status "${Texto}: $Feito" -PercentComplete $Pct
    Write-Host ("`r  $($Giro[$script:n % 4]) $Texto$('.' * ($script:n % 4))".PadRight(40)) -NoNewline -ForegroundColor Cyan
    
}

function Limpa($Texto) { ([System.Net.WebUtility]::HtmlDecode($Texto) -replace '\s+', ' ').Trim() }

function Novo($A, $Tipo, $Situacao, $Detalhe = '', $Extra = '', $Disponivel = $true, $Motivo = '') {
    [pscustomobject]@{ Nome = $A.Nome; Id = $A.Id; Tipo = $Tipo; Situacao = $Situacao; Detalhe = $Detalhe; Extra = $Extra; Disponivel = $Disponivel; Motivo = $Motivo }
}

####################################################################################################################################
# ===== 6. Coleta os itens da busca =====
$PaginasTotais = $PaginasGratis + $PaginasScan
$PagFeitas     = 0

function Get-Itens($Filtro, $Fonte, $Paginas) {
    for ($p = 0; $p -lt $Paginas; $p++) {
        Barra 'Paginas lidas na Steam' $script:PagFeitas $PaginasTotais
        $script:PagFeitas++
        try { $Html = (Invoke-RestMethod "https://store.steampowered.com/search/results/?query&start=$($p * 50)&count=50$Filtro&infinite=1&cc=br&l=brazilian" -ErrorAction Stop).results_html }
        catch { continue }

        foreach ($L in ($Html -split '(?=<a href="https://store\.steampowered\.com/(?:app|sub|bundle)/)')) {
            if ($L -notmatch 'steampowered\.com/(app|sub|bundle)/(\d+)/') { continue }
            $Link = $Matches[1]; $Id = $Matches[2]
            $Nome = if ($L -match '<span class="title">(.*?)</span>') { Limpa $Matches[1] }
            if (-not $Nome) { continue }
            [pscustomobject]@{
                Link = $Link; Id = $Id; Nome = $Nome; Fonte = $Fonte
                Preco    = if ($L -match 'data-price-final="(\d+)"') { [int]$Matches[1] } else { -1 }
                Desc     = if ($L -match 'data-discount="(\d+)"') { [int]$Matches[1] } else { 0 }
                PrecoTxt = if ($L -match 'discount_final_price">(.*?)</div>') { Limpa $Matches[1] }
            }
        }
    }
}

$Todos = @(Get-Itens '&maxprice=free&specials=1' 'gratis' $PaginasGratis) + @(Get-Itens '&specials=1' 'scan' $PaginasScan)
Barra 'Lendo a Steam' $PaginasTotais $PaginasTotais

$Itens = @($Todos | Group-Object Link, Id | ForEach-Object { $_.Group[0] })  
if (-not $Itens) { Write-Host "`n  Nenhum item encontrado." -ForegroundColor Red ; Write-Host ""; return }

####################################################################################################################################
# ===== 7. Classifica =====
function Get-Achado($A, $Html) {
    $Jogar = $Html -match "steam://run/$($A.Id)"
    $Obter = $Html -match 'addToCart\('

    if (($m = [regex]::Match($Html, 'Jogue gratuitamente at[^<"]{1,60}')).Success) {
        $r = Novo $A 'APP' 'FIM DE SEMANA GRATIS' (Limpa $m.Value) "Preco atual: $($A.PrecoTxt)" $Jogar 'sem botao Jogar na pagina'
    }
    elseif ($A.Preco -eq 0 -and $A.Desc -ge 100) {
        $m   = [regex]::Match($Html, 'Obtenha antes de\s+\d+\s+de\s+\S+(?:\s+\S+\s+\d+:\d+)?|Oferta v.lida at[^<"]{1,40}')
        $Det = if ($m.Success) { (Limpa $m.Value) -replace '\u00e0s', 'as' } else { 'data de termino nao encontrada' }
        $r   = Novo $A 'APP' 'Tempo limitado' $Det '' $Obter 'sem botao de obter/adicionar na pagina'
    }
    elseif ($A.Preco -eq 0 -and $A.Fonte -eq 'gratis') {
        $r = Novo $A 'APP' 'Gratuito para jogar (permanente)' '' '' ($Jogar -or $Obter) 'sem botao de jogar/obter na pagina'
    }
    else { return }

    if ($Html -match 'game_area_comingsoon') { $r.Disponivel = $false; $r.Motivo = "pagina marcada como 'em breve'" }
    if (-not $Html)                          { $r.Disponivel = $true;  $r.Motivo = '' }   # pagina nao carregou: nao julga
    $r
}

$Achados = [System.Collections.Generic.List[object]]::new()

####################################################################################################################################
# ===== 8. Define pacotes e bundles (so da lista gratis) =====
$Itens | Where-Object { $_.Link -ne 'app' -and $_.Fonte -eq 'gratis' } | ForEach-Object {
    $Achados.Add((Novo $_ $(if ($_.Link -eq 'sub') { 'PACOTE' } else { 'BUNDLE' }) 'Gratis em promocao'))
}

####################################################################################################################################
# ===== 9. Define os apps: baixa a pagina de cada um, um lote de cada vez; o proximo lote baixa enquanto o atual e processado =====
$Apps  = @($Itens | Where-Object { $_.Link -eq 'app' })
$Total = $Apps.Count

function Start-Lote($Inicio) {
    @($Apps | Select-Object -Skip $Inicio -First $Lote | ForEach-Object {
        [pscustomobject]@{ App = $_; Task = $Client.GetStringAsync("https://store.steampowered.com/app/$($_.Id)/?cc=br&l=brazilian") }
    })
}

$Tarefas = Start-Lote 0
for ($i = 0; $i -lt $Total; $i += $Lote) {
    $Proximo = if ($i + $Lote -lt $Total) { Start-Lote ($i + $Lote) } else { @() }

    $j = 0
    foreach ($T in $Tarefas) {
        $j++
        while (-not $T.Task.IsCompleted) { Barra 'Verificando itens' ($i + $j - 1) $Total; Start-Sleep -Milliseconds 120 }
        Barra 'Verificando itens' ($i + $j) $Total
        Start-Sleep -Milliseconds 40
        try { $Html = $RxUni.Replace($T.Task.GetAwaiter().GetResult(), $EvUni) } catch { $Html = '' }
        if ($r = Get-Achado $T.App $Html) { $Achados.Add($r) }
    }
    $Tarefas = $Proximo
}

$Achados = @($Achados | Group-Object { "$($_.Tipo):$($_.Id)" } | ForEach-Object { $_.Group[0] })

####################################################################################################################################
# ===== 10. Descobre o tipo real (JOGO / DLC / DEMO) e confere o lancamento =====
$NomeTipo = @{ game = 'JOGO'; dlc = 'DLC'; demo = 'DEMO' }
$Pend     = @($Achados | Where-Object Tipo -eq 'APP')
$k        = 0

foreach ($A in $Pend) {
    Barra 'Conferindo tipos' (++$k) $Pend.Count
    try { $Info = (Invoke-RestMethod "https://store.steampowered.com/api/appdetails?appids=$($A.Id)&cc=br&l=brazilian" -ErrorAction Stop).($A.Id) }
    catch { $A.Tipo = 'DESCONHECIDO'; continue }

    if ($Info.success) {
        $Tipo   = $Info.data.type
        $A.Tipo = if ($NomeTipo[$Tipo]) { $NomeTipo[$Tipo] } else { "$Tipo".ToUpper() }
        if ($Tipo -eq 'dlc' -and $Info.data.fullgame.name) {
            $A.Extra = (@($A.Extra, "Requer o jogo: $($Info.data.fullgame.name)") | Where-Object { $_ }) -join ' | '
        }
        if ($Info.data.release_date.coming_soon) {
            $A.Disponivel = $false
            $A.Motivo     = "ainda nao lancado (previsto: $($Info.data.release_date.date))"
        }
    }
    else { $A.Tipo = 'DESCONHECIDO'; $A.Disponivel = $false; $A.Motivo = 'indisponivel na loja do Brasil ou removido' }
    Start-Sleep -Milliseconds 300
}

####################################################################################################################################
# ===== 11. Separa em grupos =====
$Disp   = @($Achados | Where-Object Disponivel)
$Temp   = @($Disp | Where-Object { $_.Tipo -ne 'DLC' -and $_.Situacao -in @('FIM DE SEMANA GRATIS', 'Tempo limitado') })
$Gratis = @($Disp | Where-Object { $_.Tipo -eq 'JOGO' -and $_.Situacao -like 'Gratuito*' })
$Dlcs   = @($Disp | Where-Object Tipo -eq 'DLC')
$Mostra = $Temp + $Gratis + $Dlcs
$Outros = @($Disp | Where-Object { $Mostra -notcontains $_ })

####################################################################################################################################
# ===== 12. Se todos terminam na mesma data, ela vai para o titulo =====
$Datas      = @($Temp | ForEach-Object { ($_.Detalhe -replace '^(Jogue gratuitamente at\S*|Oferta v.lida at\S*|Obtenha antes de)\s*', '') -replace '\u00e0s', 'as' } | Select-Object -Unique)
$TituloTemp = 'JOGOS DISPONIVEIS PARA BAIXAR TEMPORARIAMENTE'
if ($Datas.Count -eq 1 -and $Datas[0]) { $TituloTemp += " (ATE $($Datas[0]))".ToUpper() }

####################################################################################################################################
# ===== 13. Mostra o resultado =====
function Secao($Titulo, $Lista, $Cor, [switch]$Motivo) {
    if (-not $Lista) { return }
    $Linha = '=' * 79
    Write-Host "`n$Linha`n  $Titulo  [$(@($Lista).Count)]`n$Linha`n" -ForegroundColor $Cor
    foreach ($A in ($Lista | Sort-Object Nome)) {
        Write-Host $A.Nome -ForegroundColor White
        $Detalhe = if ($Motivo) { "Motivo: $($A.Motivo)" } elseif ($A.Detalhe) { $A.Detalhe } elseif ($A.Tipo -eq 'DLC') { $A.Situacao }
        if ($Detalhe) { Write-Host "  $Detalhe"  -ForegroundColor Gray }
        if ($A.Extra) { Write-Host "  $($A.Extra)" -ForegroundColor DarkGray }
        Write-Host
    }
}

Write-Progress -Activity 'Buscando itens gratis na Steam' -Completed
Clear-Host
Write-Host "`n--- ITENS GRATIS AGORA ($($Disp.Count) disponiveis) ---" -ForegroundColor Green
if (-not $Disp) { Write-Host "`nNada disponivel encontrado nesta varredura." -ForegroundColor Red }

Secao $TituloTemp                         $Temp   Magenta
Secao 'JOGOS GRATIS'                      $Gratis Green
Secao 'DLCs'                              $Dlcs   Yellow
Secao 'OUTROS (Demos, Pacotes e Bundles)' $Outros Cyan


####################################################################################################################################
# ===== 14. Se o script for rodado no console tem um tratamento especial para sair =====
if (-not $psISE) {
    Write-Host "................................"
    Write-Host "...Pressione Ctrl+C para sair... " -ForegroundColor Gray 
    Write-Host "................................" -NoNewline
    While ($true) {Start-Sleep -Seconds 1}
}
