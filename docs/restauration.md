# Sauvegarde et restauration du volume Open WebUI

Le volume `llm-maison_open-webui` contient les comptes, les historiques, les réglages et les fichiers téléversés. Hors périmètre ici : la sauvegarde planifiée (phase 6).

## Sauvegarder

```powershell
.\scripts\laptop\backup.ps1            # conteneur actif pendant la copie
.\scripts\laptop\backup.ps1 -Arreter   # coupe Open WebUI ~1 min : base SQLite cohérente (à préférer avant une migration)
```

Résultat : `backups\openwebui-AAAA-MM-JJ-HHMMSS.tar.gz` (≈ 1 Go), sur D:, ignoré par Git. L'archive contient la base des comptes : la traiter comme un secret, ne pas la copier hors du foyer.

## Restaurer sur un volume de test (vérification, sans toucher au volume réel)

```bash
V=llm-maison-restore-test
A=openwebui-AAAA-MM-JJ-HHMMSS.tar.gz
docker volume create $V
docker run --rm -v $V:/data -v "D:\Projet_LLM\backups":/backup:ro alpine tar xzf /backup/$A -C /data
set -a; . ./.env; set +a    # même WEBUI_SECRET_KEY que le réel
docker run -d --name owui-restore-test -p 3010:8080 -v $V:/app/backend/data \
  -e OLLAMA_BASE_URL="$OLLAMA_BASE_URL" -e WEBUI_SECRET_KEY="$WEBUI_SECRET_KEY" \
  ghcr.io/open-webui/open-webui:v0.11.4
```

Ouvrir `http://localhost:3010` et se connecter avec un compte existant. Sous Git Bash, préfixer le second `docker run` de `MSYS_NO_PATHCONV=1` si le chemin `D:\...` est déformé.

Nettoyage, après confirmation, volume par volume : `docker rm -f owui-restore-test` puis `docker volume rm llm-maison-restore-test`. Jamais de `prune` : d'autres projets partagent ce Docker.

## Restaurer pour de bon (panne ou migration vers le futur serveur)

1. Reprendre le même `.env`, **surtout `WEBUI_SECRET_KEY`** : sans elle, les sessions et les secrets chiffrés sont perdus.
2. Créer le volume `llm-maison_open-webui` (ou laisser `docker compose up -d` le créer, puis `docker compose stop open-webui`).
3. Si le volume contient déjà des données à écraser : confirmation explicite avant toute suppression.
4. Extraire l'archive dans le volume, comme ci-dessus, avec `-v llm-maison_open-webui:/data`.
5. `docker compose up -d`, puis `.\scripts\laptop\healthcheck.ps1`.

## Vérification du 2026-10-04

Archive prise après la configuration des comptes, restaurée sur un volume de test : Open WebUI v0.11.4 démarre en bonne santé dessus, et la base contient les mêmes 4 comptes, le groupe `famille`, 2 conversations et 1 fiche modèle que le volume réel.
