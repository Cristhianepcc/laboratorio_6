#!/usr/bin/env bash
# Simula el conector REST POST del Proceso 2 al cerrar: publica la POSTULACION/respuesta
# del proveedor en rse.postulaciones (la respuesta que el Proceso 1 espera).
#
# En Bonita: conector REST POST en la serviceTask "Enviar postulacion":
#   URL : http://localhost:15672/api/exchanges/%2f/amq.default/publish
#   Body: routing_key = rse.postulaciones, payload = datos del proveedor
set -euo pipefail
BASE="http://${RABBIT_HOST:-localhost}:${RABBIT_PORT:-15672}/api"
USER="${RABBIT_USER:-guest}"; PASS="${RABBIT_PASS:-guest}"

PAYLOAD='{"codigoConvocatoria":"RSE-2026-001","proveedor":"EcoAndes SAC","propuesta":"Recojo y valorizacion de mermas organicas 3x semana","montoOfertado":12800.0,"certificacion":"ISO 14001","aceptada":true}'

echo "Publicando postulacion en rse.postulaciones..."
curl -s -u "$USER:$PASS" -H "content-type: application/json" \
  -XPOST "$BASE/exchanges/%2f/amq.default/publish" \
  -d "{\"routing_key\":\"rse.postulaciones\",\"payload\":$(python3 -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$PAYLOAD"),\"payload_encoding\":\"string\",\"properties\":{\"content_type\":\"application/json\",\"delivery_mode\":2}}"
echo
echo "Esperado: {\"routed\":true}"
