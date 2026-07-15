# Manual Checkpoints

Ce registre liste uniquement les actions qui ne peuvent pas être validées de manière fiable par les runners publics.

| ID | Phase | Action | Statut | Vérification prévue |
|---|---|---|---|---|
| H001 | Dépôt | Passer le dépôt en privé si nécessaire | SKIPPED_WITH_LIMITATION | Décision du propriétaire : dépôt public conservé |
| H002 | RC2 réelle | Installer et valider la RC2 sur MacBook Pro M1 avec Serato, audio et iPhone | WAITING_FOR_HUMAN | Campagne unique définie dans `Documentation/FINAL_VALIDATION.md` |
| H003 | Serato | Connecter Spotify et valider chargement, decks et transitions | WAITING_FOR_HUMAN | Probe strict, playlist locale puis Spotify |
| H004 | Permissions | Accorder Accessibilité, capture et dossiers | WAITING_FOR_HUMAN | Préflight et Feasibility Lab |
| H005 | MIDI | Mapper et confirmer toutes les commandes dans Serato | WAITING_FOR_HUMAN | Réaction réellement observée pour chaque action critique |
| H006 | Audio | Valider routage master, watchdog, latence et absence de blanc | WAITING_FOR_HUMAN | Niveaux PCM, silence, secours et Safe Fade |
| H007 | Secours | Sélectionner au moins 30 minutes de musique locale | WAITING_FOR_HUMAN | Formats, durée, sortie réelle et enchaînement |
| H008 | Réseau réel | Valider Bonjour, appairage, lecture seule et perte Wi-Fi | WAITING_FOR_HUMAN | Mac et iPhone physiques sur le même réseau local |
| H009 | Endurance | Exécuter un set autonome de deux heures | WAITING_FOR_HUMAN | Aucun crash, blanc, veille ou incident non récupéré |
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

**Statut actuel : `WAITING_FOR_HUMAN`**

Les conditions automatiques sont remplies :

1. `develop` consolidé via la PR #14 ;
2. branche `release/0.3.0-rc.2` créée ;
3. PR #17 ouverte vers `main` ;
4. macOS CI verte : run `29459910562` ;
5. iPhone Remote CI verte : run `29459910656` ;
6. workflow de release vert : run `29459907907` ;
7. artifact `MixPilot-Autopilot-0.3.0-rc.2` généré ;
8. checksum validé : `cab6e3a3252a9e138edccacd52c35abcb7d66bd361c7fcfbcc3ac756d363e100` ;
9. correctif checksum backporté dans `develop` via la PR #18, fusion `67237855deb3da8e7543ed6e9b562957dce139b2`.

La campagne regroupe H003 à H009 afin de solliciter l’utilisateur une seule fois.

## Résultats ne nécessitant plus d’action humaine

- `AUTOMATED_SUCCESS` : tests Swift Mac et bridge ;
- `SIMULATED_SUCCESS` : simulations 50 et 250 titres ;
- `AUTOMATED_SUCCESS` : application Mac et probe en Release ;
- `AUTOMATED_SUCCESS` : DMG RC2, manifest et checksum ;
- `AUTOMATED_SUCCESS` : application iPhone compilée pour simulateur ;
- `AUTOMATED_SUCCESS` : contrats Remote v1 et ordre des snapshots.

Ces résultats ne doivent pas être requalifiés en `REAL_SUCCESS` Serato ou appareil réel.
