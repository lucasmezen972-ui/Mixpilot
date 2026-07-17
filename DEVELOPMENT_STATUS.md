# État de développement

Dernière mise à jour : 17 juillet 2026

## État global

**Refonte logicielle multi-backend terminée — correctifs de clôture en cours de fusion**

- PR canonique #29 : fusionnée dans `main` ;
- branche de clôture : `fix/multi-backend-finalization` ;
- périmètre : import visible générique, correctifs distants multi-backend, provenance, persistance et migration Supabase ;
- fusion automatique dans `main` : uniquement après vérification de la PR de clôture.

### Pourcentage d’avancement

- architecture et code multi-backend : **100 %** après fusion de la branche de clôture ;
- documentation logicielle : **100 %** pour le périmètre courant ;
- validations locales et statiques disponibles : **environ 85 %** ;
- validation GitHub Actions complète : **bloquée par le provisionnement des runners** ;
- validation matérielle Mac/iPhone/logiciels DJ : **0 %** ;
- avancement global jusqu’à une version réellement éprouvée chez Lucas : **environ 82 %**.

Le code terminé ne vaut pas validation matérielle. Aucun backend, mapping ou parcours Live n’est déclaré `REAL_SUCCESS` sans test sur le matériel cible.

## Réalisé

### Audit et consolidation

- [x] branches et PR structurantes examinées ;
- [x] redondances, contradictions et anciens prompts inventoriés ;
- [x] chaîne de PR empilées remplacée par la PR canonique #29 ;
- [x] PR intermédiaires obsolètes fermées ;
- [x] anciennes interfaces principales parallèles supprimées ;
- [x] PR #29 fusionnée dans `main`.

### Contrats et moteur

- [x] contrat commun `DJBackend` ;
- [x] registre avec sélection explicite et sans backend implicite ;
- [x] changement de backend interdit pendant le Live ;
- [x] commandes universelles et matrice détaillée des capacités ;
- [x] file de commandes, timeout, idempotence et circuit breaker ;
- [x] preuve stricte `verified + validated` pour les commandes critiques ;
- [x] distinction entre commande envoyée, observée et réellement vérifiée ;
- [x] coordinateur Live indépendant du nom du logiciel ;
- [x] blocage sans lecture d’état fiable ;
- [x] réconciliation périodique du backend et de l’état pendant le Live ;
- [x] reprise manuelle coopérative au point sûr ;
- [x] aucun redémarrage automatique après crash ;
- [x] checkpoints terminés automatiquement nettoyés.

### Transitions et MIDI

- [x] horloge monotone ;
- [x] frames périmées abandonnées ;
- [x] coalescence des valeurs MIDI ;
- [x] valeurs normalisées et bornées ;
- [x] pulses Note et Control Change momentanés espacés ;
- [x] mappings continus obligatoirement en Control Change ;
- [x] Play/Pause/Load strictement vérifiés ;
- [x] Sync non bloquant tant qu’aucune lecture structurée de son effet n’existe ;
- [x] couverture MIDI fondée sur la compatibilité réelle des messages.

### Audio et secours

- [x] watchdog audio à états ;
- [x] un seul événement par épisode de silence, saturation ou perte de source ;
- [x] retour sain uniquement après récupération réelle ;
- [x] niveau UI limité à 10 Hz ;
- [x] callbacks d’anciennes sessions ignorés ;
- [x] silence critique : secours local puis reprise manuelle ;
- [x] perte de source : reprise manuelle sans audio potentiellement superposé ;
- [x] lecteur de secours protégé contre les anciens fondus ;
- [x] fichiers invalides sautés sans boucle infinie ;
- [x] ordre de la file conservé après plusieurs échecs successifs.

### Backends officiels

- [x] `DjayBackend` ;
- [x] `RekordboxBackend` ;
- [x] `SeratoBackend` ;
- [x] politiques séparées ;
- [x] détection installation/processus/version ;
- [x] validations liées au backend, à la version, au contrôleur et au mapping ;
- [x] garde `StrictVerificationDJBackend` appliqué aux trois backends ;
- [x] capacités différentes affichées sans hiérarchie produit.

### Import de playlist visible

- [x] `VisiblePlaylistImporter` est une implémentation réelle dans `MixPilotSystem` ;
- [x] lignes génériques `DJLibraryRow` ;
- [x] alias Serato limité à la compatibilité source ;
- [x] ancien fichier Runtime supprimé ;
- [x] dépendance circulaire Runtime/System supprimée ;
- [x] tests génériques ajoutés.

### iPhone Remote

- [x] contrat partagé Remote v2 ;
- [x] négociation v1/v2 symétrique ;
- [x] Mac source de vérité ;
- [x] backend, version, deck, audio et capacités dégradées transmis ;
- [x] reprise distante refusée sans état fiable ;
- [x] reconnexion après redémarrage du bridge ;
- [x] mode démo conservant le contexte backend ;
- [x] cible XCTest iOS et workflow simulateur préparés.

### Correctifs distants et services en ligne

- [x] requêtes filtrées sur le backend réellement actif ;
- [x] versions logicielles génériques ;
- [x] compatibilité descendante avec les champs rekordbox historiques ;
- [x] profil signé sans fichier inventé pour djay et Serato ;
- [x] profil et CSV recompilé/vérifié pour rekordbox ;
- [x] provenance GitHub acceptant un artefact optionnel ;
- [x] persistance et rollback adaptés au backend ;
- [x] outil de publication avec `--backend djay|rekordbox|serato` ;
- [x] migration Supabase additive et synchronisation des anciennes colonnes ;
- [x] RLS et services en ligne facultatifs conservés ;
- [x] aucune dépendance cloud dans l’exécution Live.

### Tests et garde-fous ajoutés

- [x] import visible générique ;
- [x] mappings distants djay, rekordbox et Serato ;
- [x] provenance sans CSV ;
- [x] persistance et rollback profil/CSV ;
- [x] reprise manuelle pendant une transition ;
- [x] perte répétée de lecture d’état ;
- [x] commandes observées non considérées comme validées ;
- [x] cadence des commandes continues ;
- [x] ordonnanceur de transition ;
- [x] watchdog audio ;
- [x] file audio de secours ;
- [x] scripts d’architecture et de sécurité runtime.

## Validation actuelle

### Validations réellement exécutées

- manifest SwiftPM partagé vérifié sous Swift 6.2.1 ;
- package Remote partagé : tests réussis ;
- modèles Remote iPhone : tests réussis ;
- tracker de fiabilité Live : tests réussis ;
- file de commandes stricte : tests isolés réussis ;
- garde de vérification backend : compilation Swift 6 réussie ;
- ordonnanceur de transition : compilation Swift 6 et test de charge isolé réussis ;
- watchdog audio : quatre scénarios isolés réussis ;
- garde-fous Bash vérifiés syntaxiquement lors de leur ajout.

Ces validations locales ciblées ne remplacent pas `swift test` complet sur macOS, le build iPhone, le DMG ou les essais matériels.

### Blocage GitHub Actions

Les workflows Linux, macOS et iPhone ont échoué avant leur première étape avec `steps: none`, sans checkout ni log. Ils sont temporairement en déclenchement manuel pour arrêter les notifications répétées.

Ne sont donc pas encore revendiqués :

- suite Swift complète verte sur le head final ;
- build macOS Release ;
- build iPhone complet ;
- simulations 50/250 du head final ;
- DMG et checksum du head final ;
- migration Supabase appliquée sur un projet neuf.

## Restant hors développement de la refonte

### Infrastructure et validation automatisée

- [ ] rétablir l’exécution GitHub Actions ;
- [ ] exécuter Core, Runtime, System, Remote Bridge et iPhone ;
- [ ] exécuter les simulations 50/250 ;
- [ ] construire le Mac, l’iPhone, le DMG et le checksum ;
- [ ] appliquer les migrations sur un environnement Supabase de validation neuf.

### Validation matérielle

- [ ] djay Automix supervisé ;
- [ ] djay MIDI direct ;
- [ ] rekordbox Mode Performance et CSV importé ;
- [ ] Serato contrôleur virtuel et XML ;
- [ ] chargement, lecture, volumes, EQ, filtre, crossfader et Sync ;
- [ ] lecture fiable de l’état des decks ;
- [ ] routage et watchdog audio ;
- [ ] musique de secours ;
- [ ] Remote iPhone physique et perte Wi-Fi ;
- [ ] reprise manuelle ;
- [ ] dix transitions ;
- [ ] trente minutes ;
- [ ] une heure ;
- [ ] deux heures ;
- [ ] nuit complète.

## Prochaine étape

1. fusionner la PR de clôture multi-backend dans `main` ;
2. rétablir GitHub Actions sans réactiver le spam de notifications ;
3. produire une candidate installable ;
4. lancer la campagne matérielle commune ;
5. ne publier des mappings stables qu’après validation réelle.
