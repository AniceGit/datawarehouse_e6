-- Création d'un accès en LECTURE SEULE : rôle "reporting" (tâche 3.5, C16).
-- La création de rôle est une tâche d'administrateur → à lancer en tant que postgres :
--   sudo -u postgres psql -p 5433 -d datawarehouse_e6 -f scripts/create_reporting.sql
--
-- Note pédagogique : le mot de passe est en clair ici pour le TP. En production, il
-- serait injecté par un gestionnaire de secrets, jamais écrit dans un fichier versionné.

-- 1) Créer le rôle (idempotent : (re)fixe le mot de passe si le rôle existe déjà)
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'reporting') THEN
    CREATE ROLE reporting WITH LOGIN PASSWORD 'reporting_password';
  ELSE
    ALTER ROLE reporting WITH LOGIN PASSWORD 'reporting_password';
  END IF;
END $$;

-- 2) Autoriser la connexion à la base et l'usage du schéma
GRANT CONNECT ON DATABASE datawarehouse_e6 TO reporting;
GRANT USAGE   ON SCHEMA public TO reporting;

-- 3) Lecture seule sur toutes les tables EXISTANTES
GRANT SELECT ON ALL TABLES IN SCHEMA public TO reporting;

-- 4) Lecture seule AUTOMATIQUE sur les FUTURES tables créées par dbt_user
--    (sans ça, chaque nouveau modèle dbt serait invisible pour reporting)
ALTER DEFAULT PRIVILEGES FOR ROLE dbt_user IN SCHEMA public
  GRANT SELECT ON TABLES TO reporting;

-- reporting n'a QUE SELECT : aucun INSERT / UPDATE / DELETE ne lui est accordé.
