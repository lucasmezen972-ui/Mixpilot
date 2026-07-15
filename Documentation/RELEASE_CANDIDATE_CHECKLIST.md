# MixPilot Autopilot — Checklist Release Candidate

Cette checklist ne doit être utilisée qu’après validation automatique complète de la branche `develop`.

## 1. Installation et environnement

- [ ] MacBook Pro M1 ou supérieur branché au secteur.
- [ ] macOS 14 ou supérieur à jour, sans mise à jour système planifiée pendant le test.
- [ ] Serato DJ Pro installé et lancé.
- [ ] Spotify Premium connecté dans Serato.
- [ ] Playlist de test visible dans Serato.
- [ ] Sortie audio principale fonctionnelle.
- [ ] Source de surveillance audio configurée.
- [ ] Au moins 30 minutes de musique locale de secours sélectionnées.

## 2. Autorisations macOS

- [ ] Accessibilité accordée à MixPilot.
- [ ] Capture audio ou périphérique loopback autorisé.
- [ ] Accès au dossier de secours accordé.
- [ ] MixPilot relancé après toute modification d’autorisation.

## 3. Mapping MIDI

Dans l’assistant MixPilot, confirmer chaque commande après avoir constaté sa réaction réelle dans Serato.

- [ ] Play, Pause, Cue et Sync sur les deux decks.
- [ ] Chargement Deck A et Deck B.
- [ ] Navigation dans la bibliothèque.
- [ ] Volumes et crossfader.
- [ ] EQ basses, médiums et aigus.
- [ ] Filtres et pitch.
- [ ] Echo, quantité d’effet et boucles.
- [ ] Ratio de validation supérieur ou égal à 95 %.

Un message MIDI simplement présent dans le profil ne compte pas comme validé.

## 4. Répétition technique

- [ ] Ouvrir la fenêtre **Répétition des transitions**.
- [ ] Charger et positionner la paire de titres concernée dans Serato.
- [ ] Exécuter la proposition principale.
- [ ] Vérifier l’absence de silence et de saturation.
- [ ] Comparer avec Safe Fade et Echo Exit pour les transitions faibles.
- [ ] Conserver la variante dont le score mesuré est le plus élevé.
- [ ] Répéter toutes les transitions sous 75 % de confiance.

L’audio brut capturé pendant la mesure reste en mémoire et est supprimé immédiatement après analyse.

## 5. Préflight Live

Tous les éléments critiques doivent être verts :

- [ ] Serato détecté.
- [ ] Accessibilité autorisée.
- [ ] Port MIDI disponible.
- [ ] Mapping réellement confirmé.
- [ ] Surveillance audio active.
- [ ] Internet disponible.
- [ ] Mac branché au secteur.
- [ ] Secours local d’au moins 30 minutes.
- [ ] Plan préparé, complet et verrouillé.

## 6. Tests progressifs

- [ ] Deux titres locaux.
- [ ] Dix transitions locales consécutives.
- [ ] Deux titres Spotify.
- [ ] Playlist Spotify de dix titres.
- [ ] Set d’une heure.
- [ ] Set complet dans les conditions réelles de la fête.

À chaque niveau :

- vérifier le titre chargé ;
- vérifier l’alternance A/B ;
- déclencher une reprise manuelle ;
- simuler une coupure Internet ;
- vérifier le passage au secours local ;
- exporter le diagnostic.

## 7. Critères de blocage

Ne pas publier ou utiliser sans surveillance si :

- le chargement du bon titre n’est pas répétable ;
- le mapping n’est pas confirmé ;
- la surveillance audio ne reçoit aucun signal ;
- le secours local ne sort pas sur les enceintes ;
- une transition provoque un blanc supérieur à une seconde ;
- le bouton de reprise manuelle ne stoppe pas immédiatement les automatisations ;
- le diagnostic mélange un test simulé avec une validation réelle.

## 8. Publication

La fabrication du DMG ne doit commencer qu’après :

- [ ] CI macOS entièrement verte.
- [ ] Tests Serato réels terminés.
- [ ] Diagnostic final archivé.
- [ ] Numéro de version Release Candidate défini.
- [ ] Signature Developer ID configurée, si distribution externe.
- [ ] Notarisation configurée, si distribution externe.
