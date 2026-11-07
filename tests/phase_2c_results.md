# Fase 2C — Ataques, combos, hitboxes y hurtboxes

Godot 4.6.3-stable; proyecto existente `C:/JUEGOs 3D/soul-game/`.
Trabajo y validación mediante Godot AI MCP.

## Inspección y archivos

Antes de editar se revisaron PlayerController, locomoción, ActionState,
ActorAttributes, SprintDodgeInput, DodgeController, lock-on, cámara, InputMap,
escenas y pruebas. Se reutilizan la propiedad de estados, consumo de stamina,
gravedad/colisiones, referencia horizontal y disponibilidad existentes.

Creados:
- `scripts/player/attack_controller.gd`.
- `scripts/combat/attack_data.gd`.
- `scripts/combat/attack_hitbox.gd` y `hurtbox.gd`.
- `scripts/combat/training_dummy.gd`.
- `scripts/combat/attack_debug.gd` y `combat_debug_geometry.gd`.
- `resources/attacks/light_1.tres`, `light_2.tres`, `heavy_1.tres`.
- `scenes/props/training_dummy.tscn`, derivada del prop anterior.
- `tests/phase_2c_checks.gd` y este informe.
- Los scripts incluyen UID generados por Godot.

Modificados:
- `scripts/player/player_controller.gd`: conecta el componente, procesa reloj e
  impactos dentro del tick físico y expone orientación visual para ataques.
- `scenes/player/player.tscn`: componente, CombatPivot, espada, hitbox y hurtbox.
- `scenes/levels/test_arena.tscn`: tres objetivos de entrenamiento, debug y ayuda.
- `project.godot`: solo nombres de capas CombatHitbox y CombatHurtbox añadidos.
- `tests/legacy_regressions.gd`: incluye 2B y registra que ataques están habilitados.
- `README.md`: controles, datos, reglas e interfaces actuales.

No se modificaron checks de suites anteriores, ActionState, atributos, esquivas,
selección de lock-on, cámara, parámetros de movimiento o InputMap (21 acciones).
Sin plugins, assets externos ni modificaciones de Blender.

## Arquitectura

AttackController interpreta flancos de las acciones existentes y admite una sola
solicitud pendiente por tick. Maneja datos, reloj, buffer y orientación; reclama
ATTACKING con el protocolo de dueño existente. Player conserva el único
`move_and_slide()`. La hitbox solo consulta volumen/aplica impactos, y Hurtbox
valida actor, facción, disponibilidad, invulnerabilidad y atributos.

La espada y hitbox pertenecen a CombatPivot, separado de Visual/cuerpo físico.
Fuera de ataques la espada sigue la orientación visual normal. El cuerpo físico
no gira por efecto del componente de combate.

## Datos y reloj

| Ataque | Startup | Active | Recovery | Daño | Stamina |
| --- | --- | --- | --- | --- | --- |
| LIGHT_1 | 0,25 s | 0,15 s | 0,40 s | 20 | 18 |
| LIGHT_2 | 0,30 s | 0,15 s | 0,45 s | 25 | 20 |
| HEAVY_1 | 0,55 s | 0,20 s | 0,65 s | 45 | 35 |

Son los valores iniciales solicitados, configurables en Resources y no verificados
como valores exactos de Dark Souls 1. Se validan y copian al iniciar. Tiempos,
daño, coste, ventanas de combo y corrección angular cambian sin reescribir código.

STARTUP no tiene hitbox. ACTIVE la habilita y RECOVERY la deshabilita. El reloj
avanza con delta de física, a 60 Hz, y las fronteras usan una pequeña tolerancia
numérica. Se bloquean traslación y carrera en las tres etapas, sin alterar los
valores de locomoción; gravedad y cápsula física siguen activas. No hay root motion
ni avance del ataque. Tras RECOVERY completa se libera el estado a FREE.

No hay cancelación por carrera, movimiento, otra solicitud o rodada. DEAD tiene
prioridad, apaga hitbox y borra entradas. `interrupt_for_damage()` es un punto de
integración explícito hacia el STAGGERED provisional: no se invoca automáticamente
al recibir daño ni implementa poise, tiempos/animaciones de stagger o IA.

La regeneración se bloquea durante todo ATTACKING; cada golpe consume una vez al
iniciar. Al completar se reinicia el retraso de regeneración existente. Si falta
stamina se rechaza sin cobrar y sin cambiar de estado.

## Combo y buffer

RB/R1/J inicia LIGHT_1; RT/R2/K inicia HEAVY_1. Los eventos repetidos de botón o
gatillo ya presionado no generan ataques nuevos. Liberar y presionar constituye
otra solicitud. El receptor mantiene su latch incluso durante resets para no
convertir un botón mantenido en una nueva pulsación fantasma.

En LIGHT_1, una nueva pulsación ligera se acepta en `[0,40;0,72)` segundos desde
inicio. Capacidad de buffer: uno. Caducidad: 0,50 s desde la aceptación. Más
pulsaciones no acumulan ni extienden el plazo. LIGHT_2 empieza solo al terminar
todo LIGHT_1 (0,80 s), vuelve a comprobar stamina y cobra 20. No existe tercer
eslabón ni combo fuerte/mixto. Si el buffer expira o no hay stamina, queda FREE.
Muerte, reset e interrupción incompatible lo limpian y no se reproduce después.

El inicio por entrada se procesa en física. Si hay esquiva y ataque pendientes
en el mismo tick libre, la esquiva se procesa primero; la acción incompatible
se rechaza. No se añadieron ataques cargados ni variantes a dos manos.

## Orientación

Se parte del frente visual al iniciar. Durante STARTUP se corrige hacia entrada
libre relativa a cámara o hacia la referencia del objetivo: 100°/s y máximo 30°
respecto al frente inicial, configurables por recurso. No hay giro instantáneo
de 180°; para golpear en una dirección muy diferente hay que orientarse antes.
ACTIVE y RECOVERY congelan el rumbo del golpe, aunque se mueva el objetivo o
se cambie la entrada. La cámara continúa con su comportamiento habitual y la
selección/fijación no se reescribió. La orientación física permanece independiente.

## Hitbox, hurtbox y daño

Capas separadas: World=1, Player=2, CombatHitbox=4 (capa 3), CombatHurtbox=8
(capa 4). Las máscaras físicas anteriores permanecen. La cápsula física del
jugador no produce daño.

Hitbox ofensiva: Area3D + BoxShape3D de 1,5 × 1,6 × 1,8 m a 1,2 m delante y
1 m de altura. Hurtbox: Area3D + CapsuleShape3D propia. Las consultas usan
`intersect_shape` contra áreas de combate solo durante ACTIVE; no dependen de
la latencia de la lista de solapamientos de Area3D. La forma ofensiva se habilita/
deshabilita con asignación diferida segura, y el estado lógico de fase siempre
es la autoridad de daño. Fuera de ACTIVE su capa ofensiva es cero.

Una reserva por ID de instancia del actor impide repetir daño en el mismo golpe,
incluidas varias hurtboxes de ese actor. Actores distintos pueden recibir el
mismo golpe. La reserva se establece antes de callbacks. Se corta la iteración
si un callback cancela/mata al atacante o cambia el barrido; referencias liberadas
se comprueban antes de usarlas.

Se rechazan atacante propio, misma facción, facciones vacías, desactivados,
vida cero e invulnerabilidad del jugador. Los dos bandos iniciales son `player`
y `training`. No hay resistencias, poise, crítico ni daño elemental. Una comprobación
World adicional evita dañar a través de paredes, excluyendo cuerpos del atacante
y receptor. `Hurtbox.receive_hit` llama a la API de atributos y emite el daño
realmente aplicado; se respeta el límite de vida y los i-frames de 2B.

## Entrenamiento y debug

Los tres objetivos anteriores se convirtieron en instancias de training_dummy,
con mismas posiciones, IDs, geometría y referencias de lock-on. Usan el componente
ActorAttributes existente y muestran vida/último daño mediante Label3D. No tienen
ataques, movimiento o IA. A cero se deshabilitan disponibilidad de lock-on,
recepción de impactos y colisión física; queda un prop inactivo. El reset técnico
de atributos permite restaurarlos.

La espada es un BoxMesh estático, sin animación de cápsula. El debug muestra
nombre/fase, buffer e impactos confirmados; ACTIVE resalta la espada y el volumen
ofensivo. Hurtboxes usan contornos verdes de sus límites. `debug_enabled=false`
oculta estos contornos, la información de fases, vida de entrenamiento y resaltado;
la espada sigue visible. El debug previo de esquivas conserva su propio flag.

## Preparación para animaciones

Señales `attack_started`, `phase_changed` y `attack_finished`. Modo opcional
`animation_driven` con `set_phase_from_animation(ACTIVE/RECOVERY)` y
`finish_from_animation()`: exige orden y no acepta saltar directamente a RECOVERY.
En ese modo un evento ausente deja la acción pendiente; el modo por defecto es
el reloj físico. Las animaciones futuras deberán calibrar los datos de ventana/
buffer. No se añadieron AnimationTree, clips definitivos ni simulación de cargas.

## Pruebas nuevas y regresiones

Ejecución `r43001979-26`, Godot AI MCP:

| Suite | Resultado | Receptor corto de esquivas | Ataques |
| --- | --- | --- | --- |
| 2C nueva | **60/60** | habilitado | habilitados |
| 1A | **16/16** | habilitado | habilitados |
| 1B | **44/44** | aislado como en 2B | habilitados |
| 1C | **38/38** | habilitado | habilitados |
| 1D | **47/47** | aislado como en 2B | habilitados |
| 2A | **59/59** | aislado como en 2B | habilitados |
| 2B | **63/63** | habilitado | habilitados |

Pasaron las 60 nuevas y las 267 históricas. El aislamiento preexistente de
1B/1D/2A preserva sus expectativas expresas de que un toque corto no produjera
acción/coste antes de 2B. No se cambiaron checks individuales ni se debilitaron
expectativas; el runner solo se extendió a 2B y registra que los ataques permanecen
habilitados. No se presenta el subconjunto aislado como controles actuales completos.

Cobertura nueva: LIGHT_1, LIGHT_2, HEAVY_1, tiempos, hitbox solo ACTIVE, coste exacto,
falta de stamina, exclusión mutua, capacidad/validez/expiración de buffer, coste
del combo, RB mantenido y flanco analógico RT, deduplicación por actor y por
múltiples hurtboxes, varios actores, propio jugador, aliados, oclusión World,
vida/muerte del muñeco, pérdida de fijación al morir, orientación libre/fijada,
compromiso angular, rodadas incompatibles, retorno de movimiento, prioridad DEAD,
interrupción por callback, eventos futuros de animación e integración del HUD.

| Medición | Resultado |
| --- | --- |
| LIGHT_1 ACTIVE / RECOVERY / fin | 0,25 / 0,40 / 0,80 s |
| HEAVY_1 ACTIVE / RECOVERY / fin | 0,55 / 0,75 / 1,40 s |
| Vida tras LIGHT_1 | 80 de 100, un impacto |
| Vida tras combo | 55 de 100, dos impactos |
| Vida tras HEAVY_1 | 55 de 100, un impacto |
| Stamina tras LIGHT_1 / combo / HEAVY_1 | 82 / 62 / 65 de 100 |

Se revisaron capturas estáticas de espada, vida y debug, incluida una captura
con jugador congelado técnicamente en ACTIVE a t=0,30 s. No constituye revisión
continua de game feeling ni recorrido animado de espada. Se comprobó que el
debug, contornos e indicadores de vida pueden ocultarse y luego se restauró el jugador.

Logs finales sin errores/warnings de juego y sin errores nuevos del editor desde
cursor 10. Escena principal cargada por MCP con helper activo y
`current_run_errors=[]`.

## Límites y siguiente fase

No hay joystick físico conectado. RB y RT se simularon con eventos normalizados
de mando ID 7; otras solicitudes usaron API/acciones y física real. No se probaron
USB/Bluetooth, drivers o sensación de combate con mando físico. No se midió
rendimiento en la PC objetivo de 4 GB RAM.

La hitbox es estática y amplia: no reproduce arco, trayectoria o contacto del filo.
No hay root motion, desplazamiento de ataque, golpe aéreo, barrido continuo entre
ticks ni tratamiento completo de objetivos muy rápidos. El muestreo es a 60 Hz;
ventanas menores de un tick pueden no recibir muestra y deben evitarse/calibrarse.
Las consultas tienen límite de 32 áreas por muestra. La orientación inicial solo
corrige dentro del cono configurado, y el encuadre cercano conserva límites de 1C.

Se reforzó el corte de impactos tras interrupción en un callback y se añadió una
comprobación explícita; la suite final pasó 60/60. No se detectaron regresiones.
No se instalaron dependencias ni se cambió silenciosamente una expectativa antigua.

Preparado para 2D: datos por ataque, fases/señales y eventos de animación,
hitbox/hurtbox con facciones y daño real aplicado, deduplicación por barrido,
propiedad de acción e interrupción explícita. No se implementaron escudo, parry,
riposte, backstab, Estus, ataques a dos manos, equipamiento, IA, jefe o animaciones
definitivas. No se avanzó a la fase 2D.
