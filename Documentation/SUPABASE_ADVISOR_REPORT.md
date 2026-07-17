# Rapport des advisors Supabase

Date de vérification : 17 juillet 2026  
Projet : `cqppkklfugbixpxwitab`

## Résumé

- Security Advisor : **aucune alerte**.
- Performance Advisor : **15 avis de niveau INFO**, tous de type `unused_index`.
- Tables concernées : **0 ligne** au moment de la vérification.
- Taille de chaque index signalé : **8 Ko**.
- Décision : **conserver les index jusqu’à l’apparition d’une charge réelle**.

Aucune migration destructive n’a été appliquée. Un index neuf sur une table vide ne peut pas accumuler de scans et ne doit pas être supprimé uniquement parce que le compteur `idx_scan` est encore à zéro.

## Sécurité

Le Security Advisor ne retourne aucun lint :

- aucune table publique sans RLS détectée ;
- aucune politique reposant sur des métadonnées utilisateur modifiables ;
- aucune vue `security_definer` exposée détectée ;
- aucune fonction à chemin de recherche mutable détectée ;
- aucune politique permissive critique détectée.

Les politiques examinées restent limitées au propriétaire avec `(select auth.uid()) = owner_id`. Les politiques `UPDATE` disposent de `USING` et `WITH CHECK`.

Référence : [Supabase Database Advisors](https://supabase.com/docs/guides/database/database-advisors)

## Avis performance

### Index liés au propriétaire et à la chronologie

Conservés pour les sélections protégées par RLS et les listes récentes :

- `mixpilot_devices_owner_last_seen_idx` ;
- `mixpilot_sessions_owner_started_idx` ;
- `mixpilot_events_owner_time_idx` ;
- `mixpilot_commands_owner_idx` ;
- `mixpilot_mapping_installations_owner_device_idx`.

### Index liés aux relations et au polling

Conservés pour les recherches par appareil, session et état de commande :

- `mixpilot_sessions_device_idx` ;
- `mixpilot_events_device_idx` ;
- `mixpilot_events_session_time_idx` ;
- `mixpilot_commands_device_status_idx` ;
- `mixpilot_mapping_installations_device_idx` ;
- `rekordbox_validation_device_idx`.

### Index fonctionnels

Conservés pour les parcours prévus :

- `mixpilot_releases_lookup_idx` : recherche de versions par canal, statut et build ;
- `mixpilot_events_expiry_idx` : purge des événements à expiration ;
- `mixpilot_devices_backend_version_idx` : diagnostics par backend et version ;
- `mixpilot_sessions_backend_started_idx` : sessions récentes par backend et version.

## Critère de réévaluation

Les index seront réévalués uniquement après une période d’utilisation représentative :

1. données réelles présentes dans les tables ;
2. statistiques PostgreSQL collectées après `ANALYZE` automatique ;
3. au moins plusieurs jours de requêtes applicatives ;
4. inspection conjointe de `pg_stat_user_indexes`, des requêtes lentes et de la taille des index ;
5. confirmation qu’un index n’est requis ni par une relation, ni par RLS, ni par une tâche de purge ou de polling.

Une future suppression devra être réalisée dans une migration dédiée, vérifiée sur un environnement de validation, puis suivie d’un nouveau passage des Security et Performance Advisors.

## Limites de cette validation

Cette vérification confirme l’état actuel du projet hébergé et des advisors Supabase. Elle ne remplace pas :

- l’application de toutes les migrations sur une base neuve ;
- les tests d’authentification et de RLS depuis le client macOS ;
- une mesure de performance avec des données réelles ;
- la validation matérielle des logiciels DJ.
