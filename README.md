# MixPilot Autopilot

Application macOS native destinée à préparer puis exécuter automatiquement un set DJ dans Serato DJ Pro à partir d’une playlist préparée en amont, avec transitions automatiques, surveillance audio et lecture locale de secours.

## Statut

Le projet est en phase d’initialisation. Les fonctions liées à Serato, Spotify, CoreMIDI et à la capture audio devront être distinguées entre tests simulés et validations réelles sur Mac.

## Principes

- macOS 14 ou supérieur
- Swift et SwiftUI
- traitement local
- aucune conservation du flux audio Spotify
- aucune API Serato inventée
- sécurité et absence de silence prioritaires
- intervention humaine explicitement signalée lorsqu’elle est indispensable

Consulter `DEVELOPMENT_STATUS.md` et `MANUAL_CHECKPOINTS.md` pour l’état d’avancement.
