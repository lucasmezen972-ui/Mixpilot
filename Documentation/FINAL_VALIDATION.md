# Validation finale sur MacBook Pro M1

Ce protocole n'est exécuté qu'une fois que la release candidate est entièrement verte en CI.

## Principe

Les tests automatisés GitHub valident le moteur, les calculs, la simulation, les scénarios de panne, la compilation et le DMG. Les tests ci-dessous valident uniquement les dépendances impossibles à reproduire sur un runner public : Serato DJ Pro, Spotify, l'interface réelle, CoreMIDI, le routage audio et les permissions macOS.

## Conditions

- MacBook Pro M1 sous macOS 14 ou supérieur
- alimentation secteur
- Serato DJ Pro à jour
- Spotify Premium connecté dans Serato
- connexion Internet principale et partage mobile disponible
- sortie audio de soirée ou périphérique équivalent
- au moins 30 minutes de musique locale de secours
- petite playlist Spotify de test, puis playlist longue

## Phase A — Installation et permissions

1. Installer le DMG de la release candidate.
2. Lancer MixPilot depuis Applications.
3. Accorder Accessibilité, Capture d'écran et Audio lorsque demandé.
4. Redémarrer MixPilot après chaque modification de permission.
5. Vérifier que le Feasibility Lab indique Serato, Accessibilité et MIDI comme réels.

Critère : aucune permission critique ne reste bloquée.

## Phase B — Mapping MIDI

1. Dans Serato, ouvrir le mode de mapping MIDI.
2. Sélectionner `MixPilot Virtual Controller`.
3. Mapper les actions du profil MixPilot.
4. Tester individuellement Play, Pause, Sync, Load, volumes, EQ, filtre, crossfader, echo et boucles.
5. Vérifier que chaque action contrôle le bon deck et qu'une valeur continue revient au bon neutre.

Critère : 100 % des actions critiques sont confirmées.

## Phase C — Import de playlist

1. Afficher une playlist de dix titres dans Serato.
2. Lancer la capture depuis MixPilot Studio.
3. Vérifier l'ordre, les titres, artistes, BPM et durées.
4. Corriger uniquement les champs non exposés par Serato.
5. Ouvrir l'Inspecteur de transitions et vérifier les enchaînements à faible confiance.

Critère : le bon titre est associé à chaque ligne et aucune transition n'utilise les mauvais morceaux.

## Phase D — Audio et secours

1. Démarrer la surveillance audio.
2. Faire jouer un titre et vérifier que le niveau réagit.
3. Couper volontairement la source pour provoquer une alerte de silence.
4. Vérifier le déclenchement du lecteur local de secours.
5. Tester fade-in, fade-out, passage au fichier suivant et durée totale.

Critère : aucun blanc supérieur à une seconde après le seuil critique lorsque le secours est prêt.

## Phase E — Transitions réelles

Tester au minimum :

- Smooth Blend
- Bass Swap
- Rap Switch
- Shatta Drop
- Echo Exit
- Safe Fade
- Hard Cut contrôlé

Pour chaque transition :

1. confirmer le titre sortant et entrant ;
2. observer le chargement anticipé ;
3. vérifier Sync ou l'absence volontaire de Sync ;
4. vérifier les EQ et le crossfader ;
5. confirmer l'arrêt du deck sortant ;
6. vérifier l'absence de saturation et de chevauchement vocal excessif.

Critère : dix transitions consécutives sans mauvaise sélection, blanc ou commande de deck inversée.

## Phase F — Scénarios de panne

Tester réellement :

1. perte Internet ;
2. titre Spotify qui refuse de charger ;
3. Serato fermé pendant la lecture locale de secours ;
4. routage audio interrompu ;
5. port MIDI indisponible ;
6. débranchement secteur ;
7. reprise manuelle ;
8. fermeture de MixPilot puis Centre de récupération.

Critère : chaque incident conduit au comportement prévu, sans action contradictoire.

## Phase G — Endurance

1. Préparer un set d'au moins deux heures.
2. Lancer le préflight complet.
3. Laisser l'écran et le Mac sans interaction.
4. Noter chaque alerte et reprise.
5. Exporter le diagnostic à la fin.

Critères :

- toutes les transitions prévues sont terminées ;
- aucun blanc supérieur à une seconde hors test volontaire ;
- aucun crash ;
- mémoire et CPU restent stables ;
- le Mac ne se met pas en veille ;
- la reprise manuelle reste disponible ;
- le journal final ne contient aucun incident non récupéré.

## Décision

La version peut devenir `1.0` uniquement lorsque toutes les phases sont validées. Une limite de Serato non résolue entraîne soit une correction, soit une limitation claire de la fonctionnalité concernée ; elle ne doit jamais être masquée par une simulation.
