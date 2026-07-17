# Services en ligne et diagnostics MixPilot

Les services en ligne sont facultatifs. GitHub conserve le code, les migrations, les Pull Requests, les artefacts de release et la provenance des mappings. Le projet Supabase dédié `cqppkklfugbixpxwitab` fournit PostgreSQL, l’authentification et les états en ligne autorisés.

Une indisponibilité de ces services ne doit jamais :

- arrêter la musique ;
- interrompre une transition ;
- empêcher le contrôle manuel ;
- invalider une configuration locale déjà vérifiée ;
- bloquer un Live préparé.

## Pourquoi GitHub n’est pas la base de données Live

Git est un système de versionnement, pas une base transactionnelle. Écrire des sessions et diagnostics sous forme de commits créerait des conflits, exposerait les données opérationnelles et rendrait les heartbeats peu fiables.

## Données principales

- `mixpilot_devices` : installation, backend actif, version et dernier heartbeat ;
- `mixpilot_sessions` : sessions application et Live ;
- `mixpilot_events` : diagnostics techniques filtrés et dédupliqués ;
- `rekordbox_validation_reports` : certificats historiques rekordbox conservés pendant la généralisation ;
- `mixpilot_commands` : demandes administratives courtes et allowlistées ;
- `mixpilot_mapping_releases` : mappings publiés par logiciel, contrôleur et version ;
- `mixpilot_compatibility_overrides` : correctifs ou blocages de compatibilité publiés ;
- `mixpilot_device_health` : vue `security_invoker` propriétaire ;
- `mixpilot_latest_mapping_releases` : vue `security_invoker` des mappings publiés.

Les sessions peuvent enregistrer :

- `dj_backend` ;
- `dj_software_version` ;
- contrôleur ;
- version et SHA-256 du mapping ;
- instantané des capacités ;
- état de validation ;
- mode Live ;
- consentement aux diagnostics.

## Connexion

L’application peut utiliser une identité anonyme persistante sans collecter d’adresse e-mail. RLS isole les lignes par `auth.uid()`.

L’application :

- maintient un heartbeat technique ;
- vérifie les mises à jour et correctifs publiés ;
- conserve localement les événements autorisés en cas de coupure ;
- reprend l’envoi après reconnexion ;
- continue entièrement en local lorsque Supabase est indisponible.

## Consentement

Les diagnostics en ligne sont **désactivés par défaut**.

L’utilisateur peut les activer ou les désactiver. La préférence est enregistrée localement et transmise dans les lignes appareil/session afin de distinguer une installation active d’une installation consentante.

Les mises à jour peuvent rester disponibles lorsque les diagnostics sont désactivés.

## Données interdites

Le client ne doit pas transmettre par défaut :

- titres, artistes, albums ou playlists ;
- chemins locaux complets ;
- audio brut ;
- URL ou flux Spotify protégés ;
- contenu brut de l’arbre Accessibilité ;
- code d’appairage ;
- token Remote ;
- mot de passe, clé secrète ou header d’autorisation.

Les payloads autorisés contiennent seulement des états techniques comme :

- version et build ;
- backend sélectionné ;
- catégorie de commande ;
- résultat ;
- statut de validation ;
- type d’erreur nettoyé ;
- état général du runtime.

## Rétention

Les événements possèdent `expires_at`, fixé par défaut à trente jours. Une fonction privée permet la purge des événements expirés.

Cette fonction :

- vit dans le schéma privé `mixpilot_private` ;
- n’est pas exécutable par `anon` ou `authenticated` ;
- est réservée à `service_role`.

Une stratégie planifiée d’appel doit être configurée côté infrastructure de production avant une distribution publique à grande échelle.

## Sécurité

- seule la clé publiable est embarquée dans l’application ;
- aucune clé `service_role` n’existe dans le dépôt ou le client ;
- toutes les tables exposées utilisent RLS ;
- les appareils, sessions, événements et validations sont propriétaires ;
- les mappings et correctifs sont lisibles uniquement lorsqu’ils sont publiés ;
- les vues publiques utilisent `security_invoker` ;
- `anon` n’a aucun privilège sur les vues applicatives ;
- `authenticated` possède seulement `SELECT` sur ces vues ;
- le client ne peut pas insérer une commande administrative ;
- aucune commande distante ne peut injecter du Swift, du shell ou du MIDI arbitraire ;
- aucun Live ne peut être démarré à distance ;
- aucun mapping n’est appliqué pendant le Live.

Les advisors Supabase ne signalent actuellement aucun problème de sécurité. Les avis de performance restants concernent uniquement des index encore peu utilisés sur un projet neuf ; ils sont conservés pour les requêtes prévues.

## Mappings distants

Le modèle est générique :

- `software = djay | rekordbox | serato` ;
- version du mapping ;
- versions minimale et maximale du logiciel ;
- contrôleur ;
- format ;
- profil ;
- empreintes ;
- provenance ;
- statut ;
- rollout ;
- validations.

Cependant, MixPilot ne publie actuellement que les formats réellement implémentés et validés. Un CSV rekordbox n’est jamais présenté comme un mapping djay ou Serato.

## Flux de mise à jour

1. Un événement technique autorisé est enregistré.
2. Une anomalie peut être regroupée sans données musicales.
3. Le code et les tests sont corrigés dans une branche GitHub.
4. Rien n’est fusionné ou publié automatiquement.
5. Une release contient version, build, URL HTTPS, SHA-256, notes et rollout.
6. L’application propose la mise à jour ; elle ne remplace pas silencieusement un binaire non vérifié.

## État du déploiement

- schéma multi-backend appliqué ;
- RLS vérifié ;
- vues `security_invoker` vérifiées ;
- privilèges des vues durcis ;
- rétention de trente jours appliquée ;
- migrations conservées sous `supabase/migrations` ;
- services en ligne exclus du moteur Live.
