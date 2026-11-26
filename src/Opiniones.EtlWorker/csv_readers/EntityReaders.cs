using Opiniones.EtlWorker.Models;
using Opiniones.EtlWorker.Services;

namespace Opiniones.EtlWorker.CsvReaders;

public sealed class ClienteCsvReader : EntityCsvReader<ClienteCsv>
{
    public ClienteCsvReader(CsvReader csvReader) : base(csvReader)
    {
    }

    protected override string Tabla => "Clientes";
    protected override string[] Encabezados => new[] { "IdCliente", "Nombre", "Email" };

    protected override ClienteCsv Mapear(FilaCsv fila, string archivo) => new()
    {
        IdOrigen = ValidationHelper.Entero(fila.Campos[0], "IdCliente", 1, int.MaxValue),
        Nombre = fila.Campos[1].Trim(),
        Email = fila.Campos[2].Trim(),
        NumeroLinea = fila.NumeroLinea,
        Archivo = archivo
    };
}

public sealed class ProductoCsvReader : EntityCsvReader<ProductoCsv>
{
    public ProductoCsvReader(CsvReader csvReader) : base(csvReader)
    {
    }

    protected override string Tabla => "Productos";
    protected override string[] Encabezados => new[] { "IdProducto", "Nombre", "Categoría" };

    protected override ProductoCsv Mapear(FilaCsv fila, string archivo) => new()
    {
        IdOrigen = ValidationHelper.Entero(fila.Campos[0], "IdProducto", 1, int.MaxValue),
        Nombre = fila.Campos[1].Trim(),
        Categoria = fila.Campos[2].Trim(),
        NumeroLinea = fila.NumeroLinea,
        Archivo = archivo
    };
}

public sealed class EncuestaCsvReader : EntityCsvReader<EncuestaCsv>
{
    public EncuestaCsvReader(CsvReader csvReader) : base(csvReader)
    {
    }

    protected override string Tabla => "Encuestas";
    protected override string[] Encabezados => new[]
    {
        "IdOpinion", "IdCliente", "IdProducto", "Fecha", "Comentario",
        "Clasificación", "PuntajeSatisfacción", "Fuente"
    };

    protected override EncuestaCsv Mapear(FilaCsv fila, string archivo) => new()
    {
        IdOpinion = fila.Campos[0].Trim(),
        IdCliente = ValidationHelper.Entero(fila.Campos[1], "IdCliente", 1, int.MaxValue),
        IdProducto = ValidationHelper.Entero(fila.Campos[2], "IdProducto", 1, int.MaxValue),
        Fecha = ValidationHelper.Fecha(fila.Campos[3], "Fecha"),
        Comentario = fila.Campos[4].Trim(),
        Clasificacion = fila.Campos[5].Trim(),
        Puntaje = ValidationHelper.Entero(fila.Campos[6], "PuntajeSatisfacción", 1, 5),
        Fuente = fila.Campos[7].Trim(),
        NumeroLinea = fila.NumeroLinea,
        Archivo = archivo
    };
}

public sealed class ResenaWebCsvReader : EntityCsvReader<ResenaWebCsv>
{
    public ResenaWebCsvReader(CsvReader csvReader) : base(csvReader)
    {
    }

    protected override string Tabla => "ResenasWeb";
    protected override string[] Encabezados => new[]
    {
        "IdReview", "IdCliente", "IdProducto", "Fecha", "Comentario", "Rating"
    };

    protected override ResenaWebCsv Mapear(FilaCsv fila, string archivo) => new()
    {
        IdReview = fila.Campos[0].Trim(),
        IdCliente = ValidationHelper.IdConPrefijo(fila.Campos[1], 'C', "IdCliente", 1, int.MaxValue),
        IdProducto = ValidationHelper.IdConPrefijo(fila.Campos[2], 'P', "IdProducto", 1, int.MaxValue),
        Fecha = ValidationHelper.Fecha(fila.Campos[3], "Fecha"),
        Comentario = fila.Campos[4].Trim(),
        Rating = ValidationHelper.Entero(fila.Campos[5], "Rating", 1, 5),
        NumeroLinea = fila.NumeroLinea,
        Archivo = archivo
    };
}

public sealed class ComentarioSocialCsvReader : EntityCsvReader<ComentarioSocialCsv>
{
    public ComentarioSocialCsvReader(CsvReader csvReader) : base(csvReader)
    {
    }

    protected override string Tabla => "ComentariosSociales";
    protected override string[] Encabezados => new[]
    {
        "IdComment", "IdCliente", "IdProducto", "Fuente", "Fecha", "Comentario"
    };

    protected override ComentarioSocialCsv Mapear(FilaCsv fila, string archivo)
    {
        int? idCliente = null;
        if (!string.IsNullOrWhiteSpace(fila.Campos[1]))
            idCliente = ValidationHelper.IdConPrefijo(fila.Campos[1], 'C', "IdCliente", 1, int.MaxValue);

        return new ComentarioSocialCsv
        {
            IdComment = fila.Campos[0].Trim(),
            IdCliente = idCliente,
            IdProducto = ValidationHelper.IdConPrefijo(fila.Campos[2], 'P', "IdProducto", 1, int.MaxValue),
            Plataforma = fila.Campos[3].Trim(),
            Fecha = ValidationHelper.Fecha(fila.Campos[4], "Fecha"),
            Comentario = fila.Campos[5].Trim(),
            NumeroLinea = fila.NumeroLinea,
            Archivo = archivo
        };
    }
}

public sealed class FuenteCsvReader : EntityCsvReader<FuenteCsv>
{
    public FuenteCsvReader(CsvReader csvReader) : base(csvReader)
    {
    }

    protected override string Tabla => "Fuentes";
    protected override string[] Encabezados => new[] { "IdFuente", "TipoFuente", "FechaCarga" };

    protected override FuenteCsv Mapear(FilaCsv fila, string archivo) => new()
    {
        IdFuente = fila.Campos[0].Trim(),
        TipoFuente = fila.Campos[1].Trim(),
        FechaCarga = ValidationHelper.Fecha(fila.Campos[2], "FechaCarga"),
        NumeroLinea = fila.NumeroLinea,
        Archivo = archivo
    };
}
