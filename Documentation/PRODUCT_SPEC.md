# MixPilot — Spécification produit

## Vision

MixPilot est une application native qui aide à préparer, vérifier, sécuriser, superviser et exécuter un set DJ à travers trois backends officiels :

- djay Pro ;
- rekordbox ;
- Serato DJ Pro.

Le produit contient un seul moteur de préparation, un seul moteur de transitions, un seul système de sécurité et un seul protocole Remote. Les différences entre logiciels sont exprimées par leur matrice de capacités.

## Promesse

MixPilot aide une personne à préparer et superviser un set fiable, puis à laisser l’application gérer les enchaînements en sécurité avec le logiciel DJ choisi.

L’utilisateur n’a pas besoin de comprendre CoreMIDI, Accessibilité macOS, CSV, XML, Supabase, SHA-256 ou les workflows CI pour suivre le parcours normal.

## Configuration cible

- Mac Apple Silicon ;
- macOS 14 minimum ;
- djay Pro, rekordbox ou Serato DJ Pro ;
- une configuration audio compatible ;
- un mapping lorsqu’il est nécessaire ;
- une musique locale de secours recommandée ;
- MixPilot Remote facultatif.

Les services de streaming restent utilisés directement dans le logiciel DJ. MixPilot ne conserve aucun flux protégé.

## Parcours principal

### Préparer

1. choisir le backend DJ ;
2. vérifier sa détection ;
3. importer ou lire une playlist ;
4. analyser les morceaux ;
5. proposer l’ordre et la courbe d’énergie ;
6. préparer les transitions ;
7. adapter les transitions aux capacités disponibles ;
8. répéter les passages sensibles ;
9. verrouiller le plan.

### Vérifier

1. logiciel et version ;
2. mapping ;
3. commandes critiques ;
4. lecture de l’état ;
5. audio ;
6. permissions ;
7. alimentation ;
8. musique de secours ;
9. Remote iPhone ;
10. rapport final.

Chaque problème visible explique :

- ce qui ne fonctionne pas ;
- l’impact réel ;
- l’action proposée.

### Live

1. confirmer le backend actif ;
2. charger et vérifier le premier morceau ;
3. précharger le suivant ;
4. choisir une transition réellement exécutable ;
5. envoyer les commandes dans une file sérialisée ;
6. vérifier l’effet lorsque l’état est lisible ;
7. utiliser un fallback sûr si une capacité disparaît ;
8. ouvrir le circuit breaker si le backend répond mal ;
9. rendre le contrôle manuel à tout moment ;
10. utiliser la musique de secours en cas de silence critique.

### Avancé

- laboratoires Accessibilité ;
- diagnostics ;
- provenance ;
- mappings ;
- rapports ;
- outils développeur ;
- imports spécialisés.

## Contrôle des logiciels DJ

Les backends peuvent utiliser uniquement des méthodes autorisées et réversibles :

- CoreMIDI ;
- fichiers de mapping officiellement importables ;
- Accessibilité macOS autorisée ;
- formats de bibliothèque documentés ou validés ;
- détection de processus et de version ;
- actions utilisateur guidées.

MixPilot n’invente aucune API, n’injecte aucun code et ne modifie pas les bases privées internes des logiciels DJ.

## Types de transition

- Smooth Blend ;
- Bass Swap ;
- Rap Switch ;
- Shatta Drop ;
- Echo Exit ;
- Safe Fade ;
- Hard Cut contrôlé.

Chaque type définit :

- capacités requises ;
- capacités préférées ;
- conditions de vérification ;
- fallbacks ;
- stratégie d’abandon.

## Profils musicaux

- Soirée familiale ;
- Rap français ;
- Afro ;
- Amapiano ;
- Zouk ;
- Kompa ;
- Dancehall ;
- Shatta ;
- Bouyon ;
- Variété ;
- Mode sécurisé.

## Sécurité

- commande envoyée distincte de commande vérifiée ;
- file sérialisée ;
- timeout ;
- idempotence ;
- protection contre les doublons ;
- circuit breaker ;
- checkpoints ;
- watchdog audio ;
- musique locale de secours ;
- prévention de veille ;
- reprise manuelle ;
- services en ligne facultatifs ;
- aucune mise à jour de mapping pendant le Live ;
- aucune IA dans la boucle d’exécution.

## Application iPhone

MixPilot Remote :

- affiche l’état transmis par le Mac ;
- fonctionne avec les trois backends ;
- envoie seulement des intentions de haut niveau ;
- n’envoie aucun MIDI brut ;
- ne décide jamais seule d’une transition ;
- n’altère pas le Live lors d’une perte de connexion.

## Validation

La spécification distingue :

- `AUTOMATED_SUCCESS` ;
- `SIMULATED_SUCCESS` ;
- `REQUIRES_BACKEND_VALIDATION` ;
- `REQUIRES_DEVICE_VALIDATION` ;
- `BLOCKED_BY_PLATFORM` ;
- `FAILED`.

Une simulation et une CI ne constituent jamais une validation matérielle.

## Critères de sortie multi-backend

- cœur sans dépendance directe à un logiciel DJ ;
- trois backends sur le même contrat ;
- capacités négociées dynamiquement ;
- transitions adaptées ;
- backend actif persisté sans défaut implicite ;
- changement bloqué pendant le Live ;
- cloud facultatif ;
- Remote générique ;
- quatre espaces principaux ;
- messages humains ;
- anciens formats migrés ;
- tests et simulations exécutés ;
- builds Mac et iPhone réussis ;
- validation matérielle documentée ;
- aucun succès réel revendiqué sans preuve.

Les références détaillées sont :

- `Documentation/MULTI_BACKEND_ARCHITECTURE.md` ;
- `Documentation/BACKEND_CAPABILITY_MATRIX.md` ;
- `Documentation/MULTI_BACKEND_VALIDATION.md` ;
- `Documentation/USER_JOURNEY.md`.
