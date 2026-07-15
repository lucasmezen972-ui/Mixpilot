# Runner GitHub Mac pour les tests Serato réels

Le workflow `Serato Hardware Validation` doit s'exécuter sur un Mac réel connecté à une session graphique. Il ne faut pas installer le runner comme démon système sans utilisateur, car Serato, les permissions d'Accessibilité et CoreMIDI dépendent de la session macOS active.

## Prérequis

- Mac Apple Silicon
- compte utilisateur dédié ou session habituelle sécurisée
- Xcode et Command Line Tools
- Serato DJ Pro installé
- Spotify connecté dans Serato
- permissions macOS déjà accordées à l'application et au terminal utilisé par le runner
- dépôt GitHub accessible

## Ajout du runner

Dans GitHub :

1. ouvrir `Settings` du dépôt ;
2. choisir `Actions` puis `Runners` ;
3. cliquer sur `New self-hosted runner` ;
4. sélectionner macOS et ARM64 ;
5. exécuter les commandes fournies par GitHub dans un dossier dédié ;
6. lors de `config.sh`, ajouter les labels :
   - `macOS`
   - `mixpilot-serato`

Ne jamais commiter le token d'enregistrement.

## Exécution interactive

Démarrer le runner depuis la session graphique :

```bash
cd ~/actions-runner-mixpilot
./run.sh
```

Pour un lancement automatique à l'ouverture de session, utiliser un `LaunchAgent` utilisateur qui exécute `run.sh`. Éviter `svc.sh install`, qui peut lancer le runner hors de la session graphique nécessaire.

## Préparation de la session

Avant le workflow final :

1. brancher le Mac au secteur ;
2. désactiver les notifications de l'événement ;
3. lancer Serato DJ Pro ;
4. connecter Spotify ;
5. ouvrir la playlist de validation ;
6. vérifier la sortie audio ;
7. vérifier les permissions Accessibilité et Audio ;
8. laisser la session déverrouillée pendant le test.

## Lancement

Dans GitHub Actions, lancer manuellement `Serato Hardware Validation` avec `strict=true`.

Le workflow :

- exécute les tests Core ;
- compile MixPilot et le probe matériel ;
- collecte MIDI, audio, alimentation et version macOS ;
- observe Serato et sa bibliothèque ;
- vérifie la création du port MIDI ;
- vérifie que des niveaux audio sont reçus ;
- publie un artifact `MixPilot-Serato-Hardware-Report`.

## Sécurité

- aucun mot de passe Spotify n'est lu par le workflow ;
- aucun flux audio brut n'est sauvegardé ;
- les certificats Apple restent dans GitHub Secrets ou le Trousseau ;
- les rapports doivent être relus avant publication dans une issue publique ;
- supprimer le runner de GitHub lorsqu'il n'est plus utilisé.
