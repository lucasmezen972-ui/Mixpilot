# Compatibilité rekordbox — premier lot

## Objectif

Ajouter rekordbox comme troisième logiciel DJ sélectionnable dans MixPilot, sans retirer Serato DJ Pro ni djay Pro et sans revendiquer de contrôle réel non testé.

## Fonctionnalités incluses

- backend `rekordbox` dans le modèle commun `DJSoftware` ;
- sélection persistante depuis la fenêtre `Logiciel DJ` ;
- détection du processus par nom d’application et identifiant de bundle ;
- observation Accessibilité de la fenêtre principale ;
- lecture générique des lignes visibles de playlist ;
- préflight adapté au mode de contrôle direct ;
- laboratoire de compatibilité en lecture seule ;
- export JSON du diagnostic Accessibilité ;
- tests du matcher, des capacités et du préflight.

## Sécurité

Le premier lot rekordbox n’exécute aucune action dans rekordbox depuis le laboratoire :

- aucun clic Accessibilité ;
- aucune frappe clavier ;
- aucune commande MIDI ;
- aucun chargement de morceau ;
- aucun démarrage de lecture ;
- aucune modification de playlist ;
- aucun téléchargement ou stockage de flux musical.

Le statut reste `REQUIRES_DEVICE_VALIDATION` tant que les essais sur le Mac cible n’ont pas confirmé l’arbre Accessibilité et le mapping réel.

## Parcours de validation

1. Installer et lancer rekordbox sur le Mac cible.
2. Ouvrir une playlist de test dans la vue utilisée pendant le Live.
3. Dans MixPilot, choisir `rekordbox` comme logiciel DJ.
4. Accorder la permission Accessibilité à MixPilot.
5. Ouvrir `Fenêtre → Inspecter la compatibilité rekordbox` ou utiliser `⇧⌘K`.
6. Cliquer sur `Inspecter rekordbox`.
7. Vérifier le titre de fenêtre, le nombre de textes visibles et les lignes détectées.
8. Exporter le JSON et vérifier qu’il ne contient que les informations attendues.
9. Tester ensuite le port MIDI et le mapping, commande par commande, sur un set sans public.

## Capacités déclarées

- bibliothèque de streaming visible : prise en charge prévue, validation appareil requise ;
- MIDI Learn : pris en compte par l’architecture, validation appareil requise ;
- contrôle détaillé des decks : non revendiqué dans ce lot ;
- Automix : non utilisé comme mode d’exécution par défaut ;
- mode préféré : `directDeckControl` ;
- validation : `REQUIRES_DEVICE_VALIDATION`.

## Limites connues

- le nom interne de certaines propriétés historiques contient encore `Serato`, même lorsque le backend sélectionné est rekordbox ;
- l’importeur de lignes reste heuristique et doit être confronté à l’ordre réel des colonnes rekordbox ;
- aucun preset MIDI rekordbox n’est généré automatiquement ;
- les actions Play, Load, Sync, EQ, filtre et crossfader ne sont pas revendiquées comme fonctionnelles ;
- la confirmation du titre réellement chargé sur chaque deck reste à développer ;
- le routage audio et la latence doivent être validés sur le MacBook Pro M1.

## Prochain lot recommandé

Après récupération d’un export JSON réel :

1. identifier les colonnes stables de la playlist ;
2. créer un parseur rekordbox dédié ;
3. ajouter des fixtures anonymisées et des tests de contrat ;
4. développer un profil MIDI séparé de celui de Serato ;
5. tester une seule commande sans lecture publique ;
6. ajouter la confirmation de deck et de titre avant toute transition ;
7. conserver un arrêt immédiat et une reprise manuelle prioritaire.
