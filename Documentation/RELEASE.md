# Publication de MixPilot Autopilot

## Types de build

### Build de développement

- compilation Release ;
- signature ad hoc ;
- DMG installable manuellement ;
- non notarisé ;
- destiné aux tests internes.

### Release candidate signée

- certificat `Developer ID Application` ;
- Hardened Runtime ;
- signature profonde du bundle ;
- notarisation Apple ;
- ticket staplé au DMG ;
- validation Gatekeeper.

## Secrets GitHub

Pour signer :

- `APPLE_CERTIFICATE_P12_BASE64`
- `APPLE_CERTIFICATE_PASSWORD`
- `APPLE_SIGNING_IDENTITY`

Pour notariser :

- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`

Les secrets ne doivent jamais apparaître dans le dépôt ou les logs.

## Workflow

Le workflow `.github/workflows/release.yml` peut être lancé manuellement ou par un tag `v*`.

Il exécute :

1. tests unitaires ;
2. simulation longue et matrice de pannes ;
3. import optionnel du certificat ;
4. build Release ;
5. vérification de signature ;
6. création du DMG ;
7. notarisation optionnelle ;
8. validation du checksum ;
9. manifest de release ;
10. artifact ou GitHub Release.

## Release candidate

Utiliser un numéro comme :

```text
0.9.0-rc.1
```

Lancer manuellement le workflow avec cette valeur. Aucun tag public n'est nécessaire pour un essai interne.

## Version finale

Après validation réelle complète :

```bash
git tag -a v1.0.0 -m "MixPilot Autopilot 1.0.0"
git push origin v1.0.0
```

Le tag déclenche la publication GitHub avec DMG, checksum, manifest et notes générées.

## Vérifications locales

```bash
codesign --verify --deep --strict --verbose=2 "MixPilot Autopilot.app"
spctl --assess --type execute --verbose=2 "MixPilot Autopilot.app"
shasum -a 256 -c MixPilot-Autopilot.dmg.sha256
xcrun stapler validate MixPilot-Autopilot.dmg
```

## Interdictions

- ne jamais déclarer une notarisation réussie sans réponse Apple valide ;
- ne jamais publier un DMG dont les tests ont échoué ;
- ne jamais intégrer de musique dans le bundle ;
- ne jamais inscrire des identifiants Spotify ou Serato dans le manifest ;
- ne jamais marquer une validation simulée comme réelle.
