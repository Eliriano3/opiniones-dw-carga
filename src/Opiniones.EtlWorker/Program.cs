using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Opiniones.EtlWorker;
using Opiniones.EtlWorker.Config;
using Opiniones.EtlWorker.Context;
using Opiniones.EtlWorker.CsvReaders;
using Opiniones.EtlWorker.Daos;
using Opiniones.EtlWorker.Models;
using Opiniones.EtlWorker.Services;

var dryRun = args.Any(a =>
    a.Equals("--dry-run", StringComparison.OrdinalIgnoreCase) ||
    a.Equals("--validar", StringComparison.OrdinalIgnoreCase));

var builder = Host.CreateApplicationBuilder(args);

builder.Logging.ClearProviders();
builder.Logging.AddSimpleConsole(opciones =>
{
    opciones.SingleLine = true;
    opciones.TimestampFormat = "HH:mm:ss ";
});
builder.Logging.SetMinimumLevel(LogLevel.Warning);

AppConfig config;
try
{
    config = ConfigLoader.Cargar();
}
catch (Exception ex)
{
    Console.Error.WriteLine($"No se pudo cargar la configuracion: {ex.Message}");
    return 1;
}

builder.Services.AddSingleton(config);
builder.Services.AddSingleton<CsvReader>();
builder.Services.AddSingleton<ClienteCsvReader>();
builder.Services.AddSingleton<ProductoCsvReader>();
builder.Services.AddSingleton<EncuestaCsvReader>();
builder.Services.AddSingleton<ResenaWebCsvReader>();
builder.Services.AddSingleton<ComentarioSocialCsvReader>();
builder.Services.AddSingleton<FuenteCsvReader>();
builder.Services.AddSingleton<DatabaseContext>();
builder.Services.AddSingleton<CargaDao>();
builder.Services.AddSingleton<StagingDao>();
builder.Services.AddSingleton<DimensionDao>();
builder.Services.AddSingleton<OpinionDao>();
builder.Services.AddSingleton<RechazoDao>();
builder.Services.AddSingleton<WebSourceDao>();
builder.Services.AddSingleton<PalabraClaveDao>();
builder.Services.AddSingleton<ResumenDao>();
builder.Services.AddSingleton<ClassificationService>();
builder.Services.AddSingleton<PricingService>();
builder.Services.AddSingleton<LogService>();
builder.Services.AddSingleton<SummaryPrinter>();
builder.Services.AddSingleton<ImportService>();
builder.Services.AddSingleton(new EtlOptions { DryRun = dryRun });
builder.Services.AddSingleton<EtlWorkerService>();
builder.Services.AddSingleton<IHostedService>(sp => sp.GetRequiredService<EtlWorkerService>());

var host = builder.Build();
await host.RunAsync();
return 0;
