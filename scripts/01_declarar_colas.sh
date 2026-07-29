#!/usr/bin/env bash
# Declara (idempotente) las dos colas del lab vía la Management HTTP API.
# Útil si NO usas docker-compose con definitions.json, o para re-crearlas a mano.
# Uso: ./01_declarar_colas.sh
set -euo pipefail
HOST="${RABBIT_HOST:-localhost}"
PORT="${RABBIT_PORT:-15672}"
USER="${RABBIT_USER:-guest}"
PASS="${RABBIT_PASS:-guest}"
BASE="http://${HOST}:${PORT}/api"

for q in rse.convocatorias rse.postulaciones; do
  echo "Declarando cola: $q"
  curl -s -u "$USER:$PASS" -H "content-type: application/json" \
    -XPUT "$BASE/queues/%2f/$q" \
    -d '{"durable":true,"auto_delete":false,"arguments":{}}'
  echo " -> OK"
done

echo "Colas actuales:"
curl -s -u "$USER:$PASS" "$BASE/queues/%2f" \
  | python3 -c "import sys,json;[print('  -',q['name'],'msgs=',q['messages']) for q in json.load(sys.stdin)]"
