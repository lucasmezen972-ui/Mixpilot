# Terminologie MixPilot

Ce document est la référence éditoriale pour le code visible, l’application Mac, l’application iPhone et la documentation.

## Voix produit

- tutoiement ;
- phrases courtes ;
- langage direct et rassurant ;
- expliquer le problème, son impact et l’action possible ;
- ne jamais afficher une erreur technique brute dans le parcours normal ;
- réserver les identifiants, JSON, chemins et statuts internes à l’espace Avancé et aux exports ;
- ne jamais présenter une fonction non chiffrée, simulée ou non validée physiquement comme prête pour un Live réel.

## Noms officiels

| Concept | Terme officiel visible |
|---|---|
| Produit | MixPilot |
| Logiciel piloté | Logiciel DJ |
| Logiciels DJ officiels | djay Pro, rekordbox, Serato DJ Pro |
| Exécution automatique | Autopilote |
| Session en cours | Live |
| Démarrer une session | Lancer le Live |
| Vérifications préalables | Vérification du système |
| Revenir au DJ | Reprendre la main |
| Fichiers locaux de sécurité | Musique de secours |
| Test des commandes | Test de connexion |
| Télémétrie | Diagnostics en ligne |
| Cloud utilisateur | Services en ligne |
| Mapping téléchargé | Correctif de compatibilité |
| Télécommande mobile | Télécommande iPhone |
| Section technique | Avancé |
| Logiciel non capable | Non disponible dans cette configuration |

Les termes `backend DJ`, `Remote`, `WebSocket`, `ws`, `wss`, `TLS`, `listener` et `transport` sont des termes internes. Ils peuvent apparaître dans le code, Avancé, les diagnostics et la documentation développeur, mais pas comme libellés principaux du parcours utilisateur.

## Principe multi-backend

MixPilot ne possède aucun logiciel DJ « principal », « secondaire » ou « expérimental ».

La documentation et l’interface doivent toujours :

- citer djay Pro, rekordbox et Serato DJ Pro sans hiérarchie éditoriale ;
- décrire les différences comme des capacités disponibles ou non disponibles ;
- distinguer compatibilité théorique, simulation, test automatisé et validation physique ;
- éviter qu’un nom de logiciel DJ devienne une abstraction d’architecture dans le code générique.

## Statuts visibles

Utiliser :

- Prêt ;
- Configuration nécessaire ;
- Mapping nécessaire ;
- Test nécessaire ;
- Partiellement disponible ;
- Non disponible dans cette configuration ;
- Bloqué pour ta sécurité ;
- Télécommande indisponible pour sécurité ;
- Logiciel non installé ;
- Version non validée ;
- Contrôle manuel uniquement ;
- Services en ligne indisponibles ;
- Mise à jour disponible.

## Statuts internes

Les statuts suivants restent valides dans le code, les tests et les rapports avancés :

- `AUTOMATED_SUCCESS` ;
- `SIMULATED_SUCCESS` ;
- `REQUIRES_BACKEND_VALIDATION` ;
- `REQUIRES_DEVICE_VALIDATION` ;
- `BLOCKED_BY_PLATFORM` ;
- `FAILED`.

Ils ne doivent pas être affichés seuls à l’utilisateur.

## Traduction des problèmes

Chaque message doit couvrir :

1. ce qui ne fonctionne pas ;
2. l’impact réel ;
3. l’action proposée.

Exemple :

> Le filtre du deck B n’a pas encore été testé. Certaines transitions utiliseront uniquement les volumes et les EQ. Lance le test du filtre maintenant ou continue avec les transitions compatibles.

## Sécurité de la télécommande iPhone

Tant que le canal iPhone–Mac n’utilise pas TLS avec authentification de l’identité du Mac et de l’iPhone :

- la télécommande réseau reste désactivée dans les builds Release ;
- un éventuel mode `ws` reste réservé à un build Debug explicitement autorisé sur un réseau isolé ;
- le produit affiche « Télécommande indisponible pour sécurité » plutôt que « erreur réseau » ;
- le mode démo reste disponible sans connexion au Mac ;
- aucune documentation utilisateur ne doit employer « sécurisé », « prêt », « disponible » ou « production » pour ce canal ;
- aucune réussite simulée ne doit être présentée comme une validation réelle.

Le terme « connexion locale » décrit la portée réseau, pas le niveau de sécurité.

## Termes à retirer du parcours normal

- Feasibility Lab ;
- Compatibility Lab ;
- backend expérimental ;
- backend DJ ;
- Remote ;
- WebSocket ;
- `ws` ou `wss` ;
- TLS ;
- listener ;
- transport réseau ;
- toute hiérarchie entre djay Pro, rekordbox et Serato DJ Pro ;
- Supabase ;
- CoreMIDI ;
- AXUIElement ;
- manifeste immuable ;
- SHA-256 ;
- RLS ;
- migration SQL ;
- payload ;
- actor Swift ;
- workflow CI.

Ces termes peuvent rester dans Avancé, les diagnostics et la documentation développeur.

## Commandes de la télécommande visibles

| Commande interne | Libellé utilisateur |
|---|---|
| `pauseAutopilot` | Mettre en pause |
| `resumeAutopilot` | Reprendre |
| `skipTransition` | Changer la prochaine transition |
| `safeFade` | Transition de secours |
| `takeManualControl` | Reprendre la main |

## Règle de validation

Être officiellement pris en charge ne signifie pas que toutes les capacités sont identiques ni déjà validées sur chaque Mac.

MixPilot doit toujours distinguer :

- ce qui est disponible ;
- ce qui est configuré ;
- ce qui a été testé automatiquement ;
- ce qui a été simulé ;
- ce qui a été réellement validé sur le logiciel et le matériel cible.
