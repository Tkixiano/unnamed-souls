# Fase 1D — Lock-on y movimiento fijado

Godot 4.6.3-stable. Proyecto existente: `C:/JUEGOs 3D/soul-game/`.
Inspección y verificación con Godot AI MCP.

## Inspección y alcance

Se revisaron PlayerController, estados IDLE/WALK/RUN, intérprete compartido
de B/Círculo, CameraRig, jerarquía real de arena e InputMap antes de editar.
Se confirmó la sesión existente y se conservaron las 21 acciones, el detector
de mandos, la física a 60 Hz, Compatibility y las interfaces de cámara orbital.

No se implementaron daño, combate, stamina, rodadas, IA, enemigos funcionales
ni animaciones. Los tres objetivos son props estáticos con geometría primitiva.
No se instalaron plugins ni se tocaron archivos de Blender.

## Archivos

Creados, con UID de script generado por Godot cuando corresponde:
- `scripts/systems/lockable_target.gd`.
- `scripts/player/lock_on_controller.gd`.
- `scripts/systems/lock_on_indicator.gd`.
- `scenes/props/lockable_dummy.tscn`.
- `tests/phase_1d_checks.gd`.
- Este informe.

Modificados:
- `scripts/player/player_controller.gd`: referencia horizontal externa opcional
  mediante `set_movement_reference()` / `clear_movement_reference()`; conserva
  la rama original relativa a cámara al estar libre. No se alteraron velocidades,
  aceleración, frenado, estados, gravedad ni interpretación de B/Círculo.
- `scenes/levels/test_arena.tscn`: controlador con referencias exportadas,
  tres objetivos, marcador geométrico en HUD y texto de controles.
- `README.md`: funcionamiento, parámetros, interfaces y ejecución de pruebas.

No se modificaron InputMap, detector, intérprete de carrera, CameraRig,
SpringArm, pruebas anteriores ni informes históricos.

## Arquitectura

`LockableTarget` se añade al grupo `lockable_targets`. Contrato: ID estable,
LockPoint independiente de malla, cuerpo de colisión opcional, disponibilidad,
bandera alive y posiciones de referencia/fijación. Un ID vacío o un punto
inválido impiden adquirirlo. Ocultarlo, deshabilitarlo o marcar alive=false lo
invalida. No hay sistema de salud detrás de esa bandera.

`LockOnController` referencia Player y CameraRig explícitamente. En física a
prioridad −5 procesa R3 encolado, filtra candidatos, supervisa pérdida y cambia
de objetivo. Suministra la referencia horizontal y llama `face_direction()`
sobre Visual; el cuerpo físico no rota. Player sigue moviéndose a prioridad 0,
CameraRig sigue/actualiza a 10 y SpringArm resuelve colisión a 20.

La cámara usa su modo EXTERNAL y `set_orbit_angles()`: interpolación exponencial
con límite de velocidad angular. El rig y su brazo no se reemplazaron. Al
cancelar se conservan los ángulos y se retoma FREE sin recentrado automático.

El indicador es un Control con círculo y punto dibujados, sin texturas, sin
captura de mouse y sin barras de vida. Sigue LockPoint proyectado al viewport;
se oculta si la fijación termina, el objetivo es inválido o está fuera de pantalla.

## Parámetros y reglas

| Parámetro | Inicial |
| --- | --- |
| Adquisición / ruptura | 14 m / 18 m |
| Semicono de adquisición | 50° |
| Tolerancia de oclusión continua | 0,45 s |
| Máscara LOS | World=1 |
| Umbral de cambio / neutral | 0,65 / 0,25 |
| Suavizado de cámara / velocidad angular máxima | 6 s⁻¹ / 150°/s |
| Peso del encuadre / sesgo de altura | 0,5 / 2 m |

La distancia de ruptura efectiva es al menos la de adquisición. Adquirir exige
estar disponible, dentro del rango y cono, proyectado en pantalla y visible
tanto desde la cámara como desde el punto alto del jugador. Los rayos excluyen
Player y el cuerpo del propio candidato; paredes, columna y otros cuerpos siguen
ocultando. Se prioriza centro de pantalla y secundariamente cercanía, con ID
estable como desempate.

R3/Q adquiere o cancela. Sin candidato no cambia a cámara fijada. Se libera
automáticamente por invalidez/destrucción, muerte/desactivación/ocultamiento,
distancia o oclusión continua. Visibilidad recuperada reinicia la tolerancia.
No hay cambio automático a otro objetivo al perder el actual.

El stick derecho cambia a un candidato situado a izquierda/derecha del actual
en pantalla. Superar 0,65 consume un gesto; volver a ≤0,25 lo habilita otra vez.
Mantener el stick inclinado no encadena cambios. Sin candidato a ese lado se
conserva el actual. No se añadieron acciones ni un menú de remapeo.

## Movimiento y carrera

Libre: mismo cálculo relativo a cámara. Fijado: adelante hacia el objetivo,
atrás alejándose y laterales sobre su perpendicular, recalculada cada tick.
La base horizontal ortogonal conserva magnitud analógica y diagonal normalizada.
Visual sigue al objetivo también durante retroceso y reposo; la física conserva
su orientación y los estados IDLE/WALK/RUN existentes.

El intérprete original diferencia pulsaciones cortas y prolongadas con 0,25 s.
Una corta mantiene lock-on y emite su liberación sin ejecutar rodadas. Una
prolongada con movimiento activa `is_sprinting`; LockOnController lo detecta
en el siguiente tick, libera la fijación y devuelve la referencia a cámara.
Las señales de liberación corta/larga siguen disponibles para una fase posterior.

## Escenario

Objetivos inmóviles con cápsula, colisión World y Marker3D a 1,25 m:
- Center `(0,0,−6)`, ID `arena_center`.
- Left `(−3,0,−5)`, ID `arena_left`.
- Right `(3,0,−5)`, ID `arena_right`.

Se conservan suelo, paredes, columna, iluminación y estado de joystick.
Los identificadores deben asignarse de forma única y persistente en cada escena;
no se utiliza el ID de instancia de Godot como identidad estable.

## Resultados de pruebas

Ejecución `r4434627-13`, pruebas secuenciales por Godot AI MCP:

| Suite | Resultado |
| --- | --- |
| Fase 1D | **47/47** |
| Regresión 1A | **16/16** |
| Regresión 1B | **44/44** |
| Regresión 1C | **38/38** |
| Total | **145/145**, sin fallos finales |

La suite 1D comprueba adquisición por R3, cancelación, preferencia por centro,
ausencia de candidatos, rango, detrás de cámara, muerte/desactivación y paredes;
cambio lateral con neutral obligatorio, sin repetición ni cambio cuando no hay
candidato; pérdida por distancia, destrucción, invisibilidad y disponibilidad;
oclusión breve, recuperación de visibilidad y ruptura por oclusión persistente.

También comprueba encuadre de jugador/objetivo, separación del objetivo respecto
a la silueta del jugador, marcador proyectado y ocultamiento al cancelar;
transición de cámara limitada y cancelación sin salto de ángulos;
strafe izquierdo/derecho, aproximación, retroceso con orientación hacia enemigo,
diagonal, carrera contextual y preservación de las liberaciones del botón.
Colisión y recuperación del SpringArm se verifican mientras sigue fijado.

Mediciones: diagonal fijada **3,200 m/s**, distancia de cámara contra pared
durante fijación **2,609 m**; carrera alcanza los **6 m/s** existentes. Se
conservan los 16/44/38 checks de fases previas sin eliminarlos ni debilitarlos.

Logs de la ejecución final: sin errores ni warnings de runtime, sin errores
nuevos de editor desde cursor 8; carga de escena principal confirmada con helper
activo y `current_run_errors=[]`.

## Correcciones realizadas

La primera captura mostró que un encuadre horizontal terminaba ocultando el
objetivo central detrás del jugador. Se agregó un sesgo vertical configurable;
la captura posterior muestra el objetivo central y su marcador sobre la silueta.

La primera suite pasó 42/47: cinco consultas se realizaban inmediatamente después
de girar/teletransportar la cámara, antes de que su proyección y el SpringArm
actualizaran el estado. Se sincronizaron con ticks reales antes de consultar,
sin eliminar condiciones ni ampliar tolerancias de validación. La suite
actualizada pasó 47/47. No se detectaron regresiones en las fases anteriores.

## Límites y preparación para 2A

No hay joystick físico conectado. R3 y eje derecho se generan como eventos
normalizados de mando ID 7; desplazamiento/carrera también se simulan por acciones.
Se usa física y raycast reales, pero no se verificaron USB/Bluetooth, drivers,
entradas físicas ni game feeling con un mando real.

Revisión visual limitada a capturas de adquisición central y encuadre corregido;
estabilidad y transiciones temporales se comprobaron con muestras automatizadas,
sin afirmar una revisión visual continua o equivalencia exacta con Dark Souls 1.
No se midió rendimiento en la PC objetivo de 4 GB RAM.

El encuadre es sencillo: no cambia FOV/distancia para abarcar automáticamente
objetivos de cualquier altura o espacios extremos. Colisiones muy cercanas pueden
acercar la cámara a la cápsula, como en 1C. La arena conserva bordes abiertos y
no tiene respawn. No hay auto-reemplazo al perder el objetivo ni cambio vertical.

Para fase 2A quedan disponibles el contrato de objetivo, ID estable, disponibilidad,
`current_target`, `is_locked()`, `try_acquire()`, `switch_target(direction)`,
`release_lock(reason)`, señales `target_changed` / `lock_released`, la referencia
externa de movimiento y el intérprete de pulsaciones cortas/largas original.
No se avanzó a la fase 2A.
