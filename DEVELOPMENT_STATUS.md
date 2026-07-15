# Development Status

Dernière mise à jour : 2026-07-15

## État global

**Phase 8 — Release candidate RC2 automatisée, validation matérielle requise**

Branche active : `release/0.3.0-rc.2`

Pull Request de release : **#17** vers `main`.

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
- [x] Build Release, `.app`, `.dmg`, manifest et checksum en CI

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

Commit RC2 validé : `b57bec0bc9c2ccc42a676df3ae5b2bf42d4cc82d`.

- `AUTOMATED_SUCCESS` : `swift test --parallel` sur macOS.
- `SIMULATED_SUCCESS` : set de 50 titres avec incidents injectés.
- `SIMULATED_SUCCESS` : set de 250 titres avec incidents injectés.
- `AUTOMATED_SUCCESS` : build Release `MixPilotAutopilot`.
- `AUTOMATED_SUCCESS` : build Release `MixPilotHardwareProbeCLI`.
- `AUTOMATED_SUCCESS` : création du DMG RC2.
- `AUTOMATED_SUCCESS` : validation du checksum SHA-256.
- `AUTOMATED_SUCCESS` : génération XcodeGen et build iOS Simulator.
- `AUTOMATED_SUCCESS` : contrats Remote v1 et ordre des snapshots.

Runs GitHub :

- macOS CI : `29459695495` ;
- iPhone Remote CI : `29459695476` ;
- Build DMG RC2 : `29459693654`.

Artifact RC2 : `MixPilot-Autopilot-0.3.0-rc.2`.

SHA-256 : `22bddc049c82ae990bb4229de820fa9964fc81886101598c77aef12113dbff8b`.

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
- `REQUIRES_DEVICE_VALIDATION` : Developer ID et notarisation, absents de la RC interne.

## Prochaine étape

La PR #17 reste ouverte et ne doit pas être fusionnée vers `main`.

Le prochain travail indispensable est la campagne matérielle unique décrite dans `Documentation/FINAL_VALIDATION.md` : MacBook Pro M1, Serato DJ Pro, Spotify Premium, système audio réel et iPhone physique.
