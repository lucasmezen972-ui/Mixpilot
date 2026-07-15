# MixPilot 0.3.0-rc.2 — Statut de release candidate

## Identité

- Version : `0.3.0-rc.2`
- Branche : `release/0.3.0-rc.2`
- Base : `develop` consolidé par la PR #14
- Pull Request : #17 vers `main`
- Fusion vers `main` : **interdite avant la campagne matérielle guidée**

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

## Résultats automatisés de la RC2

Commit validé : `b57bec0bc9c2ccc42a676df3ae5b2bf42d4cc82d`.

### macOS CI

Run : `29459695495`.

- tests unitaires : `AUTOMATED_SUCCESS` ;
- simulation 50 titres : `SIMULATED_SUCCESS` ;
- simulation 250 titres : `SIMULATED_SUCCESS` ;
- build Release application : `AUTOMATED_SUCCESS` ;
- build Release probe : `AUTOMATED_SUCCESS` ;
- package DMG : `AUTOMATED_SUCCESS` ;
- validation checksum : `AUTOMATED_SUCCESS` ;
- artifact `MixPilot-Autopilot-development` : `AUTOMATED_SUCCESS`.

### iPhone Remote CI

Run : `29459695476`.

- génération XcodeGen : `AUTOMATED_SUCCESS` ;
- build iOS Simulator : `AUTOMATED_SUCCESS` ;
- contrats Remote v1 : `AUTOMATED_SUCCESS` ;
- snapshots anciens/dupliqués : `AUTOMATED_SUCCESS`.

## Commandes distantes

| Commande | Présence | Statut RC2 |
|---|---|---|
| `takeManualControl` | Implémentée et idempotente | `AUTOMATED_SUCCESS`, `REQUIRES_DEVICE_VALIDATION` |
| `pauseAutopilot` | Implémentée, coopérative, sans annuler la Task principale | `AUTOMATED_SUCCESS`, `REQUIRES_SERATO_VALIDATION` |
| `resumeAutopilot` | Implémentée avec revalidation Serato, deck, MIDI et watchdog | `AUTOMATED_SUCCESS`, `REQUIRES_SERATO_VALIDATION` |
| `skipTransition` | Conserve le titre et remplace la technique par un Safe Fade contrôlé | `AUTOMATED_SUCCESS`, `REQUIRES_SERATO_VALIDATION` |
| `safeFade` | Refus explicite | `REQUIRES_DEVICE_VALIDATION` |

## Release workflow

Run : `29459693654`.

- artifact : `MixPilot-Autopilot-0.3.0-rc.2` ;
- DMG : `AUTOMATED_SUCCESS` ;
- manifest : `AUTOMATED_SUCCESS` ;
- checksum SHA-256 : `22bddc049c82ae990bb4229de820fa9964fc81886101598c77aef12113dbff8b` ;
- signature : ad hoc de développement ;
- notarisation : non effectuée et non revendiquée ;
- Developer ID : absent de cette RC interne.

## Ce qui n’est pas encore `REAL_SUCCESS`

- mapping et contrôle Serato réels ;
- chargement Spotify répétable ;
- routage audio réel ;
- absence de blanc sur le système de son cible ;
- appairage Mac/iPhone physiques ;
- perte et retour Wi-Fi réels ;
- endurance de deux heures ;
- Safe Fade distant ;
- Developer ID et notarisation.

## Blocage actuel

Tout le travail automatisable prévu pour RC2 est terminé et vert.

Le prochain blocage est matériel : campagne humaine unique définie dans `Documentation/FINAL_VALIDATION.md` sur MacBook Pro M1, Serato DJ Pro, Spotify Premium, système audio réel et iPhone physique.
