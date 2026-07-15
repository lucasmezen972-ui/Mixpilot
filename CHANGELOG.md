# Changelog

## 0.3.0-rc.2 — intégration en cours

### macOS

- application native SwiftUI macOS 14+ ;
- préparation de playlist, cue markers, timeline et transitions ;
- sept familles de transitions ;
- mapping MIDI persistant avec confirmations réelles ;
- exécution beat-par-beat des automations ;
- analyse audio temporaire et raffinement BPM/structure ;
- répétition mesurée et inspecteur de transitions ;
- préflight bloquant, watchdog et secours local ;
- checkpoints, diagnostics et Centre de récupération ;
- matrice de treize scénarios de panne ;
- simulations de 50 et 250 titres ;
- probe matériel compilable ;
- DMG et checksum produits en CI.

### iPhone et bridge local

- application iOS 17 isolée sous `Mobile/MixPilotRemote` ;
- découverte Bonjour `_mixpilot._tcp` ;
- WebSocket local Remote Protocol v1 ;
- appairage six chiffres et jetons 256 bits dans le Trousseau ;
- appareil principal et appareils secondaires en lecture seule ;
- snapshots séquencés, anciens et doublons rejetés ;
- commandes anciennes, dupliquées ou non authentifiées refusées ;
- fixtures Remote v1 partagées Mac/iPhone ;
- `takeManualControl` idempotent ;
- Pause coopérative ;
- Reprise protégée par état réel et checkpoint ;
- Skip Transition conservant le même titre et utilisant un Safe Fade contrôlé ;
- Safe Fade direct distant maintenu verrouillé jusqu’à validation audio réelle ;
- perte réseau sans modification automatique du Live Mac.

### Validation automatisée

- tests Swift Mac : `AUTOMATED_SUCCESS` ;
- simulations 50/250 titres : `SIMULATED_SUCCESS` ;
- builds Release Mac et probe : `AUTOMATED_SUCCESS` ;
- DMG et checksum : `AUTOMATED_SUCCESS` ;
- build iOS Simulator : `AUTOMATED_SUCCESS` ;
- contrats Remote v1 et snapshots : `AUTOMATED_SUCCESS`.

### Validation restante

- Serato, Spotify et mapping réel : `REQUIRES_SERATO_VALIDATION` ;
- routage audio, latence, Safe Fade et endurance : `REQUIRES_DEVICE_VALIDATION` ;
- découverte/appairage/perte Wi-Fi sur appareils physiques : `REQUIRES_DEVICE_VALIDATION`.

## 0.3.0-rc.1 — remplacée

La branche et la PR RC1 sont obsolètes. Leur statut annonçait des composants qui n’étaient pas tous présents sur cette branche. Elles ne doivent pas être fusionnées.

## 0.2

- workspace macOS enrichi ;
- mapping et répétition technique ;
- premiers garde-fous de release candidate.

## 0.1

- premier prototype Swift ;
- moteur de transitions ;
- CoreMIDI ;
- simulateur ;
- première CI et premier DMG de développement.
