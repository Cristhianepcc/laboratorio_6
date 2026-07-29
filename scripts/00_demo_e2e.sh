#!/usr/bin/env bash
# Demo end-to-end SIN Bonita: reproduce con curl exactamente el intercambio que harán
# los conectores REST de los dos procesos, para validar RabbitMQ y los payloads.
#
#   Proceso 1 (RSE)  --publish-->  rse.convocatorias  --get-->  Proceso 2 (Proveedor)
#   Proceso 1 (RSE)  <--get--      rse.postulaciones  <-publish- Proceso 2 (Proveedor)
set -euo pipefail
cd "$(dirname "$0")"

echo "============================================================"
echo " DEMO E2E RabbitMQ  (Lab 6 - RSE  <->  Comunidad/Proveedores)"
echo "============================================================"
echo
echo ">> [Proceso 1 / tnotif] publica CONVOCATORIA ......................."
./02_publicar_convocatoria.sh
echo
echo ">> [Proceso 2 / inicio] consume la CONVOCATORIA ..................."
./03_consumir_convocatoria.sh
echo
echo ">> [Proceso 2 / fin] publica POSTULACION (respuesta) ............."
./04_publicar_postulacion.sh
echo
echo ">> [Proceso 1 / Recibir postulaciones] consume la RESPUESTA ......."
./05_consumir_postulacion.sh
echo
echo "============================================================"
echo " OK: comunicacion bidireccional verificada por RabbitMQ."
echo "============================================================"
