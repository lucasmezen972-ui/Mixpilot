# MixPilot Autopilot 0.3.0-rc.1

## Statut

**Release candidate gelée pour validation matérielle finale.**

Cette version contient tout le développement réalisable sans exécuter Serato DJ Pro et Spotify sur le Mac cible. Les validations automatisées doivent rester vertes avant toute installation réelle.

## Fonctionnalités incluses

- application macOS native SwiftUI ;
- onboarding guidé ;
- port MIDI virtuel CoreMIDI ;
- profil de mapping versionné et persistant ;
- import de la playlist visible dans Serato ;
- préparation automatique des titres et cue markers ;
- analyse audio locale temporaire ;
- génération de sept familles de transitions ;
- comparaison de variantes et inspecteur détaillé ;
- exécution MIDI beat-par-beat ;
- préchargement anticipé et alternance des decks ;
- surveillance audio silence, source et saturation ;
- surveillance Internet, secteur et batterie ;
- protection contre la veille ;
- bibliothèque locale de secours ;
- préflight bloquant ;
- reprise manuelle immédiate ;
- checkpoints Live ;
- Centre de récupération ;
- diagnostics anonymisés ;
- matrice de treize scénarios de panne ;
- stress-test des automations sur cinquante titres ;
- création automatisée de l'application et du DMG ;
- signature et notarisation Apple optionnelles ;
- probe matériel et workflow de validation Serato sur Mac privé.

## Validations automatisées requises

- tests unitaires Swift ;
- simulation de cinquante titres ;
- quarante-neuf transitions ;
- matrice complète de pannes ;
- vérification des valeurs d'automation ;
- compilation Release de l'application ;
- compilation du probe matériel ;
- création du DMG ;
- contrôle du checksum.

## Validations réelles reportées à la fin

- visibilité du port `MixPilot Virtual Controller` dans Serato ;
- fonctionnement du mapping MIDI réel ;
- lecture fiable des lignes de playlist ;
- confirmation du titre sur chaque deck ;
- chargement automatique d'un titre Spotify ;
- routage du master audio vers le watchdog ;
- latence réelle des transitions ;
- déclenchement du secours sur silence réel ;
- endurance de deux heures sur MacBook Pro M1.

## Limites connues

- MixPilot ne télécharge ni ne stocke les morceaux Spotify ;
- les morceaux Spotify restent dépendants d'Internet et de Serato ;
- les Stems Spotify ne font pas partie du périmètre ;
- l'intégration de bibliothèque dépend des informations exposées par l'interface Serato ;
- les données manquantes restent signalées avec un niveau de confiance inférieur ;
- aucune reprise après crash n'envoie de commande sans observation et confirmation suffisantes ;
- la version ne doit pas devenir `1.0` avant validation du protocole `FINAL_VALIDATION.md`.

## Politique de gel

À partir de cette branche, seuls sont acceptés :

- correctifs de compilation ;
- correctifs de tests ;
- correctifs de sécurité ;
- correctifs nécessaires aux validations réelles ;
- corrections documentaires sans changement fonctionnel risqué.

Aucune nouvelle fonctionnalité non indispensable ne doit être ajoutée avant la validation finale.
