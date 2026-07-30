# Guía de Bonita Studio para el Proyecto Final (TIF)

Todo lo que queda del proyecto está detrás de la GUI de Bonita. Esta guía reduce esos
puntos a "seguir pasos y pulsar botones": las URLs, credenciales, cuerpos y scripts que
aparecen aquí **ya están validados** contra los servicios reales.

**Puntos en juego: 7 de 20.**

| Bloque | Rúbrica | Puntos | Tiempo estimado |
| --- | --- | ---: | --- |
| A. Conector de correo | Criterio 3 | +1 | 15 min |
| B. Conector REST al servicio | Criterio 3 | +2 | 25 min |
| C. Conector RabbitMQ | Criterio 3 | (cierra el 3) | 30 min |
| D. Living Application | Criterio 2 | +1 | 40 min |
| E. Subprocesos | Criterio 1 | +1 | 20 min |

> **Si el tiempo aprieta, este es el orden de rentabilidad: A → B → D → E → C.**
> A y B juntos ya suben el criterio 3 de 0 a 3 puntos (la rúbrica da 3 por
> "integración con servicios REST"; el broker no añade más puntos, pero sí es un
> requisito explícito del enunciado del proyecto).

---

## 0. Levantar la infraestructura (una sola vez)

```bash
# en laboratorio_6/
docker compose up -d
```

Esto deja corriendo:

| Servicio | Puerto | Para qué | Comprobar en |
| --- | --- | --- | --- |
| RabbitMQ | `5672` / `15672` | Broker de mensajes | <http://localhost:15672> (`guest`/`guest`) |
| MailHog | `1025` / `8025` | Servidor SMTP de pruebas | <http://localhost:8025> |

Y en el repositorio de servicios (`sodimac-servicios-rest`):

```bash
docker compose up -d       # PostgreSQL en :5432
cp .env.example .env
```

Luego, en **dos terminales**:

```bash
# terminal 1 — API REST en :5000, Swagger en /docs
REPO_BACKEND=sqlalchemy python run.py

# terminal 2 — consumidor de las colas
REPO_BACKEND=sqlalchemy EVENTOS_BACKEND=rabbitmq python worker.py
```

> ### ⚠️ `REPO_BACKEND=sqlalchemy` es obligatorio en AMBOS
>
> La API y el worker son **dos procesos distintos**. Con el backend por defecto
> (`memoria`) cada uno tiene su propio repositorio en RAM: el worker sincroniza la
> iniciativa que envía Bonita y **la API responde 404**, porque no comparten estado.
>
> Esto está verificado: con `memoria` el flujo falla; con PostgreSQL apuntando ambos a
> la misma base, funciona de extremo a extremo. El backend en memoria sirve para las
> pruebas unitarias, no para la demo.
>
> Comprobar antes de empezar: `curl -s localhost:5000/health` debe decir
> `{"backend":"sqlalchemy"}`. Si dice `memoria`, la demo no va a funcionar.
>
> Si el puerto 5432 está ocupado por otro proyecto, cambia el mapeo en
> `docker-compose.yml` (p. ej. `"5433:5432"`) y ajusta `DATABASE_URL` en el `.env`.

Colas declaradas automáticamente: `rse.convocatorias`, `rse.postulaciones` y
`rse.notificaciones`.

### Comprobación rápida de que todo está en pie

```bash
# publica una convocatoria igual que el conector de Bonita
./scripts/02_publicar_convocatoria.sh          # -> {"routed":true}
sleep 2
curl -s localhost:5000/api/iniciativas/RSE-2026-001   # -> la iniciativa, no un 404
```

Si eso responde con la iniciativa, la mitad del criterio 3 ya está demostrada antes de
tocar Bonita.

---

## A. Conector de correo electrónico  ·  +1 punto

La rúbrica pide "integración con servidores de correo electrónico". MailHog es un
servidor SMTP real que captura los mensajes en vez de entregarlos, así que la
integración se demuestra sin cuentas ni salida a internet.

**Dónde ponerlo:** tarea `tnotif` — *"Notificar áreas y aliados"*. Es la tarea que
semánticamente notifica, así que el conector cae justo donde el negocio lo espera.

1. Seleccionar **`tnotif`** → pestaña **Execution** → **Connectors out** → **Add**.
2. Categoría **Messaging → Email (SMTP)**. Nombre: `notificarAliadosPorCorreo`.
3. **Servidor:**

   | Campo | Valor |
   | --- | --- |
   | SMTP host | `localhost` |
   | SMTP port | `1025` |
   | Autenticación | **desmarcada** (MailHog no pide credenciales) |
   | SSL / STARTTLS | **desmarcados** |

4. **Mensaje:**

   | Campo | Valor |
   | --- | --- |
   | From | `procesos.bpm@sodimac.pe` |
   | To | `coordinador.rse@sodimac.pe` |
   | Subject | expresión Groovy (abajo) |
   | Content type | `text/html` |

5. **Subject** — pulsar el lápiz → *Script (Groovy)*:

   ```groovy
   "Convocatoria RSE " + iniciativa.codigo + " — " + iniciativa.nombre
   ```

6. **Message** — *Script (Groovy)*:

   ```groovy
   """<h3>Convocatoria de iniciativa RSE</h3>
   <p>Se ha aprobado la iniciativa <b>${iniciativa.nombre}</b> (${iniciativa.codigo}).</p>
   <ul>
     <li>Tipo: ${iniciativa.tipo}</li>
     <li>Presupuesto aprobado: S/ ${iniciativa.presupuestoAprobado}</li>
   </ul>
   <p>Las áreas operativas y los aliados quedan convocados a participar.</p>"""
   ```

**Evidencia:** ejecutar el proceso hasta `tnotif` y abrir <http://localhost:8025>. El
correo aparece en la bandeja. **Captura esa pantalla** — es la prueba del criterio.

> Ya está verificado que MailHog acepta y muestra correo correctamente; si no aparece
> nada, el problema está en la configuración del conector, no en el servidor.

---

## B. Conector REST contra el servicio del negocio  ·  +2 puntos

Aquí es donde el proceso deja de hacer el trabajo y **lo delega a un servicio web**, que
es exactamente lo que la rúbrica premia con 3 puntos.

**Dónde ponerlo:** tarea de sistema `tconsolida` — *"Consolidar KPIs y reporte base"*.
En vez de calcular el cumplimiento con un script Groovy embebido, el proceso llama al
servicio de dominio `EvaluadorDeMetas` a través de la API.

1. Seleccionar la ServiceTask **"Consolidar KPIs y reporte base"** → **Connectors in**
   → **Add** → **Web → REST → GET**. Nombre: `evaluarCumplimientoMetas`.
2. **Request:**

   | Campo | Valor |
   | --- | --- |
   | URL | expresión Groovy (abajo) |
   | Method | `GET` |
   | Content type | `application/json` · charset `UTF-8` |

3. **URL** — *Script (Groovy)*:

   ```groovy
   "http://localhost:5000/api/iniciativas/" + iniciativa.codigo + "/cumplimiento?tolerancia=0.9"
   ```

4. **Output** — mapear la respuesta a variables del proceso. Pestaña **Output**, script
   Groovy sobre `bodyAsObject`:

   ```groovy
   import groovy.json.JsonSlurper
   def r = new JsonSlurper().parseText(bodyAsString)
   return r.cumplidas          // -> variable de proceso Boolean metasCumplidas
   ```

   Crear antes la variable de proceso **`metasCumplidas`** (Boolean) en la pestaña
   **Data**. Añadir un segundo mapeo si quieres guardar el detalle:

   ```groovy
   import groovy.json.JsonSlurper
   def r = new JsonSlurper().parseText(bodyAsString)
   return "Avance global: " + r.porcentajeGlobal + "% · rezagados: " + r.rezagados.join(", ")
   ```

   → variable de proceso **`resumenCumplimiento`** (String).

5. **Conectar la decisión al flujo.** El gateway **«¿Metas cumplidas?»** ya existe en el
   diagrama. Editar su condición para que use la respuesta del servicio en vez de una
   variable manual:

   - Transición *"sí"*: `metasCumplidas == true`
   - Transición *"no"*: `metasCumplidas == false` → lleva a *"Generar acciones correctivas"*

Esto es lo que la rúbrica llama **composición de servicios mediada por procesos**: la
regla de negocio vive en el servicio, el proceso solo decide el camino.

**Evidencia:** captura de la configuración del conector + captura del formulario donde
se ve `resumenCumplimiento` con datos que vinieron de la API.

> **Antes de configurarlo, comprueba que el servicio responde.** Secuencia completa
> verificada:
>
> ```bash
> # 1. la iniciativa debe existir (la crea el worker al llegar la convocatoria)
> curl -s localhost:5000/api/iniciativas/RSE-2026-001
>
> # 2. debe tener al menos un KPI, o el servicio responde 400
> curl -s -XPOST localhost:5000/api/iniciativas/RSE-2026-001/indicadores \
>   -H 'content-type: application/json' \
>   -d '{"nombre":"Merma valorizada","unidad":"t","valorLineaBase":0,"valorActual":95,"meta":100}'
>
> # 3. ahora sí, el endpoint del conector
> curl -s "localhost:5000/api/iniciativas/RSE-2026-001/cumplimiento?tolerancia=0.9"
> ```
>
> Respuesta esperada del paso 3:
>
> ```json
> {"codigo":"RSE-2026-001","cumplidas":true,"porcentajeGlobal":95.0,
>  "indicadoresCumplidos":1,"indicadoresTotales":1,"rezagados":[],
>  "requiereAccionesCorrectivas":false}
> ```
>
> **Una iniciativa sin KPIs devuelve 400**, no 404: evaluar el cumplimiento sin
> indicadores no tiene sentido de negocio. Asegúrate de que el proceso registre al menos
> un KPI antes de llegar a esta tarea, o el conector fallará.

---

## C. Conectores RabbitMQ  ·  cierra el criterio 3

Los dos conectores de publicación/consumo ya están documentados paso a paso en
[`../gestion-rse-sostenibilidad/CONECTORES_RABBITMQ.md`](../gestion-rse-sostenibilidad/CONECTORES_RABBITMQ.md)
— esa guía sigue siendo válida. Aquí solo va **lo nuevo del TIF**: la cola de vuelta.

### C.1 Consumir `rse.notificaciones` (respuesta del servicio web)

Ahora el servicio REST responde al proceso por una tercera cola. El flujo completo es:

```
tnotif ──publica──► rse.convocatorias ──► worker.py ──► crea la iniciativa
                                                            │
Proceso 2 ──publica──► rse.postulaciones ──► worker.py ─────┘
                                                            │
tconsolida ◄──consume── rse.notificaciones ◄──publica───────┘
```

En la tarea **"Consolidar KPIs y reporte base"**, añadir un segundo conector
**Web → REST → POST** llamado `recibirNotificacionServicio`:

| Campo | Valor |
| --- | --- |
| URL | `http://localhost:15672/api/queues/%2f/rse.notificaciones/get` |
| Method | `POST` · Content type `application/json` |
| Auth Basic | `guest` / `guest` |

**Body** (texto fijo):

```json
{"count":1,"ackmode":"ack_requeue_false","encoding":"auto"}
```

**Output** — Groovy:

```groovy
import groovy.json.JsonSlurper
if (bodyAsObject && bodyAsObject.size() > 0) {
    def sobre = new JsonSlurper().parseText(bodyAsObject[0].payload as String)
    // el servicio envuelve el evento: { id, tipo, ocurridoEn, origen, datos }
    return sobre.tipo + " — proveedor: " + sobre.datos.proveedor
} else {
    return "SIN_NOTIFICACIONES"
}
```

→ variable de proceso **`ultimaNotificacion`** (String).

**Evidencia:** captura de <http://localhost:15672> mostrando las **tres** colas con
tráfico, y captura del formulario con `ultimaNotificacion` rellenada.

---

## D. Living Application  ·  +1 punto

La rúbrica da los 3 puntos del criterio 2 solo con **Application Page o Living
Application**; hoy el `.bos` no contiene ninguna (`app/applications/` no existe).

Es una aplicación web con menú por rol, que envuelve los procesos:
`Rol → Procesos → Instancias → Status`.

### D.1 Crear el descriptor

En **Bonita Studio**: **File → New → Application descriptor**. Se crea un `.xml` bajo
`app/applications/`.

Estructura a definir (la GUI del Studio tiene un editor de formulario para esto, no hace
falta escribir el XML a mano):

| Campo | Valor |
| --- | --- |
| Token | `rse` |
| Display name | `Gestión de RSE y Sostenibilidad` |
| Version | `1.0` |
| Profile | `User` |
| Layout | `custompage_defaultlayout` |
| Theme | `custompage_bootstrapdefaulttheme` |

### D.2 Páginas y menú por rol

Añadir estas páginas (**Application pages**) y su entrada de menú:

| Menú | Página | Contenido | Perfil |
| --- | --- | --- | --- |
| **Inicio** | `inicio` | Página de bienvenida | todos |
| **Mis procesos** | `procesos` | Lista de procesos que el usuario puede iniciar | todos |
| **Mis tareas** | `tareas` | Tareas pendientes del usuario | todos |
| **Instancias y estado** | `instancias` | Casos abiertos con su estado | `actorCoordinadorRSE` |
| **Iniciativas RSE** | `iniciativas` | Listado desde el servicio REST | `actorCoordinadorRSE`, `actorComite` |

Bonita trae páginas predefinidas que cubren casi todo esto sin programar
(`Bonita User Case list`, `Bonita Task list`, `Bonita Process list`): al añadir una
Application Page, elegirlas del catálogo en lugar de crear una custom page.

> El menú **por rol** es lo que la rúbrica llama explícitamente
> *"de acuerdo a perfil (rol o papel) de usuario"*. Los tres actores ya existen en la
> organización (`actorCoordinadorRSE`, `actorComite`, `actorAreasOperativas`), así que
> basta con asociarlos a los perfiles.

### D.3 Desplegar y capturar

**Deploy** del `.bos` completo → abrir el Portal → pestaña **Applications** → entrar a
`Gestión de RSE y Sostenibilidad`.

**Captura obligatoria:** la aplicación con el menú lateral visible y una lista de
instancias con su estado. Esa imagen es la que vale los 3 puntos del criterio 2.

---

## E. Subprocesos  ·  +1 punto

El criterio 1 da 2 puntos por *"gestión de complejidad por subprocesos"* y 3 por
*"diagrama fácil de leer"*. Hoy el Proceso 1 tiene 8 tareas humanas, 5 de sistema y 3
gateways en un solo pool: funciona, pero es plano.

**Candidato natural a subproceso: el bloque de monitoreo.** Estas tres actividades forman
una unidad con vida propia y se repiten en ciclo:

- *Monitorear y medir impacto*
- *Registrar evidencias y avances*
- *Generar acciones correctivas*

**Pasos:**

1. Seleccionar las tres actividades y el gateway «¿Metas cumplidas?».
2. Clic derecho → **Extract as subprocess** (o crear una **Call Activity** y mover las
   actividades a un diagrama nuevo `Monitoreo_Impacto_RSE`).
3. Nombrar el subproceso **"Monitorear impacto y corregir"**.
4. Definir el **contrato** del subproceso: entrada `codigoIniciativa` (String), salida
   `metasCumplidas` (Boolean).

El diagrama principal queda con una sola actividad colapsada en lugar de cuatro
elementos, que es justo lo que la rúbrica llama gestión de complejidad.

**Evidencia:** captura del diagrama principal (ya legible) y del subproceso desplegado.

---

## Checklist de capturas para el informe

El informe `Informe_Lab6_RSE.docx` tiene **7 placeholders** sin rellenar. Estas son las
capturas que hay que tomar mientras se ejecuta todo lo anterior:

- [ ] Diagrama del Proceso 1 en Studio, ya con el subproceso colapsado
- [ ] Diagrama del subproceso "Monitorear impacto y corregir"
- [ ] Configuración del conector Email en `tnotif`
- [ ] Bandeja de MailHog con el correo recibido (<http://localhost:8025>)
- [ ] Configuración del conector REST `evaluarCumplimientoMetas`
- [ ] RabbitMQ Management con las 3 colas y su tráfico (<http://localhost:15672>)
- [ ] Living Application en el Portal, con el menú por rol
- [ ] Lista de instancias con su estado dentro de la aplicación
- [ ] Formulario mostrando datos que vinieron del servicio REST

---

## Apéndice — cadena verificada fuera de Bonita

Todo el lado servicios está probado end-to-end. Esta es la salida real, y es la que los
conectores de Bonita deben reproducir:

```
1) Bonita publica la convocatoria      -> {"routed":true}
2) el worker sincroniza la iniciativa  -> RSE-2026-001 | Reciclaje de mermas en
                                          tiendas | estado=APROBADA | aprobada=True
3) Proceso 2 publica la postulación    -> {"routed":true}
4) el worker registra la evidencia     -> evidencias=1 · estado=EN_EJECUCION
                                          "Postulación de EcoAndes SAC: Recojo y
                                           valorizacion de mermas organicas 3x semana"
5) notificación de vuelta a Bonita     -> {"codigo":"RSE-2026-001",
                                           "proveedor":"EcoAndes SAC",
                                           "montoOfertado":12800.0}
6) endpoint del conector REST          -> {"cumplidas":true,"porcentajeGlobal":95.0,
                                           "indicadoresCumplidos":1,"rezagados":[]}
```

También verificado: el servidor SMTP acepta correo y lo muestra en la bandeja de MailHog.

Es decir: **si un conector falla, el problema está en su configuración dentro de Bonita,
no en los servicios ni en la infraestructura.** Eso acota mucho la búsqueda.

---

## Si algo falla

| Síntoma | Causa habitual |
| --- | --- |
| El conector no alcanza `localhost` | Bonita corre en contenedor: usar `host.docker.internal` o la IP del host |
| `guest` rechazado por la API de RabbitMQ | Falta `loopback_users = none` (ya está en `rabbitmq/rabbitmq.conf`) |
| El vhost no se encuentra | El vhost `/` se escribe **`%2f`** en la URL |
| La API REST devuelve 404 | La iniciativa no existe todavía; crearla o dejar que el worker la sincronice |
| El correo no llega | Revisar que autenticación y SSL estén **desmarcados** en el conector |
