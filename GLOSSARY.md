# LLM local familial

Auto-hébergement de LLM open-weight pour un foyer de quatre personnes. Ce glossaire fixe le vocabulaire commun aux documents, aux tickets et aux fichiers de configuration.

## Langage

**Profil** :
Ensemble des choix qui dépendent d'une machine donnée : les alias qu'elle sert, la base de chacun et les réglages du serveur de modèles. Il existe un profil par machine : `laptop`, `basique`, `spark`.
_À éviter_ : configuration, environnement, machine

**Alias** :
Nom stable sous lequel un modèle est proposé aux personnes et aux outils (`coder`, `famille`), quelle que soit la base qui le sert.
_À éviter_ : modèle personnalisé, preset

**Base** :
Modèle open-weight publié, utilisé tel quel, sur lequel un alias est construit. Elle change d'un profil à l'autre ; l'alias, non.
_À éviter_ : modèle brut, modèle d'origine
