import '../estados/montos.dart';

/// Modelo neutral de un reporte. El constructor ([ConstructorReporte]) lo llena
/// con los datos de la app y los exportadores (PDF / Excel) lo convierten al
/// formato elegido, así los cálculos viven en un solo lugar.

enum FormatoNumero { monto, entero, decimal, porcentaje }

/// Una celda de una tabla. Si [numero] no es null, Excel la guarda como número
/// (se puede sumar, graficar, etc.) y el PDF muestra [texto].
class Celda {
  const Celda._(this.texto, this.numero, this.formato, this.negrita);

  const Celda.texto(String texto, {bool negrita = false})
      : this._(texto, null, null, negrita);

  const Celda.vacia() : this._('', null, null, false);

  /// Número con formato. [v] en null se muestra como «n/d».
  /// Para [FormatoNumero.porcentaje] [v] va en puntos porcentuales (12.5 = 12.5 %).
  factory Celda.numero(
    double? v, {
    FormatoNumero formato = FormatoNumero.monto,
    bool negrita = false,
    String sufijo = '',
  }) {
    if (v == null || v.isNaN || v.isInfinite) {
      return Celda._('n/d', null, null, negrita);
    }
    final String t;
    switch (formato) {
      case FormatoNumero.monto:
        t = formatoMonto(v);
        break;
      case FormatoNumero.entero:
        t = formatoMonto(v, decimales: 0);
        break;
      case FormatoNumero.decimal:
        t = v.toStringAsFixed(2);
        break;
      default: // porcentaje
        t = '${v.toStringAsFixed(2)} %';
        break;
    }
    return Celda._(sufijo.isEmpty ? t : '$t $sufijo', v, formato, negrita);
  }

  final String texto;
  final double? numero;
  final FormatoNumero? formato;
  final bool negrita;

  bool get esNumero => numero != null;
}

class FilaReporte {
  const FilaReporte(this.celdas, {this.destacada = false});

  final List<Celda> celdas;

  /// Totales y encabezados de grupo: se muestran en negrita y con fondo.
  final bool destacada;
}

abstract class Bloque {
  const Bloque();
}

class TablaReporte extends Bloque {
  const TablaReporte({
    this.titulo,
    required this.columnas,
    required this.filas,
  });

  final String? titulo;
  final List<String> columnas;
  final List<FilaReporte> filas;
}

class NotaReporte extends Bloque {
  const NotaReporte(this.lineas, {this.titulo});

  final String? titulo;
  final List<String> lineas;
}

class SeccionReporte {
  const SeccionReporte({required this.titulo, required this.bloques});

  final String titulo;
  final List<Bloque> bloques;
}

class Reporte {
  const Reporte({
    required this.titulo,
    required this.empresa,
    required this.generado,
    required this.secciones,
  });

  final String titulo;
  final String empresa;
  final DateTime generado;
  final List<SeccionReporte> secciones;

  String get fechaTexto {
    String d(int n) => n.toString().padLeft(2, '0');
    return '${d(generado.day)}/${d(generado.month)}/${generado.year} '
        '${d(generado.hour)}:${d(generado.minute)}';
  }

  /// Nombre de archivo sin extensión, por ejemplo «reporte_gfo_20261105».
  String get nombreArchivo {
    String d(int n) => n.toString().padLeft(2, '0');
    return 'reporte_gfo_${generado.year}${d(generado.month)}${d(generado.day)}';
  }
}
