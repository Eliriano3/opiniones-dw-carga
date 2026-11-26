using System.Text;
using Opiniones.EtlWorker.Models;

namespace Opiniones.EtlWorker.Services;

public sealed class SummaryPrinter
{
    public void Imprimir(ResultadoEtl resultado)
    {
        try
        {
            Console.OutputEncoding = Encoding.UTF8;
        }
        catch
        {
            // Algunas consolas no permiten cambiar la codificacion.
        }

        Console.WriteLine();
        Console.WriteLine("==================================================================================");
        Console.WriteLine(resultado.Simulacion
            ? " VALIDACION DEL ETL (SIN BASE DE DATOS)"
            : " RESULTADO DE LA CARGA ETL");
        Console.WriteLine("==================================================================================");

        Console.WriteLine($"{"Tabla",-24}{"Procesados",12}{"Insertados",12}{"Rechazados",12}{"Duplicados",12}");
        Console.WriteLine(new string('-', 72));

        foreach (var metrica in resultado.Metricas)
        {
            Console.WriteLine(
                $"{metrica.Tabla,-24}{metrica.Procesados,12}{metrica.Insertados,12}" +
                $"{metrica.Rechazados,12}{metrica.Duplicados,12}");

            if (!string.IsNullOrWhiteSpace(metrica.Nota))
                Console.WriteLine($"  {metrica.Nota}");
        }

        Console.WriteLine(new string('-', 72));
        Console.WriteLine(
            $"{"TOTAL",-24}{resultado.TotalProcesados,12}{resultado.TotalInsertados,12}" +
            $"{resultado.TotalRechazados,12}{resultado.TotalDuplicados,12}");
        Console.WriteLine();

        Console.WriteLine($"Opiniones insertadas en fact.Opinion : {resultado.HechosInsertados}");
        Console.WriteLine($"Opiniones duplicadas (no insertadas) : {resultado.HechosDuplicados}");
        Console.WriteLine($"Comentarios sociales sin cliente     : {resultado.ClientesGenericos}");
        Console.WriteLine($"Cargas historicas de fuentes         : {resultado.CargasHistoricas}");
        Console.WriteLine($"Duracion                              : {resultado.DuracionSegundos} s");

        if (!string.IsNullOrWhiteSpace(resultado.RutaLog))
            Console.WriteLine($"Log de ejecucion                      : {resultado.RutaLog}");

        if (!string.IsNullOrWhiteSpace(resultado.ErrorCritico))
        {
            Console.WriteLine();
            Console.WriteLine($"ERROR CRITICO: {resultado.ErrorCritico}");
        }

        Console.WriteLine("==================================================================================");
        Console.WriteLine();
    }
}
