# Spotify Bridge — Rekordbox, Serato et djay

## Objectif

MixPilot utilise une bibliothèque Spotify centrale, indépendante du logiciel DJ sélectionné :

1. connexion au compte Spotify par OAuth Authorization Code avec PKCE ;
2. synchronisation des playlists privées, collaboratives et des Titres likés ;
3. préparation d’une playlist dans MixPilot à partir des métadonnées officielles ;
4. ouverture de Rekordbox, Serato ou djay ;
5. reconnaissance, via l’accessibilité macOS, de la rubrique Spotify, des playlists et des titres réellement visibles dans le logiciel DJ.

MixPilot ne tente pas de récupérer les jetons privés de Rekordbox, Serato ou djay. Il ne télécharge, ne déchiffre et ne copie aucun flux audio Spotify.

## Configuration Spotify Developer

Une application de bureau ne doit jamais embarquer de Client Secret. MixPilot utilise donc PKCE et demande uniquement le **Client ID**.

1. Ouvrir le tableau de bord Spotify for Developers.
2. Créer une application nommée `MixPilot`.
3. Ajouter exactement la Redirect URI suivante :

   `mixpilot-spotify://callback`

4. Copier le Client ID dans la fenêtre **Bibliothèque Spotify** de MixPilot.
5. Cliquer sur **Connecter Spotify**.

Le Client ID peut aussi être fourni à la build avec :

`MIXPILOT_SPOTIFY_CLIENT_ID=<client-id>`

Il est alors inscrit dans l’Info.plist du paquet macOS. L’utilisateur peut toujours enregistrer un autre Client ID localement.

## Autorisations demandées

- `playlist-read-private`
- `playlist-read-collaborative`
- `user-library-read`
- `user-read-private`

Les jetons OAuth sont conservés dans le Trousseau macOS avec une protection liée à l’appareil. Aucun Client Secret n’est utilisé ou enregistré.

## Parcours dans un logiciel DJ

1. Choisir Rekordbox, Serato ou djay dans MixPilot.
2. Ouvrir **Bibliothèque Spotify** avec `⇧⌘S`.
3. Sélectionner la playlist Spotify et cliquer sur **Préparer dans MixPilot**.
4. Cliquer sur **Ouvrir le logiciel DJ**.
5. Dans le logiciel DJ, afficher Spotify et la playlist correspondante.
6. Revenir dans MixPilot et cliquer sur **Vérifier Spotify à l’écran**.

La reconnaissance compare les noms de playlists, titres et artistes retournés par Spotify avec le texte et les lignes exposés par l’interface accessible du logiciel DJ.

## Données musicales et limites

Spotify ne fournit pas, par ce parcours, les BPM, grilles de tempo, formes d’onde ou fichiers audio nécessaires à une transition certifiée. MixPilot :

- conserve donc le BPM à `0` plutôt que d’en inventer un ;
- prépare un projet en mode prudent ;
- indique que le BPM et l’analyse doivent être confirmés depuis le logiciel DJ ou par l’analyse locale autorisée ;
- ne considère jamais la présence d’un titre dans l’API Spotify comme une preuve qu’il est chargé sur un deck.

La visibilité dépend de ce que chaque version de Rekordbox, Serato ou djay expose à l’accessibilité macOS. Une version peut afficher Spotify sans exposer toutes les lignes ; le résultat reste alors partiel et explicite.

## Mode développement Spotify

Les règles du mode développement Spotify peuvent limiter le nombre d’utilisateurs autorisés et exiger un compte Premium. Pour une diffusion plus large, l’application Spotify doit respecter le processus et les conditions de Spotify en vigueur.

## Références officielles

- Authorization Code with PKCE : https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow
- Redirect URIs : https://developer.spotify.com/documentation/web-api/concepts/redirect_uri
- Get Current User’s Playlists : https://developer.spotify.com/documentation/web-api/reference/get-a-list-of-current-users-playlists
- Get Playlist Items : https://developer.spotify.com/documentation/web-api/reference/get-playlists-tracks
