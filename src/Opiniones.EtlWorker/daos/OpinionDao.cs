using System.Data;
using Microsoft.Data.SqlClient;
using Opiniones.EtlWorker.Context;
using Opiniones.EtlWorker.Models;

namespace Opiniones.EtlWorker.Daos;

public sealed class OpinionDao
{
    private readonly DatabaseContext _db;

    public OpinionDao(DatabaseContext db)
    {
        _db = db;
    }

    public bool Insertar(OpinionFact opinion)
    {
        using var comando = _db.CrearComandoSp("etl.usp_Opinion_Insertar");
        comando.Parameters.Add(DaoHelper.Parametro("@IdFuente", SqlDbType.TinyInt, opinion.IdFuente));
        comando.Parameters.Add(DaoHelper.Parametro("@IdOpinionOrigen", SqlDbType.VarChar, opinion.IdOpinionOrigen, 50));
        comando.Parameters.Add(DaoHelper.Parametro("@ProductoKey", SqlDbType.Int, opinion.ProductoKey));
        comando.Parameters.Add(DaoHelper.Parametro("@ClienteKey", SqlDbType.Int, opinion.ClienteKey));
        comando.Parameters.Add(DaoHelper.Parametro("@FechaKey", SqlDbType.Int, opinion.FechaKey));
        comando.Parameters.Add(DaoHelper.Parametro("@IdClasificacion", SqlDbType.TinyInt, opinion.IdClasificacion));
        comando.Parameters.Add(DaoHelper.Parametro("@FechaOpinion", SqlDbType.DateTime2, opinion.FechaOpinion));
        comando.Parameters.Add(DaoHelper.Parametro("@Comentario", SqlDbType.NVarChar, opinion.Comentario, 2000));
        comando.Parameters.Add(DaoHelper.Parametro("@Calificacion", SqlDbType.TinyInt, opinion.Calificacion));
        comando.Parameters.Add(DaoHelper.Decimal("@PuntajeSentimiento", opinion.PuntajeSentimiento));
        comando.Parameters.Add(DaoHelper.Parametro("@Plataforma", SqlDbType.NVarChar, opinion.Plataforma, 30));
        comando.Parameters.Add(DaoHelper.Parametro("@IdCarga", SqlDbType.Int, opinion.IdCarga));
        var salida = DaoHelper.Salida("@Insertado", SqlDbType.Bit);
        comando.Parameters.Add(salida);

        comando.ExecuteNonQuery();
        return salida.Value is bool insertado && insertado;
    }
}
