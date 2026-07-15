# MixPilot Remote Protocol v1

Ce document est la source canonique du contrat réseau entre MixPilot Autopilot sur Mac et MixPilot Remote sur iPhone.

## Principes invariants

- transport uniquement sur le réseau local ;
- découverte Bonjour `_mixpilot._tcp` ;
- WebSocket avec sous-protocole `mixpilot-remote-v1` ;
- le Mac est la seule source de vérité ;
- aucun message ne contient de MIDI brut ;
- aucune perte réseau ne change automatiquement le Live Mac ;
- toute commande reçoit un `ack` accepté ou refusé ;
- protocole `version: 1` obligatoire ;
- dates encodées en ISO 8601 ;
- commandes de plus de dix secondes refusées ;
- UUID de commande dédupliqués ;
- snapshots dont la séquence est inférieure au dernier snapshot accepté ignorés.

## Appairage et rôles

1. l’iPhone envoie `hello` ;
2. le Mac répond `pairing_required` si aucun jeton valide n’est fourni ;
3. le Mac affiche un code à six chiffres valable deux minutes ;
4. l’iPhone envoie `pair` ;
5. le Mac renvoie `paired` avec un jeton aléatoire de 256 bits ;
6. le jeton est enregistré dans les Trousseaux iOS et macOS ;
7. le premier appareil appairé devient l’appareil principal ;
8. les appareils suivants reçoivent les snapshots mais restent en lecture seule ;
9. après reconnexion, l’iPhone envoie `authenticate` ;
10. le Mac répond `authenticated`, puis l’iPhone envoie `subscribe`.

Les codes et jetons ne doivent jamais apparaître dans les logs ou diagnostics.

## Messages client vers Mac

### `hello`

```json
{
  "version": 1,
  "type": "hello",
  "deviceID": "uuid-appareil",
  "deviceName": "iPhone de Lucas"
}
```

### `pair`

```json
{
  "version": 1,
  "type": "pair",
  "deviceID": "uuid-appareil",
  "deviceName": "iPhone de Lucas",
  "pin": "482913"
}
```

### `authenticate`

```json
{
  "version": 1,
  "type": "authenticate",
  "deviceID": "uuid-appareil",
  "token": "jeton-du-trousseau"
}
```

### `subscribe`

```json
{
  "version": 1,
  "type": "subscribe",
  "lastSequence": 41
}
```

### `command`

```json
{
  "version": 1,
  "type": "command",
  "command": {
    "id": "uuid-commande",
    "kind": "takeManualControl",
    "issuedAt": "2026-07-15T22:31:05Z"
  }
}
```

Commandes v1 :

| Commande | Statut RC2 | Sémantique |
|---|---|---|
| `takeManualControl` | `AUTOMATED_SUCCESS`, puis `REQUIRES_DEVICE_VALIDATION` | Arrête les futures automatisations ; une transition déjà engagée se termine pour éviter une coupure brutale. Idempotente. |
| `pauseAutopilot` | `AUTOMATED_SUCCESS`, puis `REQUIRES_SERATO_VALIDATION` | Pause coopérative uniquement à un point sûr ; aucune nouvelle commande MIDI automatique. |
| `resumeAutopilot` | `AUTOMATED_SUCCESS`, puis `REQUIRES_SERATO_VALIDATION` | Relecture de Serato, morceau/checkpoint, MIDI et watchdog obligatoires. Aucune reprise au milieu d’une courbe. |
| `skipTransition` | `AUTOMATED_SUCCESS`, puis `REQUIRES_SERATO_VALIDATION` | Remplace uniquement la transition suivante par un Safe Fade contrôlé ; aucun changement de titre ni saut d’index. |
| `safeFade` | `REQUIRES_DEVICE_VALIDATION` | Verrouillée tant que le routage audio réel et l’absence de blanc ne sont pas validés. |

## Messages Mac vers client

Messages :

- `hello` ;
- `pairing_required` ;
- `paired` ;
- `authenticated` ;
- `snapshot` ;
- `ack` ;
- `error` ;
- `pong`.

### `snapshot`

Le snapshot contient :

- `sequence` ;
- `updatedAt` ;
- `mode` : `idle`, `preflight`, `live`, `paused`, `manualControl`, `recovery` ;
- `setName` ;
- `currentTrack` et `nextTrack` ;
- `elapsed`, `duration` ;
- transition et confiance ;
- alerte éventuelle ;
- capacités `canPause`, `canResume`, `canSkipTransition`, `canSafeFade`, `canTakeManualControl`.

Les capacités affichées sont indicatives. Le Mac revalide toujours l’état réel au moment de la commande.

### `ack`

```json
{
  "version": 1,
  "type": "ack",
  "acknowledgement": {
    "commandID": "uuid-commande",
    "accepted": false,
    "message": "Reprise refusée : le morceau visible dans Serato ne correspond pas au checkpoint."
  }
}
```

Un refus n’est jamais transformé en succès visuel.

## Fixtures contractuelles

Le fichier partagé suivant contient tous les messages v1 :

```text
Shared/RemoteProtocolV1/Fixtures/protocol-v1-fixtures.json
```

Il est décodé par les tests Swift du bridge Mac et par les tests du projet iPhone. Toute modification incompatible exige une nouvelle version de protocole.
