# MixPilot Remote pour iPhone

MixPilot Remote supervise le Live MixPilot sur le réseau local avec **djay Pro**, **rekordbox** ou **Serato DJ Pro**.

L’application iPhone ne pilote jamais directement le logiciel DJ. Le Mac reste l’unique source de vérité et le seul composant autorisé à :

- envoyer des commandes MIDI ;
- lire les capacités du backend actif ;
- vérifier l’état du Live ;
- accepter ou refuser une commande distante ;
- déclencher les protections locales ;
- rendre le contrôle manuel.

## Ce que l’iPhone affiche

- backend actif et version du logiciel ;
- mode utilisé ;
- morceau actuel et morceau suivant ;
- deck actif ;
- progression ;
- transition prévue ;
- état audio ;
- alertes ;
- fonctions temporairement dégradées.

Les données musicales sont envoyées uniquement sur le réseau local vers l’appareil appairé. Elles ne sont pas transmises aux services en ligne par ce protocole.

## Commandes visibles

L’interface utilise des formulations produit :

- **Mettre en pause** ;
- **Reprendre** ;
- **Changer la prochaine transition** ;
- **Transition de secours** ;
- **Reprendre la main**.

Le protocole interne conserve des intentions de haut niveau. Il ne contient aucun message MIDI brut.

Une commande peut être refusée lorsque :

- le backend actif ne fournit pas la capacité ;
- le Live n’est pas dans un état sûr ;
- la commande est trop ancienne ;
- son identifiant a déjà été traité ;
- le Mac ne peut pas confirmer l’effet attendu ;
- une protection locale est active.

L’iPhone affiche le refus du Mac sans simuler de réussite.

## Perte de connexion

Une perte de Wi-Fi, la fermeture de l’application ou l’extinction de l’iPhone :

- ne met pas le Live en pause ;
- ne change pas la transition ;
- ne déclenche pas le secours ;
- n’envoie aucune commande implicite ;
- ne modifie pas le backend actif.

Le Mac continue selon son état local ou rend la main selon ses propres protections.

## Protocole partagé

Le contrat versionné se trouve dans :

```text
Shared/RemoteProtocolV2
```

Il est compilé par :

- le bridge macOS ;
- l’application iPhone ;
- les tests de contrat.

Remote v2 ajoute notamment :

- backend actif ;
- version du logiciel ;
- mode du backend ;
- deck actif ;
- état audio ;
- liste des capacités dégradées.

Le décodeur reste compatible avec les snapshots Remote v1 pendant la migration. Un ancien snapshot ne peut toutefois pas inventer un backend absent de son format.

## Réseau et appairage

- découverte Bonjour `_mixpilot._tcp` ;
- connexion WebSocket locale ;
- code à six chiffres limité dans le temps ;
- jeton d’appairage stocké dans le Trousseau iOS ;
- appareil principal autorisé à demander des commandes ;
- appareils secondaires en lecture seule ;
- snapshots ordonnés ;
- snapshots anciens ou dupliqués refusés ;
- commandes dédupliquées par UUID.

Le code d’appairage et les jetons ne doivent jamais apparaître dans les diagnostics ou les services en ligne.

## Mode démo

Le mode démo permet d’explorer l’interface sans Mac.

Il est toujours présenté comme une simulation :

- aucun logiciel DJ n’est contacté ;
- aucune commande n’est envoyée ;
- aucune validation matérielle n’est créée.

## Générer le projet

```bash
brew install xcodegen
cd Mobile/MixPilotRemote
xcodegen generate
```

## Compiler pour le simulateur

```bash
xcodebuild \
  -project MixPilotRemote.xcodeproj \
  -scheme MixPilotRemote \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Pour un iPhone physique, sélectionner une équipe de signature dans Xcode.

## Tests

### Contrat partagé et logique de séquence

```bash
cd Mobile/MixPilotRemote
swift test --parallel
```

Ces tests portables vérifient notamment :

- encodage et décodage Remote v2 ;
- compatibilité de décodage avec un snapshot v1 ;
- ordre strict des snapshots ;
- refus des doublons ;
- reprise d’un nouveau flux après redémarrage du bridge Mac ;
- conservation du backend et des capacités dégradées ;
- absence de commande MIDI brute.

### Application iPhone

Après génération XcodeGen, exécuter la cible `MixPilotRemoteTests` sur un simulateur iPhone disponible :

```bash
xcodebuild \
  -project MixPilotRemote.xcodeproj \
  -scheme MixPilotRemote \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

La CI choisit automatiquement un simulateur iPhone disponible. Les tests de l’application vérifient notamment que les commandes du mode démo restent locales et conservent le backend, le deck actif et l’état audio.

## Validation réelle nécessaire

Les tests automatisés ne valident pas :

- Bonjour entre deux appareils physiques ;
- changement de réseau ;
- mise en veille de l’iPhone ;
- appairage sur plusieurs appareils ;
- perte puis reprise du WebSocket ;
- concordance avec le backend DJ réel ;
- comportement pendant un Live de longue durée.

Ces scénarios restent `REQUIRES_DEVICE_VALIDATION` jusqu’à leur exécution sur le Mac et l’iPhone cibles.
