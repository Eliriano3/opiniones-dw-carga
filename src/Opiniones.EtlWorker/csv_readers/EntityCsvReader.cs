using System.Text.Json;
using Opiniones.EtlWorker.Models;
using Opiniones.EtlWorker.Services;

namespace Opiniones.EtlWorker.CsvReaders;

public abstract class EntityCsvReader<T>
{
    private readonly CsvReader _csvReader;

    protected EntityCsvReader(CsvReader csvReader)
    {
        _csvReader = csvReader;
    }

    protected abstract string Tabla { get; }
    protected abstract string[] Encabezados { get; }
    protected abstract T Mapear(FilaCsv fila, string archivo);

    public ResultadoLectura<T> Leer(string rutaBase, string archivo)
    {
        var resultado = new ResultadoLectura<T>();
        var filas = _csvReader.LeerFilas(rutaBase, archivo, Encabezados);

        foreach (var fila in filas)
        {
            resultado.Procesados++;

            if (fila.Error is not null)
            {
                resultado.Rechazos.Add(CrearRechazo(fila, archivo, fila.Error));
                continue;
            }

            try
            {
                resultado.Filas.Add(Mapear(fila, archivo));
            }
            catch (Exception ex)
            {
                resultado.Rechazos.Add(CrearRechazo(fila, archivo, $"Formato: {ex.Message}"));
            }
        }

        return resultado;
    }

    private RegistroRechazado CrearRechazo(FilaCsv fila, string archivo, string motivo)
    {
        var valores = new Dictionary<string, string?>();
        for (var i = 0; i < Encabezados.Length; i++)
        {
            valores[Encabezados[i]] = i < fila.Campos.Length ? fila.Campos[i] : null;
        }

        var idRegistro = fila.Campos.Length > 0 ? fila.Campos[0].Trim() : null;

        return new RegistroRechazado
        {
            Tabla = Tabla,
            Archivo = archivo,
            Linea = fila.NumeroLinea,
            IdRegistro = idRegistro is null ? null : ValidationHelper.Truncar(idRegistro, 50),
            Motivo = ValidationHelper.Truncar(motivo, 200),
            RegistroOriginal = JsonSerializer.Serialize(valores)
        };
    }
}
