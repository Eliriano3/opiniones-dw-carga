using System.Text;

namespace Opiniones.EtlWorker.CsvReaders;

public sealed class CsvReader
{
    public IReadOnlyList<FilaCsv> LeerFilas(
        string rutaBase,
        string archivo,
        IReadOnlyList<string> encabezadosEsperados)
    {
        if (string.IsNullOrWhiteSpace(rutaBase))
            throw new CsvEstructuraException("La ruta base de los archivos CSV esta vacia.");

        if (string.IsNullOrWhiteSpace(archivo))
            throw new CsvEstructuraException("El nombre del archivo CSV esta vacio.");

        var ruta = Path.Combine(rutaBase, archivo);
        if (!File.Exists(ruta))
            throw new FileNotFoundException($"No existe el archivo CSV: {ruta}", ruta);

        string contenido;
        try
        {
            contenido = File.ReadAllText(ruta, Encoding.UTF8);
        }
        catch (Exception ex)
        {
            throw new CsvEstructuraException($"No se pudo leer el archivo {ruta}: {ex.Message}");
        }

        var filas = CsvParser.Parsear(contenido);
        if (filas.Count == 0)
            throw new CsvEstructuraException($"El archivo {archivo} esta vacio.");

        var encabezado = filas[0].Campos
            .Select(Limpiar)
            .ToArray();

        if (encabezado.Length != encabezadosEsperados.Count)
        {
            throw new CsvEstructuraException(
                $"El archivo {archivo} tiene {encabezado.Length} columnas y se esperaban " +
                $"{encabezadosEsperados.Count}. Encabezado encontrado: {string.Join(", ", encabezado)}");
        }

        for (var i = 0; i < encabezado.Length; i++)
        {
            if (!string.Equals(encabezado[i], encabezadosEsperados[i].Trim(), StringComparison.OrdinalIgnoreCase))
            {
                throw new CsvEstructuraException(
                    $"El encabezado de {archivo} no coincide. Columna {i + 1}: " +
                    $"se encontro '{encabezado[i]}' y se esperaba '{encabezadosEsperados[i]}'.");
            }
        }

        var resultado = new List<FilaCsv>();
        for (var i = 1; i < filas.Count; i++)
        {
            var fila = filas[i];
            if (fila.Campos.All(string.IsNullOrWhiteSpace))
                continue;

            if (fila.Campos.Length != encabezado.Length)
            {
                resultado.Add(new FilaCsv
                {
                    NumeroLinea = fila.NumeroLinea,
                    Campos = fila.Campos,
                    Error = $"Se esperaban {encabezado.Length} columnas y se encontraron {fila.Campos.Length}."
                });
                continue;
            }

            resultado.Add(fila);
        }

        return resultado;
    }

    private static string Limpiar(string valor) =>
        valor.Trim().TrimStart('\uFEFF');
}
