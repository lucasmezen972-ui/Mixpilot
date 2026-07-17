# Publication de MixPilot

## Statuts

- `AUTOMATED_SUCCESS` : test ou build réellement exécuté sur le commit publié ;
- `SIMULATED_SUCCESS` : scénario logiciel sans matériel DJ réel ;
- `REAL_SUCCESS` : résultat observé sur une configuration précisément enregistrée ;
- `REQUIRES_BACKEND_VALIDATION` : comportement du logiciel DJ encore à confirmer ;
- `REQUIRES_DEVICE_VALIDATION` : matériel, audio ou réseau local encore à confirmer ;
- `BLOCKED_BY_PLATFORM` : capacité non garantie avec les interfaces disponibles.

Une ancienne réussite RC2, une simulation ou un mapping présent sur disque ne valide pas la refonte actuelle.

## Livrables obligatoires

Ils doivent provenir du même commit :

- tests Swift et Remote ;
- simulations 50 et 250 titres avec les trois backends ;
- build macOS Release ;
- build du probe matériel ;
- build iOS Simulator ;
- application `.app` ;
- DMG ;
- checksum SHA-256 ;
- manifest et rapports de validation.

## Conditions de publication

1. la CI doit avoir réellement exécuté toutes ses étapes ;
2. les tests et builds obligatoires doivent être verts ;
3. les simulations doivent rester identifiées comme simulations ;
4. le DMG et son checksum doivent correspondre au commit ;
5. la cohérence documentaire doit être vérifiée ;
6. aucune sélection implicite de backend ne doit subsister ;
7. les diagnostics doivent rester facultatifs et anonymisés ;
8. chaque capacité annoncée doit être couverte par la campagne matérielle correspondante.

## Mappings

Chaque mapping publié doit préciser : backend, version du logiciel, contrôleur, version du mapping, empreinte SHA-256, commit GitHub, preuves CI, validation matérielle et procédure de rollback.

Un mapping importable n’est pas automatiquement un mapping stable.

## Mises à jour dans l’application

MixPilot consulte uniquement un catalogue publié et affiche qu’une mise à jour est disponible. L’application peut ouvrir la page ou le téléchargement prévu, mais elle n’exécute aucun code distant arbitraire et n’installe rien silencieusement.

## Situation actuelle

La PR #29 reste brouillon. Les workflows échouent avant checkout et ne produisent aucun log Swift ni artefact. Aucune release ne peut être créée dans cet état.

## Vérifications

```bash
codesign --verify --deep --strict --verbose=2 "MixPilot.app"
shasum -a 256 -c MixPilot.dmg.sha256
```

Pour un build notarisé :

```bash
spctl --assess --type execute --verbose=2 "MixPilot.app"
xcrun stapler validate MixPilot.dmg
```

## Interdictions

- ne pas annoncer une CI verte sans étapes exécutées ;
- ne pas annoncer un DMG ou une notarisation sans preuve ;
- ne pas publier de données musicales, audio, texte Accessibilité ou secrets ;
- ne pas annoncer une capacité Live sans validation du backend, de sa version et de son mapping ;
- ne jamais transformer `SIMULATED_SUCCESS` en `REAL_SUCCESS`.