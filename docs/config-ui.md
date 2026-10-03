# Réglages faits dans l'interface d'Open WebUI

Version épinglée : `v0.11.4` (`docker-compose.yml`). Les chemins ci-dessous viennent de docs.openwebui.com (pages Models, Groups, Permissions, Analytics, Ollama, `/reference/env-configuration`), qui décrit la version courante. **Statut « à confirmer »** : libellé non retrouvé dans la doc ; le vérifier à l'écran en v0.11.4 et corriger ici.

Procédure guidée : `bash scripts/laptop/comptes.sh` (ticket #5). Rien n'est enregistré dans `.env` ; les mots de passe provisoires ne sont jamais consignés.

## Déjà posé par le code (`docker-compose.yml`)

| Variable | Valeur | Effet |
|---|---|---|
| `ENABLE_ADMIN_CHAT_ACCESS` | `False` | L'admin ne lit pas les conversations (lue au démarrage, non persistante). |
| `DEFAULT_USER_ROLE` | `pending` | Un nouveau compte attend la validation de l'admin. |

## Réglages manuels

| # | Réglage | Chemin dans l'interface | Statut |
|---|---|---|---|
| 1 | Compte admin | Premier compte créé à l'ouverture de `http://localhost:3000` | doc projet |
| 2 | Inscriptions fermées | Settings > Admin > General > « Enable New Sign Ups » (variable `ENABLE_SIGNUP`, persistante : l'interface prime après le premier démarrage) | à confirmer |
| 3 | 3 comptes famille, rôle `user` | Admin Panel > Users | à confirmer (format `prenom@maison.local`) |
| 4 | Groupe `famille` + les 3 comptes | Admin Panel > Users > Groups | vérifié (chemin) |
| 5 | Liste blanche Ollama : `famille:latest` | Settings > Admin > Connections > Manage Ollama API Connections > Manage > « Model IDs (Filter) ». Champ vide = tout visible | vérifié |
| 6 | `famille` privé, lecture pour le groupe `famille` | Workspace > Models > `famille` > Visibility : Private, puis Add Access (Read) | vérifié |
| 7 | `famille` modèle par défaut | Settings > Admin > Models > « Set as Selected Model » (variable équivalente `DEFAULT_MODELS`) | vérifié |
| 8 | Recherche web coupée | Settings > Admin > Web Search ; défaut `ENABLE_WEB_SEARCH=False`. Permission par groupe : Features > Web Search | à confirmer |
| 9 | Interface en français | Par compte : Settings > General > Language (défaut global : `DEFAULT_LOCALE`) | à confirmer |
| 10 | Aucun preset par personne | Ne rien créer dans Workspace > Models | — |

## Vérifications (critères du ticket #5)

- Inscription refusée depuis une fenêtre privée.
- Compte famille : seul `famille`, présélectionné ; réponse en français.
- Admin : conversations d'un compte famille inaccessibles.
- Settings > Admin > Analytics (`ENABLE_ADMIN_ANALYTICS`, vrai par défaut) : activité par personne. La doc précise que les compteurs comptent les réponses de l'assistant, pas les messages envoyés.

## Écarts constatés à l'écran

- 2026-10-03 : comptes créés avec de vraies adresses e-mail (pas `@maison.local`), rôle `Utilisateur`, groupe `famille` avec les 3 comptes : OK.
- Workspace > Models affiche « Modèles 0 » : `famille` n'a aucune fiche d'accès tant qu'on ne l'a pas enregistré une fois via Réglages > Modèles du panneau d'administration. Le wizard (étape 6) supposait le contraire.
- Permission de groupe « Accès aux modèles » = éditeur de modèles, pas visibilité : à laisser désactivée.
- Résolu le 2026-10-03 (confirmé par Yassine) : `famille` est créé dans l'espace de travail et réservé au groupe `famille` (père, mère, sœur). Ticket #5 fermé plus tôt en forçage, réglage terminé ensuite.
- Non revérifié par l'agent : rôle `Utilisateur` des trois comptes (ils avaient été passés en admin), liste blanche Ollama, modèle par défaut, inscription refusée, recherche web coupée, Analytics.
