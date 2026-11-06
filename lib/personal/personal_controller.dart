import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/indicadores_compartidos.dart';
import '../estados/montos.dart';
import 'personal_importer.dart';
import 'personal_models.dart';

/// Datos y cálculos del presupuesto personal (registro semanal de lunes a domingo).
class PersonalController extends ChangeNotifier {
  PersonalController({required this.indicadores}) {
    final h = DateTime.now();
    // Lunes de la semana actual
    fechaInicio = DateTime(h.year, h.month, h.day - (h.weekday - 1));
    _cargarProyeccionBase();
  }

  final IndicadoresCompartidos indicadores;

  // ------------------------------------------------------------ datos y meta

  String nombre = '';
  String meta = '';
  double costoMeta = 0;

  /// Duración del seguimiento en semanas.
  int semanas = 0;
  late DateTime fechaInicio;

  // ---------------------------------------------------------- proyección

  String tipoProyeccion = tiposProyeccion.first;
  double ingresoProyectado = 0;
  Frecuencia frecuencia = Frecuencia.semanal;
  final List<LineaProyeccion> lineas = [];

  final List<Movimiento> _movs = [];
  final Set<String> _categoriasExtra = {};
  int _seq = 0;

  /// Última línea de proyección agregada (para enfocar su nombre).
  String? ultimaLineaId;

  @override
  void notifyListeners() {
    super.notifyListeners();
    indicadores.publicarSaldoPersonal(hayMovimientos ? calcular().saldo : null);
  }

  /// Se llama después de modificar campos sueltos (nombre, meta, líneas...).
  void notificarCambio() => notifyListeners();

  String _nuevoId(String p) => '$p${_seq++}';

  // --------------------------------------------------------------- datos

  void setNombre(String v) {
    nombre = v;
    notifyListeners();
  }

  void setMeta(String v) {
    meta = v;
    notifyListeners();
  }

  void setCostoMeta(double v) {
    costoMeta = v;
    notifyListeners();
  }

  void setSemanas(int v) {
    semanas = v < 0 ? 0 : v;
    notifyListeners();
  }

  void setFechaInicio(DateTime v) {
    fechaInicio = DateTime(v.year, v.month, v.day);
    notifyListeners();
  }

  /// Aporte semanal recomendado = Costo de la meta / Duración (semanas)
  double get aporteSemanal => semanas == 0 ? 0 : costoMeta / semanas;

  /// Final del seguimiento (domingo) = Inicio + semanas × 7 − 1
  DateTime? get fechaFin =>
      semanas == 0 ? null : _dia(fechaInicio, semanas * 7 - 1);

  static DateTime _dia(DateTime d, int dias) =>
      DateTime(d.year, d.month, d.day + dias);

  /// Semana del seguimiento a la que pertenece una fecha (1 = primera semana).
  int semanaDe(DateTime f) {
    final a = DateTime.utc(f.year, f.month, f.day);
    final b = DateTime.utc(fechaInicio.year, fechaInicio.month, fechaInicio.day);
    return (a.difference(b).inDays / 7).floor() + 1;
  }

  // ---------------------------------------------------------- movimientos

  List<Movimiento> get movimientos => List.unmodifiable(_movs);

  bool get hayMovimientos => _movs.isNotEmpty;

  /// Categorías disponibles: las de la plantilla, las usadas y las creadas.
  List<String> get categorias {
    final set = <String>{...categoriasBase, ..._categoriasExtra};
    for (final m in _movs) {
      if (m.categoria.trim().isNotEmpty) set.add(m.categoria.trim());
    }
    for (final l in lineas) {
      if (l.categoria.trim().isNotEmpty) set.add(l.categoria.trim());
    }
    return set.toList();
  }

  void agregarCategoria(String nombre) {
    final t = nombre.trim();
    if (t.isEmpty) return;
    _categoriasExtra.add(t);
    notifyListeners();
  }

  Movimiento agregarMovimiento({
    required DateTime fecha,
    required TipoMov tipo,
    required String categoria,
    required double monto,
    String descripcion = '',
    String prioridad = '',
    String medio = '',
    String observacion = '',
  }) {
    final m = Movimiento(
      id: _nuevoId('m'),
      fecha: DateTime(fecha.year, fecha.month, fecha.day),
      semana: semanaDe(fecha),
      tipo: tipo,
      categoria: categoria.trim(),
      descripcion: descripcion.trim(),
      monto: monto,
      prioridad: prioridad,
      medio: medio,
      observacion: observacion.trim(),
    );
    _movs.add(m);
    notifyListeners();
    return m;
  }

  void eliminarMovimiento(String id) {
    _movs.removeWhere((m) => m.id == id);
    notifyListeners();
  }

  void borrarMovimientos() {
    _movs.clear();
    notifyListeners();
  }

  // ------------------------------------------------------- proyección

  void setTipoProyeccion(String v) {
    tipoProyeccion = v;
    notifyListeners();
  }

  void setIngresoProyectado(double v) {
    ingresoProyectado = v;
    notifyListeners();
  }

  void setFrecuencia(Frecuencia v) {
    frecuencia = v;
    notifyListeners();
  }

  void _cargarProyeccionBase() {
    void add(String c, String tipo) =>
        lineas.add(LineaProyeccion(id: _nuevoId('l'), categoria: c, tipo: tipo));
    add('Transporte', 'Necesidad');
    add('Alimentación', 'Necesidad');
    add('Datos/Internet', 'Necesidad');
    add('Copias y materiales', 'Necesidad');
    add('Salud', 'Necesidad');
    add('Personal/Ocio', 'Deseo');
    add('Reserva imprevistos', 'Reserva');
    add('Meta de ahorro', 'Ahorro');
    add('Otro', 'Según el caso');
  }

  LineaProyeccion agregarLinea() {
    final l = LineaProyeccion(id: _nuevoId('l'), categoria: '');
    lineas.add(l);
    ultimaLineaId = l.id;
    notifyListeners();
    return l;
  }

  void eliminarLinea(String id) {
    lineas.removeWhere((l) => l.id == id);
    notifyListeners();
  }

  double get totalAsignado => lineas.fold(0.0, (s, l) => s + l.monto);

  /// Diferencia = Ingreso disponible − Total asignado
  double get diferenciaProyeccion => ingresoProyectado - totalAsignado;

  /// Porcentaje del ingreso asignado (fracción). Null si el ingreso es cero.
  double? get pctAsignado =>
      ingresoProyectado == 0 ? null : totalAsignado / ingresoProyectado;

  String get estadoProyeccion {
    final d = diferenciaProyeccion;
    if (d.abs() < 0.005) return 'Balanceado';
    return d > 0 ? 'Falta asignar' : 'Excede el ingreso';
  }

  double get ahorroProyectado => lineas
      .where((l) => l.tipo == 'Ahorro')
      .fold(0.0, (s, l) => s + l.monto);

  /// Pasa un monto de la frecuencia del presupuesto a semanal (4 semanas = 1 mes).
  double _semanal(double monto) =>
      frecuencia == Frecuencia.mensual ? monto / 4 : monto;

  // ------------------------------------------------------------ importación

  /// Reemplaza los datos que vienen en el archivo; lo demás no se toca.
  void aplicarImportacion(ResultadoImportacionPersonal r) {
    if (r.nombre != null) nombre = r.nombre!;
    if (r.meta != null) meta = r.meta!;
    if (r.costoMeta != null) costoMeta = r.costoMeta!;
    if (r.semanas != null) semanas = r.semanas!;
    if (r.fechaInicio != null) fechaInicio = r.fechaInicio!;

    if (r.movimientos.isNotEmpty) {
      _movs.clear();
      for (final i in r.movimientos) {
        // La columna Semana manda. Si falta, se deduce de la fecha.
        // Si la fecha es absurda (p. ej. año 1900), se reconstruye con la semana.
        DateTime fecha;
        int semana;
        final f = i.fecha;
        final fechaValida = f != null && f.year >= 2000;
        if (i.semana != null) {
          semana = i.semana!;
          fecha = fechaValida ? f! : _dia(fechaInicio, (semana - 1) * 7);
        } else if (fechaValida) {
          fecha = f!;
          semana = semanaDe(f);
        } else {
          fecha = fechaInicio;
          semana = 1;
        }
        _movs.add(Movimiento(
          id: _nuevoId('m'),
          fecha: fecha,
          semana: semana,
          tipo: i.tipo,
          categoria: i.categoria,
          descripcion: i.descripcion,
          monto: i.monto,
          prioridad: i.prioridad,
          medio: i.medio,
          observacion: i.observacion,
        ));
      }
    }

    if (r.hayProyeccion) {
      if (r.lineas.isNotEmpty) {
        lineas.clear();
        for (final l in r.lineas) {
          lineas.add(LineaProyeccion(
            id: _nuevoId('l'),
            categoria: l.categoria,
            monto: l.monto,
            tipo: l.tipo,
            comentario: l.comentario,
          ));
        }
      }
      if (r.ingresoProyectado != null) ingresoProyectado = r.ingresoProyectado!;
      if (r.frecuencia != null) {
        frecuencia = Frecuencia.desdeTexto(r.frecuencia!);
      }
      if (r.tipoProyeccion != null) {
        tipoProyeccion = normalizar(r.tipoProyeccion!).contains('desead')
            ? tiposProyeccion[1]
            : tiposProyeccion[0];
      }
    }
    ultimaLineaId = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------- cálculos

  /// Seguimiento semanal y totales. Las semanas llegan hasta la duración
  /// indicada o hasta la última semana con movimientos, la que sea mayor.
  ResumenPersonal calcular() {
    final maxSemana = _movs.fold<int>(0, (m, x) => math.max(m, x.semana));
    final total = math.max(semanas, maxSemana);

    final sems = [
      for (var i = 1; i <= total; i++)
        SemanaResumen(
          semana: i,
          desde: _dia(fechaInicio, (i - 1) * 7),
          hasta: _dia(fechaInicio, (i - 1) * 7 + 6),
        ),
    ];

    final porCategoria = <String, double>{};
    var necesidad = 0.0, deseo = 0.0, otra = 0.0;
    var fuera = 0;

    for (final m in _movs) {
      if (m.semana < 1) {
        fuera++;
        continue;
      }
      final s = sems[m.semana - 1];
      switch (m.tipo) {
        case TipoMov.ingreso:
          s.ingresos += m.monto;
        case TipoMov.gasto:
          s.gastos += m.monto;
          final cat = m.categoria.trim().isEmpty ? 'Sin categoría' : m.categoria.trim();
          porCategoria[cat] = (porCategoria[cat] ?? 0) + m.monto;
          final p = normalizar(m.prioridad);
          if (p == 'necesidad') {
            necesidad += m.monto;
          } else if (p == 'deseo') {
            deseo += m.monto;
          } else {
            otra += m.monto;
          }
        case TipoMov.ahorro:
          s.ahorro += m.monto;
        case TipoMov.reserva:
          s.reserva += m.monto;
      }
    }

    var acumulado = 0.0;
    for (final s in sems) {
      acumulado += s.ahorro;
      s.ahorroAcumulado = acumulado;
    }

    final ordenadas = porCategoria.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ResumenPersonal(
      semanas: sems,
      gastosPorCategoria: ordenadas,
      gastoNecesidad: necesidad,
      gastoDeseo: deseo,
      gastoOtraPrioridad: otra,
      semanasConRegistro: sems.where((s) => s.hayActividad).length,
      movimientosFuera: fuera,
    );
  }

  /// Avance de la meta (fracción) = Ahorro acumulado / Costo de la meta.
  double? avanceMeta(ResumenPersonal r) =>
      costoMeta == 0 ? null : r.ahorro / costoMeta;

  /// Ahorro promedio por semana con registro.
  double ahorroPromedioSemanal(ResumenPersonal r) =>
      r.semanasConRegistro == 0 ? 0 : r.ahorro / r.semanasConRegistro;

  /// Compara el presupuesto proyectado con lo registrado, en promedios semanales.
  List<FilaComparacion> comparar(ResumenPersonal r) {
    final n = r.semanasConRegistro;
    double prom(double total) => n == 0 ? 0 : total / n;

    final plan = <String, double>{};
    final nombres = <String, String>{};
    var planAhorro = 0.0, planReserva = 0.0;
    for (final l in lineas) {
      final m = _semanal(l.monto);
      if (l.tipo == 'Ahorro') {
        planAhorro += m;
      } else if (l.tipo == 'Reserva') {
        planReserva += m;
      } else if (l.categoria.trim().isNotEmpty) {
        final k = normalizar(l.categoria);
        plan[k] = (plan[k] ?? 0) + m;
        nombres.putIfAbsent(k, () => l.categoria.trim());
      }
    }

    final real = <String, double>{};
    for (final e in r.gastosPorCategoria) {
      final k = normalizar(e.key);
      real[k] = (real[k] ?? 0) + e.value;
      nombres.putIfAbsent(k, () => e.key);
    }

    final filas = <FilaComparacion>[];
    for (final k in {...plan.keys, ...real.keys}) {
      final p = plan[k] ?? 0;
      final x = prom(real[k] ?? 0);
      if (p == 0 && x == 0) continue;
      filas.add(FilaComparacion(
          nombre: nombres[k]!, planificado: p, real: x, esGasto: true));
    }
    final ahorroReal = prom(r.ahorro);
    if (planAhorro != 0 || ahorroReal != 0) {
      filas.add(FilaComparacion(
          nombre: 'Ahorro para la meta',
          planificado: planAhorro,
          real: ahorroReal,
          esGasto: false));
    }
    final reservaReal = prom(r.reserva);
    if (planReserva != 0 || reservaReal != 0) {
      filas.add(FilaComparacion(
          nombre: 'Reserva',
          planificado: planReserva,
          real: reservaReal,
          esGasto: false));
    }
    return filas;
  }

  // ---------------------------------------------------------- interpretación

  static String _cs(double v) => 'C\$ ${formatoMonto(v)}';

  /// Lectura breve basada en reglas simples; funciona sin conexión a la IA.
  List<String> lectura(ResumenPersonal r) {
    final l = <String>[];
    if (r.ingresos == 0 && r.gastos == 0 && r.ahorro == 0 && r.reserva == 0) {
      return l;
    }

    final saldo = r.saldo;
    if (saldo > 0.005) {
      l.add(
          'Saldo disponible positivo: ${_cs(saldo)} sin asignar de lo que has recibido.');
    } else if (saldo < -0.005) {
      l.add(
          'Alerta: has gastado, ahorrado o reservado ${_cs(-saldo)} más de lo que ingresó.');
    } else {
      l.add('El saldo es cero: todo el dinero recibido está asignado.');
    }

    if (r.gastosPorCategoria.isNotEmpty && r.gastos > 0) {
      final top = r.gastosPorCategoria.first;
      l.add(
          '${top.key} concentra el ${(top.value / r.gastos * 100).toStringAsFixed(0)}% de los gastos (${_cs(top.value)}).');
    }

    if (r.gastos > 0 && r.gastoDeseo > 0) {
      final pct = r.gastoDeseo / r.gastos * 100;
      l.add(pct > 30
          ? 'Los gastos de deseo son el ${pct.toStringAsFixed(0)}% del gasto total: es un margen donde podrías recortar si hace falta ahorrar más.'
          : 'Los gastos de deseo son el ${pct.toStringAsFixed(0)}% del gasto total, un nivel moderado.');
    }

    final avance = avanceMeta(r);
    if (avance != null) {
      l.add(
          'Llevas ${_cs(r.ahorro)} ahorrados para la meta: ${(avance * 100).toStringAsFixed(1)}% de ${_cs(costoMeta)}.');
      if (semanas > 0 && r.semanasConRegistro > 0) {
        final ritmo = ahorroPromedioSemanal(r);
        final aporte = aporteSemanal;
        if (ritmo + 0.005 >= aporte) {
          l.add(
              'Tu ahorro promedio (${_cs(ritmo)} por semana) alcanza el aporte recomendado de ${_cs(aporte)}: vas en camino de lograr la meta.');
        } else {
          final proyectado = ritmo * semanas;
          l.add(
              'Tu ahorro promedio (${_cs(ritmo)} por semana) está por debajo del aporte recomendado de ${_cs(aporte)}. A este ritmo juntarías ${_cs(proyectado)} en $semanas semanas.');
        }
      }
    }

    final excedidas = comparar(r).where((f) => f.esGasto && f.estado == 'Excede el plan').toList();
    if (excedidas.isNotEmpty) {
      l.add(
          'Categorías que superan lo planificado: ${excedidas.map((f) => f.nombre).join(', ')}.');
    }
    return l;
  }

  // ------------------------------------------------------------ resumen para IA

  String resumenParaIa() {
    final r = calcular();
    final avance = avanceMeta(r);
    final b = StringBuffer()
      ..writeln('Moneda: córdobas (C\$). Presupuesto personal de un estudiante, seguimiento semanal (lunes a domingo).')
      ..writeln('\nMeta:')
      ..writeln('- Meta: ${meta.trim().isEmpty ? '(sin definir)' : meta.trim()}')
      ..writeln('- Costo de la meta: ${_cs(costoMeta)}')
      ..writeln('- Duración: $semanas semanas; aporte semanal recomendado: ${_cs(aporteSemanal)}')
      ..writeln('\nResultados del seguimiento (${r.semanasConRegistro} semanas con registro):')
      ..writeln('- Total de ingresos: ${_cs(r.ingresos)}')
      ..writeln('- Total de gastos: ${_cs(r.gastos)} (necesidades ${_cs(r.gastoNecesidad)}, deseos ${_cs(r.gastoDeseo)}, otros ${_cs(r.gastoOtraPrioridad)})')
      ..writeln('- Ahorro para la meta: ${_cs(r.ahorro)}${avance == null ? '' : ' (${(avance * 100).toStringAsFixed(1)}% de la meta)'}')
      ..writeln('- Reserva acumulada: ${_cs(r.reserva)}')
      ..writeln('- Saldo disponible: ${_cs(r.saldo)}')
      ..writeln('- Ahorro promedio por semana: ${_cs(ahorroPromedioSemanal(r))}')
      ..writeln('\nGastos por categoría:');
    for (final e in r.gastosPorCategoria) {
      b.writeln('- ${e.key}: ${_cs(e.value)}');
    }
    if (totalAsignado > 0 || ingresoProyectado > 0) {
      b
        ..writeln('\nPresupuesto proyectado ($tipoProyeccion, ${frecuencia.etiqueta.toLowerCase()}):')
        ..writeln('- Ingreso disponible: ${_cs(ingresoProyectado)}; total asignado: ${_cs(totalAsignado)}; estado: $estadoProyeccion')
        ..writeln('\nComparación semanal (planificado | real):');
      for (final f in comparar(r)) {
        b.writeln(
            '- ${f.nombre}: ${_cs(f.planificado)} | ${_cs(f.real)} (${f.estado})');
      }
    }
    return b.toString();
  }
}
