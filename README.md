# mobile-app-frontend
Frontend development of a mobile application using Flutter and Dart

## Configuration Supabase

Les données de l'application sont synchronisées avec Supabase : comptes
(Supabase Auth), profils, trajets, lieux, planning, réclamations et
messagerie. SQLite reste un cache hors-ligne local.

1. Ouvrir le projet Supabase puis **SQL Editor**.
2. Exécuter le script [`supabase/schema.sql`](./supabase/schema.sql).
3. Vérifier que le bucket public `unidrive-uploads` existe dans **Storage**.
4. Relancer l'application après l'exécution du script.

Le script crée les tables, les relations, le bucket d'images/audio et les
politiques nécessaires à l'application utilisant la clé publishable.

Après exécution, les anciennes données qui existaient uniquement dans SQLite
ne sont pas automatiquement importées : elles doivent être recréées ou
importées depuis un outil d'administration Supabase.
