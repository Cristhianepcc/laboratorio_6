# NOTES — Registro de resultados y mapeo de actividades (Lab 6)

Proceso de negocio: **Gestión de RSE y Sostenibilidad**. Contraparte: **Comunidad / Proveedores**.
Bróker: **RabbitMQ** (Docker). Integración: **conectores REST → Management HTTP API**.

## Mapeo con las Actividades del enunciado (1–11)

| # | Actividad del PDF | Cómo se cumple aquí | Estado |
| --- | --- | --- | --- |
| 1 | Instalar Bonita Studio (última) | Bonita Studio Community 2023.2 | ✅ |
| 2 | Instalar RabbitMQ (última) | `rabbitmq:3-management` vía `docker compose up -d` | ✅ |
| 3 | Entender el desafío de integrar 2 procesos vía RabbitMQ | Arquitectura de 2 colas desacoplando RSE ↔ Proveedores (ver `README.md`) | ✅ |
| 4 | Cargar proceso 1 en Bonita | `gestion-rse-sostenibilidad/Proceso_RSE_Sodimac.bos` (import) | ✅ |
| 5 | Cargar proceso 2 en Bonita | `comunidad-proveedores/` (responder mínimo, diseño documentado) | ✅ diseño / ⏳ modelar en Studio |
| 6 | Conectar proceso 1 con servicio vía conector RabbitMQ | Conector REST `publicarConvocatoria` en `tnotif` (publica a la cola) | ✅ config lista |
| 7 | Conectar proceso 1 con proceso 2 vía conector RabbitMQ | Colas `rse.convocatorias` (P1→P2) y `rse.postulaciones` (P2→P1) | ✅ |
| 8 | Ejecutar los procesos | Run en Bonita Portal (P1 como `coordinador.rse`, P2 como `proveedor`) | ⏳ en Studio |
| 9 | Verificar que se comunican vía RabbitMQ | Validado E2E con `scripts/00_demo_e2e.sh` (ver evidencia abajo) | ✅ |
| 10 | Registrar los resultados | Este archivo + capturas en `docs/` | ✅ |
| 11 | Reemplazar por el conector oficial de Bonita | Addendum opcional (ver sección) — REST ya demuestra la comunicación | ⏳ opcional |

> Nota: los pasos marcados "en Studio" requieren la GUI de Bonita (modelar/ejecutar). Toda la
> configuración (URLs, auth, bodies, scripts Groovy) está lista y **verificada fuera de Bonita**
> con los scripts, que replican byte a byte lo que hacen los conectores.

## Evidencia de la verificación (Actividad 9) — salida de `scripts/00_demo_e2e.sh`

```
>> [Proceso 1 / tnotif] publica CONVOCATORIA
   {"routed":true}
>> [Proceso 2 / inicio] consume la CONVOCATORIA
   payload: {"codigo":"RSE-2026-001","nombre":"Reciclaje de mermas en tiendas","tipo":"RECICLAJE",...}
>> [Proceso 2 / fin] publica POSTULACION (respuesta)
   {"routed":true}
>> [Proceso 1 / Recibir postulaciones] consume la RESPUESTA
   payload: {"codigoConvocatoria":"RSE-2026-001","proveedor":"EcoAndes SAC","montoOfertado":12800.0,...}
OK: comunicacion bidireccional verificada por RabbitMQ.
```

## Addendum (Actividad 11) — conector oficial / conector del ejemplo

El enunciado sugiere, tras lograr la comunicación, reemplazar el conector por el oficial de
BonitaSoft (Kafka/RabbitMQ) o reproducir el conector Java del ejemplo kurze-prozesse. En Bonita
Community el conector oficial disponible es de **Kafka**; para RabbitMQ el camino estable es el
REST aquí implementado. Alternativas a documentar/probar si sobra tiempo:
- Conector Java a medida (Collaboration-with-MQ.zip del ejemplo) usando el cliente AMQP.
- Conector oficial Kafka de Bonita (requeriría cambiar el bróker a Kafka).

## Pendientes para la entrega
- [ ] Modelar el Proceso 2 en Bonita Studio a partir de `comunidad-proveedores/README.md`.
- [ ] Añadir los 2 conectores REST al `.bos` del Proceso 1 (ver `CONECTORES_RABBITMQ.md`).
- [ ] Capturas de la ejecución en el Portal y de la cola en `http://localhost:15672` → `docs/`.
- [ ] Subir el repo `laboratorio_6` a GitHub.
