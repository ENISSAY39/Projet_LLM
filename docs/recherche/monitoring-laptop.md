# Recherche : stack de monitoring sur le laptop (Docker Desktop WSL2)

Date de vérification : 2026-10-07.

Portée : faisabilité, sur le laptop Windows 11 (Docker Desktop, backend WSL2, Ollama natif), des six conteneurs de monitoring prévus pour la machine cible, avec les tags à épingler. Sources primaires uniquement. Aucun conteneur n'a été lancé : tout ce qui touche au comportement réel sur la machine est classé « à tester ».

Trois niveaux de preuve, signalés partout :

- **Lu** : écrit dans la source citée (README, code, doc, registre).
- **Déduit** : conclusion tirée de sources lues, pas écrite telle quelle.
- **À tester** : aucune source ne tranche.

## Synthèse

| Composant | Verdict sur Docker Desktop WSL2 | Image:tag à épingler | arm64 | Réserve principale |
|---|---|---|---|---|
| prometheus | fonctionne (rien de spécifique à l'hôte) | `prom/prometheus:v3.15.0` (dernière) ou `prom/prometheus:v3.13.4` (LTS) | oui | Deux branches vivantes : choisir entre dernière et LTS |
| grafana | fonctionne (rien de spécifique à l'hôte) | `grafana/grafana:13.2.3` | oui | Aucune |
| node-exporter | fonctionne avec réserves | `prom/node-exporter:v1.12.1` | oui | Décrit la VM WSL2 ; pas de hwmon ; montage `rslave` de `/` à tester ; bug ouvert sur `node_filesystem_readonly` en 1.12.x |
| cadvisor | non déterminé (probable avec réserves) | `ghcr.io/google/cadvisor:v0.60.6` | oui | Le Docker du laptop utilise le magasin containerd (`overlayfs`) : cAdvisor exige alors un socket containerd, dont le chemin sous Docker Desktop n'est documenté nulle part |
| gpu-exporter | non déterminé (probable) | `utkuozdemir/nvidia_gpu_exporter:1.15.1` | oui | Le mainteneur ne supporte pas le cas conteneur sous WSL2 ; requêtes nvidia-smi incomplètes sous WSL2 ; repli Windows natif documenté |
| ollama-metrics | fonctionne avec réserves | `ghcr.io/norskhelsenett/ollama-metrics@sha256:3dd32882666cf0e77272086446b5639c636fb090ac9ea629c11874200c629164` (aucun tag de version) | oui | Projet à l'arrêt depuis mai 2025, image figée, pas de release ; routes `/v1/...` ni instrumentées ni relayées au fil de l'eau |

## Faits relevés sur la machine (lecture seule)

Relevés le 2026-10-07 avec `docker version`, `docker info` et un `ls` dans la distribution WSL `docker-desktop`. Rien n'a été modifié.

- Docker Engine 29.7.2, API 1.55 (minimum 1.40), `linux/amd64`, système « Docker Desktop », noyau `6.6.87.2-microsoft-standard-WSL2`.
- Pilote de stockage `overlayfs`, `driver-type: io.containerd.snapshotter.v1` : le magasin d'images containerd est actif.
- cgroup v2, pilote `cgroupfs`.
- Runtimes déclarés : `io.containerd.runc.v2`, `nvidia`, `runc` ; runtime par défaut `runc`.
- La VM voit 20 CPU et 16,6 Go de RAM (et non les 32 Go de Windows).
- Dans la distribution `docker-desktop` : `/usr/lib/wsl/lib/nvidia-smi` et `libnvidia-ml.so.1` présents ; `/sys/class/hwmon` vide ; ni `/run/docker.sock` ni `/run/containerd/` visibles. Ce dernier point ne prouve rien sur ce que voit le démon Docker, qui tourne dans un autre espace de noms : il montre seulement qu'on ne peut pas trancher par un `ls`.

## 1. cAdvisor

Verdict : **non déterminé**, probable avec réserves.

### Registre et tag

- **Lu** : l'image officielle est `ghcr.io/google/cadvisor` ; `gcr.io/cadvisor/cadvisor` ne vaut que pour les versions antérieures à v0.53.0. [README v0.60.6](https://github.com/google/cadvisor/blob/v0.60.6/README.md)
- **Lu (registre)** : `gcr.io/cadvisor/cadvisor:v0.60.6` n'existe pas (`not found`) ; `ghcr.io/google/cadvisor:v0.60.6` et `:0.60.6` existent et pointent sur le même digest.
- **Lu** : le schéma de tag a varié (avec ou sans `v`) autour de 0.54. [issue #3793](https://github.com/google/cadvisor/issues/3793)

### Montages et options selon le README

**Lu** dans le [README v0.60.6](https://github.com/google/cadvisor/blob/v0.60.6/README.md) :

```text
--volume=/:/rootfs:ro
--volume=/var/run:/var/run:ro
--volume=/sys:/sys:ro
--volume=/var/lib/docker/:/var/lib/docker:ro
--volume=/dev/disk/:/dev/disk:ro
--privileged
--device=/dev/kmsg
```

**Lu** dans [docs/running.md](https://github.com/google/cadvisor/blob/v0.60.6/docs/running.md) : sans `/:/rootfs:ro`, cAdvisor « se dégrade proprement » en abandonnant les statistiques qui dépendent de la racine ; `--pid=host` et `--privileged` ne sont exigés que pour les métriques `process`.

**Lu** dans [docs/runtime_options.md](https://github.com/google/cadvisor/blob/v0.60.6/docs/runtime_options.md) : les flags `--docker_only`, `--housekeeping_interval` (défaut 1 s), `--store_container_labels`, `--whitelisted_container_labels`, `--disable_metrics` existent. Valeur `disk` admise pour `--disable_metrics`.

### cgroup v2

- **Lu** : cAdvisor gère cgroup v2 ; les versions 0.57.0 et 0.60.0 ajoutent des métriques `memory.events` et `memory.stat` propres à cgroup v2. [release v0.57.0](https://github.com/google/cadvisor/releases/tag/v0.57.0), [release v0.60.0](https://github.com/google/cadvisor/releases/tag/v0.60.0)
- **Lu** : le lecteur `cpuload` par netlink est sauté sous cgroup v2 depuis 0.60.1. [release v0.60.1](https://github.com/google/cadvisor/releases/tag/v0.60.1)

### Problèmes connus sur Docker Desktop / WSL2

| Problème | Source | État |
|---|---|---|
| `failed to identify the read-write layer ID ... mount-id: no such file or directory` sur WSL2 + Docker Desktop : conteneurs non reconnus | [#2648](https://github.com/google/cadvisor/issues/2648) | Fermé sans correctif explicite ; contournement donné par le mainteneur : `--disable_metrics` sur le disque |
| Magasin d'images containerd : sous-conteneurs Docker absents | [#3459](https://github.com/google/cadvisor/issues/3459), [#3643](https://github.com/google/cadvisor/issues/3643) | Corrigé en v0.54.0 par [PR #3709](https://github.com/google/cadvisor/pull/3709) |
| Docker Desktop/WSL2 : `client version 1.41 is too old. Minimum supported API version is 1.44`, étiquettes et noms absents | [#3793](https://github.com/google/cadvisor/issues/3793) | Cause : vieille image `gcr.io` (v0.49.1). Résolu en passant à `ghcr.io/google/cadvisor` ; côté Docker, l'API 1.40 est de nouveau acceptée à partir de 29.3.0 |
| `unable to create containerd client: ... /run/containerd/containerd.sock: no such file or directory` : l'usine Docker ne s'enregistre pas | [#3772](https://github.com/google/cadvisor/issues/3772) | Ouvert. Corrigé en v0.56.0 pour les Docker **sans** magasin containerd ([PR #3796](https://github.com/google/cadvisor/pull/3796)) ; reste vrai avec le magasin containerd |
| Docker 29.x avec `overlayfs` : pas de métriques par conteneur | [#3860](https://github.com/google/cadvisor/issues/3860) | Ouvert, rapporté sur v0.49 à v0.53. Contournements cités : `--disable_metrics=disk`, ou passage à v0.54.0 |
| Docker < 25.0 non supporté à partir de v0.56.0 | [release v0.56.0](https://github.com/google/cadvisor/releases/tag/v0.56.0) | Sans objet ici (29.7.2) |

### Le point dur : le socket containerd

**Lu dans le code** ([container/docker/factory.go v0.60.6](https://github.com/google/cadvisor/blob/v0.60.6/container/docker/factory.go), [lib/container/containerd/factory.go](https://github.com/google/cadvisor/blob/v0.60.6/lib/container/containerd/factory.go)) :

- Si `docker info` annonce le pilote `overlayfs`, cAdvisor ouvre un client containerd sur la valeur du flag `--containerd` (défaut `/run/containerd/containerd.sock`), espace de noms `moby`.
- Si cette connexion échoue, l'enregistrement de l'usine Docker échoue en entier (`unable to create containerd client`). Ce test n'est pas conditionné par `--disable_metrics=disk`.
- Chaque conteneur est ensuite chargé par `containerdClient.LoadContainer` pour lire le chemin de son rootfs ([handler.go](https://github.com/google/cadvisor/blob/v0.60.6/container/docker/handler.go)).

**Déduit** : le laptop est exactement dans ce cas (pilote `overlayfs`, relevé ci-dessus). Sans socket containerd joignable dans le conteneur cAdvisor, il n'y aura ni noms de conteneurs ni étiquettes Compose, seulement des cgroups bruts. Le README ne monte que `/var/run` ; le défaut du flag vise `/run`.

**À tester** : où se trouve le socket containerd du point de vue du démon Docker Desktop, et s'il peut être monté. Aucune source primaire ne le dit. L'issue [docker/for-win #14676](https://github.com/docker/for-win/issues/14676) (« How to make Docker Desktop working with cadvisor? ») est ouverte, sans réponse.

### Configuration Compose minimale

Montages et options **lus** dans le README ; assemblage en Compose et ligne containerd **déduits**, **à tester**.

```yaml
services:
  cadvisor:
    image: ghcr.io/google/cadvisor:v0.60.6
    restart: unless-stopped
    privileged: true
    devices:
      - /dev/kmsg
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    command:
      - --docker_only=true
      - --housekeeping_interval=15s
```

Si le journal affiche `unable to create containerd client`, deux pistes à essayer dans l'ordre : `--containerd=/var/run/containerd/containerd.sock` (le socket est peut-être déjà sous le `/var/run` monté), puis un montage explicite `/run/containerd/containerd.sock:/run/containerd/containerd.sock:ro`. Si le journal affiche `failed to identify the read-write layer ID`, ajouter `--disable_metrics=disk` aux valeurs désactivées par défaut.

Le port interne de cAdvisor est 8080, comme le défaut d'`ollama-metrics` : pas de conflit à l'intérieur du réseau Compose, conflit seulement si les deux sont publiés sur l'hôte.

## 2. nvidia_gpu_exporter

Verdict : **non déterminé**, probable. Repli Windows natif documenté.

### Ce que prévoit l'exporter

**Lu** dans [docs/INSTALL.md v1.15.1](https://github.com/utkuozdemir/nvidia_gpu_exporter/blob/v1.15.1/docs/INSTALL.md) :

- L'image n'embarque aucun composant NVIDIA. C'est le NVIDIA Container Toolkit qui injecte au démarrage les périphériques, les bibliothèques et le binaire `nvidia-smi`.
- Commande de référence : `docker run --gpus all -e NVIDIA_DRIVER_CAPABILITIES=utility -p 9835:9835 utkuozdemir/nvidia_gpu_exporter:<tag>`.
- Compose de référence :

```yaml
services:
  nvidia_gpu_exporter:
    image: utkuozdemir/nvidia_gpu_exporter:1.15.1
    restart: unless-stopped
    environment:
      - NVIDIA_DRIVER_CAPABILITIES=utility
    ports:
      - "9835:9835"
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
```

- Variante si la réservation de périphérique n'est pas acceptée : `runtime: nvidia` plus `NVIDIA_VISIBLE_DEVICES=all`.
- Les variables `NVIDIA_*` ne sélectionnent pas le runtime. Sans `--gpus`, réservation ou `runtime: nvidia`, l'exporter démarre mais n'expose que ses métriques de santé, avec `nvidia_smi_last_collect_success 0`.
- L'image est distroless, sans shell. `docker exec <conteneur> nvidia-smi` reste possible pour vérifier l'injection.
- Le conteneur tourne en uid 65534.
- Sans toolkit : montage manuel de chaque `/dev/nvidia*`, du binaire `nvidia-smi` et des `libnvidia-ml.so*` dans `/usr/lib/x86_64-linux-gnu`. Qualifié de « fragile » par le README. Aucune mention de `/usr/lib/wsl/...`.
- Les processus : un conteneur ne voit que les siens, sauf avec `--pid=host`. [docs/CONFIGURE.md](https://github.com/utkuozdemir/nvidia_gpu_exporter/blob/v1.15.1/docs/CONFIGURE.md)

**Lu** : le mainteneur a fermé l'issue [#125 « getting this working on wsl2 »](https://github.com/utkuozdemir/nvidia_gpu_exporter/issues/125) en écrivant que le passage du GPU dans un conteneur sous WSL2 est une configuration de niche qu'il ne compte pas traiter. Le README prévient aussi que le projet est entretenu sur du temps libre.

### Ce que dit Docker

**Lu** dans [GPU support in Docker Desktop for Windows](https://docs.docker.com/desktop/features/gpu/) :

- Docker Desktop pour Windows prend en charge la paravirtualisation GPU (GPU-PV) NVIDIA, par `--gpus`, uniquement avec le backend WSL 2.
- Prérequis : GPU NVIDIA, Windows 10 ou 11 à jour, pilotes NVIDIA à jour supportant GPU-PV, noyau WSL 2 à jour (`wsl --update`), backend WSL 2 activé.
- Commande de validation : `docker run --rm -it --gpus=all nvcr.io/nvidia/k8s/cuda-sample:nbody nbody -gpu -benchmark`.
- La page ne parle ni de Compose, ni de `nvidia-smi`, ni d'édition de Windows (Home ou Pro).

**Lu** dans [Run Docker Compose services with GPU access](https://docs.docker.com/compose/how-tos/gpu-support/) : la syntaxe `deploy.resources.reservations.devices` avec `driver: nvidia` et `capabilities: [gpu]` (champ obligatoire) ; l'exemple lance `nvidia-smi` dans une image `nvidia/cuda`. La page ne dit pas qu'elle vaut pour Docker Desktop.

**Déduit** : le runtime `nvidia` est déclaré dans le Docker du laptop et `nvidia-smi` existe dans `/usr/lib/wsl/lib` de la VM (relevés ci-dessus). L'injection de `nvidia-smi` dans un conteneur distroless est donc plausible, mais aucune source ne l'affirme pour Docker Desktop.

### Ce que dit NVIDIA sur WSL2

**Lu** dans le [CUDA on WSL User Guide](https://docs.nvidia.com/cuda/wsl-user-guide/index.html), tableau « Features Not Yet Supported », citation exacte :

> NVML (nvidia-smi) does not support all the queries yet. GPU utilization, active compute process are some queries that are not yet supported. Modifiable state features (ECC, Compute mode, Persistence mode) will not be supported.

Et dans « Known Limitations » :

> Root user on bare metal (not containers) will not find nvidia-smi at the expected location. Use /usr/lib/wsl/lib/nvidia-smi or manually add /usr/lib/wsl/lib/ to the PATH).

> With the NVIDIA Container Toolkit for Docker 19.03, only --gpus all is supported.

Ce que la source dit, et rien de plus :

- Non supportées, nommément : l'utilisation GPU et les processus de calcul actifs.
- Température, puissance, ventilateur : **la source n'en dit rien**. À tester.
- La page ne porte pas de date de révision relevée ici ; la mention de l'utilisation GPU peut être périmée. À tester.

**Lu** dans [docs/METRICS.md](https://github.com/utkuozdemir/nvidia_gpu_exporter/blob/v1.15.1/docs/METRICS.md) : un champ indisponible (`N/A`, `[Not Supported]`) n'est pas exporté. **Déduit** : les panneaux correspondants du dashboard 14574 resteront vides, sans erreur.

### Repli : installation Windows native

**Lu** dans [docs/INSTALL.md, section Windows](https://github.com/utkuozdemir/nvidia_gpu_exporter/blob/v1.15.1/docs/INSTALL.md#windows) :

- Seul un build x86_64 existe pour Windows.
- winget : `winget install --scope machine utkuozdemir.nvidia_gpu_exporter`.
- Scoop : `scoop bucket add nvidia_gpu_exporter https://github.com/utkuozdemir/scoop_nvidia_gpu_exporter.git` puis `scoop install nvidia_gpu_exporter/nvidia_gpu_exporter --global`.
- Service Windows : l'exporter s'enregistre lui-même avec sa commande `install`, sans NSSM ; démarrage automatique au boot ; journaux dans l'Observateur d'événements.
- Un script « tout-en-un » existe aussi ; il installe Prometheus et Grafana en plus, donc hors sujet ici.
- Sous Windows en mode WDDM, pas de mémoire par processus (`used_memory_bytes` absent). [docs/CONFIGURE.md](https://github.com/utkuozdemir/nvidia_gpu_exporter/blob/v1.15.1/docs/CONFIGURE.md)

**Déduit** : avec ce repli, Prometheus scruterait `host.docker.internal:9835`. Les noms de métriques `nvidia_smi_*` restent les mêmes, donc le dashboard ne change pas, mais ce morceau ne serait plus identique à la machine cible.

## 3. ollama-metrics

Verdict : **fonctionne avec réserves** pour l'usage du projet (Open WebUI vers `/api/chat`).

Code lu : [`main.go`](https://github.com/NorskHelsenett/ollama-metrics/blob/dcc600c648ac2d87b2ebdd03c84a314ffee92fa3/main.go) au commit `dcc600c` (tête de `main`). Tout le programme tient dans ce fichier.

### Configuration

**Lu dans le code et le [README](https://github.com/NorskHelsenett/ollama-metrics/blob/main/README.md)** :

| Réglage | Nom exact | Défaut |
|---|---|---|
| URL d'Ollama en amont | variable d'environnement `OLLAMA_HOST` | `http://localhost:11434` |
| Port d'écoute | variable d'environnement `PORT` | `8080` |
| Chemin des métriques | `/metrics`, en dur | sans objet |

Aucun flag de ligne de commande. L'URL amont est concaténée telle quelle au chemin de la requête : **déduit**, `OLLAMA_HOST=http://host.docker.internal:11434` convient, sans barre oblique finale. `host.docker.internal` est déjà la voie utilisée par Open WebUI dans ce dépôt.

Attention au nom : `OLLAMA_HOST` est aussi une variable d'Ollama lui-même, avec un autre sens. Ici elle ne se pose que sur le conteneur `ollama-metrics`.

### Streaming

**Lu dans le code** :

- `/api/generate` et `/api/chat` : lecture par blocs de 1024 octets, écriture au client et `Flush()` après chaque bloc. Le NDJSON est relayé au fil de l'eau. La réponse entière est aussi gardée en mémoire pour être analysée à la fin.
- `/api/ps` : lu en entier puis renvoyé.
- Toutes les autres routes, dont `/v1/...`, `/api/pull`, `/api/tags` : `io.Copy` sans `Flush()`.

**Déduit** : le SSE des routes `/v1/chat/completions` n'est pas relayé au fil de l'eau ; le client reçoit par paquets ou à la fin. Confirmé par la description de la [PR #5](https://github.com/NorskHelsenett/ollama-metrics/pull/5), ouverte depuis avril 2026 et non fusionnée (« causes clients to hang on streamed responses »). La progression de `/api/pull` est touchée de la même façon.

**Lu** : Open WebUI v0.11.4 appelle `{url}/api/chat` pour ses connexions Ollama. [routers/ollama.py](https://github.com/open-webui/open-webui/blob/v0.11.4/backend/open_webui/routers/ollama.py) Le chemin utilisé par le projet est donc le chemin correctement relayé.

Délais : **lu**, le client HTTP amont a `Timeout: 0` (aucun délai global) et le serveur n'en fixe aucun.

### Routes instrumentées

**Lu dans le code** :

- Jetons (`prompt_eval_count`, `eval_count`, `eval_duration` de la ligne `done: true`) : seulement `/api/generate` et `/api/chat`.
- Modèles chargés : `/api/ps`, relu en amont à chaque appel de `/metrics`.
- Durée : toute route dont la requête ou la réponse porte un champ `model`.
- `/v1/...` : aucun comptage de jetons. Trois PR ouvertes le proposent ([#3](https://github.com/NorskHelsenett/ollama-metrics/pull/3), [#5](https://github.com/NorskHelsenett/ollama-metrics/pull/5), [#9](https://github.com/NorskHelsenett/ollama-metrics/pull/9)), aucune fusionnée.

### Métriques exposées

Liste exacte, **lue dans le code** :

| Nom | Type | Étiquettes |
|---|---|---|
| `ollama_prompt_tokens_total` | counter | `model` |
| `ollama_generated_tokens_total` | counter | `model` |
| `ollama_request_duration_seconds` | histogram (0,1 à 60 s) | `endpoint`, `model` |
| `ollama_time_per_token_seconds` | histogram (0,01 à 2 s) | `model` |
| `ollama_loaded_models` | gauge | aucune |
| `ollama_model_loaded` | gauge | `model` |
| `ollama_model_ram_mb` | gauge | `model` |

S'y ajoutent les métriques standard `go_*`, `process_*` et `promhttp_*` du client Prometheus.

Détails utiles, **lus** :

- Un nom de modèle sans tag reçoit `:latest` : l'alias `famille` apparaîtra comme `famille:latest`.
- `ollama_model_ram_mb` vient du champ `size` de `/api/ps`, pas de `size_vram`.
- Le plus grand seau de durée est 60 s : un chargement à froid long tombe dans `+Inf`.
- Les compteurs n'existent qu'après une première requête passée par le proxy. [issue #1](https://github.com/NorskHelsenett/ollama-metrics/issues/1)

### Dashboard Grafana

**Lu** : [`prometheus/dashboard.json`](https://github.com/NorskHelsenett/ollama-metrics/blob/main/prometheus/dashboard.json), titre « Ollama Metrics Dashboard », `schemaVersion` 40. La source de données y est référencée en dur par l'uid `prometheus`.

**Déduit** : la source de données provisionnée doit porter l'uid `prometheus`, sinon le dashboard reste vide. C'est une explication possible de l'[issue #10 « Dashboard empty »](https://github.com/NorskHelsenett/ollama-metrics/issues/10), ouverte et sans réponse.

### Images, releases, activité

**Lu (registre, API GitHub)** :

- Registre : `ghcr.io/norskhelsenett/ollama-metrics`.
- Tags trouvés : `latest`, `main`, `nightly`, tous sur le même digest. Aucun tag de version.
- Architectures : `linux/amd64` et `linux/arm64`.
- Image construite le 2025-05-08, à partir du commit `02911ce`. La tête de `main` n'en diffère que par le Dockerfile, le README et une image : le `main.go` lu ici est celui de l'image publiée.
- Aucune release GitHub, aucun tag git.
- Dernier commit sur `main` : 2025-05-08. Dernier push sur le dépôt : 2025-06-24.
- Le workflow « Docker CI » est en état `disabled_inactivity` depuis août 2025 : plus aucune image n'est reconstruite.
- 42 étoiles, 4 PR ouvertes sans réponse, 2 issues ouvertes sans réponse. L'API GitHub ne détecte aucune licence, alors que le README annonce MIT.

### Risques

- **Projet à l'arrêt.** Pas de correctif à attendre ; les PR utiles ne sont pas fusionnées.
- **Image non reconstructible depuis `main`.** Le Dockerfile de `main` compile vers `ollama-metrics` mais copie `/app/main` : **déduit**, la construction échoue. Deux PR le corrigent ([#2](https://github.com/NorskHelsenett/ollama-metrics/pull/2), [#5](https://github.com/NorskHelsenett/ollama-metrics/pull/5)).
- **Épinglage par digest obligatoire.** Les seuls tags sont flottants.
- **Dépendances figées à mai 2025** (Go 1.23, `client_golang` v1.22.0). Acceptable derrière Tailscale, sans exposition.
- **Point de passage unique.** Le proxy est sur le chemin de toutes les conversations : s'il tombe, Open WebUI perd Ollama.
- **arm64** : pas de risque, l'image existe.

## 4. Tags à épingler

Preuve : `docker buildx imagetools inspect <image>:<tag>` exécuté le 2026-10-07 (lecture seule), et `gh release list`. Le digest donné est celui de l'index multi-architecture.

| Image | Tag | Date de release | amd64 | arm64 | Digest de l'index |
|---|---|---|---|---|---|
| `prom/prometheus` | `v3.15.0` | 2026-09-25 | oui | oui | `sha256:efd719c99d83b060d9daefdcf00360461adf279f45ef5391f8d111892118753e` |
| `prom/prometheus` (LTS) | `v3.13.4` | 2026-10-02 | oui | oui | `sha256:87861b8cf91579109319ebc300f3f1060e6da9c05d6ae8ad15a20c879e84e32e` |
| `grafana/grafana` | `13.2.3` | 2026-09-29 | oui | oui | `sha256:b28bae15e219c998fb0e0424ed724930cc61b1f61fb404d47c862f9a23f9e572` |
| `prom/node-exporter` | `v1.12.1` | 2026-07-14 | oui | oui | `sha256:1b4e4438faca4dd7e001dd445d161a4a2091b0fededa84093b3a8dfeae1f1be0` |
| `ghcr.io/google/cadvisor` | `v0.60.6` | 2026-09-18 | oui | oui | `sha256:b8e7d1093144fd088f425ff003d75a4aa405de075db78dae3bc563730b1bd07a` |
| `utkuozdemir/nvidia_gpu_exporter` | `1.15.1` | 2026-09-02 | oui | oui | `sha256:7aee2d42836ad29d4adb2722b7cfdc806ec9cc8d45fd0b8971ebbad2d9f3d087` |
| `ghcr.io/norskhelsenett/ollama-metrics` | `latest` (flottant) | aucune release ; image du 2025-05-08 | oui | oui | `sha256:3dd32882666cf0e77272086446b5639c636fb090ac9ea629c11874200c629164` |

Remarques :

- **Prometheus** : `v3.15.0` est marquée « Latest » sur GitHub. La série 3.13 est la LTS en cours, supportée jusqu'au 2027-07-31. [Long-Term Support](https://prometheus.io/docs/introduction/release-cycle/) Le choix entre les deux n'est pas fait ici.
- **Miroirs vérifiés, mêmes digests** : `quay.io/prometheus/prometheus:v3.15.0`, `quay.io/prometheus/node-exporter:v1.12.1`, `ghcr.io/utkuozdemir/nvidia_gpu_exporter:1.15.1`.
- **nvidia_gpu_exporter** : le tag d'image n'a pas de `v` (`1.15.1`), la release GitHub en a un (`v1.15.1`). Des tags `-nvml` existent pour un backend expérimental ; non examinés.
- **cAdvisor** : le tag `0.60.6` sans `v` existe aussi, même digest.
- **ollama-metrics** : écrire `ghcr.io/norskhelsenett/ollama-metrics@sha256:3dd3...9164` dans le Compose.

## 5. node-exporter

Verdict : **fonctionne avec réserves**.

**Lu** dans le [README v1.12.1](https://github.com/prometheus/node_exporter/blob/v1.12.1/README.md) :

- node_exporter est conçu pour surveiller l'hôte ; en conteneur, il faut des options supplémentaires pour ne pas surveiller le conteneur lui-même.
- Configuration de référence : `--net="host"`, `--pid="host"`, `-v "/:/host:ro,rslave"`, argument `--path.rootfs=/host`. La valeur de `--path.rootfs` doit correspondre au point de montage de la racine.
- Tout point de montage hors racine à surveiller doit être monté dans le conteneur.
- Le README recommande `windows_exporter` aux utilisateurs Windows. Sans objet : le choix de décrire la VM est déjà fait.

Ce qu'il verra, **déduit** des relevés machine : la VM utilitaire de Docker Desktop, soit 20 CPU, 16,6 Go de RAM, le disque virtuel ext4 de la VM, le noyau `microsoft-standard-WSL2`. Pas le disque `C:` ni `D:` en tant que tels, pas la RAM de Windows.

Réserves :

- **Températures** : `/sys/class/hwmon` est vide dans la distribution `docker-desktop` (relevé sur la machine). **Déduit** : pas de `node_hwmon_*`, donc pas de température ni de ventilateur dans le dashboard 1860. `/sys/class/thermal` contient des `cooling_device*` ; la présence de `thermal_zone*` n'a pas été relevée.
- **Montage `rslave` de `/`** : **à tester**. Aucune source primaire actuelle ne dit s'il est accepté par Docker Desktop WSL2. Seul indice, ancien : [docker/for-win #4256](https://github.com/docker/for-win/issues/4256) (« Bind propagation shared/slave not working », fermée en 2020). En cas de refus (`path / is mounted on / but it is not a shared or slave mount`), retirer `rslave` et garder `/:/host:ro`.
- **`network_mode: host`** : sous Docker Desktop, le réseau hôte est une fonction à activer dans les réglages, depuis la version 4.34, et elle demande d'être connecté à un compte Docker ; elle opère en couche 4. [Host network driver](https://docs.docker.com/engine/network/drivers/host/) **Déduit** : mieux vaut s'en passer sur le laptop et laisser node-exporter sur le réseau Compose. Conséquence : les métriques réseau décrivent l'espace de noms du conteneur, pas la VM.
- **Métriques faussées par le contexte Docker Desktop** : l'issue [#3479 « Wrong host metrics »](https://github.com/prometheus/node_exporter/issues/3479) a été résolue par son auteur en quittant Docker Desktop pour Docker CE. Cohérent avec le choix accepté.
- **Bug ouvert en 1.12.0 et 1.12.1** : `node_filesystem_readonly` signale à tort des systèmes de fichiers en lecture seule, dans une configuration Compose avec `--path.rootfs=/host`. [#3755](https://github.com/prometheus/node_exporter/issues/3755) Ne pas bâtir d'alerte sur cette métrique tant que l'issue est ouverte.

Configuration de départ, **déduite** du README et des réserves ci-dessus, **à tester** :

```yaml
services:
  node-exporter:
    image: prom/node-exporter:v1.12.1
    restart: unless-stopped
    pid: host
    command:
      - --path.rootfs=/host
    volumes:
      - /:/host:ro,rslave
```

## 6. Dashboards Grafana

Vérifiés par l'API `https://grafana.com/api/dashboards/<id>` le 2026-10-07.

| ID | Nom | Auteur | Dernière révision | Écrit pour |
|---|---|---|---|---|
| [1860](https://grafana.com/grafana/dashboards/1860) | Node Exporter Full | rfmoz | 45, du 2026-04-11 | node_exporter (d'après le nom ; la description est vide dans l'API) |
| [14574](https://grafana.com/grafana/dashboards/14574) | Nvidia GPU Metrics | utkuozdemir | 15, du 2026-08-04 | `utkuozdemir/nvidia_gpu_exporter` : la description le dit, et le README de l'exporter le désigne comme dashboard officiel |
| [25547](https://grafana.com/grafana/dashboards/25547) | Nvidia GPU Overview | utkuozdemir | 3, du 2026-08-04 | Compagnon du 14574, comparaison de plusieurs GPU ; peu utile avec un seul GPU |
| [19792](https://grafana.com/grafana/dashboards/19792) | cadvisor dashboard | simonmysun | 6, du 2024-11-24 | cAdvisor ; filtre par projet Compose |
| [14282](https://grafana.com/grafana/dashboards/14282) | Cadvisor exporter | kokorinav | 1, du 2021-04-21 | cAdvisor ; plus simple, plus ancien |

Le JSON des dashboards 14574 et 25547 est aussi dans le dépôt de l'exporter, sous [`docs/grafana`](https://github.com/utkuozdemir/nvidia_gpu_exporter/tree/v1.15.1/docs/grafana).

Proposition pour cAdvisor : **19792**. Réserves **lues dans le JSON téléchargé** :

- 19792 s'appuie massivement sur l'étiquette `container_label_com_docker_compose_project` et sur `container_name`. Il exige donc que cAdvisor garde les étiquettes des conteneurs : ne pas mettre `--store_container_labels=false` sans `--whitelisted_container_labels`.
- 14282 filtre surtout sur `name=~` et fonctionne avec moins d'étiquettes ; à garder en repli.
- 14574 révision 15 interroge aussi `nvidia_smi_energy_joules_total` et `nvidia_smi_mig_info`, que [METRICS.md](https://github.com/utkuozdemir/nvidia_gpu_exporter/blob/v1.15.1/docs/METRICS.md) réserve au backend NVML : **déduit**, ces panneaux resteront vides avec le backend par défaut.

## 7. Alertes Grafana vers Discord

**Lu** dans la doc de provisioning par fichier de Grafana 13.2 ([File provisioning](https://grafana.com/docs/grafana/latest/alerting/set-up/provision-alerting-resources/file-provisioning/), source : [index.md à v13.2.3](https://github.com/grafana/grafana/blob/v13.2.3/docs/sources/alerting/set-up/provision-alerting-resources/file-provisioning/index.md)) :

- Type exact du receiver : `discord`.
- Champs de `settings` documentés : `url` (chaîne, obligatoire), `avatar_url` (chaîne), `use_discord_username` (booléen), `message` (chaîne).
- Fichier à déposer dans `provisioning/alerting`, avec `apiVersion: 1` et une liste `contactPoints` ; chaque receiver a `uid` (40 caractères au plus, lettres, chiffres, `-`, `_`), `type`, `settings`, et `disableResolveMessage` en option.

**Lu dans le code** du receiver ([grafana/alerting, receivers/discord/v1/config.go](https://github.com/grafana/alerting/blob/main/receivers/discord/v1/config.go)) : deux champs de plus, `title` et `use_embed_description` ; `url` est obligatoire (« could not find webhook url property in settings »).

Interpolation, **lue** dans la même page et dans [Provision Grafana, « Use environment variables »](https://grafana.com/docs/grafana/latest/administration/provisioning/#use-environment-variables) :

- Syntaxe : `$NOM` ou `${NOM}`.
- Une variable absente est remplacée par une chaîne vide.
- Réservée aux valeurs, pas aux clés.
- Pour un `$` littéral, écrire `$$`. Cela concerne les gabarits : `{{ $labels }}` doit s'écrire `{{ $$labels }}` dans un champ interpolé.
- Non interpolés dans les ressources d'alerte : annotations, plage de temps et modèle de requête des règles, noms et intervalles des mute timings, nom et contenu des groupes de gabarits.

Exemple, assemblé à partir de ces éléments (**déduit**) ; `DISCORD_WEBHOOK_URL` est un nom choisi pour ce projet, pas une variable de Grafana :

```yaml
apiVersion: 1
contactPoints:
  - orgId: 1
    name: discord
    receivers:
      - uid: discord_famille
        type: discord
        settings:
          url: ${DISCORD_WEBHOOK_URL}
          use_discord_username: false
```

La variable doit exister dans l'environnement du conteneur Grafana (`environment:` du Compose, valeur dans `.env`). Si elle est vide, `url` devient vide et le receiver est rejeté.

## À tester sur la machine

Ce que les sources ne tranchent pas, par ordre de risque :

1. **cAdvisor et le socket containerd.** Avec le pilote `overlayfs` du laptop, cAdvisor v0.60.6 enregistre-t-il l'usine Docker ? Lire son journal : `Registration of the docker container factory` suivi de `successfully` ou de `unable to create containerd client`. Puis vérifier que `container_cpu_usage_seconds_total` porte une étiquette `name` non vide.
2. **cAdvisor et le disque.** Les métriques `container_fs_*` remontent-elles, ou faut-il `--disable_metrics=disk` ?
3. **gpu-exporter en conteneur.** `nvidia-smi` est-il injecté dans l'image distroless par la réservation de périphérique Compose ? Contrôle : `nvidia_smi_last_collect_success 1` sur `:9835/metrics`, et `docker exec <conteneur> nvidia-smi`.
4. **Champs nvidia-smi réellement disponibles sous WSL2.** Utilisation GPU, température, puissance, ventilateur, mémoire, processus : noter lesquels sont exportés. Comparer avec `nvidia-smi.exe` côté Windows.
5. **ollama-metrics sur le chemin d'Open WebUI.** Le streaming d'une réponse reste-t-il fluide, et `ollama_generated_tokens_total{model="famille:latest"}` augmente-t-il après une question ? Vérifier aussi qu'un chargement à froid de 20 à 31 s ne casse rien.
6. **Refaire `scripts/laptop/healthcheck.ps1`** une fois Open WebUI branché sur le proxy : le débit ne doit pas bouger.
7. **node-exporter et `rslave`.** Le montage `/:/host:ro,rslave` est-il accepté ? Sinon, le retirer.
8. **node-exporter, capteurs.** Confirmer l'absence de `node_hwmon_*` et voir si `node_thermal_zone_temp` existe.
9. **Dashboard d'ollama-metrics.** S'affiche-t-il avec une source de données d'uid `prometheus` sous Grafana 13.2.3 (`schemaVersion` 40) ?
10. **Dashboard 19792** avec les étiquettes Compose réellement présentes.
11. **Contact point Discord.** Une alerte de test arrive-t-elle, et l'URL est-elle bien lue depuis l'environnement ?
12. **Recréation du conteneur Open WebUI** au moment de changer son URL Ollama : non testée à ce jour (ticket #3), à faire après une sauvegarde.
