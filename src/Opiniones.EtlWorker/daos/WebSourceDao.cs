using System.Data;
using Microsoft.Data.SqlClient;
using Opiniones.EtlWorker.Context;

namespace Opiniones.EtlWorker.Daos;

public sealed class WebSourceDao
{
    private readonly DatabaseContext _db;

    public WebSourceDao(DatabaseContext db)
    {
        _db = db;
    }

    public int UpsertCategoria(string nombre)
    {
        using var comando = _db.CrearComandoSp("OpinionesWebDB.dbo.usp_Categoria_ObtenerOInsertar");
        comando.Parameters.Add(DaoHelper.Parametro("@Nombre", SqlDbType.NVarChar, nombre, 100));
        var salida = DaoHelper.Salida("@IdCategoria", SqlDbType.Int);
        comando.Parameters.Add(salida);

        comando.ExecuteNonQuery();
        return Convert.ToInt32(salida.Value);
    }

    public int UpsertProducto(string codigo, string nombre, int idCategoria, decimal precio, bool activo)
    {
        using var comando = _db.CrearComandoSp("OpinionesWebDB.dbo.usp_Producto_ObtenerOInsertar");
        comando.Parameters.Add(DaoHelper.Parametro("@Codigo", SqlDbType.VarChar, codigo, 20));
        comando.Parameters.Add(DaoHelper.Parametro("@Nombre", SqlDbType.NVarChar, nombre, 200));
        comando.Parameters.Add(DaoHelper.Parametro("@IdCategoria", SqlDbType.Int, idCategoria));
        comando.Parameters.Add(new SqlParameter("@Precio", SqlDbType.Decimal)
        {
            Precision = 12,
            Scale = 2,
            Value = precio
        });
        comando.Parameters.Add(DaoHelper.Parametro("@Activo", SqlDbType.Bit, activo));
        var salida = DaoHelper.Salida("@IdProducto", SqlDbType.Int);
        comando.Parameters.Add(salida);

        comando.ExecuteNonQuery();
        return Convert.ToInt32(salida.Value);
    }

    public int UpsertCliente(string nombre, string email, string? pais)
    {
        using var comando = _db.CrearComandoSp("OpinionesWebDB.dbo.usp_Cliente_ObtenerOInsertar");
        comando.Parameters.Add(DaoHelper.Parametro("@Nombre", SqlDbType.NVarChar, nombre, 150));
        comando.Parameters.Add(DaoHelper.Parametro("@Email", SqlDbType.NVarChar, email, 150));
        comando.Parameters.Add(DaoHelper.Parametro("@Pais", SqlDbType.NVarChar, pais, 60));
        var salida = DaoHelper.Salida("@IdCliente", SqlDbType.Int);
        comando.Parameters.Add(salida);

        comando.ExecuteNonQuery();
        return Convert.ToInt32(salida.Value);
    }

    public bool InsertarResena(
        int idResena,
        int idCliente,
        int idProducto,
        byte calificacion,
        string? titulo,
        string comentario,
        DateTime fechaPublicacion,
        char estado)
    {
        using var comando = _db.CrearComandoSp("OpinionesWebDB.dbo.usp_Resena_Insertar");
        comando.Parameters.Add(DaoHelper.Parametro("@IdResena", SqlDbType.Int, idResena));
        comando.Parameters.Add(DaoHelper.Parametro("@IdCliente", SqlDbType.Int, idCliente));
        comando.Parameters.Add(DaoHelper.Parametro("@IdProducto", SqlDbType.Int, idProducto));
        comando.Parameters.Add(DaoHelper.Parametro("@Calificacion", SqlDbType.TinyInt, calificacion));
        comando.Parameters.Add(DaoHelper.Parametro("@Titulo", SqlDbType.NVarChar, titulo, 150));
        comando.Parameters.Add(DaoHelper.Parametro("@Comentario", SqlDbType.NVarChar, comentario, 2000));
        comando.Parameters.Add(DaoHelper.Parametro("@FechaPublicacion", SqlDbType.DateTime2, fechaPublicacion));
        comando.Parameters.Add(DaoHelper.Parametro("@Estado", SqlDbType.Char, estado.ToString(), 1));
        var salida = DaoHelper.Salida("@Insertado", SqlDbType.Bit);
        comando.Parameters.Add(salida);

        comando.ExecuteNonQuery();
        return salida.Value is bool insertado && insertado;
    }
}
