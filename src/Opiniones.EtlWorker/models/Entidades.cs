namespace Opiniones.EtlWorker.Models;

public sealed class ClienteCsv
{
    public int IdOrigen { get; set; }
    public string Nombre { get; set; } = "";
    public string Email { get; set; } = "";
    public int NumeroLinea { get; set; }
    public string Archivo { get; set; } = "";
}

public sealed class ProductoCsv
{
    public int IdOrigen { get; set; }
    public string Nombre { get; set; } = "";
    public string Categoria { get; set; } = "";
    public decimal Precio { get; set; }
    public int NumeroLinea { get; set; }
    public string Archivo { get; set; } = "";
}

public sealed class EncuestaCsv
{
    public string IdOpinion { get; set; } = "";
    public int IdCliente { get; set; }
    public int IdProducto { get; set; }
    public DateTime Fecha { get; set; }
    public string Comentario { get; set; } = "";
    public string Clasificacion { get; set; } = "";
    public int Puntaje { get; set; }
    public string Fuente { get; set; } = "";
    public int NumeroLinea { get; set; }
    public string Archivo { get; set; } = "";
}

public sealed class ResenaWebCsv
{
    public string IdReview { get; set; } = "";
    public int IdResena { get; set; }
    public int IdCliente { get; set; }
    public int IdProducto { get; set; }
    public DateTime Fecha { get; set; }
    public string Comentario { get; set; } = "";
    public int Rating { get; set; }
    public int NumeroLinea { get; set; }
    public string Archivo { get; set; } = "";
}

public sealed class ComentarioSocialCsv
{
    public string IdComment { get; set; } = "";
    public int? IdCliente { get; set; }
    public int IdProducto { get; set; }
    public string Plataforma { get; set; } = "";
    public DateTime Fecha { get; set; }
    public string Comentario { get; set; } = "";
    public int NumeroLinea { get; set; }
    public string Archivo { get; set; } = "";
}

public sealed class FuenteCsv
{
    public string IdFuente { get; set; } = "";
    public string TipoFuente { get; set; } = "";
    public DateTime FechaCarga { get; set; }
    public int NumeroLinea { get; set; }
    public string Archivo { get; set; } = "";
}

public sealed class OpinionFact
{
    public byte IdFuente { get; set; }
    public string IdOpinionOrigen { get; set; } = "";
    public int ProductoKey { get; set; }
    public int ClienteKey { get; set; }
    public int FechaKey { get; set; }
    public byte IdClasificacion { get; set; }
    public DateTime FechaOpinion { get; set; }
    public string Comentario { get; set; } = "";
    public byte? Calificacion { get; set; }
    public decimal? PuntajeSentimiento { get; set; }
    public string? Plataforma { get; set; }
    public int IdCarga { get; set; }
}

public sealed class RegistroRechazado
{
    public string Tabla { get; set; } = "";
    public string Archivo { get; set; } = "";
    public int Linea { get; set; }
    public string? IdRegistro { get; set; }
    public string Motivo { get; set; } = "";
    public string RegistroOriginal { get; set; } = "";
}

public sealed class PalabraClave
{
    public string Termino { get; set; } = "";
    public string TerminoNormalizado { get; set; } = "";
    public byte IdClasificacion { get; set; }
    public decimal Peso { get; set; } = 1.0m;
    public bool Activa { get; set; } = true;
}

public static class ClasificacionIds
{
    public const byte Positiva = 1;
    public const byte Neutra = 2;
    public const byte Negativa = 3;

    public static decimal Valor(byte idClasificacion) => idClasificacion switch
    {
        Positiva => 1m,
        Negativa => -1m,
        _ => 0m
    };
}

public static class FuenteIds
{
    public const byte Csv = 1;
    public const byte Web = 2;
    public const byte Social = 3;
}
