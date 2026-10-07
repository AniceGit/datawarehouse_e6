#!/usr/bin/env bash
# Sauvegarde de l'entrepôt VenteRapide (tâche 3.3, C16).
# Usage : backup.sh full | partial
# Le mot de passe est lu depuis ~/.pgpass (aucun secret dans ce script ni dans le cron).
set -euo pipefail

MODE="${1:-full}"
DB="datawarehouse_e6"
HOST="localhost"
PORT="5433"
USER="dbt_user"
ROOT="$(cd "$(dirname "$0")/.." && pwd)/backups"
STAMP="$(date +%Y-%m-%d_%H%M)"

case "$MODE" in
  full)
    DIR="$ROOT/full"; mkdir -p "$DIR"
    OUT="$DIR/dw_full_${STAMP}.dump"
    pg_dump -h "$HOST" -p "$PORT" -U "$USER" -Fc -f "$OUT" "$DB"
    find "$DIR" -name 'dw_full_*.dump' -mtime +14 -delete   # rétention 14 jours
    ;;
  partial)
    DIR="$ROOT/partial"; mkdir -p "$DIR"
    OUT="$DIR/dw_facts_${STAMP}.dump"
    pg_dump -h "$HOST" -p "$PORT" -U "$USER" -Fc \
      -t public.fact_commandes -t public.fact_visites -t public.fact_retours \
      -f "$OUT" "$DB"
    find "$DIR" -name 'dw_facts_*.dump' -mtime +3 -delete    # rétention 3 jours
    ;;
  *)
    echo "Usage: $0 full|partial" >&2; exit 1 ;;
esac

echo "OK backup $MODE -> $OUT ($(du -h "$OUT" | cut -f1))"

# --- Mesure pour Prometheus (collecteur de fichiers du node-exporter) ---
METRICS_DIR="$(dirname "$ROOT")/supervision/metrics"
if [ -d "$METRICS_DIR" ]; then
  SIZE=$(stat -c%s "$OUT" 2>/dev/null || echo 0)
  cat > "$METRICS_DIR/backup_${MODE}.prom" <<EOF
# HELP backup_${MODE}_last_success_timestamp_seconds date de la derniere sauvegarde ${MODE} reussie (epoch)
# TYPE backup_${MODE}_last_success_timestamp_seconds gauge
backup_${MODE}_last_success_timestamp_seconds $(date +%s)
# HELP backup_${MODE}_last_size_bytes taille de la derniere sauvegarde ${MODE}
# TYPE backup_${MODE}_last_size_bytes gauge
backup_${MODE}_last_size_bytes $SIZE
EOF
fi
