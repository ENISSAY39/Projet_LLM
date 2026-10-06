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

    It 'ne signale rien sans règle sur le port 3000' {
        $alertes = Get-AlertesReseau -ReglesPort3000 @()
        $alertes.Count | Should Be 0
    }

    It 'signale une règle entrante Public qui ouvre le port 3000' {
        $alertes = Get-AlertesReseau -ReglesPort3000 @($regleOuverte)
        ($alertes -join "`n") | Should Match '1 règle entrante'
        ($alertes -join "`n") | Should Match 'Autre règle'
    }

    It 'ignore une règle Any : seules les règles du profil Public sont signalées' {
        $regleAny = [pscustomobject]@{ DisplayName = 'Tout'; Profile = 'Any'; Action = 'Allow' }
        $alertes = Get-AlertesReseau -ReglesPort3000 @($regleAny)
        $alertes.Count | Should Be 0
    }

    It 'ignore une règle Public en Bloquer' {
        $regleBloquee = [pscustomobject]@{ DisplayName = 'Bloquee'; Profile = 'Public'; Action = 'Block' }
        $alertes = Get-AlertesReseau -ReglesPort3000 @($regleBloquee)
        $alertes.Count | Should Be 0
    }

    It 'ignore une règle qui n''est pas Public (Privé seul)' {
        $reglePrivee = [pscustomobject]@{ DisplayName = 'Privee'; Profile = 'Private'; Action = 'Allow' }
        $alertes = Get-AlertesReseau -ReglesPort3000 @($reglePrivee)
        $alertes.Count | Should Be 0
    }

    It 'compte les règles et regroupe les noms identiques' {
        $regles = @(
            [pscustomobject]@{ DisplayName = 'main.exe'; Profile = 'Public'; Action = 'Allow' },
            [pscustomobject]@{ DisplayName = 'main.exe'; Profile = 'Public'; Action = 'Allow' },
            [pscustomobject]@{ DisplayName = 'postman.exe'; Profile = 'Domain, Private, Public'; Action = 'Allow' }
        )
        $texte = (Get-AlertesReseau -ReglesPort3000 $regles) -join "`n"
        $texte | Should Match '3 règles'
        $texte | Should Match '2 noms'
        $texte | Should Match 'main\.exe \(×2\)'
        $texte | Should Match 'postman\.exe'
    }

    It 'ne signale pas notre propre règle Privé' {
        $alertes = Get-AlertesReseau -ReglesPort3000 @($regleNotre)
        $alertes.Count | Should Be 0
    }
}

Describe 'Test-OuvrePort' {
    It 'couvre le port 3000 par un port exact' {
        Test-OuvrePort -Ports @('3000') -Protocole 'TCP' | Should Be $true
    }

    It 'couvre le port 3000 par Any' {
        Test-OuvrePort -Ports @('Any') -Protocole 'Any' | Should Be $true
    }

    It 'couvre le port 3000 par une plage' {
        Test-OuvrePort -Ports @('2999-3001') -Protocole 'TCP' | Should Be $true
    }

    It 'couvre le port 3000 dans une liste' {
        Test-OuvrePort -Ports @('80,3000') -Protocole 'TCP' | Should Be $true
    }

    It 'ignore une plage qui ne contient pas 3000' {
        Test-OuvrePort -Ports @('3001-3010') -Protocole 'TCP' | Should Be $false
    }

    It 'ignore le port 3000 en UDP' {
        Test-OuvrePort -Ports @('3000') -Protocole 'UDP' | Should Be $false
    }

    It 'ignore un autre port' {
        Test-OuvrePort -Ports @('80') -Protocole 'TCP' | Should Be $false
    }
}

Describe 'Set-CleAutoStart' {
    It 'ajoute la clé si elle est absente, sans toucher aux autres' {
        $r = Set-CleAutoStart -Reglages ([pscustomobject]@{ Autre = 1 }) -Presente $true -Valeur $true
        $r.AutoStart | Should Be $true
        $r.Autre | Should Be 1
    }

    It 'remplace la valeur si la clé existe' {
        $r = Set-CleAutoStart -Reglages ([pscustomobject]@{ AutoStart = $false }) -Presente $true -Valeur $true
        $r.AutoStart | Should Be $true
    }

    It 'supprime la clé si elle était absente avant' {
        $r = Set-CleAutoStart -Reglages ([pscustomobject]@{ AutoStart = $true; Autre = 1 }) -Presente $false -Valeur $null
        $r.PSObject.Properties['AutoStart'] | Should BeNullOrEmpty
        $r.Autre | Should Be 1
    }
}
