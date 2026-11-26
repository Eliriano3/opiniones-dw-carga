/* Sistema de Analisis de Opiniones de Clientes
   Objetos de la base transaccional OpinionesWebDB.
   Ejecutar despues de 01_fuente_resenas_web.sql. */

USE OpinionesWebDB;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Categoria_ObtenerOInsertar
    @Nombre      NVARCHAR(100),
    @IdCategoria INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @IdCategoria = IdCategoria
      FROM dbo.Categoria
     WHERE Nombre = @Nombre;

    IF @IdCategoria IS NULL
    BEGIN
        INSERT INTO dbo.Categoria (Nombre) VALUES (@Nombre);
        SET @IdCategoria = CAST(SCOPE_IDENTITY() AS INT);
    END
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Producto_ObtenerOInsertar
    @Codigo      VARCHAR(20),
    @Nombre      NVARCHAR(200),
    @IdCategoria INT,
    @Precio      DECIMAL(12,2),
    @Activo      BIT = 1,
    @IdProducto  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @IdProducto = IdProducto
      FROM dbo.Producto
     WHERE Codigo = @Codigo;

    IF @IdProducto IS NULL
    BEGIN
        INSERT INTO dbo.Producto (Codigo, Nombre, IdCategoria, Precio, Activo)
        VALUES (@Codigo, @Nombre, @IdCategoria, @Precio, @Activo);

        SET @IdProducto = CAST(SCOPE_IDENTITY() AS INT);
    END
    ELSE
    BEGIN
        UPDATE dbo.Producto
           SET Nombre      = @Nombre,
               IdCategoria = @IdCategoria,
               Precio      = @Precio,
               Activo      = @Activo
         WHERE IdProducto = @IdProducto;
    END
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Cliente_ObtenerOInsertar
    @Nombre    NVARCHAR(150),
    @Email     NVARCHAR(150),
    @Pais      NVARCHAR(60) = NULL,
    @IdCliente INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT @IdCliente = IdCliente
      FROM dbo.Cliente
     WHERE Email = @Email;

    IF @IdCliente IS NULL
    BEGIN
        INSERT INTO dbo.Cliente (Nombre, Email, Pais)
        VALUES (@Nombre, @Email, @Pais);

        SET @IdCliente = CAST(SCOPE_IDENTITY() AS INT);
    END
    ELSE
    BEGIN
        UPDATE dbo.Cliente
           SET Nombre = @Nombre,
               Pais   = @Pais
         WHERE IdCliente = @IdCliente;
    END
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Resena_Insertar
    @IdResena        INT,
    @IdCliente       INT,
    @IdProducto      INT,
    @Calificacion    TINYINT,
    @Titulo          NVARCHAR(150) = NULL,
    @Comentario      NVARCHAR(2000) = NULL,
    @FechaPublicacion DATETIME2(0),
    @Estado          CHAR(1) = 'P',
    @Insertado       BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @Insertado = 0;

    IF NOT EXISTS (SELECT 1 FROM dbo.Resena WHERE IdResena = @IdResena)
    BEGIN
        SET IDENTITY_INSERT dbo.Resena ON;

        BEGIN TRY
            INSERT INTO dbo.Resena
                (IdResena, IdCliente, IdProducto, Calificacion, Titulo,
                 Comentario, FechaPublicacion, Estado)
            VALUES
                (@IdResena, @IdCliente, @IdProducto, @Calificacion, @Titulo,
                 @Comentario, @FechaPublicacion, @Estado);

            SET @Insertado = 1;
        END TRY
        BEGIN CATCH
            SET IDENTITY_INSERT dbo.Resena OFF;
            THROW;
        END CATCH

        SET IDENTITY_INSERT dbo.Resena OFF;
    END
END;
GO

CREATE OR ALTER VIEW dbo.vw_ResenasDetalle
AS
SELECT r.IdResena,
       c.IdCliente,
       c.Nombre AS Cliente,
       c.Email,
       p.IdProducto,
       p.Codigo,
       p.Nombre AS Producto,
       cat.Nombre AS Categoria,
       r.Calificacion,
       r.Titulo,
       r.Comentario,
       r.FechaPublicacion,
       r.Estado
  FROM dbo.Resena r
  INNER JOIN dbo.Cliente c   ON c.IdCliente = r.IdCliente
  INNER JOIN dbo.Producto p  ON p.IdProducto = r.IdProducto
  INNER JOIN dbo.Categoria cat ON cat.IdCategoria = p.IdCategoria;
GO

CREATE OR ALTER VIEW dbo.vw_ProductosCategoria
AS
SELECT p.IdProducto,
       p.Codigo,
       p.Nombre AS Producto,
       p.Precio,
       p.Activo,
       c.IdCategoria,
       c.Nombre AS Categoria
  FROM dbo.Producto p
  INNER JOIN dbo.Categoria c ON c.IdCategoria = p.IdCategoria;
GO

CREATE OR ALTER VIEW dbo.vw_ResumenProducto
AS
SELECT p.IdProducto,
       p.Codigo,
       p.Nombre AS Producto,
       c.Nombre AS Categoria,
       p.Precio,
       COUNT(r.IdResena) AS TotalResenas,
       CAST(AVG(CAST(r.Calificacion AS DECIMAL(4,2))) AS DECIMAL(4,2)) AS CalificacionPromedio,
       SUM(CASE WHEN r.Calificacion >= 4 THEN 1 ELSE 0 END) AS Positivas,
       SUM(CASE WHEN r.Calificacion <= 2 THEN 1 ELSE 0 END) AS Negativas,
       CAST(SUM(CASE WHEN r.Calificacion >= 4 THEN 1 ELSE 0 END) * 100.0
            / NULLIF(COUNT(r.IdResena), 0) AS DECIMAL(5,2)) AS PorcentajeSatisfaccion
  FROM dbo.Producto p
  INNER JOIN dbo.Categoria c ON c.IdCategoria = p.IdCategoria
  LEFT JOIN dbo.Resena r     ON r.IdProducto = p.IdProducto
 GROUP BY p.IdProducto, p.Codigo, p.Nombre, c.Nombre, p.Precio;
GO

CREATE OR ALTER VIEW dbo.vw_ClientesSinResenas
AS
SELECT c.IdCliente, c.Nombre, c.Email, c.Pais, c.FechaRegistro
  FROM dbo.Cliente c
  LEFT JOIN dbo.Resena r ON r.IdCliente = c.IdCliente
 WHERE r.IdResena IS NULL;
GO

CREATE OR ALTER VIEW dbo.vw_ResenasPorEstado
AS
SELECT Estado, COUNT(*) AS Total
  FROM dbo.Resena
 GROUP BY Estado;
GO
