# Bridge Mac pour MixPilot Remote

## État

Le bridge est développé dans un module séparé `MixPilotRemoteBridge` et reste désactivé par défaut.

Il ne démarre que lorsque l’utilisateur choisit **MixPilot → Activer la télécommande iPhone**. Sa désactivation ferme immédiatement le listener et toutes les connexions.

## Réseau

- découverte Bonjour : `_mixpilot._tcp` ;
- WebSocket local ;
- sous-protocole : `mixpilot-remote-v1` ;
- messages JSON versionnés ;
- aucune ouverture vers Internet ;
- aucun MIDI brut dans le protocole.

## Appairage

- code aléatoire à six chiffres ;
- validité de deux minutes ;
- jeton aléatoire de 256 bits ;
- jeton conservé dans le Trousseau macOS ;
- premier iPhone appairé déclaré contrôleur principal ;
- autres appareils en lecture seule.

## Protections

- commandes de plus de dix secondes refusées ;
- identifiants de commandes dédupliqués ;
- commande refusée si le Mac n’est pas dans un état compatible ;
- aucune modification automatique du Live lors d’une perte réseau ;
- le Mac reste la seule source de vérité ;
- bridge inactif par défaut.

## Commandes v1

### Active

- `takeManualControl` : annule l’autopilote et rend immédiatement le contrôle au Mac.

### Présentes dans le protocole mais volontairement verrouillées

- `pauseAutopilot` ;
- `resumeAutopilot` ;
- `skipTransition` ;
- `safeFade`.

Ces commandes sont refusées avec une explication tant que leur comportement réel n’est pas validé avec Serato, le checkpoint et le routage audio. Elles ne sont jamais simulées comme si elles avaient réussi.

## Validation avant utilisation

1. Compiler et lancer MixPilot sur le Mac.
2. Activer la télécommande depuis le menu MixPilot.
3. Vérifier que l’iPhone découvre le Mac.
4. Saisir le code affiché.
5. Vérifier les snapshots en lecture seule.
6. Tester `takeManualControl` uniquement sur un set de test.
7. Couper le Wi-Fi et confirmer que le Live Mac continue sans changement.

La télécommande ne doit pas être utilisée en prestation avant validation de ces étapes sur le Mac réel.
