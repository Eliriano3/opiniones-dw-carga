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
