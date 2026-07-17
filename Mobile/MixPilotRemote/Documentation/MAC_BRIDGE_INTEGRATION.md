# Intégration future du bridge macOS

L’application iPhone peut être développée et testée en mode démo sans modifier le moteur Mac. La connexion réelle demandera ensuite une couche d’adaptation volontairement mince.

## Principe d’intégration

Le bridge ne doit pas connaître CoreMIDI ni Serato. Il dépend uniquement d’une façade de commandes haut niveau fournie par l’application Mac.

```swift
@MainActor
protocol MixPilotRemoteControlling: AnyObject {
    func remoteSnapshot() -> RemoteSnapshot
    func pauseAutopilot(commandID: UUID) throws
    func resumeAutopilot(commandID: UUID) throws
    func skipTransition(commandID: UUID) throws
    func requestSafeFade(commandID: UUID) throws
    func takeManualControl(commandID: UUID) throws
}
```

Le futur serveur traduit les messages réseau en appels de cette façade. L’`AppModel` ou un adaptateur dédié reste responsable de toutes les validations métier.

## Fichiers à ajouter plus tard

La tranche Mac pourra rester séparée dans un target indépendant :

```text
Sources/MixPilotRemoteBridge/
├── RemoteBridgeServer.swift
├── RemotePairingStore.swift
├── RemoteCommandRouter.swift
├── RemoteSnapshotAdapter.swift
└── RemoteAuditLog.swift
```

Une seule ligne d’assemblage sera ensuite nécessaire dans le point d’entrée macOS pour démarrer ou arrêter le serveur. Cette intégration ne doit être faite qu’après stabilisation de la release candidate en cours.

## Ordre recommandé

1. Compiler et ouvrir l’application iPhone en mode démo.
2. Valider l’ergonomie des commandes et confirmations.
3. Finaliser la release candidate Mac et les essais Serato réels.
4. Créer le target `MixPilotRemoteBridge` depuis le dernier `develop` stable.
5. Implémenter un serveur local utilisant Network.framework et Bonjour.
6. Brancher uniquement la façade haut niveau à l’état réel de l’`AppModel`.
7. Tester d’abord en lecture seule.
8. Activer Pause/Reprendre.
9. Activer Safe Fade et Contrôle manuel après tests de panne.
10. Faire un test d’endurance avec coupures Wi-Fi et verrouillage de l’iPhone.

## Interdictions

- aucune commande MIDI reçue depuis le réseau ;
- aucune modification directe du deck depuis le serveur ;
- aucun démarrage automatique du Live depuis l’iPhone en v1 ;
- aucun jeton ou code d’appairage dans les logs ;
- aucune fusion dans `develop` tant que la PR de release candidate n’est pas stabilisée ;
- aucune dépendance du moteur Core vers le projet iOS.

## Gestion des conflits

La branche mobile ne modifie actuellement que `Mobile/MixPilotRemote`. Elle peut donc être rebasée sur `develop` avec un risque de conflit quasi nul. Le bridge Mac sera une seconde PR distincte afin que l’interface iPhone puisse continuer à évoluer sans bloquer les travaux Serato.
