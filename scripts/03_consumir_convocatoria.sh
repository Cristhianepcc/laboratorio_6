#!/usr/bin/env bash
# Simula lo que hace el conector REST POST del INICIO del Proceso 2 (Comunidad/Proveedores):
# consume un mensaje de rse.convocatorias.
#
# En Bonita: conector REST POST en la tarea "Recibir convocatoria":
#   URL : http://localhost:15672/api/queues/%2f/rse.convocatorias/get
#   Body: {"count":1,"ackmode":"ack_requeue_false","encoding":"auto"}
# El campo .payload de la respuesta trae el JSON de negocio (parsear con Groovy).
set -euo pipefail
BASE="http://${RABBIT_HOST:-localhost}:${RABBIT_PORT:-15672}/api"
USER="${RABBIT_USER:-guest}"; PASS="${RABBIT_PASS:-guest}"

echo "Consumiendo de rse.convocatorias..."
curl -s -u "$USER:$PASS" -H "content-type: application/json" \
  -XPOST "$BASE/queues/%2f/rse.convocatorias/get" \
  -d '{"count":1,"ackmode":"ack_requeue_false","encoding":"auto"}' \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('  (cola vacia)') if not d else print('  payload:', d[0]['payload'])"
