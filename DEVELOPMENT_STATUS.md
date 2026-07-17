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
- [x] Autopilote complet bloqué sans lecture d’état fiable.

### Backends officiels

- [x] `DjayBackend` ;
- [x] `RekordboxBackend` ;
- [x] `SeratoBackend` ;
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
- [x] outils rekordbox/Serato déplacés dans Avancé ;
- [x] export diagnostic multi-backend sans titres ni artistes par défaut.

### iPhone Remote

- [x] contrat partagé Remote v2 ;
- [x] compatibilité de lecture des snapshots v1 ;
- [x] backend et version transmis ;
- [x] deck, état audio et capacités dégradées transmis ;
- [x] interface humanisée ;
- [x] commandes de haut niveau uniquement ;
- [x] Mac maintenu comme source de vérité.

### Services en ligne et Supabase

- [x] backend réel enregistré ;
- [x] version, contrôleur, mapping et capacités enregistrables ;
- [x] diagnostics en ligne désactivés par défaut ;
- [x] rétention limitée des événements ;
- [x] vues `security_invoker` ;
- [x] RLS et clé publiable conservées ;
- [x] correctifs distants limités au format réellement implémenté ;
- [x] aucune dépendance des services en ligne dans le Live.

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
- [x] audit de consolidation.

## CI et vérification actuelle

Les workflows macOS, iPhone et Linux du dépôt échouent actuellement avant leur première étape, sans checkout, log de compilation ni artefact. Ce blocage de provisionnement GitHub Actions ne permet pas de conclure sur le code.

Par conséquent, la refonte ne revendique pas encore :

- tests Swift verts sur la branche canonique ;
- build macOS réussi ;
- build iPhone réussi ;
- DMG produit ;
- checksum de cette branche ;
- validation des migrations dans un environnement neuf.

Les résultats RC2 antérieurs restent des résultats historiques. Ils ne sont pas automatiquement attribués à la refonte multi-backend.

## Restant avant sortie du brouillon

### Code et migrations

- [ ] résoudre les éventuelles erreurs Swift 6 lorsque les runners exécutent réellement les étapes ;
- [ ] finaliser la migration des noms historiques Accessibilité et import de playlist ;
- [ ] retirer le dernier store de sélection legacy non optionnel ;
- [ ] généraliser les modèles de correctifs distants au-delà des champs historiques rekordbox ;
- [ ] ajouter la réconciliation périodique de l’état backend ;
- [ ] terminer les tests de migration des anciens projets et préférences ;
- [ ] étendre le simulateur aux scénarios multi-backend demandés ;
- [ ] exécuter les advisors Supabase sécurité et performance ;
- [ ] corriger leurs éventuels résultats ;
- [ ] vérifier la migration Supabase sur un environnement de validation neuf.

### Documentation

- [ ] harmoniser les documents historiques restants ;
- [ ] mettre à jour les protocoles Remote historiques ;
- [ ] mettre à jour les guides de release et checkpoints ;
- [ ] ajouter le contrôle documentaire CI ;
- [ ] produire le rapport final complet avec la liste exacte des README et écrans.

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
3. terminer les tests et migrations ;
4. exécuter la campagne matérielle ;
5. mettre la PR #29 en état de revue ;
6. ne fusionner qu’après validation explicite.
