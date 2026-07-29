#!/usr/bin/env bash
# Simula lo que hace el conector REST POST de la tarea `tnotif` del Proceso 1 (RSE):
# publica una "convocatoria / requisitos" en la cola rse.convocatorias.
#
# En Bonita este mismo POST se configura en el conector REST POST de `tnotif`:
#   URL   : http://localhost:15672/api/exchanges/%2f/amq.default/publish
#   Auth  : Basic guest/guest
#   Header: content-type application/json
#   Body  : el JSON de abajo (con las variables de `iniciativa`)
set -euo pipefail
BASE="http://${RABBIT_HOST:-localhost}:${RABBIT_PORT:-15672}/api"
USER="${RABBIT_USER:-guest}"; PASS="${RABBIT_PASS:-guest}"

# payload de negocio (lo que en Bonita saldría de la variable `iniciativa`)
PAYLOAD='{"codigo":"RSE-2026-001","nombre":"Reciclaje de mermas en tiendas","tipo":"RECICLAJE","presupuestoAprobado":15000.0,"requisitos":"Proveedor con certificacion ambiental ISO 14001"}'

echo "Publicando convocatoria en rse.convocatorias..."
curl -s -u "$USER:$PASS" -H "content-type: application/json" \
  -XPOST "$BASE/exchanges/%2f/amq.default/publish" \
  -d "{\"routing_key\":\"rse.convocatorias\",\"payload\":$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$PAYLOAD"),\"payload_encoding\":\"string\",\"properties\":{\"content_type\":\"application/json\",\"delivery_mode\":2}}"
echo
echo "Esperado: {\"routed\":true}"
