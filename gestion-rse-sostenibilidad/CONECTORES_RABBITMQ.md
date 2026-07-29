# Proceso 1 — Gestión de RSE y Sostenibilidad · Conectores RabbitMQ (REST)

Este documento describe **paso a paso** cómo añadir la comunicación con RabbitMQ al proceso
RSE existente (`Proceso_RSE_Sodimac.bos`) usando **conectores REST de Bonita** contra la
**Management HTTP API** de RabbitMQ (`http://localhost:15672`, usuario `guest`/`guest`).

> Requisito previo: RabbitMQ corriendo (`docker compose up -d` en la raíz de `lab6/`) con las
> colas `rse.convocatorias` y `rse.postulaciones` ya declaradas (lo hace `definitions.json`).

Los payloads y URLs son idénticos a los de `scripts/02..05_*.sh`, ya validados end-to-end.

---

## A. Publicar convocatoria — conector en la tarea de sistema `tnotif`

`tnotif` = "Notificar áreas y aliados". Es donde el diagrama ya tenía el message flow
`MF_1 "Convocatoria / requisitos"` hacia el pool externo. Ahí publicamos a la cola.

1. Seleccionar la tarea **`tnotif`** → pestaña **Execution → Connectors in → Add**.
2. Categoría **Web → REST → POST**. Nombre: `publicarConvocatoria`. Event: **Enter** (o Finish).
3. Configuración de la request:
   - **URL**: `http://localhost:15672/api/exchanges/%2f/amq.default/publish`
   - **Method**: `POST`
   - **Content type**: `application/json`  ·  **Charset**: `UTF-8`
   - **Auth (Basic)**: usuario `guest`, password `guest`
   - **Headers**: `content-type` = `application/json`
4. **Body** (pestaña *Body*, opción *Text/JSON*). Usar una **expresión Groovy** para inyectar los
   datos de la variable de negocio `iniciativa` en el `payload`:

```groovy
import groovy.json.JsonOutput
def negocio = [
    codigo             : iniciativa.codigo,
    nombre             : iniciativa.nombre,
    tipo               : iniciativa.tipo,
    presupuestoAprobado: iniciativa.presupuestoAprobado,
    requisitos         : "Convocatoria RSE - ver bases"
]
def sobre = [
    routing_key     : "rse.convocatorias",
    payload         : JsonOutput.toJson(negocio),   // payload como STRING
    payload_encoding: "string",
    properties      : [ content_type: "application/json", delivery_mode: 2 ]
]
return JsonOutput.toJson(sobre)
```

5. (Opcional) Mapear la salida: la respuesta de RabbitMQ es `{"routed":true}`. Se puede guardar en
   una variable de proceso `publicacionOk` con un script sobre `bodyAsString`/`bodyAsObject`.

---

## B. Recibir postulación — conector en la nueva tarea `Recibir postulaciones`

Añadir **después** de `tnotif` (o en una rama paralela) una tarea **`trecibe`** llamada
*"Recibir postulaciones"* (userTask con botón "consultar", o serviceTask con timer de reintento).
Ahí consumimos la respuesta del proveedor desde `rse.postulaciones`.

1. Seleccionar `trecibe` → **Connectors in → Add → Web → REST → POST**. Nombre: `recibirPostulacion`.
2. Request:
   - **URL**: `http://localhost:15672/api/queues/%2f/rse.postulaciones/get`
   - **Method**: `POST` · **Content type**: `application/json` · **Auth Basic** `guest/guest`
   - **Body** (texto fijo):

```json
{"count":1,"ackmode":"ack_requeue_false","encoding":"auto"}
```

3. **Mapear la salida** (pestaña *Output*). La respuesta es un **array**; si hay mensaje,
   `payload` trae el JSON del proveedor. Script Groovy para extraer y guardar en negocio:

```groovy
import groovy.json.JsonSlurper
// bodyAsObject: lista de mensajes devueltos por /get
if (bodyAsObject && bodyAsObject.size() > 0) {
    def msg = new JsonSlurper().parseText(bodyAsObject[0].payload as String)
    // ejemplo: guardar en variables de proceso / iniciativa
    // proveedorSeleccionado = msg.proveedor
    // montoPostulacion      = msg.montoOfertado
    return msg.proveedor + " (" + msg.montoOfertado + ")"
} else {
    return "SIN_POSTULACIONES_AUN"
}
```

   Mapear el retorno a una variable de proceso `String proveedorSeleccionado`
   (Data → añadir variable de proceso si no existe).

4. Si la cola está vacía (proveedor aún no respondió), el conector devuelve lista vacía →
   dejar un **boundary timer** o un gateway que reintente / espere. Para la **demo** basta con
   ejecutar el Proceso 2 antes de completar esta tarea.

---

## C. Orden de la demo (mapea a Actividades 8–9 del PDF)

1. `docker compose up -d` (RabbitMQ + colas).
2. **Run** del Proceso 1 (RSE) en Bonita Portal; instanciar como `coordinador.rse`.
3. Avanzar el proceso hasta `tnotif` → el conector publica en `rse.convocatorias`
   (verificar en `http://localhost:15672` → Queues, o `scripts/03_consumir_convocatoria.sh`).
4. **Run** del Proceso 2 (Comunidad/Proveedores) → consume la convocatoria, el proveedor postula,
   publica en `rse.postulaciones`.
5. Completar `Recibir postulaciones` en el Proceso 1 → el conector consume la respuesta y la
   guarda. **Comunicación bidireccional demostrada.**

---

## D. Notas / troubleshooting

- **vhost `/`** se escribe **`%2f`** en las URLs de la API.
- `guest/guest` solo funciona por HTTP API si `loopback_users = none` (ya está en
  `rabbitmq/rabbitmq.conf`). En una PC nueva, levantar con el `docker-compose.yml` del repo.
- El **exchange por defecto** `amq.default` enruta por `routing_key` = nombre de la cola
  (por eso no hace falta crear exchanges/bindings).
- Si Bonita bloquea llamadas a `localhost`, usar la IP del host o `host.docker.internal` según
  dónde corra el Studio.
- El `.bpmn` de referencia (`Diagrama_P5_RSE_ejecutable.bpmn`) documenta el message flow original;
  tras esta integración ese flujo se materializa por las colas.
