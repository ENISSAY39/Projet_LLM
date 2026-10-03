# CLAUDE.md — LLM local familial (Ollama + Open WebUI)

Contexte projet pour Claude Code. Tags, tailles et prix vérifiés le 2026-10-03 : ça bouge vite, revérifier avant d'agir. Achat de la machine cible prévu vers décembre 2027.

## État actuel

Phase 0 en cours (spec : ticket #1), sur le laptop Windows (RTX 4060 8 Go, 32 Go de RAM, Ollama natif). Fait le 2026-10-03 : l'alias `famille` tourne à 100 % GPU et `scripts/laptop/healthcheck.ps1` le vérifie. Prochaine étape : Open WebUI en Compose (ticket #3). Mettre cette section à jour à la fin de chaque phase.

## Objectif

Auto-héberger à la maison des LLM open-weight (aucun entraînement), accessibles par navigateur sur le réseau local, pour 4 personnes, avec supervision Prometheus + Grafana.

| Qui | Usage | Modèle |
|---|---|---|
| Yassine (admin) | Code, agents, data/ML | `coder` |
| Mère, père, sœur | Questions du quotidien en français, aucun bagage technique | `famille` |

## Décisions

- **2 modèles, pas 4.** Un même modèle sert plusieurs personnes ; chacun a son compte, son historique et ses réglages dans Open WebUI. Pour un assistant personnalisé par personne : preset Open WebUI (Workspace > Models) sur la base `famille`, coût mémoire nul.
- **Alias stables.** `coder` et `famille` sont créés par Modelfile ; changer de modèle = changer une ligne `FROM`.
- **Indépendant du matériel.** Un profil (`PROFILE=basique` ou `spark`) fixe les modèles et les réglages Ollama. Changer de machine ne touche ni Open WebUI, ni les comptes, ni le monitoring.
- **Tout en Docker Compose.** Sur Mac : Ollama en natif (Docker n'accède pas au GPU Apple). Sur le laptop Windows (profil `laptop`) : Ollama en natif aussi, déjà installé.
- **Rien n'est exposé à Internet.** Hors domicile : Tailscale uniquement.

```text
téléphones / PC du foyer ─► Open WebUI :3000 ─► ollama-metrics ─► Ollama (port 11434 non publié) ─► GPU
exporters (hôte, GPU, conteneurs, Ollama) ─► Prometheus :9090 ─► Grafana :3001
```

## Profils

| Réglage | `laptop` (RTX 4060 8 Go, phase 0) | `basique` (1× RTX 3090) | `spark` (DGX Spark 128 Go) |
|---|---|---|---|
| Base de `coder` | aucune : `famille` seul | `qwen3.8:27b` (18 Go), `num_ctx` 32768 | `qwen3-coder-next` (52 Go, 3B actifs, sans thinking), `num_ctx` 131072 pour commencer, jusqu'à 240000 après mesure |
| Base de `famille` | `gemma4:e4b-it-q4_K_M` (6,6 Go), `num_ctx` 30000 | `gemma4:12b` (~8 Go), `num_ctx` 8192 | `gemma4:26b` (MoE, 16–19 Go), `num_ctx` 30000 |
| Mesures de `famille` | 2026-10-03 : 100 % GPU sans repli, ≈ 85 tokens/s, chargement à froid 6 s (détail : notes `laptop` de `docs/materiel.md`) | à mesurer | à mesurer |
| `OLLAMA_MAX_LOADED_MODELS` | 1 | 1 | 3 |
| `OLLAMA_NUM_PARALLEL` | 1 (défaut) | 1 | 2 |
| `OLLAMA_KEEP_ALIVE` | `30m` au départ, à poser par le script d'installation de l'hôte (`5m` par défaut d'ici là) | `30m` | `-1` (toujours chargés) |
| `OLLAMA_FLASH_ATTENTION` / `OLLAMA_KV_CACHE_TYPE` | `1` / `q8_0` | `1` / `q8_0` | `1` / `q8_0` |
| `TASK_MODEL` (titres, tags) | modèle courant (un seul alias) | modèle courant, autocomplétion coupée | `famille:latest` |
| Système | x86_64, Windows 11, Ollama natif (hors Docker) | x86_64, Ubuntu Server LTS | arm64, DGX OS : Docker et runtime NVIDIA préinstallés |
| Mémoire | VRAM dédiée, lisible dans `nvidia-smi` ; ≈ 5 Go pris par `famille` | VRAM dédiée, lisible dans `nvidia-smi` | Unifiée, partagée avec l'OS ; `nvidia-smi` n'affiche pas la mémoire. Garder ~16 Go de marge |

## Documentation

| Fichier | Contenu | Quand le lire |
|---|---|---|
| `docs/etapes.md` | Phases 0 à 8, de prototype à migration | Avant de commencer une phase |
| `docs/reference.md` | Compose, Prometheus, Modelfiles de départ | Avant de générer ou modifier ces fichiers |
| `docs/monitoring.md` | Stack, dashboards, alertes, cas du Spark | Avant de toucher au monitoring |
| `docs/materiel.md` | Options matériel, calendrier d'achat (décembre 2027), notes par profil | Avant un achat ou un changement de profil |

Ces chemins sont volontairement cités sans import : les ouvrir seulement quand le sujet se présente.

## Dépôt et skills

- **Dépôt privé.** Avant le premier commit, créer ou compléter `.gitignore` : `.env`, `backups/`, `CLAUDE.local.md`. Privé ne veut pas dire qu'on y met des secrets.
- **Skills Matt Pocock**, installés en global (`~/.claude/skills`). Le dépôt se configure une seule fois avec `/setup-matt-pocock-skills`, que seul l'utilisateur peut lancer. Si `docs/agents/` n'existe pas, le lui rappeler et ne démarrer aucun skill d'ingénierie avant.
- **Enchaînement type**, tapé par l'utilisateur : `/grill-with-docs` → `/to-spec` → `/to-tickets` → `/implement`. En cas de doute : `/ask-matt`. Fin de session : `/handoff`.
- **À utiliser de toi-même** quand la tâche s'y prête : `research` (tags, variables et docs vérifiés sur sources primaires), `diagnosing-bugs`, `wizard` (étapes que seul l'humain peut faire : pilotes, comptes Open WebUI, secrets), `tdd`, `code-review`.
- **Ce que « test » veut dire ici** : `docker compose config`, `scripts/healthcheck.sh` (sur le laptop : `scripts/laptop/healthcheck.ps1`), puis la définition de « terminé ». Pas de code applicatif à tester.
- **Hors sujet pour ce dépôt** : les skills TypeScript ou de cours (`migrate-to-shoehorn`, `setup-ts-deep-modules`, `scaffold-exercises`).

## Agent skills

### Issue tracker

Les tickets et specs vivent dans les GitHub Issues de `ENISSAY39/Projet_LLM` (CLI `gh`). See `docs/agents/issue-tracker.md`.

### Triage labels

Vocabulaire par défaut : `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context : `GLOSSARY.md` à la racine + `docs/adr/`, créés à la demande par les skills. See `docs/agents/domain.md`.

## Arborescence cible

```text
Projet_LLM/
├── CLAUDE.md
├── GLOSSARY.md                        # glossaire du projet, créé par les skills
├── .gitignore
├── docker-compose.yml                 # ollama + open-webui
├── docker-compose.monitoring.yml      # prometheus, grafana, exporters
├── .env.example                       # PROFILE, COMPOSE_FILE, WEBUI_SECRET_KEY, GRAFANA_ADMIN_PASSWORD
├── profiles/{basique,spark}.env       # variables Ollama du profil
├── modelfiles/{basique,spark}/{coder,famille}.Modelfile
├── modelfiles/laptop/famille.Modelfile                # profil laptop : famille seul
├── monitoring/
│   ├── prometheus/prometheus.yml
│   └── grafana/provisioning/{datasources,dashboards,alerting}/
├── scripts/{pull-models,backup,healthcheck}.sh
├── scripts/laptop/{pull-models,healthcheck}.ps1       # profil laptop : Ollama natif sous Windows
└── docs/
    ├── agents/                                     # créé par /setup-matt-pocock-skills
    ├── adr/                                        # décisions, créé par /grill-with-docs
    ├── {materiel,etapes,monitoring,reference}.md   # détail du projet, lu à la demande
    └── {config-ui,guide-famille}.md                # à créer
```

## Commandes

```bash
docker compose up -d
docker compose exec ollama ollama pull qwen3.8:27b
docker compose exec ollama ollama pull gemma4:12b
docker compose exec ollama ollama create coder   -f /modelfiles/coder.Modelfile
docker compose exec ollama ollama create famille -f /modelfiles/famille.Modelfile
docker compose exec ollama ollama ps                          # répartition GPU / CPU
docker compose exec ollama ollama run --verbose coder "ping"  # eval rate = tokens/s
docker compose logs -f open-webui

# sauvegarde du volume Open WebUI (préfixé par le nom du projet Compose)
docker run --rm -v llm-maison_open-webui:/data -v "$PWD/backups":/backup alpine \
  tar czf /backup/openwebui-$(date +%F).tar.gz -C /data .
```

Profil `laptop` : Ollama est natif, les commandes `ollama` se lancent sans `docker compose exec ollama`.

```powershell
.\scripts\laptop\pull-models.ps1   # base puis alias famille ; refuse si OLLAMA_MODELS ne vaut pas D:\llms
.\scripts\laptop\healthcheck.ps1   # point de contrôle unique, à lancer après chaque changement
```

## Définition de « terminé »

- [ ] Le conteneur `ollama` voit le GPU (`nvidia-smi`).
- [ ] `coder` et `famille` tournent à 100 % GPU au contexte visé ; débit mesuré et noté.
- [ ] Un compte famille ne voit que `famille` ; l'admin voit tout.
- [ ] 10 questions réelles en français validées par la famille.
- [ ] Toutes les cibles Prometheus sont `UP` ; chaque dashboard affiche des données.
- [ ] Le streaming fonctionne à travers `ollama-metrics` et les tokens remontent dans Grafana.
- [ ] Une alerte de test arrive sur le canal choisi.
- [ ] Redémarrage de la machine : service de retour sans intervention.
- [ ] Sauvegarde restaurée avec succès sur un volume de test.

## Règles pour Claude

- Répondre en français, court.
- Lire le document concerné dans `docs/` avant d'agir sur son sujet.
- Ne jamais inventer un tag de modèle, un tag d'image, une variable d'environnement, un nom de métrique ou un chemin de menu : vérifier sur ollama.com/library, docs.ollama.com, docs.openwebui.com (variables : `/reference/env-configuration`) et le dépôt de chaque exporter. Les menus d'Open WebUI changent selon la version.
- Infra = code : toute modification passe par les fichiers compose, `profiles/`, les Modelfiles, `monitoring/` ou `scripts/`. Les réglages faits dans l'interface sont consignés dans `docs/config-ui.md`.
- Ce qui dépend du matériel va dans le profil, jamais en dur ailleurs.
- Secrets dans `.env`, jamais commités.
- Demander confirmation avant toute commande destructive (`docker compose down -v`, `docker volume rm`, `ollama rm`).
- Après tout changement de modèle, de contexte ou de variable Ollama : relancer `ollama ps` et remesurer le débit.
- Ne rien exposer à Internet.

## Limites connues

- Un modèle local reste en dessous des modèles cloud de pointe sur les tâches de code difficiles, y compris le coder 80B du Spark.
- Le Spark n'accélère pas les modèles ≤ 35B : il sert à en faire tourner de plus gros.
- Santé, juridique, argent : réponses à vérifier. Le dire clairement dans `docs/guide-famille.md`.

## Points ouverts

- D'ici décembre 2027 : rester sur le laptop (option 0) ou monter l'option 1 ?
- Machine cible : décision au jalon de novembre 2027 (`docs/materiel.md`).
- Canal de notification des alertes (Telegram, Discord, e-mail).
- Qualité du français de la base `famille` : à valider en phase 0.
- Recherche web activée ou non pour la famille.
