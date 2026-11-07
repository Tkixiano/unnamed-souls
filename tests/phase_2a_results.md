# Fase 2A — Vida, stamina y disponibilidad de acciones

Godot 4.6.3-stable, proyecto existente `C:/JUEGOs 3D/soul-game/`.
Implementación y pruebas con Godot AI MCP.

## Inspección

Antes de modificar se revisaron PlayerController, locomoción IDLE/WALK/RUN,
SprintDodgeInput, CameraRig, LockOnController, InputMap, escenas y suites previas.
Se confirmó versión/sesión existente. No se reconstruyó el proyecto.

El movimiento no tenía un bloqueo general por disponibilidad, así que se agregó
una consulta `can_move()` sin alterar velocidades, aceleración, desaceleración,
giro, gravedad, cámara o referencias de movimiento existentes. Lock-on mantiene
su selección/cambio y solo incorpora el bloqueo de adquisición/cancelación por DEAD.

## Archivos

Creados (con UID generado por Godot para los scripts):
- `scripts/systems/actor_attributes.gd`.
- `scripts/player/action_state.gd`.
- `scripts/systems/player_vitals_hud.gd`.
- `scenes/ui/player_vitals.tscn`.
- `tests/phase_2a_checks.gd`.
- Este informe.

Modificados:
- `scripts/player/player_controller.gd`: referencias a componentes, coste de
  carrera, histéresis de agotamiento y disponibilidad de movimiento/fijación.
- `scripts/player/lock_on_controller.gd`: recibe cambio de estado del jugador;
  cancela al morir y rechaza adquirir estando muerto. No cambia selección lateral.
- `scenes/player/player.tscn`: nodos Attributes y ActionState.
- `scenes/levels/test_arena.tscn`: HUD por referencia explícita y título 2A.
- `README.md`: parámetros, reglas, interfaces y ejecución de pruebas.

Sin cambios en InputMap, detector de joystick, intérprete B/Círculo, scripts
de cámara, parámetros de locomoción ni suites/informes de regresión anteriores.
Sin plugins nuevos, assets externos ni modificaciones de Blender.

## Componentes y parámetros

`Attributes` es un Node independiente. Expone saldos de consulta y máximos
editables; inicia completo según Inspector. Rechaza montos negativos o no finitos,
no permite sobregiros y recorta restauraciones a los máximos.

| Parámetro | Inicial |
| --- | --- |
| Vida / vida máxima | 100 / 100 |
| Stamina / stamina máxima | 100 / 100 |
| Regeneración | 25 puntos/s |
| Retraso tras consumo | 0,75 s |
| Coste de carrera | 12 puntos/s |
| Umbral de recuperación tras agotamiento | 15 puntos |

Valores provisionales ajustables; no se afirman valores exactos de Dark Souls 1.

API: `has_stamina`, `consume_stamina`, `restore_stamina`, `apply_damage`,
`restore_health`, `restore_all`, `set_regeneration_blocked` e
`is_regeneration_blocked`. Consumo devuelve éxito; daño y restauraciones devuelven
la cantidad realmente modificada. Cero es una operación sin coste/retraso nuevo.

Señales: `health_changed(current, maximum)`, `stamina_changed(current, maximum)`,
`died` y `fully_restored`. Muerte se emite una vez al pasar de vida positiva a cero.
Curación normal no revive; `restore_all()` es el reset explícito que, integrado
en Player, vuelve a FREE y limpia agotamiento/gesto. No mueve al jugador ni
implementa respawn.

## Regeneración y carrera

Regeneración mediante delta de física y contador escalar; no se crearon Timer
por acción. Cada consumo positivo exitoso reinicia el retraso; el tick de consumo
no regenera. Al cruzar el fin del retraso, solo regenera la fracción restante del
tick, hasta el máximo. La programación por física resuelve los límites a 60 Hz.

Los bloqueos se identifican por dueño: `sprint`, `action_state` y futuros
consumidores. Quitar uno conserva los demás. El contador puede transcurrir
durante bloqueo, pero no se restauran puntos hasta liberarlo. Vida cero impide
regeneración automática. `restore_all` reinicia explícitamente contador y bloqueos.

Carrera mantiene la interpretación original de pulsación larga de 0,25 s.
Consume 12 × delta; si no alcanza para otro tick, consume el remanente y pasa a
caminar. La velocidad frena con la desaceleración existente. No vuelve a correr
hasta recuperar 15 puntos (umbral efectivo limitado a la capacidad máxima).
Una vez reanudada, puede bajar de 15 hasta cero sin alternar estados alrededor
del umbral. Mantener B permite reanudar al recuperarse si existe movimiento.
Caminar no consume y estar quieto con B no se considera carrera.

No se cambió SprintDodgeInput: las pulsaciones cortas y sus liberaciones siguen
disponibles para futuras rodadas; las prolongadas siguen reportándose. No hay
rodadas, ataques ni gasto de stamina de otras acciones implementados.

## Estados de acción

Componente separado con FREE, ATTACKING, DODGING, BLOCKING, PARRYING, HEALING,
STAGGERED y DEAD. No duplica IDLE/WALK/RUN.

API: `current_state`, `can_transition_to`, `transition_to`, `can_move`,
`can_sprint`, `blocks_regeneration`, `reset_to_free`; señal
`state_changed(previous, current)`.

Desde FREE puede entrar a otro estado. Un estado ocupado debe volver a FREE
antes de iniciar otro incompatible; DEAD puede interrumpir cualquier estado.
IDs fuera del enum y transiciones al mismo estado se rechazan. Desde DEAD ninguna
solicitud normal permite salir; el reset explícito es una operación separada.

Los estados intermedios solo reservan disponibilidad: provisionalmente bloquean
movimiento/carrera y regeneración. No ejecutan mecánicas, animaciones o tiempos
de acción ni se activan mediante botones de ataque/defensa/curación en esta fase.

Al morir Player detiene su desplazamiento horizontal y carrera, mantiene gravedad
y colisiones y notifica el estado. LockOnController cancela inmediatamente por
señal, vuelve a cámara FREE y rechaza nueva adquisición. Stamina cero no afecta
mantener/cambiar objetivos o moverse lateralmente. Correr sigue liberando lock-on;
agotarse no readquiere automáticamente un objetivo.

## HUD

Escena reemplazable con referencia exportada a Attributes, barras ProgressBar y
StyleBoxFlat de color. Se inicializa al conectarse y se actualiza exclusivamente
por señales; no consulta atributos en `_process`. Muestra valores de depuración
y máximos. Cabe dentro del viewport 1280 × 720, debajo del texto existente.

No se añadieron menús, inventario ni teclas de daño/curación. El daño técnico se
invoca por API/MCP, no proviene de enemigos. Se revisaron capturas estáticas del
HUD completo y con vida 75/stamina 60; esto no acredita game feeling, animación
continua ni percepción de movimiento con un mando real.

## Pruebas y regresiones

Ejecución final de suites: `r7630626-16`, mediante Godot AI MCP.

| Suite | Aprobadas |
| --- | --- |
| Fase 2A | **59/59** |
| Regresión 1A | **16/16** |
| Regresión 1B | **44/44** |
| Regresión 1C | **38/38** |
| Regresión 1D | **47/47** |
| Total | **204/204** |

Cobertura nueva: inicialización según máximos, consumo atómico, sobregiros,
negativos/NaN/Inf, límites de vida/stamina, curación, señales, retraso y tasa de
regeneración, propietarios independientes de bloqueo, regeneración numérica
con deltas 1/30, 1/60 y 1/120 s, disponibilidad/entrada/salida de estados, IDs
inválidos, incompatibilidades, DEAD terminal y reset explícito.

Integración: caminar sin consumo, coste continuo de carrera, ausencia de
regeneración corriendo, agotamiento, frenado a caminar, umbral 15 e histéresis,
regeneración automática en física real, políticas ocupadas, strafe/switch con
stamina cero, pulsaciones cortas/largas, salida de lock-on al correr, muerte,
cancelación inmediata de fijación, bloqueo de movimiento y actualización del HUD.
Las suites previas siguen comprobando movimiento, cámara, colisiones y fijación.

| Medición | Resultado |
| --- | --- |
| Gasto en 30 ticks de carrera (0,5 s) | 6 puntos |
| Stamina tras 2 s de regeneración, consumo inicial de 50 y retraso 0,75 s, deltas 30/60/120 | 81,25 / 81,25 / 81,25 |
| Stamina tras 1,5 s en prueba de runtime, desde 50 | 68,333 puntos, con resolución por ticks |
| Stamina tras reanudar desde 15 durante 24 ticks | 10,2 puntos, manteniendo RUN |

Los deltas alternativos se ensayaron numéricamente, sin afirmar tres tasas de
render reales. Consumo/regeneración integrados se ejecutaron con física a 60 Hz.
Sin errores de parser/runtime nuevos ni warnings de juego en la ejecución final;
logs del editor desde cursor 8 limpios. MCP confirmó escena principal cargada,
helper activo y `current_run_errors=[]`.

## Problemas encontrados y límites

La primera suite pasó 58/59: esperaba velocidad máxima tras 15 ticks al reanudar
carrera mientras cambiaba de adelante a derecha. Se comprobó RUN y velocidad
4,961 m/s en ese punto y 6 m/s a los 24 ticks. Se sincronizó el test con la
aceleración existente, sin cambiar valores ni eliminar la comprobación de velocidad.
La ejecución actualizada pasó 59/59 y las regresiones completas pasaron intactas.

No había joystick físico conectado. Las entradas se simularon con acciones y
eventos normalizados de mando; no se validaron USB/Bluetooth, drivers ni game
feeling real. No se midió rendimiento en el hardware objetivo de 4 GB RAM.
El HUD es provisional, sin animación de barras ni efectos de pérdida. La muerte
no tiene animación ni respawn. Los límites de cámara/bordes abiertos de la arena
permanecen como en fases anteriores.

## Preparado para la siguiente fase

APIs de gasto/consulta/restauración y señales reutilizables, bloqueos de
regeneración por dueño, estados/consultas de disponibilidad, transiciones
controladas, orientación y movimiento existentes, contrato de objetivo e
intérprete original de botón compartido. Sistemas futuros pueden solicitar
disponibilidad y gasto antes de iniciar acciones, sin duplicar locomoción.

No se implementaron ataques, rodadas, bloqueo efectivo, parry, Estus, daño de
enemigos, IA, equipamiento ni animaciones definitivas. No se avanzó de fase.
