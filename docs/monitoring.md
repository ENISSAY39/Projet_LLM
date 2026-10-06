# Monitoring (Prometheus + Grafana)

À lire avant de toucher à `docker-compose.monitoring.yml` ou au dossier `monitoring/`.

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

Canal de notification : Discord, par webhook (URL dans `.env`). Repli : Telegram. Décidé le 2026-10-07.

Profil `laptop` (décidé le 2026-10-07, rien n'est encore écrit ni testé) :

- But : répéter la stack de la machine cible, pas surveiller le laptop. Périmètre complet : les six services, tous les dashboards, toutes les alertes.
- Mêmes exporters Linux que la cible, lancés dans Docker Desktop, pour que les fichiers Compose, les dashboards et les alertes soient ceux de la cible. Conséquence acceptée : les chiffres d'hôte décrivent la VM WSL2 de Docker, pas Windows.
- À vérifier sur les sources de chaque projet avant d'écrire le Compose : `cadvisor` et `gpu-exporter` dans Docker Desktop, `ollama-metrics` devant un Ollama natif (`host.docker.internal:11434`), streaming compris. Un exporter qui ne fonctionne pas est remplacé par son équivalent Windows, lui seul.
- Sans la famille, les chiffres d'usage ne sont que ceux des essais de Yassine.

Spécificités Spark : la mémoire GPU n'est pas rapportée par `nvidia-smi`, les panneaux VRAM restent vides. Suivre la mémoire avec `node-exporter` ; le DGX Dashboard (`https://localhost:11000`) sert de contrôle croisé.

Option : métriques HTTP et traces d'Open WebUI via OpenTelemetry (`ENABLE_OTEL=true`, `ENABLE_OTEL_METRICS=true`, `OTEL_EXPORTER_OTLP_ENDPOINT`) vers un collecteur OTel ; logs dans Loki.
