# État de développement

Dernière mise à jour : 17 juillet 2026

## État global

**Refonte multi-backend terminée — phase finale de débogage et nettoyage en cours**

- PR #29 : refonte multi-backend fusionnée dans `main` ;
- PR #30 : finalisation multi-backend fusionnée dans `main` ;
- PR #31 : benchmark, fiabilité et centre d’aide fusionnés dans `main` ;
- PR #32 : durcissement Remote, Supabase et validation PR fusionné dans `main` ;
- branche active de finalisation : `agent/final-debug-cleanup` ;
- fusion automatique dans `main` : interdite ;
- workflows automatiques : non réactivés tant que le blocage des runners avant `checkout` n’est pas résolu.

### Lecture correcte de l’avancement

- architecture et code multi-backend : **terminés pour le périmètre logiciel défini** ;
- benchmark technique : **terminé** ;
- stabilisation ciblée Remote/audio/état backend : **implémentée et partiellement validée** ;
- centre d’aide hors ligne partagé : **implémenté** ;
- catalogue d’aide FR/EN/ES : **implémenté** ;
- migration de tous les textes historiques vers des clés Apple stables : **à vérifier et compléter** ;
- débogage automatisé global : **incomplet** ;
- nettoyage final et rapport de clôture : **en cours** ;
- validation matérielle Mac/iPhone/logiciels DJ : **non effectuée**.

Le code terminé ne vaut pas validation matérielle. Aucun backend, mapping ou parcours Live n’est déclaré `REAL_SUCCESS` sans test sur le matériel cible.

## Réalisé

### Architecture et moteur

- [x] contrat commun `DJBackend` ;
- [x] registre avec sélection explicite et sans backend implicite ;
- [x] trois backends officiels : djay Pro, rekordbox et Serato DJ Pro ;
- [x] changement de backend interdit pendant le Live ;
- [x] matrice de capacités et validations liées au backend, à la version, au contrôleur et au mapping ;
- [x] commandes sérialisées, timeouts, idempotence, déduplication et circuit breaker ;
- [x] distinction entre commande envoyée, observée et réellement vérifiée ;
- [x] blocage sans lecture d’état fiable ;
- [x] réconciliation périodique de l’état ;
- [x] reprise manuelle coopérative au point sûr ;
- [x] aucun redémarrage automatique du Live après crash.

### MIDI, transitions et audio

- [x] horloge monotone et abandon des événements périmés ;
- [x] coalescence et bornage des valeurs MIDI ;
- [x] profils et validations séparés selon le backend ;
- [x] contrôle strict des commandes critiques ;
- [x] watchdog audio à états ;
- [x] détection du silence, de la saturation et de la perte de source ;
- [x] reconstruction bornée de `AVAudioEngine` après changement de configuration ;
- [x] musique locale de secours et retour obligatoire au contrôle manuel ;
- [x] protection contre les callbacks et buffers d’anciennes sessions.

### Import, mappings et services facultatifs

- [x] import de playlist visible générique ;
- [x] lignes `DJLibraryRow` indépendantes du backend ;
- [x] XML Serato et CSV rekordbox conservés selon leurs capacités réelles ;
- [x] correctifs distants filtrés sur le backend actif ;
- [x] provenance GitHub et empreintes SHA-256 ;
- [x] persistance et rollback adaptés au backend ;
- [x] Supabase facultatif, sans dépendance dans le Live ;
- [x] RLS et contraintes propriétaire/appareil renforcées ;
- [x] diagnostics en ligne désactivés par défaut et filtrés.

### Remote iPhone

- [x] protocole partagé v2 avec compatibilité de décodage v1 ;
- [x] Mac source de vérité ;
- [x] reconnexion bornée sans replay automatique des commandes ;
- [x] invalidation des anciennes tâches réseau par génération ;
- [x] appairage limité et Remote non chiffré désactivé par défaut ;
- [x] commandes de haut niveau uniquement ;
- [x] perte réseau sans impact sur le Live local.

### Benchmark, aide et langues

- [x] `Documentation/TECHNICAL_BENCHMARK_AND_PRIOR_ART.md` ;
- [x] comparaison des approches djay, rekordbox, Serato, VirtualDJ, Mixxx et frameworks Apple ;
- [x] centre d’aide hors ligne partagé macOS/iPhone ;
- [x] recherche sans accents et filtres par catégorie ;
- [x] onze articles couvrant démarrage, connexion, mappings, préflight, Live, iPhone et reprise ;
- [x] ressources FR/EN/ES du centre d’aide et du Remote ;
- [x] scripts de cohérence des ressources localisées ;
- [x] tests ciblés de clés, langues, recherche et parité.

### Fiabilité et sécurité ajoutées après la refonte

- [x] politique de restart bornée du listener Remote ;
- [x] politique de backoff bornée ;
- [x] expiration des états backend ;
- [x] anciennes validations conservées pour lecture mais incapables d’autoriser le Live ;
- [x] simulations de panne alignées sur le handoff manuel sûr ;
- [x] contraintes Supabase propriétaire/appareil/session ;
- [x] moindre privilège sur les vues exposées ;
- [x] workflow de validation finale préparé en déclenchement manuel.

## Validations réellement exécutées

- compilations et tests portables Swift 6.2.1 ciblés ;
- package Remote partagé : tests réussis ;
- modèles Remote iPhone : tests ciblés réussis ;
- politiques de retry, fraîcheur d’état et contexte de validation : tests ciblés réussis ;
- scénarios isolés silence, backend fermé, MIDI, source audio et perte Internet ;
- simulations isolées 50 et 250 titres avec handoff `manualControl` sûr ;
- contrôles syntaxiques et garde-fous Bash/Python ajoutés ;
- migration Supabase de durcissement appliquée sur le projet actif ;
- Supabase Security Advisor : aucune alerte au moment de la vérification.

Ces validations ne remplacent pas la suite Swift complète sur macOS, le build iPhone, le DMG, une reconstruction Supabase neuve ni les essais matériels.

## Blocages externes connus

### GitHub Actions

Les jobs Linux et macOS observés ont échoué avant leur première étape :

- aucun `checkout` ;
- aucun log de runner ;
- `steps: []` / `steps: none` ;
- jobs dépendants ensuite ignorés.

Les workflows restent donc en déclenchement manuel. Leur présence ne vaut pas exécution réussie.

### Environnement Apple

L’environnement ayant produit les validations ciblées ne dispose pas de Xcode. Ne sont pas encore prouvés sur le head final :

- build macOS complet ;
- génération XcodeGen et build iPhone ;
- XCTest iPhone ;
- DMG et checksum ;
- comportement thermique, veille et mémoire sur le Mac cible.

### Supabase neuf

La migration hébergée de durcissement a été appliquée, mais une reconstruction complète sur un projet de validation neuf ou une branche Supabase isolée reste à exécuter.

## Phase finale active : livrables automatisables restants

### Débogage exhaustif

- [ ] exécuter la suite Swift complète sur une machine macOS compatible ;
- [ ] exécuter les tests Runtime, System et Remote Bridge ensemble ;
- [ ] générer puis construire le projet iPhone ;
- [ ] exécuter les XCTest iPhone ;
- [ ] exécuter les simulations 50/250 sur le head final avec le CLI officiel ;
- [ ] construire les produits Release macOS ;
- [ ] produire le DMG et vérifier son checksum ;
- [ ] exécuter une reconstruction Supabase locale neuve avec Docker ;
- [ ] vérifier les trois backends, migrations locales et services facultatifs hors ligne ;
- [ ] corriger toute erreur de compilation ou de test révélée.

### Localisation et aide

- [ ] inventorier les chaînes historiques encore codées en dur dans macOS et iPhone ;
- [ ] migrer les erreurs, onboarding, notifications et confirmations restantes vers des clés stables ;
- [ ] tester pluralisation, textes longs et mises en page accessibles ;
- [ ] vérifier que chaque erreur importante pointe vers une aide pertinente.

### Nettoyage final

- [ ] supprimer le code mort et les anciens écrans réellement non référencés ;
- [ ] supprimer imports, commentaires et fichiers temporaires obsolètes ;
- [ ] fusionner uniquement les services dont la redondance est démontrée ;
- [ ] vérifier secrets, données personnelles et chemins locaux ;
- [ ] vérifier dépendances circulaires et artefacts inutiles ;
- [ ] harmoniser noms, dossiers, tests et traductions ;
- [ ] mettre à jour README et documents de validation ;
- [ ] produire `Documentation/FINAL_DEBUGGING_AND_CLEANUP_REPORT.md`.

## Validation matérielle séparée

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

## Règles de clôture

1. ne jamais publier un mapping stable sans validation réelle ;
2. ne jamais transformer une simulation ou une compilation ciblée en validation matérielle ;
3. ne jamais réactiver les déclenchements automatiques tant que la cause des runners n’est pas résolue ;
4. ne jamais fusionner automatiquement la PR de finalisation ;
5. documenter chaque exécution avec son commit, son environnement et son résultat ;
6. conserver le Live local-first, indépendant d’Internet, de Supabase, d’OpenAI et de l’iPhone.
