# MixPilot Remote pour iPhone

Cette application iOS est développée dans un espace entièrement isolé du moteur macOS actuel.

## Objectif

Permettre de surveiller et contrôler MixPilot depuis un iPhone lorsque Serato et le moteur Autopilot tournent sur le Mac :

- voir le titre en cours et le prochain titre ;
- suivre l’état du set et de la transition ;
- mettre l’autopilote en pause ou le reprendre ;
- demander un Safe Fade ;
- passer la prochaine transition ;
- reprendre immédiatement le contrôle manuel ;
- recevoir les alertes importantes.

## Isolation

Cette branche ne modifie aucun fichier du moteur MixPilot existant. Le dossier `Mobile/MixPilotRemote` forme un projet Xcode indépendant. La connexion au Mac reposera sur un petit bridge conforme au protocole documenté dans `Documentation/REMOTE_PROTOCOL_V1.md`.

Le Mac reste la source de vérité et le seul composant autorisé à envoyer des commandes MIDI à Serato. L’iPhone n’envoie que des intentions haut niveau, validées par les protections du Mac.

## Générer le projet Xcode

Le projet utilise XcodeGen afin d’éviter de commiter un fichier `.xcodeproj` volumineux et conflictuel.

```bash
brew install xcodegen
cd Mobile/MixPilotRemote
xcodegen generate
open MixPilotRemote.xcodeproj
```

Sélectionner ensuite une équipe de signature dans Xcode et lancer l’application sur un iPhone sous iOS 17 ou supérieur.

## Mode démo

Le bouton **Essayer le mode démo** permet de tester l’interface sans Mac ni Serato. La découverte réelle attend un service Bonjour `_mixpilot._tcp` exposé par le futur bridge macOS.

## Sécurité prévue

- découverte uniquement sur le réseau local ;
- appairage initial par code à six chiffres affiché sur le Mac ;
- jeton conservé dans le Trousseau iOS ;
- identifiant unique par commande pour empêcher les doubles exécutions ;
- confirmations obligatoires pour Safe Fade et contrôle manuel ;
- déconnexion automatique visible, sans prétendre que le Mac est encore contrôlé.
