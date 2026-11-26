namespace Opiniones.EtlWorker.CsvReaders;

public sealed class CsvEstructuraException : Exception
{
    public CsvEstructuraException(string mensaje) : base(mensaje)
    {
    }
}

public sealed class FilaCsv
{
    public int NumeroLinea { get; init; }
    public string[] Campos { get; init; } = Array.Empty<string>();
    public string? Error { get; init; }
}

public sealed class ResultadoLectura<T>
{
    public int Procesados { get; set; }
    public List<T> Filas { get; } = new();
    public List<Models.RegistroRechazado> Rechazos { get; } = new();
}
