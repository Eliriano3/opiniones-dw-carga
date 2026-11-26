using System.Text.Json;
using Opiniones.EtlWorker.Config;

namespace Opiniones.EtlWorker.Services;

public sealed class PricingService
{
    private sealed class RangoPrecio
    {
        public decimal Base { get; init; }
        public decimal Variacion { get; init; }
    }

    private readonly Dictionary<string, RangoPrecio> _rangos;

    public PricingService(AppConfig config)
    {
        var json = File.ReadAllText(config.RutaPrecios);
        using var documento = JsonDocument.Parse(json);

        _rangos = new Dictionary<string, RangoPrecio>(StringComparer.OrdinalIgnoreCase);

        foreach (var elemento in documento.RootElement.EnumerateArray())
        {
            var categoria = elemento.GetProperty("categoria").GetString()?.Trim() ?? "";
            if (categoria.Length == 0)
                continue;

            _rangos[categoria] = new RangoPrecio
            {
                Base = elemento.GetProperty("base").GetDecimal(),
                Variacion = elemento.GetProperty("variacion").GetDecimal()
            };
        }

        if (_rangos.Count == 0)
            throw new InvalidOperationException(
                $"El archivo de precios {config.RutaPrecios} no contiene categorias validas.");
    }

    public decimal Calcular(string categoria, int idProducto)
    {
        if (!_rangos.TryGetValue(categoria, out var rango))
        {
            throw new ValidationException(
                $"Precio: no hay un rango configurado para la categoria '{categoria}'.");
        }

        var factor = ((idProducto * 37) % 100) / 100m;
        var precio = rango.Base + factor * rango.Variacion;

        return Math.Round(precio, 2, MidpointRounding.AwayFromZero);
    }
}
