#!/usr/bin/env bash
# Simula el conector REST POST de la tarea "Recibir postulaciones" del Proceso 1 (RSE):
# consume la respuesta del proveedor desde rse.postulaciones y la muestra.
set -euo pipefail
BASE="http://${RABBIT_HOST:-localhost}:${RABBIT_PORT:-15672}/api"
USER="${RABBIT_USER:-guest}"; PASS="${RABBIT_PASS:-guest}"

echo "Consumiendo de rse.postulaciones..."
curl -s -u "$USER:$PASS" -H "content-type: application/json" \
  -XPOST "$BASE/queues/%2f/rse.postulaciones/get" \
  -d '{"count":1,"ackmode":"ack_requeue_false","encoding":"auto"}' \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('  (cola vacia)') if not d else print('  payload:', d[0]['payload'])"
