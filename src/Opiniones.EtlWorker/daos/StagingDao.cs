using System.Data;
using Microsoft.Data.SqlClient;
using Opiniones.EtlWorker.Context;
using Opiniones.EtlWorker.Models;

namespace Opiniones.EtlWorker.Daos;

public sealed class StagingDao
{
    private readonly DatabaseContext _db;

    public StagingDao(DatabaseContext db)
    {
        _db = db;
    }

    public void InsertarCliente(ClienteCsv cliente, int idCarga)
    {
        using var comando = _db.CrearComandoSp("etl.usp_Staging_Cliente_Insertar");
        comando.Parameters.Add(DaoHelper.Parametro("@IdCarga", SqlDbType.Int, idCarga));
        comando.Parameters.Add(DaoHelper.Parametro("@IdCliente", SqlDbType.NVarChar, cliente.IdOrigen.ToString(), 50));
        comando.Parameters.Add(DaoHelper.Parametro("@Nombre", SqlDbType.NVarChar, cliente.Nombre, 300));
        comando.Parameters.Add(DaoHelper.Parametro("@Email", SqlDbType.NVarChar, cliente.Email, 300));
        comando.Parameters.Add(DaoHelper.Parametro("@Pais", SqlDbType.NVarChar, null, 100));
        comando.ExecuteNonQuery();
    }

    public void InsertarProducto(ProductoCsv producto, int idCarga)
    {
        using var comando = _db.CrearComandoSp("etl.usp_Staging_Producto_Insertar");
        comando.Parameters.Add(DaoHelper.Parametro("@IdCarga", SqlDbType.Int, idCarga));
        comando.Parameters.Add(DaoHelper.Parametro("@IdProducto", SqlDbType.NVarChar, producto.IdOrigen.ToString(), 50));
        comando.Parameters.Add(DaoHelper.Parametro("@Nombre", SqlDbType.NVarChar, producto.Nombre, 300));
        comando.Parameters.Add(DaoHelper.Parametro("@Categoria", SqlDbType.NVarChar, producto.Categoria, 150));
        comando.ExecuteNonQuery();
    }

    public void InsertarEncuesta(EncuestaCsv encuesta, int idCarga)
    {
        using var comando = _db.CrearComandoSp("etl.usp_Staging_Encuesta_Insertar");
        comando.Parameters.Add(DaoHelper.Parametro("@IdCarga", SqlDbType.Int, idCarga));
        comando.Parameters.Add(DaoHelper.Parametro("@NombreArchivo", SqlDbType.NVarChar, encuesta.Archivo, 260));
        comando.Parameters.Add(DaoHelper.Parametro("@NumeroLinea", SqlDbType.Int, encuesta.NumeroLinea));
        comando.Parameters.Add(DaoHelper.Parametro("@IdOpinion", SqlDbType.NVarChar, encuesta.IdOpinion, 50));
        comando.Parameters.Add(DaoHelper.Parametro("@IdCliente", SqlDbType.NVarChar, encuesta.IdCliente.ToString(), 50));
        comando.Parameters.Add(DaoHelper.Parametro("@IdProducto", SqlDbType.NVarChar, encuesta.IdProducto.ToString(), 50));
        comando.Parameters.Add(DaoHelper.Parametro("@Fecha", SqlDbType.NVarChar, encuesta.Fecha.ToString("yyyy-MM-dd"), 50));
        comando.Parameters.Add(DaoHelper.Parametro("@Comentario", SqlDbType.NVarChar, encuesta.Comentario, -1));
        comando.Parameters.Add(DaoHelper.Parametro("@Clasificacion", SqlDbType.NVarChar, encuesta.Clasificacion, 50));
        comando.Parameters.Add(DaoHelper.Parametro("@Puntaje", SqlDbType.NVarChar, encuesta.Puntaje.ToString(), 20));
        comando.ExecuteNonQuery();
    }

    public void InsertarResenaWeb(ResenaWebCsv resena, int idCarga)
    {
        using var comando = _db.CrearComandoSp("etl.usp_Staging_ResenaWeb_Insertar");
        comando.Parameters.Add(DaoHelper.Parametro("@IdCarga", SqlDbType.Int, idCarga));
        comando.Parameters.Add(DaoHelper.Parametro("@IdResena", SqlDbType.NVarChar, resena.IdReview, 50));
        comando.Parameters.Add(DaoHelper.Parametro("@IdCliente", SqlDbType.NVarChar, $"C{resena.IdCliente:D3}", 50));
        comando.Parameters.Add(DaoHelper.Parametro("@IdProducto", SqlDbType.NVarChar, $"P{resena.IdProducto:D3}", 50));
        comando.Parameters.Add(DaoHelper.Parametro("@Fecha", SqlDbType.NVarChar, resena.Fecha.ToString("yyyy-MM-dd"), 50));
        comando.Parameters.Add(DaoHelper.Parametro("@Calificacion", SqlDbType.NVarChar, resena.Rating.ToString(), 20));
        comando.Parameters.Add(DaoHelper.Parametro("@Titulo", SqlDbType.NVarChar, null, 300));
        comando.Parameters.Add(DaoHelper.Parametro("@Comentario", SqlDbType.NVarChar, resena.Comentario, -1));
        comando.ExecuteNonQuery();
    }

    public void InsertarComentarioSocial(ComentarioSocialCsv comentario, int idCarga)
    {
        using var comando = _db.CrearComandoSp("etl.usp_Staging_ComentarioSocial_Insertar");
        comando.Parameters.Add(DaoHelper.Parametro("@IdCarga", SqlDbType.Int, idCarga));
        comando.Parameters.Add(DaoHelper.Parametro("@IdComentario", SqlDbType.NVarChar, comentario.IdComment, 50));
        comando.Parameters.Add(DaoHelper.Parametro(
            "@IdCliente",
            SqlDbType.NVarChar,
            comentario.IdCliente.HasValue ? $"C{comentario.IdCliente.Value:D3}" : null,
            50));
        comando.Parameters.Add(DaoHelper.Parametro("@IdProducto", SqlDbType.NVarChar, $"P{comentario.IdProducto:D3}", 50));
        comando.Parameters.Add(DaoHelper.Parametro("@Plataforma", SqlDbType.NVarChar, comentario.Plataforma, 50));
        comando.Parameters.Add(DaoHelper.Parametro("@Fecha", SqlDbType.NVarChar, comentario.Fecha.ToString("yyyy-MM-dd"), 50));
        comando.Parameters.Add(DaoHelper.Parametro("@Comentario", SqlDbType.NVarChar, comentario.Comentario, -1));
        comando.Parameters.Add(DaoHelper.Parametro("@JsonOriginal", SqlDbType.NVarChar, null, -1));
        comando.ExecuteNonQuery();
    }
}
