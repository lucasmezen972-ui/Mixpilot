# Mapping Serato automatique

## Objectif

L’utilisateur ne mappe et ne confirme aucune commande une par une.

Depuis MixPilot, le bouton **INSTALLER LE MAPPING SERATO** :

1. détecte Serato DJ Pro ;
2. demande sa fermeture puis le ferme après l’action explicite de l’utilisateur ;
3. crée `~/Music/_Serato_/MIDI/Xml` si nécessaire ;
4. sauvegarde `AUTO_SAVE.xml`, `MixPilot Autopilot.xml` et le manifeste existant ;
5. génère le XML depuis `MIDIMappingProfile.developmentDefault` ;
6. installe `MixPilot Autopilot.xml` ;
7. installe la même version sous `AUTO_SAVE.xml` ;
8. vérifie que le XML est bien formé et identique aux deux emplacements ;
9. écrit `MixPilot Autopilot.manifest.json` ;
10. relance Serato automatiquement.

## Emplacement

```text
~/Music/_Serato_/MIDI/Xml
```

Les sauvegardes horodatées sont conservées dans :

```text
~/Music/_Serato_/MIDI/Xml/MixPilot Backups
```

## Commandes générées

Le preset couvre automatiquement les commandes dont les noms XML sont vérifiés dans de vrais mappings Serato :

- lecture et pause par la commande `play` state-aware ;
- cue ;
- sync ;
- chargement Deck A/B ;
- navigation verticale de la bibliothèque ;
- changement de focus bibliothèque ;
- volumes Deck A/B ;
- EQ basses, médiums et aigus ;
- filtres ;
- pitch ;
- activation et sortie de boucle par la commande state-aware `auto_loop_enable`.

## Commandes volontairement non devinées

- position du crossfader ;
- activation et sélection exacte de l’effet Echo ;
- quantité exacte d’Echo associée à la banque FX cible.

Ces commandes restent `BLOCKED_BY_PLATFORM` dans le preset automatique tant qu’un nom et un slot XML fiables ne sont pas sourcés.

Le moteur de transition ne dépend plus du crossfader : toutes les transitions disposent également de courbes `incomingVolume` et `outgoingVolume`. Le fondu de secours reste donc pilotable par les upfaders.

## Statuts

- création et vérification des fichiers : `AUTOMATED_SUCCESS` ;
- syntaxe XML basée sur des mappings Serato réels : `SOURCED_FROM_REAL_MAPPINGS` ;
- réaction réelle dans Serato : `REQUIRES_SERATO_VALIDATION` ;
- fonctions dont le tag n’est pas vérifié : `BLOCKED_BY_PLATFORM`.

L’application ne transforme jamais une simple présence de fichier en `REAL_SUCCESS`.

## Retour arrière

Le bouton **Restaurer l’ancien mapping** :

1. ferme Serato ;
2. restaure la sauvegarde la plus récente ;
3. supprime les fichiers MixPilot qui n’existaient pas avant l’installation ;
4. relance Serato.

## Sources

- structure XML et exemple sous licence MIT : `marscanbueno/serato-dj-pro-midi-maps` ;
- noms de commandes et comportements : `Kovarsk/SERATO-XML-WIKI` ;
- contrôles complémentaires vérifiés dans plusieurs mappings publics Serato DJ Pro.

Les mentions de licence sont reproduites dans `THIRD_PARTY_NOTICES.md`.
