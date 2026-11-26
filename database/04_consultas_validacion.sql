/* Sistema de Analisis de Opiniones de Clientes
   Consultas de validacion de la carga ETL.
   Ejecutar despues de 03_dw_etl_objetos.sql y de ejecutar la aplicacion ETL. */

USE OpinionesDW;
GO

SET NOCOUNT ON;
GO

/* ------------------------------------------------------------
   1. Conteo de registros por tabla
   ------------------------------------------------------------ */
SELECT 'dim.Categoria' AS Tabla, COUNT(*) AS Registros FROM dim.Categoria
UNION ALL SELECT 'dim.Producto',        COUNT(*) FROM dim.Producto
UNION ALL SELECT 'dim.Cliente',         COUNT(*) FROM dim.Cliente
UNION ALL SELECT 'dim.Fecha',           COUNT(*) FROM dim.Fecha
UNION ALL SELECT 'dim.Fuente',          COUNT(*) FROM dim.Fuente
UNION ALL SELECT 'dim.Clasificacion',   COUNT(*) FROM dim.Clasificacion
UNION ALL SELECT 'stg.Cliente (ultima)', COUNT(*) FROM stg.Cliente
 WHERE IdCarga = (SELECT MAX(IdCarga) FROM etl.Carga WHERE Detalle LIKE 'Maestros:%')
UNION ALL SELECT 'stg.Producto (ultima)', COUNT(*) FROM stg.Producto
 WHERE IdCarga = (SELECT MAX(IdCarga) FROM etl.Carga WHERE Detalle LIKE 'Maestros:%')
UNION ALL SELECT 'stg.Encuesta (ultima)', COUNT(*) FROM stg.Encuesta
 WHERE IdCarga = (SELECT MAX(IdCarga) FROM etl.Carga WHERE Detalle LIKE 'Encuestas:%')
UNION ALL SELECT 'stg.ResenaWeb (ultima)', COUNT(*) FROM stg.ResenaWeb
 WHERE IdCarga = (SELECT MAX(IdCarga) FROM etl.Carga WHERE Detalle LIKE 'Resenas web:%')
UNION ALL SELECT 'stg.ComentarioSocial (ultima)', COUNT(*) FROM stg.ComentarioSocial
 WHERE IdCarga = (SELECT MAX(IdCarga) FROM etl.Carga WHERE Detalle LIKE 'Comentarios sociales:%')
UNION ALL SELECT 'fact.Opinion',        COUNT(*) FROM fact.Opinion
UNION ALL SELECT 'fact.ResumenSatisfaccion', COUNT(*) FROM fact.ResumenSatisfaccion
UNION ALL SELECT 'etl.Carga',           COUNT(*) FROM etl.Carga
UNION ALL SELECT 'etl.Rechazo',         COUNT(*) FROM etl.Rechazo
UNION ALL SELECT 'etl.PalabraClave',    COUNT(*) FROM etl.PalabraClave
ORDER BY Tabla;
GO

/* ------------------------------------------------------------
   2. Opiniones cargadas por fuente y clasificacion
   ------------------------------------------------------------ */
SELECT f.Codigo AS Fuente,
       f.Nombre AS Descripcion,
       cla.Codigo AS Clasificacion,
       cla.Nombre AS DescripcionClasificacion,
       COUNT(*) AS Opiniones
  FROM fact.Opinion o
  INNER JOIN dim.Fuente f          ON f.IdFuente = o.IdFuente
  INNER JOIN dim.Clasificacion cla ON cla.IdClasificacion = o.IdClasificacion
 GROUP BY f.Codigo, f.Nombre, cla.Codigo, cla.Nombre
 ORDER BY f.Codigo, cla.Codigo;
GO

/* ------------------------------------------------------------
   3. Registros huerfanos: ninguna opinion debe quedar sin
      producto, cliente, fecha, fuente, clasificacion o carga.
      Todos los conteos deben dar 0.
   ------------------------------------------------------------ */
SELECT * FROM dbo.vw_IntegridadReferencial;
GO

SELECT o.OpinionKey, o.IdFuente, o.IdOpinionOrigen,
       o.ProductoKey, o.ClienteKey, o.FechaKey, o.IdCarga
  FROM fact.Opinion o
  LEFT JOIN dim.Producto p        ON p.ProductoKey = o.ProductoKey
  LEFT JOIN dim.Cliente c         ON c.ClienteKey = o.ClienteKey
  LEFT JOIN dim.Fecha f           ON f.FechaKey = o.FechaKey
  LEFT JOIN dim.Fuente fu         ON fu.IdFuente = o.IdFuente
  LEFT JOIN dim.Clasificacion cla ON cla.IdClasificacion = o.IdClasificacion
  LEFT JOIN etl.Carga ca          ON ca.IdCarga = o.IdCarga
 WHERE p.ProductoKey IS NULL
    OR c.ClienteKey IS NULL
    OR f.FechaKey IS NULL
    OR fu.IdFuente IS NULL
    OR cla.IdClasificacion IS NULL
    OR ca.IdCarga IS NULL;
GO

/* ------------------------------------------------------------
   4. Duplicados de claves primarias y de origen.
      Ninguna consulta debe devolver filas.
   ------------------------------------------------------------ */
SELECT 'fact.Opinion' AS Tabla,
       CONCAT(IdFuente, '|', IdOpinionOrigen) AS Clave,
       COUNT(*) AS Repeticiones
  FROM fact.Opinion
 GROUP BY IdFuente, IdOpinionOrigen
HAVING COUNT(*) > 1
UNION ALL
SELECT 'dim.Producto', IdProductoOrigen, COUNT(*)
  FROM dim.Producto
 GROUP BY IdProductoOrigen
HAVING COUNT(*) > 1
UNION ALL
SELECT 'dim.Cliente', IdClienteOrigen, COUNT(*)
  FROM dim.Cliente
 GROUP BY IdClienteOrigen
HAVING COUNT(*) > 1
UNION ALL
SELECT 'dim.Categoria', Nombre, COUNT(*)
  FROM dim.Categoria
 GROUP BY Nombre
HAVING COUNT(*) > 1;
GO

/* ------------------------------------------------------------
   5. Resumen por producto: conteos, promedio y porcentaje de
      satisfaccion. Es la consulta principal para el reporte.
   ------------------------------------------------------------ */
SELECT TOP (20) *
  FROM dbo.vw_ResumenProducto
 ORDER BY TotalOpiniones DESC, Producto;
GO

SELECT COUNT(*) AS ProductosConOpiniones,
       SUM(TotalOpiniones) AS OpinionesTotales,
       CAST(AVG(PorcentajeSatisfaccion) AS DECIMAL(5,2)) AS PromedioSatisfaccion
  FROM dbo.vw_ResumenProducto;
GO

/* ------------------------------------------------------------
   6. Rechazos: total, motivos y muestra de los ultimos casos.
   ------------------------------------------------------------ */
SELECT COUNT(*) AS TotalRechazos FROM etl.Rechazo;
GO

SELECT Motivo, COUNT(*) AS Cantidad
  FROM etl.Rechazo
 GROUP BY Motivo
 ORDER BY Cantidad DESC;
GO

SELECT TOP (20) IdRechazo, IdCarga, IdRegistroOrigen, Motivo, FechaRechazo
  FROM etl.Rechazo
 ORDER BY IdRechazo DESC;
GO

/* ------------------------------------------------------------
   7. Consistencia entre fact.Opinion y fact.ResumenSatisfaccion.
      La columna Diferencia debe dar 0.
   ------------------------------------------------------------ */
SELECT COUNT(*) AS GruposConDiferencia
  FROM
  (
      SELECT r.ProductoKey, r.FechaKey, r.IdFuente, r.TotalOpiniones,
             (SELECT COUNT(*)
                FROM fact.Opinion o
               WHERE o.ProductoKey = r.ProductoKey
                 AND o.FechaKey    = r.FechaKey
                 AND o.IdFuente    = r.IdFuente) AS TotalReal
        FROM fact.ResumenSatisfaccion r
  ) x
 WHERE TotalOpiniones <> TotalReal;
GO

/* ------------------------------------------------------------
   8. Comparacion staging contra hechos por fuente.
      Para las encuestas, stg.Encuesta debe coincidir con las
      opiniones de la fuente CSV que quedaron validas.
   ------------------------------------------------------------ */
DECLARE @CargaEncuestas INT = (SELECT MAX(IdCarga) FROM etl.Carga WHERE Detalle LIKE 'Encuestas:%');
DECLARE @CargaWeb       INT = (SELECT MAX(IdCarga) FROM etl.Carga WHERE Detalle LIKE 'Resenas web:%');
DECLARE @CargaSocial    INT = (SELECT MAX(IdCarga) FROM etl.Carga WHERE Detalle LIKE 'Comentarios sociales:%');

SELECT 'stg.Encuesta (ultima)' AS Origen, COUNT(*) AS Registros
  FROM stg.Encuesta WHERE IdCarga = @CargaEncuestas
UNION ALL SELECT 'fact CSV',       COUNT(*) FROM fact.Opinion WHERE IdFuente = 1
UNION ALL SELECT 'stg.ResenaWeb (ultima)',  COUNT(*) FROM stg.ResenaWeb WHERE IdCarga = @CargaWeb
UNION ALL SELECT 'fact Web',       COUNT(*) FROM fact.Opinion WHERE IdFuente = 2
UNION ALL SELECT 'stg.ComentarioSocial (ultima)', COUNT(*) FROM stg.ComentarioSocial WHERE IdCarga = @CargaSocial
UNION ALL SELECT 'fact Social',    COUNT(*) FROM fact.Opinion WHERE IdFuente = 3;
GO

/* ------------------------------------------------------------
   9. Bitacora de cargas: leidos, insertados, duplicados y
      rechazados por ejecucion.
   ------------------------------------------------------------ */
SELECT IdCarga, IdFuente, Estado, FechaInicio, FechaFin,
       RegistrosLeidos, RegistrosInsertados, RegistrosDuplicados,
       RegistrosRechazados, Detalle
  FROM etl.Carga
 WHERE Detalle NOT LIKE 'Carga historica%'
 ORDER BY IdCarga;
GO

SELECT COUNT(*) AS TotalCargasHistoricas
  FROM etl.Carga
 WHERE Detalle LIKE 'Carga historica%';
GO
