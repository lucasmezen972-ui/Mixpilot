# Runner GitHub Mac pour les validations Serato réelles

Statut de cette procédure : `REQUIRES_DEVICE_VALIDATION`.

Le workflow `Serato Hardware Validation` s’exécute sur un Mac réel connecté à une session graphique. Il ne doit pas être installé comme démon système sans utilisateur : Serato DJ Pro, les permissions d’Accessibilité, CoreMIDI et le routage audio dépendent de la session macOS active.

## Prérequis

- Mac Apple Silicon sous macOS 14 ou supérieur ;
- session utilisateur graphique et déverrouillée ;
- Xcode et Command Line Tools ;
- Serato DJ Pro installé ;
- Spotify Premium connecté dans Serato ;
- permissions macOS déjà accordées à MixPilot et au terminal du runner ;
- dépôt GitHub accessible ;
- sortie audio et source de surveillance configurées.

## Ajout du runner

Dans GitHub :

1. ouvrir `Settings` du dépôt ;
2. choisir `Actions`, puis `Runners` ;
3. cliquer sur `New self-hosted runner` ;
4. sélectionner macOS ARM64 ;
5. exécuter les commandes fournies par GitHub dans un dossier dédié ;
6. ajouter les labels `macOS` et `mixpilot-serato` pendant `config.sh`.

Le jeton d’enregistrement est temporaire et ne doit jamais être commité.

## Exécution interactive

```bash
cd ~/actions-runner-mixpilot
./run.sh
```

Pour un lancement à l’ouverture de session, utiliser un `LaunchAgent` utilisateur. Éviter `svc.sh install`, qui peut démarrer le runner en dehors de la session graphique requise.

## Préparation avant le workflow strict

1. brancher le Mac au secteur ;
2. lancer Serato DJ Pro ;
3. connecter Spotify ;
4. ouvrir la playlist de validation ;
5. vérifier la sortie audio ;
6. vérifier Accessibilité et capture audio ;
7. laisser la session déverrouillée ;
8. vérifier que le runner affiche le statut `Idle` dans GitHub.

## Lancement

Lancer manuellement `Serato Hardware Validation` avec `strict=true`.

Le workflow doit :

- exécuter les tests Swift ;
- compiler MixPilot et `MixPilotHardwareProbeCLI` ;
- collecter versions macOS, MIDI, audio et alimentation ;
- observer le processus et la fenêtre Serato ;
- lire les lignes accessibles de la bibliothèque ;
- vérifier la création du port MIDI virtuel ;
- vérifier la réception de niveaux audio ;
- publier l’artifact `MixPilot-Serato-Hardware-Report`.

Un succès sur un runner public reste `AUTOMATED_SUCCESS` pour la compilation du probe. Seul ce workflow exécuté sur le Mac équipé de Serato peut produire `REAL_SUCCESS` pour l’environnement réel.

## Sécurité

- aucun mot de passe Spotify n’est lu ;
- aucun flux audio brut n’est sauvegardé ;
- aucun token de runner, certificat ou secret ne doit apparaître dans les logs ;
- relire les rapports avant de les publier dans le dépôt public ;
- supprimer ou désactiver le runner lorsqu’il n’est plus utilisé.
