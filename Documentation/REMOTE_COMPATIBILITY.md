# Compatibilité et correctifs à distance

MixPilot utilise GitHub pour le code et les artefacts contrôlés, puis Supabase pour distribuer des métadonnées de compatibilité strictement typées. Aucun script, binaire, code Swift, commande système ou message MIDI arbitraire n’est chargé depuis Supabase.

## Portée multi-backend

Les tables et le contexte client enregistrent toujours :

- le backend actif ;
- la version du logiciel DJ ;
- le contrôleur ou profil ;
- la version et l’empreinte du mapping ;
- les capacités et validations connues.

Le catalogue peut donc distinguer djay Pro, rekordbox et Serato DJ Pro sans valeur codée en dur.

## Limite actuelle

Le mécanisme générique de découverte et de ciblage existe pour les trois backends. En revanche, l’installateur automatique de correctif présent dans cette branche ne prépare actuellement qu’un preset rekordbox contrôlé.

Pour djay et Serato, MixPilot conserve le mapping local et affiche uniquement les instructions ou avertissements compatibles. Il ne prétend pas installer un format qui n’a pas été implémenté et validé.

## Flux d’un mapping publié

1. le correctif est développé dans une PR GitHub ;
2. les tests, simulations et contrôles de provenance doivent réussir ;
3. le profil est encodé de manière déterministe ;
4. les empreintes SHA-256 sont calculées ;
5. la publication précise backend, logiciel, version, contrôleur, build minimal, canal et rollout ;
6. MixPilot consulte uniquement les lignes publiées correspondant à son environnement ;
7. le client recalcule les empreintes et revalide localement le format ;
8. le mapping actuel est sauvegardé avant toute écriture ;
9. aucune modification en mémoire n’est appliquée pendant un Live ;
10. l’état découvert, préparé, refusé, installé ou restauré est enregistré sans donnée musicale.

## Modes

- `notify` : proposition locale, aucune préparation automatique ;
- `next_launch` : vérification et préparation hors Live pour le prochain lancement ;
- `required` : avertissement obligatoire, sans injection pendant le Live.

Un correctif requis ne donne jamais le droit de démarrer, arrêter ou modifier un Live à distance.

## Rollback

Le profil précédent est conservé localement. La restauration est exécutée hors Live et devient active au prochain lancement ou après l’étape manuelle exigée par le logiciel DJ.

Pour rekordbox, MixPilot peut également régénérer le CSV de restauration. Cette capacité n’est pas généralisée artificiellement à djay ou Serato.

## Règles de compatibilité

Les overrides peuvent uniquement décrire des décisions connues du client :

- capacités concernées ;
- validation supplémentaire requise ;
- avertissement utilisateur ;
- suspension du mode complet ;
- ciblage par backend, version, contrôleur et build.

Ils ne peuvent pas ajouter une nouvelle commande, modifier le moteur de transitions, écrire dans une base interne du logiciel DJ ou contourner le préflight.

## Garde-fous

- RLS sur les tables exposées ;
- publication impossible depuis le client macOS ;
- vues en lecture seule pour l’application ;
- empreintes SHA-256 et provenance GitHub ;
- sauvegarde, écriture atomique et relecture ;
- aucune installation pendant le Live ;
- rollout progressif ;
- aucune clé privilégiée dans l’application ;
- aucune donnée musicale, audio ou Accessibilité brute ;
- PR et CI avant publication ;
- validation matérielle toujours séparée de la simple installation.