# Bridge MixPilot Mac–iPhone

## Architecture vérifiée

Le bridge se trouve dans le target macOS séparé :

```text
Sources/MixPilotRemoteBridge/
```

L’application iPhone reste indépendante :

```text
Mobile/MixPilotRemote/
```

Le moteur `MixPilotCore` ne dépend pas du projet iOS. Le bridge ne reçoit que des intentions de haut niveau et ne connaît aucune commande MIDI brute.

## Activation

Le bridge est désactivé au lancement. Il est activé explicitement depuis le menu MixPilot sur le Mac. L’activation :

- crée un listener Network.framework local ;
- publie `_mixpilot._tcp` par Bonjour ;
- génère un code d’appairage à six chiffres ;
- démarre l’envoi périodique des snapshots.

La désactivation ferme le listener et toutes les sessions. Elle ne modifie pas le Live.

## Sécurité réellement implémentée

- code d’appairage valable deux minutes ;
- comparaison du code et des jetons en temps constant ;
- jeton aléatoire de 32 octets, soit 256 bits ;
- stockage dans le Trousseau macOS et iOS ;
- premier appareil principal ;
- appareils secondaires en lecture seule ;
- commandes de plus de dix secondes refusées ;
- UUID déjà reçu refusé ;
- JSON invalide et version inconnue refusés ;
- commande avant authentification refusée ;
- snapshots séquencés ;
- aucun code ou jeton dans le journal applicatif.

## Commandes

### Contrôle manuel

La commande est idempotente. Elle demande au coordinateur de cesser toute future automation. Lorsqu’une courbe de transition est déjà engagée, celle-ci peut se terminer afin d’éviter une rupture sonore, puis aucune nouvelle commande n’est émise.

### Pause

La Pause est coopérative :

- elle n’annule pas la Task principale ;
- elle n’interrompt pas une courbe MIDI active ;
- elle est acceptée uniquement en lecture stable ou en attente de transition ;
- elle sauvegarde un checkpoint `.paused` ;
- les attentes du coordinateur cessent de progresser tant que la pause est active.

### Reprise

La Reprise exige :

- un checkpoint de pause ;
- le morceau attendu visible dans Serato ;
- le même deck interne que le checkpoint ;
- un mapping MIDI réellement confirmé ;
- un watchdog audio actif ;
- aucun arrêt au milieu d’une courbe MIDI.

Un échec de vérification produit un `ack` refusé.

### Skip Transition

En RC2, Skip ne saute aucun titre. Il remplace la transition planifiée vers le même morceau entrant par un Safe Fade contrôlé. Il est refusé tant que le morceau entrant n’est pas confirmé ou que le moteur n’est pas en attente de transition.

### Safe Fade distant

La commande directe reste verrouillée avec le statut `REQUIRES_DEVICE_VALIDATION`. Elle ne sera activée qu’après validation du routage audio réel, de la préparation du titre entrant ou du secours local, et de l’absence de blanc.

## Perte réseau

Une déconnexion, l’arrêt du listener, le verrouillage de l’iPhone ou une perte Wi-Fi :

- supprime uniquement la session distante ;
- n’appelle aucune commande métier ;
- ne met pas le Live en pause ;
- ne change pas de titre ;
- ne déclenche pas le secours ;
- n’envoie aucun MIDI.

Le Mac continue selon son état local.

## Validation

- compilation et tests publics : `AUTOMATED_SUCCESS` ;
- politiques de commandes : `AUTOMATED_SUCCESS` ;
- découverte Bonjour, appairage physique et perte Wi-Fi : `REQUIRES_DEVICE_VALIDATION` ;
- concordance réelle avec Serato : `REQUIRES_SERATO_VALIDATION`.
