# Étapes du projet

À lire avant de commencer une phase. Cocher au fur et à mesure.

## Ordre d'ici décembre 2027 (décidé le 2026-10-07)

Aucun achat avant décembre 2027. Le laptop est le prototype de Yassine seul : la famille n'utilise pas le service avant l'ouverture (voir plus bas). Les numéros de phase sont conservés, l'ordre de travail est celui-ci, une spec par chantier :

1. Monitoring complet sur le laptop (phase 5), en répétition de la stack de la machine cible.
2. HTTPS par `tailscale serve` (phase 4).
3. RAG (phase 7).
4. En parallèle, hors des specs : fine-tuning (phase 7) et essais `coder` sur GPU loué (`docs/materiel.md`).

Les phases 1 et 2 attendent l'achat et se déroulent avec la phase 8. La sauvegarde reste manuelle (`scripts/laptop/backup.ps1`), sans planification.

## Ouverture à la famille

La famille commence à utiliser le service quand tout ceci est en place sur la machine cible :

- [ ] Machine cible installée, `coder` et `famille` chargés en même temps.
- [ ] Monitoring complet, alertes comprises.
- [ ] RAG (documents).
- [ ] HTTPS par `tailscale serve`.

Non bloquants : le fine-tuning (son issue peut être l'abandon) et la recherche web (point ouvert). Les 3 comptes famille et leur accès Tailscale restent en place d'ici là : ils servent à tester ce que la famille verra et migrent avec le volume.

## Phase 0 — Prototype sur le laptop, avant tout achat

- [x] `scripts/laptop/pull-models.ps1` : base `gemma4:e4b-it-q4_K_M` puis alias `famille`, à 100 % GPU. `scripts/laptop/healthcheck.ps1` le vérifie ; mesures dans les notes `laptop` de `docs/materiel.md`.
- [x] Script d'installation de l'hôte (ticket #4) : `scripts\laptop\hote.ps1 -WhatIf` puis `scripts\laptop\hote.ps1` en administrateur, par Yassine. Annulation : `-Annuler`. Ensuite `scripts\laptop\healthcheck.ps1`.
- [x] Open WebUI en Compose (`docker-compose.yml`, projet `llm-maison`), branché sur l'Ollama déjà installé : `.env` depuis `.env.example` (`OLLAMA_BASE_URL=http://host.docker.internal:11434`, `WEBUI_SECRET_KEY` fixe), puis `docker compose up -d`. `scripts\laptop\healthcheck.ps1` contrôle le port 3000 et la vue de l'alias depuis le conteneur.
- [x] Créer les 4 comptes et faire tester quelques jours : valide l'usage réel et le français avant de dépenser.

## Phase 1 — Serveur (profil `basique`)

Reportée à l'achat (2026-10-07) : c'est la préparation d'hôte de la phase 8, à adapter à la machine cible, et à sauter sur un DGX Spark. Aucun serveur `basique` n'est prévu d'ici là.

1. Ubuntu Server LTS, SSH par clé. Accès par le nom MagicDNS Tailscale ; une IP fixe sur la box n'est utile que si on y accède aussi depuis le réseau local (selon l'emplacement du serveur, point ouvert de `CLAUDE.md`).
2. Pilote NVIDIA : `sudo ubuntu-drivers install`, redémarrer, vérifier `nvidia-smi`.
3. Docker Engine + plugin Compose (dépôt officiel Docker).
4. NVIDIA Container Toolkit, puis `sudo nvidia-ctk runtime configure --runtime=docker && sudo systemctl restart docker`.
5. Test : `docker run --rm --gpus all ubuntu nvidia-smi`.

## Phase 2 — Stack et modèles

1. `.env` : `PROFILE=basique`, `WEBUI_SECRET_KEY=$(openssl rand -hex 32)`, `GRAFANA_ADMIN_PASSWORD`. Garder la clé fixe, sinon tout le monde est déconnecté à chaque recréation du conteneur.
2. `docker compose up -d`
3. `scripts/pull-models.sh` : pull des deux bases du profil, puis `ollama create` des deux alias.
4. Lancer le script de vérification du profil (`scripts/healthcheck.sh`) : pour chaque alias, il contrôle la répartition GPU annoncée par Ollama et le débit. S'il échoue sur ce contrôle, baisser `num_ctx`. `ollama ps` seul ne suffit pas (notes `laptop` de `docs/materiel.md`).

## Phase 3 — Open WebUI (réglages faits dans l'interface, à consigner dans `docs/config-ui.md`)

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

## Phase 4 — Réseau et sécurité

- Ne jamais ouvrir de port sur la box (3000, 3001, 9090).
- Ollama n'a aucune authentification : son port 11434 n'est pas publié, il n'est joignable que depuis le réseau Compose. Attention, Docker contourne `ufw` pour les ports publiés (3000, 3001, 9090) ; pour restreindre, publier sur `127.0.0.1` et passer par un tunnel SSH.
- Accès de la famille : Tailscale (dans le périmètre depuis le 2026-10-04, ticket #7). HTTPS (exigé par les navigateurs pour le micro) : `tailscale serve`, hors périmètre de la phase 0.
- `ENABLE_ADMIN_CHAT_ACCESS=False` : l'admin ne lit pas les conversations de la famille.
- Grafana : mot de passe admin fort dans `.env`, accès LAN uniquement.

## Phase 5 — Monitoring

Détail dans `docs/monitoring.md`. Ordre : exporters et Prometheus, cibles `UP`, dashboards provisionnés, proxy Ollama, alertes.

Prochain chantier, sur le laptop : périmètre complet, voir la section « Profil `laptop` » de `docs/monitoring.md`.

## Phase 6 — Exploitation

- Sauvegarde hebdomadaire du volume `open-webui` (cron), et avant chaque mise à jour. Tester une restauration.
- Mises à jour : versions épinglées dans les compose, puis `docker compose pull && docker compose up -d`.
- Test de redémarrage : tout doit revenir sans intervention.

## Phase 7 — Options

- Recherche web pour la famille (sans elle, le modèle ignore l'actualité) : moteur DDGS sans clé dans l'image `:main`, ou SearXNG auto-hébergé.
- Documents (RAG) : l'image `:main` embarque son moteur d'embeddings ; choisir un modèle multilingue pour le français.
- Fine-tuning (exploration, commencée ; part de la base de `famille` mais vise le futur alias `coder`, l'alias `famille` ne change pas) : entraînement QLoRA de Gemma 4 E4B sur Colab avec Unsloth, notebook `nb/Gemma4_(E4B)-Text.ipynb` du dépôt ENISSAY39/ENISSAY39.
  - Réexporter en Q4_K_M depuis l'adaptateur `lora/`, sans réentraîner : le Q8_0 ne tient pas (la base Q4 fait déjà 6,6 Go pour environ 6,9 Go de VRAM utilisable).
  - GGUF dans `D:\llms`, puis `ollama create gemma4-python -f Modelfile`.
  - Comparaison au terminal (`ollama run <modèle> --verbose`), même `num_ctx` que `famille`, sans toucher aux réglages d'Open WebUI.
  - Un seul modèle chargé à la fois sur le laptop : tests hors des plages horaires de la famille, et pas pendant la semaine de test (#8).
  - Terminé quand : le modèle tourne en Q4_K_M à 100 % GPU ; un tableau base vs fine-tuné sur 10 questions Python (qualité, tokens/s) est consigné ; une décision est écrite (piste pour `coder` ou abandon) ; le healthcheck est vert et l'alias `famille` est inchangé.

## Phase 8 — Migration vers la machine achetée (visée : décembre 2027)

1. Sauvegarder le volume `open-webui`, le restaurer sur la nouvelle machine avec la même `WEBUI_SECRET_KEY` : comptes et historiques conservés.
2. Préparer l'hôte. Sur un DGX Spark : sauter la phase 1 (Docker et runtime NVIDIA déjà présents) et ajouter l'utilisateur au groupe `docker`.
3. `.env` : `PROFILE=<nouveau profil>`. Sur une machine arm64, vérifier que chaque image existe pour cette architecture.
4. `scripts/pull-models.sh` : nouvelles bases, mêmes alias, donc rien à reconfigurer dans Open WebUI.
5. Rejouer la définition de « terminé », panneaux mémoire du monitoring compris.
