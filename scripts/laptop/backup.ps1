<#
.SYNOPSIS
Archive le volume Open WebUI dans backups\ (ignoré par Git, sur D:).

.DESCRIPTION
Crée backups\openwebui-AAAA-MM-JJ-HHMMSS.tar.gz à partir du volume llm-maison_open-webui,
lu en lecture seule. Par défaut le conteneur tourne pendant la copie ; -Arreter le coupe
quelques secondes pour garantir une base SQLite cohérente, puis le relance.
La restauration est décrite dans docs/restauration.md.

.EXAMPLE
.\scripts\laptop\backup.ps1
.\scripts\laptop\backup.ps1 -Arreter
#>

param(
    [switch]$Arreter
)

$ErrorActionPreference = 'Stop'

$Volume = 'llm-maison_open-webui'
$Dossier = Join-Path $PSScriptRoot '..\..\backups'

function Get-NomArchive([datetime]$Date) {
    "openwebui-$($Date.ToString('yyyy-MM-dd-HHmmss')).tar.gz"
}

function Echec([string]$Message) {
    Write-Host "[ECHEC] $Message" -ForegroundColor Red
    exit 1
}

if ($MyInvocation.InvocationName -eq '.') { return }

docker volume inspect $Volume *> $null
if ($LASTEXITCODE -ne 0) {
    Echec "Le volume $Volume n'existe pas."
}

New-Item -ItemType Directory -Force $Dossier | Out-Null
$Dossier = (Resolve-Path $Dossier).Path
if ($Dossier -notlike 'D:\*') {
    Echec "Le dossier de sauvegardes doit être sur D: (trouvé : $Dossier)."
}

$Nom = Get-NomArchive (Get-Date)
$Compose = Join-Path $PSScriptRoot '..\..\docker-compose.yml'

if ($Arreter) { docker compose -f $Compose stop open-webui }
try {
    docker run --rm -v "${Volume}:/data:ro" -v "${Dossier}:/backup" alpine tar czf "/backup/$Nom" -C /data .
    if ($LASTEXITCODE -ne 0) { Echec "La création de l'archive a échoué." }
}
finally {
    if ($Arreter) { docker compose -f $Compose start open-webui }
}

$Archive = Join-Path $Dossier $Nom
$Taille = [math]::Round((Get-Item $Archive).Length / 1MB, 1)
Write-Host "[OK] $Archive ($Taille Mo)" -ForegroundColor Green
