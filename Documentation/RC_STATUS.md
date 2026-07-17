# Statut de la refonte multi-backend

## État actuel

- branche : `feature/first-class-multi-backend` ;
- Pull Request : #29 vers `release/0.3.0-rc.2` ;
- état : ouverte, mergeable et brouillon ;
- aucune fusion vers `main` ;
- aucune publication automatique.

La RC `0.3.0-rc.2` est une base historique. Ses anciens résultats CI ne valident pas les changements de la PR #29.

## Migration réalisée

- djay Pro, rekordbox et Serato DJ Pro utilisent le contrat `DJBackend` ;
- aucun backend n’est choisi implicitement ;
- le runtime Live adapte les transitions aux capacités disponibles ;
- une capacité doit être réellement confirmée avant le Live ;
- sans lecture d’état fiable, aucune première commande d’Autopilote complet ne part ;
- les projets locaux mémorisent le backend choisi tout en relisant les anciens projets sans inventer Serato ;
- l’interface principale contient Préparer, Vérifier, Live et Avancé ;
- Remote v2 affiche le backend et le mode réel ;
- les services en ligne restent facultatifs et utilisent le backend sélectionné ;
- les diagnostics en ligne sont désactivés par défaut ;
- Supabase utilise RLS, des vues `security_invoker` et une rétention de trente jours ;
- les simulations et documents sont désormais multi-backend.

## État GitHub Actions

Les workflows macOS, iPhone et Linux échouent avant leur première étape : aucun checkout, aucune commande Swift, aucun log de compilation et aucun artefact.

Il s’agit d’un blocage GitHub Actions du dépôt. Ce comportement ne permet de déclarer ni succès ni échec du code actuel.

## Validation non acquise

Restent à exécuter sur le commit courant :

- tests Swift ;
- simulations 50 et 250 titres ;
- build macOS Release ;
- build iOS Simulator ;
- DMG et checksum ;
- tests matériels djay, rekordbox et Serato ;
- lecture réelle de l’état des decks ;
- routage audio, récupération et endurance ;
- appairage et perte Wi-Fi sur appareils physiques ;
- signature Developer ID et notarisation.

## Règle de sortie

La PR #29 reste brouillon jusqu’au retour d’une CI réellement exécutée et à la campagne décrite dans `Documentation/FINAL_VALIDATION.md`.

Une réussite avec un backend ne valide jamais automatiquement les deux autres. `REAL_SUCCESS` doit toujours être associé à la version du logiciel, au mapping, au matériel, au commit MixPilot et à la preuve observée.