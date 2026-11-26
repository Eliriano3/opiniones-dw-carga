using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;
using Opiniones.EtlWorker.Config;

if (args.Length == 0)
{
    Console.Error.WriteLine("Uso: dotnet run --project tools/DbRunner -- <archivo.sql>");
    Console.Error.WriteLine("     dotnet run --project tools/DbRunner -- --probar");
    return 1;
}

var config = ConfigLoader.Cargar();
var builder = new SqlConnectionStringBuilder(config.ConnectionString)
{
    InitialCatalog = "master"
};

using var conexion = new SqlConnection(builder.ConnectionString);
try
{
    conexion.Open();
}
catch (Exception ex)
{
    Console.Error.WriteLine($"No se pudo conectar a {config.ServidorVisible}: {ex.Message}");
    return 2;
}

if (args[0] == "--probar")
{
    using var comando = conexion.CreateCommand();
    comando.CommandText = "SELECT @@VERSION, DB_NAME(), SUSER_SNAME()";
    using var lector = comando.ExecuteReader();
    while (lector.Read())
    {
        Console.WriteLine($"Servidor : {config.ServidorVisible}");
        Console.WriteLine($"Version  : {lector.GetString(0).Split('\n')[0]}");
        Console.WriteLine($"Base     : {lector.GetString(1)}");
        Console.WriteLine($"Usuario  : {lector.GetString(2)}");
    }
    return 0;
}

var archivo = args[0];
if (!File.Exists(archivo))
{
    Console.Error.WriteLine($"No existe el archivo SQL: {archivo}");
    return 3;
}

var texto = File.ReadAllText(archivo);
var lotes = Regex.Split(texto, @"^\s*GO\s*$", RegexOptions.Multiline | RegexOptions.IgnoreCase)
    .Where(l => !string.IsNullOrWhiteSpace(l))
    .ToList();

Console.WriteLine($"Ejecutando {lotes.Count} lotes de {archivo}...");

for (var i = 0; i < lotes.Count; i++)
{
    var lote = lotes[i].Trim();
    if (lote.Length == 0)
        continue;

    try
    {
        using var comando = conexion.CreateCommand();
        comando.CommandText = lote;
        comando.CommandTimeout = 300;
        var afectadas = comando.ExecuteNonQuery();
        Console.WriteLine($"  Lote {i + 1}/{lotes.Count}: OK ({afectadas} filas afectadas)");
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"  Lote {i + 1}/{lotes.Count}: ERROR");
        Console.Error.WriteLine(ex.Message);
        return 4;
    }
}

Console.WriteLine("Script ejecutado correctamente.");
return 0;
