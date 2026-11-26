using System.Text;
using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;
using Opiniones.EtlWorker.Config;

if (args.Length == 0)
{
    Console.Error.WriteLine("Uso: dotnet run --project tools/QueryRunner -- <archivo.sql | consulta>");
    return 1;
}

var config = ConfigLoader.Cargar();
var texto = File.Exists(args[0]) ? File.ReadAllText(args[0]) : args[0];

var lotes = Regex.Split(texto, @"^\s*GO\s*$", RegexOptions.Multiline | RegexOptions.IgnoreCase)
    .Where(l => !string.IsNullOrWhiteSpace(l))
    .ToList();

try
{
    using var conexion = new SqlConnection(config.ConnectionString);
    conexion.Open();
    Console.OutputEncoding = Encoding.UTF8;

    for (var i = 0; i < lotes.Count; i++)
    {
        Console.WriteLine();
        Console.WriteLine($"--- Lote {i + 1}/{lotes.Count} ---");

        using var comando = conexion.CreateCommand();
        comando.CommandText = lotes[i];
        comando.CommandTimeout = 120;

        using var lector = comando.ExecuteReader();
        var conjunto = 0;

        do
        {
            conjunto++;
            if (!lector.HasRows)
            {
                Console.WriteLine($"(conjunto {conjunto}: sin filas)");
                continue;
            }

            var columnas = Enumerable.Range(0, lector.FieldCount)
                .Select(lector.GetName)
                .ToArray();

            Console.WriteLine(string.Join(" | ", columnas));
            Console.WriteLine(new string('-', Math.Min(120, columnas.Sum(c => c.Length) + columnas.Length * 3)));

            var filas = 0;
            while (lector.Read() && filas < 100)
            {
                var valores = Enumerable.Range(0, lector.FieldCount)
                    .Select(c => lector.IsDBNull(c) ? "NULL" : lector.GetValue(c)?.ToString() ?? "")
                    .ToArray();

                Console.WriteLine(string.Join(" | ", valores));
                filas++;
            }

            if (filas >= 100)
                Console.WriteLine("(salida limitada a 100 filas)");
        }
        while (lector.NextResult());
    }
}
catch (Exception ex)
{
    Console.Error.WriteLine($"Error al consultar: {ex.Message}");
    return 2;
}

return 0;
