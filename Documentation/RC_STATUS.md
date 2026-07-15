# MixPilot 0.3.0-rc.2 — Statut vérifié

## Nature de ce document

Ce fichier décrit l’état réel de la branche d’intégration avant création de la branche `release/0.3.0-rc.2`.

Branche actuelle : `integration/0.3.0-rc.2`

PR d’intégration : **#14** vers `develop`.

La RC2 n’est pas encore publiée et aucune fusion vers `main` n’a été effectuée.

## Composants réellement présents

### Mac

- target `MixPilotAutopilot` ;
- target `MixPilotHardwareProbeCLI` ;
- target `MixPilotRemoteBridge` ;
- préparation de set et transitions ;
- mapping MIDI et confirmations ;
- préflight, watchdog et secours ;
- répétition, inspecteur et analyse de préparation ;
- checkpoints, récupération et diagnostics ;
- contrôles distants de haut niveau avec protections.

### iPhone

- projet XcodeGen `Mobile/MixPilotRemote` ;
- iOS 17+ ;
- Réseau local et Bonjour `_mixpilot._tcp` ;
- Keychain ;
- découverte, appairage, authentification et snapshots ;
- mode démo explicitement identifié ;
- tests SwiftPM portant sur les fichiers de modèles réellement compilés par l’app.

## Résultats exacts de CI

### macOS CI

Run GitHub Actions : `29457501030`

- tests unitaires : `AUTOMATED_SUCCESS` ;
- simulation 50 titres : `SIMULATED_SUCCESS` ;
- simulation 250 titres : `SIMULATED_SUCCESS` ;
- build Release application : `AUTOMATED_SUCCESS` ;
- build Release probe : `AUTOMATED_SUCCESS` ;
- package DMG : `AUTOMATED_SUCCESS` ;
- checksum : `AUTOMATED_SUCCESS` ;
- artifacts : `AUTOMATED_SUCCESS`.

### iPhone Remote CI

Run GitHub Actions : `29457501093`

- génération XcodeGen : `AUTOMATED_SUCCESS` ;
- build iOS Simulator : `AUTOMATED_SUCCESS` ;
- contrats Remote v1 : `AUTOMATED_SUCCESS` ;
- protection snapshots anciens/dupliqués : `AUTOMATED_SUCCESS`.

## Commandes distantes

| Commande | Présence | Statut réel |
|---|---|---|
| `takeManualControl` | Implémentée | `AUTOMATED_SUCCESS`, `REQUIRES_DEVICE_VALIDATION` |
| `pauseAutopilot` | Implémentée, coopérative | `AUTOMATED_SUCCESS`, `REQUIRES_SERATO_VALIDATION` |
| `resumeAutopilot` | Implémentée avec vérifications | `AUTOMATED_SUCCESS`, `REQUIRES_SERATO_VALIDATION` |
| `skipTransition` | Implémentée sans saut de titre | `AUTOMATED_SUCCESS`, `REQUIRES_SERATO_VALIDATION` |
| `safeFade` | Refus explicite | `REQUIRES_DEVICE_VALIDATION` |

## Ce qui n’est pas encore un succès réel

- aucun test Serato réel n’a été exécuté par un runner public ;
- aucun compte Spotify n’a été utilisé dans la CI ;
- le port MIDI n’a pas encore été mappé dans Serato sur le Mac cible ;
- le routage audio réel n’est pas validé ;
- l’appairage n’a pas encore été testé sur les deux appareils physiques ;
- l’endurance de deux heures n’est pas encore validée ;
- aucune signature Developer ID ou notarisation n’est affirmée sans secrets Apple.

## Conditions de création de la RC2

1. PR #14 fusionnée dans `develop` après CI verte ;
2. anciennes PR marquées comme reprises ou remplacées ;
3. branche `release/0.3.0-rc.2` créée depuis ce `develop` ;
4. workflow de release exécuté avec `version=0.3.0-rc.2` ;
5. DMG, manifest et checksum produits ;
6. PR RC2 ouverte vers `main` et laissée non fusionnée ;
7. campagne humaine unique déclenchée selon `FINAL_VALIDATION.md`.
