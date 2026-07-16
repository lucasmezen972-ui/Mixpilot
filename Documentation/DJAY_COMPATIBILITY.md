# Compatibilité djay

## Objectif

Conserver le moteur MixPilot existant et ajouter djay comme deuxième logiciel DJ sélectionnable, sans retirer Serato et sans inventer d’API djay ou Spotify.

## Premier lot réalisé

- sélection persistante entre Serato DJ Pro et djay Pro ;
- détection du processus sélectionné ;
- observation Accessibilité et lecture des lignes visibles dans le logiciel choisi ;
- préflight adapté au backend ;
- MIDI et mapping optionnels pour djay Automix ;
- batterie et musique locale de secours non bloquantes ;
- fenêtre de sélection du logiciel DJ ;
- fenêtre de préparation rapide d’un set visible ;
- tests automatisés dédiés ;
- build Release et DMG validés.

## Deuxième lot — observabilité Automix

Le deuxième lot ajoute un laboratoire djay strictement en lecture seule :

- capture structurée de l’arbre Accessibilité de la fenêtre djay ;
- collecte du rôle, sous-rôle, identifiant, titre, valeur, description, aide, états et actions exposées ;
- conservation d’un contexte limité provenant des éléments parents ;
- recherche de candidats pour la file Automix, ses lignes et ses contrôles ;
- score de confiance explicable avec les raisons de chaque détection ;
- export JSON local pour analyser l’interface réelle sur le Mac cible ;
- limite de capture pour éviter une exploration sans borne ;
- aucun clic, aucune frappe, aucune action MIDI et aucune modification de la lecture ;
- tests synthétiques de l’analyseur Automix.

Le laboratoire est accessible depuis **Fenêtre → Inspecter la compatibilité djay** ou avec `⇧⌘J`.

## Parcours rapide actuel

1. choisir djay comme logiciel DJ ;
2. lancer djay et afficher la vue Automix ;
3. ouvrir `Inspecter la compatibilité djay` ;
4. lancer l’inspection en lecture seule ;
5. vérifier les candidats Automix et leur score ;
6. exporter le JSON local si l’arbre doit être analysé plus précisément ;
7. afficher ensuite une playlist et utiliser `Préparer un set rapidement` pour générer le plan MixPilot.

## Validation et confidentialité

- la compilation et les tests peuvent être automatisés ;
- l’identification exacte des éléments Automix reste `REQUIRES_DEVICE_VALIDATION` ;
- le JSON peut contenir les titres et artistes visibles dans djay ;
- le fichier reste local et ne doit pas être publié sans relecture ;
- aucun secret, jeton Spotify ou contenu audio n’est capturé volontairement.

## Limites actuelles

- MixPilot ne remplit pas encore automatiquement la file Automix de djay ;
- MixPilot ne déclenche pas encore automatiquement la lecture dans djay ;
- la lecture exacte des lignes Spotify visibles doit être validée sur le Mac réel ;
- les rôles et libellés Accessibilité peuvent varier selon la version, la langue et la disposition de djay ;
- aucun contrôle MIDI détaillé djay n’est revendiqué ;
- un score élevé n’autorise pas automatiquement l’exécution d’une action.

## Statuts

- sélection et persistance : `AUTOMATED_SUCCESS` ;
- détection djay : `AUTOMATED_SUCCESS` ;
- préflight backend-aware : `AUTOMATED_SUCCESS` ;
- analyseur de candidats Automix sur données synthétiques : `AUTOMATED_SUCCESS` ;
- capture générique via Accessibilité : `REQUIRES_DEVICE_VALIDATION` ;
- identification de la file Automix réelle : `REQUIRES_DEVICE_VALIDATION` ;
- remplissage de la file Automix : `REQUIRES_DEVICE_VALIDATION` ;
- démarrage automatique du set : `REQUIRES_DEVICE_VALIDATION`.

## Étape suivante après validation sur le Mac

Une fois un export réel obtenu :

1. figer des sélecteurs fondés sur les rôles, identifiants et libellés réellement exposés ;
2. ajouter un mode `dry-run` qui montre précisément les actions envisagées ;
3. tester l’ajout d’un seul titre local dans une file de test ;
4. confirmer l’ordre et l’absence de doublon ;
5. seulement ensuite autoriser l’ajout ordonné d’un set complet ;
6. conserver un arrêt immédiat et une reprise manuelle prioritaires.
