/* Sistema de Analisis de Opiniones de Clientes
   Consultas de validacion de OpinionesWebDB.
   Ejecutar despues de 05_opiniones_web_objetos.sql y de la carga. */

USE OpinionesWebDB;
GO

SET NOCOUNT ON;
GO

/* 1. Conteo de registros por tabla. */
SELECT 'dbo.Categoria' AS Tabla, COUNT(*) AS Registros FROM dbo.Categoria
UNION ALL SELECT 'dbo.Producto', COUNT(*) FROM dbo.Producto
UNION ALL SELECT 'dbo.Cliente',  COUNT(*) FROM dbo.Cliente
UNION ALL SELECT 'dbo.Resena',   COUNT(*) FROM dbo.Resena
ORDER BY Tabla;
GO

/* 2. Detalle de las ultimas resenas cargadas. */
SELECT TOP (20) *
  FROM dbo.vw_ResenasDetalle
 ORDER BY IdResena DESC;
GO

/* 3. Registros huerfanos. Todos los conteos deben dar 0. */
SELECT 'Resena -> Cliente' AS Relacion, COUNT(*) AS Huerfanos
  FROM dbo.Resena r
  LEFT JOIN dbo.Cliente c ON c.IdCliente = r.IdCliente
 WHERE c.IdCliente IS NULL
UNION ALL
SELECT 'Resena -> Producto', COUNT(*)
  FROM dbo.Resena r
  LEFT JOIN dbo.Producto p ON p.IdProducto = r.IdProducto
 WHERE p.IdProducto IS NULL
UNION ALL
SELECT 'Producto -> Categoria', COUNT(*)
  FROM dbo.Producto p
  LEFT JOIN dbo.Categoria c ON c.IdCategoria = p.IdCategoria
 WHERE c.IdCategoria IS NULL;
GO

/* 4. Duplicados de claves y campos unicos. */
SELECT 'dbo.Cliente.Email' AS Tabla, Email AS Clave, COUNT(*) AS Repeticiones
  FROM dbo.Cliente
 GROUP BY Email
HAVING COUNT(*) > 1
UNION ALL
SELECT 'dbo.Producto.Codigo', Codigo, COUNT(*)
  FROM dbo.Producto
 GROUP BY Codigo
HAVING COUNT(*) > 1
UNION ALL
SELECT 'dbo.Categoria.Nombre', Nombre, COUNT(*)
  FROM dbo.Categoria
 GROUP BY Nombre
HAVING COUNT(*) > 1
UNION ALL
SELECT 'dbo.Resena.IdResena', CAST(IdResena AS VARCHAR(20)), COUNT(*)
  FROM dbo.Resena
 GROUP BY IdResena
HAVING COUNT(*) > 1;
GO

/* 5. Resumen por producto. */
SELECT TOP (20) *
  FROM dbo.vw_ResumenProducto
 ORDER BY TotalResenas DESC, Producto;
GO

SELECT COUNT(*) AS ProductosConResenas,
       SUM(TotalResenas) AS ResenasTotales,
       CAST(SUM(Positivas) * 100.0 / NULLIF(SUM(TotalResenas), 0) AS DECIMAL(5,2))
           AS PorcentajeSatisfaccionGlobal,
       CAST(AVG(PorcentajeSatisfaccion) AS DECIMAL(5,2)) AS PromedioSatisfaccion
  FROM dbo.vw_ResumenProducto
 WHERE TotalResenas > 0;
GO

/* 6. Clientes sin resenas y resenas por estado. */
SELECT COUNT(*) AS ClientesSinResenas FROM dbo.vw_ClientesSinResenas;
GO

SELECT * FROM dbo.vw_ResenasPorEstado;
GO

/* 7. Rango de precios por categoria. */
SELECT Categoria,
       COUNT(*) AS Productos,
       MIN(Precio) AS PrecioMinimo,
       MAX(Precio) AS PrecioMaximo,
       CAST(AVG(Precio) AS DECIMAL(12,2)) AS PrecioPromedio
  FROM dbo.vw_ProductosCategoria
 GROUP BY Categoria
 ORDER BY Categoria;
GO
