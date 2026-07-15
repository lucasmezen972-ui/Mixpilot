# MixPilot Autopilot — Product Specification

## Vision

MixPilot Autopilot est une application macOS native qui prépare un set DJ à partir d’une playlist ordonnée, génère une transition pour chaque paire de morceaux, puis pilote Serato DJ Pro de manière autonome pendant un événement.

## Configuration cible

- MacBook Pro Apple Silicon, M1 ou supérieur
- macOS 14 minimum
- Serato DJ Pro
- Spotify Premium connecté dans Serato
- deux decks
- sortie audio alimentant les enceintes
- bibliothèque locale de secours d’au moins 30 minutes

## Parcours principal

### Studio

1. Détecter Serato.
2. Sélectionner une playlist préparée.
3. Observer et identifier les morceaux.
4. Analyser BPM, beats, mesures, phrases, énergie et zones de voix.
5. Générer les marqueurs `START`, `MIX_IN`, `VOCAL_IN`, `DROP`, `BREAK`, `MIX_OUT`, `END_SAFE` et boucle de secours.
6. Préparer automatiquement chaque transition.
7. Répéter ou simuler les transitions.
8. Afficher uniquement les transitions à faible confiance.
9. Verrouiller le plan du set.

### Live

1. Effectuer les contrôles préalables.
2. Charger le premier titre.
3. Précharger le suivant environ 90 secondes avant son utilisation.
4. Confirmer le titre et l’état du deck.
5. Exécuter la transition préparée.
6. Nettoyer le deck sortant.
7. Continuer jusqu’à la fin.
8. Déclencher le secours local en cas de panne critique.

## Contrôle de Serato

Le pont Serato repose sur :

1. CoreMIDI pour les commandes musicales ;
2. AXUIElement pour naviguer et observer l’interface accessible ;
3. ScreenCaptureKit et Vision pour compléter la vérification ;
4. une calibration explicite si l’interface ne fournit pas assez d’informations.

Aucune API Serato non documentée ne doit être supposée.

## Types de transition V1

- Smooth Blend
- Bass Swap
- Rap Switch
- Shatta Drop
- Echo Exit
- Safe Fade
- Hard Cut contrôlé

## Profils prioritaires

- Soirée familiale
- Rap français
- Afro
- Amapiano
- Zouk
- Kompa
- Dancehall
- Shatta
- Bouyon
- Antilles général
- Variété
- Mode sécurisé

## Sécurité

- confirmation après toute commande critique ;
- watchdog audio ;
- absence de silence prioritaire ;
- Emergency Player indépendant de Serato ;
- reprise manuelle immédiate ;
- persistance de checkpoints ;
- distinction stricte entre tests réels et simulés ;
- aucune conservation du flux Spotify.

## Preuve de faisabilité

La première version verticale doit valider cinq tests :

1. port MIDI virtuel et commandes principales ;
2. chargement automatique d’un morceau ;
3. confirmation du titre chargé ;
4. surveillance de la sortie audio ;
5. lecture locale de secours.

## Critères V1

- projet Xcode compilable ;
- application SwiftUI native ;
- simulateur de deux decks ;
- set simulé de 50 titres ;
- machine à états Autopilot ;
- Emergency Player ;
- Feasibility Lab ;
- CI macOS ;
- production d’un `.app` et d’un `.dmg` ;
- documentation utilisateur en français ;
- aucune fonction critique présentée comme réelle sans validation matérielle.
