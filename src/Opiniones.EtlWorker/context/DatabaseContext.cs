using System.Data;
using Microsoft.Data.SqlClient;

namespace Opiniones.EtlWorker.Context;

public sealed class DatabaseContext : IDisposable
{
    private readonly SqlConnection _conexion;
    private SqlTransaction? _transaccion;
    private bool _disposed;

    public DatabaseContext(Config.AppConfig config)
    {
        _conexion = new SqlConnection(config.ConnectionString);
    }

    public SqlConnection Conexion => _conexion;

    public void Abrir()
    {
        if (_conexion.State != ConnectionState.Open)
            _conexion.Open();
    }

    public void IniciarTransaccion()
    {
        Abrir();
        _transaccion = _conexion.BeginTransaction(IsolationLevel.ReadCommitted);
    }

    public SqlCommand CrearComandoSp(string procedimiento)
    {
        var comando = _conexion.CreateCommand();
        comando.CommandText = procedimiento;
        comando.CommandType = CommandType.StoredProcedure;
        comando.Transaction = _transaccion;
        comando.CommandTimeout = 120;
        return comando;
    }

    public SqlCommand CrearComandoSql(string sql)
    {
        var comando = _conexion.CreateCommand();
        comando.CommandText = sql;
        comando.CommandType = CommandType.Text;
        comando.Transaction = _transaccion;
        comando.CommandTimeout = 120;
        return comando;
    }

    public void Commit()
    {
        _transaccion?.Commit();
        _transaccion?.Dispose();
        _transaccion = null;
    }

    public void Rollback()
    {
        try
        {
            _transaccion?.Rollback();
        }
        catch
        {
            // Si la conexion ya se perdio no hay nada que revertir.
        }
        finally
        {
            _transaccion?.Dispose();
            _transaccion = null;
        }
    }

    public void Cerrar()
    {
        Rollback();
        if (_conexion.State != ConnectionState.Closed)
            _conexion.Close();
    }

    public void Dispose()
    {
        if (_disposed)
            return;

        Cerrar();
        _conexion.Dispose();
        _disposed = true;
    }
}
