# Proceso 2 — Comunidad / Proveedores (responder mínimo)

Contraparte del Proceso 1 (RSE). Convierte el pool caja-negra *"Comunidad / Proveedores"* del
diagrama RSE en un **proceso Bonita ejecutable** que se comunica por RabbitMQ.

Rol en la arquitectura:

```
  rse.convocatorias  --get-->  [Proceso 2]  --publish-->  rse.postulaciones
       (recibe)                  postula                      (responde)
```

## Diseño del proceso (crear en Bonita Studio como diagrama nuevo)

Pool **`Proceso_Comunidad_Proveedores`** (nombre de pool **ASCII**, sin tildes). Una sola lane
**`Proveedor`**. Flujo:

1. **Start event** `inicio`.
2. **Service task** `trecibeConv` — "Recibir convocatoria" · conector REST POST que consume de
   `rse.convocatorias` (config en la sección A). Guarda los datos en variables de proceso.
3. **User task** `tpostular` — "Evaluar y postular" (actor `actorProveedor`). Formulario con:
   datos de la convocatoria (read-only) + campos: `nombreProveedor`, `propuesta`,
   `montoOfertado`, `certificacion`, `aceptada` (boolean).
4. **Service task** `tenviaPost` — "Enviar postulación" · conector REST POST que publica en
   `rse.postulaciones` (config en la sección B).
5. **End event** `fin`.

### Variables de proceso (Data)
| Variable | Tipo | Uso |
| --- | --- | --- |
| `codigoConvocatoria` | String | extraído del mensaje recibido |
| `nombreConvocatoria` | String | read-only en el form |
| `tipoConvocatoria` | String | read-only |
| `nombreProveedor` | String | input del proveedor |
| `propuesta` | String | input |
| `montoOfertado` | Double | input |
| `certificacion` | String | input |
| `aceptada` | Boolean | input |

### Actor / organización
- Actor `actorProveedor` (iniciador). Usuario de prueba `proveedor` / `bpm12345`.
- Se puede reutilizar la organización `RSE_Sodimac` añadiendo un grupo/rol `Proveedores`, o
  crear una organización mínima con un solo usuario `proveedor`.

---

## A. Conector "Recibir convocatoria" (`trecibeConv`)

**Web → REST → POST**, event **Enter**:
- **URL**: `http://localhost:15672/api/queues/%2f/rse.convocatorias/get`
- **Auth Basic** `guest/guest` · content-type `application/json`
- **Body** (texto fijo):

```json
{"count":1,"ackmode":"ack_requeue_false","encoding":"auto"}
```

- **Output** (Groovy) → mapear a las variables de proceso:

```groovy
import groovy.json.JsonSlurper
if (bodyAsObject && bodyAsObject.size() > 0) {
    def m = new JsonSlurper().parseText(bodyAsObject[0].payload as String)
    // asignar a variables de proceso desde el mapeo de salida:
    // codigoConvocatoria = m.codigo
    // nombreConvocatoria = m.nombre
    // tipoConvocatoria   = m.tipo
    return m.codigo
}
return "SIN_CONVOCATORIA"
```

---

## B. Conector "Enviar postulación" (`tenviaPost`)

**Web → REST → POST**, event **Enter/Finish**:
- **URL**: `http://localhost:15672/api/exchanges/%2f/amq.default/publish`
- **Auth Basic** `guest/guest` · content-type `application/json`
- **Body** (Groovy con los inputs del proveedor):

```groovy
import groovy.json.JsonOutput
def negocio = [
    codigoConvocatoria: codigoConvocatoria,
    proveedor         : nombreProveedor,
    propuesta         : propuesta,
    montoOfertado     : montoOfertado,
    certificacion     : certificacion,
    aceptada          : aceptada
]
def sobre = [
    routing_key     : "rse.postulaciones",
    payload         : JsonOutput.toJson(negocio),
    payload_encoding: "string",
    properties      : [ content_type: "application/json", delivery_mode: 2 ]
]
return JsonOutput.toJson(sobre)
```

Respuesta esperada de RabbitMQ: `{"routed":true}`.

---

## Prueba rápida sin Bonita

Los scripts de la raíz reproducen exactamente estos dos conectores:
`scripts/03_consumir_convocatoria.sh` (= conector A) y `scripts/04_publicar_postulacion.sh`
(= conector B). El flujo completo: `scripts/00_demo_e2e.sh`.
