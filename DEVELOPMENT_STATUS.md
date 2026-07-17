# État de développement

Dernière mise à jour : 17 juillet 2026

## État global

**Refonte canonique multi-backend en cours — PR brouillon #29**

- branche : `feature/first-class-multi-backend` ;
- base : `release/0.3.0-rc.2` ;
- PR : #29 ;
- fusion dans `main` : interdite tant que les critères de sortie ne sont pas remplis.

La branche récupère les fonctions utiles des PR djay, rekordbox, Serato, Remote et services en ligne, puis remplace progressivement les dépendances historiques au lieu d’ajouter une couche supplémentaire.

## Réalisé dans la refonte

### Audit et consolidation

- [x] branches et PR structurantes examinées ;
- [x] branche la plus complète identifiée ;
- [x] inventaire des redondances et contradictions ;
- [x] décisions Conserver / Fusionner / Renommer / Déplacer / Supprimer documentées ;
- [x] branche canonique créée ;
- [x] ancienne chaîne de PR empilées remplacée par une PR vers RC2 ;
- [x] anciennes coquilles d’interface parallèles supprimées.

### Contrats et moteur

- [x] contrat commun `DJBackend` ;
- [x] registre des backends ;
- [x] sélection explicite et persistance ;
- [x] blocage du changement pendant le Live ;
- [x] commandes universelles `DJControlAction` ;
- [x] cycle Requested / Sent / Acknowledged / Observed / Verified / Failed / Unknown ;
- [x] matrice détaillée des capacités ;
- [x] fallbacks de transitions ;
- [x] mocks complet, partiel, instable, lecture seule et déconnecté ;
- [x] file de commandes, timeout, idempotence et circuit breaker ;
- [x] coordinateur Live indépendant du nom du logiciel ;
- [x] Autopilote complet bloqué sans lecture d’état fiable ;
- [x] refus d’un coordinateur Live construit pour un autre backend ;
- [x] invalidation immédiate des capacités dépendantes de l’Accessibilité ;
- [x] scénarios simulés réellement bloquants pour backend perdu, commande non confirmée et changement de version.

### Backends officiels

- [x] `DjayBackend` ;
- [x] `RekordboxBackend` ;
- [x] `SeratoBackend` ;
- [x] politiques de capacités séparées pour les trois logiciels ;
- [x] détection commune installation/processus/version ;
- [x] validations enregistrées par backend, version, contrôleur et mapping ;
- [x] capacités différentes affichées sans hiérarchie produit.

L’existence d’un adaptateur ne vaut pas validation matérielle. Les capacités restent associées à leur statut réel.

### Interface Mac

- [x] écran de sélection avec trois cartes égales ;
- [x] navigation réduite à Préparer, Vérifier, Live et Avancé ;
- [x] nouveau workspace unifié ;
- [x] messages visibles réécrits avec problème, impact et action ;
- [x] termes Cloud et Supabase retirés du parcours normal ;
- [x] outils propres au backend déplacés dans une carte contextuelle d’Avancé ;
- [x] entrées globales parallèles rekordbox/Serato retirées du menu macOS ;
- [x] export diagnostic multi-backend sans titres ni artistes par défaut.

### iPhone Remote

- [x] contrat partagé Remote v2 ;
- [x] négociation compatible v1/v2 sur le Mac et l’iPhone ;
- [x] compatibilité de lecture des snapshots v1 ;
- [x] backend et version transmis ;
- [x] backend du coordinateur Live utilisé comme source de vérité ;
- [x] deck, état audio et capacités dégradées transmis ;
- [x] reprise distante bloquée si les capacités courantes ou la surveillance audio ne sont plus prêtes ;
- [x] interface humanisée ;
- [x] commandes de haut niveau uniquement ;
- [x] Mac maintenu comme source de vérité ;
- [x] permissions Réseau local et service Bonjour déclarés dans les bundles Mac et iPhone.

### Services en ligne et Supabase

- [x] backend réel enregistré ;
- [x] version, contrôleur, mapping et capacités enregistrables ;
- [x] diagnostics en ligne désactivés par défaut ;
- [x] rétention limitée des événements ;
- [x] vues `security_invoker` ;
- [x] RLS et clé publiable conservées ;
- [x] correctifs distants limités au format réellement implémenté ;
- [x] commandes cloud limitées aux mises à jour, configuration et diagnostics ;
- [x] probe Supabase externe rendu non bloquant pour le build local ;
- [x] aucune dépendance des services en ligne dans le Live.

### Package, CI et distribution

- [x] test targets Runtime, System, Remote Bridge et Remote partagé déclarés ;
- [x] dépendance Supabase exclue du graphe Linux ;
- [x] SHA-256 rendu portable via CryptoKit / Swift Crypto ;
- [x] contrôle automatisé du manifest SwiftPM ;
- [x] runners définis via `ubuntu-latest` et `macos-latest` ;
- [x] bundle Mac préparé avec permissions audio, observation, réseau local et Bonjour ;
- [x] script DMG et vérification SHA-256 conservés comme étapes bloquantes.

### Documentation

- [x] README racine réécrit ;
- [x] README iPhone réécrit ;
- [x] architecture multi-backend ;
- [x] matrice des capacités ;
- [x] guides djay, rekordbox et Serato ;
- [x] protocole de validation commun ;
- [x] terminologie produit ;
- [x] parcours utilisateur ;
- [x] positionnement produit ;
- [x] audit de consolidation ;
- [x] contrôle documentaire CI ;
- [x] rapport final de refonte avec README, écrans, tests, limites et risques.

## CI et vérification actuelle

Les workflows macOS, iPhone et Linux du dépôt échouent actuellement avant leur première étape, sans checkout, log de compilation ni artefact. Le remplacement des images fixes par les alias officiels `ubuntu-latest` et `macos-latest` n’a pas modifié ce comportement. Ce blocage de provisionnement GitHub Actions ne permet pas de conclure sur le code.

Par conséquent, la refonte ne revendique pas encore :

- tests Swift complets verts sur la branche canonique ;
- build macOS réussi ;
- build iPhone complet réussi ;
- simulations 50/250 exécutées par la CI courante ;
- DMG produit depuis le head actuel ;
- checksum du head actuel ;
- validation des migrations dans un environnement neuf.

Les résultats RC2 antérieurs restent des résultats historiques. Ils ne sont pas automatiquement attribués à la refonte multi-backend.

Validations locales limitées déjà consignées : manifest partagé sous Linux, quatre tests du protocole Remote partagé et trois tests du package de modèles Remote iPhone. Elles ne valent pas validation macOS, iOS complète ou matérielle.

## Restant avant sortie du brouillon

### Code et migrations

- [ ] résoudre les éventuelles erreurs Swift 6 lorsque les runners exécutent réellement les étapes ;
- [ ] finaliser la migration des derniers noms historiques Accessibilité et import de playlist ;
- [ ] retirer le dernier store de sélection legacy non optionnel ;
- [ ] généraliser les modèles de correctifs distants au-delà des champs historiques rekordbox ;
- [ ] ajouter la réconciliation périodique de l’état backend pendant le Live ;
- [x] terminer les tests de migration des anciens projets et préférences ;
- [x] étendre le simulateur aux scénarios multi-backend critiques ;
- [ ] exécuter les advisors Supabase sécurité et performance ;
- [ ] corriger leurs éventuels résultats ;
- [ ] vérifier la migration Supabase sur un environnement de validation neuf.

### Documentation restante

- [ ] harmoniser les documents historiques qui ne sont plus des références courantes ;
- [ ] mettre à jour ou archiver le protocole Remote v1 historique ;
- [ ] mettre à jour les guides historiques de release et checkpoints après une CI réellement verte.

### Validation matérielle

- [ ] djay Automix supervisé ;
- [ ] djay MIDI direct ;
- [ ] rekordbox Mode Performance et CSV importé ;
- [ ] Serato contrôleur virtuel et XML ;
- [ ] chargement, lecture, volumes et Sync réels ;
- [ ] état des decks ;
- [ ] watchdog audio ;
- [ ] musique de secours ;
- [ ] Remote iPhone physique ;
- [ ] dix transitions ;
- [ ] trente minutes ;
- [ ] deux heures.

## Prochaine priorité

1. restaurer une exécution GitHub Actions réelle ;
2. corriger la compilation à partir de logs concrets ;
3. terminer les derniers chemins legacy et la réconciliation d’état ;
4. exécuter les advisors et migrations Supabase ;
5. exécuter la campagne matérielle ;
6. mettre la PR #29 en état de revue ;
7. ne fusionner qu’après validation explicite.
