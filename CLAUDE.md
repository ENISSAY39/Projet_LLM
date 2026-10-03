# CLAUDE.md — LLM local familial (Ollama + Open WebUI)

Contexte projet pour Claude Code. Tags, tailles et prix vérifiés le 2026-10-03 : ça bouge vite, revérifier avant d'agir. Achat de la machine cible prévu vers décembre 2027.

## Objectif

Auto-héberger à la maison des LLM open-weight (aucun entraînement), accessibles par navigateur sur le réseau local, pour 4 personnes, avec supervision Prometheus + Grafana.

| Qui | Usage | Modèle |
|---|---|---|
| Yassine (admin) | Code, agents (Cline), data/ML | `coder` |
| Mère, père, sœur | Questions du quotidien en français, aucun bagage technique | `famille` |

## Décisions

- **2 modèles, pas 4.** Un même modèle sert plusieurs personnes ; chacun a son compte, son historique et ses réglages dans Open WebUI. Pour un assistant personnalisé par personne : preset Open WebUI (Workspace > Models) sur la base `famille`, coût mémoire nul.
- **Alias stables.** `coder` et `famille` sont créés par Modelfile ; changer de modèle = changer une ligne `FROM`.
- **Indépendant du matériel.** Un profil (`PROFILE=basique` ou `spark`) fixe les modèles et les réglages Ollama. Changer de machine ne touche ni Open WebUI, ni les comptes, ni le monitoring.
- **Tout en Docker Compose.** Sur Mac : Ollama en natif (Docker n'accède pas au GPU Apple).
- **Rien n'est exposé à Internet.** Hors domicile : Tailscale uniquement.

```text
téléphones / PC du foyer ─► Open WebUI :3000 ─► ollama-metrics ─┐
                                                                ├─► Ollama :11434 ─► GPU
laptop dev (Cline) ─────────────────────────────────────────────┘
exporters (hôte, GPU, conteneurs, Ollama) ─► Prometheus :9090 ─► Grafana :3001
```

## Matériel : toutes les options

| # | Option | Mémoire | Prix relevé | Modèle de code visé | À retenir |
|---|---|---|---|---|---|
| 0 | Laptop actuel (RTX 4060) | 8 Go VRAM | 0 € | MoE 30B déjà en place | Prototype uniquement, pas un serveur 24/7 |
| 1 | **Basique** : PC + 1× RTX 3090 d'occasion | 24 Go VRAM | GPU ≈ 700–900 € + PC | `qwen3.8:27b` (dense) | Rapide. Un modèle à la fois : bascule code ↔ famille de ~10–20 s (à mesurer) |
| 2 | PC + 2× RTX 3090 | 48 Go VRAM | + ≈ 700–900 € | idem, contexte long | Code et famille résidents. Bruit, chaleur, ~700 W en charge |
| 3 | Mini PC Ryzen AI Max+ 395 | 64 ou 128 Go unifiés | ≈ 2 200 $ / 3 650 $ | MoE ; `qwen3-coder-next` en 128 Go | Meilleur prix au Go. Génération proche du Spark, lecture du prompt ~5× plus lente. Pas de CUDA |
| 4 | Mac mini M5 Pro | jusqu'à 64 Go unifiés | dès 1 699 $, 64 Go en option | MoE 30–35B | Silencieux. Ollama natif, pas de CUDA |
| 5 | DGX Spark 64 Go | 64 Go unifiés | 4 999 $, en vente le 23 oct. 2026 | `qwen3.6:35b` (MoE) | Trop juste pour le coder 80B (52 Go) + famille : mauvais rapport prix/usage |
| 6 | **DGX Spark 128 Go** | 128 Go unifiés | 6 950 $ (3 999 $ au lancement) | `qwen3-coder-next` (80B MoE) | Tout résident, contexte long, CUDA, fine-tuning. ≈ 45 tok/s mesurés sur ce modèle |
| 7 | Au-delà | 32 à 256 Go | RTX 5090 ≈ 4 300–5 000 $ de rue, RTX PRO 6000 96 Go, 2 Spark en cluster | — | Hors besoin pour 4 personnes |

Comment lire le tableau :

- La quantité de mémoire décide de la taille du modèle ; la bande passante mémoire décide de la vitesse. Le Spark (273 Go/s) gagne en capacité, pas en vitesse : sur un modèle qui tient dans 24 Go, une RTX 3090 (936 Go/s) reste environ 3× plus rapide (estimation à mesurer).
- Sur mémoire unifiée (options 3 à 6), `coder` doit être un MoE : un 27B dense plafonne vers 11 tok/s sur le Spark.
- Ce tableau est une photo d'octobre 2026, pas une liste d'achat : l'investissement est prévu vers décembre 2027 (voir « Calendrier »).

**Choix.** D'ici décembre 2027 : option 0 (laptop, 0 €), ou option 1 si l'usage réel le justifie (carte d'occasion revendable ensuite). En décembre 2027 : décision reprise sur le marché du moment, avec la méthode de la section « Calendrier ». À titre de repère aujourd'hui : l'option 6 vise un modèle de code plus gros, tout résident, plus du fine-tuning ; l'option 3 en 128 Go la même capacité à moitié prix, sans CUDA ; l'option 2 la vitesse sur des modèles ≤ 35B.

Reste du PC (options 1 et 2) : CPU récent 6–8 cœurs, 32 Go de RAM minimum (64 conseillé), NVMe 1 To, alimentation 850 W (1 200 W pour deux cartes), carte mère avec deux slots PCIe x16 espacés, boîtier bien ventilé, hors des pièces de vie.

## Calendrier

| Période | Action |
|---|---|
| Oct. 2026 → nov. 2027 | Faire tourner la stack (option 0 ou 1) et accumuler les mesures d'usage dans Grafana et l'écran Analytics d'Open WebUI |
| Nov. 2027 | Jalon de décision : choisir le modèle, puis la machine |
| Déc. 2027 | Achat, puis phase 8 (migration) |

Pourquoi ne rien figer aujourd'hui :

- Le DGX Spark actuel (GB10) aura sans doute un successeur : la feuille de route publique de NVIDIA place un « Vera Rubin Spark » en LPDDR6 sur 2027–2028. Côté AMD, Gorgon Halo (jusqu'à 192 Go) est annoncé pour fin 2026 et la génération Zen 6 « Medusa » pour 2027 ; les caractéristiques de Medusa Halo ne sont que des rumeurs.
- Ne pas compter sur une baisse des prix : TrendForce prévoit une DRAM encore tendue en 2027, Micron une amélioration progressive en 2028 seulement.
- Les modèles open-weight auront changé plusieurs fois : les tags de ce fichier seront périmés.

Méthode au jalon de novembre 2027 :

1. Sortir les chiffres d'usage : requêtes par jour et par personne, simultanéité maximale, longueur de contexte réelle en code, débit jugé confortable.
2. Choisir d'abord le modèle de code : tester les candidats du moment sur un vrai dépôt (suite pytest), via une API ou un GPU loué à l'heure.
3. En déduire la mémoire nécessaire (poids + contexte + modèle `famille` + ~16 Go de marge) et le débit minimal.
4. Comparer les machines du moment sur quatre critères : mémoire (Go), bande passante (Go/s), prix par Go, besoin de CUDA pour le fine-tuning. Puis bruit et consommation.
5. Créer le profil correspondant dans `profiles/` et `modelfiles/` ; le profil `spark` de ce fichier sert de gabarit.

## Profils

| Réglage | `basique` (1× RTX 3090) | `spark` (DGX Spark 128 Go) |
|---|---|---|
| Base de `coder` | `qwen3.8:27b` (18 Go), `num_ctx` 32768 | `qwen3-coder-next` (52 Go, 3B actifs, sans thinking), `num_ctx` 65536 puis monter |
| Base de `famille` | `gemma4:12b` (~8 Go), `num_ctx` 8192 | `gemma4:26b` (MoE, 16–19 Go), `num_ctx` 16384 |
| `OLLAMA_MAX_LOADED_MODELS` | 1 | 3 |
| `OLLAMA_NUM_PARALLEL` | 1 | 2 |
| `OLLAMA_KEEP_ALIVE` | `30m` | `-1` (toujours chargés) |
| `OLLAMA_FLASH_ATTENTION` / `OLLAMA_KV_CACHE_TYPE` | `1` / `q8_0` | `1` / `q8_0` |
| `TASK_MODEL` (titres, tags) | modèle courant, autocomplétion coupée | `famille:latest` |
| Système | x86_64, Ubuntu Server LTS | arm64, DGX OS : Docker et runtime NVIDIA préinstallés |
| Mémoire | VRAM dédiée, lisible dans `nvidia-smi` | Unifiée, partagée avec l'OS ; `nvidia-smi` n'affiche pas la mémoire. Garder ~16 Go de marge |

Notes `basique` :

- 18 Go de poids laissent environ 5 Go pour le contexte : si `ollama ps` montre une part CPU, descendre `num_ctx` à 24k puis 16k.
- Alternative sans bascule : tout le monde sur `coder` avec un preset « famille ». À tester avant de l'adopter (latence du thinking, qualité du français).
- Autres bases à tester : `qwen3.6:27b-coding`, `qwen3-coder:30b` (MoE, ~19 Go), `gemma4:e4b-it-q4_K_M` (6,6 Go).

Notes `spark` (gabarit daté d'octobre 2026, à recréer pour la machine réellement achetée) :

- Toutes les images doivent exister en arm64 (`docker manifest inspect`). À vérifier en priorité : `nvidia_gpu_exporter` et `ollama-metrics`, sinon build local.
- Playbooks officiels NVIDIA (Open WebUI + Ollama, Tailscale, DGX Dashboard, Unsloth pour le fine-tuning) : build.nvidia.com/spark.
- Voie plus rapide hors Ollama : vLLM ou TensorRT-LLM en NVFP4, branché dans Open WebUI comme connexion OpenAI-compatible. Optimisation ultérieure, pas un prérequis.

Dans les deux profils : tout dépôt GGUF de Hugging Face se tire avec `ollama pull hf.co/<user>/<repo>:<quant>`. Départager les candidats `coder` sur un vrai dépôt avec la suite pytest, pas sur les classements (les benchmarks publiés viennent des éditeurs).

## Arborescence cible

```text
llm-maison/
├── CLAUDE.md
├── docker-compose.yml                 # ollama + open-webui
├── docker-compose.monitoring.yml      # prometheus, grafana, exporters
├── .env.example                       # PROFILE, COMPOSE_FILE, WEBUI_SECRET_KEY, GRAFANA_ADMIN_PASSWORD
├── profiles/{basique,spark}.env       # variables Ollama du profil
├── modelfiles/{basique,spark}/{coder,famille}.Modelfile
├── monitoring/
│   ├── prometheus/prometheus.yml
│   └── grafana/provisioning/{datasources,dashboards,alerting}/
├── scripts/{pull-models,backup,healthcheck}.sh
└── docs/{config-ui,guide-famille}.md
```

## Étapes

### Phase 0 — Prototype sur le laptop, avant tout achat

- [ ] Open WebUI en Docker, branché sur l'Ollama déjà installé (commande `docker run` du Quick Start officiel).
- [ ] `ollama pull gemma4:e4b-it-q4_K_M` (tient dans 8 Go de VRAM) comme base provisoire de `famille`.
- [ ] Créer les 4 comptes et faire tester quelques jours : valide l'usage réel et le français avant de dépenser.

### Phase 1 — Serveur (profil `basique`)

1. Ubuntu Server LTS, IP fixe par réservation DHCP sur la box, SSH par clé.
2. Pilote NVIDIA : `sudo ubuntu-drivers install`, redémarrer, vérifier `nvidia-smi`.
3. Docker Engine + plugin Compose (dépôt officiel Docker).
4. NVIDIA Container Toolkit, puis `sudo nvidia-ctk runtime configure --runtime=docker && sudo systemctl restart docker`.
5. Test : `docker run --rm --gpus all ubuntu nvidia-smi`.

### Phase 2 — Stack et modèles

1. `.env` : `PROFILE=basique`, `WEBUI_SECRET_KEY=$(openssl rand -hex 32)`, `GRAFANA_ADMIN_PASSWORD`. Garder la clé fixe, sinon tout le monde est déconnecté à chaque recréation du conteneur.
2. `docker compose up -d`
3. `scripts/pull-models.sh` : pull des deux bases du profil, puis `ollama create` des deux alias.
4. `ollama ps` doit afficher `100% GPU` pour chaque alias. Sinon, baisser `num_ctx`.

### Phase 3 — Open WebUI (réglages faits dans l'interface, à consigner dans `docs/config-ui.md`)

1. Ouvrir `http://<ip-serveur>:3000` et créer le compte admin : le premier compte est admin, puis l'inscription se ferme toute seule.
2. Créer les 3 comptes famille depuis l'administration (rôle `user`).
3. Créer le groupe `famille` avec ces 3 comptes.
4. Réglages des modèles :
   - `famille` : privé, accès en lecture pour le groupe `famille`, modèle par défaut.
   - `coder` : privé, admin seul.
   - Bases brutes (`qwen3.8:27b`, `gemma4:12b`…) : désactivées ou masquées.
   - Règle Open WebUI : un preset n'est utilisable que si l'utilisateur a aussi accès à son modèle de base.
5. Tâches annexes (titres, tags, autocomplétion) : voir la ligne `TASK_MODEL` du profil. En `basique`, couper l'autocomplétion (`ENABLE_AUTOCOMPLETE_GENERATION=False`) pour éviter des bascules de modèle.
6. Interface en français sur chaque compte ; installer le site comme application sur les téléphones.

### Phase 4 — Réseau et sécurité

- Ne jamais ouvrir de port sur la box (3000, 3001, 9090, 11434).
- Ollama n'a aucune authentification : le port 11434 reste sur un LAN de confiance. Attention, Docker contourne `ufw` pour les ports publiés ; pour restreindre, publier sur `127.0.0.1` et passer par un tunnel SSH.
- Hors domicile, et HTTPS (exigé par les navigateurs pour le micro) : Tailscale + `tailscale serve`.
- `ENABLE_ADMIN_CHAT_ACCESS=False` : l'admin ne lit pas les conversations de la famille.
- Grafana : mot de passe admin fort dans `.env`, accès LAN uniquement.

### Phase 5 — Monitoring

Détail dans la section « Monitoring ». Ordre : exporters et Prometheus, cibles `UP`, dashboards provisionnés, proxy Ollama, alertes.

### Phase 6 — Exploitation

- Sauvegarde hebdomadaire du volume `open-webui` (cron), et avant chaque mise à jour. Tester une restauration.
- Mises à jour : versions épinglées dans les compose, puis `docker compose pull && docker compose up -d`.
- Test de redémarrage : tout doit revenir sans intervention.

### Phase 7 — Options

- Recherche web pour la famille (sans elle, le modèle ignore l'actualité) : moteur DDGS sans clé dans l'image `:main`, ou SearXNG auto-hébergé.
- Documents (RAG) : l'image `:main` embarque son moteur d'embeddings ; choisir un modèle multilingue pour le français.
- Cline : provider Ollama, `http://<ip-serveur>:11434`, modèle `coder:latest`.

### Phase 8 — Migration vers la machine achetée (visée : décembre 2027)

1. Sauvegarder le volume `open-webui`, le restaurer sur la nouvelle machine avec la même `WEBUI_SECRET_KEY` : comptes et historiques conservés.
2. Préparer l'hôte. Sur un DGX Spark : sauter la phase 1 (Docker et runtime NVIDIA déjà présents) et ajouter l'utilisateur au groupe `docker`.
3. `.env` : `PROFILE=<nouveau profil>`. Sur une machine arm64, vérifier que chaque image existe pour cette architecture.
4. `scripts/pull-models.sh` : nouvelles bases, mêmes alias, donc rien à reconfigurer dans Open WebUI.
5. Rejouer la définition de « terminé », panneaux mémoire du monitoring compris.

## Monitoring

| Service | Rôle | Port |
|---|---|---|
| `prometheus` | Collecte, rétention 30 jours | 9090 |
| `grafana` | Dashboards et alertes, provisionnés par fichiers | 3001 (3000 est pris par Open WebUI) |
| `node-exporter` | CPU, RAM, disque, températures de l'hôte | 9100 interne |
| `cadvisor` | CPU et mémoire par conteneur | 8080 interne |
| `gpu-exporter` (`utkuozdemir/nvidia_gpu_exporter`) | Utilisation GPU, VRAM, température, puissance (`nvidia_smi_*`) | 9835 interne |
| `ollama-metrics` (`NorskHelsenett/ollama-metrics`) | Proxy devant Ollama : tokens, durée, temps par token, modèles chargés (`ollama_*`) | 8080 interne |

Ollama n'expose pas de `/metrics` natif, d'où le proxy. C'est un petit projet communautaire placé sur le chemin des requêtes : relire `main.go`, épingler l'image par digest, vérifier que le streaming passe. Repli : remettre Open WebUI sur `http://ollama:11434` et écrire un mini exporter qui interroge `/api/ps`.

Dashboards (JSON versionnés dans `monitoring/grafana/provisioning/dashboards/`) :

- Hôte : Node Exporter Full (ID 1860).
- GPU : Nvidia GPU Metrics (ID 14574).
- Ollama : celui fourni dans le dossier `prometheus/` du dépôt `ollama-metrics`.
- Conteneurs : un dashboard cAdvisor au choix.
- Usage par personne et par modèle : écran Analytics intégré à l'admin d'Open WebUI, sans Grafana.

Alertes (Grafana, provisionnées, un canal de notification à choisir) :

- Une cible Prometheus `down` plus de 2 min.
- Température GPU > 85 °C pendant 5 min.
- Disque libre < 15 %.
- RAM disponible < 10 % (critique sur le Spark, mémoire unifiée).
- VRAM > 95 % pendant 10 min (profil `basique`).
- `ollama_time_per_token_seconds` en forte hausse : le modèle a débordé sur le CPU.

Les noms exacts des métriques se lisent sur le `/metrics` de chaque exporter avant d'écrire une requête.

Spécificités Spark : la mémoire GPU n'est pas rapportée par `nvidia-smi`, les panneaux VRAM restent vides. Suivre la mémoire avec `node-exporter` ; le DGX Dashboard (`https://localhost:11000`) sert de contrôle croisé.

Option : métriques HTTP et traces d'Open WebUI via OpenTelemetry (`ENABLE_OTEL=true`, `ENABLE_OTEL_METRICS=true`, `OTEL_EXPORTER_OTLP_ENDPOINT`) vers un collecteur OTel ; logs dans Loki.

## Fichiers de référence

`docker-compose.yml` :

```yaml
services:
  ollama:
    image: ollama/ollama:latest                 # épingler une version une fois validée
    restart: unless-stopped
    ports: ["11434:11434"]                      # pour Cline, LAN de confiance uniquement
    env_file: profiles/${PROFILE}.env
    volumes:
      - ollama:/root/.ollama
      - ./modelfiles/${PROFILE}:/modelfiles:ro
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]

  open-webui:
    image: ghcr.io/open-webui/open-webui:main   # épingler :vX.Y.Z
    restart: unless-stopped
    depends_on: [ollama]
    ports: ["3000:8080"]
    volumes:
      - open-webui:/app/backend/data
    environment:
      OLLAMA_BASE_URL: http://ollama:11434
      WEBUI_SECRET_KEY: ${WEBUI_SECRET_KEY}
      ENABLE_ADMIN_CHAT_ACCESS: "False"
      DEFAULT_USER_ROLE: pending

volumes:
  ollama:
  open-webui:
```

`docker-compose.monitoring.yml` (fusionné avec le précédent via `COMPOSE_FILE=docker-compose.yml:docker-compose.monitoring.yml` dans `.env`) :

```yaml
services:
  open-webui:
    environment:
      OLLAMA_BASE_URL: http://ollama-metrics:8080   # passe par le proxy de métriques

  ollama-metrics:
    image: ghcr.io/norskhelsenett/ollama-metrics:latest   # épingler par digest
    restart: unless-stopped
    environment:
      OLLAMA_HOST: http://ollama:11434

  prometheus:
    image: prom/prometheus:latest
    restart: unless-stopped
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --storage.tsdb.path=/prometheus
      - --storage.tsdb.retention.time=30d
    volumes:
      - ./monitoring/prometheus:/etc/prometheus:ro
      - prometheus:/prometheus
    ports: ["9090:9090"]

  grafana:
    image: grafana/grafana:latest
    restart: unless-stopped
    environment:
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_ADMIN_PASSWORD}
    volumes:
      - grafana:/var/lib/grafana
      - ./monitoring/grafana/provisioning:/etc/grafana/provisioning:ro
    ports: ["3001:3000"]

  node-exporter:
    image: prom/node-exporter:latest
    restart: unless-stopped
    pid: host
    command: ["--path.rootfs=/host"]
    volumes: ["/:/host:ro,rslave"]

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    restart: unless-stopped
    privileged: true
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro

  gpu-exporter:
    image: utkuozdemir/nvidia_gpu_exporter:latest-nvml   # vérifier le tag
    restart: unless-stopped
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]

volumes:
  prometheus:
  grafana:
```

Open WebUI mémorise ses connexions en base après le premier démarrage : si le changement d'`OLLAMA_BASE_URL` n'est pas pris en compte, corriger l'URL dans les réglages admin (Connections).

`monitoring/prometheus/prometheus.yml` :

```yaml
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: node
    static_configs: [{ targets: ["node-exporter:9100"] }]
  - job_name: cadvisor
    static_configs: [{ targets: ["cadvisor:8080"] }]
  - job_name: gpu
    static_configs: [{ targets: ["gpu-exporter:9835"] }]
  - job_name: ollama
    static_configs: [{ targets: ["ollama-metrics:8080"] }]
```

`modelfiles/basique/coder.Modelfile` :

```text
FROM qwen3.8:27b
PARAMETER num_ctx 32768
```

`modelfiles/basique/famille.Modelfile` :

```text
FROM gemma4:12b
PARAMETER num_ctx 8192
SYSTEM """Tu es l'assistant de la famille. Réponds en français, simplement, sans jargon. Si tu n'es pas sûr, dis-le."""
```

Les Modelfiles `spark` ne changent que `FROM` et `num_ctx` (voir « Profils »).

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
- Machine cible : décision au jalon de novembre 2027 (section « Calendrier »).
- Canal de notification des alertes (Telegram, Discord, e-mail).
- Qualité du français de la base `famille` : à valider en phase 0.
- Recherche web activée ou non pour la famille.