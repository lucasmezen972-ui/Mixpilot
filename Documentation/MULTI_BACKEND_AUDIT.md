# Audit de consolidation multi-backend

Date de l’audit : 17 juillet 2026  
Branche de travail : `feature/first-class-multi-backend`  
Base technique inspectée : `feature/rekordbox-max-compatibility-ui` au commit `7f6e337653232d68e42abc4f36f3ac6a556d5448`

## But

Cet audit précède la refonte. Il ne valide aucune commande matérielle supplémentaire.

La cible produit est un seul MixPilot, avec :

- un moteur de préparation commun ;
- un moteur de transitions commun ;
- un système de sécurité commun ;
- un protocole Remote commun ;
- trois backends officiels : djay Pro, rekordbox et Serato DJ Pro.

Les trois logiciels ont la même importance produit. Leurs capacités peuvent rester différentes et doivent être décrites honnêtement.

## Dépôt et visibilité

- dépôt : `lucasmezen972-ui/Mixpilot` ;
- branche par défaut : `main` ;
- visibilité : privée ;
- aucune fusion automatique autorisée dans le cadre de cette refonte.

## Branches structurantes examinées

Les références suivantes ont été examinées directement ou par leurs Pull Requests et comparaisons Git :

- `main` ;
- `develop` ;
- `integration/0.3.0-rc.2` ;
- `release/0.3.0-rc.1` ;
- `release/0.3.0-rc.2` ;
- `feature/autopilot-runtime` ;
- `feature/final-product-experience` ;
- `feature/release-candidate-hardening` ;
- `feature/final-workspace` ;
- `feature/final-workspace-clean` ;
- `feature/release-candidate-completion` ;
- `feature/rehearsal-readiness` ;
- `feature/iphone-remote` ;
- `feature/mac-remote-bridge` ;
- `feature/automatic-serato-mapping` ;
- `fix/serato-midi-controller-publication` ;
- `feature/djay-compatibility` ;
- `feature/djay-automix-observability` ;
- `feature/rekordbox-compatibility` ;
- `feature/rekordbox-json-compatibility` ;
- `feature/rekordbox-actions` ;
- `feature/rekordbox-midi-preset` ;
- `feature/rekordbox-max-compatibility-ui`.

La recherche de branches du connecteur GitHub n’a pas renvoyé de liste exploitable. Les branches ci-dessus ont donc été établies à partir des références Git des PR et vérifiées par comparaison de commits lorsque nécessaire.

## Pull Requests examinées

### Chaîne historique produit

- #2 — fondation native ;
- #4 — runtime Autopilot Serato ;
- #5 — expérience produit et onboarding ;
- #6 — récupération et diagnostics ;
- #8 — espace de préparation ;
- #10 — répétition et protections finales ;
- #14 — consolidation RC2 ;
- #15 et #16 — intégration iPhone et bridge ;
- #17 — release candidate RC2 ;
- #21 et #22 — mapping Serato et publication CoreMIDI.

### Chaîne multi-backend actuelle

- #23 — ajout de djay comme deuxième logiciel ;
- #24 — laboratoire Automix djay en lecture seule ;
- #25 — ajout de rekordbox comme troisième logiciel ;
- #26 — actions rekordbox protégées ;
- #27 — preset MIDI rekordbox ;
- #28 — compatibilité rekordbox, cloud, mappings distants et interface.

## Branche la plus complète

`feature/rekordbox-max-compatibility-ui` est la branche la plus complète :

- elle contient intégralement `release/0.3.0-rc.2` ;
- elle est en avance de 135 commits sur cette release ;
- elle est en avance de 247 commits sur `main` ;
- la CI macOS associée est verte ;
- elle contient le Mac, l’iPhone, le bridge, Supabase, la provenance des mappings et les travaux rekordbox les plus récents.

Elle est utilisée comme base de récupération fonctionnelle, pas comme architecture cible.

## README trouvés

La comparaison récursive de l’arbre de la branche complète a identifié exactement deux README :

1. `README.md` ;
2. `Mobile/MixPilotRemote/README.md`.

Les deux sont centrés sur Serato et doivent être réécrits.

## Documentation trouvée

Documents principaux présents :

- `DEVELOPMENT_STATUS.md` ;
- `MANUAL_CHECKPOINTS.md` ;
- `SECURITY.md` ;
- `CHANGELOG.md` ;
- `CLAUDE.md` ;
- `Documentation/ARCHITECTURE.md` ;
- `Documentation/AUTOMATIC_SERATO_MAPPING.md` ;
- `Documentation/CLOUD_OBSERVABILITY.md` ;
- `Documentation/DJAY_COMPATIBILITY.md` ;
- `Documentation/FINAL_VALIDATION.md` ;
- `Documentation/IPHONE_REMOTE_BRIDGE.md` ;
- `Documentation/PRODUCT_SPEC.md` ;
- `Documentation/RC_STATUS.md` ;
- `Documentation/REKORDBOX_COMPATIBILITY.md` ;
- `Documentation/REKORDBOX_MAX_COMPATIBILITY.md` ;
- `Documentation/REKORDBOX_MIDI_PRESET.md` ;
- `Documentation/RELEASE.md` ;
- `Documentation/RELEASE_CANDIDATE_CHECKLIST.md` ;
- `Documentation/REMOTE_COMPATIBILITY.md` ;
- `Documentation/REMOTE_PROTOCOL_V1.md` ;
- `Documentation/SETUP_RUNNER.md` ;
- `Mobile/MixPilotRemote/Documentation/MAC_BRIDGE_INTEGRATION.md` ;
- `Mobile/MixPilotRemote/Documentation/REMOTE_PROTOCOL_V1.md`.

## Architecture réellement présente

### Modules SwiftPM

- `MixPilotCore` ;
- `MixPilotMIDI` ;
- `MixPilotSystem` ;
- `MixPilotRuntime` ;
- `MixPilotRemoteBridge` ;
- `MixPilotApp` ;
- `MixPilotSimulatorCLI` ;
- `MixPilotMappingPublisherCLI` ;
- `MixPilotHardwareProbeCLI`.

L’application iPhone reste isolée sous `Mobile/MixPilotRemote`.

### Dépendances actuelles

Le graphe général est sain dans sa direction :

- App → Core, MIDI, System, Runtime, Remote Bridge ;
- Runtime → Core, MIDI, System ;
- System → Core, MIDI, Supabase ;
- MIDI → Core ;
- Remote Bridge → Core.

Le problème se trouve dans le contenu des contrats, pas seulement dans le graphe des modules.

## Problèmes confirmés dans le code

### 1. Le cœur est encore centré sur Serato

`SeratoAction` représente en réalité des intentions DJ universelles : Play, Pause, Cue, Sync, Load, volumes, EQ, filtre, tempo, crossfader, boucle et Echo.

Ces intentions sont utilisées directement dans :

- `MIDIMappingProfile` ;
- `TransitionFrame` ;
- `TransitionFrameGenerator` ;
- `TransitionExecutor` ;
- `LiveAutopilotCoordinator` ;
- les écrans de mapping ;
- les tests ;
- les générateurs de mappings rekordbox.

Décision : **renommer et migrer** vers un modèle de commandes universelles. Une compatibilité de décodage devra préserver les anciens profils.

### 2. Le runtime Live dépend directement de Serato

`LiveAutopilotCoordinator` dépend de :

- `MappedSeratoController` ;
- `SeratoAccessibilityBridge` ;
- `SeratoAction` ;
- `SeratoWindowObservation` ;
- erreurs et événements nommés Serato.

Décision : **réécrire progressivement la frontière du runtime**. Le coordinateur devra recevoir un backend actif et un plan déjà adapté à ses capacités.

### 3. Le multi-backend actuel est surtout une sélection visuelle

`DJSoftware` contient trois cas, mais :

- les capacités sont six valeurs codées en dur ;
- aucun objet backend n’est instancié par le cœur ;
- aucun registre ne gère le changement, le Live ou la persistance par backend ;
- l’absence d’ancienne préférence sélectionne silencieusement Serato ;
- le `AppModel` instancie toujours les composants Serato.

Décision : **remplacer le magasin statique par un registre de backends et une migration de préférence explicite**.

### 4. Le préflight reste Serato sous des libellés génériques

`PreflightInput.seratoRunning` est utilisé pour les trois logiciels. Les règles MIDI et mapping sont décidées à partir d’un mode préféré codé en dur, pas des capacités réellement validées.

Décision : **fusionner le préflight avec le rapport de validation du backend et la matrice de capacités**.

### 5. Les détecteurs sont fragmentés

- `SeratoEnvironmentProbe` détecte en réalité le logiciel sélectionné ;
- `DjayEnvironmentProbe` ne détecte que le processus ;
- `RekordboxEnvironmentProbe` ne détecte que le processus et le bundle ;
- les modèles de résultat sont incompatibles ;
- la détection de version est répétée dans des vues et dans le cloud.

Décision : **fusionner les contrats de détection**, garder les matchers spécifiques et supprimer les responsabilités dupliquées.

### 6. Le cloud est codé pour rekordbox

`MixPilotCloudCoordinator` et `MixPilotCloudService` :

- utilisent un nom de contrôleur rekordbox au démarrage ;
- détectent uniquement la version de rekordbox ;
- enregistrent `djBackend: "rekordbox"` en dur ;
- traitent tous les correctifs distants comme des mappings rekordbox ;
- affichent des erreurs techniques brutes dans plusieurs états.

Décision : **généraliser le contexte cloud**, séparer les mises à jour de l’application des mappings de backend et traduire les erreurs en messages produit.

### 7. Les modèles Remote sont dupliqués

Les snapshots, commandes, accusés de réception et enveloppes existent séparément dans :

- `Sources/MixPilotRemoteBridge/RemoteProtocol.swift` ;
- `Mobile/MixPilotRemote/Sources/RemoteModels.swift`.

Les modèles iPhone ne contiennent pas le backend actif, sa version ni les capacités dégradées.

Décision : **déplacer le contrat versionné réellement partagé dans `Shared/RemoteProtocolV1`**, puis préparer une migration de protocole compatible.

### 8. Deux interfaces complètes coexistent

`ContentView.swift` contient l’ancienne application complète. L’application actuelle utilise :

- `MixPilotMainShellView` ;
- `BrandedRootView` ;
- `AdvancedContentView`.

`ContentView` conserve des textes Serato, un ancien onboarding, une ancienne navigation et plusieurs vues parallèles.

Décision : **déprécier puis supprimer `ContentView.swift` après vérification de compilation**.

### 9. Navigation et écrans redondants

Les rôles se chevauchent entre :

- Dashboard ;
- Onboarding ;
- Quick Set ;
- Studio ;
- Mapping MIDI ;
- Rekordbox Hub ;
- Rekordbox Compatibility Lab ;
- Rekordbox Device Validation ;
- Automatic Rekordbox Mapping ;
- Automatic Serato Mapping ;
- Feasibility Lab ;
- Diagnostics ;
- Hardware Probe.

Décision : **ramener le parcours normal à Préparer, Vérifier, Live et Avancé**. Les laboratoires et exports resteront accessibles dans Avancé.

### 10. Les documents se contredisent

Exemples :

- le README décrit une application Serato ;
- `PRODUCT_SPEC.md` définit Serato comme seule cible ;
- `ARCHITECTURE.md` relie directement MIDI et System à Serato ;
- `DEVELOPMENT_STATUS.md` indique encore `release/0.3.0-rc.2` comme branche active ;
- `DJAY_COMPATIBILITY.md` présente djay comme deuxième logiciel ajouté ;
- `REKORDBOX_COMPATIBILITY.md` présente rekordbox comme troisième logiciel ajouté et reconnaît les noms Serato résiduels.

Décision : **créer des documents de référence uniques**, puis raccourcir les documents historiques ou les marquer clairement comme historiques.

## Inventaire des décisions

| Élément | Décision | Motif |
|---|---|---|
| `DJSoftware` | Renommer progressivement en identifiant de backend | C’est une identité, pas un backend complet |
| `DJSoftwareSelectionStore` | Remplacer et migrer | Défaut Serato implicite et absence de verrou Live |
| `DJSoftwareCapabilities` | Réécrire | Trop peu détaillé et codé en dur |
| `SeratoAction` | Renommer et migrer | Contient des intentions universelles |
| `SeratoCommandSending` | Remplacer | Contrat trop faible et spécifique |
| `MappedSeratoController` | Déplacer dans le backend Serato | Adaptateur concret |
| `TransitionExecutor` | Conserver le moteur, changer son port de sortie | Logique utile mais dépendance Serato |
| `LiveAutopilotCoordinator` | Réécrire par étapes | Orchestration utile, dépendances concrètes |
| `SeratoEnvironmentProbe` | Fusionner et renommer | Détecte déjà les trois logiciels |
| `DjayEnvironmentProbe` | Conserver le matcher, fusionner le contrat | Détection utile mais incomplète |
| `RekordboxEnvironmentProbe` | Conserver le matcher, fusionner le contrat | Détection utile mais incomplète |
| `PreflightEvaluator` | Conserver la structure de rapport, réécrire les entrées | Bon modèle d’UI, mauvaises sources |
| `MixPilotCloudService` | Généraliser | Backend rekordbox codé en dur |
| `MixPilotCloudCoordinator` | Séparer app updates et backend mappings | Plusieurs responsabilités |
| Remote v1 dupliqué | Fusionner | Risque de divergence de protocole |
| `ContentView.swift` | Supprimer après migration | Ancienne application complète inutilisée |
| `AdvancedContentView.swift` | Découper | Fichier trop volumineux et plusieurs écrans |
| Rekordbox Hub + labs | Fusionner le parcours utilisateur | Trop de portes d’entrée |
| Mappings Serato/rekordbox | Conserver les validateurs spécifiques | Artefacts réellement différents |
| Cloud pendant le Live | Maintenir facultatif | Sécurité locale prioritaire |
| Supabase | Conserver dans System/Cloud | Ne doit pas entrer dans Runtime |

## Fonctionnalités à préserver

- préparation et optimisation de set ;
- sept familles de transitions ;
- courbes d’automation ;
- mapping MIDI et confirmations ;
- installation et rollback Serato ;
- import XML/JSON rekordbox ;
- compilation et validation du CSV rekordbox ;
- provenance GitHub et SHA-256 ;
- catalogue distant et rollout ;
- observation Accessibilité protégée ;
- répétition mesurée ;
- watchdog audio ;
- secours local ;
- checkpoints et récupération ;
- diagnostics anonymisés ;
- Remote iPhone local ;
- commandes distantes de haut niveau ;
- simulations 50 et 250 titres ;
- DMG et checksum ;
- distinction entre automatisé, simulé et matériel.

## Fonctionnalités décrites mais non réellement disponibles

- backend djay complet ;
- contrôle direct djay validé ;
- gestion de file Automix djay ;
- lecture fiable de l’état des decks pour les trois logiciels ;
- vérification commune de chaque commande ;
- négociation dynamique des capacités ;
- adaptation automatique complète des transitions au backend ;
- changement de backend protégé pendant le Live ;
- télémétrie du backend réellement sélectionné ;
- application iPhone affichant le backend actif ;
- environnement cloud développement/validation/production ;
- consentement et rétention explicites de la télémétrie.

## Architecture cible retenue

La refonte utilisera les modules existants autant que possible.

### `MixPilotCore`

Conserver : planification, analyse, transitions, sécurité, récupération et diagnostics purs.

Ajouter ou consolider :

- contrats de backend ;
- identifiants et commandes universels ;
- matrice de capacités ;
- validation ;
- sélection de variantes de transition ;
- erreurs produit traduites.

### `MixPilotMIDI`

Conserver CoreMIDI et les profils MIDI génériques.

Les compilateurs de mappings spécifiques restent dans leurs adaptateurs ou services spécifiques.

### `MixPilotSystem`

Conserver les interactions macOS, audio, fichiers, Keychain et services en ligne.

Créer des adaptateurs concrets djay, rekordbox et Serato sans faire dépendre Core de leurs types.

### `MixPilotRuntime`

Conserver l’orchestration du Live, mais dépendre uniquement d’un backend actif et des contrats du Core.

### `MixPilotRemoteBridge`

Conserver le réseau local et les décisions du Mac. Importer les modèles partagés au lieu de les redéfinir.

### `MixPilotApp`

Unifier la navigation autour de :

1. Préparer ;
2. Vérifier ;
3. Live ;
4. Avancé.

## Ordre de migration retenu

1. figer l’audit et la terminologie ;
2. créer les types communs sans brancher le runtime ;
3. ajouter les mocks et tests ;
4. migrer les commandes et profils avec compatibilité des anciens formats ;
5. créer le registre et les adaptateurs ;
6. migrer le préflight ;
7. migrer le runtime ;
8. généraliser le cloud ;
9. faire évoluer Remote ;
10. simplifier l’interface ;
11. supprimer les anciens chemins ;
12. réécrire tous les README et documents ;
13. valider les builds et simulations ;
14. préparer les protocoles matériels.

## Limites de cet audit

- aucune validation matérielle nouvelle n’a été réalisée ;
- aucune API non documentée n’est supposée ;
- les branches ne sont pas supprimées ;
- les PR historiques ne sont pas encore fermées ;
- aucun mapping stable n’est publié ;
- aucune migration Supabase supplémentaire n’est appliquée à ce stade.
