# MixPilot Remote pour iPhone

MixPilot Remote est une application iOS 17 isolée du moteur macOS. Elle surveille MixPilot sur le réseau local et envoie uniquement des intentions de haut niveau. Le Mac reste la source de vérité et le seul composant autorisé à contrôler Serato ou à envoyer du MIDI.

## Fonctions présentes

- découverte Bonjour `_mixpilot._tcp` ;
- connexion WebSocket locale Remote Protocol v1 ;
- appairage par code à six chiffres ;
- jeton stocké dans le Trousseau iOS ;
- affichage du morceau actuel, du prochain titre, de la transition et des alertes ;
- snapshots séquencés ;
- rejet des snapshots anciens et dupliqués, y compris après reconnexion ;
- état de déconnexion visible ;
- confirmation des commandes critiques ;
- mode démo clairement identifié comme simulation.

## Commandes RC2

- **Reprendre le contrôle manuel** : implémentée et idempotente ;
- **Pause** : demande une pause coopérative au prochain point sûr ;
- **Reprendre** : le Mac revalide Serato, le checkpoint, le MIDI et le watchdog ;
- **Skip Transition** : ne saute pas de titre ; la transition suivante vers le même morceau devient un Safe Fade contrôlé ;
- **Safe Fade direct** : reste verrouillé tant que le routage audio réel n’est pas validé.

Une commande refusée par le Mac affiche le refus exact ; l’app ne simule jamais un succès.

## Isolation

Le projet XcodeGen se trouve uniquement dans :

```text
Mobile/MixPilotRemote
```

Le moteur Swift macOS ne dépend pas du projet iOS. Les modèles Remote testables utilisent les mêmes fichiers Swift que l’application, via le package SwiftPM local.

## Générer et compiler

```bash
brew install xcodegen
cd Mobile/MixPilotRemote
xcodegen generate
xcodebuild \
  -project MixPilotRemote.xcodeproj \
  -scheme MixPilotRemote \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Pour installer sur un iPhone physique, sélectionner une équipe de signature dans Xcode.

## Tests de contrat

```bash
cd Mobile/MixPilotRemote
swift test --parallel
```

Ces tests décodent les fixtures partagées de `Shared/RemoteProtocolV1/Fixtures` et vérifient également l’ordre strict des snapshots.

## Sécurité

- réseau local uniquement ;
- aucun MIDI brut ;
- code d’appairage limité dans le temps ;
- jeton 256 bits dans le Trousseau ;
- appareil principal et appareils secondaires en lecture seule ;
- UUID de commande dédupliqués ;
- commandes anciennes refusées ;
- aucune modification du Live Mac lors d’une perte Wi-Fi ou de la fermeture de l’app ;
- aucun jeton, code réel ou mot de passe dans les logs.

## Validation

- XcodeGen et build iOS Simulator : `AUTOMATED_SUCCESS` ;
- contrats Remote v1 et ordre des snapshots : `AUTOMATED_SUCCESS` ;
- découverte, appairage et perte Wi-Fi sur appareils physiques : `REQUIRES_DEVICE_VALIDATION` ;
- concordance avec Serato réel : `REQUIRES_SERATO_VALIDATION`.
