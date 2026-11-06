import '../analisis/analisis_calculos.dart';
import '../apalancamiento/apalancamiento_calculos.dart';
import '../cvu/cvu_calculos.dart';
import '../estados/estados_controller.dart';
import '../estados/estados_models.dart';
import '../estados/montos.dart';
import '../flujo/flujo_controller.dart';
import '../personal/personal_controller.dart';
import '../presupuestos/presupuestos_controller.dart';
import '../proforma/proforma_calculos.dart';

/// Interpretaciones sin IA: reglas fijas aplicadas a las mismas cifras que se
/// enviarían a la IA. Sirven de respaldo cuando la IA no responde (sin clave,
/// sin conexión o sin cuota) y siguen la misma estructura de 4 partes.
///
/// Cada método devuelve null cuando todavía no hay datos suficientes.
class InterpretacionLocal {
  const InterpretacionLocal._();

  // ------------------------------------------------------ análisis financiero

  static String? analisis(AnalisisFinanciero a, Alcance alcance) {
    if (!a.hayDatos) return null;
    final i = _Informe();
    final todo = alcance == Alcance.completo;
    if (todo || alcance == Alcance.horizontal) _horizontal(a, i);
    if (todo || alcance == Alcance.vertical) _vertical(a, i);
    if (todo || alcance == Alcance.razones) _razones(a, i);
    if (todo || alcance == Alcance.dupont) _dupont(a, i);
    return i.vacio ? null : i.toString();
  }

  static FilaAnalisis? _buscar(List<FilaAnalisis> filas, String nombre) {
    for (final f in filas) {
      if (f.nombre == nombre) return f;
    }
    return null;
  }

  static String _cambio(String nombre, FilaAnalisis f, String ant, String act) {
    final pct = f.variacionPct;
    if (pct == null) {
      return '$nombre: ${_cs(f.actual)} en $act (no hay cifra anterior para comparar).';
    }
    final verbo = f.variacion > 0
        ? 'subió'
        : f.variacion < 0
            ? 'bajó'
            : 'se mantuvo';
    return '$nombre $verbo ${_p1(pct.abs())} entre $ant y $act (de ${_cs(f.anterior)} a ${_cs(f.actual)}).';
  }

  static void _horizontal(AnalisisFinanciero a, _Informe i) {
    final c = a.c;
    final ant = c.etiqueta(Periodo.anterior);
    final act = c.etiqueta(Periodo.actual);
    if (!c.hayDatos(Periodo.anterior, Estado.balance) &&
        !c.hayDatos(Periodo.anterior, Estado.resultados)) {
      i.hallazgos.add(
          'Falta el período anterior: el análisis horizontal necesita las cifras de los dos períodos para comparar.');
      i.recomendaciones.add(
          'Ingresa el período anterior en Estados financieros para ver la evolución de cada cuenta.');
      return;
    }

    final er = a.filasResultados();
    final bal = a.filasBalance();
    final ventas = _buscar(er, 'Ventas netas');
    final neta = _buscar(er, 'UTILIDAD NETA');
    final activos = _buscar(bal, 'TOTAL ACTIVOS');
    final pasivos = _buscar(bal, 'TOTAL PASIVOS');
    final patrimonio = _buscar(bal, 'TOTAL PATRIMONIO');

    bool hay(FilaAnalisis? f) => f != null && (f.anterior != 0 || f.actual != 0);

    if (hay(ventas)) i.hallazgos.add(_cambio('Las ventas netas', ventas!, ant, act));
    if (hay(neta)) i.hallazgos.add(_cambio('La utilidad neta', neta!, ant, act));
    if (hay(activos)) i.hallazgos.add(_cambio('El total de activos', activos!, ant, act));

    final vp = ventas?.variacionPct;
    final np = neta?.variacionPct;
    if (vp != null && np != null && neta!.anterior > 0) {
      if (vp > 0 && np < 0) {
        i.riesgos.add(
            'Las ventas suben pero la utilidad neta baja: los costos y gastos están creciendo más rápido que los ingresos.');
        i.recomendaciones.add(
            'Revisa el costo de ventas y los gastos de operación para ver cuál creció más que las ventas.');
      } else if (np > vp && np > 0) {
        i.fuertes.add(
            'La utilidad neta crece más rápido que las ventas (${_p1(np)} frente a ${_p1(vp)}): la empresa está siendo más eficiente.');
      }
    }
    if (vp != null && vp < 0) {
      i.riesgos.add('Las ventas bajaron ${_p1(-vp)} respecto al período anterior.');
      i.recomendaciones.add(
          'Analiza la causa de la caída de ventas (precio, volumen, clientes) y define acciones para recuperarlas.');
    }
    if (neta != null && neta.actual < 0) {
      i.riesgos.add('La empresa cerró $act con pérdida de ${_cs(-neta.actual)}.');
    }

    final pp = pasivos?.variacionPct;
    final patp = patrimonio?.variacionPct;
    if (pp != null && patp != null) {
      if (pp > patp && pp > 0) {
        i.riesgos.add(
            'Los pasivos crecen más rápido que el patrimonio (${_p1(pp)} frente a ${_p1(patp)}): aumenta la dependencia de la deuda.');
      } else if (patp > pp && patp > 0) {
        i.fuertes.add(
            'El patrimonio crece más rápido que los pasivos: la empresa se financia cada vez más con recursos propios.');
      }
    }

    FilaAnalisis? mayor;
    for (final f in bal) {
      if (f.total) continue;
      if (mayor == null || f.variacion.abs() > mayor.variacion.abs()) mayor = f;
    }
    if (mayor != null && mayor.variacion != 0) {
      i.hallazgos.add(
          'La cuenta del balance con mayor cambio fue ${mayor.nombre}: ${mayor.variacion > 0 ? '+' : '−'}${_cs(mayor.variacion.abs())}.');
      i.recomendaciones.add(
          'Verifica que el cambio en ${mayor.nombre} tenga una explicación clara (compra, pago, cobro o ajuste).');
    }
  }

  static void _vertical(AnalisisFinanciero a, _Informe i) {
    final c = a.c;
    final act = c.etiqueta(Periodo.actual);

    final ta = c.totalActivos(Periodo.actual);
    if (ta > 0) {
      final ac = c.totalActivosCorrientes(Periodo.actual);
      final pas = c.totalPasivos(Periodo.actual);
      final pat = c.totalPatrimonio(Periodo.actual);
      i.hallazgos.add(
          'En $act, ${_p1(ac / ta * 100)} de los activos es corriente y ${_p1((ta - ac) / ta * 100)} no corriente.');
      i.hallazgos.add(
          'Los activos se financian ${_p1(pas / ta * 100)} con pasivos y ${_p1(pat / ta * 100)} con patrimonio.');
      if (pas / ta > 0.6) {
        i.riesgos.add(
            'Más del 60% de los activos está financiado con deuda: la empresa depende mucho de terceros.');
        i.recomendaciones.add(
            'Evalúa reducir deuda o capitalizar utilidades para bajar el peso de los pasivos.');
      } else if (pas / ta < 0.4) {
        i.fuertes.add('Poca dependencia de deuda: menos del 40% de los activos se financia con pasivos.');
      }
    }

    final v = c.ventasNetas(Periodo.actual);
    if (v > 0) {
      final costo = c.totalGrupo(Grupo.costoVentas, Periodo.actual);
      final gastos = c.totalGrupo(Grupo.gastosOperacion, Periodo.actual);
      final neta = c.utilidadNeta(Periodo.actual);
      i.hallazgos.add(
          'De cada C\$ 100 vendidos, C\$ ${(costo / v * 100).toStringAsFixed(1)} se van en costo de ventas y C\$ ${(gastos / v * 100).toStringAsFixed(1)} en gastos de operación; la utilidad neta es C\$ ${(neta / v * 100).toStringAsFixed(1)}.');
      if (costo / v > 0.7) {
        i.riesgos.add(
            'El costo de ventas consume más del 70% de los ingresos: queda poco margen para gastos y utilidad.');
        i.recomendaciones.add(
            'Busca mejores precios con proveedores o ajusta tus precios de venta para ampliar el margen bruto.');
      }
      if (gastos / v > 0.3) {
        i.riesgos.add('Los gastos de operación superan el 30% de las ventas.');
        i.recomendaciones.add('Revisa los gastos de operación más grandes y define cuáles se pueden reducir.');
      }
      if (neta <= 0) {
        i.riesgos.add('La utilidad neta es cero o negativa: las ventas no alcanzan para cubrir todos los costos.');
      } else if (neta / v >= 0.1) {
        i.fuertes.add('El margen neto es de ${_p1(neta / v * 100)}, un nivel saludable.');
      }
    }
  }

  static String? _tend(Razon r, {required bool masEsMejor}) {
    final x = r.anterior;
    final y = r.actual;
    if (x == null || y == null || (y - x).abs() < 1e-9) return null;
    return ((y > x) == masEsMejor) ? 'mejoró' : 'empeoró';
  }

  static String? _linea(Razon r, {bool masEsMejor = true}) {
    final y = r.actual;
    if (y == null) return null;
    String f(double v) {
      if (r.unidad == 'C\$') return _cs(v);
      if (r.unidad == '%') return '${v.toStringAsFixed(1)}%';
      return '${v.toStringAsFixed(2)} ${r.unidad}';
    }

    final x = r.anterior;
    final t = _tend(r, masEsMejor: masEsMejor);
    final antes = x == null ? '' : ' (antes ${f(x)}${t == null ? '' : ', $t'})';
    return '${r.nombre}: ${f(y)}$antes.';
  }

  static void _razones(AnalisisFinanciero a, _Informe i) {
    final liq = a.liquidez();
    final act = a.actividad();
    final end = a.endeudamiento();
    final ren = a.rentabilidad();

    final rc = liq[0].actual;
    final pa = liq[1].actual;
    final ct = liq[2].actual;
    final rotInv = act[0];
    final ppc = act[1].actual;
    final ppp = act[2].actual;
    final rd = end[0].actual;
    final cob = end[2].actual;
    final mn = ren[2].actual;
    final roa = ren[3].actual;
    final roe = ren[4].actual;

    for (final l in [
      _linea(liq[0]),
      _linea(liq[1]),
      _linea(liq[2]),
      _linea(rotInv),
      _linea(act[1], masEsMejor: false),
      _linea(act[2], masEsMejor: true),
      _linea(end[0], masEsMejor: false),
      _linea(end[2]),
      _linea(ren[2]),
      _linea(ren[3]),
      _linea(ren[4]),
    ]) {
      if (l != null) i.hallazgos.add(l);
    }

    // Liquidez
    if (rc != null) {
      if (rc < 1) {
        i.riesgos.add(
            'Liquidez débil: la razón corriente (${rc.toStringAsFixed(2)}) indica que los activos corrientes no cubren los pasivos de corto plazo.');
        i.recomendaciones.add(
            'Mejora la liquidez: acelera cobros, negocia plazos con proveedores o refinancia deuda de corto plazo a largo plazo.');
      } else if (rc < 1.5) {
        i.hallazgos.add('La liquidez es ajustada: cubre las deudas de corto plazo, pero con poco margen.');
      } else if (rc <= 3) {
        i.fuertes.add('Buena liquidez: la razón corriente es de ${rc.toStringAsFixed(2)}.');
      } else {
        i.hallazgos.add(
            'La liquidez es muy holgada (${rc.toStringAsFixed(2)}); verifica que no haya efectivo o inventario ocioso.');
      }
    }
    if (pa != null && pa < 1 && (rc == null || rc >= 1)) {
      i.riesgos.add(
          'Sin contar inventarios, la liquidez es justa (prueba ácida ${pa.toStringAsFixed(2)}): depende de vender inventario para pagar deudas.');
    }
    if (ct != null) {
      if (ct < 0) {
        i.riesgos.add('El capital de trabajo neto es negativo (${_cs(ct)}).');
      } else if (ct > 0) {
        i.fuertes.add('El capital de trabajo neto es positivo (${_cs(ct)}).');
      }
    }

    // Actividad
    if (ppc != null && ppp != null && ppc > ppp) {
      i.riesgos.add(
          'Se cobra en ${ppc.toStringAsFixed(0)} días pero se paga en ${ppp.toStringAsFixed(0)}: la empresa financia a sus clientes con su propio efectivo.');
      i.recomendaciones.add(
          'Acorta el plazo de cobro a clientes o negocia más días de pago con proveedores.');
    }
    final ri = rotInv.actual;
    if (ri != null && ri < 4) {
      i.hallazgos.add(
          'El inventario rota ${ri.toStringAsFixed(1)} veces al año; una rotación baja inmoviliza dinero en bodega.');
    }

    // Endeudamiento
    if (rd != null) {
      if (rd > 60) {
        i.riesgos.add('Endeudamiento alto: ${_p1(rd)} de los activos está financiado con deuda.');
        i.recomendaciones.add('Prioriza pagar deuda o capitalizar utilidades para reducir el nivel de endeudamiento.');
      } else if (rd < 40) {
        i.fuertes.add('Endeudamiento bajo: ${_p1(rd)} de los activos se financia con deuda.');
      }
    }
    if (cob != null) {
      if (cob < 1.5) {
        i.riesgos.add(
            'La utilidad antes de intereses cubre los gastos financieros solo ${cob.toStringAsFixed(1)} veces: poco margen ante una caída de ventas.');
      } else if (cob >= 3) {
        i.fuertes.add('Los intereses se cubren con holgura (${cob.toStringAsFixed(1)} veces).');
      }
    }

    // Rentabilidad
    if (mn != null) {
      if (mn <= 0) {
        i.riesgos.add('El margen neto es cero o negativo: la empresa no está generando utilidad.');
        i.recomendaciones.add('Revisa precios y estructura de costos para recuperar rentabilidad.');
      } else if (mn >= 10) {
        i.fuertes.add('Buen margen neto (${_p1(mn)}).');
      } else {
        i.hallazgos.add('El margen neto de ${_p1(mn)} deja espacio para mejorar con control de costos.');
      }
    }
    if (roe != null && roa != null && roe > 0 && roa > 0 && roe > roa * 2.5) {
      i.riesgos.add(
          'El ROE (${_p1(roe)}) es mucho mayor que el ROA (${_p1(roa)}): la rentabilidad para los dueños se apoya en bastante deuda.');
    }
  }

  static void _dupont(AnalisisFinanciero a, _Informe i) {
    final d = a.dupont(Periodo.actual);
    final roe = d.roe;
    if (roe == null) {
      i.hallazgos.add(
          'No hay datos suficientes para calcular el ROE con DuPont (se necesitan ventas, activos y patrimonio).');
      return;
    }
    i.hallazgos.add(
        'ROE de ${(roe * 100).toStringAsFixed(1)}% = margen neto ${(d.margenNeto! * 100).toStringAsFixed(1)}% × rotación de activos ${d.rotacion!.toStringAsFixed(2)} × multiplicador de capital ${d.multiplicador!.toStringAsFixed(2)}.');
    i.hallazgos.add(a.lecturaDupont());

    final mn = d.margenNeto!;
    final rot = d.rotacion!;
    final mult = d.multiplicador!;
    if (mn <= 0) {
      i.riesgos.add('El margen neto no es positivo: ni la rotación ni la deuda pueden compensarlo.');
      i.recomendaciones.add('Para subir el ROE, primero hay que recuperar margen: sube precios o reduce costos.');
    } else if (mn >= 0.1) {
      i.fuertes.add('El margen neto (${(mn * 100).toStringAsFixed(1)}%) aporta buena rentabilidad por cada córdoba vendido.');
    } else {
      i.recomendaciones.add('Mejorar el margen neto (precios o costos) es la forma más sana de subir el ROE.');
    }
    if (rot < 0.5) {
      i.riesgos.add('Los activos generan pocas ventas (rotación ${rot.toStringAsFixed(2)}): hay recursos poco productivos.');
      i.recomendaciones.add('Revisa activos ociosos o poco usados que se puedan vender o aprovechar mejor.');
    } else if (rot >= 1) {
      i.fuertes.add('Buena rotación de activos (${rot.toStringAsFixed(2)} veces).');
    }
    if (mult > 3) {
      i.riesgos.add(
          'El multiplicador de capital es alto (${mult.toStringAsFixed(2)}): el ROE depende mucho del endeudamiento y sería más sensible a una caída de ventas.');
    }
  }

  // ----------------------------------------------------------- apalancamiento

  static String? apalancamiento(ResultadoApalancamiento r) {
    final i = _Informe();
    final d = r.datos;
    i.hallazgos.add(
        'Con ventas de ${_cs(d.ventas)} y costos variables de ${_cs(d.costosVariables)}, el margen de contribución es ${_cs(r.margenContribucion)}; después de los costos fijos queda una UAII de ${_cs(r.uaii)}.');

    final gao = r.gao;
    final gaf = r.gaf;
    final gat = r.gat;

    if (gao != null) {
      i.hallazgos.add(
          'GAO de ${gao.toStringAsFixed(2)} veces: si las ventas cambian 1%, la UAII cambia aproximadamente ${gao.toStringAsFixed(2)}%.');
      if (gao > 3) {
        i.riesgos.add(
            'Apalancamiento operativo alto: los costos fijos pesan mucho y una pequeña caída de ventas reduce bastante la UAII.');
        i.recomendaciones.add(
            'Reduce costos fijos o conviértelos en variables (por ejemplo, subcontratar) para bajar el riesgo operativo.');
      } else if (gao <= 1.5) {
        i.fuertes.add('Estructura de costos flexible: la UAII reacciona poco a los cambios en ventas.');
      }
    } else if (r.avisoGao != null) {
      i.riesgos.add(r.avisoGao!);
      i.recomendaciones.add(
          'Sube las ventas, mejora el margen o baja los costos fijos hasta que la UAII sea positiva.');
    }

    if (gaf != null) {
      i.hallazgos.add(
          'GAF de ${gaf.toStringAsFixed(2)} veces: si la UAII cambia 1%, la utilidad después de intereses y dividendos preferentes cambia aproximadamente ${gaf.toStringAsFixed(2)}%.');
      if (gaf > 2) {
        i.riesgos.add('Apalancamiento financiero alto: los intereses y dividendos preferentes absorben gran parte de la UAII.');
        i.recomendaciones.add('Considera reducir deuda o refinanciarla a una tasa menor para bajar la carga financiera.');
      } else if (gaf < 1.2) {
        i.fuertes.add('La carga financiera es baja: casi toda la UAII llega a los dueños.');
      }
    } else if (r.uaii > 0 && r.avisoGaf != null) {
      i.riesgos.add(r.avisoGaf!);
      i.recomendaciones.add('La UAII no cubre la carga financiera: reduce deuda o aumenta la UAII.');
    }

    if (gat != null) {
      i.hallazgos.add(
          'GAT de ${gat.toStringAsFixed(2)} veces (GAO × GAF): si las ventas cambian 1%, la utilidad después de cargas financieras cambia aproximadamente ${gat.toStringAsFixed(2)}%.');
      if (gat > 4) {
        i.riesgos.add('El riesgo total es alto: una caída moderada de ventas podría eliminar la utilidad.');
      }
    }

    if (d.intereses > 0 && r.uaii > 0) {
      final cob = r.uaii / d.intereses;
      if (cob < 1.5) {
        i.riesgos.add('La UAII cubre los intereses solo ${cob.toStringAsFixed(2)} veces.');
      }
    }

    if (i.recomendaciones.isEmpty) {
      i.recomendaciones.add(
          'Usa estos grados para simular: antes de endeudarte o aumentar costos fijos, calcula cómo cambiaría el GAT.');
    }
    return i.toString();
  }

  // ------------------------------------------------------------------ C-V-U

  static String _u(double v) =>
      formatoMonto(v, decimales: v == v.roundToDouble() ? 0 : 1);

  static String? cvu(ResultadoCvu base, {ResultadoCvu? escenario}) {
    final i = _Informe();
    final d = base.datos;
    i.hallazgos.add(
        'Cada unidad deja un margen de contribución de ${_cs(base.margenContribucionUnitario)} (${_p1(base.razonMargenContribucion * 100)} del precio) para cubrir los costos fijos de ${_cs(d.costosFijos)}.');

    final pe = base.puntoEquilibrioUnidades;
    if (pe == null) {
      i.riesgos.add(
          'No existe punto de equilibrio: el precio no supera el costo variable unitario, así que cada venta aumenta la pérdida.');
      i.recomendaciones.add('Sube el precio o reduce el costo variable unitario hasta que el margen sea positivo.');
    } else {
      i.hallazgos.add(
          'El punto de equilibrio es de ${_u(pe)} unidades (${_cs(base.puntoEquilibrioMonetario!)} en ventas): por debajo de eso hay pérdida.');
    }

    final u = d.unidades;
    if (u != null && pe != null) {
      final ut = base.utilidadOperativa!;
      i.hallazgos.add(
          'Con ${_u(u)} unidades vendidas, la utilidad operativa es ${_cs(ut)}.');
      final ms = base.margenSeguridadPorcentaje;
      if (ut < 0) {
        i.riesgos.add(
            'Se vende por debajo del equilibrio: faltan ${_u(-base.margenSeguridadUnidades!)} unidades para no perder.');
        i.recomendaciones.add('Aumenta el volumen, mejora el margen por unidad o reduce los costos fijos para llegar al equilibrio.');
      } else if (ms != null) {
        i.hallazgos.add(
            'El margen de seguridad es de ${_u(base.margenSeguridadUnidades!)} unidades (${_p1(ms * 100)}): las ventas pueden caer ese porcentaje antes de entrar en pérdida.');
        if (ms < 0.1) {
          i.riesgos.add('El margen de seguridad es menor al 10%: una caída pequeña de ventas genera pérdida.');
          i.recomendaciones.add('Busca ampliar el margen de seguridad con más ventas o menos costos fijos.');
        } else if (ms >= 0.3) {
          i.fuertes.add('Margen de seguridad cómodo (${_p1(ms * 100)}).');
        }
      }
    } else if (u == null && pe != null) {
      i.hallazgos.add('No se informaron unidades vendidas, por eso no se calculan utilidad ni margen de seguridad.');
    }

    if (escenario != null) {
      final pe2 = escenario.puntoEquilibrioUnidades;
      final partes = <String>[];
      if (pe != null && pe2 != null) {
        partes.add(
            'el punto de equilibrio pasa de ${_u(pe)} a ${_u(pe2)} unidades');
      }
      final ut1 = base.utilidadOperativa;
      final ut2 = escenario.utilidadOperativa;
      if (ut1 != null && ut2 != null) {
        partes.add('la utilidad operativa pasa de ${_cs(ut1)} a ${_cs(ut2)}');
      }
      if (partes.isNotEmpty) {
        i.hallazgos.add('En el escenario simulado ${partes.join(' y ')}.');
      }
      if (ut1 != null && ut2 != null) {
        if (ut2 > ut1) {
          i.fuertes.add('El escenario simulado mejora la utilidad en ${_cs(ut2 - ut1)}.');
        } else if (ut2 < ut1) {
          i.riesgos.add('El escenario simulado reduce la utilidad en ${_cs(ut1 - ut2)}.');
        }
      }
    }

    if (i.recomendaciones.isEmpty) {
      i.recomendaciones.add(
          'Prueba escenarios cambiando precio, costo variable, costos fijos y volumen para ver cuál palanca mejora más la utilidad.');
    }
    return i.toString();
  }

  // ---------------------------------------------------------------- proforma

  static String? proforma(ResultadoProforma r) {
    final i = _Informe();
    final a = r.actualEr;
    final b = r.proyectadoEr;
    final s = r.supuestos;

    i.hallazgos.add(
        'Con ventas ${_signo(s.crecimientoVentas)} y costos ${_signo(s.variacionCostos)}, las ventas pasan de ${_cs(a.ventas)} a ${_cs(b.ventas)} y la utilidad neta de ${_cs(a.utilidadNeta)} a ${_cs(b.utilidadNeta)}.');

    final roeA = r.roeActual;
    final roeP = r.roeProyectado;
    if (roeA != null && roeP != null) {
      i.hallazgos.add('El ROE pasa de ${roeA.toStringAsFixed(1)}% a ${roeP.toStringAsFixed(1)}%.');
      if (roeP > roeA) {
        i.fuertes.add('La rentabilidad para los dueños (ROE) mejora con estos supuestos.');
      } else if (roeP < roeA) {
        i.riesgos.add('El ROE empeora con estos supuestos.');
      }
    }

    final rc = r.razonCorrienteProyectada;
    if (rc != null) {
      i.hallazgos.add('La razón corriente proyectada es de ${rc.toStringAsFixed(2)}.');
      if (rc < 1) {
        i.riesgos.add('Liquidez proyectada débil: los activos corrientes no cubrirían los pasivos corrientes.');
        i.recomendaciones.add('Planifica financiamiento a largo plazo o reduce compromisos de corto plazo.');
      } else if (rc >= 1.5) {
        i.fuertes.add('La liquidez proyectada es sana (razón corriente ${rc.toStringAsFixed(2)}).');
      }
    }

    final gat = r.gatProyectado;
    if (gat != null && gat > 3) {
      i.riesgos.add(
          'El apalancamiento total proyectado es alto (${gat.toStringAsFixed(2)} veces): una caída pequeña de ventas golpearía fuerte la utilidad.');
    }

    final peA = r.puntoEquilibrioActual;
    final peP = r.puntoEquilibrioProyectado;
    if (peA != null && peP != null) {
      i.hallazgos.add(
          'El punto de equilibrio en ventas pasa de ${_cs(peA)} a ${_cs(peP)}.');
      if (b.ventas > 0 && peP > b.ventas) {
        i.riesgos.add('Las ventas proyectadas quedan por debajo del punto de equilibrio proyectado.');
      }
    }

    if (b.utilidadNeta > a.utilidadNeta && b.utilidadNeta > 0) {
      i.fuertes.add('La utilidad neta proyectada es mayor que la actual.');
    }

    i.riesgos.addAll(r.avisos);

    if (b.utilidadNeta < 0) {
      i.recomendaciones.add('Revisa los supuestos de costos o busca más ventas: la proyección termina en pérdida.');
    }
    if (r.efectivoProyectado < 0) {
      i.recomendaciones.add('Reduce la inversión adicional, endeuda menos o consigue financiamiento antes de ejecutar el plan.');
    }
    if (i.recomendaciones.isEmpty) {
      i.recomendaciones.add(
          'Revisa la tabla de sensibilidad para ver qué tanto cambia la utilidad si las ventas o los costos se desvían de lo esperado.');
    }
    return i.toString();
  }

  // -------------------------------------------------- planeación y presupuestos

  static String? presupuestos(PresupuestosController p) {
    if (!p.hayDatos) return null;
    final r = p.calcular();
    final i = _Informe();

    final ventas = suma(r.ventas);
    final uo = suma(r.utilidadOperativa);
    final fin = suma(r.financiamiento);

    i.hallazgos.add(
        'Ventas presupuestadas del año: ${_cs(ventas)}; utilidad operativa: ${_cs(uo)}${ventas > 0 ? ' (${_p1(uo / ventas * 100)} de las ventas)' : ''}.');

    var mejor = 0;
    for (var t = 1; t < 4; t++) {
      if (r.ventas[t] > r.ventas[mejor]) mejor = t;
    }
    if (r.ventas[mejor] > 0) {
      i.hallazgos.add('El trimestre de mayores ventas es ${trimestres[mejor]} (${_cs(r.ventas[mejor])}).');
    }
    i.hallazgos.add('El saldo final de efectivo al cierre (T4) es de ${_cs(r.saldoFinal[3])}.');

    final conFin = [
      for (var t = 0; t < 4; t++)
        if (r.financiamiento[t] > 0.005) trimestres[t],
    ];
    if (fin > 0.005) {
      i.riesgos.add(
          'Se necesita financiamiento por ${_cs(fin)} en total (${conFin.join(', ')}): la caja no alcanza con lo que se cobra.');
      i.recomendaciones.add(
          'Gestiona con tiempo una línea de crédito para ${conFin.join(', ')}, o adelanta cobros y negocia más plazo con proveedores.');
    } else {
      i.fuertes.add('No se necesita financiamiento: la caja cubre las necesidades en los cuatro trimestres.');
    }

    final perdidas = [
      for (var t = 0; t < 4; t++)
        if (r.utilidadOperativa[t] < 0) trimestres[t],
    ];
    if (perdidas.isNotEmpty) {
      i.riesgos.add('Hay utilidad operativa negativa en ${perdidas.join(', ')}.');
      i.recomendaciones.add('Revisa precio, costo unitario o gastos de operación en ${perdidas.join(', ')}.');
    } else if (uo > 0) {
      i.fuertes.add('La operación es rentable en todos los trimestres.');
    }

    final contado = p.valor(Campo.pctVentasContado);
    if (contado < 50) {
      i.riesgos.add(
          'Solo ${contado.toStringAsFixed(0)}% de las ventas es al contado: la caja depende de cobrar a crédito el trimestre siguiente.');
      i.recomendaciones.add('Ofrece descuentos por pago al contado para acelerar la entrada de efectivo.');
    }

    if (i.recomendaciones.isEmpty) {
      i.recomendaciones.add(
          'Compara el presupuesto con lo real cada trimestre y ajusta ventas, compras y gastos si hay desviaciones.');
    }
    return i.toString();
  }

  // ---------------------------------------------------------- flujo de efectivo

  static String? flujo(FlujoController f, EstadosController e) {
    if (!f.hayMovimientos) return null;
    final i = _Informe();

    for (final a in Actividad.values) {
      i.hallazgos.add(
          '${a.titulo}: entradas ${_cs(f.totalEntradas(a))}, salidas ${_cs(f.totalSalidas(a))}, flujo neto ${_cs(f.flujoNeto(a))}.');
    }
    final ini = f.saldoInicial(e);
    final fin = f.saldoFinal(e);
    i.hallazgos.add(
        'El efectivo pasa de ${_cs(ini)} a ${_cs(fin)} (variación neta de ${_cs(f.variacionNeta)}).');

    final op = f.flujoNeto(Actividad.operacion);
    final inv = f.flujoNeto(Actividad.inversion);
    final fi = f.flujoNeto(Actividad.financiamiento);

    if (op > 0) {
      i.fuertes.add('La operación genera efectivo (${_cs(op)}): el negocio se sostiene con su propia actividad.');
      if (op + inv > 0) {
        i.fuertes.add('El efectivo de la operación alcanza para cubrir las inversiones.');
      }
    } else if (op < 0) {
      i.riesgos.add('La operación consume efectivo (${_cs(op)}): los cobros no cubren los pagos del día a día.');
      i.recomendaciones.add('Acelera los cobros a clientes o reduce pagos de operación hasta que el flujo operativo sea positivo.');
    }
    if (op < 0 && fi > 0) {
      i.riesgos.add('La empresa depende de financiamiento (${_cs(fi)}) para sostener su operación.');
    }
    if (inv < 0 && op + inv < 0) {
      i.riesgos.add('Las inversiones superan el efectivo que genera la operación; se cubren con deuda, capital o caja previa.');
    }
    if (fi < 0 && op + inv + fi < 0) {
      i.riesgos.add('Los pagos de deuda y dividendos superan lo que generan la operación y la inversión: la caja se reduce.');
    }
    if (fin < 0) {
      i.riesgos.add('El saldo final de efectivo es negativo (${_cs(fin)}).');
      i.recomendaciones.add('Cubre el faltante de efectivo con financiamiento o posterga pagos y compras.');
    }

    if (f.hayCuentasDeEfectivo(e) && e.hayDatos(Periodo.actual, Estado.balance)) {
      final dif = fin - f.efectivoEnBalance(e, Periodo.actual);
      if (dif.abs() >= 0.01) {
        i.riesgos.add(
            'El saldo final calculado difiere del efectivo del balance en ${_cs(dif.abs())}: puede faltar o sobrar algún movimiento.');
        i.recomendaciones.add('Concilia el flujo con el efectivo del balance antes de usar los resultados.');
      } else {
        i.fuertes.add('El saldo final de efectivo coincide con el balance.');
      }
    }

    if (i.recomendaciones.isEmpty) {
      i.recomendaciones.add('Mantén un saldo mínimo de efectivo y revisa el flujo cada mes para anticipar faltantes.');
    }
    return i.toString();
  }

  // ------------------------------------------------------- presupuesto personal

  static String? personal(PersonalController p) {
    if (!p.hayMovimientos) return null;
    final r = p.calcular();
    final i = _Informe();

    i.hallazgos.add(
        'En ${r.semanasConRegistro} semanas con registro: ingresos ${_cs(r.ingresos)}, gastos ${_cs(r.gastos)}, ahorro ${_cs(r.ahorro)} y reserva ${_cs(r.reserva)}; saldo disponible ${_cs(r.saldo)}.');
    if (r.ingresos > 0) {
      i.hallazgos.add(
          'Ahorras ${_p1(r.ahorro / r.ingresos * 100)} de lo que ingresa y gastas ${_p1(r.gastos / r.ingresos * 100)}.');
    }

    final claveRiesgo = RegExp(r'Alerta|por debajo|superan|recortar');
    for (final t in p.lectura(r)) {
      if (claveRiesgo.hasMatch(t)) {
        i.riesgos.add(t);
      } else if (t.contains('vas en camino')) {
        i.fuertes.add(t);
      } else {
        i.hallazgos.add(t);
      }
    }

    if (r.saldo < -0.005) {
      i.recomendaciones.add(
          'Recorta primero los gastos de deseo para cubrir los ${_cs(-r.saldo)} que faltan.');
    }
    if (p.costoMeta > 0 && p.semanas > 0 && r.semanasConRegistro > 0) {
      final ritmo = p.ahorroPromedioSemanal(r);
      final aporte = p.aporteSemanal;
      if (ritmo + 0.005 < aporte) {
        i.recomendaciones.add(
            'Para llegar a la meta, sube tu ahorro semanal en ${_cs(aporte - ritmo)} (de ${_cs(ritmo)} a ${_cs(aporte)}).');
      }
    } else if (p.costoMeta > 0 && r.ahorro == 0) {
      i.recomendaciones.add('Empieza a apartar una cantidad fija cada semana para tu meta, aunque sea pequeña.');
    }
    if (r.gastos > 0 && r.gastoDeseo / r.gastos > 0.3) {
      i.recomendaciones.add('Fija un tope semanal para los gastos de deseo y revísalo cada domingo.');
    }
    final excedidas = p
        .comparar(r)
        .where((f) => f.esGasto && f.estado == 'Excede el plan')
        .map((f) => f.nombre)
        .toList();
    if (excedidas.isNotEmpty) {
      i.recomendaciones.add('Revisa las categorías que superan lo planificado: ${excedidas.join(', ')}.');
    }
    if (i.recomendaciones.isEmpty) {
      i.recomendaciones.add('Sigue registrando cada movimiento el día que ocurre y compara cada semana con tu plan.');
    }
    return i.toString();
  }

  // --------------------------------------------------------------- utilidades

  static String _cs(double v) => 'C\$ ${formatoMonto(v)}';

  static String _p1(double v) => '${v.toStringAsFixed(1)}%';

  /// 0.05 -> "+5.0%" ; -0.03 -> "−3.0%"
  static String _signo(double fraccion) {
    final p = fraccion * 100;
    return '${p >= 0 ? '+' : '−'}${p.abs().toStringAsFixed(1)}%';
  }
}

/// Las cuatro partes de una interpretación, con la misma estructura que se
/// pide a la IA.
class _Informe {
  final hallazgos = <String>[];
  final fuertes = <String>[];
  final riesgos = <String>[];
  final recomendaciones = <String>[];

  bool get vacio =>
      hallazgos.isEmpty &&
      fuertes.isEmpty &&
      riesgos.isEmpty &&
      recomendaciones.isEmpty;

  void _seccion(StringBuffer b, String titulo, List<String> lineas) {
    if (lineas.isEmpty) return;
    if (b.isNotEmpty) b.writeln();
    b.writeln(titulo);
    for (final t in lineas) {
      b.writeln('• $t');
    }
  }

  @override
  String toString() {
    final b = StringBuffer();
    _seccion(b, '1) Hallazgos principales', hallazgos);
    _seccion(b, '2) Puntos fuertes', fuertes);
    _seccion(b, '3) Riesgos o alertas', riesgos);
    _seccion(b, '4) Recomendaciones', recomendaciones);
    return b.toString().trimRight();
  }
}
