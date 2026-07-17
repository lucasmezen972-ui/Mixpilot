# Commandes de développement et de validation

Ce document est la référence pour exécuter la refonte multi-backend. Une commande terminée avec succès valide uniquement ce qu’elle mesure ; elle ne remplace jamais une campagne sur le logiciel DJ et le matériel réels.

## Contrôles statiques

```bash
bash Scripts/check_source_architecture.sh
bash Scripts/check_documentation_consistency.sh
```

## Tests Swift

```bash
swift test --parallel
```

Sur macOS, cette commande doit inclure les targets Core, Runtime, System et Remote déclarés dans `Package.swift`.

## Simulations

Les trois backends doivent être inclus explicitement :

```bash
swift run MixPilotSimulatorCLI --tracks 50 --backend all --inject-failures
swift run MixPilotSimulatorCLI --tracks 250 --backend all --inject-failures
```

Pour isoler une décision :

```bash
swift run MixPilotSimulatorCLI --tracks 50 --backend djay --inject-failures
swift run MixPilotSimulatorCLI --tracks 50 --backend rekordbox --inject-failures
swift run MixPilotSimulatorCLI --tracks 50 --backend serato --inject-failures
```

Le résultat reste `SIMULATED_SUCCESS`, jamais `REAL_SUCCESS`.

## Builds macOS

```bash
swift build -c release --product MixPilotAutopilot
swift build -c release --product MixPilotHardwareProbeCLI
```

## Probe matériel

Le backend est obligatoire. Le probe ne choisit jamais Serato automatiquement.

```bash
swift run MixPilotHardwareProbeCLI --backend djay
swift run MixPilotHardwareProbeCLI --backend rekordbox
swift run MixPilotHardwareProbeCLI --backend serato
```

Le mode strict est réservé à une machine préparée avec le logiciel concerné ouvert :

```bash
swift run MixPilotHardwareProbeCLI --backend djay --strict
swift run MixPilotHardwareProbeCLI --backend rekordbox --strict
swift run MixPilotHardwareProbeCLI --backend serato --strict
```

Un rapport réussi confirme uniquement les contrôles du probe. Il ne valide pas toutes les transitions, la lecture fiable des decks ou l’endurance.

## Application iPhone

```bash
cd Mobile/MixPilotRemote
xcodegen generate
xcodebuild \
  -project MixPilotRemote.xcodeproj \
  -scheme MixPilotRemote \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
swift test --parallel
```

## DMG de développement

```bash
./Scripts/build_release.sh
./Scripts/package_dmg.sh
shasum -a 256 -c build/MixPilot-Autopilot.dmg.sha256
```

Un DMG de développement n’est ni signé ni notarisé sauf preuve explicite du pipeline correspondant.

## Validation finale

Après une CI réellement exécutée et verte, suivre :

- `Documentation/FINAL_VALIDATION.md` ;
- `Documentation/MULTI_BACKEND_VALIDATION.md` ;
- le guide spécifique de djay, rekordbox ou Serato.

Chaque rapport doit enregistrer le commit MixPilot, macOS, le backend, sa version, le contrôleur, le mapping et les preuves observées.