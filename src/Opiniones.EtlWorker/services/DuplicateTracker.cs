namespace Opiniones.EtlWorker.Services;

public sealed class DuplicateTracker
{
    private readonly HashSet<int> _clientes = new();
    private readonly HashSet<string> _emails = new(StringComparer.OrdinalIgnoreCase);
    private readonly HashSet<int> _productos = new();
    private readonly HashSet<string> _encuestas = new(StringComparer.OrdinalIgnoreCase);
    private readonly HashSet<string> _resenas = new(StringComparer.OrdinalIgnoreCase);
    private readonly HashSet<string> _comentarios = new(StringComparer.OrdinalIgnoreCase);
    private readonly HashSet<string> _fuentes = new(StringComparer.OrdinalIgnoreCase);

    public HashSet<int> ClientesValidos { get; } = new();
    public HashSet<int> ProductosValidos { get; } = new();
    public HashSet<string> CategoriasValidas { get; } = new(StringComparer.OrdinalIgnoreCase);

    public void AgregarCliente(int id)
    {
        if (!_clientes.Add(id))
            throw new DuplicateException($"IdCliente {id} duplicado dentro del CSV de clientes.");

        ClientesValidos.Add(id);
    }

    public void AgregarEmail(string email)
    {
        if (!_emails.Add(email))
            throw new DuplicateException($"Email {email} duplicado dentro del CSV de clientes.");
    }

    public void AgregarProducto(int id)
    {
        if (!_productos.Add(id))
            throw new DuplicateException($"IdProducto {id} duplicado dentro del CSV de productos.");

        ProductosValidos.Add(id);
    }

    public void AgregarCategoria(string categoria) => CategoriasValidas.Add(categoria);

    public void AgregarEncuesta(string id)
    {
        if (!_encuestas.Add(id))
            throw new DuplicateException($"IdOpinion {id} duplicado dentro del CSV de encuestas.");
    }

    public void AgregarResena(string id)
    {
        if (!_resenas.Add(id))
            throw new DuplicateException($"IdReview {id} duplicado dentro del CSV de resenas web.");
    }

    public void AgregarComentario(string id)
    {
        if (!_comentarios.Add(id))
            throw new DuplicateException($"IdComment {id} duplicado dentro del CSV de comentarios sociales.");
    }

    public void AgregarFuente(string id)
    {
        if (!_fuentes.Add(id))
            throw new DuplicateException($"IdFuente {id} duplicado dentro del CSV de fuentes.");
    }

    public void ValidarCliente(int id, string email)
    {
        if (_clientes.Contains(id))
            throw new DuplicateException($"IdCliente {id} duplicado dentro del CSV de clientes.");

        if (_emails.Contains(email))
            throw new DuplicateException($"Email {email} duplicado dentro del CSV de clientes.");
    }

    public void RegistrarCliente(int id, string email)
    {
        _clientes.Add(id);
        _emails.Add(email);
        ClientesValidos.Add(id);
    }

    public void ValidarProducto(int id)
    {
        if (_productos.Contains(id))
            throw new DuplicateException($"IdProducto {id} duplicado dentro del CSV de productos.");
    }

    public void RegistrarProducto(int id)
    {
        _productos.Add(id);
        ProductosValidos.Add(id);
    }

    public bool ExisteCliente(int id) => ClientesValidos.Contains(id);
    public bool ExisteProducto(int id) => ProductosValidos.Contains(id);
    public bool ExisteCategoria(string categoria) => CategoriasValidas.Contains(categoria);
}
