using Opiniones.EtlWorker.Context;

namespace Opiniones.EtlWorker.Daos;

public sealed class ResumenDao
{
    private readonly DatabaseContext _db;

    public ResumenDao(DatabaseContext db)
    {
        _db = db;
    }

    public void Recalcular()
    {
        using var comando = _db.CrearComandoSp("etl.usp_RecalcularResumenSatisfaccion");
        comando.ExecuteNonQuery();
    }
}
