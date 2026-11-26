namespace Opiniones.EtlWorker.Services;

public sealed class ValidationException : Exception
{
    public ValidationException(string mensaje) : base(mensaje)
    {
    }
}

public sealed class DuplicateException : Exception
{
    public DuplicateException(string mensaje) : base(mensaje)
    {
    }
}
