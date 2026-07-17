# Validation multi-backend MixPilot

## Principe

Une validation appartient toujours à une configuration précise :

- version de MixPilot ;
- backend DJ ;
- version du logiciel ;
- contrôleur ;
- version et empreinte du mapping ;
- Mac ;
- routage audio ;
- application iPhone lorsque utilisée.

Une validation ne doit pas être réutilisée aveuglément après une mise à jour.

## Niveaux de preuve

### AUTOMATED_SUCCESS

Un test automatisé a confirmé un comportement logiciel déterministe, par exemple :

- décodage d’un format ;
- validation d’un CSV ;
- génération d’une empreinte ;
- fallback de transition ;
- idempotence ;
- migration d’un ancien projet.

### SIMULATED_SUCCESS

Le simulateur a terminé un scénario avec des pannes injectées. Il n’a contacté aucun logiciel DJ ou matériel réel.

### REQUIRES_BACKEND_VALIDATION

La fonction doit être testée avec le logiciel DJ cible.

### REQUIRES_DEVICE_VALIDATION

La fonction doit être testée avec le Mac, le contrôleur, l’audio ou l’iPhone cible.

### BLOCKED_BY_PLATFORM

La méthode envisagée n’est pas disponible ou suffisamment sûre.

### FAILED

L’échec a été observé. La capacité ne doit pas entrer dans un plan Live.

## Protocole commun

Pour chaque backend :

1. détecter l’installation ;
2. détecter le processus ;
3. détecter la version ;
4. détecter ou importer le mapping ;
5. vérifier la sauvegarde du mapping précédent ;
6. tester Play ;
7. tester Pause ;
8. tester Load ;
9. tester volume A ;
10. tester volume B ;
11. tester Sync ;
12. confirmer l’état des decks ou le mode supervisé ;
13. tester une transition simple ;
14. tester un fallback ;
15. tester la reprise manuelle ;
16. perdre le processus ;
17. vérifier le circuit breaker ;
18. relancer le logiciel ;
19. vérifier la récupération ;
20. tester le Remote iPhone ;
21. exécuter dix transitions ;
22. exécuter trente minutes ;
23. exécuter deux heures.

## Protocole djay

Ajouter :

- lecture de la file Automix ;
- morceau actuel et suivant ;
- pause et reprise Automix ;
- déclenchement de la prochaine transition ;
- perte du contrôle Accessibilité ;
- changement de disposition ;
- profil MIDI direct ;
- comparaison Automix supervisé / MixPilot avancé.

## Protocole rekordbox

Ajouter :

- import XML ;
- import JSON ;
- génération du CSV ;
- validation des 15 colonnes ;
- import dans la fenêtre MIDI ;
- Mode Performance ;
- navigation ;
- formule ou Hardware Unlock ;
- changement de version ;
- rollback du mapping.

## Protocole Serato

Ajouter :

- création du contrôleur virtuel ;
- entrée et sortie MIDI ;
- activation du périphérique ;
- installation XML ;
- relance contrôlée ;
- disposition de bibliothèque ;
- mapping manuel de secours ;
- rollback.

## Remote iPhone

Tester pour les trois backends :

- découverte Bonjour ;
- appairage ;
- appareil principal ;
- appareil secondaire en lecture seule ;
- ordre des snapshots ;
- commande dupliquée ;
- commande périmée ;
- perte Wi-Fi ;
- passage en arrière-plan ;
- reconnexion ;
- refus du Mac ;
- reprise manuelle.

La perte de l’iPhone ne doit jamais modifier le Live.

## Audio et secours

Tester :

- source audio correcte ;
- silence court ;
- silence critique ;
- saturation ;
- perte de source ;
- restauration de source ;
- lecture de la musique de secours ;
- arrêt du secours ;
- contrôle manuel pendant le secours.

## Rapport de validation

Chaque rapport contient :

- identifiants de versions ;
- matériel ;
- date ;
- étapes réussies ;
- étapes échouées ;
- éléments non testés ;
- incidents ;
- logs anonymisés ;
- statut final par capacité ;
- signature ou personne responsable lorsque nécessaire.

## Critère de sortie

Un backend peut être officiellement pris en charge tout en restant partiellement validé.

Le terme « prêt pour l’Autopilote complet » exige cependant :

- Load confirmé ;
- Play et Pause confirmés ;
- volumes confirmés ;
- lecture d’état ou Automix supervisé suffisamment fiable ;
- surveillance audio active ;
- fallback sûr ;
- reprise manuelle testée ;
- aucune commande critique en statut simulé ou inconnu.
