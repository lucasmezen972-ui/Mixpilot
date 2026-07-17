# MixPilot

**TRADIKOM BY LUCAS MEZEN**

MixPilot est un autopilote DJ local-first pour macOS, accompagné d’une télécommande iPhone facultative. Il aide à préparer, vérifier, sécuriser et superviser un set à travers un moteur commun et trois backends officiels :

- **djay Pro** ;
- **rekordbox** ;
- **Serato DJ Pro**.

MixPilot ne présente pas les trois logiciels comme techniquement identiques. Chaque backend expose ses capacités, ses limites, sa version, son mapping et les validations disponibles. Une fonction non confirmée reste bloquée ou utilise un fallback conservateur.

> Une compilation, un test automatisé ou une simulation ne vaut jamais validation matérielle. Aucun backend ni mapping n’est déclaré `REAL_SUCCESS` sans essai sur le Mac, le logiciel DJ, le contrôleur et le routage audio cibles.

## Parcours principal

L’application Mac est organisée autour de quatre espaces :

1. **Préparer** : choisir le logiciel DJ, importer une playlist, analyser le set et préparer les transitions ;
2. **Vérifier** : contrôler logiciel, version, permissions, MIDI, mapping, audio et musique de secours ;
3. **Live** : armer l’autopilote, suivre l’état réel et reprendre la main ;
4. **Avancé** : ouvrir les outils de mapping, répétition, analyse et diagnostic.

Le Mac reste la source de vérité. L’iPhone, Internet, Supabase et les services en ligne ne sont jamais requis pour maintenir un Live local déjà lancé.

## Backends officiels

### djay Pro

- Automix supervisé lorsque l’environnement observé le permet ;
- transitions MixPilot directes uniquement pour les commandes confirmées ;
- inspection Accessibilité en lecture seule avant toute automatisation ;
- aucun recours à une API djay ou Spotify inventée.

### rekordbox

- import XML et JSON adaptatif ;
- lecture de bibliothèque et de playlists ;
- génération locale d’un CSV MIDI à 15 colonnes ;
- validation, sauvegarde et restauration du mapping ;
- provenance GitHub et empreintes SHA-256 ;
- publication interdite tant que le comportement réel n’est pas validé.

### Serato DJ Pro

- contrôleur virtuel CoreMIDI ;
- import XML ;
- assistant de configuration ;
- sauvegarde et rollback du mapping ;
- observation protégée de l’interface ;
- validation commande par commande.

## Fiabilité du Live

Le runtime commun utilise notamment :

- une file de commandes sérialisée ;
- des identifiants d’idempotence et une déduplication ;
- des timeouts et retries bornés ;
- un circuit breaker ;
- une réconciliation périodique du backend et de l’état ;
- le rejet des observations anciennes ou non fiables ;
- une horloge monotone et l’abandon des frames périmées ;
- un watchdog audio à états ;
- une musique locale de secours ;
- une reprise manuelle coopérative au prochain point sûr ;
- aucun redémarrage automatique du Live après un crash.

Une perte de réseau ou de l’iPhone ne coupe pas le Live. La fermeture du logiciel DJ, la perte répétée de l’état, du MIDI ou de la source audio provoque une dégradation explicite, un secours local ou une reprise manuelle selon le risque.

## MixPilot Remote pour iPhone

L’application se trouve dans `Mobile/MixPilotRemote`.

Elle affiche le backend actif, les morceaux, le deck, la progression, l’état audio et les alertes. Elle envoie uniquement des intentions de haut niveau ; elle n’envoie jamais de MIDI brut et ne contacte jamais directement le logiciel DJ.

Le protocole partagé se trouve dans `Shared/RemoteProtocolV2`.

Le transport local non chiffré reste désactivé dans les builds normaux. Il ne peut être activé que pour un test de développement explicite sur un réseau isolé. La reconnexion est bornée et ne rejoue aucune ancienne commande.

## Centre d’aide et langues

MixPilot comprend un centre d’aide hors ligne partagé entre macOS et iPhone :

- recherche sans accents ;
- filtres par catégorie ;
- onze articles couvrant démarrage, logiciel DJ, mapping, préparation, transitions, vérification, Live, iPhone, reprise manuelle, secours et dépannage ;
- liens possibles depuis les erreurs et parcours de sécurité.

Les surfaces principales, le Remote, les menus, fenêtres et alertes de sécurité utilisent des clés stables Apple en :

- français ;
- anglais ;
- espagnol.

Les ressources sont séparées en quatre tables :

- `Localizable.strings` ;
- `Remote.strings` ;
- `Workspace.strings` ;
- `Commands.strings`.

Les scripts contrôlent la parité des clés, les doublons, les placeholders et les références utilisées dans le code.

## Services en ligne facultatifs

Les services en ligne servent uniquement à :

- vérifier les mises à jour ;
- récupérer des correctifs de compatibilité publiés ;
- synchroniser des métadonnées techniques autorisées ;
- suivre les incidents non musicaux.

Ils ne contrôlent jamais le Live. La télémétrie est désactivée par défaut et filtre titres, artistes, playlists, chemins locaux, audio, tokens, codes d’appairage et contenu Accessibilité.

Supabase utilise des politiques RLS et des contraintes propriétaire/appareil/session. La migration de durcissement a été appliquée sur le projet actif lors de la phase précédente, mais une reconstruction complète sur une base neuve reste à exécuter dès qu’un runner ou un environnement Docker approprié est disponible.

## Architecture

```text
MixPilotCore
├── modèles et contrats DJBackend
├── préparation et planification
├── transitions et sécurité
├── simulations et diagnostics purs
└── validation des mappings

MixPilotMIDI
└── contrôleur virtuel et commandes MIDI génériques

MixPilotSystem
├── adaptateurs djay, rekordbox et Serato
├── Accessibilité, audio, fichiers et Keychain
└── services en ligne facultatifs

MixPilotRuntime
├── coordinateur Live indépendant du backend
├── file de commandes et circuit breaker
└── réconciliation et reprise manuelle

MixPilotRemoteBridge
└── Bonjour, transport local, appairage et snapshots

MixPilotHelp
└── aide hors ligne et catalogues FR/EN/ES

MixPilotApp
└── Préparer, Vérifier, Live et Avancé
```

## Développement

Prérequis :

- Swift 6 ;
- macOS 14 ou supérieur pour l’application Mac ;
- Xcode et XcodeGen pour l’application iPhone ;
- Docker pour une reconstruction Supabase locale neuve.

### Audits portables

```bash
python3 Scripts/check_help_localizations.py
python3 Scripts/check_localization_consistency.py
python3 Scripts/final_repository_audit.py --strict
./Scripts/check_package_manifest.sh
./Scripts/check_source_architecture.sh
./Scripts/check_runtime_safety.sh
./Scripts/check_documentation_consistency.sh
./Scripts/check_transport_reliability.sh
./Scripts/check_validation_context.sh
```

`final_repository_audit.py` contrôle notamment :

- workflows manuels uniquement tant que les runners restent bloqués ;
- secrets et blocs de clés privées complets ;
- chemins personnels ;
- fichiers `.env` ;
- artefacts générés suivis par Git ;
- marqueurs `TODO`, `FIXME`, `HACK` ou `XXX` dans le code actif ;
- chaînes visibles codées en dur dans les surfaces principales ;
- présence des livrables de la phase finale.

Cet audit portable ne compile pas les applications Apple et ne revendique aucune validation matérielle.

### Tests et simulations

```bash
swift test --parallel
swift run MixPilotSimulatorCLI --tracks 50 --backend all --inject-failures
swift run MixPilotSimulatorCLI --tracks 250 --backend all --inject-failures
```

### Builds macOS

```bash
swift build -c release --product MixPilotAutopilot
swift build -c release --product MixPilotHardwareProbeCLI
swift build -c release --product MixPilotMappingPublisherCLI
./Scripts/build_release.sh
./Scripts/package_dmg.sh
shasum -a 256 -c build/MixPilot-Autopilot.dmg.sha256
```

### Application iPhone

```bash
cd Mobile/MixPilotRemote
xcodegen generate
xcodebuild \
  -project MixPilotRemote.xcodeproj \
  -scheme MixPilotRemote \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=<SIMULATOR_UDID>' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

## GitHub Actions

Les workflows restent volontairement en `workflow_dispatch` uniquement.

Des runs précédents ont échoué avant `actions/checkout`, sans étape ni log de runner (`steps: none`). Les déclenchements automatiques ne doivent pas être réactivés tant qu’un smoke test Ubuntu et macOS n’a pas réellement démarré.

`.github/workflows/final-pr-validation.yml` prépare :

- smoke tests Ubuntu et macOS ;
- audits portables ;
- suite Swift portable ;
- simulations 50/250 sur les trois backends ;
- reconstruction Supabase neuve ;
- suite Swift complète sur macOS ;
- génération XcodeGen et XCTest iPhone ;
- builds Release Mac ;
- DMG et checksum.

La présence de ce workflow ne signifie pas qu’il a été exécuté avec succès.

## Statuts de validation

MixPilot distingue strictement :

- `AUTOMATED_SUCCESS` : test automatisé réellement exécuté et réussi ;
- `SIMULATED_SUCCESS` : simulation réellement exécutée et réussie ;
- `REQUIRES_BACKEND_VALIDATION` : comportement à confirmer dans le logiciel DJ ;
- `REQUIRES_DEVICE_VALIDATION` : matériel, audio ou réseau réels à confirmer ;
- `BLOCKED_BY_PLATFORM` : validation impossible dans l’environnement courant ;
- `FAILED` : échec observé.

Les validations ciblées déjà documentées ne remplacent pas une exécution complète sur le head final.

## Validation matérielle séparée

Pour chaque backend, il reste à confirmer sur le matériel cible :

1. logiciel et version ;
2. import ou lecture de bibliothèque ;
3. mapping ;
4. Load, Play et Pause ;
5. volumes, EQ, filtre et crossfader ;
6. Sync ;
7. transition simple ;
8. lecture fiable de l’état des decks ;
9. routage et watchdog audio ;
10. musique de secours ;
11. Remote iPhone physique et perte Wi-Fi ;
12. reprise manuelle ;
13. dix transitions ;
14. trente minutes, une heure, deux heures puis endurance prolongée.

Aucun mapping stable ne doit être publié avant cette campagne.

## Confidentialité

Le dépôt ne doit contenir aucun secret, code d’appairage réel, certificat ou clé privée, fichier audio protégé, chemin personnel inutile ou donnée de compte sensible.

Les services de streaming restent utilisés directement dans le logiciel DJ. MixPilot ne télécharge, n’extrait, n’enregistre ni ne stocke les flux protégés.

## Documentation principale

- `DEVELOPMENT_STATUS.md` ;
- `Documentation/TECHNICAL_BENCHMARK_AND_PRIOR_ART.md` ;
- `Documentation/RELIABILITY_HARDENING_REPORT.md` ;
- `Documentation/MULTI_BACKEND_ARCHITECTURE.md` ;
- `Documentation/BACKEND_CAPABILITY_MATRIX.md` ;
- `Documentation/FINAL_VALIDATION.md` ;
- `Documentation/FINAL_DEBUGGING_AND_CLEANUP_REPORT.md` ;
- `Mobile/MixPilotRemote/README.md`.

## Limites actuelles

- aucune API privée ou non documentée n’est supposée ;
- les capacités dépendent des versions réelles de djay, rekordbox et Serato ;
- les écrans techniques secondaires peuvent encore contenir des textes historiques à migrer ;
- la CI globale, les builds Apple finaux, le DMG et la reconstruction Supabase neuve ne sont pas encore prouvés sur le head actuel ;
- la validation matérielle reste entièrement séparée.
