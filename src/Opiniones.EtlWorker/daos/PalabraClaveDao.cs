using System.Data;
using Microsoft.Data.SqlClient;
using Opiniones.EtlWorker.Context;
using Opiniones.EtlWorker.Models;

namespace Opiniones.EtlWorker.Daos;

public sealed class PalabraClaveDao
{
    private readonly DatabaseContext _db;

    public PalabraClaveDao(DatabaseContext db)
    {
        _db = db;
    }

    public void Upsert(PalabraClave palabra)
    {
        using var comando = _db.CrearComandoSp("etl.usp_PalabraClave_Upsert");
        comando.Parameters.Add(DaoHelper.Parametro("@Termino", SqlDbType.NVarChar, palabra.Termino, 50));
        comando.Parameters.Add(DaoHelper.Parametro("@IdClasificacion", SqlDbType.TinyInt, palabra.IdClasificacion));
        comando.Parameters.Add(new SqlParameter("@Peso", SqlDbType.Decimal)
        {
            Precision = 3,
            Scale = 1,
            Value = palabra.Peso
        });
        comando.Parameters.Add(DaoHelper.Parametro("@Activa", SqlDbType.Bit, palabra.Activa));

        comando.ExecuteNonQuery();
    }
}
