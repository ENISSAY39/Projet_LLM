<#
.SYNOPSIS
Point de contrôle unique du profil laptop : à lancer après chaque changement.

.DESCRIPTION
Observe la machine de l'extérieur et s'arrête au premier contrôle en échec,
avec un message qui dit quoi corriger. Code de sortie : 0 si tout passe, 1 sinon.

.EXAMPLE
.\scripts\laptop\healthcheck.ps1
#>

$ErrorActionPreference = 'Stop'

$DossierModeles = 'D:\llms'
$Ollama = 'http://127.0.0.1:11434'
$Alias = 'famille'
$Modele = "${Alias}:latest"
# Moitié du débit mesuré avec tout le modèle sur le GPU (environ 85 tokens/s).
# Ollama 0.32.6 annonce « 100% GPU » même quand des couches débordent sur le CPU :
# le débit, lui, s'effondre (19 à 21 tokens/s avec 8 à 10 couches sur 43 sur le GPU).
$DebitMinimal = 40

function Reussite([string]$Message) {
    Write-Host "[OK]    $Message" -ForegroundColor Green
}

function Echec([string]$Message) {
    Write-Host "[ECHEC] $Message" -ForegroundColor Red
    exit 1
}

# 1. Stockage : tous les modèles restent dans D:\llms, jamais sur C:.
if ($env:OLLAMA_MODELS -ne $DossierModeles) {
    $Valeur = if ($env:OLLAMA_MODELS) { "« $env:OLLAMA_MODELS »" } else { 'non définie' }
    Echec "OLLAMA_MODELS doit valoir « $DossierModeles » (valeur actuelle : $Valeur)."
}
$ParDefaut = Join-Path $env:USERPROFILE '.ollama\models\blobs'
if (Test-Path (Join-Path $ParDefaut 'sha256-*')) {
    Echec "Des modèles existent dans $ParDefaut : ils doivent tous être dans $DossierModeles."
}
Reussite "OLLAMA_MODELS vaut $DossierModeles, aucun modèle dans l'emplacement par défaut."

# 2. Ollama répond.
try {
    $Version = (Invoke-RestMethod "$Ollama/api/version" -TimeoutSec 5).version
} catch {
    Echec "Ollama ne répond pas sur $Ollama : démarrer l'application Ollama."
}
Reussite "Ollama $Version répond sur $Ollama."

# 3. L'alias existe, et ses fichiers sont bien dans D:\llms.
if ($Modele -notin (Invoke-RestMethod "$Ollama/api/tags").models.name) {
    Echec "L'alias $Alias n'existe pas : lancer scripts\laptop\pull-models.ps1."
}
if (-not (Test-Path (Join-Path $DossierModeles 'blobs\sha256-*'))) {
    Echec "L'alias $Alias existe mais $DossierModeles\blobs est vide : Ollama stocke ses modèles ailleurs. Le redémarrer avec OLLAMA_MODELS=$DossierModeles."
}
Reussite "L'alias $Alias existe, ses fichiers sont dans $DossierModeles."

# 4. L'alias tient sur le GPU : Ollama l'annonce à 100 % GPU et le débit le confirme.
# Une courte question charge le modèle et donne le débit.
$DejaCharge = $Modele -in (Invoke-RestMethod "$Ollama/api/ps").models.name
$Question = @{ model = $Alias; prompt = 'Explique en deux phrases pourquoi le ciel est bleu.'; stream = $false } | ConvertTo-Json
try {
    $Reponse = Invoke-RestMethod "$Ollama/api/generate" -Method Post -ContentType 'application/json' -Body ([Text.Encoding]::UTF8.GetBytes($Question)) -TimeoutSec 300
} catch {
    Echec "L'alias $Alias ne répond pas : $($_.Exception.Message)"
}
$Charge = (Invoke-RestMethod "$Ollama/api/ps").models | Where-Object name -eq $Modele
if (-not $Charge) {
    Echec "L'alias $Alias a répondu mais n'est plus chargé : impossible de lire sa répartition GPU / CPU."
}
if ($Charge.size_vram -ne $Charge.size) {
    $PartGpu = [math]::Floor(100 * $Charge.size_vram / $Charge.size)
    Echec "L'alias $Alias n'est qu'à $PartGpu % sur le GPU (contexte $($Charge.context_length)) : appliquer la règle de repli des notes laptop de docs\materiel.md."
}
$Debit = $Reponse.eval_count / $Reponse.eval_duration * 1e9
if ($Debit -lt $DebitMinimal) {
    Echec ("L'alias $Alias ne produit que {0:N0} tokens/s (minimum : $DebitMinimal) : il déborde sans doute sur le CPU, même si « ollama ps » affiche 100 % GPU. Appliquer la règle de repli des notes laptop de docs\materiel.md." -f $Debit)
}
$Chargement = if ($DejaCharge) { 'déjà chargé' } else { 'chargement à froid en {0:N1} s' -f ($Reponse.load_duration / 1e9) }
Reussite ("Ollama annonce $Alias à 100 % GPU, contexte $($Charge.context_length) : {0:N0} tokens/s, $Chargement." -f $Debit)
