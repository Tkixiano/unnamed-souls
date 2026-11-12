from pathlib import Path
import json
p=Path('tests/perf_6a');s=json.loads((p/'analysis.json').read_text())
rows=[]
labels={'0_chase':'Sin aggro (2 IDLE)','1_chase':'1 soldado en persecución','2_chase':'2 soldados en persecución','2_blocked':'2 con aggro, bloqueados'}
for key,name in labels.items():
 b=s['baseline']['scenarios'][key];a=s['optimized']['scenarios'][key]
 ranges=lambda x: f"{x['cpu_one_core_range'][0]/8:.2f}–{x['cpu_one_core_range'][1]/8:.2f}"
 rows.append(f"| {name} | {b['cpu_machine_percent_median']:.2f}% ({ranges(b)}) | {a['cpu_machine_percent_median']:.2f}% ({ranges(a)}) |")
cpu='\n'.join(rows)
profile=[]
for key,name in labels.items():
 b=s['baseline']['scenarios'][key];a=s['optimized']['scenarios'][key]
 profile.append(f"| {name} | {b['ai_total_us_per_tick_median']:.2f} / {a['ai_total_us_per_tick_median']:.2f} | {b['travel_us_per_tick_median']:.2f} / {a['travel_us_per_tick_median']:.2f} | {b['move_and_slide_us_per_tick_median']:.2f} / {a['move_and_slide_us_per_tick_median']:.2f} |")
profile='\n'.join(profile)
text=f'''# Fase 6A — Ampliación: evaluación del aggro persistente

## Resultado y alcance

Se midieron los **dos soldados normales del nivel integrado** sin aggro, con uno persiguiendo, con ambos persiguiendo y con ambos bloqueados. Se conserva la detección inicial por distancia/cone/raycast y la retención persistente. No se introduce pérdida por distancia, navegación avanzada, cambios de velocidad, daño, tiempos de ataque o reglas de reinicio.

La mejora aplicada elimina la creación repetida de objetos de parámetros de paso y evita reenviar geometría de cápsula idéntica. El microbenchmark pareado muestra una reducción local del coste de can_step; **no se demostró una reducción de CPU global ni una mejora de FPS** con estos dos soldados y estas ventanas cortas.

Este documento es un anexo específico de aggro. No certifica una auditoría completa del nivel, una exportación final ni rendimiento mínimo en el equipo escolar.

## Entorno y método

- Godot 4.6.3 oficial, Compatibility/OpenGL, ventana 1280 × 720; ejecutable de depuración con helper MCP.
- CPU disponible: AMD Ryzen 5 3450U with Radeon Vega Mobile Gfx, **8 procesadores lógicos**. Godot informa 6 323 187 712 bytes físicos (aprox. 5,89 GiB). No es el Ryzen 7 con 4 GB objetivo.
- Todos los arranques del motor se realizaron mediante Godot AI MCP, incluido el launcher del proceso nativo de medición. No se modificaron preferencias globales del editor.
- VSync desactivado y límite local de 60 FPS en el proceso de benchmark. No se modifica project.godot. No equivale a medir FPS máximos.
- CPU del proceso: GetProcessTimes de Windows (usuario + kernel), dividido por tiempo de pared y por 8. Los porcentajes siguientes expresan capacidad total de los 8 hilos atribuible al proceso de Godot, **no CPU total del sistema**. También se conservan los porcentajes respecto de un núcleo completo en analysis.json.
- Muestreo externo cada 0,1 s; se excluyen intervalos que cambian de fase, cargas y preparación. Tres ventanas de 240 ticks físicos por condición (unos 4 s), con orden rotativo. Los datos instrumentados se capturan aparte y se excluyen de la medición de CPU.
- Perfil por funciones: tres ventanas de 120 ticks por condición, con contadores/timestamps en copias de scripts bajo tests/perf_6a. No hay contadores de rendimiento añadidos al código jugable. Se normaliza por las llamadas efectivamente observadas, no se supone que todas las callbacks hayan terminado al emitirse physics_frame.
- En el nivel real se mantienen los actores, geometría, cámara, gravedad y colisiones. Se adquiere aggro mediante visión válida. Para sostener persecución sin llegar a atacar, el protagonista queda lejos y las posiciones de los soldados vuelven a su punto de partida cada 2 s, sin limpiar aggro. Son episodios de fixture, no teletransporte del comportamiento jugable.
- El caso bloqueado añade dos paredes estáticas de prueba, una frente a cada soldado. No se guardan en las escenas. Todas las ventanas comprobaron el número esperado de objetivos con aggro, sin fallos.

No se ejecutaron dos procesos de juego simultáneos durante las capturas de rendimiento. No se controlaron todos los procesos externos, frecuencias térmicas o carga del sistema operativo. El render del nivel y el resto de sistemas siguen incluidos en la CPU del proceso.

## CPU del proceso: antes y después

Mediana de tres repeticiones; entre paréntesis mínimo–máximo de esas tres repeticiones. Un 100% equivaldría a ocupar los ocho procesadores lógicos completos.

| Condición | Antes | Después |
|---|---:|---:|
{cpu}

Los incrementos descriptivos de ambas persecuciones respecto a su IDLE son aproximadamente +0,95 puntos porcentuales antes y +0,49 después. **No se interpretan como una reducción causal del coste de IA**: con un solo perseguidor el dato posterior incluso cae por debajo de IDLE, señal de que el ruido del proceso completo supera al ahorro local buscado. Las diferencias de render, planificación, calentamiento y frecuencia de CPU no quedan aisladas por estas ventanas.

Los datos crudos de CPU proceden de código sin instrumentar. baseline_cpu.json y optimized_cpu.json conservan todos los intervalos y etiquetas; baseline_results.json y optimized_results.json conservan estados y monitores. Se incluye candidate_cpu.json/candidate_results.json de una versión intermedia de la reutilización, separada de la versión final.

## IA, persecución y física

Medianas de microsegundos por tick para **la suma de los dos soldados**. Cada celda es antes / después. Son tiempos diagnósticos de pared, con la sobrecarga del perfilador de funciones presente en ambas versiones.

| Condición | IA total (µs) | can_travel inclusivo (µs) | move_and_slide (µs) |
|---|---:|---:|---:|
{profile}

La IA adicional sobre IDLE para ambos perseguidores fue aproximadamente 219,28 µs/tick antes y 226,81 después; bloqueados, 218,53 y 215,52. Estas variaciones no demuestran una mejora de la IA agregada. El ahorro se identifica con mayor claridad en llamadas pareadas de la consulta concreta y en los contadores de creación de recursos.

**Los tiempos son inclusivos y no se deben sumar entre columnas:** can_detect/can_travel están dentro de IA total; intersect_shape/cast_motion/raycast están dentro de can_travel; move_and_slide está dentro del tick de SoldierActor. Ese tick también ejecuta relojes de ataque, pose y etiquetas de depuración. No se atribuye todo ese coste a la FSM.

Los monitores del nivel completo registraron medianas de física de 2,16→2,12 ms sin aggro, 2,83→2,20 ms con uno, 2,89→2,72 ms con dos y 2,52→2,28 ms bloqueados. Son otra observación del proceso, no una medición aislada ni evidencia causal de la mejora local.

## Coste de las consultas y trabajo redundante

En persecución, cada soldado intenta un paso por tick físico: intersect_shape, cast_motion y raycast al suelo. Con dos, son unas 120 llamadas/s de cada operación. Bloqueados se conservan unas 120 intersect_shape/s y 120 cast_motion/s; no se llega al raycast de suelo porque el volumen ya rechaza el paso. Las cantidades son iguales antes y después.

Sin aggro y fuera del radio, can_detect retorna con el filtro de distancia: no hay raycasts visuales en las ventanas IDLE medidas. Durante la persecución lejana tampoco se consulta visión para conservar aggro. La línea de visión de ataque sigue consultándose al cumplir sus condiciones. Por ello se añadió una medición de detección dentro del radio y con pared en el mundo real del nivel, para no confundir ausencia de raycasts con coste cero del sistema visual.

El sondeo de detección compara 20 lotes pareados de 300 llamadas por versión: con visión libre, 39,05 / 39,79 µs por llamada; con pared, 47,35 / 52,70 µs. El algoritmo de detección no se modificó; esas diferencias muestran variación de medición. Todas las respuestas coincidieron. No se usa este sondeo aislado como cifra de CPU global de dos soldados viendo al jugador.

### Microbenchmark de paso sin instrumentación

Diez lotes pareados por caso, 300 llamadas por versión y lote, alternando el orden antes/después en el mismo mundo físico sin moverlo entre ambas llamadas. Se compara la copia original de la consulta contra la vía reutilizada final.

| Caso | Mediana antes (µs/llamada) | Mediana después | Cambio local |
|---|---:|---:|---:|
| Paso libre | 44,92 | 34,72 | −22,7% |
| Paso bloqueado | 34,61 | 28,53 | −17,6% |

La vía nueva fue más rápida en 9/10 pares libres y 10/10 bloqueados. Las medianas de las reducciones por par fueron 20,4% y 16,8%, respectivamente; no son la misma estadística que dividir las medianas de las columnas. Es un coste local de la función, no un porcentaje de ganancia del juego completo.

### Recursos creados por segundo físico

| Condición | Antes | Después en régimen estable |
|---|---:|---:|
| Un perseguidor | 180 | 0 |
| Ambos perseguidores | 360 | 0 |
| Ambos bloqueados | 240 | 0 |

Se cuentan CapsuleShape3D, PhysicsShapeQueryParameters3D y PhysicsRayQueryParameters3D del sondeo de paso; **no todas las asignaciones de memoria de GDScript**. Permanecen temporales como listas de RID. La inicialización crea un StepProbe con sus tres recursos por soldado, fuera de las ventanas estables. La memoria estática mediana de Godot pasó aproximadamente de 78,4 a 78,5 MiB; no es el working set completo ni incluye toda la memoria gráfica/controlador. Hay unos diez objetos más residentes en las muestras posteriores, una contrapartida pequeña y explícita de la reutilización.

## Optimización aplicada y límites

- EnemyWorldQueries.StepProbe contiene cápsula, consulta de volumen y consulta de suelo reutilizables.
- SoldierAI posee un StepProbe por instancia y lo entrega a can_step. No hay singleton de parámetros compartidos entre soldados.
- Posición, movimiento, máscara y exclusiones se actualizan en cada consulta. Se obtiene el espacio físico actual cada vez. No se conserva ningún resultado ni referencia al mundo anterior.
- Radio/altura solo se reenvían al motor si cambian. La geometría sigue correspondiendo a los parámetros solicitados.
- La vía sin StepProbe conserva el funcionamiento original y los parámetros especiales del jefe; no se modifica su controlador ni sus ataques.
- No se modifica detección, estados, pausas, gravedad, velocidad, daño, ventanas de combate, memoria de aggro ni reinicios.

Se evaluó bajar la frecuencia cuando están bloqueados, pero no se aplica: una respuesta a 10 Hz puede retrasar hasta 0,1 s la reacción al mover una pared o despejar el camino. No se demostró necesidad de aceptar esa latencia con solo dos soldados. Mantener la consulta y la física a 60 Hz evita ese cambio observable. Tampoco se duerme arbitrariamente CharacterBody3D, porque deben conservarse suelo, gravedad y colisiones.

Siguen existiendo coste de consultas dinámicas y procesamiento de pose/etiquetas del actor aun detenido. No se introduce navegación ni una ruta alternativa; un soldado puede quedar frente a un obstáculo conservando el objetivo. No se restaura el límite de persecución como técnica de ahorro.

## Pruebas y trazabilidad

- query_results.json: 11/11 contratos aprobados, incluyendo 450 comparaciones original/reutilizada y vía por defecto, límites/suelo/direcciones, cambio de obstáculo al siguiente tick, recursos estables, restauración y cambio de mundo.
- detection_results.json: 2/2 comprobaciones y coincidencia de 20 lotes de detección libre/obstruida.
- El primer ensayo de la fixture física dio 10/11 porque enabled=false conserva el retorno temprano que pone a cero la intención de movimiento. Se conservó query_first_results.json y se corrigió la fixture para suspender esa callback solo durante la prueba manual de intención. La aserción de movimiento no se debilitó ni se cambió el actor.
- native_regressions.gd incorpora explícitamente aggro_checks.gd (38 comprobaciones) junto con menús/audio. Sus soldados y coordinadores reales permanecen activos. Las fixtures de consultas aisladas no sustituyen esa regresión integrada.
- Las regresiones históricas se ejecutan con los wrappers e isolaciones ya documentadas. Se conservan las expectativas de aggro persistente aprobadas en el ajuste anterior; no se cambian pruebas históricas en esta tarea ni se sobrescriben sus resultados.

## Archivos y reproducción

Archivos jugables modificados: scripts/enemies/soldier_ai.gd y scripts/enemies/enemy_world_queries.gd. El resto se contrasta mediante integrity_baseline.json / integrity.json. No se modifican escenas, modelos, jugador, datos de ataques, jefe, menús, HUD ni tutorial.

Artefactos de esta auditoría bajo tests/perf_6a/: snapshots anteriores, benchmark.gd, build_variants.py, cpu_sampler.py, capturas baseline/optimized, variantes instrumentadas exclusivamente de prueba, query_checks.gd, detection_probe.gd, wrappers de regresión, análisis y este informe. Los launchers MCP son tests/test_perf_6a_launcher.gd y tests/test_perf6a_regressions.gd.

Reproducción: build_variants.py genera las copias a partir del snapshot anterior y del código vigente. Elegir baseline u optimized en request.txt y ejecutar la suite MCP perf6a; iniciar cpu_sampler.py con la misma etiqueta. El proceso espera su señal antes de medir. El launcher solo confirma el arranque; los resultados funcionales están en los JSON finales. Para regresiones nativas, suite MCP perf6a_regressions. Para las históricas/integradas, usar los métodos de regressions.gd y esperar a su archivo de resultados.

El muestreador necesitó permiso de lectura del proceso de Godot fuera del sandbox; se autorizó la lectura de contadores. No se cambian prioridades, afinidad, configuración de Windows ni servicios.

## Limitaciones de rendimiento

Las capturas son cortas y de depuración, en el equipo disponible. TIME_FPS tuvo mediana 60 con rango observado 27–61; su contador de un segundo puede incluir la preparación anterior a una ventana, por lo que ese rango tampoco es un 1% low. No se garantiza 60 FPS estables, rendimiento de exportación o funcionamiento con 4 GB. Se requieren pruebas prolongadas y jugables en el equipo objetivo, con recursos finales y carga representativa.

No hubo mando físico ni evaluación manual del game feeling. No se inicia otra fase ni se implementa navegación avanzada.
'''
(p/'INFORME_AGGRO_RENDIMIENTO.md').write_text(text,encoding='utf-8')
print('Report generated from captured data')

from runpy import run_path
run_path(str(p / "finalize_report.py"))
