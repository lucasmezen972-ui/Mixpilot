# MixPilot

**TRADIKOM BY LUCAS MEZEN**

MixPilot est un système d’Autopilote DJ pour macOS. Il aide à préparer, vérifier, sécuriser et superviser un set, puis traduit le même plan vers l’un des trois backends DJ officiels :

- **djay Pro** ;
- **rekordbox** ;
- **Serato DJ Pro**.

MixPilot n’est pas une application Serato à laquelle deux modes secondaires ont été ajoutés. Le produit repose sur un seul moteur de préparation, un seul moteur de transitions, un seul système de sécurité, une seule application iPhone et trois adaptateurs interchangeables.

> Être officiellement pris en charge ne signifie pas que toutes les capacités sont identiques ni déjà validées sur chaque Mac. MixPilot affiche les différences et bloque les fonctions qui ne disposent pas encore de preuves suffisantes.

## Ce que fait l’utilisateur

Le parcours normal tient en sept étapes :

1. choisir djay Pro, rekordbox ou Serato DJ Pro ;
2. vérifier la connexion ;
3. importer ou lire une playlist ;
4. préparer le set et sa courbe d’énergie ;
5. tester une transition ;
6. terminer la Vérification du système ;
7. lancer le Live et garder la possibilité de reprendre la main.

La navigation principale contient quatre espaces :

- **Préparer** ;
- **Vérifier** ;
- **Live** ;
- **Avancé**.

CoreMIDI, Accessibilité macOS, CSV, XML, provenance, SHA-256, Supabase et les rapports techniques restent derrière cette expérience.

## Les trois backends officiels

### djay Pro

Positionnement : **Autopilote natif et contrôle avancé**.

Deux modes sont prévus :

- **Automix supervisé** : MixPilot prépare le plan, observe l’exécution et alerte ;
- **MixPilot avancé** : MixPilot traduit directement les transitions vers les commandes validées.

La présence d’Automix ne suffit pas à déclarer le mode prêt. La version de djay, les contrôles accessibles, le profil MIDI et la réaction réelle doivent être confirmés sur le Mac cible.

### rekordbox

Positionnement : **Mode Performance et installations professionnelles**.

Le backend conserve notamment :

- import XML ;
- import JSON adaptatif ;
- lecture des playlists importées ;
- génération et validation du CSV MIDI à 15 colonnes ;
- sauvegarde et restauration du mapping ;
- provenance GitHub et empreintes SHA-256 ;
- validation par version et par contrôleur.

MixPilot peut préparer un CSV valide sans prétendre que rekordbox ou le contrôleur physique y ont déjà réagi.

### Serato DJ Pro

Positionnement : **Contrôle MIDI avec configuration guidée**.

Le backend conserve notamment :

- contrôleur virtuel CoreMIDI ;
- détection du processus et de la version ;
- installation du mapping XML ;
- sauvegarde et rollback ;
- assistant de configuration ;
- observation protégée de l’interface ;
- validation commande par commande.

Serato reste un backend officiel, mais il n’est plus le centre de l’architecture.

## Capacités et adaptation des transitions

Chaque backend expose une matrice commune. Elle couvre notamment :

- détection du logiciel et de sa version ;
- lecture de bibliothèque et de playlist ;
- chargement, lecture, pause, Cue et Sync ;
- tempo, volumes, EQ, filtre et crossfader ;
- boucles et effets ;
- Automix ;
- lecture de l’état des decks ;
- surveillance audio ;
- mapping, rollback, Remote et récupération.

Chaque capacité indique :

- sa disponibilité ;
- la méthode utilisée ;
- le niveau de confiance ;
- la validation encore nécessaire ;
- la version du logiciel et du mapping ;
- le contrôleur associé ;
- la raison d’un blocage ;
- l’action proposée à l’utilisateur.

Le moteur ne construit un Live qu’avec les capacités confirmées. Par exemple :

- sans crossfader, il utilise les volumes des decks ;
- sans Echo validé, il choisit Bass Swap, Smooth Blend ou Safe Fade ;
- sans chargement ou lecture confirmés, il bloque l’Autopilote complet ;
- sans lecture fiable de l’état, il reste en préparation, mode supervisé ou contrôle manuel.

Les familles de transitions conservées sont :

- Smooth Blend ;
- Bass Swap ;
- Rap Switch ;
- Shatta Drop ;
- Echo Exit ;
- Safe Fade ;
- Hard Cut contrôlé.

## Sécurité du Live

Le Live fonctionne d’abord en local. Il ne dépend jamais :

- d’Internet ;
- des services en ligne ;
- d’OpenAI ;
- de l’iPhone ;
- d’un mapping distant non installé.

Le runtime utilise :

- une file de commandes sérialisée ;
- des identifiants d’idempotence ;
- des timeouts ;
- une distinction entre commande envoyée et effet vérifié ;
- un circuit breaker ;
- des checkpoints ;
- une surveillance du silence et de la saturation ;
- une musique locale de secours ;
- un arrêt coopératif ;
- un contrôle manuel prioritaire.

Un backend qui répond mal provoque une suspension et une reprise manuelle, pas une rafale de commandes aveugles.

## MixPilot Remote pour iPhone

L’application iPhone se trouve dans :

```text
Mobile/MixPilotRemote
```

Elle fonctionne de la même manière avec les trois backends.

Elle affiche notamment :

- le backend actif et sa version ;
- le morceau actuel et le suivant ;
- le deck actif ;
- la progression ;
- la transition prévue ;
- l’état audio ;
- les fonctions temporairement dégradées ;
- les alertes du Mac.

Les commandes restent des intentions de haut niveau :

- Mettre en pause ;
- Reprendre ;
- Changer la prochaine transition ;
- Transition de secours, uniquement si le Mac l’autorise ;
- Reprendre la main.

L’iPhone n’envoie jamais de MIDI brut, ne contacte jamais directement le logiciel DJ et ne prend aucune décision autonome. Une perte réseau ne modifie pas le Live.

Le contrat partagé et versionné se trouve dans :

```text
Shared/RemoteProtocolV2
```

Le décodage des anciens snapshots Remote v1 reste pris en charge pendant la migration.

## Services en ligne

Les services en ligne fournissent uniquement des fonctions facultatives :

- mises à jour de MixPilot ;
- correctifs de compatibilité publiés ;
- diagnostics techniques autorisés par l’utilisateur ;
- suivi non musical de la compatibilité.

Ils ne contrôlent jamais le Live.

Les diagnostics en ligne sont désactivés par défaut. MixPilot ne transmet pas par défaut :

- titre ou artiste ;
- nom de playlist ;
- chemin local complet ;
- audio brut ;
- flux Spotify ;
- token ;
- code d’appairage ;
- contenu de l’arbre Accessibilité.

La télémétrie technique expire après une durée limitée. Les tables exposées utilisent RLS et l’application ne contient qu’une clé publiable.

## Architecture

```text
MixPilotCore
├── préparation et analyse du set
├── moteur de transitions
├── sécurité et récupération
├── contrats DJBackend
├── matrice des capacités
└── diagnostics purs

MixPilotMIDI
└── CoreMIDI et profils de commandes génériques

MixPilotSystem
├── adaptateurs djay, rekordbox et Serato
├── Accessibilité, fichiers, audio et Keychain
└── services en ligne facultatifs

MixPilotRuntime
├── coordinateur Live indépendant du backend
├── file de commandes et circuit breaker
└── exécution et réconciliation

MixPilotRemoteBridge
└── Bonjour, WebSocket local, appairage et décisions du Mac

MixPilotApp
└── Préparer, Vérifier, Live et Avancé

Mobile/MixPilotRemote
└── application iPhone générique
```

Les dépendances restent orientées vers le cœur. Aucune logique cloud n’entre dans le moteur de transitions et aucune logique iPhone n’entre dans les adaptateurs DJ.

## Formats et migrations

La migration locale préserve :

- les anciens profils MIDI ;
- l’ancienne préférence explicite de logiciel ;
- les checkpoints ;
- les projets de set ;
- les diagnostics historiques ;
- les snapshots Remote v1.

En l’absence d’un ancien backend explicite, MixPilot demande un choix. Il ne déduit Serato que lorsqu’une preuve locale fiable existe.

## Développement

Prérequis principaux :

- Swift 6 ;
- macOS 14 ou supérieur pour l’application Mac ;
- Xcode et XcodeGen pour l’application iPhone.

Validation du cœur :

```bash
swift test --parallel
swift run MixPilotSimulatorCLI --tracks 50 --inject-failures
swift run MixPilotSimulatorCLI --tracks 250 --inject-failures
```

Builds macOS :

```bash
swift build -c release --product MixPilotAutopilot
swift build -c release --product MixPilotHardwareProbeCLI
./Scripts/build_release.sh
./Scripts/package_dmg.sh
shasum -a 256 -c build/MixPilot-Autopilot.dmg.sha256
```

Application iPhone :

```bash
cd Mobile/MixPilotRemote
xcodegen generate
xcodebuild \
  -project MixPilotRemote.xcodeproj \
  -scheme MixPilotRemote \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
swift test --parallel
```

## Validation et statuts

MixPilot distingue strictement :

- `AUTOMATED_SUCCESS` : test automatisé réussi ;
- `SIMULATED_SUCCESS` : scénario simulé réussi ;
- `REQUIRES_BACKEND_VALIDATION` : comportement à confirmer dans le logiciel ;
- `REQUIRES_DEVICE_VALIDATION` : matériel et routage réels à confirmer ;
- `BLOCKED_BY_PLATFORM` : fonction non disponible par cette méthode ;
- `FAILED` : échec observé.

Une CI verte ne valide ni un contrôleur physique, ni un système audio, ni une version de logiciel DJ sur le Mac cible.

Au moment de cette refonte, les workflows GitHub Actions du dépôt peuvent échouer avant leur première étape à cause du provisionnement des runners. Un tel échec n’est ni présenté comme une réussite ni interprété comme une erreur du code.

## Validation matérielle requise

Pour chaque backend, le protocole commun vérifie au minimum :

1. logiciel et version ;
2. mapping ;
3. Play et Pause ;
4. Load ;
5. volumes ;
6. Sync ;
7. transition simple ;
8. reprise manuelle ;
9. perte de connexion ;
10. récupération ;
11. Remote iPhone ;
12. dix transitions ;
13. trente minutes ;
14. deux heures.

Les protocoles spécifiques sont documentés séparément. Aucun backend ne doit être présenté comme entièrement prêt avant ces validations.

## Confidentialité et contenu protégé

Les services de streaming restent utilisés directement dans le logiciel DJ. MixPilot ne télécharge, n’extrait, n’enregistre ni ne stocke aucun flux protégé.

Le dépôt ne doit contenir aucun secret, code d’appairage réel, certificat privé, fichier audio protégé ou donnée de compte sensible.

## Documentation

Références produit et architecture :

- `Documentation/PRODUCT_POSITIONING.md` ;
- `Documentation/USER_JOURNEY.md` ;
- `Documentation/TERMINOLOGY.md` ;
- `Documentation/MULTI_BACKEND_AUDIT.md` ;
- `Documentation/MULTI_BACKEND_ARCHITECTURE.md` ;
- `Documentation/BACKEND_CAPABILITY_MATRIX.md` ;
- `Documentation/MULTI_BACKEND_VALIDATION.md`.

Intégrations :

- `Documentation/DJAY_INTEGRATION.md` ;
- `Documentation/REKORDBOX_INTEGRATION.md` ;
- `Documentation/SERATO_INTEGRATION.md` ;
- `Documentation/CLOUD_OBSERVABILITY.md` ;
- `Mobile/MixPilotRemote/README.md`.

## Limites actuelles

- aucune API privée ou non documentée n’est supposée ;
- la lecture complète de l’état des decks dépend de la version et du logiciel ;
- les profils djay doivent encore être validés sur le Mac cible ;
- les CSV rekordbox exigent toujours un import et un test réels ;
- Serato exige une confirmation de la réaction réelle des commandes ;
- les correctifs distants non rekordbox ne sont pas publiés tant que leurs formats ne sont pas réellement implémentés ;
- l’IA n’est pas dans la boucle Live.

## Roadmap

Priorités avant une release stable multi-backend :

1. validation matérielle commune ;
2. validation Automix et MIDI djay ;
3. validation Mode Performance rekordbox ;
4. validation complète du parcours Serato ;
5. endurance audio et récupération ;
6. compilation et tests Mac/iPhone sur runners disponibles ;
7. publication progressive des mappings validés ;
8. suppression des derniers noms historiques internes après migration des formats.
