# Rapport de durcissement de la fiabilité

Dernière mise à jour : 17 juillet 2026

## Périmètre

Ce rapport couvre les améliorations réalisées après la refonte multi-backend des PR #29 et #30. Il complète `TECHNICAL_BENCHMARK_AND_PRIOR_ART.md` et distingue systématiquement :

- **validé automatiquement** : compilé ou testé par un test déterministe exécuté ;
- **contrôlé statiquement** : invariant protégé par un script ou une revue de code ;
- **préparé pour validation macOS/iOS** : code écrit, mais build de plateforme non exécuté sur le head courant ;
- **validation matérielle requise** : impossible à conclure sans le Mac, l’iPhone, le logiciel DJ et le matériel réel.

Aucun résultat matériel n’est revendiqué dans ce document.

## Résumé

| Domaine | Amélioration | Niveau actuel |
|---|---|---|
| Remote Mac | restart borné du `NWListener` | politique portable testée ; intégration macOS à construire sur runner |
| Remote iPhone | reconnexion bornée sans replay de commande | politique portable testée ; build iOS requis |
| Audio | reconstruction après changement `AVAudioEngine` | machine de récupération implémentée ; build macOS requis |
| État backend | expiration des observations après deux secondes | tests portables exécutés |
| Validation commandes | contexte lié à macOS, Mac et build MixPilot | modèle et migration testés sous Swift 6.2.1 |
| Simulations | handoff manuel après pertes critiques | machine d’état compilée et scénarios isolés exécutés |
| CI longue | déclenchement manuel uniquement | contrôlé dans le workflow |

## 1. Listener Remote Mac

### Problème initial

Un état `NWListener.failed` arrêtait définitivement la télécommande. Le Live local continuait, mais la supervision iPhone ne revenait pas après une panne temporaire du réseau ou du service Bonjour.

### Correction

- politique `RemoteTransportRetryPolicy` ;
- maximum de cinq tentatives ;
- délais exponentiels bornés ;
- remise à zéro seulement après une période stable ;
- fermeture idempotente des sessions ;
- invalidation des tâches de retry par génération de cycle de vie ;
- aucune incidence sur le Live local lorsque le budget est épuisé.

### Validation

- quatre tests portables du calcul de retry ;
- compilation Swift 6.2.1 de la politique ;
- contrôle statique de la présence du retry et du message de continuité locale.

### Restant

- build macOS ;
- test réel de changement Wi-Fi ;
- disparition puis retour du service Bonjour ;
- plusieurs clients lents ou déconnectés pendant un broadcast.

## 2. Reconnexion iPhone

### Problème initial

Une perte WebSocket plaçait l’application en état déconnecté et demandait souvent une nouvelle action utilisateur.

### Correction

- reconnexion automatique vers le même Mac appairé ;
- budget et backoff bornés ;
- génération de transport pour ignorer les anciens callbacks ;
- conservation de la dernière séquence de snapshot acceptée ;
- resubscription à partir de cette séquence ;
- aucune file de commandes à rejouer ;
- arrêt explicite après épuisement du budget.

### Invariant de sécurité

Une commande créée avant la reconnexion n’est jamais renvoyée. La reconnexion restaure uniquement l’observation et les commandes futures explicitement demandées par l’utilisateur.

### Restant

- build et XCTest iOS ;
- mise en veille et réveil ;
- changement de Wi-Fi ;
- redémarrage du bridge Mac ;
- test avec anciennes séquences et snapshots dupliqués.

## 3. Changements de configuration audio

### Problème initial

Un changement de route, de fréquence ou de périphérique peut arrêter et désinitialiser `AVAudioEngine`. Les anciens buffers peuvent également arriver après une reconstruction.

### Correction

- observation de `AVAudioEngineConfigurationChange` ;
- génération de session audio ;
- retrait du tap et reconstruction hors callback Apple ;
- backoff borné ;
- signal `sourceAvailable = false` pendant la récupération ;
- invalidation des anciens buffers et des anciennes tâches de retry ;
- retour à un état arrêt propre après épuisement du budget.

### Restant

- compilation macOS complète ;
- changement réel de périphérique ;
- changement de fréquence d’échantillonnage ;
- retrait de l’interface audio pendant un Live ;
- vérification du retour correct du watchdog après reconstruction.

## 4. Fraîcheur de l’état backend

### Problème initial

Une observation pouvait rester marquée fiable même si son horodatage n’était plus compatible avec une décision Live immédiate.

### Correction

`StrictVerificationDJBackend` accepte uniquement un `DJBackendState` :

- marqué fiable par l’adaptateur ;
- âgé de zéro à deux secondes ;
- non daté dans le futur.

Toute autre lecture est rétrogradée en `isReliable = false` avant d’atteindre le Live ou le Remote.

### Validation

Tests portables :

- état récent accepté ;
- état ancien refusé ;
- état non fiable refusé ;
- état futur refusé ;
- intégration au wrapper strict vérifiée.

## 5. Contexte exact des validations de commandes

### Problème initial

Une validation était déjà liée au backend, à la version du logiciel, au contrôleur, au mapping et à la commande, mais pouvait survivre à :

- une mise à jour de macOS ;
- un changement de Mac ;
- une recompilation ou mise à jour de MixPilot.

### Correction

La clé comprend maintenant :

- version macOS ;
- modèle matériel `hw.model` ;
- build MixPilot ;
- backend ;
- version du logiciel DJ ;
- contrôleur ;
- hash/version du mapping ;
- commande.

Un build de développement sans `CFBundleVersion` utilise l’horodatage de modification de l’exécutable. Une recompilation invalide donc naturellement les anciennes confirmations.

### Compatibilité

Les anciens enregistrements restent décodables grâce aux champs optionnels. Ils ne sont toutefois plus autorisés à débloquer le Live, car leur contexte plateforme est incomplet.

### Validation

- compilation Swift 6.2.1 du modèle ;
- test de correspondance exacte ;
- rejet après changement d’OS, matériel ou build ;
- décodage d’un ancien JSON ;
- rejet d’une preuve simulée même si son détail contient une ancienne chaîne de confirmation.

## 6. Handoff après panne critique

### Problème initial

La simulation historique revenait automatiquement à `playing` après certaines pertes alors que le runtime produit rendait la main. Cela créait des succès simulés trompeurs.

### Politique corrigée

| Incident | Décision simulée |
|---|---|
| Perte Internet | récupération automatique locale |
| Saturation | récupération automatique contrôlée |
| Chargement lent / mauvais morceau | récupération automatique contrôlée |
| Silence critique | musique de secours, puis contrôle manuel |
| Logiciel DJ fermé | musique de secours, puis contrôle manuel |
| Source audio perdue | contrôle manuel immédiat |
| MIDI perdu | contrôle manuel immédiat |
| Checkpoint incohérent | contrôle manuel immédiat |
| Lecteur de secours en panne | arrêt sécurisé |

### Validation

Un paquet Swift 6.2.1 isolé a compilé la machine d’état et exécuté les scénarios suivants :

- silence vers secours puis manuel ;
- backend fermé vers secours puis manuel ;
- MIDI et source audio vers manuel ;
- Internet vers récupération puis lecture.

Des tests équivalents sont ajoutés dans `MixPilotCoreTests`.

## 7. Déclenchements GitHub Actions

Les workflows Core, macOS, iPhone et simulation longue restent manuels. Le déclenchement hebdomadaire de la simulation longue a été retiré pendant le blocage des runners afin d’éviter les notifications répétées.

Ils ne devront être réactivés automatiquement qu’après une exécution manuelle ayant atteint au minimum l’étape `checkout` et produit des logs exploitables.

## 8. Risques restant ouverts

### Logiciels propriétaires

L’observation détaillée des decks reste limitée par les interfaces publiques disponibles. La présence d’un titre dans une fenêtre ne constitue jamais une preuve de chargement ou de lecture.

### CoreMIDI horodaté

La coalescence et l’horloge monotone sont en place. La planification par `MIDITimeStamp` reste une expérimentation P1 à mesurer avant adoption.

### Charge longue durée

Les simulations logiques ne mesurent pas :

- mémoire résidente ;
- température ;
- pression thermique ;
- latence AX réelle ;
- retard CoreMIDI réel ;
- stabilité des drivers audio ;
- comportement de chaque version des trois logiciels.

### Matériel

Le catalogue de compatibilité restera vide ou `REQUIRES_DEVICE_VALIDATION` tant que chaque combinaison n’aura pas été testée physiquement.

## 9. Critères de sortie de la phase stabilisation

- [x] benchmark technique sourcé ;
- [x] restart borné du listener Mac ;
- [x] reconnexion bornée de l’iPhone ;
- [x] changements de configuration audio traités ;
- [x] preuves backend expirables ;
- [x] validation liée au contexte Mac/build ;
- [x] simulations de panne alignées sur le runtime ;
- [x] workflows automatiques laissés désactivés ;
- [ ] tests Swift complets du dépôt exécutés ;
- [ ] build macOS exécuté ;
- [ ] build iPhone exécuté ;
- [ ] simulations 50/250 exécutées sur le head final ;
- [ ] DMG et checksum du head final ;
- [ ] campagne matérielle.

Les cases non cochées dépendent soit du retour des runners GitHub, soit du matériel cible. Elles ne sont pas transformées artificiellement en succès.