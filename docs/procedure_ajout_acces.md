# Procédure — Ajouter un accès à l'entrepôt (cas d'usage)

_Entrepôt VenteRapide (PostgreSQL 16, port 5433). Principe directeur : **moindre privilège** —
on n'accorde que les droits strictement nécessaires au besoin._

## 1. Objectif
Créer un accès à l'entrepôt pour un nouveau besoin (ex. équipe reporting en lecture seule), de façon
tracée et testée.

## 2. Prérequis
- Être administrateur de la base (utilisateur système `postgres`) : la création de rôle n'est pas
  permise à l'utilisateur applicatif `dbt_user`.
- Avoir défini **le besoin** : quelles données, en lecture seule ou lecture/écriture, pour qui.

## 3. Étapes (exemple : rôle `reporting` en lecture seule)

```sql
-- 1) créer le compte avec un mot de passe
CREATE ROLE reporting WITH LOGIN PASSWORD '<mot_de_passe>';

-- 2) autoriser la connexion à la base et l'usage du schéma
GRANT CONNECT ON DATABASE datawarehouse_e6 TO reporting;
GRANT USAGE   ON SCHEMA public TO reporting;

-- 3) lecture seule sur les tables existantes
GRANT SELECT ON ALL TABLES IN SCHEMA public TO reporting;

-- 4) lecture seule AUTOMATIQUE sur les futures tables créées par dbt_user
ALTER DEFAULT PRIVILEGES FOR ROLE dbt_user IN SCHEMA public GRANT SELECT ON TABLES TO reporting;
```

Exécution (script fourni) :
```bash
sudo -u postgres psql -p 5433 -d datawarehouse_e6 -f scripts/create_reporting.sql
```

Le point clé de l'étape 4 : sans `ALTER DEFAULT PRIVILEGES`, chaque **nouveau** modèle dbt serait
invisible pour `reporting`. On l'attache **au rôle créateur des tables** (`dbt_user`).

## 4. Tester l'accès (obligatoire : positif ET négatif)

```bash
# POSITIF : la lecture fonctionne
PGPASSWORD='<mot_de_passe>' psql -h localhost -p 5433 -U reporting -d datawarehouse_e6 \
  -c "select count(*) from fact_commandes;"

# NÉGATIF : l'écriture est refusée (résultat attendu : permission denied)
PGPASSWORD='<mot_de_passe>' psql -h localhost -p 5433 -U reporting -d datawarehouse_e6 \
  -c "insert into dim_produit(produit_id) values (99999);"
```

Résultat validé (2026-09-10) : `SELECT` OK ; `INSERT`/`UPDATE`/`DELETE` → `permission denied`.
Le rôle n'a aucun privilège d'administration (`superuser=false, createdb=false, createrole=false`).

## 5. Révoquer un accès (fin de mission)
```sql
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM reporting;
REVOKE ALL ON SCHEMA public FROM reporting;
REVOKE CONNECT ON DATABASE datawarehouse_e6 FROM reporting;
DROP ROLE reporting;   -- après avoir vérifié qu'il ne possède aucun objet
```

## 6. Bonne pratique RGPD (aller plus loin)
Si un accès n'a pas besoin des colonnes personnelles (nom, email…), exposer une **vue** limitée aux
colonnes utiles plutôt que la table entière — voir `docs/rgpd_registre_et_purge.md`.
