# MixPilot 0.3.0-rc.2 — Statut de release candidate

## Identité

- Version : `0.3.0-rc.2`
- Branche : `release/0.3.0-rc.2`
- Base : `develop` consolidé par la PR #14
- Fusion vers `main` : **interdite avant validation du workflow de release et campagne matérielle**

## Consolidation effectuée

- PR #14 fusionnée dans `develop` au commit `06e980d068b86cf0c06237ffa563d5b31f2d35ef` ;
- PR #9 remplacée après port manuel de ses éléments utiles ;
- PR #11 reprise et consolidée pour l’iPhone ;
- PR #12 RC1 fermée comme obsolète ;
- PR #13 reprise et enrichie pour le bridge Mac.

## Composants réellement présents

### Mac

- target `MixPilotAutopilot` ;
- target `MixPilotHardwareProbeCLI` ;
- target `MixPilotRemoteBridge` ;
- préparation de set, analyse et transitions ;
- mapping MIDI avec confirmations ;
- préflight, watchdog et secours ;
- répétition, inspecteur et analyse de préparation ;
- checkpoints, récupération et diagnostics ;
- commandes distantes de haut niveau protégées.

### iPhone

- projet XcodeGen `Mobile/MixPilotRemote` ;
- iOS 17+ ;
- Réseau local et Bonjour `_mixpilot._tcp` ;
- stockage Keychain ;
- découverte, appairage, authentification et snapshots ;
- mode démo explicitement identifié comme simulation ;
- package SwiftPM testant les fichiers de modèles réellement utilisés par l’app.

## Résultats automatisés avant gel

### macOS CI

Dernier run vert d’intégration : `29457958857`.

- tests unitaires : `AUTOMATED_SUCCESS` ;
- simulation 50 titres : `SIMULATED_SUCCESS` ;
- simulation 250 titres : `SIMULATED_SUCCESS` ;
- build Release application : `AUTOMATED_SUCCESS` ;
- build Release probe : `AUTOMATED_SUCCESS` ;
- package DMG : `AUTOMATED_SUCCESS` ;
- validation checksum : `AUTOMATED_SUCCESS` ;
- artifacts : `AUTOMATED_SUCCESS`.

### iPhone Remote CI

Dernier run vert d’intégration : `29457958882`.

- génération XcodeGen : `AUTOMATED_SUCCESS` ;
- build iOS Simulator : `AUTOMATED_SUCCESS` ;
- contrats Remote v1 : `AUTOMATED_SUCCESS` ;
- snapshots anciens/dupliqués : `AUTOMATED_SUCCESS`.

## Commandes distantes

| Commande | Présence | Statut RC2 |
|---|---|---|
| `takeManualControl` | Implémentée et idempotente | `AUTOMATED_SUCCESS`, `REQUIRES_DEVICE_VALIDATION` |
| `pauseAutopilot` | Implémentée, coopérative | `AUTOMATED_SUCCESS`, `REQUIRES_SERATO_VALIDATION` |
| `resumeAutopilot` | Implémentée avec revalidation | `AUTOMATED_SUCCESS`, `REQUIRES_SERATO_VALIDATION` |
| `skipTransition` | Même titre, transition remplacée | `AUTOMATED_SUCCESS`, `REQUIRES_SERATO_VALIDATION` |
| `safeFade` | Refus explicite | `REQUIRES_DEVICE_VALIDATION` |

## Release workflow

État : `PENDING` au moment de ce commit.

Le workflow doit encore produire sur cette branche :

- `MixPilot-Autopilot.dmg` ;
- `MixPilot-Autopilot.dmg.sha256` ;
- `release-manifest.json` ;
- détails de signature ;
- artifact de release `0.3.0-rc.2`.

L’absence de secrets Apple implique une signature ad hoc et aucune notarisation revendiquée.

## Ce qui n’est pas encore `REAL_SUCCESS`

- mapping et contrôle Serato réels ;
- chargement Spotify répétable ;
- routage audio réel ;
- absence de blanc sur le système de son cible ;
- appairage Mac/iPhone physiques ;
- perte et retour Wi-Fi réels ;
- endurance de deux heures ;
- Safe Fade distant ;
- Developer ID et notarisation si les secrets Apple ne sont pas configurés.

## Blocage suivant attendu

Après workflow de release vert et validation du checksum RC2, la seule étape restante sera la campagne humaine unique définie dans `Documentation/FINAL_VALIDATION.md`.
