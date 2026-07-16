# Compatibilité et mappings à distance

MixPilot utilise GitHub pour le code et Supabase pour distribuer des décisions de compatibilité strictement typées. Aucun script, binaire ou code Swift arbitraire n'est chargé depuis Supabase.

## Flux d'un mapping

1. Un correctif est développé dans GitHub et validé par les tests et simulations.
2. Le profil `MIDIMappingProfile` est encodé de manière déterministe.
3. Son SHA-256 et celui du preset rekordbox recompilé sont enregistrés dans `mixpilot_mapping_releases`.
4. La publication peut cibler un canal, un contrôleur, une plage de versions rekordbox, un build minimal et un pourcentage d'installations.
5. MixPilot télécharge uniquement les lignes publiées correspondant à son environnement.
6. L'application recalcule les deux empreintes et recompile le CSV avec le générateur local.
7. Le profil actuel est sauvegardé avant toute écriture.
8. Le nouveau profil est enregistré pour le prochain lancement. Le contrôleur actif en mémoire n'est jamais remplacé pendant un Live.
9. Le CSV officiel est écrit atomiquement et doit être importé via MIDI IMPORT dans rekordbox.
10. L'état découvert, validé, installé, refusé ou restauré est enregistré dans `mixpilot_mapping_installations`.

## Modes de publication

- `notify` : affiche la proposition et attend une action locale.
- `next_launch` : valide et prépare automatiquement le mapping hors Live ; il devient actif au prochain lancement.
- `required` : affiche un correctif requis et empêche sa fermeture dans l'interface. Il n'est toutefois jamais injecté pendant le Live.

## Rollback

La dernière version locale est conservée dans Application Support. Le bouton Rollback restaure le profil précédent pour le prochain lancement et génère également un CSV rekordbox de restauration.

## Règles de compatibilité

`mixpilot_compatibility_overrides` permet de publier uniquement des données connues de l'application :

- actions concernées ;
- validations requises ;
- avertissements ;
- suspension du Live ;
- ciblage par version et contrôleur.

Ces règles ne contiennent pas de commandes système et ne peuvent pas modifier une base rekordbox.

## Garde-fous

- RLS sur toutes les tables ;
- aucune écriture de release depuis le client macOS ;
- clé Supabase publique uniquement dans l'application ;
- contrôles SHA-256 ;
- recompilation locale du preset ;
- détection des doublons MIDI ;
- écriture atomique et relecture ;
- sauvegarde avant installation ;
- aucun changement pendant le Live ;
- déploiement progressif ;
- PR, tests et CI avant publication d'un correctif.
