#!/usr/bin/env bash
# Monitoring des pipelines dbt (tâche 3.2, C16).
# Lance `dbt build` ; en cas d'ÉCHEC, envoie une alerte e-mail (msmtp) avec les
# dernières lignes du log. Prévu pour tourner à la main ou via cron.
set -uo pipefail   # pas de -e : on veut CAPTURER l'échec de dbt, pas planter le script avant l'alerte

PROJ="$(cd "$(dirname "$0")/.." && pwd)"
DBT="$PROJ/.venv/bin/dbt"
LOGDIR="$PROJ/logs/monitoring"
# Destinataire de l'alerte lu depuis une variable d'environnement, aucune adresse en clair dans le script.
# À définir avant usage, par exemple : export ALERT_EMAIL="vous@exemple.fr"
ALERT_TO="${ALERT_EMAIL:?Definir la variable ALERT_EMAIL (adresse destinataire des alertes dbt)}"
FROM="$ALERT_TO"

mkdir -p "$LOGDIR"
STAMP="$(date +%F_%H%M%S)"
RUN_LOG="$LOGDIR/dbt_build_$STAMP.log"

cd "$PROJ"
"$DBT" build > "$RUN_LOG" 2>&1
CODE=$?

if [ "$CODE" -ne 0 ]; then
  # --- ALERTE : le build a échoué ---
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
