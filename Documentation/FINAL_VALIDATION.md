# Validation finale guidée — MixPilot 0.3.0-rc.2

Cette campagne humaine n’est lancée qu’après une CI entièrement verte et la génération du DMG avec checksum valide.

## Statut avant campagne

Les éléments suivants restent obligatoirement classés :

- Serato, Spotify et mapping MIDI : `REQUIRES_SERATO_VALIDATION` ;
- routage audio, latence, MacBook Pro M1 et iPhone : `REQUIRES_DEVICE_VALIDATION` ;
- moteur, simulations et builds publics : `AUTOMATED_SUCCESS` ou `SIMULATED_SUCCESS` selon le cas.

## Préconditions

- MacBook Pro M1 sous macOS 14 ou supérieur, branché au secteur ;
- Serato DJ Pro installé et lancé ;
- Spotify Premium connecté dans Serato ;
- sortie audio réelle ou configuration équivalente ;
- au moins 30 minutes de musique locale de secours ;
- iPhone sous iOS 17 ou supérieur ;
- Mac et iPhone sur le même réseau local ;
- DMG et application iPhone issus du même protocole Remote v1.

## Phase A — Installation Mac et permissions

1. installer le DMG de la RC2 ;
2. lancer MixPilot depuis Applications ;
3. accorder Accessibilité, capture d’écran et audio lorsque demandé ;
4. relancer l’application après les changements de permissions ;
5. exporter un premier diagnostic.

Critère : aucune permission critique ne reste bloquée.

## Phase B — Serato et mapping MIDI

1. lancer Serato et connecter Spotify ;
2. afficher une playlist de test ;
3. sélectionner `MixPilot Virtual Controller` ;
4. mapper Play, Pause, Cue, Sync, Load, volumes, EQ, filtres, pitch, crossfader, effets et boucles ;
5. confirmer dans MixPilot chaque réaction réellement observée.

Critère : les actions critiques sont réellement confirmées. La présence d’un mapping dans un fichier ne suffit pas.

## Phase C — Préparation de playlist

1. importer une playlist locale ;
2. vérifier titres, artistes, ordre, BPM et durées ;
3. lancer l’analyse temporaire sur quelques morceaux ;
4. vérifier les marqueurs et les transitions ;
5. inspecter toutes les transitions sous le seuil de confiance ;
6. verrouiller le plan.

Répéter avec une playlist Spotify de dix titres dans Serato.

Critère : aucun mauvais titre, doublon ou décalage d’ordre.

## Phase D — Sept familles de transitions

Tester :

- Smooth Blend ;
- Bass Swap ;
- Rap Switch ;
- Shatta Drop ;
- Echo Exit ;
- Safe Fade ;
- Hard Cut contrôlé.

Vérifier le deck sortant, le deck entrant, les EQ, le crossfader, le niveau, la continuité sonore et l’arrêt du deck sortant.

Critère : dix transitions consécutives sans inversion de deck, blanc ou double chargement.

## Phase E — Watchdog et secours

1. activer la surveillance audio ;
2. provoquer un silence contrôlé ;
3. couper le routage audio ;
4. interrompre Internet ;
5. fermer Serato pendant que le secours local joue ;
6. vérifier fade-in, enchaînement des fichiers et retour au contrôle manuel.

Critère : aucun changement contradictoire et aucun blanc supérieur à une seconde après le déclenchement critique lorsque le secours est prêt.

## Phase F — Récupération

1. arrêter MixPilot pendant une session de test ;
2. relancer l’application ;
3. ouvrir le Centre de récupération ;
4. vérifier le rapprochement entre checkpoint, morceau et deck réels ;
5. confirmer qu’aucune reprise aveugle n’est exécutée ;
6. reprendre manuellement ou depuis un point sûr.

## Phase G — Endurance Mac

1. préparer un set d’au moins deux heures ;
2. lancer le préflight complet ;
3. laisser le Mac sans interaction ;
4. surveiller mémoire, CPU, veille, incidents et récupération ;
5. exporter le diagnostic final.

Critères : aucun crash, aucune mise en veille, toutes les transitions prévues terminées et aucun incident non récupéré.

## Phase H — Installation iPhone et appairage

1. installer l’application iPhone issue de la RC2 ;
2. activer explicitement le bridge sur le Mac ;
3. vérifier la découverte Bonjour `_mixpilot._tcp` ;
4. saisir le code à six chiffres ;
5. vérifier le stockage du jeton dans le Trousseau ;
6. appairer un second appareil ou réinstaller l’app pour vérifier le mode lecture seule.

Critère : un seul appareil principal ; les autres ne peuvent pas commander le Mac.

## Phase I — Réseau et commandes distantes

1. vérifier les snapshots et leur ordre ;
2. envoyer `takeManualControl` deux fois et vérifier l’idempotence ;
3. tester les commandes autorisées de la RC2 ;
4. vérifier les refus explicites des commandes verrouillées ;
5. couper puis rétablir le Wi-Fi ;
6. verrouiller puis déverrouiller l’iPhone ;
7. arrêter l’app iPhone ;
8. vérifier que le Live Mac ne change jamais du seul fait d’une perte réseau.

## Phase J — Diagnostics

Exporter les diagnostics Mac et iPhone. Vérifier qu’ils ne contiennent ni jeton, ni code d’appairage, ni mot de passe, ni audio protégé, ni donnée Spotify sensible.

## Décision

Une fonctionnalité non validée reste verrouillée et marquée `REQUIRES_SERATO_VALIDATION` ou `REQUIRES_DEVICE_VALIDATION`. Elle ne doit jamais être annoncée comme fiable pour masquer une limite de plateforme ou l’absence de matériel réel.
