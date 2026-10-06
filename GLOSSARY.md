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

**Machine cible** :
Machine achetée pour servir le foyer durablement, choisie au jalon de novembre 2027. Elle doit tenir les critères d'achat ; une machine qui ne les tient pas est une solution d'attente, pas une machine cible.
_À éviter_ : infra, serveur, serveur final

**Prototype** :
Le laptop de Yassine, sur lequel le service est monté et répété avant l'achat de la machine cible. Yassine en est le seul utilisateur.
_À éviter_ : serveur, serveur de test, banc d'essai

**Ouverture** :
Moment où la famille commence à utiliser le service. Elle a lieu sur la machine cible, jamais sur le prototype.
_À éviter_ : mise en production, lancement
