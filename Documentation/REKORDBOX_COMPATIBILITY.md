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
- inspection des contrôles Accessibilité et de leurs actions disponibles ;
- exécution protégée de `AXPress`, `AXConfirm`, `AXIncrement`, `AXDecrement` et `AXShowMenu` ;
- commandes MIDI de test pour charger, lire, mettre en pause et synchroniser les decks A et B ;
- navigation dans la bibliothèque par MIDI ;
- test du crossfader et des volumes ;
- export JSON contenant les lignes et les contrôles actionnables ;
- tests du matcher, des capacités, du préflight et de la politique de sécurité.

## Contrôle Live

Le moteur Live utilisait déjà des intentions de haut niveau indépendantes de l’interface :

- focus navigateur ;
- titre suivant ;
- chargement sur deck A ou B ;
- lecture et pause ;
- synchronisation ;
- volumes ;
- égalisation ;
- crossfader ;
- transitions automatisées.

Lorsque rekordbox est sélectionné, les mêmes messages sont envoyés par le port `MixPilot Virtual Controller`. rekordbox doit apprendre ces messages avec son système MIDI Learn avant que le préflight puisse être considéré comme validé.

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

Les contrôles visibles de rekordbox peuvent maintenant être actionnés depuis MixPilot, notamment lorsqu’ils exposent une action Accessibilité standard.

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
2. Ouvrir une playlist de test.
3. Dans MixPilot, choisir `rekordbox` comme logiciel DJ.
4. Accorder la permission Accessibilité.
5. Ouvrir `Fenêtre → Contrôler et inspecter rekordbox` ou utiliser `⇧⌘K`.
6. Cliquer sur `Inspecter rekordbox`.
7. Armer les actions uniquement sur une playlist de test.
8. Tester les commandes MIDI une par une : Load, Play, Pause, Sync et navigation.
9. Sélectionner un contrôle Accessibilité non destructif et tester son action.
10. Exporter le JSON de diagnostic.
11. Désarmer les actions avant de quitter le laboratoire.
12. Ne pas activer le Live tant que chaque commande critique n’a pas été confirmée dans rekordbox.

## Capacités déclarées

- bibliothèque Spotify : prise en charge prévue à partir des versions rekordbox compatibles, validation appareil requise ;
- MIDI Learn : intégré au parcours de contrôle, validation appareil requise ;
- contrôle réel des decks : code actif, validation appareil requise ;
- actions sur l’interface : code actif avec armement et vérification d’empreinte ;
- Automix : non utilisé comme mode d’exécution par défaut ;
- mode préféré : `directDeckControl` ;
- validation : `REQUIRES_DEVICE_VALIDATION`.

## Limites connues

- certains noms internes historiques contiennent encore `Serato`, même lorsque le moteur agit sur rekordbox ;
- aucun preset MIDI rekordbox n’est encore installé automatiquement ;
- l’ordre réel des colonnes de playlist doit encore être confirmé ;
- la confirmation du titre chargé sur chaque deck doit être testée sur l’interface réelle ;
- les actions Accessibilité dépendent de ce que la version installée expose ;
- le routage audio et la latence doivent être validés sur le MacBook Pro M1 ;
- aucune écriture directe dans la base SQLCipher n’est autorisée pendant le Live.

## Étapes suivantes

1. créer un profil MIDI rekordbox séparé et confirmé ;
2. mémoriser les contrôles Accessibilité validés par version ;
3. ajouter l’import JSON/XML multi-schémas ;
4. confirmer les titres et les decks après chaque chargement ;
5. développer un service de bibliothèque hors Live avec sauvegarde et rollback ;
6. tester une prestation complète sur une bibliothèque de copie avant toute utilisation publique.
