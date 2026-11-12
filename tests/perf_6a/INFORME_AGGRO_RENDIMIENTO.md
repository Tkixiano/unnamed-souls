# Fase 6A — Ampliación: evaluación del aggro persistente

## Resultado y alcance

Se midieron los **dos soldados normales del nivel integrado** sin aggro, con uno persiguiendo, con ambos persiguiendo y con ambos bloqueados. Se conserva la detección inicial por distancia/cono/raycast y la retención persistente. No se introduce pérdida por distancia, navegación avanzada, cambios de velocidad, daño, tiempos de ataque o reglas de reinicio.

La mejora aplicada elimina la creación repetida de objetos de parámetros de paso. El microbenchmark pareado muestra una reducción local del coste de can_step; **no se demostró una reducción de CPU global ni una mejora de FPS** con estos dos soldados y estas ventanas cortas.

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
| Sin aggro (2 IDLE) | 8.34% (7.83–8.99) | 8.52% (7.88–9.83) |
| 1 soldado en persecución | 8.62% (7.17–10.56) | 9.58% (8.84–12.58) |
| 2 soldados en persecución | 9.29% (8.03–9.75) | 9.69% (6.84–11.01) |
| 2 con aggro, bloqueados | 8.63% (7.67–9.70) | 9.51% (8.38–9.74) |

Los incrementos descriptivos de dos perseguidores sobre IDLE son +0.95 puntos porcentuales antes y +1.17 después. No son una estimación causal: las medianas de CPU no mejoran de forma consistente y sus intervalos varían ampliamente. No se demuestra ahorro de CPU global.

Los datos crudos de CPU finales están en baseline_cpu.json y reuse_only_cpu.json; sus ventanas y monitores en baseline_results.json y reuse_only_results.json. reuse_only es copia exacta de candidate_*, la primera captura de reutilización y la implementación que se entrega. optimized_* / float_check_* conservan la pasada con chequeos flotantes descartada. capture_manifest.json registra esa selección; no se editan los valores capturados.

## IA, persecución y física

Medianas de microsegundos por tick para **la suma de los dos soldados**. Cada celda es antes / después. Son tiempos diagnósticos de pared, con la sobrecarga del perfilador de funciones presente en ambas versiones.

| Condición | IA total (µs) | can_travel inclusivo (µs) | move_and_slide (µs) |
|---|---:|---:|---:|
| Sin aggro (2 IDLE) | 73.64 / 66.46 | 0.00 / 0.00 | 50.75 / 42.55 |
| 1 soldado en persecución | 247.60 / 218.33 | 162.54 / 132.32 | 61.82 / 59.96 |
| 2 soldados en persecución | 292.92 / 286.08 | 208.61 / 190.18 | 61.82 / 77.11 |
| 2 con aggro, bloqueados | 292.17 / 304.18 | 194.65 / 188.15 | 41.29 / 52.54 |

La IA adicional sobre IDLE para dos perseguidores fue 219.28 µs/tick antes y 219.61 después; bloqueados, 218.53 y 237.72. No se demuestra reducción agregada con estos tiempos instrumentados; el ahorro local se comprueba por llamadas pareadas y asignaciones de recursos.

**Los tiempos son inclusivos y no se deben sumar entre columnas:** can_detect/can_travel están dentro de IA total; intersect_shape/cast_motion/raycast están dentro de can_travel; move_and_slide está dentro del tick de SoldierActor. Ese tick también ejecuta relojes de ataque, pose y etiquetas de depuración. No se atribuye todo ese coste a la FSM.

Los monitores del nivel completo registraron física antes/después: 0_chase: 2.16/2.46 ms; 1_chase: 2.83/2.33 ms; 2_chase: 2.89/2.68 ms; 2_blocked: 2.52/2.46 ms. Son observaciones inclusivas del nivel y no una atribución causal a la optimización.

## Coste de las consultas y trabajo redundante

En persecución, cada soldado intenta un paso por tick físico: intersect_shape, cast_motion y raycast al suelo. Con dos, son unas 120 llamadas/s de cada operación. Bloqueados se conservan unas 120 intersect_shape/s y 120 cast_motion/s; no se llega al raycast de suelo porque el volumen ya rechaza el paso. Las cantidades son iguales antes y después.

Sin aggro y fuera del radio, can_detect retorna con el filtro de distancia: no hay raycasts visuales en las ventanas IDLE medidas. Durante la persecución lejana tampoco se consulta visión para conservar aggro. La línea de visión de ataque sigue consultándose al cumplir sus condiciones. Por ello se añadió una medición de detección dentro del radio y con pared en el mundo real del nivel, para no confundir ausencia de raycasts con coste cero del sistema visual.

El sondeo de detección compara 20 lotes pareados de 300 llamadas por versión en el nivel real. Visión libre: 41.52/39.80 µs; pared: 50.85/51.00 µs. Las respuestas coinciden y el algoritmo de detección no cambia. Las variaciones temporales no se presentan como una mejora de detección.

### Microbenchmark de paso sin instrumentación

Diez lotes pareados por caso, 300 llamadas por versión y lote, alternando el orden antes/después en el mismo mundo físico sin moverlo entre ambas llamadas. Se compara la copia original de la consulta contra la vía reutilizada final.

| Caso | Mediana antes (µs/llamada) | Mediana después | Cambio local |
|---|---:|---:|---:|
| Paso libre | 47.27 | 34.73 | -26.5% |
| Paso bloqueado | 46.53 | 36.46 | -21.6% |

La vía nueva fue más rápida en 10/10 pares libres y 9/10 bloqueados. Las reducciones medianas por par fueron 24.8% y 26.1%; son una estadística distinta de dividir las medianas de las columnas. No equivalen a una ganancia porcentual del juego completo.

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
- Radio y altura se asignan en cada consulta, igual que antes. No se omiten cambios de geometría por una comparación aproximada.
- La vía sin StepProbe conserva el funcionamiento original y los parámetros especiales del jefe; no se modifica su controlador ni sus ataques.
- No se modifica detección, estados, pausas, gravedad, velocidad, daño, ventanas de combate, memoria de aggro ni reinicios.

Se ensayó omitir setters por igualdad directa, pero Godot devuelve radio=0,349999994 y altura=1,600000024 tras asignar 0,35/1,6. El chequeo no evitaba los setters y se descartó. Se entrega la reutilización simple ya medida; las comprobaciones afectadas se repitieron sobre ese código. No se atribuye ahorro a omitir setters. precision_probe.txt y capture_manifest.json conservan la evidencia y trazabilidad.

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

Las capturas son cortas y de depuración, en el equipo disponible. TIME_FPS tuvo mediana 60 con rango observado 15–61; su contador de un segundo puede incluir preparación anterior a la ventana. Este rango no es un 1% low y no demuestra estabilidad a 60 FPS. Se requieren pruebas prolongadas y jugables en el equipo objetivo; no se certifica rendimiento de exportación ni con 4 GB.

No hubo mando físico ni evaluación manual del game feeling. No se inicia otra fase ni se implementa navegación avanzada.

## Incidencia del agregador de regresiones

El primer agregador buscó el resultado 4A fuera de perf_6a y produjo null. El sondeo de estado accedió después a ese null. Se conservan integration_first_aggregate.json y harness_first_editor_log.json. Las aserciones de las suites ya habían terminado; el agregado se recuperó de sus JSON reales sin cambiar resultados ni expectativas. Se corrigieron las rutas del wrapper y se repitió 4A: confirm4a_results.json, 64/64. La incidencia pertenece al harness, no a la IA.

## Verificación final consolidada

**13/13 contratos nuevos y 1082/1082 comprobaciones de regresión aprobados**, incluidos los 38 contratos de aggro persistente en el runner nativo. Las 450 comparaciones de consultas forman parte de uno de esos contratos; no se suman de nuevo. Tampoco se cuentan los launchers ni se suman resultados repetidos de fases anteriores.

Después de retirar los chequeos flotantes se repitieron consultas, detección, aggro, soldado/checkpoints y jefe sobre el código final: **247/247** contratos (final_focus_results.json). Es una confirmación focalizada de cobertura ya contada, no un incremento de 247 pruebas distintas.

Auditoría SHA-256: 515 archivos jugables, únicamente los dos scripts de consultas/IA modificados; 513 intactos. Ninguna prueba histórica se modificó en esta ampliación.

F5 verificado mediante main: menú principal, foco Nueva partida y preferencias conservadas. F6 verificado mediante current con la arena artística abierta: protagonista en suelo, vida 100, cinco Estus, jefe con 600 de vida en fase 1. Los logs finales de esas ejecuciones y de la confirmación focalizada no registran errores del run. Las incidencias anteriores del harness se conservan separadas. El juego quedó detenido, con F5/F6 configurados como antes.
