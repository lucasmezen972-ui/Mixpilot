# Compatibilité rekordbox — contrôle progressif

## Objectif

Ajouter rekordbox comme troisième logiciel DJ sélectionnable dans MixPilot et permettre à MixPilot d’agir réellement sur l’application, sans retirer Serato DJ Pro ni djay Pro.

Le contrôle est volontairement séparé en deux canaux :

1. **MIDI virtuel** pour le Live et les commandes de decks ;
2. **Accessibilité macOS** pour les boutons, menus et contrôles réellement exposés par la version installée.

## Fonctionnalités incluses

- backend `rekordbox` dans le modèle commun `DJSoftware` ;
- sélection persistante depuis la fenêtre `Logiciel DJ` ;
- détection du processus par nom d’application et identifiant de bundle ;
- observation Accessibilité de la fenêtre principale ;
- lecture générique des lignes visibles de playlist ;
- préflight adapté au mode de contrôle direct ;
- centre de contrôle rekordbox accessible avec `⇧⌘K` ;
- générateur de preset MIDI rekordbox accessible avec `⇧⌘B` ;
- compilation d’un `.midi.csv` à 15 colonnes pour `MixPilot Virtual Controller` ;
- validation de l’en-tête, des commandes, des codes hexadécimaux et des doublons MIDI ;
- inspection des contrôles Accessibilité et de leurs actions disponibles ;
- exécution protégée de `AXPress`, `AXConfirm`, `AXIncrement`, `AXDecrement` et `AXShowMenu` ;
- commandes MIDI de test pour charger, lire, mettre en pause et synchroniser les decks A et B ;
- navigation dans la bibliothèque par MIDI ;
- test du crossfader et des volumes ;
- export JSON contenant les lignes et les contrôles actionnables ;
- tests du matcher, des capacités, du préflight, du compilateur MIDI et de la politique de sécurité.

## Contrôle Live

Le moteur Live utilise des intentions de haut niveau indépendantes de l’interface :

- focus navigateur ;
- titre suivant ;
- chargement sur deck A ou B ;
- lecture et pause ;
- synchronisation ;
- volumes ;
- égalisation ;
- crossfader ;
- transitions automatisées.

Lorsque rekordbox est sélectionné, les mêmes messages sont envoyés par le port `MixPilot Virtual Controller`.

MixPilot peut maintenant générer un preset importable dans la fenêtre MIDI officielle de rekordbox. Le preset couvre uniquement les commandes dont les noms ont été retrouvés dans les catalogues rekordbox 6.6.3 et 6.7.4 : `PlayPause`, `Cue`, `Sync`, `Load`, `BrowseUp`, `BrowseDown`, `ChannelFader`, `CrossFader`, les trois EQ, `TempoSlider`, `BeatLoop4` et `ReloopExit`.

Le focus navigateur, le filtre et l’Echo restent hors preset automatique tant qu’un nom de commande stable n’est pas confirmé.

## Actions Accessibilité

MixPilot inspecte l’arbre réel de la fenêtre rekordbox et enregistre pour chaque contrôle :

- son rôle ;
- son titre, sa valeur, sa description et son aide ;
- son chemin dans l’arbre ;
- les actions macOS disponibles ;
- une empreinte permettant de vérifier que le contrôle n’a pas changé avant l’exécution.

Une action n’est exécutée que si :

1. rekordbox est le backend sélectionné ;
2. la permission Accessibilité est accordée ;
3. le contrôle est toujours au même emplacement avec la même empreinte ;
4. l’action appartient à la liste autorisée ;
5. l’utilisateur a armé les actions ;
6. une seconde confirmation est donnée lorsque le libellé ressemble à une suppression.

## Modification de bibliothèque

Les contrôles visibles de rekordbox peuvent être actionnés depuis MixPilot lorsqu’ils exposent une action Accessibilité standard.

La modification directe de la base chiffrée rekordbox n’est pas activée dans ce lot. Une future couche hors Live devra obligatoirement :

- vérifier que rekordbox est complètement fermé ;
- créer une sauvegarde datée de la base et de ses fichiers annexes ;
- utiliser une transaction ;
- vérifier l’intégrité après écriture ;
- proposer un rollback ;
- refuser les suppressions sans confirmation renforcée.

Pendant une prestation, MixPilot ne modifiera jamais directement la base de données.

## Parcours de validation

1. Installer et lancer rekordbox sur le Mac cible.
2. Ouvrir `Fenêtre → Générer le mapping rekordbox` ou utiliser `⇧⌘B`.
3. Exporter `MixPilot Virtual Controller.midi.csv`.
4. Dans rekordbox, passer en mode PERFORMANCE et ouvrir la fenêtre MIDI.
5. Sélectionner `MixPilot Virtual Controller`, cliquer sur `IMPORT` et choisir le fichier exporté.
6. Ouvrir une playlist de test.
7. Dans MixPilot, choisir `rekordbox` comme logiciel DJ.
8. Accorder la permission Accessibilité.
9. Ouvrir `Fenêtre → Contrôler et inspecter rekordbox` ou utiliser `⇧⌘K`.
10. Cliquer sur `Inspecter rekordbox`.
11. Armer les actions uniquement sur une playlist de test.
12. Tester les commandes MIDI une par une : Load, PlayPause, Sync, navigation, volumes et EQ.
13. Sélectionner un contrôle Accessibilité non destructif et tester son action.
14. Exporter le JSON de diagnostic.
15. Désarmer les actions avant de quitter le laboratoire.
16. Ne pas activer le Live tant que chaque commande critique n’a pas été confirmée dans rekordbox.

## Capacités déclarées

- bibliothèque Spotify : prise en charge prévue à partir des versions rekordbox compatibles, validation appareil requise ;
- MIDI Learn : preset généré et importable, réaction réelle à valider ;
- contrôle réel des decks : code actif, validation appareil requise ;
- actions sur l’interface : code actif avec armement et vérification d’empreinte ;
- Automix : non utilisé comme mode d’exécution par défaut ;
- mode préféré : `directDeckControl` ;
- validation : `REQUIRES_DEVICE_VALIDATION`.

## Limites connues

- certains noms internes historiques contiennent encore `Serato`, même lorsque le moteur agit sur rekordbox ;
- `PlayPause` est une bascule et nécessite une confirmation de l’état réel du deck ;
- les catalogues de commandes observés sont ceux de rekordbox 6.6.3 et 6.7.4 ;
- le preset doit être validé sur rekordbox 7.2.3 ou ultérieur lorsqu’il est utilisé avec Spotify ;
- les jog wheels, le scratch, les faders 14 bits et le retour LED ne sont pas générés ;
- l’ordre réel des colonnes de playlist doit encore être confirmé ;
- la confirmation du titre chargé sur chaque deck doit être testée sur l’interface réelle ;
- les actions Accessibilité dépendent de ce que la version installée expose ;
- le routage audio et la latence doivent être validés sur le MacBook Pro M1 ;
- aucune écriture directe dans la base SQLCipher n’est autorisée pendant le Live.

## Étapes suivantes

1. importer le preset sur le Mac cible et confirmer chaque commande ;
2. mémoriser les contrôles Accessibilité validés par version ;
3. ajouter l’import JSON/XML multi-schémas ;
4. confirmer les titres et les decks après chaque chargement ;
5. développer un service de bibliothèque hors Live avec sauvegarde et rollback ;
6. tester une prestation complète sur une bibliothèque de copie avant toute utilisation publique.
