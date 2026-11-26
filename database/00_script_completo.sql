/* Sistema de Analisis de Opiniones de Clientes
   Script completo de creacion de bases, tablas, restricciones,
   procedimientos almacenados y vistas.
   Ejecutar una sola vez en una instalacion nueva.
   ADVERTENCIA: los scripts 01 y 02 recrean las tablas y borran los datos existentes. */

-- ============================================================
-- 1. Base transaccional OpinionesWebDB
-- ============================================================
/* Sistema de Análisis de Opiniones de Clientes
   Base de datos fuente: reseñas del sitio web (OpinionesWebDB) */

IF DB_ID(N'OpinionesWebDB') IS NULL
    CREATE DATABASE OpinionesWebDB COLLATE Modern_Spanish_CI_AI;
GO

USE OpinionesWebDB;
GO

DROP TABLE IF EXISTS dbo.Resena;
DROP TABLE IF EXISTS dbo.Producto;
DROP TABLE IF EXISTS dbo.Cliente;
DROP TABLE IF EXISTS dbo.Categoria;
GO

CREATE TABLE dbo.Categoria (
    IdCategoria   INT            IDENTITY(1,1) NOT NULL,
    Nombre        NVARCHAR(100)  NOT NULL,
    CONSTRAINT PK_Categoria        PRIMARY KEY (IdCategoria),
    CONSTRAINT UQ_Categoria_Nombre UNIQUE (Nombre)
);
GO

CREATE TABLE dbo.Producto (
    IdProducto    INT            IDENTITY(1,1) NOT NULL,
    Codigo        VARCHAR(20)    NOT NULL,
    Nombre        NVARCHAR(200)  NOT NULL,
    IdCategoria   INT            NOT NULL,
    Precio        DECIMAL(12,2)  NOT NULL,
    Activo        BIT            NOT NULL CONSTRAINT DF_Producto_Activo DEFAULT (1),
    CONSTRAINT PK_Producto           PRIMARY KEY (IdProducto),
    CONSTRAINT UQ_Producto_Codigo    UNIQUE (Codigo),
    CONSTRAINT FK_Producto_Categoria FOREIGN KEY (IdCategoria) REFERENCES dbo.Categoria (IdCategoria),
    CONSTRAINT CK_Producto_Precio    CHECK (Precio >= 0)
);
GO

CREATE TABLE dbo.Cliente (
    IdCliente      INT            IDENTITY(1,1) NOT NULL,
    Nombre         NVARCHAR(150)  NOT NULL,
    Email          NVARCHAR(150)  NOT NULL,
    Pais           NVARCHAR(60)   NULL,
    FechaRegistro  DATETIME2(0)   NOT NULL CONSTRAINT DF_Cliente_FechaRegistro DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_Cliente       PRIMARY KEY (IdCliente),
    CONSTRAINT UQ_Cliente_Email UNIQUE (Email)
);
GO

CREATE TABLE dbo.Resena (
    IdResena         INT            IDENTITY(1,1) NOT NULL,
    IdCliente        INT            NOT NULL,
    IdProducto       INT            NOT NULL,
    Calificacion     TINYINT        NOT NULL,   -- 1 a 5 estrellas
    Titulo           NVARCHAR(150)  NULL,
    Comentario       NVARCHAR(2000) NULL,
    FechaPublicacion DATETIME2(0)   NOT NULL CONSTRAINT DF_Resena_Fecha DEFAULT (SYSDATETIME()),
    Estado           CHAR(1)        NOT NULL CONSTRAINT DF_Resena_Estado DEFAULT ('P'),  -- P = publicada, O = oculta
    CONSTRAINT PK_Resena              PRIMARY KEY (IdResena),
    CONSTRAINT FK_Resena_Cliente      FOREIGN KEY (IdCliente)  REFERENCES dbo.Cliente (IdCliente),
    CONSTRAINT FK_Resena_Producto     FOREIGN KEY (IdProducto) REFERENCES dbo.Producto (IdProducto),
    CONSTRAINT CK_Resena_Calificacion CHECK (Calificacion BETWEEN 1 AND 5),
    CONSTRAINT CK_Resena_Estado       CHECK (Estado IN ('P','O'))
);
GO

CREATE INDEX IX_Resena_FechaPublicacion ON dbo.Resena (FechaPublicacion) INCLUDE (Estado);
GO

-- ============================================================
-- 2. Base analitica OpinionesDW
-- ============================================================
/* Sistema de Análisis de Opiniones de Clientes
   Base de datos analítica (OpinionesDW)
   Esquemas: stg (staging), dim (dimensiones), fact (hechos), etl (control de cargas) */

IF DB_ID(N'OpinionesDW') IS NULL
    CREATE DATABASE OpinionesDW COLLATE Modern_Spanish_CI_AI;
GO

USE OpinionesDW;
GO

IF SCHEMA_ID(N'stg')  IS NULL EXEC (N'CREATE SCHEMA stg');
IF SCHEMA_ID(N'dim')  IS NULL EXEC (N'CREATE SCHEMA dim');
IF SCHEMA_ID(N'fact') IS NULL EXEC (N'CREATE SCHEMA fact');
IF SCHEMA_ID(N'etl')  IS NULL EXEC (N'CREATE SCHEMA etl');
GO

DROP TABLE IF EXISTS fact.ResumenSatisfaccion;
DROP TABLE IF EXISTS fact.Opinion;
DROP TABLE IF EXISTS etl.Rechazo;
DROP TABLE IF EXISTS etl.Carga;
DROP TABLE IF EXISTS etl.PalabraClave;
DROP TABLE IF EXISTS dim.Producto;
DROP TABLE IF EXISTS dim.Categoria;
DROP TABLE IF EXISTS dim.Cliente;
DROP TABLE IF EXISTS dim.Fecha;
DROP TABLE IF EXISTS dim.Clasificacion;
DROP TABLE IF EXISTS dim.Fuente;
DROP TABLE IF EXISTS stg.Encuesta;
DROP TABLE IF EXISTS stg.ResenaWeb;
DROP TABLE IF EXISTS stg.ComentarioSocial;
DROP TABLE IF EXISTS stg.Producto;
DROP TABLE IF EXISTS stg.Cliente;
GO

/* ---------------- Staging ---------------- */

CREATE TABLE stg.Encuesta (
    StgId                BIGINT         IDENTITY(1,1) NOT NULL,
    IdCarga              INT            NOT NULL,
    NombreArchivo        NVARCHAR(260)  NOT NULL,
    NumeroLinea          INT            NOT NULL,
    IdOpinion            NVARCHAR(50)   NULL,
    IdCliente            NVARCHAR(50)   NULL,
    IdProducto           NVARCHAR(50)   NULL,
    Fecha                NVARCHAR(50)   NULL,
    Comentario           NVARCHAR(MAX)  NULL,
    Clasificacion        NVARCHAR(50)   NULL,
    PuntajeSatisfaccion  NVARCHAR(20)   NULL,
    FechaExtraccion      DATETIME2(0)   NOT NULL CONSTRAINT DF_stgEncuesta_FechaExt DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_stgEncuesta PRIMARY KEY (StgId)
);

CREATE TABLE stg.ResenaWeb (
    StgId                BIGINT         IDENTITY(1,1) NOT NULL,
    IdCarga              INT            NOT NULL,
    IdResena             NVARCHAR(50)   NULL,
    IdCliente            NVARCHAR(50)   NULL,
    IdProducto           NVARCHAR(50)   NULL,
    Fecha                NVARCHAR(50)   NULL,
    Calificacion         NVARCHAR(20)   NULL,
    Titulo               NVARCHAR(300)  NULL,
    Comentario           NVARCHAR(MAX)  NULL,
    FechaExtraccion      DATETIME2(0)   NOT NULL CONSTRAINT DF_stgResenaWeb_FechaExt DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_stgResenaWeb PRIMARY KEY (StgId)
);

CREATE TABLE stg.ComentarioSocial (
    StgId                BIGINT         IDENTITY(1,1) NOT NULL,
    IdCarga              INT            NOT NULL,
    IdComentario         NVARCHAR(50)   NULL,
    IdCliente            NVARCHAR(50)   NULL,
    IdProducto           NVARCHAR(50)   NULL,
    Plataforma           NVARCHAR(50)   NULL,
    Fecha                NVARCHAR(50)   NULL,
    Comentario           NVARCHAR(MAX)  NULL,
    JsonOriginal         NVARCHAR(MAX)  NULL,
    FechaExtraccion      DATETIME2(0)   NOT NULL CONSTRAINT DF_stgComentarioSocial_FechaExt DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_stgComentarioSocial PRIMARY KEY (StgId)
);

CREATE TABLE stg.Producto (
    StgId                BIGINT         IDENTITY(1,1) NOT NULL,
    IdCarga              INT            NOT NULL,
    IdProducto           NVARCHAR(50)   NULL,
    Nombre               NVARCHAR(300)  NULL,
    Categoria            NVARCHAR(150)  NULL,
    FechaExtraccion      DATETIME2(0)   NOT NULL CONSTRAINT DF_stgProducto_FechaExt DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_stgProducto PRIMARY KEY (StgId)
);

CREATE TABLE stg.Cliente (
    StgId                BIGINT         IDENTITY(1,1) NOT NULL,
    IdCarga              INT            NOT NULL,
    IdCliente            NVARCHAR(50)   NULL,
    Nombre               NVARCHAR(300)  NULL,
    Email                NVARCHAR(300)  NULL,
    Pais                 NVARCHAR(100)  NULL,
    FechaExtraccion      DATETIME2(0)   NOT NULL CONSTRAINT DF_stgCliente_FechaExt DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_stgCliente PRIMARY KEY (StgId)
);
GO

/* ---------------- Dimensiones ---------------- */

CREATE TABLE dim.Fuente (
    IdFuente      TINYINT        NOT NULL,
    Codigo        VARCHAR(20)    NOT NULL,
    Nombre        NVARCHAR(100)  NOT NULL,
    TipoFuente    VARCHAR(5)     NOT NULL,
    Canal         NVARCHAR(50)   NOT NULL,
    Activa        BIT            NOT NULL CONSTRAINT DF_Fuente_Activa DEFAULT (1),
    CONSTRAINT PK_Fuente        PRIMARY KEY (IdFuente),
    CONSTRAINT UQ_Fuente_Codigo UNIQUE (Codigo),
    CONSTRAINT CK_Fuente_Tipo   CHECK (TipoFuente IN ('CSV','BD','API'))
);

CREATE TABLE dim.Clasificacion (
    IdClasificacion  TINYINT       NOT NULL,
    Codigo           CHAR(3)       NOT NULL,
    Nombre           NVARCHAR(20)  NOT NULL,
    Valor            SMALLINT      NOT NULL,
    CONSTRAINT PK_Clasificacion        PRIMARY KEY (IdClasificacion),
    CONSTRAINT UQ_Clasificacion_Codigo UNIQUE (Codigo),
    CONSTRAINT CK_Clasificacion_Valor  CHECK (Valor IN (-1, 0, 1))
);

CREATE TABLE dim.Fecha (
    FechaKey       INT           NOT NULL,   -- AAAAMMDD
    Fecha          DATE          NOT NULL,
    Anio           SMALLINT      NOT NULL,
    Trimestre      TINYINT       NOT NULL,
    Mes            TINYINT       NOT NULL,
    NombreMes      NVARCHAR(15)  NOT NULL,
    AnioMes        CHAR(7)       NOT NULL,   -- AAAA-MM
    SemanaISO      TINYINT       NOT NULL,
    DiaMes         TINYINT       NOT NULL,
    DiaSemana      TINYINT       NOT NULL,   -- 1 = lunes, 7 = domingo
    NombreDia      NVARCHAR(15)  NOT NULL,
    EsFinDeSemana  BIT           NOT NULL,
    CONSTRAINT PK_Fecha       PRIMARY KEY (FechaKey),
    CONSTRAINT UQ_Fecha_Fecha UNIQUE (Fecha)
);

CREATE TABLE dim.Categoria (
    IdCategoria  INT            IDENTITY(1,1) NOT NULL,
    Nombre       NVARCHAR(100)  NOT NULL,
    CONSTRAINT PK_Categoria        PRIMARY KEY (IdCategoria),
    CONSTRAINT UQ_Categoria_Nombre UNIQUE (Nombre)
);

CREATE TABLE dim.Producto (
    ProductoKey          INT            IDENTITY(1,1) NOT NULL,
    IdProductoOrigen     VARCHAR(50)    NOT NULL,
    Nombre               NVARCHAR(200)  NOT NULL,
    NombreNormalizado    NVARCHAR(200)  NOT NULL,
    IdCategoria          INT            NOT NULL,
    Activo               BIT            NOT NULL CONSTRAINT DF_Producto_Activo DEFAULT (1),
    FechaAlta            DATETIME2(0)   NOT NULL CONSTRAINT DF_Producto_FechaAlta DEFAULT (SYSDATETIME()),
    FechaActualizacion   DATETIME2(0)   NULL,
    CONSTRAINT PK_Producto           PRIMARY KEY (ProductoKey),
    CONSTRAINT UQ_Producto_IdOrigen  UNIQUE (IdProductoOrigen),
    CONSTRAINT FK_Producto_Categoria FOREIGN KEY (IdCategoria) REFERENCES dim.Categoria (IdCategoria)
);
CREATE INDEX IX_Producto_NombreNormalizado ON dim.Producto (NombreNormalizado);

CREATE TABLE dim.Cliente (
    ClienteKey           INT            IDENTITY(1,1) NOT NULL,
    IdClienteOrigen      VARCHAR(50)    NOT NULL,
    Nombre               NVARCHAR(150)  NOT NULL,
    Email                NVARCHAR(150)  NULL,
    Pais                 NVARCHAR(60)   NULL,
    FechaAlta            DATETIME2(0)   NOT NULL CONSTRAINT DF_Cliente_FechaAlta DEFAULT (SYSDATETIME()),
    FechaActualizacion   DATETIME2(0)   NULL,
    CONSTRAINT PK_Cliente          PRIMARY KEY (ClienteKey),
    CONSTRAINT UQ_Cliente_IdOrigen UNIQUE (IdClienteOrigen)
);
GO

/* ---------------- Control del ETL ---------------- */

CREATE TABLE etl.Carga (
    IdCarga               INT            IDENTITY(1,1) NOT NULL,
    IdFuente              TINYINT        NOT NULL,
    FechaInicio           DATETIME2(0)   NOT NULL CONSTRAINT DF_Carga_FechaInicio DEFAULT (SYSDATETIME()),
    FechaFin              DATETIME2(0)   NULL,
    Estado                VARCHAR(12)    NOT NULL CONSTRAINT DF_Carga_Estado DEFAULT ('EN_PROCESO'),
    RegistrosLeidos       INT            NOT NULL CONSTRAINT DF_Carga_Leidos      DEFAULT (0),
    RegistrosInsertados   INT            NOT NULL CONSTRAINT DF_Carga_Insertados  DEFAULT (0),
    RegistrosDuplicados   INT            NOT NULL CONSTRAINT DF_Carga_Duplicados  DEFAULT (0),
    RegistrosRechazados   INT            NOT NULL CONSTRAINT DF_Carga_Rechazados  DEFAULT (0),
    MarcaAguaHasta        DATETIME2(0)   NULL,
    Detalle               NVARCHAR(500)  NULL,
    CONSTRAINT PK_Carga        PRIMARY KEY (IdCarga),
    CONSTRAINT FK_Carga_Fuente FOREIGN KEY (IdFuente) REFERENCES dim.Fuente (IdFuente),
    CONSTRAINT CK_Carga_Estado CHECK (Estado IN ('EN_PROCESO','COMPLETADA','FALLIDA'))
);

CREATE TABLE etl.Rechazo (
    IdRechazo          BIGINT         IDENTITY(1,1) NOT NULL,
    IdCarga            INT            NOT NULL,
    IdRegistroOrigen   NVARCHAR(50)   NULL,
    Motivo             NVARCHAR(200)  NOT NULL,
    RegistroOriginal   NVARCHAR(MAX)  NULL,
    FechaRechazo       DATETIME2(0)   NOT NULL CONSTRAINT DF_Rechazo_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_Rechazo       PRIMARY KEY (IdRechazo),
    CONSTRAINT FK_Rechazo_Carga FOREIGN KEY (IdCarga) REFERENCES etl.Carga (IdCarga)
);

CREATE TABLE etl.PalabraClave (
    IdPalabraClave   INT            IDENTITY(1,1) NOT NULL,
    Termino          NVARCHAR(50)   NOT NULL,
    IdClasificacion  TINYINT        NOT NULL,
    Peso             DECIMAL(3,1)   NOT NULL CONSTRAINT DF_PalabraClave_Peso DEFAULT (1.0),
    Activa           BIT            NOT NULL CONSTRAINT DF_PalabraClave_Activa DEFAULT (1),
    CONSTRAINT PK_PalabraClave               PRIMARY KEY (IdPalabraClave),
    CONSTRAINT UQ_PalabraClave_Termino       UNIQUE (Termino),
    CONSTRAINT FK_PalabraClave_Clasificacion FOREIGN KEY (IdClasificacion) REFERENCES dim.Clasificacion (IdClasificacion),
    CONSTRAINT CK_PalabraClave_Peso          CHECK (Peso > 0)
);
GO

/* ---------------- Hechos ---------------- */

CREATE TABLE fact.Opinion (
    OpinionKey           BIGINT          IDENTITY(1,1) NOT NULL,
    IdFuente             TINYINT         NOT NULL,
    IdOpinionOrigen      VARCHAR(50)     NOT NULL,
    ProductoKey          INT             NOT NULL,
    ClienteKey           INT             NOT NULL,
    FechaKey             INT             NOT NULL,
    IdClasificacion      TINYINT         NOT NULL,
    FechaOpinion         DATETIME2(0)    NOT NULL,
    Comentario           NVARCHAR(2000)  NOT NULL,
    Calificacion         TINYINT         NULL,
    PuntajeSentimiento   DECIMAL(5,2)    NULL,
    Plataforma           NVARCHAR(30)    NULL,
    IdCarga              INT             NOT NULL,
    FechaCarga           DATETIME2(0)    NOT NULL CONSTRAINT DF_Opinion_FechaCarga DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_Opinion               PRIMARY KEY (OpinionKey),
    CONSTRAINT UQ_Opinion_Origen        UNIQUE (IdFuente, IdOpinionOrigen),
    CONSTRAINT FK_Opinion_Fuente        FOREIGN KEY (IdFuente)        REFERENCES dim.Fuente (IdFuente),
    CONSTRAINT FK_Opinion_Producto      FOREIGN KEY (ProductoKey)     REFERENCES dim.Producto (ProductoKey),
    CONSTRAINT FK_Opinion_Cliente       FOREIGN KEY (ClienteKey)      REFERENCES dim.Cliente (ClienteKey),
    CONSTRAINT FK_Opinion_Fecha         FOREIGN KEY (FechaKey)        REFERENCES dim.Fecha (FechaKey),
    CONSTRAINT FK_Opinion_Clasificacion FOREIGN KEY (IdClasificacion) REFERENCES dim.Clasificacion (IdClasificacion),
    CONSTRAINT FK_Opinion_Carga         FOREIGN KEY (IdCarga)         REFERENCES etl.Carga (IdCarga),
    CONSTRAINT CK_Opinion_Calificacion  CHECK (Calificacion IS NULL OR Calificacion BETWEEN 1 AND 5),
    CONSTRAINT CK_Opinion_Comentario    CHECK (LEN(Comentario) > 0)
);
CREATE INDEX IX_Opinion_Producto_Fecha ON fact.Opinion (ProductoKey, FechaKey) INCLUDE (IdClasificacion, Calificacion);
CREATE INDEX IX_Opinion_Fecha          ON fact.Opinion (FechaKey) INCLUDE (IdClasificacion);
CREATE INDEX IX_Opinion_Cliente        ON fact.Opinion (ClienteKey);

CREATE TABLE fact.ResumenSatisfaccion (
    ProductoKey             INT            NOT NULL,
    FechaKey                INT            NOT NULL,
    IdFuente                TINYINT        NOT NULL,
    TotalOpiniones          INT            NOT NULL,
    Positivas               INT            NOT NULL,
    Neutras                 INT            NOT NULL,
    Negativas               INT            NOT NULL,
    CalificacionPromedio    DECIMAL(4,2)   NULL,
    PorcentajeSatisfaccion  AS CAST(Positivas * 100.0 / NULLIF(TotalOpiniones, 0) AS DECIMAL(5,2)) PERSISTED,
    FechaCalculo            DATETIME2(0)   NOT NULL CONSTRAINT DF_Resumen_FechaCalculo DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_ResumenSatisfaccion PRIMARY KEY (ProductoKey, FechaKey, IdFuente),
    CONSTRAINT FK_Resumen_Producto    FOREIGN KEY (ProductoKey) REFERENCES dim.Producto (ProductoKey),
    CONSTRAINT FK_Resumen_Fecha       FOREIGN KEY (FechaKey)    REFERENCES dim.Fecha (FechaKey),
    CONSTRAINT FK_Resumen_Fuente      FOREIGN KEY (IdFuente)    REFERENCES dim.Fuente (IdFuente),
    CONSTRAINT CK_Resumen_Suma        CHECK (Positivas + Neutras + Negativas = TotalOpiniones)
);
GO

/* ---------------- Catálogos ---------------- */

INSERT INTO dim.Fuente (IdFuente, Codigo, Nombre, TipoFuente, Canal) VALUES
    (1, 'ENCUESTA_CSV', N'Encuestas internas de satisfacción', 'CSV', N'Encuesta interna'),
    (2, 'RESENA_WEB',   N'Reseñas del sitio web',              'BD',  N'Sitio web'),
    (3, 'SOCIAL_API',   N'Comentarios en redes sociales',      'API', N'Redes sociales');

INSERT INTO dim.Clasificacion (IdClasificacion, Codigo, Nombre, Valor) VALUES
    (1, 'POS', N'Positiva',  1),
    (2, 'NEU', N'Neutra',    0),
    (3, 'NEG', N'Negativa', -1);

-- Calendario 2020 - 2030
;WITH Numeros AS (
    SELECT TOP (DATEDIFF(DAY, '20200101', '20301231') + 1)
           ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
    FROM sys.all_objects a CROSS JOIN sys.all_objects b
), Dias AS (
    SELECT DATEADD(DAY, n, CAST('20200101' AS DATE)) AS Fecha FROM Numeros
)
INSERT INTO dim.Fecha (FechaKey, Fecha, Anio, Trimestre, Mes, NombreMes, AnioMes,
                       SemanaISO, DiaMes, DiaSemana, NombreDia, EsFinDeSemana)
SELECT CONVERT(INT, CONVERT(CHAR(8), d.Fecha, 112)),
       d.Fecha,
       YEAR(d.Fecha),
       DATEPART(QUARTER, d.Fecha),
       MONTH(d.Fecha),
       CHOOSE(MONTH(d.Fecha), N'Enero', N'Febrero', N'Marzo', N'Abril', N'Mayo', N'Junio',
              N'Julio', N'Agosto', N'Septiembre', N'Octubre', N'Noviembre', N'Diciembre'),
       CONVERT(CHAR(7), d.Fecha, 126),
       DATEPART(ISO_WEEK, d.Fecha),
       DAY(d.Fecha),
       ds.DiaSemana,
       CHOOSE(ds.DiaSemana, N'Lunes', N'Martes', N'Miércoles', N'Jueves', N'Viernes', N'Sábado', N'Domingo'),
       CASE WHEN ds.DiaSemana IN (6, 7) THEN 1 ELSE 0 END
FROM Dias d
CROSS APPLY (SELECT (DATEDIFF(DAY, CAST('19000101' AS DATE), d.Fecha) % 7) + 1 AS DiaSemana) ds;
GO

-- ============================================================
-- 3. Procedimientos y vistas de OpinionesDW
-- ============================================================
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

-- ============================================================
-- 4. Procedimientos y vistas de OpinionesWebDB
-- ============================================================
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
