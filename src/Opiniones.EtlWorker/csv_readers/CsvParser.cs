using System.Text;

namespace Opiniones.EtlWorker.CsvReaders;

public static class CsvParser
{
    public static List<FilaCsv> Parsear(string contenido)
    {
        var filas = new List<FilaCsv>();
        var campos = new List<string>();
        var campo = new StringBuilder();
        var enComillas = false;
        var numeroLinea = 1;
        var inicioRegistro = 1;
        var texto = contenido.Replace("\r\n", "\n").Replace('\r', '\n');

        for (var i = 0; i < texto.Length; i++)
        {
            var caracter = texto[i];

            if (enComillas)
            {
                if (caracter == '"')
                {
                    if (i + 1 < texto.Length && texto[i + 1] == '"')
                    {
                        campo.Append('"');
                        i++;
                    }
                    else
                    {
                        enComillas = false;
                    }
                }
                else
                {
                    campo.Append(caracter);
                    if (caracter == '\n')
                        numeroLinea++;
                }

                continue;
            }

            switch (caracter)
            {
                case '"':
                    enComillas = true;
                    break;
                case ',':
                    campos.Add(campo.ToString());
                    campo.Clear();
                    break;
                case '\n':
                    campos.Add(campo.ToString());
                    campo.Clear();
                    filas.Add(new FilaCsv
                    {
                        NumeroLinea = inicioRegistro,
                        Campos = campos.ToArray()
                    });
                    campos.Clear();
                    numeroLinea++;
                    inicioRegistro = numeroLinea;
                    break;
                default:
                    campo.Append(caracter);
                    break;
            }
        }

        if (campo.Length > 0 || campos.Count > 0)
        {
            campos.Add(campo.ToString());
            filas.Add(new FilaCsv
            {
                NumeroLinea = inicioRegistro,
                Campos = campos.ToArray()
            });
        }

        return filas;
    }
}
