# Manual Checkpoints

Ce registre liste uniquement les actions qui ne peuvent pas être validées de manière fiable par les runners publics.

| ID | Phase | Action | Statut | Vérification prévue |
|---|---|---|---|---|
| H001 | Dépôt | Passer le dépôt en privé si nécessaire | SKIPPED_WITH_LIMITATION | Décision du propriétaire : dépôt public conservé |
| H002 | RC2 réelle | Installer et valider la RC2 sur MacBook Pro M1 avec Serato, audio et iPhone | NOT_REQUIRED_YET | Campagne unique définie dans `Documentation/FINAL_VALIDATION.md` |
| H003 | Serato | Connecter Spotify et valider chargement, decks et transitions | NOT_REQUIRED_YET | Probe strict, playlist locale puis Spotify |
| H004 | Permissions | Accorder Accessibilité, capture et dossiers | NOT_REQUIRED_YET | Préflight et Feasibility Lab |
| H005 | MIDI | Mapper et confirmer toutes les commandes dans Serato | NOT_REQUIRED_YET | Réaction réellement observée pour chaque action critique |
| H006 | Audio | Valider routage master, watchdog, latence et absence de blanc | NOT_REQUIRED_YET | Niveaux PCM, silence, secours et Safe Fade |
| H007 | Secours | Sélectionner au moins 30 minutes de musique locale | NOT_REQUIRED_YET | Formats, durée, sortie réelle et enchaînement |
| H008 | Réseau réel | Valider Bonjour, appairage, lecture seule et perte Wi-Fi | NOT_REQUIRED_YET | Mac et iPhone physiques sur le même réseau local |
| H009 | Endurance | Exécuter un set autonome de deux heures | NOT_REQUIRED_YET | Aucun crash, blanc, veille ou incident non récupéré |
| H010 | Distribution publique | Ajouter Developer ID et notarisation si distribution externe | NOT_REQUIRED_YET | `codesign`, `notarytool`, `stapler` et Gatekeeper |

## H001 — Visibilité du dépôt

**Statut : `SKIPPED_WITH_LIMITATION`**

Le propriétaire a décidé le 15 juillet 2026 de conserver le dépôt public.

Mesures obligatoires :

- aucun secret, jeton, certificat ou mot de passe dans le dépôt ;
- secrets de CI uniquement dans GitHub Secrets ;
- aucun fichier audio protégé ni donnée Spotify sensible ;
- diagnostics anonymisés ;
- jetons Remote stockés dans les Trousseaux ;
- fixtures de test utilisant uniquement de faux jetons explicitement identifiés.

## H002 — Campagne humaine finale RC2

**Statut actuel : `NOT_REQUIRED_YET`**

Cette action ne devient `WAITING_FOR_HUMAN` qu’après :

1. fusion de la branche d’intégration verte dans `develop` ;
2. création de `release/0.3.0-rc.2` ;
3. génération du DMG RC2 ;
4. validation réelle du checksum ;
5. ouverture de la PR RC2 vers `main`.

La campagne regroupera H003 à H009 afin de ne solliciter l’utilisateur qu’une seule fois.

## Résultats ne nécessitant plus d’action humaine

- `AUTOMATED_SUCCESS` : tests Swift Mac et bridge ;
- `SIMULATED_SUCCESS` : simulations 50 et 250 titres ;
- `AUTOMATED_SUCCESS` : application Mac et probe en Release ;
- `AUTOMATED_SUCCESS` : DMG de branche d’intégration et checksum ;
- `AUTOMATED_SUCCESS` : application iPhone compilée pour simulateur ;
- `AUTOMATED_SUCCESS` : contrats Remote v1 et ordre des snapshots.

Ces résultats ne doivent pas être requalifiés en `REAL_SUCCESS` Serato ou appareil réel.
