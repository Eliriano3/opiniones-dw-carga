# Evidencias de la carga ETL

Estudiante: Eduardo Liriano  
Matricula: 20231017  
Profesor: Francis Ramirez  
Big Data, ITLA

## Entorno

- Motor: Microsoft SQL Server 2025, puerto 14330.
- Base transaccional: `OpinionesWebDB`.
- Base analitica: `OpinionesDW`.
- Usuario de conexion: `sa`.
- Aplicacion: `src/Opiniones.EtlWorker`.

## Ejecuciones

| Ejecucion | Resultado |
|---|---|
| Primera | Carga inicial de `OpinionesDW`: 406 opiniones y 494 rechazos. |
| Segunda | Prueba de re-ejecucion: 0 opiniones nuevas, 406 duplicadas, 100 cargas historicas no repetidas. |
| Tercera | Carga de `OpinionesWebDB`: 200 resenas nuevas. En `OpinionesDW` no se insertaron opiniones nuevas. |
| Cuarta | Prueba de re-ejecucion de la base transaccional: 0 resenas nuevas en `OpinionesWebDB` y 200 duplicadas. En `OpinionesDW` tampoco se insertaron opiniones nuevas. |

## Estado de OpinionesDW

| Tabla | Registros |
|---|---:|
| `dim.Categoria` | 5 |
| `dim.Clasificacion` | 3 |
| `dim.Cliente` | 501 |
| `dim.Fecha` | 4018 |
| `dim.Fuente` | 3 |
| `dim.Producto` | 200 |
| `etl.Carga` | 120 |
| `etl.PalabraClave` | 32 |
| `etl.Rechazo` | 1976 |
| `fact.Opinion` | 406 |
| `fact.ResumenSatisfaccion` | 386 |
| `stg.Cliente` | 500 en la ultima carga |
| `stg.Producto` | 200 en la ultima carga |
| `stg.Encuesta` | 6 en la ultima carga |
| `stg.ResenaWeb` | 200 en la ultima carga |
| `stg.ComentarioSocial` | 200 en la ultima carga |

La tabla `etl.Rechazo` acumula las cuatro ejecuciones, 494 por cada una. Cada fila de
`etl.Carga` conserva el conteo de su propia ejecucion. La primera ejecucion tiene 494
rechazos, la segunda 494, la tercera 494 y la cuarta 494.

## Estado de OpinionesWebDB

| Tabla | Registros |
|---|---:|
| `dbo.Categoria` | 5 |
| `dbo.Producto` | 200 |
| `dbo.Cliente` | 500 |
| `dbo.Resena` | 200 |

Las 200 resenas tienen estado `P`, calificacion entre 1 y 5 y estan relacionadas con un
cliente y un producto existentes. El `IdResena` va de 1 a 200 y corresponde al numero de
`IdReview`: `W0001` se cargo como 1 y `W0200` como 200.

## Precios de productos

El precio se calculo con la regla de `config/precios_categorias.json`. Los rangos obtenidos
son:

| Categoria | Productos | Precio minimo | Precio maximo | Precio promedio |
|---|---:|---:|---:|---:|
| Deportes | 34 | 40.24 | 64.74 | 51.14 |
| Electrónica | 37 | 151.99 | 247.99 | 208.58 |
| Hogar | 43 | 49.99 | 78.49 | 65.77 |
| Juguetes | 53 | 20.09 | 29.79 | 24.42 |
| Ropa | 33 | 29.99 | 49.79 | 39.72 |

Ejemplos: `P001` quedo en 23.69, `P002` en 223.99, `P003` en 21.09 y `P016` en 62.99.

## Validaciones de OpinionesDW

- Huerfanos en `fact.Opinion` y `fact.ResumenSatisfaccion`: 0 en todas las relaciones.
- Duplicados de `fact.Opinion`, `dim.Producto`, `dim.Cliente` y `dim.Categoria`: 0.
- Diferencias entre `fact.Opinion` y `fact.ResumenSatisfaccion`: 0.
- Staging de la ultima carga contra hechos: 6 contra 6 en encuestas, 200 contra 200 en
  resenas web y 200 contra 200 en comentarios sociales.
- Productos con opiniones: 26.
- Opiniones totales: 406.
- Promedio de satisfaccion por producto: 45.42 por ciento.
- Clasificacion: 204 positivas, 85 neutras y 117 negativas.

## Validaciones de OpinionesWebDB

- Resenas huerfanas de cliente, producto o categoria: 0.
- Duplicados de email, codigo de producto, nombre de categoria y `IdResena`: 0.
- Productos con al menos una resena: 20.
- Resenas totales: 200.
- Satisfaccion global: 41.50 por ciento.
- Promedio de satisfaccion por producto con resenas: 40.70 por ciento.
- Clientes sin resenas: 461.
- Resenas por estado: 200 publicadas.

## Distribucion por fuente en OpinionesDW

| Fuente | Positivas | Neutras | Negativas | Total |
|---|---:|---:|---:|---:|
| Encuestas CSV | 2 | 2 | 2 | 6 |
| Resenas web | 118 | 13 | 69 | 200 |
| Comentarios sociales | 84 | 70 | 46 | 200 |
| Total | 204 | 85 | 117 | 406 |

## Capturas de pantalla

Las capturas estan en la carpeta `capturas/`:

| Archivo | Contenido |
|---|---|
| `01_web_categorias_productos_clientes.jpg` | Categorias, productos con precio y total de clientes de `OpinionesWebDB`. |
| `02_web_resenas.jpg` | Resenas de `OpinionesWebDB` con cliente, producto, calificacion y estado. |
| `03_web_resumen_productos.jpg` | Resumen de resenas y satisfaccion por producto en `OpinionesWebDB`. |
| `04_dw_categorias_clientes_fact.jpg` | Categorias, clientes y opiniones de `OpinionesDW`. |
| `05_dw_resumen_satisfaccion.jpg` | Resumen de satisfaccion por producto, fecha y fuente. |
| `06_dw_etl_carga.jpg` | Bitacora de las ejecuciones en `etl.Carga`. |
| `07_dw_etl_rechazo.jpg` | Rechazos de la primera ejecucion en `etl.Rechazo`. |
| `08_dw_integridad_referencial.jpg` | Vista de integridad referencial con todos los conteos en cero. |
| `09_ejecucion_etl_consola.jpg` | Salida de la aplicacion durante una ejecucion. |

## Archivos de evidencia

- Primera ejecucion de OpinionesDW: `evidence/consultas_validacion.txt`.
- Segunda ejecucion de OpinionesDW: `evidence/consultas_validacion_final.txt`.
- Cuarta ejecucion de OpinionesDW: `evidence/consultas_validacion_actual.txt`.
- Validacion de OpinionesWebDB: `evidence/consultas_web.txt`.
- Tablas, vistas y procedimientos: `evidence/objetos_bd.txt`.
- Log de la primera carga: `logs/etl_20261023_191229_549.json`.
- Log de la segunda carga: `logs/etl_20261023_191357_513.json`.
- Log de la tercera carga: `logs/etl_20261023_192250_326.json`.
- Log de la cuarta carga: `logs/etl_20261023_193030_177.json`.
