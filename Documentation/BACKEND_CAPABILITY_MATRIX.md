# Matrice des capacités des backends DJ

La matrice décrit ce que MixPilot peut planifier, ce qui reste à tester et ce qui est bloqué dans une configuration précise.

Elle ne constitue pas une promesse statique par marque. Le résultat dépend de la version du logiciel, du mapping, du contrôleur et de la validation réalisée sur le Mac cible.

## États

### Disponibilité

- `available` : la méthode existe pour cette configuration ;
- `partiallyAvailable` : seulement une partie du besoin est couverte ;
- `unavailable` : aucune méthode utilisable n’est disponible ;
- `unknown` : la configuration n’a pas encore été évaluée.

### Confiance

- `documented` : comportement décrit par une source ou un format officiel ;
- `validated` : comportement confirmé avec la configuration enregistrée ;
- `observed` : comportement visible mais pas suffisamment stable pour un Live autonome ;
- `simulated` : comportement reproduit uniquement dans un test ;
- `unverified` : aucune preuve suffisante.

### Validation

- `AUTOMATED_SUCCESS` ;
- `SIMULATED_SUCCESS` ;
- `REQUIRES_BACKEND_VALIDATION` ;
- `REQUIRES_DEVICE_VALIDATION` ;
- `BLOCKED_BY_PLATFORM` ;
- `FAILED`.

Une capacité entre dans un plan Live autonome uniquement lorsqu’elle est disponible, validée avec une preuve fiable et associée à la version/configuration courante.

## Capacités communes

| Capacité | Utilité |
|---|---|
| processDetection | Détecter si le logiciel est lancé |
| versionDetection | Identifier la version réellement utilisée |
| libraryReading | Lire une bibliothèque documentée ou importée |
| visiblePlaylistReading | Lire la playlist visible de façon autorisée |
| trackLoading | Charger le morceau prévu sur un deck |
| playPause | Lancer ou mettre en pause un deck |
| cue | Revenir ou se placer au point Cue |
| sync | Synchroniser le tempo |
| tempo | Modifier le tempo |
| channelVolume | Modifier le volume d’un deck |
| eqLow / eqMid / eqHigh | Modifier les EQ |
| filter | Modifier le filtre |
| crossfader | Déplacer le crossfader |
| loop | Activer ou quitter une boucle |
| effects | Déclencher un effet validé |
| automix | Utiliser un Automix natif |
| transitionTrigger | Déclencher la prochaine transition |
| deckStateReading | Lire l’état du deck |
| trackStateReading | Confirmer le morceau chargé ou joué |
| waveformReading | Lire une forme d’onde exploitable |
| masterAudioMonitoring | Surveiller le son de sortie localement |
| mappingImport | Importer un profil supporté |
| mappingAutoInstall | Installer un profil sans intervention risquée |
| mappingRollback | Restaurer le profil précédent |
| remoteControl | Accepter les intentions iPhone via le Mac |
| recovery | Reprendre depuis un checkpoint sûr |

## Situation actuelle par backend

Les entrées ci-dessous décrivent l’implémentation logicielle actuelle, pas une validation matérielle finale.

### djay Pro

| Domaine | Situation actuelle |
|---|---|
| Détection | processus, installation et version détectables |
| Bibliothèque | observation de l’interface et de la file Automix à valider par version |
| Automix | mode officiel prévu, validation backend et appareil requise |
| MIDI | profil générique disponible, import et réaction réelle à valider |
| État des decks | observation partielle, Autopilote complet bloqué sans preuve fiable |
| Mapping automatique | non revendiqué |
| Remote | disponible via le Mac |

### rekordbox

| Domaine | Situation actuelle |
|---|---|
| Détection | processus, installation et version détectables |
| Bibliothèque | import XML et JSON validé automatiquement |
| Mode Performance | configuration et formule compatible à confirmer |
| MIDI | CSV généré et validé structurellement |
| Import du mapping | action guidée dans l’interface officielle |
| Rollback | sauvegarde locale et restauration disponibles |
| État des decks | observation partielle, validation réelle requise |
| Remote | disponible via le Mac |

### Serato DJ Pro

| Domaine | Situation actuelle |
|---|---|
| Détection | processus, installation et version détectables |
| Bibliothèque | lecture des lignes visibles selon la disposition validée |
| MIDI | contrôleur virtuel et profil XML disponibles |
| Installation | assistant, sauvegarde et rollback disponibles |
| État des decks | observation Accessibilité partielle |
| Réaction des commandes | confirmation commande par commande obligatoire |
| Remote | disponible via le Mac |

## Règles de fallback

- crossfader indisponible → volumes des decks ;
- effet indisponible → transition sans effet ;
- EQ indisponible → variante basée sur les volumes ;
- navigation indisponible → préparation manuelle du morceau entrant ;
- Load ou Play non confirmés → Autopilote complet bloqué ;
- état des decks non fiable → mode supervisé ou contrôle manuel ;
- backend instable → circuit breaker et reprise manuelle.

## Instantané et persistance

Les validations sont enregistrées par :

- backend ;
- version du logiciel ;
- contrôleur ;
- version du mapping ;
- commande ou capacité ;
- date de validation.

Une mise à jour du logiciel ou du mapping peut invalider les preuves précédentes et demander un nouveau test.
