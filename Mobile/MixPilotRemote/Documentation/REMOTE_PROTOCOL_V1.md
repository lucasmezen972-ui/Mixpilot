# MixPilot Remote Protocol v1

## Rôle des composants

- **Mac MixPilot** : source de vérité, propriétaire du set, du moteur Autopilot, du MIDI, des protections et de la récupération.
- **iPhone Remote** : écran de surveillance et émetteur d’intentions haut niveau.
- **Serato** : n’est jamais contacté directement par l’iPhone.

Cette séparation empêche une perte réseau, un double tap ou une ancienne information affichée sur l’iPhone de produire directement une commande MIDI dangereuse.

## Transport

- découverte Bonjour : `_mixpilot._tcp` ;
- connexion WebSocket locale : `ws://<mac>:<port>/v1/remote` ;
- sous-protocole WebSocket : `mixpilot-remote-v1` ;
- messages JSON UTF-8 ;
- dates ISO 8601 ;
- champ `version` obligatoire et égal à `1`.

Une future version distribuée pourra remplacer `ws` par `wss` sans changer les messages métier.

## Appairage

1. Le Mac affiche un code aléatoire à six chiffres, valable deux minutes.
2. L’iPhone envoie `hello` avec son identifiant stable et son nom.
3. Le Mac répond `pairing_required` si aucun jeton valide n’est fourni.
4. L’iPhone envoie `pair` avec le code.
5. Le Mac renvoie `paired` et un jeton propre à cet appareil.
6. L’iPhone conserve ce jeton dans le Trousseau iOS.
7. Les connexions suivantes utilisent `authenticate`.

Le Mac doit permettre de révoquer individuellement chaque iPhone appairé.

## Messages client

### Hello

```json
{
  "version": 1,
  "type": "hello",
  "deviceID": "UUID",
  "deviceName": "iPhone de Lucas"
}
```

### Appairage

```json
{
  "version": 1,
  "type": "pair",
  "deviceID": "UUID",
  "deviceName": "iPhone de Lucas",
  "pin": "482913"
}
```

### Authentification

```json
{
  "version": 1,
  "type": "authenticate",
  "deviceID": "UUID",
  "token": "opaque-random-token"
}
```

### Abonnement à l’état

```json
{
  "version": 1,
  "type": "subscribe",
  "lastSequence": 41
}
```

### Commande

```json
{
  "version": 1,
  "type": "command",
  "command": {
    "id": "UUID",
    "kind": "pauseAutopilot",
    "issuedAt": "2026-07-15T22:30:00Z"
  }
}
```

Commandes v1 :

- `pauseAutopilot` ;
- `resumeAutopilot` ;
- `skipTransition` ;
- `safeFade` ;
- `takeManualControl`.

## Messages serveur

Types prévus :

- `hello` ;
- `pairing_required` ;
- `paired` ;
- `authenticated` ;
- `snapshot` ;
- `ack` ;
- `error` ;
- `pong`.

### Snapshot

Chaque snapshot contient un numéro `sequence` strictement croissant. L’iPhone ignore tout snapshot plus ancien que celui déjà affiché.

```json
{
  "version": 1,
  "type": "snapshot",
  "snapshot": {
    "sequence": 42,
    "updatedAt": "2026-07-15T22:31:03Z",
    "mode": "live",
    "setName": "Baptême — Set principal",
    "currentTrack": {
      "title": "Water",
      "artist": "Tyla",
      "bpm": 117
    },
    "nextTrack": {
      "title": "One Track Mind",
      "artist": "Naïka",
      "bpm": 116
    },
    "elapsed": 74,
    "duration": 201,
    "transitionLabel": "Smooth Blend dans 1 min 12",
    "transitionConfidence": 91,
    "alert": null,
    "canPause": true,
    "canResume": false,
    "canSkipTransition": true,
    "canSafeFade": true,
    "canTakeManualControl": true
  }
}
```

### Accusé de réception

```json
{
  "version": 1,
  "type": "ack",
  "acknowledgement": {
    "commandID": "UUID",
    "accepted": true,
    "message": "Autopilote mis en pause"
  }
}
```

## Invariants de sécurité côté Mac

1. Une commande déjà vue avec le même `command.id` ne doit jamais être exécutée deux fois.
2. Une commande de plus de dix secondes doit être refusée.
3. Le Mac vérifie l’état réel avant toute exécution et peut refuser une commande même si l’iPhone l’affiche comme disponible.
4. `takeManualControl` a priorité sur toutes les autres commandes.
5. `safeFade` passe obligatoirement par les protections audio et la vérification du secours local.
6. Une perte de connexion ne modifie pas automatiquement l’état du set.
7. Aucun MIDI brut, nom de note MIDI ou valeur de contrôleur ne traverse le protocole mobile.
8. Un seul appareil peut être déclaré contrôleur principal ; les autres restent en lecture seule, sauf transfert explicite.
9. Les commandes sont journalisées dans le diagnostic avec l’identifiant d’appareil, sans stocker le jeton.
10. L’iPhone ne peut pas contourner le préflight ni démarrer un Live non prêt dans la version 1.
