# MixPilot Remote Protocol v1 — historique

Ce document décrit l’ancien contrat v1. Il n’est plus la source canonique.

La source actuelle est :

```text
Shared/RemoteProtocolV2
```

Le guide utilisateur se trouve dans :

```text
Mobile/MixPilotRemote/README.md
```

## Pourquoi v2

Remote v1 transportait l’état du Live et les commandes de haut niveau, mais ne décrivait pas :

- le backend actif ;
- la version du logiciel DJ ;
- le mode utilisé ;
- le deck actif ;
- l’état audio ;
- les capacités temporairement dégradées.

Ces informations sont nécessaires pour une interface identique avec djay Pro, rekordbox et Serato DJ Pro.

## Invariants conservés

Remote v2 conserve les garanties de v1 :

- réseau local uniquement ;
- découverte Bonjour `_mixpilot._tcp` ;
- WebSocket ;
- Mac source de vérité ;
- aucun MIDI brut ;
- aucune décision autonome de l’iPhone ;
- aucune modification du Live après une perte réseau ;
- commandes datées et dédupliquées ;
- snapshots ordonnés ;
- accusé accepté ou refusé ;
- code d’appairage et jeton absents des diagnostics.

## Messages v1

Les types historiques restent :

- `hello` ;
- `pair` ;
- `authenticate` ;
- `subscribe` ;
- `command` ;
- `snapshot` ;
- `ack` ;
- `error` ;
- `pong`.

Les commandes internes restent des intentions de haut niveau :

- `pauseAutopilot` ;
- `resumeAutopilot` ;
- `skipTransition` ;
- `safeFade` ;
- `takeManualControl`.

Elles ne doivent jamais être affichées telles quelles à l’utilisateur. L’interface utilise :

- Mettre en pause ;
- Reprendre ;
- Changer la prochaine transition ;
- Transition de secours ;
- Reprendre la main.

## Migration vers v2

Le décodeur v2 accepte encore un snapshot v1. Les champs nouveaux sont alors absents :

- `backend = nil` ;
- `activeDeck = nil` ;
- `audioStatus = nil`.

MixPilot ne déduit pas Serato lorsqu’un snapshot historique ne contient pas de backend.

Un client v1 peut donc être lu pendant la période de migration, mais il ne bénéficie pas des informations multi-backend de v2.

## Validation

Les anciens statuts `REQUIRES_SERATO_VALIDATION` sont remplacés par :

- `REQUIRES_BACKEND_VALIDATION` ;
- `REQUIRES_DEVICE_VALIDATION`.

La reprise vérifie le backend actif, le checkpoint, le deck, les commandes et l’audio. Elle n’est plus décrite comme une relecture spécifique de Serato.

## Conservation

Les anciennes fixtures et copies du protocole peuvent être conservées pour les tests de décodage historique. Toute évolution fonctionnelle doit être apportée à Remote v2, pas à v1.
