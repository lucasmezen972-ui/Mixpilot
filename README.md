# MixPilot Autopilot

MixPilot est une application macOS native en cours de développement pour préparer et exécuter automatiquement un set dans Serato DJ Pro.

## État actuel

Le premier MVP contient :

- une application SwiftUI native pour macOS 14+ ;
- un moteur de génération de transitions ;
- une machine à états Autopilot ;
- les profils Rap, Afro, Zouk, Kompa, Dancehall, Shatta, Bouyon et soirée familiale ;
- les transitions Smooth Blend, Bass Swap, Rap Switch, Shatta Drop, Echo Exit et Safe Fade ;
- un simulateur de sets longs avec injection d’incidents ;
- un port MIDI virtuel CoreMIDI nommé `MixPilot Virtual Controller` ;
- la détection de Serato DJ Pro et de la permission Accessibilité ;
- un lecteur local de secours fondé sur AVFoundation ;
- un Feasibility Lab séparant les tests réels des simulations ;
- une CI macOS et la génération automatique d’un `.app` et d’un `.dmg`.

## Validation actuelle

- `SIMULATED` : moteur Autopilot et récupération d’incidents.
- `REQUIRES_SERATO_VALIDATION` : mapping MIDI, sélection de playlist, chargement automatique et capture audio réelle.

Aucune simulation n’est présentée comme une validation réelle avec Serato.

## Développement

Ouvrir le fichier `Package.swift` dans Xcode ou utiliser :

```bash
swift test
swift run MixPilotSimulatorCLI --tracks 50 --inject-failures
```

Sur macOS :

```bash
swift run MixPilotAutopilot
./Scripts/build_release.sh
./Scripts/package_dmg.sh
```

Le DMG est créé dans `build/MixPilot-Autopilot.dmg`.

## Spotify et Serato

Spotify reste connecté directement dans Serato DJ Pro. MixPilot ne télécharge, n’enregistre et ne stocke aucun flux Spotify brut. Une bibliothèque locale de secours sera exigée pour le mode Live autonome.

## Prochaine étape

Faire compiler le MVP dans GitHub Actions, corriger les éventuelles incompatibilités macOS, puis effectuer les cinq tests réels du Feasibility Lab sur un Mac équipé de Serato DJ Pro.
