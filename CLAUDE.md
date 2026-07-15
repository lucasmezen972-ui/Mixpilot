# CLAUDE.md — MixPilot Autopilot

## Mission

Construire une application macOS native en Swift/SwiftUI qui prépare un set DJ à partir d’une playlist ordonnée, génère les transitions, puis pilote Serato DJ Pro de façon autonome avec surveillance audio et lecture locale de secours.

## Règles absolues

1. Ne jamais inventer d’API Serato ou Spotify.
2. Distinguer systématiquement `REAL`, `SIMULATED`, `REQUIRES_SERATO_VALIDATION` et `BLOCKED_BY_PLATFORM`.
3. Ne jamais conserver le flux audio Spotify ni contourner un DRM.
4. Favoriser la continuité sonore et la récupération plutôt qu’une transition complexe.
5. Compiler et tester après chaque lot cohérent.
6. Ajouter des tests pour chaque correctif important.
7. Mettre à jour `DEVELOPMENT_STATUS.md` et `MANUAL_CHECKPOINTS.md`.
8. Ne jamais stocker de secret dans le dépôt.
9. Utiliser des branches et des Pull Requests ; ne jamais pousser directement une fonctionnalité sur `main`.

## Action humaine requise

Lorsqu’une opération humaine est indispensable, utiliser exactement ce format :

```text
============================================================
ACTION HUMAINE REQUISE — [IDENTIFIANT]
============================================================
OBJECTIF
...

POURQUOI CETTE ACTION EST NÉCESSAIRE
...

À FAIRE
1. ...

RÉSULTAT ATTENDU
...

RÉPONSE À ENVOYER À CLAUDE
« ACTION [IDENTIFIANT] TERMINÉE »

CE QUE CLAUDE FERA ENSUITE
...
============================================================
```

Avant d’attendre, sauvegarder le travail, mettre à jour les fichiers de suivi et poursuivre les modules indépendants lorsque possible.

## Architecture cible

- `MixPilotApp/` : application SwiftUI macOS
- `Packages/MixPilotCore/` : modèles et logique partagée
- `Packages/MIDIEngine/` : CoreMIDI et mapping
- `Packages/SeratoBridge/` : accessibilité, observation et pilotage Serato
- `Packages/AudioCapture/` : capture et ring buffer
- `Packages/AudioAnalysis/` : BPM, beats, phrases, énergie et silence
- `Packages/TransitionEngine/` : planification des transitions
- `Packages/AutopilotEngine/` : machine à états Live
- `Packages/EmergencyPlayer/` : lecture locale indépendante
- `Packages/Persistence/` : projets, plans et checkpoints
- `Packages/Diagnostics/` : logs et Feasibility Lab
- `Tests/` : unitaires, intégration, simulation et UI

## Technologies prioritaires

Swift, SwiftUI, AppKit, CoreMIDI, AVFoundation, AVAudioEngine, Core Audio, Accelerate/vDSP, ScreenCaptureKit, Vision, AXUIElement, Network, OSLog et SwiftData.

## Commandes attendues

À créer et maintenir :

```bash
./Scripts/verify_environment.sh
./Scripts/run_tests.sh
./Scripts/build_release.sh
./Scripts/package_dmg.sh
```

## Critères initiaux

La première validation verticale doit prouver :

1. port MIDI virtuel ;
2. chargement automatique d’un morceau ;
3. confirmation du titre chargé ;
4. surveillance audio ;
5. lecture locale de secours.

Aucun de ces tests ne doit être marqué `REAL_SUCCESS` sans test réel sur un Mac équipé de Serato DJ Pro.
