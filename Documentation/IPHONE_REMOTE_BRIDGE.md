# Bridge MixPilot Mac–iPhone

## Architecture

Le bridge macOS se trouve dans :

```text
Sources/MixPilotRemoteBridge/
```

L’application iPhone se trouve dans :

```text
Mobile/MixPilotRemote/
```

Le contrat partagé se trouve dans :

```text
Shared/RemoteProtocolV2/
```

Le moteur ne dépend pas du projet iOS. Le bridge reçoit uniquement des intentions de haut niveau et ne connaît aucun message MIDI brut.

## Source de vérité

Le Mac reste l’unique composant autorisé à :

- connaître le backend actif ;
- lire ses capacités ;
- vérifier l’état réel ;
- accepter ou refuser une commande ;
- gérer les checkpoints ;
- déclencher le secours ;
- rendre le contrôle manuel.

L’iPhone fonctionne de la même manière avec djay Pro, rekordbox et Serato DJ Pro.

## Activation

Le bridge est activé explicitement depuis le Mac. L’activation :

- crée un listener Network.framework local ;
- publie `_mixpilot._tcp` par Bonjour ;
- génère un code d’appairage à six chiffres ;
- démarre l’envoi de snapshots ordonnés.

La désactivation ferme le listener et les sessions distantes. Elle ne modifie pas le Live.

## Sécurité

- code d’appairage limité dans le temps ;
- comparaison en temps constant ;
- jeton aléatoire de 256 bits ;
- stockage dans les Trousseaux macOS et iOS ;
- premier appareil principal ;
- appareils secondaires en lecture seule ;
- commandes anciennes refusées ;
- UUID dédupliqués ;
- JSON invalide ou version inconnue refusés ;
- commande avant authentification refusée ;
- snapshots séquencés ;
- aucun code ou jeton dans les diagnostics.

## Snapshot v2

Le snapshot peut contenir :

- backend actif ;
- version du logiciel ;
- mode utilisé ;
- morceau actuel et suivant ;
- deck actif ;
- progression ;
- transition prévue ;
- état audio ;
- capacités temporairement dégradées ;
- actions autorisées par le Mac.

Ces capacités restent indicatives. Le Mac revalide toujours la demande au moment de son exécution.

## Commandes

### Reprendre la main

La commande est idempotente. Elle cesse les futures automatisations. Si une transition est déjà engagée, MixPilot termine uniquement la partie nécessaire pour éviter une coupure brutale, puis n’envoie plus de nouvelle commande.

### Mettre en pause

La pause est coopérative :

- elle n’annule pas brutalement la tâche Live ;
- elle n’interrompt pas une courbe déjà engagée ;
- elle est acceptée seulement à un point sûr ;
- elle sauvegarde un checkpoint ;
- le temps du moteur cesse de progresser pendant la pause.

### Reprendre

La reprise exige :

- un checkpoint de pause ;
- le morceau attendu confirmé dans le backend actif ;
- le même deck que le checkpoint ;
- les commandes requises encore confirmées ;
- la surveillance audio active ;
- aucun retour au milieu d’une courbe interrompue.

Un échec produit un accusé refusé avec une explication humaine.

### Changer la prochaine transition

Cette commande ne saute aucun morceau. Elle remplace la transition vers le même morceau entrant par une variante de secours sûre. Elle est refusée tant que le morceau entrant n’est pas confirmé ou que le moteur n’attend pas la transition.

### Transition de secours

La commande directe reste désactivée tant que le routage audio réel, le morceau entrant et l’absence de blanc ne sont pas validés sur la configuration cible.

## Perte réseau

Une déconnexion, le verrouillage de l’iPhone ou une perte Wi-Fi :

- ferme uniquement la session distante ;
- n’appelle aucune commande métier ;
- ne met pas le Live en pause ;
- ne change pas de morceau ;
- ne déclenche pas le secours ;
- n’envoie aucun MIDI.

Le Mac continue selon son état local.

## Validation

- encodage, décodage, ordre et déduplication : `AUTOMATED_SUCCESS` lorsque les tests passent ;
- scénarios de perte iPhone simulés : `SIMULATED_SUCCESS` ;
- Bonjour, appairage physique, arrière-plan et perte Wi-Fi : `REQUIRES_DEVICE_VALIDATION` ;
- concordance avec le backend réel : `REQUIRES_BACKEND_VALIDATION` puis `REQUIRES_DEVICE_VALIDATION`.
