namespace Opiniones.EtlWorker.Config;

public sealed class AppConfig
{
    public string DbHost { get; init; } = "";
    public string DbPort { get; init; } = "1433";
    public string DbInstance { get; init; } = "";
    public string DbName { get; init; } = "";
    public string DbUser { get; init; } = "";
    public string DbPassword { get; init; } = "";
    public bool DbEncrypt { get; init; } = true;
    public bool DbTrustServerCertificate { get; init; } = true;

    public string RaizProyecto { get; init; } = "";
    public string RutaConfig { get; init; } = "";
    public string RutaDataInput { get; init; } = "";
    public string RutaLogs { get; init; } = "";
    public string RutaPalabrasClave { get; init; } = "";
    public string RutaPrecios { get; init; } = "";

    public string ArchivoClientes { get; init; } = "clientes.csv";
    public string ArchivoProductos { get; init; } = "productos.csv";
    public string ArchivoEncuestas { get; init; } = "encuestas.csv";
    public string ArchivoResenasWeb { get; init; } = "resenas_web.csv";
    public string ArchivoComentarios { get; init; } = "comentarios_sociales.csv";
    public string ArchivoFuentes { get; init; } = "fuentes.csv";

    public string ConnectionString { get; init; } = "";

    public string ServidorVisible =>
        string.IsNullOrWhiteSpace(DbInstance) ? $"{DbHost},{DbPort}" : $"{DbHost}\\{DbInstance}";
}
