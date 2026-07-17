# Preset MIDI rekordbox généré par MixPilot

## But

MixPilot peut générer un fichier `MixPilot Virtual Controller.midi.csv` à importer dans la fenêtre MIDI officielle de rekordbox.

Le fichier est construit depuis le profil CoreMIDI actif de MixPilot et ne modifie :

- ni le paquet signé de rekordbox ;
- ni les mappings Pioneer/AlphaTheta livrés avec l’application ;
- ni la base SQLCipher de la bibliothèque ;
- ni les fichiers audio.

## Sources techniques utilisées

Le compilateur s’appuie sur :

1. le guide officiel **MIDI LEARN Operation Guide** de rekordbox, qui confirme :
   - la sélection d’un appareil MIDI connecté ;
   - les colonnes Function, Deck, MIDI IN, Type, MIDI OUT et Comment ;
   - les types Button, Pad, Knob/Fader 7 bits, Knob/Fader 14 bits, Rotary, Indicator et Value ;
   - l’import et l’export de mappings ;
   - l’interdiction d’affecter un même code MIDI à plusieurs fonctions ;
2. les catalogues de commandes rekordbox 6.6.3 et 6.7.4 fournis au projet ;
3. les fichiers `.midi.csv` du projet MIT `timkondratev/RekordJog`, qui confirment l’en-tête `@file,1,<controller>` et le format à 15 colonnes ;
4. la documentation des mappings Mixxx, utilisée comme référence d’architecture pour séparer messages entrants, sorties, résolutions et contrôles relatifs.

MixPilot ne copie pas le format XML de Mixxx dans rekordbox : les deux logiciels utilisent des formats différents.

## Commandes générées

Le registre conservateur contient uniquement les commandes retrouvées dans les catalogues observés :

- `PlayPause` ;
- `Cue` ;
- `Sync` ;
- `Load` ;
- `BrowseUp` et `BrowseDown` ;
- `ChannelFader` ;
- `CrossFader` ;
- `EQLow`, `EQMid`, `EQHigh` ;
- `TempoSlider` ;
- `BeatLoop4` ;
- `ReloopExit`.

Les actions suivantes sont volontairement exclues du preset automatique tant qu’un nom stable n’est pas confirmé :

- focus navigateur ;
- filtre ;
- Echo et quantité d’Echo.

## Traduction MIDI

### Boutons

Les notes MixPilot deviennent un code MIDI IN sur quatre caractères :

- canal 1, note 60 → `903C` ;
- canal 3, note 64 → `9240`.

### Faders et potentiomètres

Les Control Change deviennent :

- canal 1, CC 10 → `B00A` ;
- canal 16, CC 10 → `BF0A`.

### Colonnes de deck

- action globale : colonne `input` ;
- deck A : colonne `deck1` ;
- deck B : colonne `deck2`.

Les colonnes Deck 3 et Deck 4 restent vides dans ce lot.

## Contrôles de sécurité

Le preset est refusé si :

- l’en-tête `@file` est invalide ;
- une ligne ne contient pas exactement 15 colonnes ;
- une commande n’existe pas dans le registre vérifié ;
- un code MIDI n’est pas un hexadécimal sur quatre caractères ;
- une ligne ne contient pas exactement un MIDI IN ;
- le même code MIDI apparaît sur plusieurs fonctions ;
- aucune action compatible n’est présente.

Après écriture, MixPilot relit le fichier, vérifie l’égalité binaire et relance le validateur.

## Import utilisateur

1. Lancer MixPilot afin de publier `MixPilot Virtual Controller`.
2. Lancer rekordbox en mode PERFORMANCE.
3. Ouvrir la fenêtre MIDI.
4. Choisir `MixPilot Virtual Controller`.
5. Cliquer sur `IMPORT`.
6. Sélectionner `MixPilot Virtual Controller.midi.csv`.
7. Tester chaque commande sur une playlist de copie.

Le raccourci MixPilot pour ouvrir le générateur est `⇧⌘B`.

## Limites

- `PlayPause` est une commande bascule dans rekordbox. Les intentions internes `play` et `pause` de MixPilot utilisent donc deux messages distincts vers la même fonction et nécessitent une vérification de l’état du deck.
- Les catalogues observés sont ceux de rekordbox 6.6.3 et 6.7.4. La présence des mêmes commandes dans rekordbox 7.2.3 ou ultérieur doit être validée sur le Mac cible.
- Les jog wheels, le scratch et les encodeurs relatifs ne sont pas générés automatiquement.
- Les faders haute résolution `0h-3FFFh` ne sont pas générés dans ce lot.
- Aucun MIDI OUT pour LED n’est émis par le preset, afin d’éviter une boucle de retour non testée.
- L’import réussi ne prouve pas encore la réaction réelle du logiciel. Le statut reste `REQUIRES_DEVICE_VALIDATION`.
