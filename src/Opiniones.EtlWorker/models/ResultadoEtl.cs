namespace Opiniones.EtlWorker.Models;

public sealed class MetricaTabla
{
    public string Tabla { get; set; } = "";
    public int Procesados { get; set; }
    public int Insertados { get; set; }
    public int Rechazados { get; set; }
    public int Duplicados { get; set; }
    public string? Nota { get; set; }
}

public sealed class ResultadoEtl
{
    public DateTime Inicio { get; set; } = DateTime.Now;
    public DateTime Fin { get; set; }
    public bool Simulacion { get; set; }
    public string? ErrorCritico { get; set; }
    public string? RutaLog { get; set; }
    public List<MetricaTabla> Metricas { get; set; } = new();
    public List<RegistroRechazado> Rechazos { get; set; } = new();
    public int HechosInsertados { get; set; }
    public int HechosDuplicados { get; set; }
    public int ClientesGenericos { get; set; }
    public int CargasHistoricas { get; set; }

    public int TotalProcesados => Metricas.Sum(m => m.Procesados);
    public int TotalInsertados => Metricas.Sum(m => m.Insertados);
    public int TotalRechazados => Metricas.Sum(m => m.Rechazados);
    public int TotalDuplicados => Metricas.Sum(m => m.Duplicados);
    public double DuracionSegundos => Math.Round((Fin - Inicio).TotalSeconds, 2);
    public bool Exitoso => string.IsNullOrWhiteSpace(ErrorCritico);
}

public sealed class DatasetCsv
{
    public List<ClienteCsv> Clientes { get; } = new();
    public List<ProductoCsv> Productos { get; } = new();
    public List<string> Categorias { get; } = new();
    public List<EncuestaCsv> Encuestas { get; } = new();
    public List<ResenaWebCsv> ResenasWeb { get; } = new();
    public List<ComentarioSocialCsv> ComentariosSociales { get; } = new();
    public List<FuenteCsv> Fuentes { get; } = new();
    public List<RegistroRechazado> Rechazos { get; } = new();
    public List<MetricaTabla> Metricas { get; } = new();

    public MetricaTabla? BuscarMetrica(string tabla) =>
        Metricas.FirstOrDefault(m => string.Equals(m.Tabla, tabla, StringComparison.OrdinalIgnoreCase));
}

public sealed class EtlOptions
{
    public bool DryRun { get; set; }
}
