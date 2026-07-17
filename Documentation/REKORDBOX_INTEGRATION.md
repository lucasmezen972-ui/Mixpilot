# Intégration officielle rekordbox

## Positionnement

rekordbox est un backend officiel de premier niveau, orienté Mode Performance et installations professionnelles.

Son support officiel ne signifie pas que toutes les formules, versions et configurations matérielles exposent les mêmes fonctions MIDI.

## Méthodes autorisées

L’intégration utilise selon la fonction :

- détection du processus et de la version ;
- import XML documenté ;
- import JSON adaptatif validé ;
- fenêtre MIDI officielle ;
- CSV de mapping officiellement importable ;
- CoreMIDI ;
- observation Accessibilité autorisée ;
- étapes utilisateur guidées.

MixPilot ne modifie pas la base interne privée de rekordbox et n’injecte aucun code dans son processus.

## Bibliothèque

Le backend conserve :

- import XML ;
- import JSON tolérant les variantes validées ;
- lecture des playlists importées ;
- validation des lignes avant création du projet MixPilot ;
- avertissements explicites pour les données incomplètes.

L’import de bibliothèque est distinct de la lecture en temps réel de l’état des decks.

## Mapping MIDI

Le CSV généré est traité comme un artefact de production.

Il comporte ou référence :

- logiciel `rekordbox` ;
- version du mapping ;
- contrôleur ;
- format CSV ;
- validation à 15 colonnes ;
- version minimale de MixPilot ;
- versions rekordbox compatibles ;
- manifeste ;
- commit GitHub immuable ;
- empreinte du manifeste ;
- empreinte du profil ;
- empreinte du preset généré ;
- statut de publication ;
- rollout ;
- résultat de CI ;
- procédure de rollback.

La génération et la validation structurelle du CSV ne prouvent pas que rekordbox ou le contrôleur réel ont réagi.

## Publication

Statuts autorisés :

- draft ;
- published ;
- paused ;
- withdrawn.

Une publication stable exige :

- provenance complète ;
- empreintes cohérentes ;
- format validé ;
- version cible documentée ;
- commandes critiques testées ;
- possibilité de rollback ;
- absence de revendication matérielle issue uniquement de la CI.

## Parcours utilisateur

1. rekordbox installé ;
2. version détectée ;
3. Mode Performance confirmé ;
4. formule ou Hardware Unlock compatible confirmé lorsque nécessaire ;
5. contrôleur virtuel visible ;
6. CSV généré et vérifié ;
7. import dans la fenêtre MIDI officielle ;
8. Play testé ;
9. Load testé ;
10. volumes A et B testés ;
11. Sync testé ;
12. navigation testée si utilisée ;
13. transition simple testée ;
14. reprise manuelle testée.

## Capacités directes

Le backend expose uniquement les commandes présentes et validées dans le registre :

- Play et Pause ;
- Cue ;
- Sync ;
- Load ;
- navigation ;
- volumes ;
- EQ ;
- tempo ;
- crossfader ;
- boucles ;
- effets confirmés.

Une commande non validée est retirée de la matrice ou marquée indisponible pour le Live.

## Correctifs distants

Les correctifs rekordbox peuvent être découverts en ligne, mais :

- ils ne sont jamais appliqués pendant le Live ;
- ils sont validés localement avant préparation ;
- l’ancien mapping est sauvegardé ;
- l’import final reste visible et confirmé par l’utilisateur ;
- une panne réseau conserve la configuration locale actuelle.

## Validation matérielle

Tester :

- import XML et JSON ;
- génération et import CSV ;
- Mode Performance ;
- chargement des decks ;
- navigation ;
- changement de version ;
- formule ou Hardware Unlock ;
- contrôleur virtuel ;
- récupération après perte de processus ;
- Remote iPhone ;
- dix transitions ;
- trente minutes ;
- deux heures.

## État honnête

Les imports, validateurs et mécanismes de provenance disposent de tests automatisés. La réaction réelle de rekordbox et du matériel reste `REQUIRES_DEVICE_VALIDATION` tant que le protocole cible n’est pas exécuté.
