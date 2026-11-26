using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;
using Opiniones.EtlWorker.Config;
using Opiniones.EtlWorker.Models;

namespace Opiniones.EtlWorker.Services;

public sealed class LogService
{
    private readonly AppConfig _config;
    private readonly JsonSerializerOptions _opciones = new()
    {
        WriteIndented = true,
        Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping
    };

    public LogService(AppConfig config)
    {
        _config = config;
    }

    public string Guardar(ResultadoEtl resultado)
    {
        Directory.CreateDirectory(_config.RutaLogs);

        var nombre = $"etl_{resultado.Inicio:yyyyMMdd_HHmmss_fff}.json";
        var ruta = Path.Combine(_config.RutaLogs, nombre);
        var json = JsonSerializer.Serialize(resultado, _opciones);

        File.WriteAllText(ruta, json, new UTF8Encoding(false));
        return ruta;
    }
}
