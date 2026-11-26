using System.Globalization;
using Microsoft.Data.SqlClient;

namespace Opiniones.EtlWorker.Config;

public static class ConfigLoader
{
    public static AppConfig Cargar()
    {
        var rutaEnv = BuscarArchivoEnv();
        var valores = LeerArchivoEnv(rutaEnv);
        var directorioConfig = Path.GetDirectoryName(rutaEnv)
            ?? throw new InvalidOperationException("No se pudo determinar la carpeta de configuracion.");
        var raiz = Directory.GetParent(directorioConfig)?.FullName
            ?? throw new InvalidOperationException("No se pudo determinar la raiz del proyecto.");

        var host = Obtener(valores, "DB_HOST", obligatorio: true);
        var puerto = Obtener(valores, "DB_PORT", obligatorio: false, porDefecto: "1433");
        var instancia = Obtener(valores, "DB_INSTANCE", obligatorio: false);
        var baseDatos = Obtener(valores, "DB_NAME", obligatorio: true);
        var usuario = Obtener(valores, "DB_USER", obligatorio: true);
        var clave = Obtener(valores, "DB_PASSWORD", obligatorio: true);

        var dataInput = ResolverRuta(raiz, Obtener(valores, "DATA_INPUT", false, "./data/input"));
        var logs = ResolverRuta(raiz, Obtener(valores, "LOG_DIR", false, "./logs"));
        var archivoPalabras = Obtener(valores, "ARCHIVO_PALABRAS_CLAVE", false, "palabras_clave.json");
        var rutaPalabras = Path.Combine(directorioConfig, archivoPalabras);
        var archivoPrecios = Obtener(valores, "ARCHIVO_PRECIOS", false, "precios_categorias.json");
        var rutaPrecios = Path.Combine(directorioConfig, archivoPrecios);

        if (!Directory.Exists(dataInput))
            throw new DirectoryNotFoundException($"No existe la carpeta de CSV: {dataInput}");
        if (!File.Exists(rutaPalabras))
            throw new FileNotFoundException($"No existe el diccionario de palabras clave: {rutaPalabras}", rutaPalabras);
        if (!File.Exists(rutaPrecios))
            throw new FileNotFoundException($"No existe el archivo de precios: {rutaPrecios}", rutaPrecios);

        var connectionStringBuilder = new SqlConnectionStringBuilder
        {
            DataSource = string.IsNullOrWhiteSpace(instancia) ? $"{host},{puerto}" : $"{host}\\{instancia}",
            InitialCatalog = baseDatos,
            UserID = usuario,
            Password = clave,
            Encrypt = ParseBool(Obtener(valores, "DB_ENCRYPT", false, "true")),
            TrustServerCertificate = ParseBool(Obtener(valores, "DB_TRUST_SERVER_CERTIFICATE", false, "true")),
            ConnectTimeout = 15,
            ApplicationName = "OpinionesETL",
            Pooling = true
        };

        return new AppConfig
        {
            DbHost = host,
            DbPort = puerto,
            DbInstance = instancia,
            DbName = baseDatos,
            DbUser = usuario,
            DbPassword = clave,
            DbEncrypt = connectionStringBuilder.Encrypt,
            DbTrustServerCertificate = connectionStringBuilder.TrustServerCertificate,
            RaizProyecto = raiz,
            RutaConfig = rutaEnv,
            RutaDataInput = dataInput,
            RutaLogs = logs,
            RutaPalabrasClave = rutaPalabras,
            RutaPrecios = rutaPrecios,
            ArchivoClientes = Obtener(valores, "ARCHIVO_CLIENTES", false, "clientes.csv"),
            ArchivoProductos = Obtener(valores, "ARCHIVO_PRODUCTOS", false, "productos.csv"),
            ArchivoEncuestas = Obtener(valores, "ARCHIVO_ENCUESTAS", false, "encuestas.csv"),
            ArchivoResenasWeb = Obtener(valores, "ARCHIVO_RESENAS_WEB", false, "resenas_web.csv"),
            ArchivoComentarios = Obtener(valores, "ARCHIVO_COMENTARIOS", false, "comentarios_sociales.csv"),
            ArchivoFuentes = Obtener(valores, "ARCHIVO_FUENTES", false, "fuentes.csv"),
            ConnectionString = connectionStringBuilder.ConnectionString
        };
    }

    private static string BuscarArchivoEnv()
    {
        foreach (var inicio in new[] { Directory.GetCurrentDirectory(), AppContext.BaseDirectory })
        {
            var directorio = new DirectoryInfo(inicio);
            for (var i = 0; i < 8 && directorio is not null; i++, directorio = directorio.Parent)
            {
                var candidato = Path.Combine(directorio.FullName, "config", ".env");
                if (File.Exists(candidato))
                    return candidato;
            }
        }

        throw new FileNotFoundException(
            "No se encontro config/.env. Copia config/.env.example como config/.env y completa los datos.");
    }

    private static Dictionary<string, string> LeerArchivoEnv(string ruta)
    {
        var valores = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        foreach (var linea in File.ReadAllLines(ruta))
        {
            var texto = linea.Trim();
            if (texto.Length == 0 || texto.StartsWith('#'))
                continue;

            var indice = texto.IndexOf('=');
            if (indice <= 0)
                continue;

            var clave = texto[..indice].Trim();
            var valor = texto[(indice + 1)..].Trim();
            if (valor.Length >= 2 && valor[0] == '"' && valor[^1] == '"')
                valor = valor[1..^1];

            valores[clave] = valor;
        }

        foreach (var clave in valores.Keys.ToList())
        {
            var desdeEntorno = Environment.GetEnvironmentVariable(clave);
            if (!string.IsNullOrWhiteSpace(desdeEntorno))
                valores[clave] = desdeEntorno;
        }

        return valores;
    }

    private static string Obtener(
        IReadOnlyDictionary<string, string> valores,
        string clave,
        bool obligatorio,
        string? porDefecto = null)
    {
        if (valores.TryGetValue(clave, out var valor) && !string.IsNullOrWhiteSpace(valor))
            return valor.Trim();

        if (obligatorio)
            throw new InvalidOperationException($"Falta la variable obligatoria {clave} en config/.env.");

        return porDefecto ?? "";
    }

    private static string ResolverRuta(string raiz, string ruta)
    {
        return Path.IsPathRooted(ruta)
            ? Path.GetFullPath(ruta)
            : Path.GetFullPath(Path.Combine(raiz, ruta));
    }

    private static bool ParseBool(string valor)
    {
        return bool.TryParse(valor, out var resultado) && resultado;
    }
}
