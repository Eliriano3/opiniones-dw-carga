using System.Text.Json;
using System.Text.RegularExpressions;
using Opiniones.EtlWorker.Config;
using Opiniones.EtlWorker.Context;
using Opiniones.EtlWorker.CsvReaders;
using Opiniones.EtlWorker.Daos;
using Opiniones.EtlWorker.Models;

namespace Opiniones.EtlWorker.Services;

public sealed class ImportService
{
    private readonly AppConfig _config;
    private readonly ClienteCsvReader _clientesReader;
    private readonly ProductoCsvReader _productosReader;
    private readonly EncuestaCsvReader _encuestasReader;
    private readonly ResenaWebCsvReader _resenasReader;
    private readonly ComentarioSocialCsvReader _comentariosReader;
    private readonly FuenteCsvReader _fuentesReader;
    private readonly DatabaseContext _db;
    private readonly CargaDao _cargaDao;
    private readonly StagingDao _stagingDao;
    private readonly DimensionDao _dimensionDao;
    private readonly OpinionDao _opinionDao;
    private readonly RechazoDao _rechazoDao;
    private readonly WebSourceDao _webSourceDao;
    private readonly PalabraClaveDao _palabraClaveDao;
    private readonly ResumenDao _resumenDao;
    private readonly ClassificationService _clasificador;
    private readonly PricingService _pricing;
    private readonly LogService _log;

    public ImportService(
        AppConfig config,
        ClienteCsvReader clientesReader,
        ProductoCsvReader productosReader,
        EncuestaCsvReader encuestasReader,
        ResenaWebCsvReader resenasReader,
        ComentarioSocialCsvReader comentariosReader,
        FuenteCsvReader fuentesReader,
        DatabaseContext db,
        CargaDao cargaDao,
        StagingDao stagingDao,
        DimensionDao dimensionDao,
        OpinionDao opinionDao,
        RechazoDao rechazoDao,
        WebSourceDao webSourceDao,
        PalabraClaveDao palabraClaveDao,
        ResumenDao resumenDao,
        ClassificationService clasificador,
        PricingService pricing,
        LogService log)
    {
        _config = config;
        _clientesReader = clientesReader;
        _productosReader = productosReader;
        _encuestasReader = encuestasReader;
        _resenasReader = resenasReader;
        _comentariosReader = comentariosReader;
        _fuentesReader = fuentesReader;
        _db = db;
        _cargaDao = cargaDao;
        _stagingDao = stagingDao;
        _dimensionDao = dimensionDao;
        _opinionDao = opinionDao;
        _rechazoDao = rechazoDao;
        _webSourceDao = webSourceDao;
        _palabraClaveDao = palabraClaveDao;
        _resumenDao = resumenDao;
        _clasificador = clasificador;
        _pricing = pricing;
        _log = log;
    }

    public Task<ResultadoEtl> EjecutarAsync(bool dryRun, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();

        var resultado = new ResultadoEtl
        {
            Inicio = DateTime.Now,
            Simulacion = dryRun
        };

        DatasetCsv? dataset = null;

        try
        {
            dataset = ExtraerYValidar();
            resultado.Metricas = dataset.Metricas;
            resultado.Rechazos = dataset.Rechazos;

            if (dryRun)
                Simular(dataset, resultado);
            else
                Cargar(dataset, resultado);
        }
        catch (Exception ex)
        {
            resultado.ErrorCritico = ex.Message;
        }
        finally
        {
            resultado.Fin = DateTime.Now;

            try
            {
                resultado.RutaLog = _log.Guardar(resultado);
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"No se pudo escribir el log: {ex.Message}");
            }
        }

        return Task.FromResult(resultado);
    }

    private DatasetCsv ExtraerYValidar()
    {
        var dataset = new DatasetCsv();
        var duplicados = new DuplicateTracker();

        ExtraerClientes(dataset, duplicados);
        ExtraerProductos(dataset, duplicados);
        ExtraerCategorias(dataset, duplicados);
        ExtraerEncuestas(dataset, duplicados);
        ExtraerResenasWeb(dataset, duplicados);
        ExtraerComentariosSociales(dataset, duplicados);
        ExtraerFuentes(dataset, duplicados);

        return dataset;
    }

    private void ExtraerClientes(DatasetCsv dataset, DuplicateTracker duplicados)
    {
        var lectura = _clientesReader.Leer(_config.RutaDataInput, _config.ArchivoClientes);
        dataset.Rechazos.AddRange(lectura.Rechazos);
        var repetidos = 0;

        foreach (var cliente in lectura.Filas)
        {
            try
            {
                cliente.Nombre = ValidationHelper.Texto(cliente.Nombre, 150, "Nombre", soloLetras: true);
                cliente.Email = ValidationHelper.Email(cliente.Email);
                duplicados.ValidarCliente(cliente.IdOrigen, cliente.Email);
                duplicados.RegistrarCliente(cliente.IdOrigen, cliente.Email);
                dataset.Clientes.Add(cliente);
            }
            catch (Exception ex)
            {
                if (ex is DuplicateException)
                    repetidos++;

                dataset.Rechazos.Add(CrearRechazo(
                    "Clientes", cliente.Archivo, cliente.NumeroLinea,
                    cliente.IdOrigen.ToString(), ex.Message, cliente));
            }
        }

        dataset.Metricas.Add(CrearMetrica(
            "Clientes", lectura.Procesados, dataset.Clientes.Count, dataset, repetidos));
    }

    private void ExtraerProductos(DatasetCsv dataset, DuplicateTracker duplicados)
    {
        var lectura = _productosReader.Leer(_config.RutaDataInput, _config.ArchivoProductos);
        dataset.Rechazos.AddRange(lectura.Rechazos);
        var repetidos = 0;

        foreach (var producto in lectura.Filas)
        {
            try
            {
                producto.Nombre = ValidationHelper.Texto(producto.Nombre, 200, "Nombre", soloLetras: true);
                producto.Categoria = ValidationHelper.Texto(producto.Categoria, 100, "Categoría", soloLetras: true);

                if (TextNormalizer.Normalizar(producto.Nombre).Length == 0)
                    throw new ValidationException("Nombre: no contiene letras ni numeros utiles.");

                producto.Precio = _pricing.Calcular(producto.Categoria, producto.IdOrigen);

                duplicados.ValidarProducto(producto.IdOrigen);
                duplicados.RegistrarProducto(producto.IdOrigen);
                duplicados.AgregarCategoria(producto.Categoria);
                dataset.Productos.Add(producto);
            }
            catch (Exception ex)
            {
                if (ex is DuplicateException)
                    repetidos++;

                dataset.Rechazos.Add(CrearRechazo(
                    "Productos", producto.Archivo, producto.NumeroLinea,
                    producto.IdOrigen.ToString(), ex.Message, producto));
            }
        }

        dataset.Metricas.Add(CrearMetrica(
            "Productos", lectura.Procesados, dataset.Productos.Count, dataset, repetidos));
    }

    private void ExtraerCategorias(DatasetCsv dataset, DuplicateTracker duplicados)
    {
        foreach (var categoria in duplicados.CategoriasValidas.OrderBy(c => c, StringComparer.OrdinalIgnoreCase))
            dataset.Categorias.Add(categoria);

        var metrica = CrearMetrica(
            "Categorias", dataset.Categorias.Count, dataset.Categorias.Count, dataset);
        metrica.Nota = "Categorias distintas derivadas del CSV de productos.";
        dataset.Metricas.Add(metrica);
    }

    private void ExtraerEncuestas(DatasetCsv dataset, DuplicateTracker duplicados)
    {
        var lectura = _encuestasReader.Leer(_config.RutaDataInput, _config.ArchivoEncuestas);
        dataset.Rechazos.AddRange(lectura.Rechazos);
        var repetidos = 0;

        foreach (var encuesta in lectura.Filas)
        {
            try
            {
                encuesta.IdOpinion = ValidationHelper.Texto(encuesta.IdOpinion, 50, "IdOpinion");

                if (!duplicados.ExisteCliente(encuesta.IdCliente))
                {
                    throw new ValidationException(
                        $"IdCliente {encuesta.IdCliente} no existe en el catalogo de clientes (FK).");
                }

                if (!duplicados.ExisteProducto(encuesta.IdProducto))
                {
                    throw new ValidationException(
                        $"IdProducto {encuesta.IdProducto} no existe en el catalogo de productos (FK).");
                }

                ValidationHelper.FechaKey(encuesta.Fecha);
                encuesta.Comentario = ValidationHelper.Texto(encuesta.Comentario, 2000, "Comentario");

                var clasificacion = ValidationHelper.Clasificacion(encuesta.Clasificacion);
                ValidationHelper.ValidarConsistenciaClasificacion(
                    clasificacion, encuesta.Puntaje, encuesta.IdOpinion);

                encuesta.Fuente = ValidationHelper.Texto(encuesta.Fuente, 50, "Fuente");
                if (!encuesta.Fuente.Equals("EncuestaInterna", StringComparison.OrdinalIgnoreCase))
                {
                    throw new ValidationException(
                        $"Fuente: '{encuesta.Fuente}' no corresponde a una encuesta interna.");
                }

                duplicados.AgregarEncuesta(encuesta.IdOpinion);
                dataset.Encuestas.Add(encuesta);
            }
            catch (Exception ex)
            {
                if (ex is DuplicateException)
                    repetidos++;

                dataset.Rechazos.Add(CrearRechazo(
                    "Encuestas", encuesta.Archivo, encuesta.NumeroLinea,
                    encuesta.IdOpinion, ex.Message, encuesta));
            }
        }

        var metrica = CrearMetrica(
            "Encuestas", lectura.Procesados, dataset.Encuestas.Count, dataset, repetidos);
        metrica.Nota = "Las encuestas con cliente o producto inexistente se rechazan por integridad referencial.";
        dataset.Metricas.Add(metrica);
    }

    private void ExtraerResenasWeb(DatasetCsv dataset, DuplicateTracker duplicados)
    {
        var lectura = _resenasReader.Leer(_config.RutaDataInput, _config.ArchivoResenasWeb);
        dataset.Rechazos.AddRange(lectura.Rechazos);
        var repetidos = 0;

        foreach (var resena in lectura.Filas)
        {
            try
            {
                resena.IdReview = ValidationHelper.Texto(resena.IdReview, 50, "IdReview");

                if (!Regex.IsMatch(resena.IdReview, @"^W\d{4}$", RegexOptions.CultureInvariant))
                {
                    throw new ValidationException(
                        $"IdReview: '{resena.IdReview}' no tiene el formato W0000.");
                }

                resena.IdResena = ValidationHelper.Entero(
                    resena.IdReview[1..], "IdResena", 1, int.MaxValue);

                if (!duplicados.ExisteCliente(resena.IdCliente))
                {
                    throw new ValidationException(
                        $"IdCliente {resena.IdCliente} no existe en el catalogo de clientes (FK).");
                }

                if (!duplicados.ExisteProducto(resena.IdProducto))
                {
                    throw new ValidationException(
                        $"IdProducto {resena.IdProducto} no existe en el catalogo de productos (FK).");
                }

                ValidationHelper.FechaKey(resena.Fecha);
                resena.Comentario = ValidationHelper.Texto(resena.Comentario, 2000, "Comentario");

                duplicados.AgregarResena(resena.IdReview);
                dataset.ResenasWeb.Add(resena);
            }
            catch (Exception ex)
            {
                if (ex is DuplicateException)
                    repetidos++;

                dataset.Rechazos.Add(CrearRechazo(
                    "ResenasWeb", resena.Archivo, resena.NumeroLinea,
                    resena.IdReview, ex.Message, resena));
            }
        }

        dataset.Metricas.Add(CrearMetrica(
            "ResenasWeb", lectura.Procesados, dataset.ResenasWeb.Count, dataset, repetidos));
    }

    private void ExtraerComentariosSociales(DatasetCsv dataset, DuplicateTracker duplicados)
    {
        var lectura = _comentariosReader.Leer(_config.RutaDataInput, _config.ArchivoComentarios);
        dataset.Rechazos.AddRange(lectura.Rechazos);
        var repetidos = 0;

        foreach (var comentario in lectura.Filas)
        {
            try
            {
                comentario.IdComment = ValidationHelper.Texto(comentario.IdComment, 50, "IdComment");

                if (!duplicados.ExisteProducto(comentario.IdProducto))
                {
                    throw new ValidationException(
                        $"IdProducto {comentario.IdProducto} no existe en el catalogo de productos (FK).");
                }

                if (comentario.IdCliente.HasValue && !duplicados.ExisteCliente(comentario.IdCliente.Value))
                {
                    throw new ValidationException(
                        $"IdCliente {comentario.IdCliente.Value} no existe en el catalogo de clientes (FK).");
                }

                ValidationHelper.FechaKey(comentario.Fecha);
                comentario.Comentario = ValidationHelper.Texto(comentario.Comentario, 2000, "Comentario");
                comentario.Plataforma = ValidationHelper.Texto(comentario.Plataforma, 30, "Plataforma");

                duplicados.AgregarComentario(comentario.IdComment);
                dataset.ComentariosSociales.Add(comentario);
            }
            catch (Exception ex)
            {
                if (ex is DuplicateException)
                    repetidos++;

                dataset.Rechazos.Add(CrearRechazo(
                    "ComentariosSociales", comentario.Archivo, comentario.NumeroLinea,
                    comentario.IdComment, ex.Message, comentario));
            }
        }

        dataset.Metricas.Add(CrearMetrica(
            "ComentariosSociales", lectura.Procesados, dataset.ComentariosSociales.Count, dataset, repetidos));
    }

    private void ExtraerFuentes(DatasetCsv dataset, DuplicateTracker duplicados)
    {
        var lectura = _fuentesReader.Leer(_config.RutaDataInput, _config.ArchivoFuentes);
        dataset.Rechazos.AddRange(lectura.Rechazos);
        var repetidos = 0;

        foreach (var fuente in lectura.Filas)
        {
            try
            {
                fuente.IdFuente = ValidationHelper.Texto(fuente.IdFuente, 10, "IdFuente");

                if (!Regex.IsMatch(fuente.IdFuente, @"^F\d{3}$", RegexOptions.CultureInvariant))
                    throw new ValidationException($"IdFuente: '{fuente.IdFuente}' no tiene el formato F000.");

                ValidationHelper.TipoFuente(fuente.TipoFuente);
                if (fuente.FechaCarga.Year < 2020 || fuente.FechaCarga.Year > 2030)
                {
                    throw new ValidationException(
                        $"FechaCarga: {fuente.FechaCarga:yyyy-MM-dd} esta fuera del rango 2020 a 2030.");
                }

                duplicados.AgregarFuente(fuente.IdFuente);
                dataset.Fuentes.Add(fuente);
            }
            catch (Exception ex)
            {
                if (ex is DuplicateException)
                    repetidos++;

                dataset.Rechazos.Add(CrearRechazo(
                    "Fuentes", fuente.Archivo, fuente.NumeroLinea,
                    fuente.IdFuente, ex.Message, fuente));
            }
        }

        var metrica = CrearMetrica(
            "Fuentes", lectura.Procesados, dataset.Fuentes.Count, dataset, repetidos);
        metrica.Nota = "Catalogo de cargas historicas que se inserta en etl.Carga.";
        dataset.Metricas.Add(metrica);
    }

    private void Simular(DatasetCsv dataset, ResultadoEtl resultado)
    {
        resultado.HechosInsertados =
            dataset.Encuestas.Count + dataset.ResenasWeb.Count + dataset.ComentariosSociales.Count;
        resultado.HechosDuplicados = 0;
        resultado.ClientesGenericos = dataset.ComentariosSociales.Count(c => !c.IdCliente.HasValue);
        resultado.CargasHistoricas = dataset.Fuentes.Count;

        var metricaSocial = dataset.BuscarMetrica("ComentariosSociales");
        if (metricaSocial is not null)
            metricaSocial.Nota = $"{resultado.ClientesGenericos} comentarios sin cliente usan el cliente SIN_CLIENTE.";
    }

    private void Cargar(DatasetCsv dataset, ResultadoEtl resultado)
    {
        _db.Abrir();
        _db.IniciarTransaccion();

        try
        {
            var idCargaMaestros = _cargaDao.Insertar(FuenteIds.Csv, "ETL maestros CSV");
            var idCargaEncuestas = _cargaDao.Insertar(FuenteIds.Csv, "ETL encuestas CSV");
            var idCargaWeb = _cargaDao.Insertar(FuenteIds.Web, "ETL resenas web CSV");
            var idCargaSocial = _cargaDao.Insertar(FuenteIds.Social, "ETL comentarios sociales CSV");
            var idCargaFuentes = _cargaDao.Insertar(FuenteIds.Csv, "ETL catalogo de fuentes");
            var metricaFuentes = dataset.BuscarMetrica("Fuentes")!;

            foreach (var palabra in _clasificador.Terminos)
                _palabraClaveDao.Upsert(palabra);

            var detallesHistoricos = _cargaDao.ObtenerDetallesHistoricos();
            var fuentesInsertadas = 0;
            var fuentesDuplicadas = 0;

            foreach (var fuente in dataset.Fuentes)
            {
                var detalle = $"Carga historica {fuente.IdFuente} ({fuente.TipoFuente})";
                if (!detallesHistoricos.Add(detalle))
                {
                    fuentesDuplicadas++;
                    continue;
                }

                var tipo = ValidationHelper.TipoFuente(fuente.TipoFuente);
                _cargaDao.InsertarHistorica(tipo, fuente.FechaCarga, detalle);

                fuentesInsertadas++;
                resultado.CargasHistoricas++;
            }

            metricaFuentes.Insertados = fuentesInsertadas;
            metricaFuentes.Duplicados += fuentesDuplicadas;

            var categoriaIds = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            foreach (var categoria in dataset.Categorias)
                categoriaIds[categoria] = _dimensionDao.ObtenerOInsertarCategoria(categoria);

            var clienteIds = new Dictionary<int, int>();
            foreach (var cliente in dataset.Clientes)
            {
                _stagingDao.InsertarCliente(cliente, idCargaMaestros);
                clienteIds[cliente.IdOrigen] = _dimensionDao.UpsertCliente(
                    cliente.IdOrigen.ToString(), cliente.Nombre, cliente.Email, null);
            }

            var clienteGenericoKey = _dimensionDao.UpsertCliente(
                "SIN_CLIENTE", "No identificado", null, null);

            resultado.ClientesGenericos = dataset.ComentariosSociales.Count(c => !c.IdCliente.HasValue);

            var productoIds = new Dictionary<int, int>();
            foreach (var producto in dataset.Productos)
            {
                _stagingDao.InsertarProducto(producto, idCargaMaestros);
                var idCategoria = categoriaIds[producto.Categoria];
                productoIds[producto.IdOrigen] = _dimensionDao.UpsertProducto(
                    producto.IdOrigen.ToString(),
                    producto.Nombre,
                    TextNormalizer.Normalizar(producto.Nombre),
                    idCategoria);
            }

            var metricaEncuestas = dataset.BuscarMetrica("Encuestas")!;
            var encuestasInsertadas = 0;
            var encuestasDuplicadas = 0;

            foreach (var encuesta in dataset.Encuestas)
            {
                _stagingDao.InsertarEncuesta(encuesta, idCargaEncuestas);

                var clasificacion = ValidationHelper.Clasificacion(encuesta.Clasificacion);
                var hechos = new OpinionFact
                {
                    IdFuente = FuenteIds.Csv,
                    IdOpinionOrigen = encuesta.IdOpinion,
                    ProductoKey = productoIds[encuesta.IdProducto],
                    ClienteKey = clienteIds[encuesta.IdCliente],
                    FechaKey = ValidationHelper.FechaKey(encuesta.Fecha),
                    IdClasificacion = clasificacion,
                    FechaOpinion = encuesta.Fecha,
                    Comentario = encuesta.Comentario,
                    Calificacion = (byte)encuesta.Puntaje,
                    PuntajeSentimiento = ClasificacionIds.Valor(clasificacion),
                    Plataforma = null,
                    IdCarga = idCargaEncuestas
                };

                if (_opinionDao.Insertar(hechos))
                    encuestasInsertadas++;
                else
                    encuestasDuplicadas++;
            }

            metricaEncuestas.Insertados = encuestasInsertadas;
            metricaEncuestas.Duplicados += encuestasDuplicadas;

            var metricaWeb = dataset.BuscarMetrica("ResenasWeb")!;
            var webInsertadas = 0;
            var webDuplicadas = 0;

            foreach (var resena in dataset.ResenasWeb)
            {
                _stagingDao.InsertarResenaWeb(resena, idCargaWeb);

                var (clasificacion, puntaje) =
                    _clasificador.ClasificarResenaWeb(resena.Comentario, resena.Rating);

                var hechos = new OpinionFact
                {
                    IdFuente = FuenteIds.Web,
                    IdOpinionOrigen = resena.IdReview,
                    ProductoKey = productoIds[resena.IdProducto],
                    ClienteKey = clienteIds[resena.IdCliente],
                    FechaKey = ValidationHelper.FechaKey(resena.Fecha),
                    IdClasificacion = clasificacion,
                    FechaOpinion = resena.Fecha,
                    Comentario = resena.Comentario,
                    Calificacion = (byte)resena.Rating,
                    PuntajeSentimiento = puntaje,
                    Plataforma = null,
                    IdCarga = idCargaWeb
                };

                if (_opinionDao.Insertar(hechos))
                    webInsertadas++;
                else
                    webDuplicadas++;
            }

            metricaWeb.Insertados = webInsertadas;
            metricaWeb.Duplicados += webDuplicadas;

            var metricaSocial = dataset.BuscarMetrica("ComentariosSociales")!;
            var socialInsertadas = 0;
            var socialDuplicadas = 0;

            foreach (var comentario in dataset.ComentariosSociales)
            {
                _stagingDao.InsertarComentarioSocial(comentario, idCargaSocial);

                var (clasificacion, puntaje) = _clasificador.Clasificar(comentario.Comentario);
                var clienteKey = comentario.IdCliente.HasValue
                    ? clienteIds[comentario.IdCliente.Value]
                    : clienteGenericoKey;

                var hechos = new OpinionFact
                {
                    IdFuente = FuenteIds.Social,
                    IdOpinionOrigen = comentario.IdComment,
                    ProductoKey = productoIds[comentario.IdProducto],
                    ClienteKey = clienteKey,
                    FechaKey = ValidationHelper.FechaKey(comentario.Fecha),
                    IdClasificacion = clasificacion,
                    FechaOpinion = comentario.Fecha,
                    Comentario = comentario.Comentario,
                    Calificacion = null,
                    PuntajeSentimiento = puntaje,
                    Plataforma = comentario.Plataforma,
                    IdCarga = idCargaSocial
                };

                if (_opinionDao.Insertar(hechos))
                    socialInsertadas++;
                else
                    socialDuplicadas++;
            }

            metricaSocial.Insertados = socialInsertadas;
            metricaSocial.Duplicados += socialDuplicadas;
            metricaSocial.Nota = $"{resultado.ClientesGenericos} comentarios sin cliente usan el cliente SIN_CLIENTE.";

            CargarFuenteWeb(dataset);

            var cargaPorTabla = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase)
            {
                ["Clientes"] = idCargaMaestros,
                ["Productos"] = idCargaMaestros,
                ["Categorias"] = idCargaMaestros,
                ["Encuestas"] = idCargaEncuestas,
                ["ResenasWeb"] = idCargaWeb,
                ["ComentariosSociales"] = idCargaSocial,
                ["Fuentes"] = idCargaFuentes
            };

            foreach (var rechazo in dataset.Rechazos)
            {
                var idCarga = cargaPorTabla.TryGetValue(rechazo.Tabla, out var encontrado)
                    ? encontrado
                    : idCargaMaestros;

                _rechazoDao.Insertar(rechazo, idCarga);
            }

            var metricaClientes = dataset.BuscarMetrica("Clientes")!;
            var metricaProductos = dataset.BuscarMetrica("Productos")!;
            var metricaCategorias = dataset.BuscarMetrica("Categorias")!;

            _cargaDao.Actualizar(
                idCargaMaestros,
                metricaClientes.Procesados + metricaProductos.Procesados + metricaCategorias.Procesados,
                metricaClientes.Insertados + metricaProductos.Insertados + metricaCategorias.Insertados,
                metricaClientes.Duplicados + metricaProductos.Duplicados,
                metricaClientes.Rechazados + metricaProductos.Rechazados,
                "COMPLETADA",
                $"Maestros: {dataset.Clientes.Count} clientes, {dataset.Productos.Count} productos, " +
                $"{dataset.Categorias.Count} categorias");

            _cargaDao.Actualizar(
                idCargaEncuestas,
                metricaEncuestas.Procesados,
                encuestasInsertadas,
                metricaEncuestas.Duplicados,
                metricaEncuestas.Rechazados,
                "COMPLETADA",
                $"Encuestas: {encuestasInsertadas} insertadas, {metricaEncuestas.Rechazados} rechazadas");

            _cargaDao.Actualizar(
                idCargaWeb,
                metricaWeb.Procesados,
                webInsertadas,
                metricaWeb.Duplicados,
                metricaWeb.Rechazados,
                "COMPLETADA",
                $"Resenas web: {webInsertadas} insertadas, {metricaWeb.Rechazados} rechazadas");

            _cargaDao.Actualizar(
                idCargaSocial,
                metricaSocial.Procesados,
                socialInsertadas,
                metricaSocial.Duplicados,
                metricaSocial.Rechazados,
                "COMPLETADA",
                $"Comentarios sociales: {socialInsertadas} insertados, {metricaSocial.Rechazados} rechazados");

            _cargaDao.Actualizar(
                idCargaFuentes,
                metricaFuentes.Procesados,
                metricaFuentes.Insertados,
                metricaFuentes.Duplicados,
                metricaFuentes.Rechazados,
                "COMPLETADA",
                $"Catalogo de fuentes: {metricaFuentes.Insertados} cargas historicas");

            _resumenDao.Recalcular();
            _db.Commit();

            resultado.HechosInsertados = encuestasInsertadas + webInsertadas + socialInsertadas;
            resultado.HechosDuplicados = encuestasDuplicadas + webDuplicadas + socialDuplicadas;
        }
        catch
        {
            _db.Rollback();
            throw;
        }
    }

    private void CargarFuenteWeb(DatasetCsv dataset)
    {
        var categoriaIds = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        foreach (var categoria in dataset.Categorias)
            categoriaIds[categoria] = _webSourceDao.UpsertCategoria(categoria);

        var clienteIds = new Dictionary<int, int>();
        foreach (var cliente in dataset.Clientes)
            clienteIds[cliente.IdOrigen] = _webSourceDao.UpsertCliente(
                cliente.Nombre, cliente.Email, null);

        var productoIds = new Dictionary<int, int>();
        foreach (var producto in dataset.Productos)
        {
            var codigo = $"P{producto.IdOrigen:D3}";
            productoIds[producto.IdOrigen] = _webSourceDao.UpsertProducto(
                codigo,
                producto.Nombre,
                categoriaIds[producto.Categoria],
                producto.Precio,
                true);
        }

        var resenasInsertadas = 0;
        var resenasDuplicadas = 0;

        foreach (var resena in dataset.ResenasWeb)
        {
            var insertada = _webSourceDao.InsertarResena(
                resena.IdResena,
                clienteIds[resena.IdCliente],
                productoIds[resena.IdProducto],
                (byte)resena.Rating,
                null,
                resena.Comentario,
                resena.Fecha,
                'P');

            if (insertada)
                resenasInsertadas++;
            else
                resenasDuplicadas++;
        }

        var metricaWeb = dataset.BuscarMetrica("ResenasWeb");
        if (metricaWeb is not null)
        {
            metricaWeb.Nota =
                $"DW: {metricaWeb.Insertados} nuevas, {metricaWeb.Duplicados} duplicadas. " +
                $"OpinionesWebDB: {resenasInsertadas} nuevas, {resenasDuplicadas} duplicadas.";
        }

        dataset.Metricas.Add(new MetricaTabla
        {
            Tabla = "ResenasWebDB",
            Procesados = dataset.ResenasWeb.Count,
            Insertados = resenasInsertadas,
            Rechazados = 0,
            Duplicados = resenasDuplicadas,
            Nota = "Resenas insertadas en OpinionesWebDB.dbo.Resena."
        });
    }

    private static MetricaTabla CrearMetrica(
        string tabla,
        int procesados,
        int insertados,
        DatasetCsv dataset,
        int duplicados = 0)
    {
        return new MetricaTabla
        {
            Tabla = tabla,
            Procesados = procesados,
            Insertados = insertados,
            Rechazados = dataset.Rechazos.Count(r =>
                string.Equals(r.Tabla, tabla, StringComparison.OrdinalIgnoreCase)),
            Duplicados = duplicados
        };
    }

    private static RegistroRechazado CrearRechazo(
        string tabla,
        string archivo,
        int linea,
        string? idRegistro,
        string motivo,
        object modelo)
    {
        return new RegistroRechazado
        {
            Tabla = tabla,
            Archivo = archivo,
            Linea = linea,
            IdRegistro = idRegistro is null ? null : ValidationHelper.Truncar(idRegistro, 50),
            Motivo = ValidationHelper.Truncar(motivo, 200),
            RegistroOriginal = JsonSerializer.Serialize(modelo)
        };
    }
}
