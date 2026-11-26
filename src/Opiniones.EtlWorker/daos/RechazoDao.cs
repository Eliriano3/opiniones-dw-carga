using System.Data;
using Microsoft.Data.SqlClient;
using Opiniones.EtlWorker.Context;
using Opiniones.EtlWorker.Models;
using Opiniones.EtlWorker.Services;

namespace Opiniones.EtlWorker.Daos;

public sealed class RechazoDao
{
    private readonly DatabaseContext _db;

    public RechazoDao(DatabaseContext db)
    {
        _db = db;
    }

    public void Insertar(RegistroRechazado rechazo, int idCarga)
    {
        using var comando = _db.CrearComandoSp("etl.usp_Rechazo_Insertar");
        comando.Parameters.Add(DaoHelper.Parametro("@IdCarga", SqlDbType.Int, idCarga));
        comando.Parameters.Add(DaoHelper.Parametro(
            "@IdRegistroOrigen",
            SqlDbType.NVarChar,
            rechazo.IdRegistro is null ? null : ValidationHelper.Truncar(rechazo.IdRegistro, 50),
            50));
        comando.Parameters.Add(DaoHelper.Parametro(
            "@Motivo",
            SqlDbType.NVarChar,
            ValidationHelper.Truncar(rechazo.Motivo, 200),
            200));
        comando.Parameters.Add(DaoHelper.Parametro(
            "@RegistroOriginal",
            SqlDbType.NVarChar,
            rechazo.RegistroOriginal,
            -1));

        comando.ExecuteNonQuery();
    }
}
