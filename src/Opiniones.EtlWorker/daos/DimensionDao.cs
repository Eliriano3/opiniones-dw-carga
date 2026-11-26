using System.Data;
using Microsoft.Data.SqlClient;
using Opiniones.EtlWorker.Context;

namespace Opiniones.EtlWorker.Daos;

public sealed class DimensionDao
{
    private readonly DatabaseContext _db;

    public DimensionDao(DatabaseContext db)
    {
        _db = db;
    }

    public int ObtenerOInsertarCategoria(string nombre)
    {
        using var comando = _db.CrearComandoSp("etl.usp_Categoria_ObtenerOInsertar");
        comando.Parameters.Add(DaoHelper.Parametro("@Nombre", SqlDbType.NVarChar, nombre, 100));
        var salida = DaoHelper.Salida("@IdCategoria", SqlDbType.Int);
        comando.Parameters.Add(salida);

        comando.ExecuteNonQuery();
        return Convert.ToInt32(salida.Value);
    }

    public int UpsertProducto(string idOrigen, string nombre, string nombreNormalizado, int idCategoria)
    {
        using var comando = _db.CrearComandoSp("etl.usp_Producto_Upsert");
        comando.Parameters.Add(DaoHelper.Parametro("@IdProductoOrigen", SqlDbType.VarChar, idOrigen, 50));
        comando.Parameters.Add(DaoHelper.Parametro("@Nombre", SqlDbType.NVarChar, nombre, 200));
        comando.Parameters.Add(DaoHelper.Parametro("@NombreNormalizado", SqlDbType.NVarChar, nombreNormalizado, 200));
        comando.Parameters.Add(DaoHelper.Parametro("@IdCategoria", SqlDbType.Int, idCategoria));
        var salida = DaoHelper.Salida("@ProductoKey", SqlDbType.Int);
        comando.Parameters.Add(salida);

        comando.ExecuteNonQuery();
        return Convert.ToInt32(salida.Value);
    }

    public int UpsertCliente(string idOrigen, string nombre, string? email, string? pais)
    {
        using var comando = _db.CrearComandoSp("etl.usp_Cliente_Upsert");
        comando.Parameters.Add(DaoHelper.Parametro("@IdClienteOrigen", SqlDbType.VarChar, idOrigen, 50));
        comando.Parameters.Add(DaoHelper.Parametro("@Nombre", SqlDbType.NVarChar, nombre, 150));
        comando.Parameters.Add(DaoHelper.Parametro("@Email", SqlDbType.NVarChar, email, 150));
        comando.Parameters.Add(DaoHelper.Parametro("@Pais", SqlDbType.NVarChar, pais, 60));
        var salida = DaoHelper.Salida("@ClienteKey", SqlDbType.Int);
        comando.Parameters.Add(salida);

        comando.ExecuteNonQuery();
        return Convert.ToInt32(salida.Value);
    }
}
