# Matériel, calendrier d'achat et notes par profil

Photo du marché au 2026-10-03. À relire avant toute décision d'achat ou tout changement de profil.

## Toutes les options

| # | Option | Mémoire | Prix relevé | Modèle de code visé | À retenir |
|---|---|---|---|---|---|
| 0 | Laptop actuel (RTX 4060) | 8 Go VRAM | 0 € | Aucun, `famille` seul | Prototype uniquement, pas un serveur 24/7 |
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

Exigences de contexte pour la machine cible (fixées le 2026-10-03) :

- `coder` : `num_ctx` entre 131072 et 240000. C'est un critère d'achat : une machine qui ne tient pas 131072 est écartée.
- `famille` : `num_ctx` de 30000 au maximum. Sur le laptop, on garde le plus grand contexte qui tient à 100 % GPU.
- La machine se dimensionne sur les bornes hautes : `coder` à 240000 et `famille` à 30000.
- `coder` et `famille` restent chargés en même temps. C'est aussi un critère d'achat : quelqu'un doit pouvoir discuter dans l'interface pendant que Yassine code.

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
3. En déduire la mémoire nécessaire (poids + contexte aux bornes hautes + modèle `famille` chargé en même temps + ~16 Go de marge) et le débit minimal.
4. Comparer les machines du moment sur cinq critères : mémoire (Go), bande passante (Go/s), vitesse de lecture du prompt (tokens/s en entrée, décisive avec un contexte de 131072), prix par Go, besoin de CUDA pour le fine-tuning. Puis bruit et consommation.
5. Créer le profil correspondant dans `profiles/` et `modelfiles/` ; le profil `spark` de `CLAUDE.md` sert de gabarit.

## Notes par profil

Notes `laptop` (prototype de la phase 0, Ollama natif sous Windows) :

- Alias : `famille` seul. Pas de `coder` sur cette machine ; il reste prévu pour le futur serveur.
- Stockage : tous les modèles restent dans `D:\llms`, jamais sur C: ni dans un volume Docker. C'est la variable utilisateur Windows `OLLAMA_MODELS` qui le fixe : la vérifier avant tout téléchargement, et aucun script ne la modifie.
- Règle de repli si `famille` déborde sur le CPU (`scripts/laptop/healthcheck.ps1` échoue sur le contrôle GPU), dans cet ordre : base `gemma4:e4b-it-qat` (6,1 Go), puis `num_ctx` réduit, puis base `gemma4:e2b-it-q4_K_M` (4,6 Go). À chaque étape : revérifier le tag sur ollama.com/library, modifier `modelfiles/laptop/famille.Modelfile`, relancer `scripts/laptop/pull-models.ps1` puis la vérification.
- Mesures du 2026-10-03 (Ollama 0.32.6 ; valeurs retenues dans le tableau des profils de `CLAUDE.md`) : aucun repli. Les 43 couches du modèle tiennent sur le GPU à tous les contextes essayés, de 8192 à 131072 (le maximum du modèle). `num_ctx` 30000 est donc le plafond fixé pour `famille`, pas une limite de VRAM : environ 5 Go occupés à 30000, près de 7 Go à 131072. Débit de 79 à 93 tokens/s. Chargement à froid en 6 s quand les fichiers du modèle sont en cache disque (y compris juste après un redémarrage d'Ollama), 20 à 31 s au premier chargement ou après une longue inactivité (mesuré par le script de vérification, qui affiche ce temps quand le modèle n'était pas chargé). La valeur de `OLLAMA_KEEP_ALIVE` se décide sur le cas de 31 s.
- `OLLAMA_KEEP_ALIVE` retenu : `4h` (ticket #4, 2026-10-03). Le cas de 31 s dépasse le seuil de 10 s du ticket ; 4 h couvrent une journée d'usage fragmentée. Posé par `scripts\laptop\hote.ps1`, contrôlé par `scripts\laptop\healthcheck.ps1`. Reste à remesurer le chargement à froid après un redémarrage de la machine.
- `ollama ps` ne suffit pas sur cette version : il affiche `100% GPU` même quand le moteur ne place que 8 à 10 couches sur 43 sur le GPU (essais forcés, débit tombé à 19–21 tokens/s). Le script de vérification exige donc aussi un débit minimal (40 tokens/s, à revoir si la base change) ; il détecte un gros débordement, pas un débordement de quelques couches. La preuve directe est la ligne `offloaded 43/43 layers to GPU` du journal `%LOCALAPPDATA%\Ollama\server.log`, écrit quand Ollama est lancé par son application.
- Réflexion (thinking) : activée par défaut sur cette base. Chaque réponse commence par environ 300 à 500 tokens de raisonnement en anglais, soit 3 à 6 s avant le texte visible. À trancher au moment des réglages d'Open WebUI ; côté API Ollama, c'est le champ `think`.

Notes `basique` :

- Ne tient aucun des deux critères d'achat : avec 18 Go de poids sur 24 Go, le contexte de `coder` plafonne bien en dessous de 131072, et un seul modèle est chargé à la fois. Ce profil reste une solution d'attente, pas une machine cible.
- 18 Go de poids laissent environ 5 Go pour le contexte : si le script de vérification échoue sur le contrôle GPU (part CPU ou débit effondré), descendre `num_ctx` à 24k puis 16k.
- Alternative sans bascule : tout le monde sur `coder` avec un preset « famille ». À tester avant de l'adopter (latence du thinking, qualité du français).
- Autres bases à tester : `qwen3.6:27b-coding`, `qwen3-coder:30b` (MoE, ~19 Go), `gemma4:e4b-it-q4_K_M` (6,6 Go).

Notes `spark` (gabarit daté d'octobre 2026, à recréer pour la machine réellement achetée) :

- Contexte : `coder` à 131072 pour commencer, à monter jusqu'à 240000 après mesure (le modèle annonce 256K sur ollama.com) ; `famille` à 30000. Mémoire et débit à ces contextes, les deux modèles chargés : à mesurer, en gardant ~16 Go de marge.
- Toutes les images doivent exister en arm64 (`docker manifest inspect`). À vérifier en priorité : `nvidia_gpu_exporter` et `ollama-metrics`, sinon build local.
- Playbooks officiels NVIDIA (Open WebUI + Ollama, Tailscale, DGX Dashboard, Unsloth pour le fine-tuning) : build.nvidia.com/spark.
- Voie plus rapide hors Ollama : vLLM ou TensorRT-LLM en NVFP4, branché dans Open WebUI comme connexion OpenAI-compatible. Optimisation ultérieure, pas un prérequis.

Dans les deux profils : tout dépôt GGUF de Hugging Face se tire avec `ollama pull hf.co/<user>/<repo>:<quant>`. Départager les candidats `coder` sur un vrai dépôt avec la suite pytest, pas sur les classements (les benchmarks publiés viennent des éditeurs).
