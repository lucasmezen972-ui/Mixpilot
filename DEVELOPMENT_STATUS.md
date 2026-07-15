# Development Status

Dernière mise à jour : 2026-07-15

## État global

**Phase 7 — Intégration RC2 automatisée, validation matérielle différée**

Branche active : `integration/0.3.0-rc.2`

Pull Request d’intégration : **#14** vers `develop`.

## Réalisé sur macOS

- [x] Package Swift 6 modulaire et application SwiftUI macOS 14+
- [x] Port virtuel CoreMIDI `MixPilot Virtual Controller`
- [x] Assistant de mapping avec confirmations réelles séparées du simple profil
- [x] Génération et exécution beat-par-beat des automations MIDI
- [x] Préparation des cue markers, transitions et timeline de set
- [x] Analyse audio locale temporaire sans conservation du flux brut
- [x] Optimisation non destructive de playlist
- [x] Répétition mesurée et inspecteur de variantes de transition
- [x] Coordinateur Live avec alternance des decks et checkpoints persistants
- [x] Pause coopérative sans annulation de la Task principale
- [x] Reprise protégée par observation Serato, checkpoint, MIDI et watchdog
- [x] Skip Transition remplaçant uniquement la technique par un Safe Fade contrôlé
- [x] Contrôle manuel distant idempotent
- [x] Watchdog silence, clipping et perte de source
- [x] Bibliothèque locale de secours multi-fichiers
- [x] Préflight bloquant
- [x] Centre de récupération prudent après interruption
- [x] Diagnostics anonymisés et journal d’incidents
- [x] Matrice automatisée de treize scénarios de panne
- [x] Probe matériel `MixPilotHardwareProbeCLI`
- [x] Workflow Serato pour runner Mac auto-hébergé
- [x] Build Release, `.app`, `.dmg` et checksum en CI

## Réalisé pour l’iPhone et le bridge

- [x] Application iOS 17 isolée dans `Mobile/MixPilotRemote`
- [x] Génération XcodeGen et compilation iOS Simulator
- [x] Déclaration Réseau local et Bonjour `_mixpilot._tcp`
- [x] Découverte locale et client WebSocket v1
- [x] Jetons stockés dans les Trousseaux iOS et macOS
- [x] Bridge macOS dans le target séparé `MixPilotRemoteBridge`
- [x] Bridge désactivé par défaut et activation explicite sur le Mac
- [x] Code à six chiffres limité à deux minutes
- [x] Jetons aléatoires de 256 bits
- [x] Appareil principal et appareils secondaires en lecture seule
- [x] Refus des commandes anciennes, dupliquées ou non authentifiées
- [x] Protection stricte contre les snapshots anciens et dupliqués
- [x] Fixtures JSON Remote v1 décodées côté Mac et côté iPhone
- [x] Perte réseau sans commande métier ni modification automatique du Live Mac
- [x] Safe Fade distant maintenu verrouillé jusqu’à validation audio réelle

## Validation automatisée vérifiée

Résultats du commit d’intégration `aa49c80cd09bd1690c377a7aca4bbe45800348e5` :

- `AUTOMATED_SUCCESS` : `swift test --parallel` sur macOS.
- `SIMULATED_SUCCESS` : set de 50 titres avec incidents injectés.
- `SIMULATED_SUCCESS` : set de 250 titres avec incidents injectés.
- `AUTOMATED_SUCCESS` : build Release `MixPilotAutopilot`.
- `AUTOMATED_SUCCESS` : build Release `MixPilotHardwareProbeCLI`.
- `AUTOMATED_SUCCESS` : création du DMG de développement.
- `AUTOMATED_SUCCESS` : validation du checksum SHA-256.
- `AUTOMATED_SUCCESS` : génération XcodeGen et build iOS Simulator.
- `AUTOMATED_SUCCESS` : contrats Remote v1 et ordre des snapshots.

Artifacts GitHub produits :

- `MixPilot-Autopilot-development` ;
- `MixPilot-Validation-Reports` ;
- `iphone-remote-validation-logs`.

## Limitations encore réelles

- `REQUIRES_SERATO_VALIDATION` : visibilité et mapping du port CoreMIDI dans Serato.
- `REQUIRES_SERATO_VALIDATION` : chargement répétable du bon titre Spotify sur le bon deck.
- `REQUIRES_SERATO_VALIDATION` : données réellement exposées par AXUIElement selon la version et la disposition Serato.
- `REQUIRES_SERATO_VALIDATION` : Pause, Reprise et Skip Transition avec l’état réel des decks.
- `REQUIRES_DEVICE_VALIDATION` : routage du master Serato vers le watchdog.
- `REQUIRES_DEVICE_VALIDATION` : absence de blanc lors du secours et du Safe Fade.
- `REQUIRES_DEVICE_VALIDATION` : découverte Bonjour, appairage et perte Wi-Fi sur Mac/iPhone physiques.
- `REQUIRES_DEVICE_VALIDATION` : endurance de deux heures sur MacBook Pro M1.
- `REQUIRES_DEVICE_VALIDATION` : Safe Fade distant, qui reste refusé en RC2 tant que le routage réel n’est pas validé.

## Prochaines étapes

1. Mettre les documents de statut et les README en cohérence.
2. Fusionner la PR #14 entièrement verte dans `develop`.
3. Fermer ou marquer comme remplacées les PR #9, #11, #12 et #13.
4. Créer `release/0.3.0-rc.2` depuis le nouveau `develop`.
5. Exécuter le workflow de release et vérifier le DMG, le manifest et le checksum.
6. Ouvrir une PR RC2 vers `main` sans la fusionner.
7. Déclencher une seule campagne humaine MacBook Pro M1 + Serato + iPhone.
