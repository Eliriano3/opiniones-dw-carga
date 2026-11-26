using System.Data;
using Microsoft.Data.SqlClient;

namespace Opiniones.EtlWorker.Daos;

internal static class DaoHelper
{
    public static SqlParameter Parametro(string nombre, SqlDbType tipo, object? valor, int tamano = 0)
    {
        var parametro = tamano != 0
            ? new SqlParameter(nombre, tipo, tamano)
            : new SqlParameter(nombre, tipo);

        parametro.Value = valor ?? DBNull.Value;
        return parametro;
    }

    public static SqlParameter Decimal(string nombre, decimal? valor)
    {
        var parametro = new SqlParameter(nombre, SqlDbType.Decimal)
        {
            Precision = 5,
            Scale = 2,
            Value = valor.HasValue ? valor.Value : DBNull.Value
        };

        return parametro;
    }

    public static SqlParameter Salida(string nombre, SqlDbType tipo)
    {
        return new SqlParameter(nombre, tipo) { Direction = ParameterDirection.Output };
    }
}
