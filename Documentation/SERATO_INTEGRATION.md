# Intégration officielle Serato DJ Pro

## Positionnement

Serato DJ Pro reste un backend officiel de premier niveau. Il ne définit plus les modèles, commandes ou erreurs du cœur MixPilot.

## Méthodes autorisées

L’intégration peut utiliser :

- détection du processus et de la version ;
- CoreMIDI ;
- contrôleur virtuel MixPilot ;
- profil XML officiellement chargé par Serato ;
- observation Accessibilité autorisée ;
- sauvegarde et restauration des mappings ;
- étapes utilisateur guidées ;
- relance contrôlée lorsque l’utilisateur l’autorise.

Elle ne doit pas :

- injecter du code ;
- modifier le paquet signé ;
- écrire dans une base privée non documentée ;
- envoyer des frappes arbitraires ;
- annoncer une commande réussie uniquement parce que le XML existe.

## Parcours de configuration

Le parcours officiel vérifie :

1. Serato installé ;
2. Serato détecté ;
3. version détectée ;
4. contrôleur virtuel MixPilot créé ;
5. entrée MIDI visible ;
6. sortie MIDI visible ;
7. périphérique activé dans Serato ;
8. mapping installé ;
9. mapping chargé ;
10. Play testé ;
11. Pause testée ;
12. Load testé ;
13. volume A testé ;
14. volume B testé ;
15. Sync testé ;
16. contrôle manuel testé.

Chaque étape fournit :

- un statut ;
- une explication humaine ;
- une action corrective ;
- un bouton de nouveau test ;
- un diagnostic avancé facultatif.

## Mapping

Le profil Serato reste :

- versionné ;
- sauvegardé avant remplacement ;
- écrit de façon atomique ;
- associé au contrôleur virtuel ;
- restaurable ;
- testé commande par commande.

Les anciens profils Serato peuvent être décodés pendant la migration vers `DJControlAction`, car les valeurs brutes des commandes sont conservées.

## Observation

L’observation Accessibilité peut servir à :

- confirmer que Serato est lancé ;
- lire les lignes visibles de la bibliothèque ;
- rechercher le morceau attendu dans les textes accessibles ;
- détecter un changement d’interface ou une permission absente.

Elle ne constitue pas automatiquement une lecture fiable de l’état complet des decks.

## Mode dégradé

Lorsqu’une commande manque :

- MixPilot l’indique précisément ;
- le plan de transition retire la capacité ;
- une variante sûre est choisie lorsque possible ;
- les fonctions encore validées restent disponibles ;
- l’Autopilote complet est bloqué si Load, Play ou les volumes ne sont pas confirmés ;
- le contrôle manuel reste prioritaire.

## Validation matérielle

Tester :

- création du contrôleur virtuel ;
- visibilité MIDI ;
- activation du périphérique ;
- installation XML ;
- sauvegarde et rollback ;
- relance ;
- réaction réelle de chaque commande critique ;
- disposition de bibliothèque ;
- perte d’Accessibilité ;
- perte du processus ;
- mapping manuel de secours ;
- Remote iPhone ;
- dix transitions ;
- trente minutes ;
- deux heures.

## État honnête

Les mécanismes de fichier, de mapping, de rollback et de détection peuvent être validés automatiquement. La réaction de Serato et du contrôleur réel reste distincte et doit être confirmée sur la configuration cible.
