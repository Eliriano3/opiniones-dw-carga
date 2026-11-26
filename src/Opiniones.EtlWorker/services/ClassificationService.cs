using System.Text.Json;
using System.Text.RegularExpressions;
using Opiniones.EtlWorker.Config;
using Opiniones.EtlWorker.Models;

namespace Opiniones.EtlWorker.Services;

public sealed class ClassificationService
{
    private sealed class TerminoClasificador
    {
        public required PalabraClave Palabra { get; init; }
        public required Regex Patron { get; init; }
    }

    private readonly List<TerminoClasificador> _terminos = new();

    public ClassificationService(AppConfig config)
    {
        var json = File.ReadAllText(config.RutaPalabrasClave);
        using var documento = JsonDocument.Parse(json);

        foreach (var elemento in documento.RootElement.EnumerateArray())
        {
            var termino = elemento.GetProperty("termino").GetString()?.Trim() ?? "";
            var clasificacion = elemento.GetProperty("clasificacion").GetString() ?? "";
            var peso = elemento.TryGetProperty("peso", out var pesoElemento)
                ? pesoElemento.GetDecimal()
                : 1.0m;

            if (termino.Length == 0)
                continue;

            var palabra = new PalabraClave
            {
                Termino = termino,
                TerminoNormalizado = TextNormalizer.Normalizar(termino),
                IdClasificacion = ValidationHelper.Clasificacion(clasificacion),
                Peso = peso,
                Activa = true
            };

            if (palabra.TerminoNormalizado.Length == 0)
                continue;

            var patron = new Regex(
                $@"(?<![\p{{L}}\p{{N}}]){Regex.Escape(palabra.TerminoNormalizado)}(?![\p{{L}}\p{{N}}])",
                RegexOptions.Compiled | RegexOptions.CultureInvariant | RegexOptions.IgnoreCase);

            _terminos.Add(new TerminoClasificador { Palabra = palabra, Patron = patron });
        }

        if (_terminos.Count == 0)
            throw new InvalidOperationException(
                $"El diccionario {config.RutaPalabrasClave} no contiene palabras clave validas.");

        _terminos = _terminos
            .OrderByDescending(t => t.Palabra.TerminoNormalizado.Length)
            .ToList();
    }

    public IReadOnlyList<PalabraClave> Terminos => _terminos.Select(t => t.Palabra).ToList();

    public (byte IdClasificacion, decimal Puntaje) Clasificar(string comentario)
    {
        var texto = TextNormalizer.Normalizar(comentario);
        if (texto.Length == 0)
            return (ClasificacionIds.Neutra, 0m);

        var puntaje = 0m;
        foreach (var termino in _terminos)
        {
            if (termino.Patron.IsMatch(texto))
                puntaje += ClasificacionIds.Valor(termino.Palabra.IdClasificacion) * termino.Palabra.Peso;
        }

        puntaje = Math.Clamp(puntaje, -1m, 1m);

        var id = puntaje > 0m
            ? ClasificacionIds.Positiva
            : puntaje < 0m
                ? ClasificacionIds.Negativa
                : ClasificacionIds.Neutra;

        return (id, puntaje);
    }

    public (byte IdClasificacion, decimal Puntaje) ClasificarResenaWeb(string comentario, int rating)
    {
        var (id, puntaje) = Clasificar(comentario);

        if (id == ClasificacionIds.Neutra)
        {
            id = rating >= 4
                ? ClasificacionIds.Positiva
                : rating == 3
                    ? ClasificacionIds.Neutra
                    : ClasificacionIds.Negativa;

            puntaje = ClasificacionIds.Valor(id);
        }

        return (id, puntaje);
    }
}
