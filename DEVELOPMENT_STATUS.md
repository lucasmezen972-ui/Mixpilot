# Development Status

Dernière mise à jour : 2026-07-15

## État global

**Phase 6 — Release candidate macOS autonome**

## Réalisé

- [x] Dépôt GitHub public sécurisé par `.gitignore` et politique de sécurité
- [x] Package Swift 6 modulaire
- [x] Application native SwiftUI macOS 14+
- [x] Port virtuel CoreMIDI `MixPilot Virtual Controller`
- [x] Profil MIDI versionné, persistant et contrôleur mappé
- [x] Génération beat-par-beat des automations MIDI
- [x] Exécution des courbes crossfader, volumes, EQ, filtre et effet
- [x] Moteur de préparation des cue markers et transitions
- [x] Profils Rap, Afro, Amapiano, Zouk, Kompa, Dancehall, Shatta, Bouyon et familial
- [x] Analyse audio locale : onsets, BPM, beat phase, énergie et sections
- [x] Capture PCM temporaire en mémoire pour la préparation, sans conservation du flux brut
- [x] Observation Accessibilité de la fenêtre Serato
- [x] Lecture heuristique des lignes visibles de bibliothèque Serato
- [x] Import d’une playlist observée et génération d’un plan de set
- [x] Optimiseur non destructif de l’ordre de playlist
- [x] Moteur de répétition et comparaison de variantes de transition
- [x] Coordinateur Live avec alternance des decks
- [x] Préchargement, validation du titre et exécution de transition
- [x] Watchdog audio silence, clipping et perte de source
- [x] Bibliothèque locale de secours multi-fichiers avec enchaînement automatique
- [x] Préflight bloquant avant mode Live
- [x] Checkpoint de session et stratégie de reprise après crash
- [x] Simulateur de machine à états sur 50 titres
- [x] Stress-test des commandes générées sur 49 transitions
- [x] Matrice automatisée de scénarios de panne
- [x] Inspecteur de transitions et comparaison des variantes
- [x] Centre de récupération sécurisé
- [x] Probe matériel macOS pour la validation finale Serato
- [x] CI macOS : tests, simulation longue, build Release et DMG
- [x] Scripts de construction `.app` et `.dmg`

## Périmètre actif

Le développement se concentre exclusivement sur **MixPilot Autopilot pour macOS** :

- préparation complète des playlists ;
- analyse musicale ;
- transitions automatiques ;
- pilotage de Serato DJ Pro ;
- fonctionnement autonome ;
- surveillance audio et récupération ;
- sécurité, robustesse et distribution macOS.

## Hors périmètre actuel

- application iPhone ;
- contrôle à distance ;
- serveur réseau ou WebSocket destiné à une télécommande ;
- synchronisation cloud avec une application mobile ;
- conception d’une API publique pour le mobile.

Ces sujets ne doivent pas détourner le développement de la release candidate macOS. Ils pourront être étudiés plus tard comme projet séparé.

## Validation automatisée

- `SUCCESS` : tests unitaires du moteur Core.
- `SUCCESS` : simulation de 50 titres avec incidents injectés.
- `SUCCESS` : génération de toutes les commandes de 49 transitions dans les limites normalisées.
- `IN_PROGRESS` : assemblage final de la release candidate macOS et génération du DMG.

## Validation différée jusqu’à la version candidate finale

- `REQUIRES_SERATO_VALIDATION` : visibilité du port CoreMIDI dans Serato.
- `REQUIRES_SERATO_VALIDATION` : mapping réel des commandes Serato.
- `REQUIRES_SERATO_VALIDATION` : sélection et chargement automatique d’un titre Spotify précis.
- `REQUIRES_SERATO_VALIDATION` : contenu réellement exposé par AXUIElement selon la version et la disposition Serato.
- `REQUIRES_DEVICE_VALIDATION` : routage audio du master Serato vers le watchdog.
- `REQUIRES_DEVICE_VALIDATION` : latence réelle sur MacBook Pro M1.

## Prochaines étapes automatiques

1. Réconcilier la release candidate avec le dernier workspace macOS.
2. Obtenir une CI entièrement verte.
3. Corriger toute erreur de compilation ou de simulation restante.
4. Produire le DMG de release candidate.
5. Faire la revue finale de sécurité et de récupération.
6. Préparer une unique campagne de validation réelle sur MacBook Pro M1.

## Checkpoints humains différés

- H002 : installation et ouverture de la version candidate sur le MacBook Pro M1.
- H003 : Serato DJ Pro lancé et Spotify connecté.
- H004 : permissions Accessibilité et capture audio accordées.
- H005 : mapping MIDI réel validé.
- H006 : routage audio Serato/BlackHole validé si nécessaire.
- H007 : bibliothèque locale de secours sélectionnée.
