# Intégration officielle djay Pro

## Positionnement

djay Pro est un backend officiel de premier niveau. Il n’est pas présenté comme un laboratoire ni comme une variante secondaire de Serato.

Deux modes produit sont prévus :

- **Automix supervisé** ;
- **MixPilot avancé**.

## Méthodes autorisées

L’intégration peut utiliser :

- détection du processus et du bundle ;
- détection de version ;
- contrôles Accessibilité réellement exposés ;
- observation de la fenêtre et de la file Automix ;
- profil MIDI importé par l’utilisateur ;
- CoreMIDI ;
- actions guidées dans l’interface officielle.

Elle ne doit pas :

- injecter du code ;
- modifier le paquet signé de djay ;
- écrire dans une base interne non documentée ;
- inventer une API djay ;
- envoyer des frappes arbitraires ;
- considérer la présence d’un bouton comme une commande validée.

## Détection

Le backend détecte :

- installation ;
- processus ;
- bundle identifier ;
- version ;
- état d’ouverture.

La détection d’Automix, de sa file et des contrôles accessibles doit être versionnée. Une empreinte d’interface inconnue invalide les actions en écriture.

## Automix supervisé

Objectif : laisser djay exécuter son Automix natif pendant que MixPilot :

- prépare l’ordre ;
- vérifie la file lorsque l’interface le permet ;
- affiche le morceau actuel et le suivant ;
- surveille l’audio ;
- alerte en cas d’écart ;
- accepte les intentions iPhone ;
- permet la reprise manuelle.

Ce mode ne peut être présenté comme prêt que si MixPilot peut confirmer suffisamment l’état courant et le déclenchement de transition.

## MixPilot avancé

Objectif : exécuter les transitions MixPilot avec les commandes MIDI validées.

Les commandes peuvent couvrir :

- Play et Pause ;
- Cue ;
- Sync ;
- Load ;
- volumes ;
- EQ ;
- filtre ;
- tempo ;
- crossfader ;
- boucles ;
- effets.

Chaque commande reste absente du plan Live tant que sa réaction réelle n’est pas confirmée avec la version et le profil actifs.

## Mapping

Le profil djay doit comporter :

- version ;
- format ;
- contrôleur ;
- version minimale de MixPilot ;
- versions djay testées ;
- empreinte du profil ;
- liste des commandes ;
- résultat de validation ;
- procédure de sauvegarde et de restauration.

L’installation automatique n’est pas revendiquée tant qu’une méthode officiellement supportée et réversible n’est pas confirmée.

## Parcours utilisateur

1. djay installé ;
2. djay détecté ;
3. version détectée ;
4. mode Automix supervisé ou MixPilot avancé choisi ;
5. permissions demandées uniquement si nécessaires ;
6. profil MIDI importé si le mode direct est choisi ;
7. commandes critiques testées ;
8. état des decks ou de la file confirmé ;
9. transition de test ;
10. contrôle manuel testé.

## Validation matérielle

Tester séparément :

- file Automix ;
- morceau actuel et suivant ;
- pause et reprise Automix ;
- déclenchement de transition ;
- changement de disposition ;
- perte d’Accessibilité ;
- profil MIDI ;
- commandes directes ;
- perte de processus ;
- reprise manuelle ;
- Remote iPhone ;
- endurance de trente minutes et deux heures.

## État honnête

Le backend logiciel et son contrat commun existent. Les capacités de contrôle et de lecture détaillée restent associées à leur statut de validation réel. Cette documentation ne constitue pas une validation d’une version djay particulière.
