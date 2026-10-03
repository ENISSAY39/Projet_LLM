<#
.SYNOPSIS
Applique les réglages de l'hôte du profil laptop, ou les annule.

.DESCRIPTION
Pour la durée du test : supprime OLLAMA_CONTEXT_LENGTH, pose OLLAMA_KEEP_ALIVE,
ouvre le port 3000 sur le profil Privé, active le démarrage d'Ollama et de Docker
Desktop, et règle la fermeture du capot (secteur : rien ; batterie : veille).

Ne lit ni n'écrit OLLAMA_MODELS ni OLLAMA_HOST. Signale sans corriger un réseau
qui n'est pas Privé et toute règle « Public » sur le port 3000.

Avant la première application, les valeurs d'origine sont notées dans
%LOCALAPPDATA%\llm-maison\hote-avant.json ; -Annuler les remet.

Application et annulation demandent un terminal administrateur (pare-feu).
-WhatIf décrit chaque changement sans rien modifier.

.EXAMPLE
.\scripts\laptop\hote.ps1 -WhatIf
.\scripts\laptop\hote.ps1
.\scripts\laptop\hote.ps1 -Annuler
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Annuler
)

$ErrorActionPreference = 'Stop'

# Valeurs décidées au ticket #4 : KEEP_ALIVE allongé (chargement à froid mesuré à 20-31 s).
$KeepAlive = '4h'
$VariablesASupprimer = @('OLLAMA_CONTEXT_LENGTH')
$Port = 3000
$NomRegle = 'llm-maison : Open WebUI (port 3000, profil Privé)'

$Dossier = Join-Path $env:LOCALAPPDATA 'llm-maison'
$Sauvegarde = Join-Path $Dossier 'hote-avant.json'
$Ollama = Join-Path $env:LOCALAPPDATA 'Programs\Ollama\ollama app.exe'
$RaccourciOllama = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\Ollama.lnk'
$SettingsDocker = Join-Path $env:APPDATA 'Docker\settings-store.json'
$SousGroupeAlim = '4f971e89-eebd-4455-a8de-9e59040e7347'
$ReglageCapot = '5ca83367-6e45-459f-a27b-476b1d01c936'

$Utf8SansBom = New-Object System.Text.UTF8Encoding($false)

function Echec([string]$Message) {
    Write-Host "[ECHEC] $Message" -ForegroundColor Red
    exit 1
}

function Info([string]$Message) {
    Write-Host "[INFO]  $Message" -ForegroundColor Cyan
}

function Alerte([string]$Message) {
    Write-Host "[ALERTE] $Message" -ForegroundColor Yellow
}

# ---------------------------------------------------------------------------
# Fonctions pures (testées dans scripts\laptop\tests).
# ---------------------------------------------------------------------------

# Compare l'état actuel de chaque variable utilisateur à la cible.
# -Poser : nom -> valeur voulue. -Supprimer : noms à retirer.
function Get-PlanEnvironnement {
    param(
        [hashtable]$Actuel,
        [hashtable]$Poser,
        [string[]]$Supprimer
    )
    foreach ($nom in $Poser.Keys) {
        $avant = $Actuel[$nom]
        $action = if ($avant -eq $Poser[$nom]) { 'Inchange' } else { 'Poser' }
        [pscustomobject]@{ Nom = $nom; Actuel = $avant; Nouveau = $Poser[$nom]; Action = $action }
    }
    foreach ($nom in $Supprimer) {
        $avant = $Actuel[$nom]
        $action = if ($null -eq $avant) { 'Inchange' } else { 'Supprimer' }
        [pscustomobject]@{ Nom = $nom; Actuel = $avant; Nouveau = $null; Action = $action }
    }
}

# Renvoie les avertissements : réseau non Privé, et règles entrantes « Public » ou « Any » sur le port 3000.
# Ne corrige rien.
function Get-AlertesReseau {
    param(
        $Profils,
        $ReglesPort3000
    )
    $alertes = @()
    foreach ($profil in $Profils) {
        if ($profil.NetworkCategory -ne 'Private') {
            $alertes += "Le réseau « $($profil.InterfaceAlias) » est en profil $($profil.NetworkCategory) : le passer en Privé dans les paramètres Windows (non corrigé par ce script)."
        }
    }
    foreach ($regle in $ReglesPort3000) {
        if ($regle.DisplayName -eq $NomRegle) { continue }
        if ($regle.Action -eq 'Allow' -and $regle.Profile -match 'Public|Any') {
            $alertes += "La règle entrante « $($regle.DisplayName) » ouvre le port $Port en profil $($regle.Profile) (non corrigée par ce script)."
        }
    }
    return , $alertes
}

# ---------------------------------------------------------------------------
# Lecture de l'état de la machine.
# ---------------------------------------------------------------------------

function Get-EtatActuel {
    $variables = @{}
    foreach ($nom in @('OLLAMA_KEEP_ALIVE') + $VariablesASupprimer) {
        $variables[$nom] = [Environment]::GetEnvironmentVariable($nom, 'User')
    }

    $regles = @(Get-NetFirewallRule -Direction Inbound -Enabled True -ErrorAction SilentlyContinue | Where-Object {
        (Get-NetFirewallPortFilter -AssociatedNetFirewallRule $_ -ErrorAction SilentlyContinue).LocalPort -contains "$Port"
    } | ForEach-Object {
        [pscustomobject]@{ DisplayName = $_.DisplayName; Profile = $_.Profile.ToString(); Action = $_.Action.ToString() }
    })

    $docker = $null
    if (Test-Path $SettingsDocker) {
        $docker = (Get-Content $SettingsDocker -Raw | ConvertFrom-Json).AutoStart
    }

    return [pscustomobject]@{
        Env              = $variables
        ReglesPort       = $regles
        ReglePareFeu     = [bool](Get-NetFirewallRule -DisplayName $NomRegle -ErrorAction SilentlyContinue)
        RaccourciOllama  = Test-Path $RaccourciOllama
        DockerAutoStart  = $docker
        Capot            = Get-ReglageCapot
        Profils          = @(Get-NetConnectionProfile -ErrorAction SilentlyContinue)
    }
}

# Lit les valeurs AC et DC de la fermeture du capot dans le plan actif (0 = ne rien faire, 1 = veille).
# Le réglage est masqué : powercfg /query ne l'affiche pas. Windows n'écrit la valeur dans le registre
# qu'après un premier réglage ; tant qu'elle n'y est pas, c'est la valeur par défaut, la mise en veille (1).
function Get-ReglageCapot {
    $schema = [regex]::Match((powercfg /getactivescheme) -join ' ', '[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}').Value
    $chemin = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes\$schema\$SousGroupeAlim\$ReglageCapot"
    $stocke = if (Test-Path $chemin) { Get-ItemProperty $chemin } else { $null }
    $ac = if ($stocke -and $null -ne $stocke.ACSettingIndex) { [int]$stocke.ACSettingIndex } else { 1 }
    $dc = if ($stocke -and $null -ne $stocke.DCSettingIndex) { [int]$stocke.DCSettingIndex } else { 1 }
    return [pscustomobject]@{ AC = $ac; DC = $dc }
}

# ---------------------------------------------------------------------------
# Modifications. Chacune passe par ShouldProcess : -WhatIf ne fait que décrire.
# ---------------------------------------------------------------------------

function Set-VariableUtilisateur([string]$Nom, $Valeur) {
    if ($PSCmdlet.ShouldProcess("Variable utilisateur $Nom", $(if ($null -eq $Valeur) { 'Supprimer' } else { "Poser à « $Valeur »" }))) {
        [Environment]::SetEnvironmentVariable($Nom, $Valeur, 'User')
        # Le processus courant garde ses propres variables : elles servent au redémarrage d'Ollama.
        [Environment]::SetEnvironmentVariable($Nom, $Valeur, 'Process')
    }
}

function Set-PareFeu {
    if ($PSCmdlet.ShouldProcess("Pare-feu : $NomRegle", "Créer (entrant, TCP $Port, profil Privé seul)")) {
        Remove-NetFirewallRule -DisplayName $NomRegle -ErrorAction SilentlyContinue
        New-NetFirewallRule -DisplayName $NomRegle -Direction Inbound -Action Allow -Protocol TCP -LocalPort $Port -Profile Private | Out-Null
    }
}

function Remove-PareFeu {
    if ($PSCmdlet.ShouldProcess("Pare-feu : $NomRegle", 'Supprimer')) {
        Remove-NetFirewallRule -DisplayName $NomRegle -ErrorAction SilentlyContinue
    }
}

function Set-RaccourciOllama([bool]$Present) {
    if ($Present) {
        if (-not (Test-Path $Ollama)) { Echec "Ollama introuvable : $Ollama." }
        if ($PSCmdlet.ShouldProcess($RaccourciOllama, 'Créer le raccourci de démarrage')) {
            $lnk = (New-Object -ComObject WScript.Shell).CreateShortcut($RaccourciOllama)
            $lnk.TargetPath = $Ollama
            $lnk.Save()
        }
    } elseif (Test-Path $RaccourciOllama) {
        if ($PSCmdlet.ShouldProcess($RaccourciOllama, 'Supprimer le raccourci de démarrage')) {
            Remove-Item $RaccourciOllama
        }
    }
}

# Docker Desktop n'expose pas ce réglage autrement que par son interface ou son fichier settings-store.json.
function Set-DockerAutoStart($Valeur) {
    if ($null -eq $Valeur) { return }
    if (-not (Test-Path $SettingsDocker)) {
        Alerte "Fichier de réglages Docker introuvable : lancer Docker Desktop une fois, puis relancer ce script."
        return
    }
    if (Get-Process 'Docker Desktop' -ErrorAction SilentlyContinue) {
        Alerte "Docker Desktop est ouvert : il peut réécrire son fichier de réglages. Vérifier « Démarrer Docker Desktop à la connexion » après fermeture."
    }
    if ($PSCmdlet.ShouldProcess($SettingsDocker, "AutoStart = $($Valeur.ToString().ToLower())")) {
        $reglages = Get-Content $SettingsDocker -Raw | ConvertFrom-Json
        $reglages | Add-Member -NotePropertyName AutoStart -NotePropertyValue $Valeur -Force
        [IO.File]::WriteAllText($SettingsDocker, ($reglages | ConvertTo-Json -Depth 20), $Utf8SansBom)
    }
}

function Set-Capot([int]$AC, [int]$DC) {
    if ($PSCmdlet.ShouldProcess('Plan d''alimentation actif, fermeture du capot', "Secteur : $AC, batterie : $DC (0 = ne rien faire, 1 = veille)")) {
        powercfg /setacvalueindex SCHEME_CURRENT $SousGroupeAlim $ReglageCapot $AC
        powercfg /setdcvalueindex SCHEME_CURRENT $SousGroupeAlim $ReglageCapot $DC
        powercfg /setactive SCHEME_CURRENT | Out-Null
        $relu = Get-ReglageCapot
        if ($relu.AC -ne $AC -or $relu.DC -ne $DC) {
            Echec "Le capot reste à secteur $($relu.AC) / batterie $($relu.DC) après écriture : vérifier le plan d'alimentation à la main."
        }
    }
}

function Restart-Ollama {
    if ($PSCmdlet.ShouldProcess('Ollama', 'Redémarrer pour prendre en compte les variables')) {
        Get-Process -Name 'ollama*' -ErrorAction SilentlyContinue | Stop-Process -Force -Confirm:$false
        Start-Process -FilePath $Ollama
        # Attend que l'API réponde (60 s au plus) avant la vérification.
        for ($i = 0; $i -lt 60; $i++) {
            try {
                Invoke-RestMethod 'http://127.0.0.1:11434/api/version' -TimeoutSec 2 | Out-Null
                return
            } catch {
                Start-Sleep -Seconds 1
            }
        }
        Echec "Ollama ne répond pas 60 s après son redémarrage."
    }
}

function Write-Sauvegarde($Etat) {
    $donnees = [ordered]@{
        Cree            = (Get-Date).ToString('o')
        Env             = $Etat.Env
        ReglePareFeu    = $Etat.ReglePareFeu
        RaccourciOllama = $Etat.RaccourciOllama
        DockerAutoStart = $Etat.DockerAutoStart
        CapotAC         = $Etat.Capot.AC
        CapotDC         = $Etat.Capot.DC
    }
    if ($PSCmdlet.ShouldProcess($Sauvegarde, 'Noter les valeurs d''origine')) {
        New-Item -ItemType Directory -Path $Dossier -Force | Out-Null
        [IO.File]::WriteAllText($Sauvegarde, ($donnees | ConvertTo-Json -Depth 5), $Utf8SansBom)
    }
}

function Test-Administrateur {
    $identite = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $identite.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ---------------------------------------------------------------------------
# Actions principales.
# ---------------------------------------------------------------------------

function Invoke-Appliquer {
    $etat = Get-EtatActuel

    foreach ($alerte in Get-AlertesReseau -Profils $etat.Profils -ReglesPort3000 $etat.ReglesPort) {
        Alerte $alerte
    }

    $plan = @(Get-PlanEnvironnement -Actuel $etat.Env -Poser @{ OLLAMA_KEEP_ALIVE = $KeepAlive } -Supprimer $VariablesASupprimer)
    foreach ($ligne in $plan) {
        Info ("{0,-22} {1} : « {2} » -> « {3} »" -f $ligne.Action, $ligne.Nom, $ligne.Actuel, $ligne.Nouveau)
    }

    if (-not $WhatIfPreference -and -not (Test-Administrateur)) {
        Echec "Lancer ce script depuis un terminal administrateur (pare-feu, plan d'alimentation)."
    }

    if (-not (Test-Path $Sauvegarde)) {
        Write-Sauvegarde $etat
    } else {
        Info "Sauvegarde des valeurs d'origine déjà présente : elle n'est pas réécrite."
    }

    foreach ($ligne in $plan | Where-Object Action -ne 'Inchange') {
        Set-VariableUtilisateur $ligne.Nom $ligne.Nouveau
    }
    Set-PareFeu
    if (-not $etat.RaccourciOllama) { Set-RaccourciOllama $true }
    Set-DockerAutoStart $true
    Set-Capot -AC 0 -DC 1

    Restart-Ollama

    if (-not $WhatIfPreference) {
        Info "Vérification : le script de vérification mesure aussi le débit."
        & (Join-Path $PSScriptRoot 'healthcheck.ps1')
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
}

function Invoke-Annuler {
    if (-not (Test-Path $Sauvegarde)) {
        Echec "Pas de sauvegarde à $Sauvegarde : rien à annuler."
    }
    if (-not $WhatIfPreference -and -not (Test-Administrateur)) {
        Echec "Lancer l'annulation depuis un terminal administrateur."
    }
    $d = Get-Content $Sauvegarde -Raw | ConvertFrom-Json

    foreach ($nom in @('OLLAMA_KEEP_ALIVE') + $VariablesASupprimer) {
        $valeur = $d.Env.$nom
        Set-VariableUtilisateur $nom $valeur
    }
    if (-not $d.ReglePareFeu) { Remove-PareFeu }
    Set-RaccourciOllama ([bool]$d.RaccourciOllama)
    Set-DockerAutoStart $d.DockerAutoStart
    Set-Capot -AC $d.CapotAC -DC $d.CapotDC

    Restart-Ollama

    if ($PSCmdlet.ShouldProcess($Sauvegarde, 'Supprimer la sauvegarde')) {
        Remove-Item $Sauvegarde
    }
    Info "Réglages d'origine remis en place."
}

if ($MyInvocation.InvocationName -ne '.') {
    if ($Annuler) { Invoke-Annuler } else { Invoke-Appliquer }
}
