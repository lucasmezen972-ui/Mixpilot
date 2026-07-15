# Development Status

Dernière mise à jour : 2026-07-15

## État global

**Phase 0 — Initialisation du dépôt**

Le dépôt a été initialisé. La gouvernance technique, le cahier des charges et le protocole des interventions humaines sont désormais versionnés sur la branche de fondation.

## Branches

- `main` : base stable initiale
- `develop` : intégration
- `feature/bootstrap-foundation` : fondations du projet

## Réalisé

- [x] Dépôt GitHub identifié
- [x] README initialisé
- [x] Branche `develop` créée
- [x] Branche de fondation créée
- [x] Règles Claude ajoutées
- [x] Registre des checkpoints humains
- [x] Cahier des charges versionné dans le dépôt
- [x] Pull Request de fondation ouverte
- [x] Visibilité publique confirmée comme décision volontaire
- [ ] Structure Swift/Xcode
- [ ] Feasibility Lab
- [ ] Simulateur Serato
- [ ] CI macOS
- [ ] Production `.app`
- [ ] Production `.dmg`

## Prochaine étape automatique

1. Ajouter un `.gitignore` adapté à Xcode, macOS et aux secrets.
2. Ajouter la politique de sécurité du dépôt public.
3. Préparer les workflows GitHub Actions de validation.
4. Initialiser le squelette Swift/Xcode depuis un environnement macOS disposant de Xcode.
5. Construire le Feasibility Lab et le simulateur.

## Risques ouverts

- Le dépôt est public par décision du propriétaire : aucun secret ni contenu audio protégé ne doit être commité.
- Aucun test réel Serato n’a encore été effectué.
- Aucun projet Xcode n’est encore présent.
- Aucun runner Mac privé n’est encore configuré.

## Statuts de validation

- `REAL` : validé sur matériel réel
- `SIMULATED` : validé uniquement dans le simulateur
- `REQUIRES_SERATO_VALIDATION` : implémenté mais non testé avec Serato réel
- `BLOCKED_BY_PLATFORM` : bloqué par une limite externe documentée