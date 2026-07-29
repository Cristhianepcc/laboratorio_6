# Laboratorio 6 — BPM y Servicios Web Basados en Eventos (RabbitMQ)

**Curso:** Diseño de Servicios Empresariales (DSE) · **Trabajo individual** · Cristhian Taipe

Integración de **dos procesos de negocio** modelados en **BonitaSoft** que se comunican de forma
**asíncrona vía un bróker de mensajes (RabbitMQ)**.

Proceso de negocio desarrollado: **Gestión de Responsabilidad Social y Sostenibilidad (RSE)**.

## Arquitectura

```
 Proceso 1: Gestión de RSE y Sostenibilidad            RabbitMQ (Docker, HTTP API :15672)
 ────────────────────────────────────────             ───────────────────────────────────
 tnotif "Notificar áreas y aliados" ──publish──►  [ rse.convocatorias ] ──get──►  Proceso 2
                                                                                   Comunidad /
 "Recibir postulaciones"  ◄──────get────────────  [ rse.postulaciones ] ◄─publish─ Proveedores
```

- **Proceso 1 (RSE)** publica una *convocatoria/requisitos* a la cola `rse.convocatorias`
  (en la tarea `tnotif`, donde el diagrama ya modelaba el message flow al pool externo).
- **Proceso 2 (Comunidad / Proveedores)** consume la convocatoria, el proveedor **postula** y
  publica su respuesta en `rse.postulaciones`.
- **Proceso 1** consume esa respuesta en la tarea *Recibir postulaciones*. Comunicación
  **bidireccional** y **desacoplada** por el bróker.

Integración Bonita↔RabbitMQ mediante **conectores REST** contra la **Management HTTP API**
(el enfoque más estable en Bonita Community; corresponde al "caso extremo" del enunciado y a la
[HTTP API reference](https://www.rabbitmq.com/docs/http-api-reference)).

## Estructura del repo

| Ruta | Contenido |
| --- | --- |
| `docker-compose.yml` · `rabbitmq/` | RabbitMQ + Management UI y **auto-declaración** de las 2 colas (`definitions.json`). |
| `gestion-rse-sostenibilidad/` | Proceso 1: `.bos` ejecutable + `CONECTORES_RABBITMQ.md` (config paso a paso). |
| `comunidad-proveedores/` | Proceso 2: diseño del responder mínimo + config de conectores. |
| `scripts/` | Reproducen con `curl` exactamente lo que hacen los conectores (demo/validación sin Bonita). |
| `NOTES.md` | Mapeo de las **Actividades 1–11** del enunciado y registro de resultados. |
| `Microsoft Word - Lab_...pdf` | Enunciado original. |

## Requisitos

- **Docker** (para RabbitMQ) — o RabbitMQ instalado localmente.
- **Java JDK 17** y **Bonita Studio Community 2023.2** (para abrir/ejecutar los `.bos`).

## Puesta en marcha

```bash
# 1) Bróker + colas
docker compose up -d
#    UI de gestión: http://localhost:15672   (guest / guest)

# 2) Validar la comunicación E2E sin Bonita (opcional pero recomendado)
./scripts/00_demo_e2e.sh
#    -> publica convocatoria, la consume, publica postulación y la consume.

# 3) En Bonita Studio: importar los .bos, desplegar BDM + organización y ejecutar
#    ambos procesos siguiendo gestion-rse-sostenibilidad/CONECTORES_RABBITMQ.md
```

### Usuarios de prueba (organización `RSE_Sodimac`, password `bpm12345`)
| Usuario | Rol |
| --- | --- |
| `coordinador.rse` | Coordinador de RSE (inicia Proceso 1) |
| `comite.sost` | Comité de Sostenibilidad / Gerencia |
| `operario` | Áreas Operativas |
| `proveedor` | Proveedor (inicia/atiende Proceso 2) |

## Detener / limpiar

```bash
docker compose down          # detiene el broker (las colas se recrean al volver a subir)
```

## Colas

| Cola | Sentido | Contenido |
| --- | --- | --- |
| `rse.convocatorias` | Proceso 1 → Proceso 2 | convocatoria RSE (código, nombre, tipo, presupuesto, requisitos) |
| `rse.postulaciones` | Proceso 2 → Proceso 1 | postulación del proveedor (propuesta, monto, certificación, aceptada) |
