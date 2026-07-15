# Publication de MixPilot Autopilot

Ce document décrit uniquement les capacités réellement présentes dans le dépôt.

## Niveaux de validation

- `AUTOMATED_SUCCESS` : tests ou compilation exécutés en CI sans matériel Serato réel ;
- `SIMULATED_SUCCESS` : scénario validé par le simulateur ;
- `REAL_SUCCESS` : test observé sur le Mac et le périphérique réels ;
- `REQUIRES_SERATO_VALIDATION` : dépend de Serato DJ Pro et de son interface réelle ;
- `REQUIRES_DEVICE_VALIDATION` : dépend du routage audio, du Mac ou de l’iPhone réel ;
- `BLOCKED_BY_PLATFORM` : impossible de garantir proprement avec les APIs disponibles.

## Build interne

Le workflow CI produit :

- une compilation Swift Release ;
- `MixPilot Autopilot.app` signé ad hoc ;
- `MixPilot-Autopilot.dmg` ;
- son checksum SHA-256 ;
- les rapports de tests et de simulation.

Ce build est installable pour les essais internes, mais il n’est pas présenté comme notarisé si les secrets Apple sont absents.

## Build Developer ID et notarisation

Secrets GitHub requis pour la signature :

- `APPLE_CERTIFICATE_P12_BASE64` ;
- `APPLE_CERTIFICATE_PASSWORD` ;
- `APPLE_SIGNING_IDENTITY`.

Secrets requis pour la notarisation :

- `APPLE_ID` ;
- `APPLE_TEAM_ID` ;
- `APPLE_APP_SPECIFIC_PASSWORD`.

Les secrets ne doivent jamais être inscrits dans le dépôt, les rapports ou les logs.

## Workflow de release

`.github/workflows/release.yml` exécute :

1. `swift test --parallel` ;
2. simulation de 50 titres avec incidents ;
3. simulation de 250 titres avec incidents ;
4. compilation de `MixPilotHardwareProbeCLI` ;
5. import optionnel du certificat Developer ID ;
6. construction de l’application ;
7. vérification de la signature ;
8. création du DMG ;
9. notarisation optionnelle ;
10. validation du checksum ;
11. génération d’un manifest de release ;
12. publication des artifacts ou d’une GitHub Release.

## Release candidate 0.3.0-rc.2

La RC2 sera créée uniquement après fusion de la branche d’intégration entièrement verte dans `develop`.

La branche attendue est :

```text
release/0.3.0-rc.2
```

Le workflow est lancé avec :

```text
version = 0.3.0-rc.2
```

La PR vers `main` ne doit pas être fusionnée avant :

- `AUTOMATED_SUCCESS` des tests Swift ;
- `AUTOMATED_SUCCESS` des simulations 50 et 250 titres ;
- `AUTOMATED_SUCCESS` des builds Mac, probe et iPhone ;
- génération réelle du DMG ;
- validation réelle du checksum ;
- cohérence des documents de statut.

## Vérifications du livrable

```bash
codesign --verify --deep --strict --verbose=2 "MixPilot Autopilot.app"
shasum -a 256 -c MixPilot-Autopilot.dmg.sha256
```

Pour un build notarisé :

```bash
spctl --assess --type execute --verbose=2 "MixPilot Autopilot.app"
xcrun stapler validate MixPilot-Autopilot.dmg
```

## Interdictions

- ne jamais annoncer une notarisation sans réponse Apple valide ;
- ne jamais annoncer un DMG validé avant sa génération et le contrôle du checksum ;
- ne jamais intégrer de musique ou de flux Spotify dans le bundle ;
- ne jamais placer d’identifiant Spotify ou Serato dans le manifest ;
- ne jamais transformer un résultat simulé en `REAL_SUCCESS`.
