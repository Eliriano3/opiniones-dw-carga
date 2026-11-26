using Microsoft.Extensions.Hosting;
using Opiniones.EtlWorker.Models;
using Opiniones.EtlWorker.Services;

namespace Opiniones.EtlWorker;

public sealed class EtlWorkerService : BackgroundService
{
    private readonly ImportService _importService;
    private readonly SummaryPrinter _summary;
    private readonly IHostApplicationLifetime _lifetime;
    private readonly EtlOptions _options;

    public EtlWorkerService(
        ImportService importService,
        SummaryPrinter summary,
        IHostApplicationLifetime lifetime,
        EtlOptions options)
    {
        _importService = importService;
        _summary = summary;
        _lifetime = lifetime;
        _options = options;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        try
        {
            var resultado = await _importService.EjecutarAsync(_options.DryRun, stoppingToken);
            _summary.Imprimir(resultado);

            if (!resultado.Exitoso)
                Environment.ExitCode = 1;
        }
        catch (Exception ex)
        {
            Environment.ExitCode = 1;
            Console.Error.WriteLine($"ERROR NO CONTROLADO: {ex.Message}");
        }
        finally
        {
            _lifetime.StopApplication();
        }
    }
}
