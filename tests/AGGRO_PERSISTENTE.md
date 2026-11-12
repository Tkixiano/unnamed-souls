# Ajuste de IA — Aggro persistente de soldados

Godot 4.6.3 oficial, GDScript, Compatibility. Auditoría y ejecución del motor mediante Godot AI MCP. Cambio limitado a detección y seguimiento de enemigos normales.

## Comportamiento anterior y auditoría

Se revisaron SoldierAI, SoldierActor, EnemyWorldQueries, AttackHitbox, el coordinador de checkpoints, GameMenus y las escenas del soldado, nivel integrado y arenas técnicas. También se revisaron los contratos de pruebas de 3A, 3B y las regresiones posteriores.

SoldierAI._physics_process descartaba `_acquired` y entraba en RETURNING cuando se cumplía cualquiera de estas condiciones:

- Distancia entre soldado y jugador superior a loss_radius (12 m por defecto).
- Falta de visión durante unseen_tolerance (1,2 s por defecto).
- Soldado o jugador alejados de origin más de maximum_pursuit_distance (8 m por defecto).

La adquisición inicial requiere objetivo vivo, radio de detección (7 m), cono visual (130° totales) y raycast libre. Las escenas integradas no sobrescriben esos valores del soldado. No hay NavigationAgent3D ni búsqueda de rutas: se emplea persecución directa y probes de volumen/suelo antes de cada desplazamiento. La física permanece en SoldierActor.move_and_slide().

## Cambio implementado

Se reutiliza `_acquired` como memoria persistente de aggro, sin duplicar estados ni crear otro controlador. `has_aggro()` expone su consulta validando además que el objetivo sigue vivo y disponible.

`target` sigue siendo la referencia al jugador inyectada por la escena; su presencia no significa detección. Solo una adquisición mediante can_detect() activa `_acquired`. Una vez activado, la memoria no depende de visión, cono, distancia al jugador ni distancia al origen. El soldado sigue orientándose y solicitando desplazamiento aunque el jugador se oculte o se aleje.

Se eliminó el reloj privado de pérdida de visión y la condición de retorno por distancia/oclusión. loss_radius, unseen_tolerance y maximum_pursuit_distance permanecen como propiedades heredadas para compatibilidad de escenas y fixtures; **ya no limitan la retención del objetivo**. Los parámetros de adquisición y combate conservan su significado y valores.

La validación de objetivo muerto/destruido se realiza también antes del retorno temprano por STAGGERED. Una referencia destruida se reemplaza por null, se limpia la memoria y se cancela un ataque existente. No se busca otro jugador mediante rutas nuevas ni se conservan accesos a instancias liberadas.

## Eventos de reinicio

| Evento | Resultado |
|---|---|
| Soldado muere | _on_died limpia aggro y desactiva la IA, como antes. |
| Jugador muere | La validación detiene seguimiento/ataques; el coordinador ejecuta luego la restauración del encuentro. |
| Descanso o reaparición | SoldierActor.restore_at_checkpoint restaura atributos, posición e IDLE y llama a reset_brain. La referencia válida al mismo jugador se conserva. |
| Nueva partida / reinicio de sesión | El gestor existente sustituye la escena y crea soldados con memoria inicial vacía y referencias al nuevo protagonista. |
| Reinicio explícito del nivel | La recarga vuelve a inicializar las instancias sin aggro. |
| reset_brain explícito / restauración completa del soldado | Limpia memoria y decisiones a través de la API existente. |
| Pausa y continuar | No limpian aggro, referencia, ataque ni relojes. Se conserva el modo de pausa de Godot. |

RETURNING se conserva para la pérdida explícita de un objetivo válido, por ejemplo tras su muerte. No se utiliza para olvidar al jugador por ocultarse o alejarse. La reaparición normal del protagonista restaura la misma instancia; no requiere modificar el coordinador.

## Colisiones y ataques

No se modifican velocidad (2 m/s), aceleración, daño, stamina, tiempos, orientación comprometida ni patrones. La selección de ataque sigue exigiendo alcance, orientación, intervalo de decisión y línea de visión. Además, la hitbox compartida ya comprueba _unobstructed() antes de aplicar cada impacto, por lo que un sólido interpuesto bloquea el contacto incluso si el ataque había empezado.

Los probes existentes conservan máscara física 1, volumen de cápsula, detección de suelo/pendientes y rechazo de vacío. No se teletransporta al enemigo para recuperar el camino.

**Limitación de navegación:** un soldado puede quedarse detenido frente a una pared, construcción o desnivel, manteniendo el objetivo. No calcula cómo rodear obstáculos; seguirá intentando cuando haya un trayecto directo seguro. El nuevo aggro puede mantener soldados activos a distancias mayores; no se promete rendimiento ni persecución por todo el mapa sin una evaluación jugable posterior.

## Pruebas nuevas

`aggro_checks.gd`: **38/38** comprobaciones aprobadas. Incluye detección válida, rechazo inicial por pared/distancia/espalda, retención por oclusión prolongada y antiguos límites, salida del cono, jugador detrás, paredes dentro del rango de ataque, recuperación del ataque al despejarse, daño normal intacto, pausa real, muerte/restauración del soldado y referencia de jugador destruida.

En el nivel integrado se ejecutan los componentes reales: adquisición por Soldier1, descanso validado por área de hoguera, muerte del protagonista, secuencia automática de reaparición, limpieza de memoria sin duplicar el soldado, readquisición, nueva partida y recarga del nivel. No se desactivan los nuevos comportamientos para estas comprobaciones. En las fixtures espaciales se colocan actores/paredes y se fija la espera aleatoria para obtener resultados deterministas; esas colocaciones no son movimiento jugable ni cambios de las escenas guardadas.

Resultado detallado: aggro_results.json. La entrada fue automática/simulada; no hubo mando físico ni evaluación visual de la sensación de persecución.

## Actualización justificada de pruebas históricas

En phase_3a_checks.gd se sustituyeron tres expectativas incompatibles con el requisito nuevo, manteniendo el total de 61 comprobaciones:

| Expectativa anterior | Cobertura actual |
|---|---|
| leash_enters_returning | beyond_former_leash_keeps_aggro: conserva objetivo y CHASE fuera de la antigua zona. |
| returns_home_without_teleport | pursues_without_teleport_beyond_former_leash: avanza hacia el jugador fuera de la zona, midiendo el paso máximo durante 180 ticks y conservando el límite <0,1 m/tick. |
| extended_occlusion_returns_home | extended_occlusion_keeps_aggro: mantiene referencia y memoria sin atacar a través de la pared. |

No se borran resultados/informes históricos. La prueba de oclusión breve, detección inicial, combate, colisiones, daño y muerte permanece. Los archivos nuevos de resultados tienen prefijo aggro_.

Los wrappers conservan los aislamientos históricos documentados: la pantalla automática de victoria se suspende únicamente en suites mecánicas que necesitan continuar física tras vencer; se prueba habilitada en las suites de menús/audio. Se mantienen las fixtures antiguas de entradas cortas, atacante autónomo y preparación de suelo del primer descanso. No se desactiva la memoria persistente para hacer pasar pruebas.

La ruta larga de 4B conserva su fixture histórica de 1000 puntos de vida para poder completar el recorrido automático, sin aumentar stamina ni apagar la IA. 4A conserva el control de decisiones del jefe durante sus pruebas de patrones concretos. Estas fixtures no se presentan como balance o jugabilidad real. El reintento integrado de 4B y las nuevas pruebas de muerte/descanso se ejecutan con vida normal y los coordinadores reales; los datos del proyecto no se modifican.

En la primera ejecución concatenada de suites nativas, las aserciones pasaron pero quedó un callback de foco diferido de la escena de menú antes de iniciar la siguiente fixture. Se conservan aggro_native_first.log y aggro_native_first_results.json. El runner ahora espera cuatro frames entre suites para terminar esa transición real; no cambia el menú ni elimina cobertura. El log final se evalúa por separado.

## Archivos

Modificados:

- scripts/enemies/soldier_ai.gd: única modificación jugable.
- tests/phase_3a_checks.gd: tres expectativas documentadas y nombre de métrica de persecución.

Creados:

- tests/aggro_checks.gd y aggro_results.json.
- tests/aggro_regressions.gd y resultados de regresión separados.
- tests/aggro_native_window.gd y test_aggro_native_launcher.gd: ejecución nativa desde Godot AI MCP de audio/menús y comprobaciones adicionales, sin modificar configuración global del editor.
- tests/aggro_integrity_baseline.json, aggro_integrity.json, logs y consultas reproducibles.
- Este informe.

No se modifican escenas, jefe, modelos, animaciones, jugador, HUD, tutorial, menús, audio ni datos de combate. No se instala navegación, plugins o recursos externos. No se avanza de fase.

## Regresiones ejecutadas

| Suite | Aprobadas | Total |
|---|---:|---:|
| 1A | 16 | 16 |
| 1B | 44 | 44 |
| 1C | 38 | 38 |
| 1D | 47 | 47 |
| 2A | 59 | 59 |
| 2B | 63 | 63 |
| 2C | 60 | 60 |
| 2D | 63 | 63 |
| 2E | 77 | 77 |
| 3A | 61 | 61 |
| 3B | 62 | 62 |
| 3C | 73 | 73 |
| phase_5b_checks.gd (nativa) | 73 | 73 |
| phase_5c_checks.gd (nativa) | 95 | 95 |
| phase_5c_followup.gd (nativa) | 5 | 5 |

La persecución fuera de la antigua zona registró un paso máximo de **0,033334 m por tick** durante la prueba histórica de 180 ticks, conservando la velocidad configurada. No es una medición de FPS ni una evaluación manual.

### Nivel integrado y tutorial

| Suite | Aprobadas | Total |
|---|---:|---:|
| 4A | 64 | 64 |
| 4B_CHECKS | 47 | 47 |
| 4B_SPATIAL | 26 | 26 |
| 4B_RETRY | 8 | 8 |
| 5A_CHECKS | 53 | 53 |
| 5A_CONTEXT_CHECKS | 10 | 10 |

Resultado final: **38/38 nuevas y 1044/1044 comprobaciones de regresión aprobadas**. Son aserciones ejecutadas en esta validación; no se suman resultados repetidos de entregas anteriores ni se cuentan lanzadores como verificaciones funcionales. Los resultados históricos permanecen en sus archivos originales.

La auditoría SHA-256 de **515 archivos jugables** detectó únicamente scripts/enemies/soldier_ai.gd como modificado; los otros **514** permanecen idénticos al inicio de esta tarea (aggro_integrity.json). Esta comparación no sustituye una evaluación jugable ni garantiza rendimiento en hardware de 4 GB.

## Arranques y logs finales

F5 se ejecutó mediante el modo main del editor: main_menu.tscn, foco Nueva partida, simulación sin pausa y victoria automática habilitada. F6 se ejecutó mediante el modo current con ruins_boss_arena.tscn abierta: protagonista en suelo, 100 de vida y cinco Estus; jefe con 600 de vida y fase 1. Se conservaron las preferencias del usuario y no se modificó project.godot. Evidencia: aggro_f5_startup.json y aggro_f6_startup.json.

Los logs de las regresiones, F5 y F6 no registran errores del run. El log nativo final está libre de errores; el fallo de concatenación de fixtures previo se conserva por separado. Se detuvo la ejecución dejando la arena artística abierta para F6 y el menú como escena principal para F5. No se avanzó a otra fase.
