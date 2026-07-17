# Validation finale guidée de MixPilot

Cette campagne valide la refonte multi-backend sur le matériel réel. Elle ne commence qu’après une CI entièrement exécutable et verte, puis la génération d’un DMG dont le checksum a été contrôlé.

La procédure détaillée commune est complétée par `Documentation/MULTI_BACKEND_VALIDATION.md` et par les guides de chaque intégration.

## Statuts autorisés

- `AUTOMATED_SUCCESS` : test ou build réellement exécuté avec succès ;
- `SIMULATED_SUCCESS` : scénario logiciel réussi sans matériel DJ réel ;
- `REAL_SUCCESS` : résultat observé sur la configuration matérielle et logicielle indiquée ;
- `REQUIRES_BACKEND_VALIDATION` : comportement du logiciel DJ encore à confirmer ;
- `REQUIRES_DEVICE_VALIDATION` : matériel, audio, réseau local ou installation physique encore à confirmer ;
- `BLOCKED_BY_PLATFORM` : capacité non garantie proprement avec les interfaces disponibles.

Une simulation, un mapping présent sur disque ou une commande envoyée ne constituent jamais une validation Live.

## Préconditions communes

- Mac Apple Silicon sous macOS 14 ou supérieur, branché au secteur ;
- MixPilot construit depuis le commit testé ;
- musique locale de secours d’au moins trente minutes ;
- système audio de test dont la coupure ne met personne en danger ;
- iPhone sous iOS 17 ou supérieur pour les phases Remote ;
- aucun événement public ni matériel de production pendant la campagne ;
- sauvegarde des mappings existants avant toute modification.

## Matrice minimale

La campagne doit être exécutée séparément pour :

1. djay Pro ;
2. rekordbox en Mode Performance ;
3. Serato DJ Pro.

Chaque rapport doit enregistrer la version du logiciel, macOS, le contrôleur ou profil utilisé, le mapping, le commit MixPilot et la date du test.

## Phase A — Installation et permissions

1. installer le DMG de test ;
2. lancer MixPilot depuis Applications ;
3. accorder uniquement les permissions expliquées par l’application ;
4. relancer après les changements de permission ;
5. vérifier qu’aucun logiciel DJ n’est choisi implicitement ;
6. exporter un diagnostic anonymisé.

Critère : l’application démarre sans backend par défaut et explique chaque action manuelle nécessaire.

## Phase B — Sélection et détection du backend

Pour chacun des trois logiciels :

1. sélectionner explicitement le backend ;
2. vérifier l’installation, le lancement et la version détectée ;
3. fermer puis rouvrir le logiciel ;
4. vérifier qu’un changement de backend est refusé pendant le Live ;
5. confirmer qu’un ancien projet sans backend demande un choix.

Critère : aucune donnée, commande ou télémétrie n’est attribuée à un autre backend.

## Phase C — Bibliothèque et préparation

1. ouvrir une playlist de copie ;
2. importer les lignes visibles ou le format documentaire disponible ;
3. contrôler l’ordre, le nombre de morceaux, BPM et durées ;
4. préparer les marqueurs et transitions ;
5. inspecter les transitions à faible confiance ;
6. changer de backend hors Live et vérifier que le plan musical est conservé mais doit être revérifié ;
7. verrouiller le projet pour le backend choisi.

Critère : aucun mauvais titre, doublon ou ordre modifié silencieusement.

## Phase D — Mapping et commandes

Pour chaque backend :

1. sauvegarder le mapping existant ;
2. importer ou configurer le profil selon la méthode officiellement disponible ;
3. tester séparément Load, Play/Pause, Cue, Sync et volumes ;
4. tester ensuite EQ, filtre, crossfader, boucles et effets lorsqu’ils sont exposés ;
5. confirmer chaque réaction dans MixPilot ;
6. provoquer un test refusé et vérifier que la capacité reste bloquée ;
7. restaurer le mapping précédent.

Critère : seules les commandes réellement confirmées pour la version et le mapping testés peuvent être planifiées en Live.

## Phase E — Lecture fiable de l’état

1. charger un morceau sur chaque deck ;
2. vérifier le morceau, le deck actif, lecture/pause et position lorsque disponibles ;
3. modifier la disposition de l’interface ;
4. provoquer une observation ambiguë ;
5. vérifier que MixPilot bascule en configuration supervisée.

Critère impératif : sans lecture d’état fiable, l’Autopilote complet n’envoie aucune première commande.

## Phase F — Transitions et dégradation

Tester les sept familles : Smooth Blend, Bass Swap, Rap Switch, Shatta Drop, Echo Exit, Safe Fade et Hard Cut contrôlé.

Pour chaque backend, répéter les tests avec :

- crossfader indisponible ;
- effets indisponibles ;
- EQ partiel ;
- commande retardée ;
- commande non confirmée ;
- mapping incompatible.

Critère : MixPilot utilise un fallback confirmé, demande une intervention ou bloque le Live. Il ne commande jamais une fonction non validée.

## Phase G — Watchdog, secours et récupération

1. activer la surveillance audio ;
2. provoquer un silence contrôlé ;
3. perdre la source audio ;
4. interrompre Internet ;
5. fermer le backend actif ;
6. tester le lecteur local de secours ;
7. interrompre puis relancer MixPilot ;
8. vérifier le checkpoint et reprendre uniquement depuis un état cohérent.

Critère : aucune reprise aveugle, aucun changement contradictoire et contrôle manuel toujours disponible.

## Phase H — Remote iPhone v2

1. activer explicitement le bridge Mac ;
2. vérifier Bonjour `_mixpilot._tcp` ;
3. appairer l’iPhone et contrôler le stockage Trousseau ;
4. vérifier le backend et le mode réellement affichés ;
5. tester pause, reprise, skip et reprise manuelle ;
6. tester les refus du Mac ;
7. couper le Wi-Fi, verrouiller l’iPhone et fermer l’app ;
8. vérifier qu’aucune perte réseau ne modifie le Live Mac.

Critère : le Mac reste la seule source de vérité et aucun MIDI brut ne traverse le protocole Remote.

## Phase I — Services en ligne

1. lancer MixPilot avec diagnostics désactivés ;
2. vérifier que mises à jour et Live local restent indépendants ;
3. activer explicitement les diagnostics ;
4. contrôler le backend, la version et le mapping enregistrés ;
5. vérifier l’absence de titre, artiste, playlist, chemin, audio, texte Accessibilité et secret ;
6. couper Internet pendant le Live ;
7. rétablir Internet et vérifier la reprise de la file locale.

Critère : aucune panne Supabase ne bloque, ne démarre ou ne modifie le Live.

## Phase J — Endurance

Pour chaque backend autorisé en mode complet :

1. préparer un set d’au moins deux heures ;
2. exécuter le préflight ;
3. laisser le Mac sans interaction ;
4. surveiller CPU, mémoire, veille, audio, commandes et incidents ;
5. exporter le diagnostic final.

Critère : aucun crash, aucune commande aveugle, aucune veille et aucun incident critique non récupéré.

## Décision de publication

Une configuration peut recevoir `REAL_SUCCESS` uniquement si le rapport contient ses versions et preuves. Une réussite avec djay ne valide ni rekordbox ni Serato, et inversement.

La PR de refonte reste en brouillon et aucune fusion vers `main`, publication de mapping stable ou release publique n’est autorisée tant que la CI actuelle ne s’exécute pas réellement et que les campagnes matérielles correspondantes ne sont pas terminées.