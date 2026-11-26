# Proceso ETL para OpinionesWebDB y OpinionesDW

Estudiante: Eduardo Liriano  
Matricula: 20231017  
Profesor: Francis Ramirez  
Big Data, ITLA

## 1. Alcance

El proceso lee los seis archivos CSV del proyecto y carga dos bases del modelado:

- `OpinionesWebDB`, base transaccional con categorias, productos, clientes y resenas web.
- `OpinionesDW`, base analitica con staging, dimensiones, hechos y control de cargas.

La carga de `OpinionesWebDB` y la de `OpinionesDW` se ejecutan dentro de la misma transaccion.

## 2. Arquitectura en capas

| Capa | Carpeta | Responsabilidad |
|---|---|---|
| Configuracion | `config` | Lee `.env`, rutas de CSV, conexion, palabras clave y precios. |
| Contexto | `context` | Abre la conexion, inicia, confirma o revierte la transaccion. |
| Modelos | `models` | Entidades CSV, hechos, metricas y contenedor general de la carga. |
| Extraccion | `csv_readers` | Lector CSV generico y lectores por entidad. |
| Carga | `daos` | Procedimientos almacenados y parametros hacia SQL Server. |
| Servicios | `services` | Validacion, limpieza, clasificacion, precios, orquestacion, log y resumen. |

El archivo `Program.cs` configura la aplicacion, carga la configuracion e inicia el servicio
huesped. `ImportService` coordina extraccion, validacion, transformacion y carga.

## 3. Mapeo de archivos

| Archivo CSV | Destino | Tratamiento |
|---|---|---|
| `clientes.csv` | `OpinionesWebDB.dbo.Cliente`, `stg.Cliente`, `dim.Cliente` | Limpieza de nombre y correo, unicidad de ID y email. |
| `productos.csv` | `OpinionesWebDB.dbo.Producto`, `stg.Producto`, `dim.Categoria`, `dim.Producto` | Categorias, codigo `P000`, precio por regla y nombre normalizado. |
| `encuestas.csv` | `stg.Encuesta`, `fact.Opinion` | Fuente 1. Se valida cliente, producto, fecha, clasificacion y puntaje. |
| `resenas_web.csv` | `OpinionesWebDB.dbo.Resena`, `stg.ResenaWeb`, `fact.Opinion` | Fuente 2. Se valida cliente, producto, fecha y rating. |
| `comentarios_sociales.csv` | `stg.ComentarioSocial`, `fact.Opinion` | Fuente 3. Cliente vacio se asigna al cliente `SIN_CLIENTE`. |
| `fuentes.csv` | `etl.Carga` | Catalogo de 100 cargas historicas, con tipo de fuente y fecha. |

Los identificadores `C007` y `P016` de las resenas y comentarios se normalizan a los IDs
numericos del catalogo de clientes y productos. En staging se conserva el formato original
`C007` y `P016`.

## 4. Reglas de validacion

- Campos obligatorios y limpieza con `Trim`.
- Longitudes maximas segun el `VARCHAR` o `NVARCHAR` de la tabla.
- Nombres que no sean solo numeros o simbolos.
- Correos con formato valido y unicos.
- Fechas con formato `yyyy-MM-dd` dentro del calendario 2020 a 2030.
- Enteros dentro del rango permitido, por ejemplo calificacion de 1 a 5.
- Clasificacion permitida: Positiva, Neutra o Negativa.
- Consistencia entre clasificacion y puntaje en las encuestas.
- Duplicados de PK y campos unicos mediante `HashSet`, sin consultar la base fila por fila.
- Integridad referencial en memoria contra los `HashSet` de clientes y productos.
- Errores capturados por registro, con motivo exacto, contador de rechazados y continuidad
  del proceso.

## 5. Carga de OpinionesWebDB

El CSV de productos no trae codigo ni precio. El codigo se genera como `P001`, `P002` hasta
`P200`, que coincide con los identificadores `P016` de las resenas.

El precio se calcula con una regla configurable en `config/precios_categorias.json`:

```text
precio = base + ((IdProducto * 37) % 100) / 100 * variacion
```

| Categoria | Base | Variacion |
|---|---:|---:|
| Juguetes | 19.99 | 10.00 |
| Electrónica | 149.99 | 100.00 |
| Ropa | 29.99 | 20.00 |
| Hogar | 49.99 | 30.00 |
| Deportes | 39.99 | 25.00 |

La carga inserta 5 categorias, 200 productos, 500 clientes y 200 resenas. Las resenas usan
el numero de `IdReview` como `IdResena`: `W0001` se convierte en 1 y `W0200` en 200. La
insercion se hace con `IDENTITY_INSERT` y una verificacion previa, de modo que repetir el
proceso no duplica resenas y el modelo de la tabla no cambia.

Los objetos de esta base estan en `05_opiniones_web_objetos.sql` y las consultas de
validacion en `06_consultas_web.sql`.

## 6. Carga transaccional de OpinionesDW

1. Se abre una transaccion explicita.
2. Se registran las cargas en `etl.Carga`.
3. Se sincroniza el diccionario `etl.PalabraClave`.
4. Se cargan categorias, clientes y productos.
5. Se cargan las encuestas, resenas web y comentarios sociales, en ese orden.
6. Se insertan los rechazos en `etl.Rechazo`.
7. Se cargan categorias, productos, clientes y resenas en `OpinionesWebDB`.
8. Se actualizan los contadores de cada carga.
9. Se recalcula `fact.ResumenSatisfaccion`.
10. Se confirma la transaccion. Ante un error critico se revierte.

La tabla `fact.Opinion` tiene la restriccion unica `(IdFuente, IdOpinionOrigen)`, por lo que
volver a ejecutar el proceso no duplica opiniones. Las dimensiones se cargan con procedimientos
de tipo upsert.

## 7. Resultado de la validacion previa

La ejecucion en modo de validacion, sin base de datos, produce:

| Tabla | Procesados | Insertados | Rechazados | Duplicados |
|---|---:|---:|---:|---:|
| Clientes | 500 | 500 | 0 | 0 |
| Productos | 200 | 200 | 0 | 0 |
| Categorias | 5 | 5 | 0 | 0 |
| Encuestas | 500 | 6 | 494 | 0 |
| Resenas web | 200 | 200 | 0 | 0 |
| Comentarios sociales | 200 | 200 | 0 | 0 |
| Fuentes | 100 | 100 | 0 | 0 |
| Total | 1705 | 1211 | 494 | 0 |

Se insertan 406 opiniones en `fact.Opinion`: 6 encuestas, 200 resenas web y 200 comentarios
sociales. Los 494 rechazos de encuestas corresponden a identificadores de cliente o producto
que no existen en los catalogos CSV; es el resultado esperado de la regla de integridad
referencial y queda registrado en `etl.Rechazo`.

## 8. Objetos SQL

El script `03_dw_etl_objetos.sql` crea:

- Procedimientos de control de cargas, dimensiones, staging, hechos, rechazos y palabras clave.
- Procedimiento `usp_RecalcularResumenSatisfaccion`.
- Vistas `vw_OpinionesDetalle`, `vw_ResumenProducto`, `vw_OpinionesPorFuente`,
  `vw_TendenciaMensual`, `vw_RechazosPorMotivo` y `vw_IntegridadReferencial`.

El script `04_consultas_validacion.sql` contiene las consultas de conteo, huerfanos,
duplicados, resumen por producto, rechazos, consistencia del resumen y comparacion
staging contra hechos.

El script `05_opiniones_web_objetos.sql` crea los procedimientos y las vistas de
`OpinionesWebDB`. El script `06_consultas_web.sql` valida esa base.

El script `00_script_completo.sql` reune `01`, `02`, `03` y `05` en un solo archivo para
una instalacion nueva.
