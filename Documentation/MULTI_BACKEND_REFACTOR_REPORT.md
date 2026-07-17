# Rapport de refonte multi-backend

Dernière mise à jour : 17 juillet 2026

## 1. Branche de base utilisée

- cible : `release/0.3.0-rc.2` ;
- branche canonique : `feature/first-class-multi-backend` ;
- Pull Request : `#29` ;
- état : brouillon, non fusionnée.

## 2. Branches et Pull Requests inspectées

La consolidation a examiné les fondations et le runtime, la RC2, le Remote iPhone et son bridge, l’installation du mapping Serato, puis les travaux djay et rekordbox des PR empilées jusqu’à la PR #28.

La PR #29 remplace la chaîne fonctionnelle empilée par une branche canonique visant directement la dernière base de release consolidée.

## 3. Architecture avant

Les principaux problèmes confirmés étaient :

- runtime Live dépendant de noms et composants Serato ;
- sélection de logiciel reposant sur un modèle de capacités codées en dur ;
- préflight utilisant encore des états Serato spécifiques ;
- adaptateurs djay et rekordbox ajoutés autour d’une architecture historiquement Serato ;
- télémétrie pouvant enregistrer rekordbox en dur ;
- modèles Remote dupliqués ;
- plusieurs surfaces d’interface remplissant des rôles proches ;
- documentation principale centrée sur Serato.

## 4. Problèmes liés aux anciens prompts

Les couches successives avaient produit :

- plusieurs parcours de préparation et de configuration ;
- des laboratoires devenus des fonctions produit sans migration éditoriale complète ;
- des modèles anciens conservés pour compatibilité au milieu des nouveaux contrats ;
- des validations automatisées, simulées et matérielles parfois trop proches dans les textes ;
- une chaîne de PR empilées difficile à considérer comme base canonique.

L’audit détaillé se trouve dans `Documentation/MULTI_BACKEND_AUDIT.md`.

## 5. Éléments redondants trouvés

- anciennes interfaces principales parallèles ;
- ancien sélecteur `DJSoftware` utilisé comme source de vérité ;
- bridge Accessibilité nommé Serato alors qu’il observait plusieurs logiciels ;
- adaptateur standard unique contenant des `switch` pour les trois backends ;
- modèles Remote Mac/iPhone avant contrat partagé ;
- probe environnement nommé Serato alors que son rôle était générique.

## 6. Éléments fusionnés

- contrat Remote dans `Shared/RemoteProtocolV2` ;
- navigation principale dans Préparer / Vérifier / Live / Avancé ;
- intentions de commandes dans `DJBackendCommand` et `DJControlAction` ;
- matrice des capacités et validation Live ;
- contexte cloud multi-backend ;
- préparation et négociation des transitions dans le cœur indépendant.

## 7. Éléments supprimés

Les anciennes surfaces parallèles suivantes sont interdites par la CI d’architecture :

- `Sources/MixPilotApp/ContentView.swift` ;
- `Sources/MixPilotApp/BrandedRootView.swift` ;
- `Sources/MixPilotApp/AdvancedContentView.swift`.

Leur retour provoque désormais un échec du contrôle de cohérence.

## 8. Éléments renommés ou conservés pour migration

- `DJBackendIdentifier` remplace le rôle actif de `DJSoftware` ;
- `DJAccessibilityBridge` remplace l’usage actif du bridge nommé Serato ;
- `DJEnvironmentProbe` remplace le probe Serato générique ;
- certains alias historiques restent dépréciés afin de lire les anciens projets et préférences sans casser la migration.

## 9. Architecture après

- `MixPilotCore` : préparation, transitions, contrats backend, capacités, sécurité, migrations et diagnostics purs ;
- `MixPilotMIDI` : contrôleur virtuel et mapping générique ;
- `MixPilotSystem` : adaptateurs spécifiques, Accessibilité, audio, fichiers et services facultatifs ;
- `MixPilotRuntime` : coordinateur Live et file de commandes ;
- `MixPilotRemoteBridge` : réseau local, appairage et décisions du Mac ;
- `MixPilotApp` : expérience Préparer / Vérifier / Live / Avancé ;
- `Mobile/MixPilotRemote` : télécommande générique.

Les règles propres aux backends sont maintenant séparées dans :

- `SeratoBackendPolicy` ;
- `RekordboxBackendPolicy` ;
- `DjayBackendPolicy`.

Le transport et les protections réellement communs restent mutualisés sans cacher les différences de capacités.

## 10. Fichiers ajoutés significatifs

Notamment :

- contrats et validations multi-backend ;
- runtime de file de commandes ;
- diagnostics et simulations multi-backend ;
- contrat Remote v2 partagé ;
- migrations de préférences, projets, checkpoints et cloud ;
- contrôles `check_package_manifest.sh`, `check_source_architecture.sh` et `check_documentation_consistency.sh` ;
- tests de registre, migration, capacités, Remote, runtime et contexte cloud ;
- `DJRuntimeAvailability.swift` pour invalider les capacités Accessibilité lorsque la permission courante est absente.

## 11. Fichiers modifiés significatifs

Les changements couvrent notamment :

- `Package.swift` ;
- les workflows Core, macOS et iPhone ;
- `AppModel` et ses extensions ;
- le préflight ;
- le runtime Live ;
- les adaptateurs djay, rekordbox et Serato ;
- le bridge et le client Remote ;
- les services en ligne ;
- les README et documents principaux.

## 12. Fichiers supprimés

Les anciennes interfaces parallèles identifiées dans la section 7 ont été retirées. Les alias techniques historiques encore nécessaires sont conservés de manière dépréciée et isolée.

## 13. Migrations locales

- ancienne préférence explicite de logiciel vers `DJBackendIdentifier` ;
- suppression de la clé ancienne après migration ;
- projets sans backend conservés mais bloqués avant le Live jusqu’au choix explicite ;
- checkpoints versionnés avec backend ;
- snapshots Remote v1 toujours décodables ;
- validations de commandes liées au backend, à la version, au contrôleur et à l’empreinte du mapping.

## 14. Migrations Supabase

Les migrations ajoutent ou consolident :

- contexte multi-backend ;
- versions de logiciels ;
- informations de mapping et capacités ;
- politiques RLS ;
- rétention de la télémétrie ;
- durcissement des privilèges des vues exposées.

Le contexte de session et les heartbeats utilisent le backend réellement sélectionné. Le Live reste indépendant de ces services.

## 15. Tests exécutés

### Exécutés localement avec succès

En environnement Swift 6.2.1 Linux, avec caches redirigés vers un répertoire inscriptible :

- package `Shared/RemoteProtocolV2` : 4 tests réussis ;
- package `Mobile/MixPilotRemote` pour les modèles et la politique de séquence : 3 tests réussis ;
- vérification du manifest SwiftPM partagé : réussie sur Linux sans résolution de Supabase ni inclusion des cibles macOS.

Ces résultats sont des succès automatisés locaux limités à ces packages. Ils ne valent pas build macOS, build iPhone complet ou validation matérielle.

### Ajoutés mais non exécutés par GitHub Actions

- sécurité de la file de commandes ;
- résultat incertain et timeout ;
- blocage du Live sans état fiable ;
- reprise manuelle coopérative pendant une transition ;
- révocation de la permission Accessibilité ;
- registre et migration de backend ;
- contexte cloud multi-backend ;
- simulations multi-backend.

## 16. Résultats CI

Au dernier commit vérifié, les trois workflows sont créés mais échouent avant leur première étape :

- Core, Remote and Documentation CI ;
- macOS CI ;
- iPhone Remote CI.

Le job Core le plus récent retourne `steps: none`, aucun log et aucun checkout. Aucun test Swift du dépôt, build macOS, build iPhone complet, DMG ou checksum du commit courant n’est donc revendiqué.

Ce blocage est classé comme infrastructure GitHub Actions ou provisionnement du compte, distinct d’une erreur de compilation observable. La PR reste brouillon tant qu’il n’est pas levé.

## 17. README trouvés

L’inventaire a trouvé :

- `README.md` ;
- `Mobile/MixPilotRemote/README.md`.

## 18. README mis à jour

Les deux README ont été réécrits pour :

- présenter les trois backends au même niveau ;
- rappeler que capacités officielles et capacités validées ne sont pas synonymes ;
- expliquer le Mac source de vérité ;
- documenter les modes locaux, les validations, les limites et le Remote générique.

## 19. Documentation mise à jour

Notamment :

- architecture multi-backend ;
- matrice des capacités ;
- parcours utilisateur ;
- terminologie ;
- intégrations djay, rekordbox et Serato ;
- Remote ;
- services en ligne ;
- validation finale ;
- statut de développement et de release.

## 20. Capacités djay

Disponibles dans le contrat :

- détection d’installation, processus et version ;
- observation protégée ;
- préparation du set ;
- matrice MIDI générique ;
- description officielle des modes Automix supervisé et MixPilot avancé.

Restent non validés sur le Mac cible :

- lecture fiable et versionnée de la file Automix ;
- préparation et contrôle natifs de la file ;
- déclenchement et confirmation de transition ;
- état détaillé des decks ;
- profil MIDI réel et réactions des commandes.

Le runtime direct n’invente aucune commande Automix. Le mode ne doit pas être déclaré prêt avant implémentation et validation d’un chemin réellement observable.

## 21. Capacités rekordbox

Présentes :

- import XML et JSON adaptatif ;
- génération et validation du CSV MIDI à quinze colonnes ;
- provenance et empreintes ;
- sauvegarde et restauration ;
- actions Accessibilité protégées ;
- validation commande par commande.

Restent à valider physiquement : import du CSV, réactions Load/Play/Volume/Sync, lecture fiable de l’état et endurance.

## 22. Capacités Serato

Présentes :

- contrôleur virtuel CoreMIDI ;
- détection du logiciel et de la version ;
- génération, installation, sauvegarde et rollback XML ;
- assistant et validation commande par commande ;
- observation protégée.

Restent à valider physiquement : visibilité du contrôleur, activation MIDI, réactions exactes, lecture d’état, audio et endurance.

## 23. Fonctions encore non validées

- lecture détaillée et fiable des decks pour les trois logiciels ;
- Automix djay ;
- réaction réelle des commandes ;
- import rekordbox réel ;
- routage audio et absence de blanc ;
- appairage et reconnexion sur appareils physiques ;
- endurance ;
- build, DMG, signature et checksum du commit courant sur macOS.

## 24. Tests matériels nécessaires

Pour chaque backend : installation, version, mapping, Load, Play/Pause, Sync, volumes, état des decks, transition simple, reprise manuelle, perte du logiciel, récupération, Remote iPhone, dix transitions, trente minutes puis deux heures.

## 25. Messages et parcours humanisés

Les surfaces principales utilisent désormais :

- Choisir le logiciel ;
- Préparer ;
- Vérifier ;
- Live ;
- Reprendre la main ;
- Services en ligne ;
- Musique de secours.

Les erreurs techniques sont traduites en impact et action utilisateur. Les détails internes restent dans les diagnostics avancés.

## 26. Correctifs de sécurité ajoutés pendant la reprise

- isolation de Supabase et des cibles macOS dans `Package.swift` ;
- déclaration explicite des test targets ;
- contrôle automatisé du graphe SwiftPM ;
- séparation des politiques djay, rekordbox et Serato ;
- probe environnement avec backend explicite ;
- négociation Remote v1/v2 symétrique ;
- réponse du bridge dans la version négociée avec chaque client ;
- correction du test iPhone qui importait le mauvais module ;
- acceptation d’un nouveau flux de snapshots après redémarrage du Mac ;
- invalidation runtime des capacités Accessibilité après révocation de la permission ;
- reprise manuelle coopérative sans annulation brutale ni libération anticipée du backend ;
- garde-fous CI empêchant le retour de ces régressions.

## 27. Risques restants

- GitHub Actions ne démarre aucune étape ;
- les cibles macOS ne peuvent pas être compilées dans l’environnement Linux local ;
- les lecteurs d’état réels dépendent des interfaces et versions installées ;
- aucune validation matérielle ne doit être déduite des mocks ou simulations ;
- les modes natifs non implémentés doivent rester bloqués même s’ils sont officiellement prévus.

## 28. Prochaines étapes recommandées

1. rétablir l’exécution GitHub Actions ;
2. corriger les erreurs Swift éventuellement révélées ;
3. produire les artefacts macOS et iPhone ;
4. exécuter la campagne matérielle commune ;
5. seulement après la clôture réelle de cette PR, lancer le benchmark, la stabilisation approfondie, le centre d’aide multilingue et le nettoyage final dans une PR distincte.

## Conclusion

La refonte structurelle et éditoriale est largement réalisée, mais la PR ne peut pas être déclarée terminée ou verte tant que les runners n’exécutent pas ses tests et que les validations matérielles restent absentes. Le statut honnête demeure : code consolidé et protections renforcées, validation finale en attente.
