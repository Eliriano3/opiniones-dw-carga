using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace Opiniones.EtlWorker.Services;

public static class TextNormalizer
{
    private static readonly Regex Espacios = new(@"\s+", RegexOptions.Compiled | RegexOptions.CultureInvariant);

    public static string Normalizar(string? texto)
    {
        if (string.IsNullOrWhiteSpace(texto))
            return "";

        var descompuesto = texto.Trim().ToLowerInvariant().Normalize(NormalizationForm.FormD);
        var constructor = new StringBuilder(descompuesto.Length);

        foreach (var caracter in descompuesto)
        {
            var categoria = CharUnicodeInfo.GetUnicodeCategory(caracter);
            if (categoria == UnicodeCategory.NonSpacingMark)
                continue;

            if (char.IsLetterOrDigit(caracter))
                constructor.Append(caracter);
            else
                constructor.Append(' ');
        }

        return Espacios.Replace(constructor.ToString(), " ").Trim();
    }
}
