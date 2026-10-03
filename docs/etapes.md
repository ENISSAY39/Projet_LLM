# Étapes du projet

À lire avant de commencer une phase. Cocher au fur et à mesure.

## Phase 0 — Prototype sur le laptop, avant tout achat

- [x] `scripts/laptop/pull-models.ps1` : base `gemma4:e4b-it-q4_K_M` puis alias `famille`, à 100 % GPU. `scripts/laptop/healthcheck.ps1` le vérifie ; mesures dans les notes `laptop` de `docs/materiel.md`.
- [x] Script d'installation de l'hôte (ticket #4) : `scripts\laptop\hote.ps1 -WhatIf` puis `scripts\laptop\hote.ps1` en administrateur, par Yassine. Annulation : `-Annuler`. Ensuite `scripts\laptop\healthcheck.ps1`.
- [x] Open WebUI en Compose (`docker-compose.yml`, projet `llm-maison`), branché sur l'Ollama déjà installé : `.env` depuis `.env.example` (`OLLAMA_BASE_URL=http://host.docker.internal:11434`, `WEBUI_SECRET_KEY` fixe), puis `docker compose up -d`. `scripts\laptop\healthcheck.ps1` contrôle le port 3000 et la vue de l'alias depuis le conteneur.
- [ ] Créer les 4 comptes et faire tester quelques jours : valide l'usage réel et le français avant de dépenser.

## Phase 1 — Serveur (profil `basique`)

1. Ubuntu Server LTS, IP fixe par réservation DHCP sur la box, SSH par clé.
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
- Hors domicile, et HTTPS (exigé par les navigateurs pour le micro) : Tailscale + `tailscale serve`.
- `ENABLE_ADMIN_CHAT_ACCESS=False` : l'admin ne lit pas les conversations de la famille.
- Grafana : mot de passe admin fort dans `.env`, accès LAN uniquement.

## Phase 5 — Monitoring

Détail dans `docs/monitoring.md`. Ordre : exporters et Prometheus, cibles `UP`, dashboards provisionnés, proxy Ollama, alertes.

## Phase 6 — Exploitation

- Sauvegarde hebdomadaire du volume `open-webui` (cron), et avant chaque mise à jour. Tester une restauration.
- Mises à jour : versions épinglées dans les compose, puis `docker compose pull && docker compose up -d`.
- Test de redémarrage : tout doit revenir sans intervention.

## Phase 7 — Options

- Recherche web pour la famille (sans elle, le modèle ignore l'actualité) : moteur DDGS sans clé dans l'image `:main`, ou SearXNG auto-hébergé.
- Documents (RAG) : l'image `:main` embarque son moteur d'embeddings ; choisir un modèle multilingue pour le français.

## Phase 8 — Migration vers la machine achetée (visée : décembre 2027)

1. Sauvegarder le volume `open-webui`, le restaurer sur la nouvelle machine avec la même `WEBUI_SECRET_KEY` : comptes et historiques conservés.
2. Préparer l'hôte. Sur un DGX Spark : sauter la phase 1 (Docker et runtime NVIDIA déjà présents) et ajouter l'utilisateur au groupe `docker`.
3. `.env` : `PROFILE=<nouveau profil>`. Sur une machine arm64, vérifier que chaque image existe pour cette architecture.
4. `scripts/pull-models.sh` : nouvelles bases, mêmes alias, donc rien à reconfigurer dans Open WebUI.
5. Rejouer la définition de « terminé », panneaux mémoire du monitoring compris.
