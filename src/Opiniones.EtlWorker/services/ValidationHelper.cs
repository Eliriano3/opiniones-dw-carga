using System.Globalization;
using System.Text.RegularExpressions;
using Opiniones.EtlWorker.Models;

namespace Opiniones.EtlWorker.Services;

public static class ValidationHelper
{
    private static readonly Regex EmailRegex = new(
        @"^[^@\s]+@[^@\s]+\.[^@\s]+$",
        RegexOptions.Compiled | RegexOptions.CultureInvariant);

    public static string Texto(
        string? valor,
        int longitudMaxima,
        string columna,
        bool soloLetras = false,
        bool obligatorio = true)
    {
        var limpio = (valor ?? "").Trim();

        if (obligatorio && limpio.Length == 0)
            throw new ValidationException($"{columna}: campo obligatorio vacio.");

        if (limpio.Length > longitudMaxima)
            throw new ValidationException(
                $"{columna}: longitud {limpio.Length} supera el maximo de {longitudMaxima} caracteres.");

        if (limpio.Any(char.IsControl))
            throw new ValidationException($"{columna}: contiene caracteres de control.");

        if (soloLetras && limpio.Length > 0 && !limpio.Any(char.IsLetter))
            throw new ValidationException($"{columna}: no puede estar formado solo por numeros o simbolos.");

        return limpio;
    }

    public static string Email(string? valor, string columna = "Email", int longitudMaxima = 150)
    {
        var limpio = Texto(valor, longitudMaxima, columna).ToLowerInvariant();
        if (!EmailRegex.IsMatch(limpio))
            throw new ValidationException($"{columna}: formato de correo invalido ({limpio}).");

        return limpio;
    }

    public static int Entero(string? valor, string columna, int minimo = int.MinValue, int maximo = int.MaxValue)
    {
        var limpio = (valor ?? "").Trim();
        if (limpio.Length == 0)
            throw new ValidationException($"{columna}: valor numerico obligatorio vacio.");

        if (!int.TryParse(limpio, NumberStyles.Integer, CultureInfo.InvariantCulture, out var numero))
            throw new ValidationException($"{columna}: '{limpio}' no es un numero entero valido.");

        if (numero < minimo || numero > maximo)
            throw new ValidationException($"{columna}: {numero} esta fuera del rango permitido ({minimo} a {maximo}).");

        return numero;
    }

    public static decimal Decimal(
        string? valor,
        string columna,
        decimal minimo = 0m,
        decimal maximo = decimal.MaxValue,
        int decimales = 2)
    {
        var limpio = (valor ?? "").Trim();
        if (limpio.Length == 0)
            throw new ValidationException($"{columna}: valor decimal obligatorio vacio.");

        if (!decimal.TryParse(limpio, NumberStyles.Number, CultureInfo.InvariantCulture, out var numero))
            throw new ValidationException($"{columna}: '{limpio}' no es un numero decimal valido.");

        if (numero < minimo)
            throw new ValidationException($"{columna}: {numero} no puede ser menor que {minimo}.");

        if (numero > maximo)
            throw new ValidationException($"{columna}: {numero} no puede ser mayor que {maximo}.");

        if (decimal.Round(numero, decimales, MidpointRounding.AwayFromZero) != numero)
            throw new ValidationException($"{columna}: {numero} supera los {decimales} decimales permitidos.");

        return numero;
    }

    public static DateTime Fecha(string? valor, string columna, DateTime? minimo = null, DateTime? maximo = null)
    {
        var limpio = (valor ?? "").Trim();
        if (limpio.Length == 0)
            throw new ValidationException($"{columna}: fecha obligatoria vacia.");

        var formatos = new[]
        {
            "yyyy-MM-dd", "yyyy/MM/dd", "dd/MM/yyyy", "MM/dd/yyyy",
            "yyyy-MM-dd HH:mm:ss", "yyyy-MM-ddTHH:mm:ss"
        };

        if (!DateTime.TryParseExact(
                limpio,
                formatos,
                CultureInfo.InvariantCulture,
                DateTimeStyles.None,
                out var fecha))
        {
            throw new ValidationException($"{columna}: '{limpio}' no tiene un formato de fecha valido (yyyy-MM-dd).");
        }

        fecha = fecha.Date;

        if (minimo.HasValue && fecha < minimo.Value.Date)
            throw new ValidationException($"{columna}: {fecha:yyyy-MM-dd} es anterior a {minimo.Value:yyyy-MM-dd}.");

        if (maximo.HasValue && fecha > maximo.Value.Date)
            throw new ValidationException($"{columna}: {fecha:yyyy-MM-dd} es posterior a {maximo.Value:yyyy-MM-dd}.");

        return fecha;
    }

    public static int IdConPrefijo(
        string? valor,
        char prefijo,
        string columna,
        int minimo = 1,
        int maximo = int.MaxValue)
    {
        var limpio = (valor ?? "").Trim();
        if (limpio.Length == 0)
            throw new ValidationException($"{columna}: identificador obligatorio vacio.");

        if (char.IsLetter(limpio[0]))
        {
            if (char.ToUpperInvariant(limpio[0]) != char.ToUpperInvariant(prefijo))
                throw new ValidationException($"{columna}: se esperaba el prefijo {prefijo} en '{limpio}'.");

            limpio = limpio[1..].Trim();
        }

        return Entero(limpio, columna, minimo, maximo);
    }

    public static byte Clasificacion(string? valor)
    {
        var normalizado = TextNormalizer.Normalizar(valor);

        return normalizado switch
        {
            "positiva" => ClasificacionIds.Positiva,
            "positivas" => ClasificacionIds.Positiva,
            "neutra" => ClasificacionIds.Neutra,
            "neutro" => ClasificacionIds.Neutra,
            "negativa" => ClasificacionIds.Negativa,
            "negativas" => ClasificacionIds.Negativa,
            _ => throw new ValidationException(
                $"Clasificacion: '{valor}' no es valida. Use Positiva, Neutra o Negativa.")
        };
    }

    public static byte TipoFuente(string? valor)
    {
        var normalizado = TextNormalizer.Normalizar(valor);

        return normalizado switch
        {
            "csv" => FuenteIds.Csv,
            "web" => FuenteIds.Web,
            "red social" => FuenteIds.Social,
            _ => throw new ValidationException(
                $"TipoFuente: '{valor}' no es valido. Use Web, CSV o Red Social.")
        };
    }

    public static void ValidarConsistenciaClasificacion(byte idClasificacion, int puntaje, string idRegistro)
    {
        var inconsistente = idClasificacion switch
        {
            ClasificacionIds.Positiva => puntaje < 4,
            ClasificacionIds.Neutra => puntaje != 3,
            ClasificacionIds.Negativa => puntaje > 2,
            _ => true
        };

        if (inconsistente)
        {
            throw new ValidationException(
                $"La clasificacion del registro {idRegistro} no coincide con el puntaje {puntaje}.");
        }
    }

    public static int FechaKey(DateTime fecha)
    {
        if (fecha.Year < 2020 || fecha.Year > 2030)
            throw new ValidationException(
                $"Fecha: {fecha:yyyy-MM-dd} esta fuera del calendario de dim.Fecha (2020 a 2030).");

        return int.Parse(fecha.ToString("yyyyMMdd", CultureInfo.InvariantCulture), CultureInfo.InvariantCulture);
    }

    public static string Truncar(string? valor, int longitud)
    {
        var texto = valor ?? "";
        return texto.Length <= longitud ? texto : texto[..longitud];
    }
}
