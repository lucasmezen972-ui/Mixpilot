# Compatibilité djay — premier lot

## Objectif

Conserver le moteur MixPilot existant et ajouter djay comme deuxième logiciel DJ sélectionnable, sans retirer Serato.

## Réalisé

- sélection persistante entre Serato DJ Pro et djay Pro ;
- détection du processus sélectionné ;
- observation Accessibilité et lecture des lignes visibles dans le logiciel choisi ;
- préflight adapté au backend ;
- MIDI et mapping optionnels pour djay Automix ;
- batterie et musique locale de secours non bloquantes ;
- fenêtre de sélection du logiciel DJ ;
- fenêtre de préparation rapide d’un set visible ;
- tests automatisés dédiés ;
- build Release et DMG validés.

## Limites actuelles

- MixPilot ne remplit pas encore automatiquement la file Automix de djay ;
- MixPilot ne déclenche pas encore automatiquement la lecture dans djay ;
- la lecture exacte des lignes Spotify visibles dans djay doit être validée sur le Mac réel ;
- aucun contrôle MIDI détaillé djay n’est revendiqué.

## Statuts

- sélection et persistance : `AUTOMATED_SUCCESS` ;
- détection djay : `AUTOMATED_SUCCESS` ;
- préflight backend-aware : `AUTOMATED_SUCCESS` ;
- capture générique via Accessibilité : `REQUIRES_DEVICE_VALIDATION` ;
- remplissage de la file Automix : `REQUIRES_DEVICE_VALIDATION` ;
- démarrage automatique du set : `REQUIRES_DEVICE_VALIDATION`.
