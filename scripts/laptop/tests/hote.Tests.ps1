#Requires -Modules Pester

# Tests des fonctions pures de scripts/laptop/hote.ps1 (sans toucher à la machine).
# Lancer : Invoke-Pester scripts\laptop\tests

. (Join-Path $PSScriptRoot '..\hote.ps1')

Describe 'Get-PlanEnvironnement' {
    It 'pose une variable absente ou différente de la cible' {
        $plan = Get-PlanEnvironnement -Actuel @{} -Poser @{ OLLAMA_KEEP_ALIVE = '4h' } -Supprimer @()
        $plan.Nom | Should Be 'OLLAMA_KEEP_ALIVE'
        $plan.Action | Should Be 'Poser'
        $plan.Nouveau | Should Be '4h'
        $plan.Actuel | Should BeNullOrEmpty
    }

    It 'ne signale rien si la valeur est déjà la cible' {
        $plan = Get-PlanEnvironnement -Actuel @{ OLLAMA_KEEP_ALIVE = '4h' } -Poser @{ OLLAMA_KEEP_ALIVE = '4h' } -Supprimer @()
        $plan.Action | Should Be 'Inchange'
    }

    It 'supprime une variable présente qui doit disparaître' {
        $plan = Get-PlanEnvironnement -Actuel @{ OLLAMA_CONTEXT_LENGTH = '65536' } -Poser @{} -Supprimer @('OLLAMA_CONTEXT_LENGTH')
        $plan.Action | Should Be 'Supprimer'
        $plan.Actuel | Should Be '65536'
    }

    It 'ne signale rien pour une variable à supprimer qui est déjà absente' {
        $plan = Get-PlanEnvironnement -Actuel @{} -Poser @{} -Supprimer @('OLLAMA_CONTEXT_LENGTH')
        $plan.Action | Should Be 'Inchange'
    }
}

Describe 'Get-AlertesReseau' {
    $regleOuverte = [pscustomobject]@{ DisplayName = 'Autre règle'; Profile = 'Public'; Action = 'Allow' }
    $regleNotre = [pscustomobject]@{ DisplayName = $NomRegle; Profile = 'Private'; Action = 'Allow' }

    It 'signale un Wi-Fi qui n''est pas en profil Privé' {
        $profils = @([pscustomobject]@{ InterfaceAlias = 'Wi-Fi'; NetworkCategory = 'Public' })
        $alertes = Get-AlertesReseau -Profils $profils -ReglesPort3000 @()
        $alertes.Count | Should Be 1
        $alertes[0] | Should Match 'Wi-Fi'
    }

    It 'ne signale pas un profil Privé' {
        $profils = @([pscustomobject]@{ InterfaceAlias = 'Wi-Fi'; NetworkCategory = 'Private' })
        $alertes = Get-AlertesReseau -Profils $profils -ReglesPort3000 @()
        $alertes.Count | Should Be 0
    }

    It 'signale une règle entrante Public ou Any qui ouvre le port 3000' {
        $alertes = Get-AlertesReseau -Profils @() -ReglesPort3000 @($regleOuverte)
        $alertes.Count | Should Be 1
        $alertes[0] | Should Match 'Autre règle'
    }

    It 'signale une règle Any sur le port 3000' {
        $regleAny = [pscustomobject]@{ DisplayName = 'Tout'; Profile = 'Any'; Action = 'Allow' }
        $alertes = Get-AlertesReseau -Profils @() -ReglesPort3000 @($regleAny)
        $alertes.Count | Should Be 1
    }

    It 'ne signale pas notre propre règle Privé' {
        $alertes = Get-AlertesReseau -Profils @() -ReglesPort3000 @($regleNotre)
        $alertes.Count | Should Be 0
    }
}
