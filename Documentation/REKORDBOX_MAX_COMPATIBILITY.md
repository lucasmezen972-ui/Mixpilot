# Rekordbox — compatibilité maximale et nouveau Hub

## Objectif

Cette couche regroupe les chemins de compatibilité rekordbox étudiés dans les guides officiels et les projets open source transmis au projet MixPilot.

Elle ne cherche pas à forcer une seule intégration fragile. MixPilot choisit plutôt le chemin disponible :

1. export XML officiel ;
2. JSON adaptatif ;
3. sortie `rekordbox-connect` ;
4. sortie MCP / `pyrekordbox` ;
5. sortie OneLibrary ;
6. MIDI Learn officiel ;
7. Accessibilité macOS ;
8. architecture prévue pour PRO DJ LINK.

## Import bibliothèque

`RekordboxLibraryImporter` accepte :

- le XML `DJ_PLAYLISTS` officiel ;
- les objets `rows` de `rekordbox-connect` ;
- les réponses snake_case du Rekordbox MCP ;
- les objets OneLibrary imbriqués ;
- des JSON futurs dont l’enveloppe ou les noms de champs changent.

### Données normalisées

- identifiant rekordbox / ContentID ;
- titre et sous-titre ;
- artiste, album, genre, label et remixer ;
- BPM, y compris les valeurs de base multipliées par 100 ;
- durée en secondes ou millisecondes ;
- tonalité ;
- note et compteur de lecture ;
- chemin local ou fournisseur de streaming ;
- cues, hot cues et boucles ;
- grille de tempo ;
- playlists et dossiers.

Les champs inconnus sont ajoutés au rapport `unknownFieldNames` au lieu de faire échouer l’import. Les doublons provenant de plusieurs enveloppes sont supprimés.

## XML officiel

Le parseur prend en charge les éléments documentés :

- `PRODUCT` ;
- `COLLECTION` ;
- `TRACK` ;
- `TEMPO` ;
- `POSITION_MARK` ;
- `PLAYLISTS` et l’arbre de `NODE`.

Les notes rekordbox XML `0`, `51`, `102`, `153`, `204`, `255` sont converties sur une échelle de zéro à cinq.

Source : `https://cdn.rekordbox.com/files/20200410160904/xml_format_list.pdf`

## Compatibilité Spotify

MixPilot ne télécharge, ne copie et ne déchiffre aucun flux Spotify.

Il détecte uniquement :

- les URI et fournisseurs contenant Spotify ;
- les indicateurs de streaming présents dans le JSON ;
- la version déclarée par l’export ou détectée dans l’application.

Le seuil `7.2.3` est utilisé comme politique de compatibilité du projet et doit être confirmé sur l’installation cible. Une preuve Spotify dans les données reste prioritaire sur la version.

## Mapping MIDI avancé

Le preset standard est complété par :

- `SwitchActiveWindow` pour `browserFocus` ;
- `CFXParameterCH1` pour `filterA` ;
- `CFXParameterCH2` pour `filterB`.

Pour les deux paramètres CFX, **Filter doit être sélectionné comme Color FX dans rekordbox avant le Live**.

L’Echo reste volontairement exclu : les catalogues exposent des slots FX génériques, mais ne prouvent pas une sélection Echo stable sur toutes les versions.

### Commandes répertoriées

La matrice inclut notamment :

- Browse, BrowseUp, BrowseDown, Back, Forward ;
- SwitchActiveWindow ;
- Preview, PlayPausePreview, SkipPreview ;
- PlayPause, Cue, Sync, Load ;
- Master, Vinyl et Quantize ;
- BeatLoop4, ReloopExit, LoopHalf, LoopDouble, LoopIn et LoopOut ;
- SemitoneUp et SemitoneDown ;
- ChannelFader, CrossFader, EQLow, EQMid, EQHigh et TempoSlider ;
- CFXParameterCH1 et CFXParameterCH2 ;
- AutoMixStartStop, répertorié mais non branché au moteur.

Sources :

- guide MIDI Learn officiel rekordbox 5.3 ;
- catalogues rekordbox 6.6.3 et 6.7.4 fournis sur Pastebin ;
- `timkondratev/RekordJog` ;
- documentation des mappings Mixxx.

## 7 bits, 14 bits et jog wheels

Le guide officiel autorise les faders 7 bits et 14 bits. Les recommandations Mixxx détaillent les paires MSB/LSB, le soft takeover et les encodeurs relatifs.

Le runtime actuel de MixPilot émet des messages 7 bits. Aucun jog wheel ou fader 14 bits n’est fabriqué artificiellement. Une future couche devra :

1. apprendre les deux messages MSB/LSB ;
2. vérifier leur ordre ;
3. tester la plage complète ;
4. ajouter un soft takeover ;
5. enregistrer le résultat par version de rekordbox et par appareil.

## Rekordbox Hub

La fenêtre `Rekordbox Hub`, accessible avec `⇧⌘H`, offre :

- détection de l’application et de sa version ;
- import XML/JSON ;
- résumé local/streaming/Spotify ;
- recherche dans les titres ;
- affichage des playlists ;
- aperçu du nombre de transitions MixPilot ;
- matrice de compatibilité ;
- génération du preset MIDI avancé ;
- commandes de test armées manuellement ;
- accès au laboratoire Accessibilité.

L’interface principale de MixPilot est désormais neutre entre Serato, djay et rekordbox.

## Sécurité

- aucune modification du paquet signé de rekordbox ;
- aucune écriture SQLCipher pendant le Live ;
- aucune fonction de téléchargement Spotify ou YouTube ;
- aucune commande Echo ambiguë ;
- aucune action Accessibilité sans armement ;
- double confirmation pour les libellés potentiellement destructeurs ;
- statut `REQUIRES_DEVICE_VALIDATION` conservé pour les actions réelles.

## Sources open source étudiées

- `https://github.com/chrisle/rekordbox-connect`
- `https://github.com/chrisle/alphatheta-connect`
- `https://github.com/chrisle/onelibrary-connect`
- `https://github.com/chrisle/now-playing-app`
- `https://github.com/davehenke/rekordbox-mcp`
- `https://github.com/jviall/rekordbox-edit`
- `https://github.com/timkondratev/RekordJog`
- `https://github.com/mixxxdj/mixxx/wiki/MIDI-controller-mapping-file-format`
- `https://github.com/mixxxdj/mixxx/wiki/Contributing-Mappings`

Le dépôt `rekordbox-spotify-downloader` a uniquement servi à comprendre certains formats d’export de playlists. Aucune logique de téléchargement ou de contournement n’a été intégrée.
