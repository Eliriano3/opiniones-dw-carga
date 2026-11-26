/* Sistema de Analisis de Opiniones de Clientes
   Objetos del ETL: procedimientos almacenados, vistas y soporte de clasificacion.
   Ejecutar despues de 02_dw_opiniones.sql. */

USE OpinionesDW;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ============================================================
   Procedimientos de control de cargas
   ============================================================ */

CREATE OR ALTER PROCEDURE etl.usp_Carga_Insertar
    @IdFuente TINYINT,
    @Detalle  NVARCHAR(500) = NULL,
    @IdCarga  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO etl.Carga (IdFuente, Estado, Detalle)
    VALUES (@IdFuente, 'EN_PROCESO', @Detalle);

    SET @IdCarga = CAST(SCOPE_IDENTITY() AS INT);
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_Carga_Historica_Insertar
    @IdFuente   TINYINT,
    @FechaCarga DATETIME2(0),
    @Detalle    NVARCHAR(500) = NULL,
    @IdCarga    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO etl.Carga
        (IdFuente, FechaInicio, FechaFin, Estado, MarcaAguaHasta, Detalle)
    VALUES
        (@IdFuente, @FechaCarga, @FechaCarga, 'COMPLETADA', @FechaCarga, @Detalle);

    SET @IdCarga = CAST(SCOPE_IDENTITY() AS INT);
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_Carga_Actualizar
    @IdCarga      INT,
    @Leidos       INT,
    @Insertados   INT,
    @Duplicados   INT,
    @Rechazados   INT,
    @Estado       VARCHAR(12),
    @Detalle      NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE etl.Carga
       SET FechaFin             = SYSDATETIME(),
           RegistrosLeidos      = @Leidos,
           RegistrosInsertados  = @Insertados,
           RegistrosDuplicados  = @Duplicados,
           RegistrosRechazados  = @Rechazados,
           Estado               = @Estado,
           Detalle              = COALESCE(@Detalle, Detalle)
     WHERE IdCarga = @IdCarga;
END;
GO

/* ============================================================
   Procedimientos de dimensiones
   ============================================================ */

CREATE OR ALTER PROCEDURE etl.usp_Categoria_ObtenerOInsertar
    @Nombre      NVARCHAR(100),
    @IdCategoria INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @IdCategoria = IdCategoria
      FROM dim.Categoria
     WHERE Nombre = @Nombre;

    IF @IdCategoria IS NULL
    BEGIN
        INSERT INTO dim.Categoria (Nombre) VALUES (@Nombre);
        SET @IdCategoria = CAST(SCOPE_IDENTITY() AS INT);
    END
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_Producto_Upsert
    @IdProductoOrigen   VARCHAR(50),
    @Nombre             NVARCHAR(200),
    @NombreNormalizado  NVARCHAR(200),
    @IdCategoria        INT,
    @ProductoKey        INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @ProductoKey = ProductoKey
      FROM dim.Producto
     WHERE IdProductoOrigen = @IdProductoOrigen;

    IF @ProductoKey IS NULL
    BEGIN
        INSERT INTO dim.Producto
            (IdProductoOrigen, Nombre, NombreNormalizado, IdCategoria, Activo)
        VALUES
            (@IdProductoOrigen, @Nombre, @NombreNormalizado, @IdCategoria, 1);

        SET @ProductoKey = CAST(SCOPE_IDENTITY() AS INT);
    END
    ELSE
    BEGIN
        UPDATE dim.Producto
           SET Nombre            = @Nombre,
               NombreNormalizado = @NombreNormalizado,
               IdCategoria       = @IdCategoria,
               FechaActualizacion = SYSDATETIME()
         WHERE ProductoKey = @ProductoKey;
    END
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_Cliente_Upsert
    @IdClienteOrigen VARCHAR(50),
    @Nombre          NVARCHAR(150),
    @Email           NVARCHAR(150) = NULL,
    @Pais            NVARCHAR(60)  = NULL,
    @ClienteKey      INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @ClienteKey = ClienteKey
      FROM dim.Cliente
     WHERE IdClienteOrigen = @IdClienteOrigen;

    IF @ClienteKey IS NULL
    BEGIN
        INSERT INTO dim.Cliente
            (IdClienteOrigen, Nombre, Email, Pais)
        VALUES
            (@IdClienteOrigen, @Nombre, @Email, @Pais);

        SET @ClienteKey = CAST(SCOPE_IDENTITY() AS INT);
    END
    ELSE
    BEGIN
        UPDATE dim.Cliente
           SET Nombre = @Nombre,
               Email  = @Email,
               Pais   = @Pais,
               FechaActualizacion = SYSDATETIME()
         WHERE ClienteKey = @ClienteKey;
    END
END;
GO

/* ============================================================
   Procedimientos de hechos y rechazos
   ============================================================ */

CREATE OR ALTER PROCEDURE etl.usp_Opinion_Insertar
    @IdFuente            TINYINT,
    @IdOpinionOrigen     VARCHAR(50),
    @ProductoKey         INT,
    @ClienteKey          INT,
    @FechaKey            INT,
    @IdClasificacion     TINYINT,
    @FechaOpinion        DATETIME2(0),
    @Comentario          NVARCHAR(2000),
    @Calificacion        TINYINT = NULL,
    @PuntajeSentimiento  DECIMAL(5,2) = NULL,
    @Plataforma          NVARCHAR(30) = NULL,
    @IdCarga             INT,
    @Insertado           BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @Insertado = 0;

    IF NOT EXISTS
    (
        SELECT 1
          FROM fact.Opinion
         WHERE IdFuente = @IdFuente
           AND IdOpinionOrigen = @IdOpinionOrigen
    )
    BEGIN
        INSERT INTO fact.Opinion
            (IdFuente, IdOpinionOrigen, ProductoKey, ClienteKey, FechaKey,
             IdClasificacion, FechaOpinion, Comentario, Calificacion,
             PuntajeSentimiento, Plataforma, IdCarga)
        VALUES
            (@IdFuente, @IdOpinionOrigen, @ProductoKey, @ClienteKey, @FechaKey,
             @IdClasificacion, @FechaOpinion, @Comentario, @Calificacion,
             @PuntajeSentimiento, @Plataforma, @IdCarga);

        SET @Insertado = 1;
    END
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_Rechazo_Insertar
    @IdCarga          INT,
    @IdRegistroOrigen NVARCHAR(50) = NULL,
    @Motivo           NVARCHAR(200),
    @RegistroOriginal NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO etl.Rechazo
        (IdCarga, IdRegistroOrigen, Motivo, RegistroOriginal)
    VALUES
        (@IdCarga, @IdRegistroOrigen, @Motivo, @RegistroOriginal);
END;
GO

/* ============================================================
   Procedimientos de staging
   ============================================================ */

CREATE OR ALTER PROCEDURE etl.usp_Staging_Cliente_Insertar
    @IdCarga    INT,
    @IdCliente  NVARCHAR(50),
    @Nombre     NVARCHAR(300),
    @Email      NVARCHAR(300),
    @Pais       NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO stg.Cliente (IdCarga, IdCliente, Nombre, Email, Pais)
    VALUES (@IdCarga, @IdCliente, @Nombre, @Email, @Pais);
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_Staging_Producto_Insertar
    @IdCarga    INT,
    @IdProducto NVARCHAR(50),
    @Nombre     NVARCHAR(300),
    @Categoria  NVARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO stg.Producto (IdCarga, IdProducto, Nombre, Categoria)
    VALUES (@IdCarga, @IdProducto, @Nombre, @Categoria);
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_Staging_Encuesta_Insertar
    @IdCarga         INT,
    @NombreArchivo   NVARCHAR(260),
    @NumeroLinea     INT,
    @IdOpinion       NVARCHAR(50),
    @IdCliente       NVARCHAR(50),
    @IdProducto      NVARCHAR(50),
    @Fecha           NVARCHAR(50),
    @Comentario      NVARCHAR(MAX),
    @Clasificacion   NVARCHAR(50),
    @Puntaje         NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO stg.Encuesta
        (IdCarga, NombreArchivo, NumeroLinea, IdOpinion, IdCliente, IdProducto,
         Fecha, Comentario, Clasificacion, PuntajeSatisfaccion)
    VALUES
        (@IdCarga, @NombreArchivo, @NumeroLinea, @IdOpinion, @IdCliente, @IdProducto,
         @Fecha, @Comentario, @Clasificacion, @Puntaje);
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_Staging_ResenaWeb_Insertar
    @IdCarga      INT,
    @IdResena     NVARCHAR(50),
    @IdCliente    NVARCHAR(50),
    @IdProducto   NVARCHAR(50),
    @Fecha        NVARCHAR(50),
    @Calificacion NVARCHAR(20),
    @Titulo       NVARCHAR(300) = NULL,
    @Comentario   NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO stg.ResenaWeb
        (IdCarga, IdResena, IdCliente, IdProducto, Fecha, Calificacion,
         Titulo, Comentario)
    VALUES
        (@IdCarga, @IdResena, @IdCliente, @IdProducto, @Fecha, @Calificacion,
         @Titulo, @Comentario);
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_Staging_ComentarioSocial_Insertar
    @IdCarga      INT,
    @IdComentario NVARCHAR(50),
    @IdCliente    NVARCHAR(50) = NULL,
    @IdProducto   NVARCHAR(50),
    @Plataforma   NVARCHAR(50),
    @Fecha        NVARCHAR(50),
    @Comentario   NVARCHAR(MAX),
    @JsonOriginal NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO stg.ComentarioSocial
        (IdCarga, IdComentario, IdCliente, IdProducto, Plataforma, Fecha,
         Comentario, JsonOriginal)
    VALUES
        (@IdCarga, @IdComentario, @IdCliente, @IdProducto, @Plataforma, @Fecha,
         @Comentario, @JsonOriginal);
END;
GO

/* ============================================================
   Diccionario de clasificacion
   ============================================================ */

CREATE OR ALTER PROCEDURE etl.usp_PalabraClave_Upsert
    @Termino        NVARCHAR(50),
    @IdClasificacion TINYINT,
    @Peso           DECIMAL(3,1),
    @Activa         BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM etl.PalabraClave WHERE Termino = @Termino)
        UPDATE etl.PalabraClave
           SET IdClasificacion = @IdClasificacion,
               Peso            = @Peso,
               Activa          = @Activa
         WHERE Termino = @Termino;
    ELSE
        INSERT INTO etl.PalabraClave (Termino, IdClasificacion, Peso, Activa)
        VALUES (@Termino, @IdClasificacion, @Peso, @Activa);
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_PalabraClave_Listar
AS
BEGIN
    SET NOCOUNT ON;

    SELECT Termino, IdClasificacion, Peso
      FROM etl.PalabraClave
     WHERE Activa = 1
     ORDER BY LEN(Termino) DESC, Termino;
END;
GO

/* ============================================================
   Recalculo de fact.ResumenSatisfaccion
   ============================================================ */

CREATE OR ALTER PROCEDURE etl.usp_RecalcularResumenSatisfaccion
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Agg AS
    (
        SELECT o.ProductoKey,
               o.FechaKey,
               o.IdFuente,
               COUNT(*) AS TotalOpiniones,
               SUM(CASE WHEN c.Codigo = 'POS' THEN 1 ELSE 0 END) AS Positivas,
               SUM(CASE WHEN c.Codigo = 'NEU' THEN 1 ELSE 0 END) AS Neutras,
               SUM(CASE WHEN c.Codigo = 'NEG' THEN 1 ELSE 0 END) AS Negativas,
               CAST(AVG(CAST(o.Calificacion AS DECIMAL(4,2))) AS DECIMAL(4,2)) AS CalificacionPromedio
          FROM fact.Opinion o
          INNER JOIN dim.Clasificacion c
                  ON c.IdClasificacion = o.IdClasificacion
         GROUP BY o.ProductoKey, o.FechaKey, o.IdFuente
    )
    MERGE fact.ResumenSatisfaccion AS t
    USING Agg AS s
       ON t.ProductoKey = s.ProductoKey
      AND t.FechaKey    = s.FechaKey
      AND t.IdFuente    = s.IdFuente
    WHEN MATCHED THEN
        UPDATE SET TotalOpiniones       = s.TotalOpiniones,
                   Positivas            = s.Positivas,
                   Neutras              = s.Neutras,
                   Negativas            = s.Negativas,
                   CalificacionPromedio = s.CalificacionPromedio,
                   FechaCalculo         = SYSDATETIME()
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (ProductoKey, FechaKey, IdFuente, TotalOpiniones,
                Positivas, Neutras, Negativas, CalificacionPromedio, FechaCalculo)
        VALUES (s.ProductoKey, s.FechaKey, s.IdFuente, s.TotalOpiniones,
                s.Positivas, s.Neutras, s.Negativas, s.CalificacionPromedio, SYSDATETIME())
    WHEN NOT MATCHED BY SOURCE THEN
        DELETE;
END;
GO

/* ============================================================
   Vistas para reportes y validacion
   ============================================================ */

CREATE OR ALTER VIEW dbo.vw_OpinionesDetalle
AS
SELECT o.OpinionKey,
       f.IdFuente,
       f.Codigo            AS FuenteCodigo,
       f.Nombre            AS Fuente,
       o.IdOpinionOrigen,
       p.IdProductoOrigen,
       p.Nombre            AS Producto,
       cat.Nombre          AS Categoria,
       cl.IdClienteOrigen,
       cl.Nombre           AS Cliente,
       d.Fecha,
       o.FechaOpinion,
       o.IdClasificacion,
       cla.Codigo          AS ClasificacionCodigo,
       cla.Nombre          AS Clasificacion,
       o.Calificacion,
       o.PuntajeSentimiento,
       o.Comentario,
       o.Plataforma,
       o.IdCarga,
       o.FechaCarga
  FROM fact.Opinion o
  INNER JOIN dim.Fuente f        ON f.IdFuente = o.IdFuente
  INNER JOIN dim.Producto p      ON p.ProductoKey = o.ProductoKey
  INNER JOIN dim.Categoria cat   ON cat.IdCategoria = p.IdCategoria
  INNER JOIN dim.Cliente cl      ON cl.ClienteKey = o.ClienteKey
  INNER JOIN dim.Fecha d         ON d.FechaKey = o.FechaKey
  INNER JOIN dim.Clasificacion cla ON cla.IdClasificacion = o.IdClasificacion;
GO

CREATE OR ALTER VIEW dbo.vw_ResumenProducto
AS
SELECT p.IdProductoOrigen,
       p.Nombre AS Producto,
       cat.Nombre AS Categoria,
       COUNT(*) AS TotalOpiniones,
       SUM(CASE WHEN cla.Codigo = 'POS' THEN 1 ELSE 0 END) AS Positivas,
       SUM(CASE WHEN cla.Codigo = 'NEU' THEN 1 ELSE 0 END) AS Neutras,
       SUM(CASE WHEN cla.Codigo = 'NEG' THEN 1 ELSE 0 END) AS Negativas,
       CAST(SUM(CASE WHEN cla.Codigo = 'POS' THEN 1 ELSE 0 END) * 100.0
            / NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) AS PorcentajeSatisfaccion,
       CAST(AVG(CAST(o.Calificacion AS DECIMAL(4,2))) AS DECIMAL(4,2)) AS CalificacionPromedio
  FROM fact.Opinion o
  INNER JOIN dim.Producto p      ON p.ProductoKey = o.ProductoKey
  INNER JOIN dim.Categoria cat   ON cat.IdCategoria = p.IdCategoria
  INNER JOIN dim.Clasificacion cla ON cla.IdClasificacion = o.IdClasificacion
 GROUP BY p.IdProductoOrigen, p.Nombre, cat.Nombre;
GO

CREATE OR ALTER VIEW dbo.vw_OpinionesPorFuente
AS
SELECT f.IdFuente,
       f.Codigo,
       f.Nombre AS Fuente,
       COUNT(*) AS TotalOpiniones,
       SUM(CASE WHEN cla.Codigo = 'POS' THEN 1 ELSE 0 END) AS Positivas,
       SUM(CASE WHEN cla.Codigo = 'NEU' THEN 1 ELSE 0 END) AS Neutras,
       SUM(CASE WHEN cla.Codigo = 'NEG' THEN 1 ELSE 0 END) AS Negativas,
       CAST(SUM(CASE WHEN cla.Codigo = 'POS' THEN 1 ELSE 0 END) * 100.0
            / NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) AS PorcentajeSatisfaccion
  FROM fact.Opinion o
  INNER JOIN dim.Fuente f        ON f.IdFuente = o.IdFuente
  INNER JOIN dim.Clasificacion cla ON cla.IdClasificacion = o.IdClasificacion
 GROUP BY f.IdFuente, f.Codigo, f.Nombre;
GO

CREATE OR ALTER VIEW dbo.vw_TendenciaMensual
AS
SELECT d.Anio,
       d.Mes,
       d.NombreMes,
       f.Codigo AS FuenteCodigo,
       COUNT(*) AS TotalOpiniones,
       SUM(CASE WHEN cla.Codigo = 'POS' THEN 1 ELSE 0 END) AS Positivas,
       SUM(CASE WHEN cla.Codigo = 'NEG' THEN 1 ELSE 0 END) AS Negativas,
       CAST(SUM(CASE WHEN cla.Codigo = 'POS' THEN 1 ELSE 0 END) * 100.0
            / NULLIF(COUNT(*), 0) AS DECIMAL(5,2)) AS PorcentajeSatisfaccion
  FROM fact.Opinion o
  INNER JOIN dim.Fecha d         ON d.FechaKey = o.FechaKey
  INNER JOIN dim.Fuente f        ON f.IdFuente = o.IdFuente
  INNER JOIN dim.Clasificacion cla ON cla.IdClasificacion = o.IdClasificacion
 GROUP BY d.Anio, d.Mes, d.NombreMes, f.Codigo;
GO

CREATE OR ALTER VIEW dbo.vw_RechazosPorMotivo
AS
SELECT Motivo, COUNT(*) AS Total
  FROM etl.Rechazo
 GROUP BY Motivo;
GO

CREATE OR ALTER VIEW dbo.vw_IntegridadReferencial
AS
SELECT 'fact.Opinion -> dim.Producto' AS Relacion,
       COUNT(*) AS Huerfanos
  FROM fact.Opinion o
  LEFT JOIN dim.Producto p ON p.ProductoKey = o.ProductoKey
 WHERE p.ProductoKey IS NULL
UNION ALL
SELECT 'fact.Opinion -> dim.Cliente', COUNT(*)
  FROM fact.Opinion o
  LEFT JOIN dim.Cliente c ON c.ClienteKey = o.ClienteKey
 WHERE c.ClienteKey IS NULL
UNION ALL
SELECT 'fact.Opinion -> dim.Fecha', COUNT(*)
  FROM fact.Opinion o
  LEFT JOIN dim.Fecha f ON f.FechaKey = o.FechaKey
 WHERE f.FechaKey IS NULL
UNION ALL
SELECT 'fact.Opinion -> dim.Fuente', COUNT(*)
  FROM fact.Opinion o
  LEFT JOIN dim.Fuente f ON f.IdFuente = o.IdFuente
 WHERE f.IdFuente IS NULL
UNION ALL
SELECT 'fact.Opinion -> dim.Clasificacion', COUNT(*)
  FROM fact.Opinion o
  LEFT JOIN dim.Clasificacion c ON c.IdClasificacion = o.IdClasificacion
 WHERE c.IdClasificacion IS NULL
UNION ALL
SELECT 'fact.Opinion -> etl.Carga', COUNT(*)
  FROM fact.Opinion o
  LEFT JOIN etl.Carga c ON c.IdCarga = o.IdCarga
 WHERE c.IdCarga IS NULL
UNION ALL
SELECT 'fact.ResumenSatisfaccion -> dim.Producto', COUNT(*)
  FROM fact.ResumenSatisfaccion r
  LEFT JOIN dim.Producto p ON p.ProductoKey = r.ProductoKey
 WHERE p.ProductoKey IS NULL
UNION ALL
SELECT 'fact.ResumenSatisfaccion -> dim.Fecha', COUNT(*)
  FROM fact.ResumenSatisfaccion r
  LEFT JOIN dim.Fecha f ON f.FechaKey = r.FechaKey
 WHERE f.FechaKey IS NULL
UNION ALL
SELECT 'fact.ResumenSatisfaccion -> dim.Fuente', COUNT(*)
  FROM fact.ResumenSatisfaccion r
  LEFT JOIN dim.Fuente f ON f.IdFuente = r.IdFuente
 WHERE f.IdFuente IS NULL;
GO
