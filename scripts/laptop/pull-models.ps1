<#
.SYNOPSIS
Télécharge les bases du profil laptop puis crée ses alias.

.DESCRIPTION
Pour chaque Modelfile de modelfiles\laptop : récupère la base de la ligne FROM,
puis crée l'alias qui porte le nom du fichier. Refuse de démarrer si
OLLAMA_MODELS ne vaut pas D:\llms : aucun modèle ne doit arriver sur C:.

.EXAMPLE
.\scripts\laptop\pull-models.ps1
#>

$ErrorActionPreference = 'Stop'

$DossierModeles = 'D:\llms'
$Modelfiles = Join-Path $PSScriptRoot '..\..\modelfiles\laptop'

function Echec([string]$Message) {
    Write-Host "[ECHEC] $Message" -ForegroundColor Red
    exit 1
}

if ($env:OLLAMA_MODELS -ne $DossierModeles) {
    $Valeur = if ($env:OLLAMA_MODELS) { "« $env:OLLAMA_MODELS »" } else { 'non définie' }
    Echec "OLLAMA_MODELS doit valoir « $DossierModeles » (valeur actuelle : $Valeur). Rien n'a été téléchargé."
}

foreach ($Modelfile in Get-ChildItem $Modelfiles -Filter '*.Modelfile') {
    $Alias = $Modelfile.BaseName
    $From = Select-String -Path $Modelfile.FullName -Pattern '^\s*FROM\s+(\S+)' | Select-Object -First 1
    if (-not $From) {
        Echec "Pas de ligne FROM dans $($Modelfile.FullName)."
    }
    $Base = $From.Matches[0].Groups[1].Value

    Write-Host "Téléchargement de la base $Base"
    ollama pull $Base
    if ($LASTEXITCODE -ne 0) {
        Echec "Le téléchargement de $Base a échoué."
    }

    Write-Host "Création de l'alias $Alias"
    ollama create $Alias -f $Modelfile.FullName
    if ($LASTEXITCODE -ne 0) {
        Echec "La création de l'alias $Alias a échoué."
    }
}
