# Parcours utilisateur MixPilot

## Navigation principale

L’application doit tenir dans quatre espaces.

### Préparer

- choisir le backend DJ ;
- connecter le logiciel ;
- importer ou lire une playlist ;
- analyser les morceaux ;
- organiser le set ;
- préparer les transitions ;
- ajouter la musique de secours ;
- tester une transition.

### Vérifier

- logiciel et version ;
- capacités disponibles ;
- mapping ;
- commandes critiques ;
- permissions ;
- audio ;
- alimentation ;
- Internet lorsque la bibliothèque en dépend ;
- connexion iPhone ;
- musique de secours ;
- rapport final avant Live.

### Live

- backend actif ;
- morceau actuel ;
- morceau suivant ;
- deck actif ;
- progression ;
- transition prévue ;
- capacités temporairement dégradées ;
- état audio ;
- état de l’iPhone ;
- alertes ;
- reprise manuelle.

### Avancé

- laboratoires Accessibilité ;
- diagnostics ;
- mappings et provenance ;
- services en ligne ;
- exports ;
- rapports techniques ;
- outils développeur.

## Parcours rapide

```text
Choisir le logiciel
→ Vérifier la connexion
→ Importer une playlist
→ Préparer le set
→ Tester une transition
→ Vérifier le système
→ Lancer le Live
```

## Principe de divulgation progressive

Le parcours normal ne demande pas de comprendre les protocoles, mappings ou services techniques.

Les détails apparaissent seulement lorsqu’ils sont nécessaires pour résoudre un problème ou lorsqu’Avancé est ouvert.

## Structure d’un message de problème

Chaque problème affiché doit présenter :

- le problème ;
- son impact ;
- une action principale ;
- éventuellement une alternative sûre.

## Choix du backend

Les cartes djay Pro, rekordbox et Serato DJ Pro doivent afficher les mêmes catégories :

- installé ou non ;
- version ;
- état de compatibilité ;
- mode recommandé ;
- principales capacités ;
- configuration manquante ;
- dernière validation ;
- Configurer ;
- Tester ;
- Utiliser.

Le changement reste possible hors Live et interdit pendant le Live.

## Préparation indépendante du backend

Le projet de set, l’analyse musicale, la courbe d’énergie et les transitions appartiennent à MixPilot.

Le backend actif intervient seulement pour :

- lire la bibliothèque ou la playlist ;
- traduire les commandes ;
- vérifier l’état ;
- signaler les capacités réellement disponibles.

Un projet peut être préparé sans backend actif. Le Live exige un backend sélectionné et validé.

## Sécurité

Le bouton Reprendre la main doit rester visible en Live.

Une perte des services en ligne ou de l’iPhone ne modifie jamais automatiquement le Live.

Un backend qui répond mal passe en mode dégradé ou en contrôle manuel. MixPilot ne compense pas par une rafale de commandes aveugles.
