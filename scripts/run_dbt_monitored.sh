#!/usr/bin/env bash
# Monitoring des pipelines dbt (tâche 3.2, C16).
# Lance `dbt build` ; en cas d'ÉCHEC, envoie une alerte e-mail (msmtp) avec les
# dernières lignes du log. Prévu pour tourner à la main ou via cron.
set -uo pipefail   # pas de -e : on veut CAPTURER l'échec de dbt, pas planter le script avant l'alerte

PROJ="$(cd "$(dirname "$0")/.." && pwd)"
DBT="$PROJ/.venv/bin/dbt"
LOGDIR="$PROJ/logs/monitoring"
METRICS_DIR="$PROJ/supervision/metrics"   # mesures exposees a Prometheus (si la supervision est en place)

mkdir -p "$LOGDIR"
STAMP="$(date +%F_%H%M%S)"
RUN_LOG="$LOGDIR/dbt_build_$STAMP.log"

cd "$PROJ"
"$DBT" build > "$RUN_LOG" 2>&1
CODE=$?

# --- Mesures pour Prometheus (collecteur de fichiers du node-exporter) ---
if [ -d "$METRICS_DIR" ]; then
  SUCCESS=0; [ "$CODE" -eq 0 ] && SUCCESS=1
  TESTS=$("$PROJ/.venv/bin/python" -c "import json
try:
    r=json.load(open('$PROJ/target/run_results.json'))['results']
    t=[x for x in r if x.get('unique_id','').startswith('test.')]
    print(len(t), sum(1 for x in t if x.get('status')=='pass'))
except Exception:
    print(0,0)" 2>/dev/null || echo '0 0')
  cat > "$METRICS_DIR/dbt.prom" <<EOF
# HELP dbt_build_success 1 si le dernier dbt build a reussi, 0 sinon
# TYPE dbt_build_success gauge
dbt_build_success $SUCCESS
# HELP dbt_build_timestamp_seconds date du dernier dbt build (epoch)
# TYPE dbt_build_timestamp_seconds gauge
dbt_build_timestamp_seconds $(date +%s)
# HELP dbt_tests_total nombre total de tests dbt
# TYPE dbt_tests_total gauge
dbt_tests_total ${TESTS%% *}
# HELP dbt_tests_passed nombre de tests dbt au vert
# TYPE dbt_tests_passed gauge
dbt_tests_passed ${TESTS##* }
EOF
fi

if [ "$CODE" -ne 0 ]; then
  # --- ALERTE : le build a échoué ---
  # Adresse destinataire lue ici seulement, depuis une variable d'environnement.
  ALERT_TO="${ALERT_EMAIL:?Definir la variable ALERT_EMAIL (adresse destinataire des alertes)}"
  FROM="$ALERT_TO"
  {
    echo "Subject: [ALERTE dbt] Echec du build - entrepot VenteRapide"
    echo "From: $FROM"
    echo "To: $ALERT_TO"
    echo "Content-Type: text/plain; charset=UTF-8"
    echo
    echo "Le 'dbt build' a ÉCHOUÉ (code de sortie $CODE) le $(date '+%d/%m/%Y à %H:%M:%S')."
    echo "Projet : datawarehouse_e6"
    echo "Log complet : $RUN_LOG"
    echo
    echo "----- dernières lignes du log -----"
    tail -n 25 "$RUN_LOG"
  } | msmtp "$ALERT_TO"
  echo "[$(date '+%H:%M:%S')] ECHEC dbt (code $CODE) -> alerte e-mail envoyee a $ALERT_TO"
else
  echo "[$(date '+%H:%M:%S')] dbt build OK -> aucun incident."
fi

exit "$CODE"
