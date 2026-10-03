# Fichiers de référence

Point de départ pour générer les fichiers du dépôt. Syntaxe YAML validée, jamais exécutés : à tester.

`docker-compose.yml` :

```yaml
name: llm-maison                              # nom du projet Compose : préfixe des volumes, indépendant du dossier

services:
  ollama:
    image: ollama/ollama:latest                 # épingler une version une fois validée
    restart: unless-stopped
    # aucun port publié : Ollama n'est joignable que depuis le réseau Compose
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

Les Modelfiles `spark` ne changent que `FROM` et `num_ctx` (voir le tableau des profils dans `CLAUDE.md`).
