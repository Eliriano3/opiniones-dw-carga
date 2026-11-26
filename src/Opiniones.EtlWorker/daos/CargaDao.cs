using System.Data;
using Microsoft.Data.SqlClient;
using Opiniones.EtlWorker.Context;

namespace Opiniones.EtlWorker.Daos;

public sealed class CargaDao
{
    private readonly DatabaseContext _db;

    public CargaDao(DatabaseContext db)
    {
        _db = db;
    }

    public int Insertar(byte idFuente, string detalle)
    {
        using var comando = _db.CrearComandoSp("etl.usp_Carga_Insertar");
        comando.Parameters.Add(DaoHelper.Parametro("@IdFuente", SqlDbType.TinyInt, idFuente));
        comando.Parameters.Add(DaoHelper.Parametro("@Detalle", SqlDbType.NVarChar, detalle, 500));
        var salida = DaoHelper.Salida("@IdCarga", SqlDbType.Int);
        comando.Parameters.Add(salida);

        comando.ExecuteNonQuery();
        return Convert.ToInt32(salida.Value);
    }

    public int InsertarHistorica(byte idFuente, DateTime fechaCarga, string detalle)
    {
        using var comando = _db.CrearComandoSp("etl.usp_Carga_Historica_Insertar");
        comando.Parameters.Add(DaoHelper.Parametro("@IdFuente", SqlDbType.TinyInt, idFuente));
        comando.Parameters.Add(DaoHelper.Parametro("@FechaCarga", SqlDbType.DateTime2, fechaCarga));
        comando.Parameters.Add(DaoHelper.Parametro("@Detalle", SqlDbType.NVarChar, detalle, 500));
        var salida = DaoHelper.Salida("@IdCarga", SqlDbType.Int);
        comando.Parameters.Add(salida);

        comando.ExecuteNonQuery();
        return Convert.ToInt32(salida.Value);
    }

    public HashSet<string> ObtenerDetallesHistoricos()
    {
        using var comando = _db.CrearComandoSql(
            "SELECT Detalle FROM etl.Carga WHERE Detalle LIKE 'Carga historica%' AND Detalle IS NOT NULL");

        using var lector = comando.ExecuteReader();
        var detalles = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        while (lector.Read())
        {
            if (!lector.IsDBNull(0))
                detalles.Add(lector.GetString(0));
        }

        return detalles;
    }

    public void Actualizar(
        int idCarga,
        int leidos,
        int insertados,
        int duplicados,
        int rechazados,
        string estado,
        string detalle)
    {
        using var comando = _db.CrearComandoSp("etl.usp_Carga_Actualizar");
        comando.Parameters.Add(DaoHelper.Parametro("@IdCarga", SqlDbType.Int, idCarga));
        comando.Parameters.Add(DaoHelper.Parametro("@Leidos", SqlDbType.Int, leidos));
        comando.Parameters.Add(DaoHelper.Parametro("@Insertados", SqlDbType.Int, insertados));
        comando.Parameters.Add(DaoHelper.Parametro("@Duplicados", SqlDbType.Int, duplicados));
        comando.Parameters.Add(DaoHelper.Parametro("@Rechazados", SqlDbType.Int, rechazados));
        comando.Parameters.Add(DaoHelper.Parametro("@Estado", SqlDbType.VarChar, estado, 12));
        comando.Parameters.Add(DaoHelper.Parametro("@Detalle", SqlDbType.NVarChar, detalle, 500));

        comando.ExecuteNonQuery();
    }
}
