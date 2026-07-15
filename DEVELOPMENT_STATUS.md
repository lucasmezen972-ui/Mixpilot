# Development Status

Dernière mise à jour : 2026-07-15

## État global

**Phase 0 — Initialisation du dépôt**

Le dépôt a été initialisé et la structure de gouvernance du développement est en cours de création.

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
- [ ] Registre des checkpoints humains
- [ ] Cahier des charges versionné dans le dépôt
- [ ] Structure Swift/Xcode
- [ ] Feasibility Lab
- [ ] Simulateur Serato
- [ ] CI macOS
- [ ] Production `.app`
- [ ] Production `.dmg`

## Prochaine étape automatique

1. Ajouter le cahier des charges technique versionné.
2. Ajouter les checkpoints humains.
3. Ouvrir une Pull Request vers `develop`.
4. Préparer l’initialisation du projet macOS.

## Risques ouverts

- Le dépôt est actuellement public.
- Aucun test réel Serato n’a encore été effectué.
- Aucun projet Xcode n’est encore présent.
- Aucun runner Mac privé n’est encore configuré.

## Statuts de validation

- `REAL` : validé sur matériel réel
- `SIMULATED` : validé uniquement dans le simulateur
- `REQUIRES_SERATO_VALIDATION` : implémenté mais non testé avec Serato réel
- `BLOCKED_BY_PLATFORM` : bloqué par une limite externe documentée
