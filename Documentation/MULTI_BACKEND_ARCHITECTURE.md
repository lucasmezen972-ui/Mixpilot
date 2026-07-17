# Architecture multi-backend de MixPilot

Ce document décrit l’architecture canonique. Les documents plus anciens consacrés à une intégration précise ne doivent pas redéfinir le cœur du produit.

## Principe

MixPilot possède un seul moteur métier et trois adaptateurs officiels : djay Pro, rekordbox et Serato DJ Pro.

Le moteur manipule des intentions universelles. Il ne connaît ni le nom du logiciel, ni son format de mapping, ni la méthode utilisée pour envoyer ou vérifier une commande.

## Couches

### MixPilotCore

Responsabilités :

- modèles de set et d’analyse ;
- planification des transitions ;
- contrats `DJBackend` ;
- matrice des capacités ;
- validation et messages produit ;
- sélection des fallbacks ;
- diagnostics purs ;
- migration des formats partagés.

Interdictions :

- AppKit et CoreMIDI ;
- appels réseau ;
- types djay, rekordbox ou Serato ;
- interface SwiftUI.

### MixPilotMIDI

Responsabilités :

- port virtuel CoreMIDI ;
- traduction d’un profil générique vers des messages MIDI ;
- persistance atomique du profil local.

Le module ne décide pas si une commande est sûre. Il envoie uniquement les messages demandés par un backend déjà validé.

### MixPilotSystem

Responsabilités :

- détection des applications ;
- adaptateurs djay, rekordbox et Serato ;
- Accessibilité macOS ;
- audio, fichiers, Keychain et alimentation ;
- services en ligne facultatifs ;
- installation et rollback des mappings.

### MixPilotRuntime

Responsabilités :

- orchestration du Live ;
- file de commandes sérialisée ;
- timeout et idempotence ;
- circuit breaker ;
- exécution des transitions ;
- checkpoints ;
- pause, reprise et contrôle manuel.

Le runtime dépend du protocole `DJBackend`, jamais d’un adaptateur concret.

### MixPilotRemoteBridge

Responsabilités :

- Bonjour ;
- WebSocket local ;
- appairage ;
- ordre des snapshots ;
- validation des commandes distantes par le Mac.

### MixPilotApp

Responsabilités :

- Préparer ;
- Vérifier ;
- Live ;
- Avancé ;
- traduction humaine des états ;
- consentement aux diagnostics en ligne.

### MixPilot Remote

L’application iPhone affiche un snapshot et envoie des intentions de haut niveau. Elle ne contient aucune logique d’adaptateur DJ.

## Contrat DJBackend

Un backend doit pouvoir :

- détecter son environnement ;
- annoncer ses capacités ;
- produire un rapport de validation ;
- lire l’état disponible ;
- exécuter une commande universelle ;
- vérifier séparément l’effet attendu ;
- rendre le contrôle manuel.

L’envoi d’une commande ne vaut jamais vérification.

## Registre

`DJBackendRegistry` :

- contient les backends disponibles ;
- restaure un choix explicite ;
- ne crée aucun choix par défaut ;
- bloque tout changement pendant le Live ;
- retourne le backend actif au runtime.

## Flux de préparation

```text
Playlist ou import
→ analyse MixPilot
→ ordre du set
→ transitions candidates
→ capacités du backend
→ adaptations et fallbacks
→ Vérification du système
→ plan verrouillé
```

## Flux de commande Live

```text
Intention du moteur
→ vérification de la capacité
→ file sérialisée
→ adaptateur du backend
→ commande envoyée
→ observation éventuelle
→ vérification ou état inconnu
→ poursuite, fallback, circuit breaker ou contrôle manuel
```

## Services en ligne

Les services en ligne restent dans `MixPilotSystem` et ne sont jamais une dépendance de `MixPilotRuntime`.

Une panne en ligne peut désactiver :

- les mises à jour ;
- les correctifs distants ;
- les diagnostics autorisés.

Elle ne peut pas modifier le Live.

## Dépendances autorisées

```text
App → Runtime → Core
App → System → Core
Runtime → System abstractions
System → MIDI → Core
Remote Bridge → Core + Remote Protocol
Mobile → Remote Protocol
```

Les dépendances inverses sont interdites.

## Migration

Les alias et champs historiques peuvent rester temporairement pour décoder les anciens formats. Ils ne doivent plus être utilisés dans les nouveaux parcours.

Chaque compatibilité temporaire doit comporter :

- une destination de migration ;
- une justification ;
- un test de lecture de l’ancien format ;
- une suppression planifiée après la période de migration.
