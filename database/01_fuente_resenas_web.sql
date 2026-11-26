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
