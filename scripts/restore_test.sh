#!/usr/bin/env bash
# Test de restauration (tâche 3.3, C16) : restaure le dernier backup complet dans une base
# JETABLE, vérifie quelques comptes de lignes, puis supprime la base de test.
# Prérequis : dbt_user doit avoir le droit CREATEDB (ALTER ROLE dbt_user CREATEDB;).
set -euo pipefail

HOST="localhost"; PORT="5433"; USER="dbt_user"
TESTDB="datawarehouse_e6_restore_test"
ROOT="$(cd "$(dirname "$0")/.." && pwd)/backups"

LAST="$(ls -t "$ROOT"/full/dw_full_*.dump | head -1)"
echo "Dernier backup complet : $LAST"

dropdb   -h "$HOST" -p "$PORT" -U "$USER" --if-exists "$TESTDB"
createdb -h "$HOST" -p "$PORT" -U "$USER" "$TESTDB"
# --no-owner / --no-privileges : on restaure les données sans rejouer les
# propriétaires ni les GRANT (dbt_user n'est pas superadmin). Sans effet sur les données.
pg_restore -h "$HOST" -p "$PORT" -U "$USER" --no-owner --no-privileges -d "$TESTDB" "$LAST"

echo "Vérification du contenu restauré :"
psql -h "$HOST" -p "$PORT" -U "$USER" -d "$TESTDB" -c "
select 'fact_commandes' as table, count(*) from fact_commandes
union all select 'fact_retours', count(*) from fact_retours
union all select 'dim_client',   count(*) from dim_client
union all select 'scd_client',   count(*) from scd_client;"

dropdb -h "$HOST" -p "$PORT" -U "$USER" "$TESTDB"
echo "Base de test supprimée. Restauration validée."
