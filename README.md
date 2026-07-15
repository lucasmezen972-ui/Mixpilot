# MixPilot Autopilot

MixPilot est une application native macOS qui prépare un set DJ, planifie les transitions, pilote Serato DJ Pro par MIDI, surveille le son et fournit des mécanismes de récupération et de secours.

Une application iPhone séparée, **MixPilot Remote**, permet la surveillance et l’envoi d’intentions de haut niveau sur le réseau local. Le Mac reste toujours la source de vérité et le seul composant autorisé à contrôler Serato ou à envoyer du MIDI.

## Cibles

- MacBook Pro Apple Silicon ;
- macOS 14 ou supérieur ;
- Serato DJ Pro ;
- Spotify Premium utilisé directement dans Serato ;
- iPhone sous iOS 17 ou supérieur ;
- Mac et iPhone sur le même réseau local.

## Composants

### Application Mac

- Swift 6, SwiftUI et AppKit ;
- CoreMIDI et contrôleur virtuel `MixPilot Virtual Controller` ;
- préparation des marqueurs et du plan de set ;
- sept familles de transitions ;
- analyse audio locale temporaire ;
- mapping MIDI avec confirmations ;
- préflight bloquant ;
- watchdog audio et musique locale de secours ;
- répétition et inspection des transitions ;
- checkpoints et Centre de récupération ;
- diagnostics anonymisés ;
- bridge iPhone séparé et désactivé par défaut.

### Application iPhone

Le projet est isolé dans :

```text
Mobile/MixPilotRemote
```

Il inclut :

- génération XcodeGen ;
- découverte Bonjour `_mixpilot._tcp` ;
- client WebSocket local ;
- appairage et authentification ;
- stockage Keychain ;
- snapshots séquencés ;
- commandes critiques confirmées ;
- mode démo explicitement marqué comme simulation.

## Commandes distantes RC2

- `takeManualControl` : implémentée et idempotente ;
- `pauseAutopilot` : pause coopérative à un point sûr ;
- `resumeAutopilot` : reprise uniquement après vérifications ;
- `skipTransition` : conserve le même titre et remplace uniquement la technique ;
- `safeFade` : volontairement verrouillée jusqu’à validation du routage audio réel.

Aucune commande iPhone ne contient de MIDI brut. Une perte réseau ne change jamais automatiquement le Live Mac.

## Validation automatisée

```bash
swift test --parallel
swift run MixPilotSimulatorCLI --tracks 50 --inject-failures
swift run MixPilotSimulatorCLI --tracks 250 --inject-failures
swift build -c release --product MixPilotAutopilot
swift build -c release --product MixPilotHardwareProbeCLI
./Scripts/build_release.sh
./Scripts/package_dmg.sh
shasum -a 256 -c build/MixPilot-Autopilot.dmg.sha256
```

Application iPhone :

```bash
cd Mobile/MixPilotRemote
xcodegen generate
xcodebuild \
  -project MixPilotRemote.xcodeproj \
  -scheme MixPilotRemote \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
swift test --parallel
```

## Statuts

- tests et builds publics : `AUTOMATED_SUCCESS` ;
- simulations : `SIMULATED_SUCCESS` ;
- Serato, Spotify et mapping réel : `REQUIRES_SERATO_VALIDATION` ;
- audio réel, appareils physiques et endurance : `REQUIRES_DEVICE_VALIDATION`.

Aucune simulation n’est présentée comme une validation réelle.

## Spotify et confidentialité

Spotify reste connecté directement dans Serato DJ Pro. MixPilot ne télécharge, n’extrait, n’enregistre ni ne stocke aucun flux Spotify brut.

Le dépôt ne doit contenir aucun token, code d’appairage réel, certificat, mot de passe, fichier audio protégé ou donnée Spotify sensible.

## Documentation principale

- `DEVELOPMENT_STATUS.md` ;
- `MANUAL_CHECKPOINTS.md` ;
- `Documentation/RC_STATUS.md` ;
- `Documentation/REMOTE_PROTOCOL_V1.md` ;
- `Documentation/IPHONE_REMOTE_BRIDGE.md` ;
- `Documentation/FINAL_VALIDATION.md` ;
- `Documentation/RELEASE.md`.
