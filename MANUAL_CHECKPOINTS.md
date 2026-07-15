# Manual Checkpoints

Ce registre liste les actions qui ne peuvent pas être réalisées de manière fiable sans intervention humaine.

| ID | Phase | Action | Statut | Vérification prévue |
|---|---|---|---|---|
| H001 | Dépôt | Passer le dépôt GitHub en privé si le code ne doit pas être public | SKIPPED_WITH_LIMITATION | Décision du propriétaire : dépôt public conservé |
| H002 | Environnement | Installer Xcode et accepter sa licence sur le Mac de développement | NOT_REQUIRED_YET | `xcodebuild -version` et compilation minimale |
| H003 | Serato | Installer Serato DJ Pro, connecter Spotify et ouvrir une playlist de test | NOT_REQUIRED_YET | Détection du processus et de la fenêtre Serato |
| H004 | Permissions | Accorder Accessibilité et Capture d’écran/audio à MixPilot | NOT_REQUIRED_YET | Vérification des statuts macOS et test d’observation |
| H005 | MIDI | Effectuer le premier mapping MIDI dans Serato | NOT_REQUIRED_YET | Test Play/Sync/EQ/crossfader avec confirmation d’état |
| H006 | Audio | Choisir et valider le routage audio, avec BlackHole si nécessaire | NOT_REQUIRED_YET | Détection PCM, RMS et silence sans couper la sortie principale |
| H007 | Secours | Sélectionner au moins 30 minutes de musique locale | NOT_REQUIRED_YET | Validation formats, durée et lecture |
| H008 | CI réelle | Configurer un runner GitHub auto-hébergé sur un Mac avec Serato | NOT_REQUIRED_YET | Runner en ligne avec labels attendus |
| H009 | Distribution | Ajouter certificat Developer ID et secrets de notarisation Apple | NOT_REQUIRED_YET | `codesign`, notarisation et vérification Gatekeeper |

## H001 — Visibilité du dépôt

**Statut : `SKIPPED_WITH_LIMITATION`**

### Décision

Le propriétaire du projet a décidé le 15 juillet 2026 de conserver le dépôt GitHub public.

### Limitation acceptée

Le code source, l’architecture et la documentation non sensibles pourront être consultés publiquement.

### Mesures obligatoires

- Ne jamais committer de clé API, token, certificat, mot de passe ou secret.
- Stocker les secrets de CI uniquement dans GitHub Secrets.
- Ajouter et maintenir un fichier `.gitignore` strict.
- Anonymiser les diagnostics et journaux exportés.
- Ne jamais ajouter de fichiers audio protégés ou de données Spotify sensibles.
- Activer la détection de secrets dans la CI lorsque possible.

### Vérification

La visibilité publique est volontaire et ne bloque plus le développement.