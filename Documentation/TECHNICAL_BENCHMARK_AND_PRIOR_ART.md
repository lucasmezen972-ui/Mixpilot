# Benchmark technique et état de l’art de MixPilot

Dernière mise à jour : 17 juillet 2026

## Objet

Ce document compare MixPilot aux fonctions d’automatisation, de contrôle MIDI, de télécommande et de fiabilité disponibles dans les principaux logiciels DJ et dans plusieurs projets ouverts. Il confronte ensuite ces pratiques aux frameworks Apple utilisés par MixPilot.

Le but n’est pas de copier un produit ni de contourner ses protections. Le but est d’identifier des principes d’architecture, des contrats de sécurité et des stratégies de test réutilisables proprement.

## Méthode

Les sources ont été classées par ordre de confiance :

1. documentation officielle des éditeurs ;
2. documentation Apple ;
3. dépôts et documentation de projets ouverts reconnus ;
4. travaux de recherche ;
5. inférences explicitement signalées.

Les fonctionnalités observées dans une interface ne sont jamais assimilées à une API publique. Une fonction MIDI configurable ne prouve pas qu’un logiciel expose son état de façon fiable. Une fonction Automix ne prouve pas qu’un tiers peut la piloter ou la superviser.

## Résumé exécutif

MixPilot possède déjà plusieurs choix architecturaux plus prudents que beaucoup d’outils comparables :

- le Mac reste la source de vérité ;
- le Live est local-first ;
- les commandes critiques exigent une preuve renforcée ;
- les capacités sont liées au backend, à la version, au contrôleur et au mapping ;
- la reprise après interruption reste manuelle ;
- le Remote transporte des intentions de haut niveau et non des octets MIDI ;
- les correctifs distants ne publient pas d’artefact inventé pour un backend qui n’en possède pas.

Les principaux écarts restant à traiter ne concernent pas la structure multi-backend. Ils concernent l’observabilité et l’exploitation longue durée :

1. dépendance encore forte à l’Accessibilité pour observer les logiciels propriétaires ;
2. absence de redémarrage borné du listener Remote après une panne réseau ;
3. reconnexion iPhone encore limitée ;
4. absence de gestion explicite des changements de configuration `AVAudioEngine` ;
5. émission CoreMIDI principalement immédiate, sans planification par horodatage hôte ;
6. catalogue de compatibilité matériel/version encore à construire par validation réelle ;
7. absence de campagne automatisée de durée mesurant mémoire, cadence, files d’attente et dérive.

La priorité n’est donc pas d’ajouter davantage de fonctions de transition. La priorité est de rendre chaque dépendance externe observable, bornée, redémarrable et honnêtement qualifiée.

---

## 1. Produits et projets comparables

### 1.1 djay Pro / Automix

La documentation Algoriddim présente Automix comme une file de lecture automatique avec :

- choix du type de transition ;
- durée automatique, en mesures ou en secondes ;
- gestion du tempo ;
- points d’entrée et de sortie automatiques ou manuels ;
- durée maximale de lecture ;
- commandes Skip et Mix Now.

La cartographie MIDI distingue correctement les boutons, notes, Control Change, valeurs minimales/maximales et retours MIDI vers les LED. Les configurations peuvent être dupliquées, partagées et installées.

#### Enseignements pour MixPilot

- Les réglages musicaux doivent rester séparés des contrats de fiabilité.
- Un profil de transition doit être éditable, prévisualisable et versionné.
- Les types MIDI doivent faire partie du contrat du mapping, pas seulement de l’interface.
- Les configurations doivent pouvoir être sauvegardées, comparées et restaurées.
- djay possède déjà un Automix riche : la valeur de MixPilot sur ce backend est principalement la préparation, la supervision, le Remote, le watchdog et la reprise sûre, pas la duplication de tout le moteur Automix.

#### Limite importante

La documentation publique décrit l’utilisation et le MIDI Learn. Elle ne constitue pas une API publique d’observation des decks ou de contrôle automatisé externe.

### 1.2 rekordbox

rekordbox expose MIDI LEARN pour de nombreuses fonctions, y compris certaines fonctions avancées comme MIX POINT LINK et les Stems. L’accès peut dépendre d’un abonnement ou d’un appareil Hardware Unlock. La documentation avertit aussi que la mémoire disponible, les applications résidentes, le buffer audio et les réglages d’économie d’énergie peuvent affecter le fonctionnement.

MIX POINT LINK représente un précédent intéressant : la préparation relie un point de sortie à un point d’entrée, puis le logiciel déclenche le morceau suivant lorsque la barre de lecture atteint le point configuré.

#### Enseignements pour MixPilot

- Le préflight doit vérifier non seulement le logiciel, mais aussi le plan/licence et le mode actif qui rendent la fonction disponible.
- Les capacités peuvent disparaître sans changement de mapping, par exemple après changement d’abonnement, d’appareil ou de mode.
- Les mix points préparés doivent être stockés comme décisions explicites et validables.
- La mémoire, l’alimentation et le buffer audio doivent être intégrés au protocole de validation longue durée.
- Le CSV rekordbox doit rester un artefact recompilé et vérifié localement, ce que MixPilot fait déjà.

#### Limite importante

MIDI LEARN ne fournit pas une API de retour d’état complète. Une commande mappable n’implique pas une preuve structurée de son effet.

### 1.3 Serato DJ Pro

Serato permet de mapper une fonction à un contrôleur principal remappable, à un contrôleur MIDI secondaire ou à un accessoire officiel. Les mappings peuvent être enregistrés sous forme de presets XML. La documentation recommande un preset par matériel et avertit qu’un mapping peut rester chargé tout en ne correspondant plus au matériel connecté.

Serato distingue plusieurs modes de données MIDI pour les contrôles continus : absolu et plusieurs formats relatifs. La documentation recommande également de mapper bouton vers bouton, fader vers fader et potentiomètre vers potentiomètre. Certaines fonctions matérielles ne sont pas remappables, notamment plusieurs jog wheels, switches et modes de pads.

#### Enseignements pour MixPilot

- Le mapping doit être lié à l’identité du contrôleur et pas seulement au logiciel.
- Les contrôles continus ont besoin d’un type de données explicite, au-delà du simple couple Note/CC.
- Un mapping sauvegardé n’est pas une validation de compatibilité.
- La disponibilité du bouton MIDI et des fonctions mappables doit être vérifiée dans le préflight.
- Les limitations matérielles doivent apparaître dans la matrice des capacités au lieu d’être masquées par un profil universel.

### 1.4 VirtualDJ

VirtualDJ possède un Automix configurable et un éditeur de transitions par paire de titres. L’éditeur permet de déplacer les titres sur une timeline, d’ajuster les points de mix, d’activer le BPM matching et de conserver les réglages pour une paire donnée.

VirtualDJ utilise un seul deck pour Automix afin de garder les autres decks disponibles. Son application Remote iOS/Android se connecte en Wi-Fi et nécessite une acceptation locale.

#### Enseignements pour MixPilot

- Une décision de transition peut être mémorisée par paire de morceaux, avec une provenance et une possibilité de réinitialisation.
- L’utilisateur doit pouvoir préécouter les zones de transition avant le Live.
- Un mode Automix natif supervisé peut être plus fiable qu’un contrôle direct sur deux decks lorsque le backend le permet.
- L’appairage du Remote doit rester local, explicite et révocable.
- La télécommande ne doit pas devenir indispensable au Live.

### 1.5 Mixxx

Mixxx est un logiciel DJ libre sous GPLv2. Il fournit Auto DJ, une large collection de mappings MIDI/HID et un système de scripts JavaScript pour les contrôleurs. Les scripts peuvent transformer les valeurs, gérer des modificateurs, envoyer des retours MIDI et connecter des callbacks à des contrôles internes.

Mixxx documente clairement qu’une compatibilité matérielle dépend de l’existence et de la qualité d’un mapping. Le projet conserve des catégories de mappings certifiés, communautaires, en développement et non disponibles.

#### Enseignements pour MixPilot

- La classification `certifié / communautaire / expérimental / absent` est plus honnête qu’un booléen compatible.
- Les transformations de valeurs et modes relatifs doivent être des données ou des stratégies versionnées.
- Les callbacks d’état valent mieux qu’un polling global lorsqu’ils sont disponibles.
- Le retour MIDI peut servir à vérifier une partie de l’état d’un contrôleur, mais ne prouve pas à lui seul l’état audio.
- Les mappings doivent avoir des tests de contrat et des fixtures par matériel.

#### Licence

Mixxx et plusieurs projets Automix ouverts sont sous GPL. Leurs idées, architecture observable et stratégies de test peuvent être étudiées. Leur code ne doit pas être copié dans MixPilot sans analyser les obligations de licence. Pour cette phase, aucune copie de code Mixxx n’est recommandée.

### 1.6 Projets audio et MIDI ouverts

AudioKit fournit une plateforme Swift d’analyse et de traitement audio sous licence MIT. RtMidi fournit une abstraction MIDI multiplateforme et rappelle l’importance des ports virtuels, de la durée entre Note On/Off et de la fermeture explicite des ressources.

Ces bibliothèques peuvent servir de référence ou de fixture, mais MixPilot utilise déjà directement les frameworks Apple. Ajouter une dépendance n’est justifié que si elle réduit réellement le risque ou fournit une capacité testée manquante.

### 1.7 Recherche sur les transitions automatiques

Des travaux de recherche ont exploré l’apprentissage de transitions avec EQ et fader différentiables, ainsi que la transcription de mixes existants. Ces travaux confirment que l’automatisation musicale peut bénéficier de modèles appris et de données de mixes réels.

#### Décision pour MixPilot

L’apprentissage automatique ne doit pas entrer dans le chemin Live critique maintenant. Il peut être utilisé plus tard hors ligne pour proposer des paramètres de transition, à condition que :

- la proposition soit convertie en plan déterministe ;
- les bornes et fallbacks soient explicites ;
- le Live n’ait aucune dépendance réseau ou modèle ;
- une transition faible soit remplacée par un fallback conservateur.

---

## 2. Références Apple et conséquences architecturales

### 2.1 CoreMIDI

CoreMIDI fournit des paquets et des listes d’événements avec un `MIDITimeStamp`. Pour un envoi, l’horodatage représente le moment où l’événement doit être joué ; zéro signifie immédiatement.

#### État MixPilot

MixPilot publie un contrôleur virtuel CoreMIDI, vérifie sa visibilité et sérialise les envois. Les commandes momentanées de la couche mappée possèdent une durée minimale et une extinction garantie.

#### Amélioration recommandée

Pour les transitions à cadence élevée, étudier une planification par timestamp hôte plutôt que des successions de `Task.sleep`. Le premier objectif n’est pas MIDI 2.0 en soi, mais :

- réduire la dérive ;
- grouper les événements proches ;
- garantir l’ordre ;
- mesurer le retard réel ;
- abandonner les événements devenus inutiles.

Le passage aux Universal MIDI Packets ne doit être engagé que si un backend ou un matériel en bénéficie réellement.

### 2.2 Accessibilité macOS

`AXUIElement` permet de communiquer avec les éléments accessibles d’une application et de recevoir des notifications. Les appels peuvent échouer avec des erreurs telles que `invalidUIElement`, `cannotComplete` ou `notImplemented`.

#### Conséquence

Une lecture AX ne doit jamais être considérée fiable simplement parce qu’elle n’a pas levé d’exception. Elle a besoin :

- d’un élément encore valide ;
- d’une version et d’un layout reconnus ;
- d’attributs attendus ;
- d’une fraîcheur maximale ;
- d’une cohérence avec plusieurs signaux ;
- d’un fallback manuel.

Lorsque le logiciel émet des notifications AX utiles, elles doivent compléter le polling périodique. Le polling complet de toute la fenêtre doit rester borné et ne jamais être déclenché à chaque frame MIDI.

### 2.3 AVAudioEngine

Apple indique qu’un changement de configuration du matériel audio peut arrêter et désinitialiser l’engine. Une notification `AVAudioEngineConfigurationChangeNotification` est envoyée. Les nœuds restent attachés, mais les connexions peuvent devoir être reconstruites. Apple déconseille de désallouer l’engine directement dans le callback interne.

#### Conséquence

Le watchdog MixPilot doit traiter un changement de configuration comme un état distinct :

1. suspendre l’interprétation des niveaux ;
2. invalider l’ancienne génération de callbacks ;
3. reconstruire ou redémarrer l’engine hors du callback ;
4. vérifier le format et la source ;
5. réarmer le watchdog ;
6. rendre la main si la reconstruction échoue.

### 2.4 Network.framework

`NWConnection` et `NWListener` exposent des états explicites : setup, waiting, preparing, ready, failed et cancelled. `NWConnection` fournit également les mises à jour de chemin, de viabilité et de meilleure route.

#### Conséquence

Le Remote doit utiliser une machine à états et non un simple booléen connecté. Une attente due à un changement de Wi-Fi ne doit pas être traitée comme un succès, mais ne doit pas non plus déclencher une boucle de reconnexion agressive.

Recommandation :

- retry borné et exponentiel ;
- jitter déterministe testable ;
- reset après une période stable ;
- aucune commande implicite après reconnexion ;
- nouvelle authentification ou reprise de session contrôlée ;
- dernière séquence de snapshot conservée ;
- fermeture idempotente des sessions.

---

## 3. Comparaison synthétique

| Sujet | djay | rekordbox | Serato | VirtualDJ | Mixxx | MixPilot |
|---|---|---|---|---|---|---|
| Automix intégré | Oui, très configurable | Fonctions de mix points | Limité selon workflow | Oui, éditeur détaillé | Auto DJ | Planificateur + supervision |
| Mapping MIDI | Oui | MIDI LEARN | MIDI assign | Oui | MIDI/HID + scripts | Profils versionnés multi-backend |
| Retour d’état public structuré | Non documenté | Non documenté | Non documenté | Interne au produit | Oui dans le moteur ouvert | Variable, souvent AX |
| Télécommande mobile | Fonctions produit | Écosystème propre | Écosystème propre | Remote Wi-Fi | Contrôleurs/scripts | Remote local, Mac source de vérité |
| Mapping qualifié par matériel | Configurations | Matériel/plan | Preset conseillé par matériel | Oui | Catégories de mappings | Backend + version + contrôleur + hash |
| Fallback manuel | Interface produit | Interface produit | Interface produit | Interface produit | Contrôle complet | Reprise coopérative au point sûr |
| Transparence du code | Fermé | Fermé | Fermé | Fermé | Ouvert GPLv2 | Privé, contrats et tests documentés |

---

## 4. Audit de l’architecture MixPilot par rapport à l’état de l’art

### Forces confirmées

1. **Contrat backend commun** : évite de confondre nom du logiciel et capacité réelle.
2. **Matrice de capacités** : plus honnête qu’un support global oui/non.
3. **Vérification stricte des commandes critiques** : une observation faible ne débloque pas le Live.
4. **Idempotence et circuit breaker** : pratiques adaptées aux systèmes distribués appliquées au contrôle local.
5. **Réconciliation périodique** : détecte fermeture, changement de backend et contradictions fiables.
6. **Watchdog audio à états** : évite le spam d’incidents et les faux retours sains.
7. **Remote de haut niveau** : limite la surface de commande et conserve le Mac comme source de vérité.
8. **Récupération conservatrice** : aucun redémarrage automatique après crash.
9. **Correctifs distants signés et spécifiques au backend** : aucun artefact fictif.
10. **Live sans dépendance cloud** : choix essentiel pour la résilience.

### Écarts prioritaires

#### A. Listener Remote non redémarré après panne

Le bridge arrête actuellement le Remote après un état listener `failed`. Il ne possède pas de politique de redémarrage bornée. Cela ne doit pas interrompre le Live, mais réduit la capacité de supervision après un changement de réseau.

**Action P0** : ajouter une politique de restart avec backoff, compteur, reset stable et annulation explicite.

#### B. Reconnexion iPhone limitée

La perte du WebSocket place le client en état déconnecté. La reprise nécessite encore une action utilisateur dans plusieurs cas.

**Action P1** : reconnexion automatique bornée vers le même Mac appairé, sans rejouer aucune commande et en reprenant seulement les snapshots plus récents.

#### C. Changements de configuration audio

Le watchdog distingue silence, saturation et source indisponible, mais doit posséder un chemin dédié pour `AVAudioEngineConfigurationChangeNotification`.

**Action P0** : redémarrage générationnel de l’engine et test de reconfiguration simulée.

#### D. Horodatage MIDI

Les valeurs sont coalescées et les frames périmées abandonnées, mais l’envoi utilise encore principalement “maintenant”.

**Action P1** : mesurer la dérive et expérimenter les timestamps CoreMIDI pour les courbes planifiées.

#### E. Observabilité AX

L’observation générique collecte principalement du texte et ne peut pas honnêtement déduire tous les états de decks.

**Action P0** : formaliser une preuve composite avec source, fraîcheur, version, attributs et confiance. Ne jamais augmenter automatiquement la confiance grâce à un titre visible seul.

#### F. Catalogue de compatibilité

Les validations sont stockées par contexte, mais la campagne physique n’a pas commencé.

**Action P0 matériel** : catalogue signé par version de logiciel, version macOS, contrôleur, mapping, commandes validées, durée et date.

#### G. Mesures longue durée

Les simulations valident la logique, pas la charge réelle des frameworks macOS.

**Action P1** : instrumentation locale de :

- mémoire résidente ;
- nombre de tâches ;
- profondeur des files ;
- cadence de snapshots ;
- retard MIDI ;
- temps des lectures AX ;
- interruptions audio ;
- reconnexions réseau ;
- température et pression thermique lorsque disponible.

---

## 5. Priorités d’implémentation

### P0 — avant campagne matérielle longue

1. `RemoteListenerRestartPolicy` pure et testable.
2. redémarrage borné du listener sans impact sur le Live.
3. gestion explicite des changements `AVAudioEngine`.
4. preuve d’observation structurée et fraîcheur maximale.
5. journal de compatibilité par contexte réel.
6. scénario de fermeture et relance du logiciel DJ pendant un Live simulé.
7. scénario de disparition et retour du port MIDI.
8. scénario de changement de route audio.

### P1 — avant bêta personnelle prolongée

1. reconnexion iPhone bornée et reprise de séquence ;
2. métriques de durée exportables sans données musicales ;
3. planification CoreMIDI horodatée expérimentale ;
4. test de deux heures avec horloge accélérée et sans croissance de file ;
5. test de 10 000 commandes continues coalescées ;
6. replay déterministe des incidents ;
7. matrice de compatibilité visible dans l’application.

### P2 — après validation réelle des trois backends

1. mémorisation de transitions validées par paire ;
2. préécoute et édition graphique des mix points ;
3. suggestions musicales hors ligne ;
4. apprentissage à partir des corrections manuelles, sans dépendance Live ;
5. support MIDI 2.0 uniquement sur preuve d’un bénéfice concret.

---

## 6. Proposition de contrats techniques

### 6.1 Preuve d’état backend

```text
BackendObservationEvidence
- backend
- softwareVersion
- controllerIdentity
- source: accessibility | midiFeedback | audio | nativeMode | userValidation
- observedAt
- maximumAge
- attributesSeen
- confidence: unknown | observed | validated
- contradictions
```

Une capacité critique est confirmée uniquement si les preuves exigées sont présentes, fraîches et non contradictoires.

### 6.2 Santé du Remote

```text
RemoteTransportHealth
- listenerState
- restartAttempt
- lastReadyAt
- lastFailureAt
- activeSessions
- authenticatedSessions
- lastSnapshotSequence
- sendFailures
- droppedSnapshots
```

Aucune métrique Remote ne doit bloquer le Live.

### 6.3 Santé audio

```text
AudioMonitorHealth
- generation
- engineRunning
- routeIdentifier
- sampleRate
- channelCount
- lastBufferAt
- incidentState
- configurationChangeCount
- restartCount
```

### 6.4 Rapport de validation matérielle

```text
HardwareValidationRecord
- backend
- softwareVersion
- macOSVersion
- MacModel
- controller
- mappingHash
- action
- result
- evidence
- duration
- testedAt
- notes
```

---

## 7. Stratégie de test recommandée

### Tests unitaires portables

- politiques de retry et backoff ;
- déduplication ;
- vieillissement des preuves ;
- transition de confiance ;
- invalidation après changement de version ;
- reprise de séquence Remote ;
- machine à états audio ;
- coalescence MIDI.

### Tests macOS automatisés

- création et disparition du port CoreMIDI ;
- restart du listener ;
- client WebSocket lent ;
- session fermée pendant un envoi ;
- notification de configuration audio ;
- permission Accessibilité retirée pendant la session ;
- application DJ simulée avec arbre AX changeant.

### Simulations déterministes

- 50 et 250 titres ;
- backend fermé au milieu du fondu ;
- commande Play envoyée mais non vérifiée ;
- snapshot dupliqué ;
- iPhone reconnecté avec ancienne séquence ;
- silence puis retour audio ;
- saturation puis route audio changée ;
- file MIDI surchargée ;
- transition en retard et frames abandonnées.

### Tests matériels

Ils restent obligatoires pour chaque backend. Un test automatisé ou un mock ne peut pas remplacer :

- le chargement réel ;
- le démarrage audio ;
- la synchronisation ;
- les volumes ;
- le crossfader ;
- la visibilité du contrôleur ;
- les changements de fenêtre et de version ;
- la perte du Wi-Fi ;
- la reprise manuelle ;
- la stabilité pendant deux heures.

---

## 8. Décisions d’architecture

### À conserver

- architecture multi-backend ;
- local-first ;
- preuve stricte ;
- Remote de haut niveau ;
- fallback manuel ;
- watchdog à états ;
- mapping versionné ;
- correctifs distants optionnels ;
- simulations déterministes.

### À éviter

- scraper un format propriétaire non documenté comme unique source de vérité ;
- considérer un élément AX visible comme une preuve de lecture ;
- envoyer des retries aveugles après une commande incertaine ;
- dépendre du téléphone pour maintenir le son ;
- injecter un modèle génératif dans la boucle Live ;
- publier des mappings universels sans validation par version et matériel ;
- copier du code GPL dans le dépôt sans décision de licence explicite ;
- ajouter une abstraction qui ne supprime aucun risque réel.

---

## 9. Sources principales

Consultées le 17 juillet 2026.

### Algoriddim

- Using Automix: https://help.algoriddim.com/user-manual/djay-pro-windows/mixing-basics/using-automix
- Automix settings: https://help.algoriddim.com/user-manual/djay-pro-mac/settings/automix
- Mapping a MIDI device: https://help.algoriddim.com/user-manual/djay-pro-mac/midi/mapping
- Multiple MIDI mappings: https://help.algoriddim.com/user-manual/djay-pro-mac/midi/multiple-mappings
- Sharing MIDI mappings: https://help.algoriddim.com/user-manual/djay-pro-mac/midi/sharing

### rekordbox

- Manuals and MIDI LEARN guide entry: https://rekordbox.com/en/download/
- rekordbox 7 FAQ: https://rekordbox.com/en/support/faq/rekordbox7/
- rekordbox 7 Hardware Unlock FAQ: https://rekordbox.com/en/support/faq/v7/

### Serato

- MIDI mapping with Serato DJ Pro: https://support.serato.com/hc/en-us/articles/209377487-MIDI-mapping-with-Serato-DJ-Pro
- MIDI Data Types: https://support.serato.com/hc/en-us/articles/225065768-MIDI-Data-Types
- MIDI Overview: https://support.serato.com/hc/en-us/articles/225064908-MIDI-Overview

### VirtualDJ

- Automix: https://virtualdj.com/manuals/virtualdj/interface/browser/sideview/automix.html
- Automix Editor: https://virtualdj.com/manuals/virtualdj/editors/automixeditor.html
- VirtualDJ Remote: https://virtualdj.com/manuals/virtualdj/vdjremote.html

### Apple

- Core MIDI: https://developer.apple.com/documentation/coremidi
- MIDIEventPacket: https://developer.apple.com/documentation/coremidi/midieventpacket
- MIDITimeStamp discussion: https://developer.apple.com/documentation/coremidi/midieventpacket/timestamp
- AXUIElement: https://developer.apple.com/documentation/applicationservices/axuielement
- AXUIElement header: https://developer.apple.com/documentation/applicationservices/axuielement_h
- AVAudioEngine configuration change: https://developer.apple.com/documentation/avfaudio/avaudioengineconfigurationchangenotification
- NWConnection states: https://developer.apple.com/documentation/network/nwconnection/state-swift.enum
- NWConnection state handler: https://developer.apple.com/documentation/network/nwconnection/stateupdatehandler
- NWConnection path updates: https://developer.apple.com/documentation/network/nwconnection/pathupdatehandler

### Projets ouverts

- Mixxx: https://github.com/mixxxdj/mixxx
- Mixxx hardware compatibility: https://github.com/mixxxdj/mixxx/wiki/Hardware-Compatibility
- Mixxx MIDI scripting: https://github.com/mixxxdj/mixxx/wiki/midi-scripting
- AudioKit: https://github.com/AudioKit/AudioKit
- python-rtmidi: https://github.com/SpotlightKid/python-rtmidi
- Automix GPLv2: https://github.com/walkywalker/automix

### Recherche

- Automatic DJ Transitions with Differentiable Audio Effects and Generative Adversarial Networks: https://arxiv.org/abs/2110.06525
- DJ Mix Transcription with Multi-Pass Non-Negative Matrix Factorization: https://arxiv.org/abs/2410.04198

---

## Conclusion

MixPilot ne gagnera pas sa fiabilité en ajoutant une transition de plus. Il la gagnera en transformant chaque dépendance externe en machine à états observable, testable et bornée.

Le benchmark valide la direction actuelle : backend explicite, preuve stricte, local-first et reprise manuelle. La prochaine étape doit donc être une stabilisation ciblée, en commençant par le redémarrage du listener Remote, les changements de configuration audio et la qualification structurée des preuves d’état.