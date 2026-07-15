# Development Status

Dernière mise à jour : 2026-07-15

## État global

**Phase 2 — Premier MVP natif et prototype vertical**

## Réalisé

- [x] Dépôt et branches initialisés
- [x] Règles Claude et sécurité du dépôt public
- [x] Cahier des charges versionné
- [x] Package Swift 6 modulaire
- [x] Application SwiftUI macOS
- [x] Moteur de génération de transitions
- [x] Machine à états Autopilot
- [x] Simulateur CLI
- [x] Six tests du moteur validés localement
- [x] Simulation de 50 titres et 49 transitions validée localement
- [x] Récupération de quatre incidents injectés validée localement
- [x] Port virtuel CoreMIDI implémenté
- [x] Détection du processus Serato implémentée
- [x] Lecteur audio local de secours implémenté
- [x] Feasibility Lab initial
- [x] CI macOS et simulation longue
- [x] Scripts de construction `.app` et `.dmg`

## Validation

- `SIMULATED` : moteur de transitions, Autopilot et récupération.
- `REQUIRES_SERATO_VALIDATION` : CoreMIDI dans Serato, chargement de titres, observation de decks et capture audio.
- `REQUIRES_MACOS_CI` : compilation des cibles Apple spécifiques.

## Prochaines étapes automatiques

1. Exécuter la CI macOS sur la Pull Request.
2. Corriger toute erreur Swift/CoreMIDI/SwiftUI remontée par Xcode.
3. Ajouter le mapping MIDI persistant.
4. Ajouter le pilote Accessibilité pour la bibliothèque Serato.
5. Ajouter la capture audio et le watchdog de silence.
6. Produire le premier DMG de développement.

## Checkpoints humains à venir

- H002 : disposer d’un Mac avec Xcode pour les tests réels.
- H003 : lancer Serato DJ Pro et connecter Spotify.
- H004 : accorder les permissions macOS.
- H005 : mapper les commandes MIDI.
- H007 : sélectionner la musique locale de secours.
