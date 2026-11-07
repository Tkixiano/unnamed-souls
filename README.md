# Soul game — Fase 3C

Jefe de prueba: abrir `scenes/levels/boss_arena.tscn` y pulsar **F6**.
**F5** conserva la arena principal. Avanzá desde la hoguera hacia la entrada.

Base técnica con locomoción analógica para Godot 4.6.x / GDScript. Abrir
`project.godot` y ejecutar la escena principal con F5 (F6 ejecuta la escena abierta).
Mover con stick izquierdo o WASD; mantener B/Círculo/Espacio durante 0,25 s para
correr. Cámara orbital con stick derecho, flechas o arrastrando el mouse con el
botón derecho. R3/Q fija o libera objetivos; fijado, stick derecho/flechas cambia
de objetivo. Mantener carrera mientras se mueve libera la fijación.
Vida y stamina tienen componentes reutilizables y HUD provisional. Correr consume
stamina; agotarse obliga a caminar hasta recuperar el umbral configurado.
Soltar B/Círculo/Espacio antes del umbral ejecuta rodada con dirección o backstep
sin dirección. RB/R1/J inicia ligero; una segunda pulsación en ventana prepara
LIGHT_2. RT/R2/K inicia fuerte. Los tres objetivos reciben daño y muestran vida.
Mantener LB/L1/U levanta el escudo; LT/L2/I inicia parry. Tras un parry válido,
RB/R1/J tiene prioridad contextual para riposte frontal cercano.
F1–F4 preparan golpes del atacante técnico: frontal, no parryable, trasero y
rompeguardia. Reposicionan solo ese actor antes del golpe; son controles técnicos.
RB/R1/J prioriza riposte, luego backstab trasero cercano y finalmente ligero.
X/Cuadrado/E bebe Estus (5 cargas, curación diferida). Y/Triángulo/R cambia
empuñadura con compromiso temporal; a dos manos no hay escudo ni parry.
Hay un soldado con IA básica frente al jugador; detecta, persigue, ataca y recibe
daño, parry, riposte y backstab. La hoguera permite descansar y reaparecer al morir; no hay inventario ni guardado en disco.

## Controles actuales de teclado y mouse

| Acción | Control |
|---|---|
| Movimiento | WASD |
| Rodada con dirección / backstep sin dirección | Toque de Espacio y soltar |
| Carrera | Mantener Espacio mientras te movés (umbral 0,25 s) |
| Cámara | Flechas, o mover el mouse manteniendo el botón derecho |
| Fijar/liberar objetivo | Q o clic de rueda (botón central) |
| Cambiar objetivo fijado | Flecha izquierda/derecha; volver a neutral para otro cambio |
| Ligero / combo / riposte / backstab contextual | Clic izquierdo o J |
| Fuerte | Shift o K (una pulsación, no Shift + clic) |
| Escudo | Mantener Ctrl o L; U sigue disponible |
| Parry | C o I |
| Estus | E |
| Una/dos manos | R |
| Interactuar | F: encender / descansar cerca de la hoguera |
| Confirmar / cancelar menú | Enter / Retroceso (acciones preparadas; sin menús todavía) |
| Pausa | Escape (binding preparado; la pausa de juego todavía no está implementada) |
| Pantalla completa | F11 |
| Ataques técnicos | F1 frontal, F2 no parryable, F3 trasero, F4 rompeguardia |
| Reiniciar prueba | F5 desde el editor de Godot |

Distribución sin mouse: mano izquierda en WASD/Espacio/Q/E/R/F; mano derecha en
J (ligero), K (fuerte), L (escudo), I (parry), y flechas para cámara. Con mouse,
usá clic izquierdo, Shift, Ctrl y C para combatir junto a WASD. Se conservan
los bindings de mando y las teclas técnicas anteriores. El escudo/parry requieren
una mano y los críticos siguen siendo contextuales, no tienen tecla independiente.

## Estructura

- `scenes/`: player, enemies, bosses, levels, ui, props.
- `scripts/`: player, combat, enemies, systems.
- `assets/`: models, animations, textures, audio.
- `resources/`: recursos futuros; `tests/`: comprobaciones de esta fase.
- Las carpetas reservadas contienen `.gitkeep`, sin scripts vacíos.

## Archivos principales

- `scenes/levels/test_arena.tscn`: suelo primitivo con colisión, luz sin sombras,
  ambiente básico, cámara orbital, dos paredes, columna y estado de los mandos.
- `scenes/player/player.tscn`: CharacterBody3D con colisión y Visual independiente.
  El origen está a los pies; la cápsula mide 1,8 m. La marca ámbar señala −Z local.
- `scripts/player/player_controller.gd`: movimiento físico, orientación visual
  y estado de locomoción en funciones independientes.
- `scripts/player/sprint_dodge_input.gd`: interpretación del botón compartido.
- `scripts/systems/controller_registry.gd`: autoload ControllerRegistry.
- `scripts/systems/test_arena.gd`: indicador de mandos y pantalla completa.
- `tests/phase_1a_checks.gd`: comprobaciones de integración ejecutables por MCP.
- `tests/phase_1b_checks.gd`: integración de movimiento mediante eventos simulados.
- `scenes/props/camera_rig.tscn`: rig reutilizable con objetivo explícito.
- `scripts/systems/orbit_camera.gd`: órbita y seguimiento, separados del jugador.
- `scripts/systems/camera_spring_arm.gd`: recuperación de distancia sin atravesar
  la longitud segura que proporciona el SpringArm nativo.
- `tests/phase_1c_checks.gd`: integración de cámara, colisiones y locomoción.
- `scripts/player/lock_on_controller.gd`: adquisición, pérdida, cambio lateral,
  referencia de movimiento y orientación externa de cámara.
- `scripts/systems/lockable_target.gd`: contrato de objetivo independiente de malla.
- `scripts/systems/lock_on_indicator.gd`: marcador geométrico proyectado.
- `scenes/props/lockable_dummy.tscn`: objetivo primitivo inmóvil reutilizable.
- `tests/phase_1d_checks.gd`: pruebas funcionales de fijación y movimiento contextual.
- `scripts/systems/actor_attributes.gd`: vida, stamina, señales y regeneración.
- `scripts/player/action_state.gd`: disponibilidad y estados de acción independientes.
- `scenes/ui/player_vitals.tscn` y `scripts/systems/player_vitals_hud.gd`: HUD por señales.
- `tests/phase_2a_checks.gd`: validación de atributos, estados e integración.
- `scripts/player/dodge_controller.gd` y `dodge_profile.gd`: esquivas y perfiles.
- `resources/dodges/`: FAST, MEDIUM, HEAVY y backstep, editables como recursos.
- `scripts/systems/dodge_debug.gd`: texto de depuración desactivable.
- `tests/phase_2b_checks.gd` y `legacy_regressions.gd`: validación actual e histórica.
- `scripts/player/attack_controller.gd`: entradas, reloj, combo y orientación.
- `scripts/combat/attack_data.gd` y `resources/attacks/`: datos de los tres golpes.
- `scripts/combat/attack_hitbox.gd` / `hurtbox.gd`: detección, deduplicación y daño.
- `scenes/props/training_dummy.tscn` y `scripts/combat/training_dummy.gd`: variante
  de los objetivos anteriores con atributos, hurtbox e indicador de vida.
- `scripts/combat/attack_debug.gd` / `combat_debug_geometry.gd`: debug sin texturas.
- `tests/phase_2c_checks.gd`: pruebas de ataques e integración.

## Locomoción y parámetros

Seleccionar Player en `player.tscn` para ajustar los grupos del Inspector:

| Parámetro | Inicial | Unidad |
| --- | --- | --- |
| walk_speed | 3,2 | m/s a inclinación completa |
| run_speed | 6,0 | m/s a inclinación completa |
| acceleration | 14 | m/s² |
| deceleration | 20 | m/s² |
| turn_speed | 540 | grados/s |
| input_deadzone | 0,22 | radio normalizado |
| sprint_hold_threshold | 0,25 | segundos |

Son valores iniciales ajustables, no mediciones exactas de Dark Souls 1.
`Input.get_vector()` conserva magnitud analógica, aplica deadzone circular y
normaliza diagonales. El controlador usa su deadzone exportada explícitamente,
sin modificar InputMap. La respuesta después de la deadzone es lineal hasta 1.
La velocidad normal escala con esa magnitud; la carrera también.

La dirección usa la cámara activa (o `movement_camera` asignada en la arena),
proyectando su frente al plano XZ y reconstruyendo el eje lateral ortogonal.
La física se ejecuta en `_physics_process(delta)` con aceleración/frenado,
gravedad de Godot y `move_and_slide()`. Suelo: snap 0,25 m, pendiente máxima
45°, detención en pendientes y velocidad constante sobre pendientes.
No se agregó control de salto ni mecánicas aéreas.

Solo gira `Visual`, con límite angular por segundo. El cuerpo y su colisión
permanecen independientes. `orient_to_movement=false` y
`face_direction(direction, delta)` permiten que un sistema posterior decida la
orientación. El componente de fijación usa estas interfaces sin girar el cuerpo.

Estados consultables: `LocomotionState.IDLE`, `WALK`, `RUN`; propiedad
`locomotion_state` y señal `locomotion_state_changed`. Además se exponen
`movement_input`, `movement_direction`, `horizontal_speed` e `is_sprinting`.
El estado usa velocidad horizontal física: durante el frenado sigue en WALK;
al detenerse pasa a IDLE. La marca frontal usa el mismo Visual que el futuro modelo.

El intérprete del botón registra press/release mediante eventos, incluso entre
ticks, y mide la duración por tiempo de física. No marca los eventos como
consumidos. `sprint_dodge_released(held_seconds, was_long_press)` informa cada
liberación, ahora atendida por el receptor de esquivas. Un tap entre ticks informa duración 0.
La carrera requiere superar el umbral y tener entrada de movimiento.
La pérdida de foco cancela el gesto sin iniciar una esquiva.

La arena conserva bordes abiertos; todavía se puede caer del suelo. Detener y
volver a ejecutar con F5 restablece el inicio. No se añadió respawn.

## Cámara orbital

Jerarquía reutilizable en `scenes/props/camera_rig.tscn`:

```text
CameraRig (orbit_camera.gd; prioridad física 10)
└── YawPivot
    └── PitchPivot
        └── SpringArm3D (camera_spring_arm.gd; prioridad física 20)
            └── Camera3D
```

El Player sigue usando su mismo controlador, sin cambios en su código. Su
propiedad `movement_camera` apunta a la cámara del rig. `follow_target` del rig
apunta explícitamente a Player desde la escena de arena. La cámara no gira el
cuerpo ni Visual: el jugador solo orienta Visual cuando recibe movimiento.

Parámetros del rig, editables en el Inspector:

| Parámetro | Inicial |
| --- | --- |
| follow_height | 1,25 m |
| normal_distance | 4,5 m |
| minimum_distance | 0,55 m preferidos; la colisión tiene prioridad |
| follow_smoothing | 14 s⁻¹; 0 desactiva el suavizado |
| distance_recovery | 8 s⁻¹; 0 recupera inmediatamente |
| horizontal_sensitivity | 150°/s |
| vertical_sensitivity | 110°/s |
| input_deadzone | 0,22 circular |
| minimum_pitch / maximum_pitch | −65° / +35° |
| initial_yaw / initial_pitch | 0° / −18° |
| invert_vertical | false |
| mouse_enabled / mouse_sensitivity | true / 0,16° por píxel |

Son valores iniciales para ajustar jugando, no valores exactos de Dark Souls 1.
El stick se lee con las cuatro acciones existentes mediante `Input.get_vector`.
La velocidad angular usa delta; el mouse usa desplazamiento acumulado en píxeles,
sin multiplicarlo otra vez por delta. El mouse solo controla mientras se arrastra
con botón derecho y no captura el cursor. Joystick y mouse pueden coexistir.
No se cambió el InputMap ni se agregó un menú de remapeo.

Seguimiento exponencial en física después del movimiento del personaje; brazo
procesado después del rig. Se habilitó `physics/common/physics_interpolation`
en el proyecto para interpolar las poses físicas al renderizar, sin mover el
personaje o la cámara de nuevo desde `_process`. Esto conserva física a 60 Hz.
Los teletransportes deben llamar a `reset_physics_interpolation()` en Player y
`snap_to_target()` en el rig para evitar interpolar desde la posición antigua.

Colisión: barrido esférico de radio 0,25 m, margen 0,08 m y máscara World (1).
Player usa capa 2 y además se excluye su RID al asignar el objetivo. La cámara
tiene near=0,05 m. El SpringArm obtiene la longitud segura cada tick; el pequeño
script complementario permite acercamiento inmediato y retorno exponencial.
Suavizar también la contracción mantendría la cámara detrás de una pared durante
algunos frames, por eso la seguridad tiene prioridad. En un espacio menor que
0,55 m se permite bajar del mínimo preferido para no forzar la cámara a través
de geometría. No hay transparencia de personaje ni solución de espacios donde
el propio punto de seguimiento quede dentro de una pared.

Interfaces disponibles para una fase posterior:

- `get_orbit_angles()` / `set_orbit_angles(yaw, pitch)`: radianes; pitch limitado.
- `get_follow_target()` / `set_follow_target(target, snap=true)`.
- `snap_to_target()`: seguimiento inmediato y reinicio de interpolación.
- `set_control_mode(ControlMode.EXTERNAL)`: suspende stick/mouse, conserva seguimiento.
- `set_control_mode(ControlMode.FREE)`: retoma entrada sin recentrado automático.
- `camera`, `spring_arm` y `control_mode` consultables.

El modo EXTERNAL solo deja que otro sistema proporcione ángulos. En fase 1D,
LockOnController lo utiliza para encuadrar al objetivo sin reemplazar el rig.

## Lock-on y objetivos

`LockOnController` es un nodo independiente con referencias exportadas a Player
y CameraRig. Corre a prioridad física −5: actualiza la referencia horizontal y
la orientación visual antes de locomoción (0), rig (10) y SpringArm (20).
No implementa física propia ni modifica estados IDLE/WALK/RUN.

Los componentes `lockable_target.gd` se registran en `lockable_targets`. Cada uno
expone `target_id` estable y no vacío, `lock_point`, `collision_body` opcional,
`available` y `alive`; ofrece `is_available()`, `get_reference_position()` y
`get_aim_position()`. `alive` es una bandera para integración futura, no un
sistema de vida. Ocultar el componente, deshabilitarlo o destruir su punto
también lo invalida. No requiere un esqueleto o malla concretos.

La arena contiene objetivos estáticos Center `(0,0,−6)`, Left `(−3,0,−5)` y
Right `(3,0,−5)`, con IDs `arena_center`, `arena_left` y `arena_right`.
Sus cápsulas tienen colisión World=1; los rayos excluyen el propio cuerpo del
candidato y el jugador. Paredes, columna y otros objetivos siguen ocluyendo.

Parámetros de fijación en Inspector:

| Parámetro | Inicial |
| --- | --- |
| acquisition_distance | 14 m |
| break_distance | 18 m, efectivo nunca menor que adquisición |
| acquisition_half_angle | 50° respecto al frente de cámara |
| occlusion_grace | 0,45 s continuos |
| visibility_mask | World=1 |
| switch_threshold / switch_neutral | 0,65 / 0,25 |
| camera_smoothing | 6 s⁻¹ |
| maximum_camera_turn | 150°/s |
| framing_weight | 0,5 hacia el punto intermedio |
| framing_height_bias | 2 m de sesgo de encuadre |

Al pulsar R3/Q, se adquiere un objetivo válido o se cancela el actual. La
adquisición exige rango, cono de cámara, proyección dentro de pantalla y dos
rayos libres: desde la cámara y desde el punto alto del jugador hasta LockPoint.
Entre candidatos se prioriza la distancia al centro de pantalla, con una pequeña
preferencia adicional por cercanía; empates se resuelven por `target_id`.
No se adquiere a través de una pared. Sin candidato, se conserva cámara libre.

La fijación se pierde por distancia de ruptura, objetivo inválido, no disponible,
muerto/oculto/destruido, o por oclusión continua superior a la tolerancia. Una
oclusión breve no libera el objetivo; al recuperar visibilidad se reinicia el
temporizador. No hay adquisición automática de reemplazo al perder un objetivo.

El cambio usa las acciones existentes `camera_left/right`. Un gesto supera
0,65 para seleccionar el candidato más próximo a ese lado del objetivo actual
en pantalla; debe volver a ≤0,25 para habilitar otro gesto. Se conservan filtros
de visibilidad, distancia y disponibilidad. Si no hay candidato, conserva el
actual. No hay cambio vertical ni remapeo nuevo.

Sin fijación se ejecuta la rama original de movimiento relativo a cámara. Con
fijación, `set_movement_reference(forward)` proporciona un eje horizontal hacia
el objetivo y su perpendicular: adelante acerca, atrás aleja y los laterales
rodean al objetivo. La magnitud/diagonal, aceleración y colisiones siguen a cargo
del controlador existente. `face_direction()` gira Visual hacia el objetivo,
también al retroceder o estando quieto. Al liberar, `clear_movement_reference()`
y la restauración de `orient_to_movement` devuelven el comportamiento libre.

El intérprete original de B/Círculo no cambió. Una pulsación de menos de 0,25 s
emite su liberación corta e inicia esquiva sin cancelar fijación; la prolongada activa el intento
de carrera existente. Si hay movimiento, el componente detecta `is_sprinting`
en el siguiente tick, cancela lock-on y continúa con movimiento libre. Las
liberaciones cortas/largas se conservan y el receptor de esquivas ignora la larga.

La cámara recibe ángulos con interpolación exponencial y límite angular, sin
cambiar el seguimiento ni el SpringArm. Un sesgo vertical mantiene al objetivo
por encima de la silueta del jugador. Cancelar conserva los ángulos actuales y
devuelve FREE sin recentrar. El marcador circular se dibuja en un Control sin
capturar mouse: solo es visible con objetivo válido y proyección en pantalla;
se actualiza en render y no usa texturas externas ni barras de vida.

Interfaces de fijación: `try_acquire()`, `release_lock(reason)`, `is_locked()`,
`switch_target(direction)`, `current_target`, `last_release_reason` y señales
`target_changed(target)` / `lock_released(reason)`. Las consultas de adquisición
y cambio con raycast deben realizarse con el mundo físico actualizado; la ruta
de entrada normal encola R3 y lo procesa en física. Tras teletransportes, esperar
actualización del SpringArm y proyección de cámara antes de consultas manuales.

La base 2A conserva objetivos con ID/punto independiente del modelo, banderas de
disponibilidad, señales de cambio/pérdida, referencia de movimiento externa y
liberaciones del botón compartido. No se implementó combate anticipado.

## Vida, stamina y estados de acción

Player incorpora dos nodos hijos: `Attributes` y `ActionState`. Atributos no
conoce cámara, HUD ni fuentes de daño. ActionState solo gestiona disponibilidad;
IDLE/WALK/RUN permanecen en locomoción y no se duplican.

Parámetros de `Player/Attributes` y del controlador, ajustables en Inspector:

| Parámetro | Inicial |
| --- | --- |
| max_health / max_stamina | 100 / 100 |
| stamina_regeneration | 25 puntos/s |
| regeneration_delay | 0,75 s |
| sprint_stamina_cost (Player) | 12 puntos/s |
| sprint_resume_stamina (Player) | 15 puntos |

Son valores provisionales, no valores exactos de Dark Souls 1. Los atributos
inician completos según sus máximos. Los valores actuales se consultan mediante
`current_health` / `current_stamina`; se modifican por métodos, no por asignación.

Métodos de atributos:

- `has_stamina(amount)` y `consume_stamina(amount)`: consulta y gasto atómico.
  Un gasto superior al saldo se rechaza sin cambios; no deja valores negativos.
- `restore_stamina(amount)`, `apply_damage(amount)` y `restore_health(amount)`:
  devuelven la cantidad realmente modificada, limitada por cero y el máximo.
- `restore_all()`: reset explícito de vida/stamina, retraso y bloqueos; en Player
  también restaura FREE y el latch de agotamiento. No equivale a un sistema de respawn.
- `set_regeneration_blocked(reason, blocked)`: bloqueos por dueño identificable;
  quitar uno no elimina los de otros componentes.
- Señales `health_changed(current, maximum)`, `stamina_changed(current, maximum)`,
  `died` y `fully_restored`. Muerte se emite una sola vez por agotamiento de vida.

Montos negativos o no finitos se rechazan. Un gasto cero no reinicia el retraso.
Curación normal no revive vida cero; solo el reset explícito lo hace en esta fase.
Cambiar un máximo en ejecución recorta el saldo si hace falta y notifica al HUD.

La regeneración se calcula en física con delta y un contador escalar, sin Timer
por acción. Solo regenera la parte del tick posterior al retraso, hasta el máximo.
El tick que registra consumo no regenera. Un consumo válido nuevo reinicia el
retraso. Los bloqueos permiten que el contador transcurra, pero impiden restaurar
stamina mientras estén activos. DEAD impide regeneración automática.

La carrera consume cada tick después de interpretar el botón original. Si queda
menos que el coste del tick, consume el remanente, pasa a caminar y queda inhibida.
La desaceleración existente devuelve la velocidad a caminar; no se cambian valores
de movimiento. Tras agotarse, solo se habilita otra vez con 15 puntos (o el máximo
si la capacidad configurada es menor). Una vez habilitada puede seguir bajando de
15 hasta cero: esa histéresis evita alternancias alrededor del umbral. Si se
mantiene B y hay movimiento, puede reanudar automáticamente al recuperar el umbral.
Caminar no consume; carrera bloquea regeneración. La pulsación corta del botón
y sus señales siguen intactas; el nuevo componente atiende únicamente la corta.

ActionState define FREE, ATTACKING, DODGING, BLOCKING, PARRYING, HEALING,
STAGGERED y DEAD. `current_state`, `can_transition_to()` y `transition_to()`
permiten consultar/solicitar cambios; `state_changed(previous, current)` los
notifica. Desde FREE puede entrar a un estado; un estado ocupado debe volver a
FREE antes de iniciar otro incompatible. DEAD puede interrumpir cualquiera.
IDs inválidos, repetición del mismo estado y solicitudes normales para salir de
DEAD se rechazan. `reset_to_free()` es una operación explícita de reinicio.

DODGING y ATTACKING están implementados mediante un dueño de acción: no admiten cancelaciones
normales a FREE ni otras acciones hasta completar la recuperación. DEAD puede
interrumpirlos y el reset explícito sigue disponible. Los otros cuatro estados
intermedios continúan como disponibilidad provisional, sin mecánicas. No hay
defensa, parry, curación ni stagger efectivos.

Player expone `can_move()` y `can_lock_on()`. Al morir pasa a DEAD, detiene el
desplazamiento horizontal y conserva gravedad/colisiones. El lock-on se cancela
por señal inmediatamente y no se puede readquirir estando muerto. Stamina cero
no impide fijar, cambiar objetivos o moverse lateralmente. Carrera sigue liberando
el lock-on; agotarse no provoca una nueva fijación automática. La cámara conserva
su funcionamiento orbital, sin efectos de muerte añadidos.

El HUD usa ProgressBar y StyleBoxFlat nativos. Recibe señales de atributos y
carga su valor inicial al conectarse; no consulta valores en `_process`. Puede
reemplazarse cambiando la escena UI y su referencia exportada a Attributes.
No se agregaron teclas de daño/curación, menús, inventario ni Estus: las APIs
pueden invocarse técnicamente desde MCP, por ejemplo `player.attributes.apply_damage(25)`.

## Rodadas y backstep

Player incorpora `DodgeController`. El componente escucha la señal de liberación
existente, captura dirección al soltar y procesa la petición en el siguiente tick
de física (o en ese mismo tick si la liberación se detecta por polling). No usa
índices físicos de mando, no agrega acciones y no cambia SprintDodgeInput.

- Toque corto con dirección: rodada libre relativa a cámara; con referencia del
  lock-on, cuatro cardinales relativas al objetivo. Gana el eje de mayor magnitud;
  empate exacto de diagonal gana adelante/atrás. La distancia no depende de cuánto
  se inclina el stick después de superar la deadzone.
- Toque corto sin dirección: backstep opuesto al frente de Visual, conserva su
  orientación y usa perfil/coste propios.
- Mantener ≥0,25 s con dirección: carrera existente. Su liberación no genera
  esquiva. No se añadió salto desde carrera ni una variante especial de running roll.

Aquí ambas esquivas se activan al soltar, no al presionar, sin buffer de acciones
ocupadas. No se verificó el instante exacto de activación de DS1; el umbral y
esta decisión de liberación conservan el contrato de las fases previas.

La carga provisional `equipment_load_percent` no viene de inventario. Categorías:
FAST ≤25%, MEDIUM >25–50%, HEAVY >50–100%, OVERLOADED >100%. OVERLOADED rechaza
rodada y backstep sin coste, desplazamiento o animación de fallo. El peso en esta
fase solo selecciona esquivas; no altera velocidades de marcha/carrera existentes.

| Perfil | Total s | Desplazamiento s | Distancia m | I-frames s [inicio, fin) | Recuperación s |
| --- | --- | --- | --- | --- | --- |
| FAST | 0,60 | 0,30 | 3,00 | [0,04; 0,30) | 0,20 |
| MEDIUM | 0,78 | 0,36 | 2,60 | [0,06; 0,30) | 0,30 |
| HEAVY | 1,10 | 0,45 | 2,00 | [0,10; 0,28) | 0,45 |
| BACKSTEP | 0,45 | 0,18 | 1,00 | [0,00; 0,10) | 0,18 |

Todos son valores provisionales, no frames exactos de DS1. En particular el
backstep tiene una ventana breve independiente, sin asumir que equivale a la
rodada ni afirmar que 0,10 s sea el valor original. Recursos `.tres` permiten
ajustar o anular su ventana con inicio=fin. La recuperación ocupa el final del
tiempo total; entre fin de desplazamiento y recuperación puede existir un tramo
estacionario. El perfil se valida y se copia al empezar para evitar cambios en vuelo.

Coste inicial: rodada 25, backstep 15, ajustables en Inspector. Falta de stamina,
estar ocupado, sobrecarga o no tener suelo rechazan el inicio sin cobrar. La
dirección queda fija. DODGING se reclama por dueño antes de emitir su señal;
solo ese dueño puede completarlo normalmente. Movimiento, carrera u otra acción
no lo cancelan. Muerte/reset limpian acción, impulso e invulnerabilidad de forma segura.

Player mantiene el único `move_and_slide()`. Dodge entrega velocidad horizontal
calculada integrando una curva de distancia ease-out por intervalos; gravedad,
suelo y paredes siguen activos. No se desactiva CollisionShape3D ni se deforma o
hace rodar la cápsula. Durante la acción se congela su orientación visual inicial;
al terminar se retoma orientación normal/fijada. Chocar no devuelve stamina ni
cancela la recuperación. Salir por un borde permite caer; no hay esquivas nuevas
en aire, levitación, barrera invisible o protección contra caída implementada.

Regeneración bloqueada durante toda la acción, incluido recovery. Al completar
reinicia el retraso existente de 0,75 s sin cobrar otra vez. La carrera conserva
su coste continuo y latch de agotamiento de 2A.

`Player.is_invulnerable()` y `can_receive_attack()` son consultas para un futuro
receptor de impactos. Ahora `Hurtbox.receive_hit` consulta esa disponibilidad antes
de modificar atributos. No interceptan llamadas directas a `Attributes.apply_damage`,
que sigue siendo una API técnica. No hay IA ni fuentes ofensivas de enemigos.
La invulnerabilidad solo cubre la ventana configurada, no todo DODGING.

`DodgeController.debug_enabled=false` oculta el texto de perfil/acción/i-frames.
No afecta mecánicas. `input_enabled=false` desconecta únicamente el receptor de
liberaciones cortas (por ejemplo, pruebas históricas); `try_dodge(Vector2)` sigue
disponible como API técnica. El juego inicia con ambos activados.

## Configuración

1280 × 720, ventana redimensionable, escalado `canvas_items`, F11 para alternar
pantalla completa. Física a 60 Hz. Compatibility/OpenGL para gráficos integrados.
La ventana embebida del editor solo permite modo ventana; probar F11 ejecutando
el juego en una ventana independiente. No se cambió esa preferencia del editor.
Se conserva Jolt, que ya estaba configurado. Sin sombras, SSAO, SSR, glow, niebla
volumétrica ni assets externos. Mouse visible y sin captura; sin emulación táctil.
Zonas muertas: sticks 0,22, gatillos/botones 0,5. Capas: World=1, Player=2.
No se añadieron plugins; se conserva Godot AI y su helper existente.

El objetivo es Ryzen 7 con gráficos integrados y 4 GB RAM. Esta escena mínima
no constituye una validación de rendimiento del juego final en ese hardware.

## InputMap

Joystick como dispositivo principal. Los nombres son acciones semánticas;
el código futuro debe consultar InputMap, no índices físicos directamente.

| Acción | Xbox | PlayStation equivalente | Teclado técnico |
| --- | --- | --- | --- |
| move_left / move_right | Stick izquierdo X | Stick izquierdo X | A / D |
| move_forward / move_backward | Stick izquierdo Y | Stick izquierdo Y | W / S |
| sprint_dodge | B | Círculo | Espacio |
| camera_left / camera_right | Stick derecho X | Stick derecho X | Flechas izquierda / derecha |
| camera_up / camera_down | Stick derecho Y | Stick derecho Y | Flechas arriba / abajo |
| lock_on | R3 | R3 | Q |
| light_attack | RB | R1 | J |
| heavy_attack | RT | R2 | K |
| block | LB | L1 | U |
| parry | LT | L2 | I |
| two_hand_toggle | Y | Triángulo | R |
| use_item | X | Cuadrado | E |
| interact | A | Cruz | F |
| pause_game | Start / Menu | Options / Start | Escape |
| menu_confirm | A | Cruz | Enter |
| menu_cancel | B | Círculo | Retroceso |
| toggle_fullscreen | — | — | F11 |

Los eventos de joystick usan cualquier ID (`device=-1`). Esto no implementa
multijugador. Godot normaliza los mandos reconocidos; los índices del InputMap
son los de su interfaz normalizada, no una suposición de índices raw universales.

## Detección y futuro remapeo

ControllerRegistry consulta los dispositivos al iniciar y escucha
`Input.joy_connection_changed`. Expone `has_controller()`, `get_devices()`
(copia), `devices_changed` y `connection_reported(id, connected)`.
Cada registro contiene ID de sesión, nombre, GUID y `mapped`.
Sin mandos la lista queda vacía y la escena sigue funcionando.

Un mando genérico desconocido se informa como tal: no se garantiza su
distribución. En una fase posterior, agregar su mapping mediante
`Input.add_joy_mapping()` usando GUID o permitir capturar entradas y reemplazar
eventos con `InputMap.action_erase_events()` / `action_add_event()`.
Los perfiles de usuario deberán guardarse en `user://`, sin usar el ID de sesión
como identidad persistente. No hay pantalla ni persistencia de remapeo en 1A.

## Pruebas por Godot AI MCP

Con el juego ejecutándose, usar `editor_manage(op="game_eval")` con:

```gdscript
var suite = load("res://tests/phase_1a_checks.gd").new()
return await suite.run(get_tree())
```

La suite comprueba escena, nodos, resolución, renderer, física, mouse, las 20
acciones con teclado y mando, IDs de mando, estabilidad en reposo y detector de mandos.
Emite señales sintéticas de conexión/desconexión y un RB sintético de ID 7.
Estas pruebas no validan USB, Bluetooth, drivers ni entradas físicas.
Los resultados de la ejecución de esta fase están en `tests/phase_1a_results.md`.

Para la suite 1B, iniciar el trabajo sin esperar dentro de una sola llamada MCP
(la suite supera el presupuesto de 8 s de `game_eval`):

```gdscript
var suite = load("res://tests/phase_1b_checks.gd").new()
get_tree().root.set_meta("phase_1b_suite", suite)
suite.start(get_tree())
return "started"
```

En otra llamada, consultar hasta que `status` sea `complete`:

```gdscript
return get_tree().root.get_meta("phase_1b_result")
```

Ejecutar con el juego recién iniciado y sin tocar los controles durante la suite.
Esta mueve/restablece al personaje, rota temporalmente la cámara para verificar
su referencia y crea una pared temporal que elimina al finalizar. La escena
persistida no cambia. Ver `tests/phase_1b_results.md` para resultados y límites.

Para fase 1C se usa el mismo patrón asíncrono:

```gdscript
var suite = load("res://tests/phase_1c_checks.gd").new()
get_tree().root.set_meta("phase_1c_suite", suite)
suite.start(get_tree())
return "started"
```

Consultar después `get_tree().root.get_meta("phase_1c_result")` hasta
`status="complete"`. Ejecutar las suites secuencialmente, sin tocar controles.
La suite mueve al personaje y restablece el rig; no modifica escenas persistidas.
Ver `tests/phase_1c_results.md`. Las pruebas anteriores se conservan; 1A consulta
la cámara activa del viewport y 1B usa `Player.movement_camera` para no depender
del nombre de la cámara provisional eliminada.

Para fase 1D, ejecutar el mismo patrón con
`load("res://tests/phase_1d_checks.gd").new()`, guardar la instancia en metadata
`phase_1d_suite`, llamar `suite.start(get_tree())` y consultar
`get_tree().root.get_meta("phase_1d_result")` hasta `status="complete"`.
Las pruebas crean obstáculos y un objetivo temporal, luego los eliminan y
restablecen los tres objetivos de la arena. No tocar controles ni ejecutar
otras suites simultáneamente. Ver `tests/phase_1d_results.md`.

Para fase 2A, crear `load("res://tests/phase_2a_checks.gd").new()`, guardar la
instancia en metadata `phase_2a_suite` y llamar `suite.start(get_tree())`. Consultar
`get_tree().root.get_meta("phase_2a_result")` hasta `status="complete"`.
Usa componentes temporales para bordes numéricos y el Player real para carrera,
HUD, estados y muerte; finaliza restaurándolo. Ejecutar las suites anteriores
secuencialmente y con valores iniciales. Informe: `tests/phase_2a_results.md`.

Para fase 2B, usar el patrón asíncrono:

```gdscript
var suite = load("res://tests/phase_2b_checks.gd").new()
get_tree().root.set_meta("phase_2b_suite", suite)
suite.start(get_tree())
return "started"
```

Consultar `get_tree().root.get_meta("phase_2b_result")` hasta `status="complete"`.
Para todas las regresiones históricas usar `tests/legacy_regressions.gd`, método
`start(get_tree())`, y consultar metadata `legacy_regressions`. Guardar también
la instancia del runner en metadata para mantenerla durante el trabajo asíncrono.

1A y 1C corren con el receptor de esquivas activo. 1B, 1D y 2A se ejecutan con
`input_enabled=false` solo en ese receptor: conservan las comprobaciones antiguas
que explícitamente esperaban que la liberación corta no ejecutara acción ni gasto.
No se apagan stamina, estados, locomoción, cámara o lock-on ni se eliminan checks.
La suite nueva comprueba el comportamiento integrado con esquivas habilitadas.
El runner informa el aislamiento por suite y reactiva la entrada al finalizar.
Esto es regresión aislada del contrato histórico: las suites 1B/1D/2A no equivalen
a pruebas con la nueva reacción corta habilitada. No ejecutar suites en paralelo.

Reglas contrastadas: [manual oficial de controles](https://www.fromsoftware.jp/manual/darksoulsremastered/ps4/action1.html)
y [categorías de carga, wiki comunitaria](https://darksouls.wikidot.com/equipment-load).
La [referencia comunitaria sobre backstep](https://estus.com.br/wiki/dark-souls/guia/recuo)
describe una invulnerabilidad breve distinta de rodar; no aporta aquí verificación
primaria del frame exacto. No se presenta ninguna ventana configurable como
reproducción exacta del original. Informe completo: `tests/phase_2b_results.md`.

## Ataques y detección de daño — 2C

RB/R1/J solicita LIGHT_1. RT/R2/K solicita HEAVY_1. Se detecta flanco de pulsación
por acción, incluido el gatillo analógico: mantenerlo o recibir eventos repetidos
no genera más golpes. No se agregaron acciones. Las solicitudes se procesan en
física; si también existe una esquiva pendiente en FREE, la esquiva se procesa
primero y el ataque incompatible se rechaza.

AttackController no ejecuta física propia: reclama ATTACKING usando ActionState,
consume stamina, dirige el reloj y orienta CombatPivot/Visual. Player conserva
su único `move_and_slide()`. STARTUP, ACTIVE y RECOVERY bloquean traslación y
carrera; gravedad/colisión permanecen activas. DODGING y ATTACKING se excluyen.
La recuperación no se cancela con entradas normales. Al completar vuelve a FREE.

Los datos están en `resources/attacks/`, como Resources configurables:

| Ataque | Startup s | Active s | Recovery s | Daño | Stamina |
| --- | --- | --- | --- | --- | --- |
| LIGHT_1 | 0,25 | 0,15 | 0,40 | 20 | 18 |
| LIGHT_2 | 0,30 | 0,15 | 0,45 | 25 | 20 |
| HEAVY_1 | 0,55 | 0,20 | 0,65 | 45 | 35 |

Valores iniciales solicitados, no datos verificados de DS1. Se validan y copian
al comenzar cada golpe; las fases usan segundos de física, no FPS renderizados.
La hitbox solo es autoritativa en ACTIVE. Regeneración bloqueada durante las
tres fases; al terminar se reinicia el retraso de stamina existente.

LIGHT_1 admite una única solicitud ligera adicional en `[0,40;0,72)` segundos
desde su inicio. Su tiempo de vida es 0,50 s, también configurable. La entrada
no se acumula ni refresca con más pulsaciones. Se descarta al expirar, morir,
resetear o interrumpir. LIGHT_2 comienza solo después de toda la recuperación
de LIGHT_1 y vuelve a comprobar/cobrar 20 de stamina. No hay tercer eslabón,
combo fuerte/mixto, carga ni variante a dos manos. Si no alcanza la stamina para
el segundo golpe, termina en FREE sin cobrarlo. Inputs fuera de ventana se rechazan.

El ataque comienza con el frente visual actual. Durante STARTUP puede corregir
hacia la entrada libre relativa a cámara o hacia la referencia del lock-on:
100°/s y máximo 30° desde su orientación inicial, configurables por recurso.
Esto evita saltar 180° ante una entrada opuesta; para atacar hacia atrás hay que
orientarse primero. ACTIVE y RECOVERY conservan la dirección comprometida.
No hay seguimiento perfecto del objetivo durante el golpe. El cuerpo no rota;
la cámara y la selección de objetivos siguen usando sus controladores existentes.

CombatPivot incluye una espada BoxMesh estática y una hitbox frontal BoxShape3D
de 1,5 × 1,6 × 1,8 m, centrada a 1,2 m hacia delante y 1 m de altura. Es una
aproximación de alcance, **no el recorrido real de una espada**. No hay barrido
animado, root motion, contacto exacto de filo ni colisión de espada contra pared.
Sí se rechaza daño si una pared World se interpone entre atacante y hurtbox.

Capas: World=1, Player=2, CombatHitbox=4 (capa 3), CombatHurtbox=8 (capa 4).
Las máscaras físicas anteriores no cambiaron. Hitbox y Hurtbox son Area3D con
CollisionShape3D independientes de la cápsula física. Se consulta el volumen
mediante `intersect_shape` solo durante ACTIVE, para no depender de la caché
de señales Area3D al habilitar una ventana corta. La capa ofensiva y forma se
desactivan fuera de ventana; el daño siempre queda condicionado por fase lógica.
La desactivación de forma usa asignación diferida segura.

Hurtbox recibe referencias a actor, atributos y cuerpo físico, sin nombres de
enemigos. Excluye atacante, facción propia, facciones vacías, vida cero, desactivados
e invulnerabilidad del Player. El ID de actor deduplica incluso varias hurtboxes
del mismo actor; cada golpe puede dañar actores distintos. La reserva ocurre
antes de callbacks. Una interrupción/muerte durante un impacto detiene el resto
de ese barrido. Las facciones deben configurarse; vacías se rechazan por defecto.

Los tres objetivos anteriores ahora instancian `training_dummy.tscn`, derivada
de la escena provisional, con mismas posiciones/IDs y colisión. Reutilizan
ActorAttributes para vida, tienen hurtbox y Label3D con vida/último daño. A cero
se marcan no disponibles/muertos, deshabilitan recepción y colisión física y
dejan un prop inactivo; no persiguen ni atacan. `attributes.restore_all()` permite
restaurarlos técnicamente. Acercarse antes de golpear: no se amplió alcance para
impactar a los objetivos desde la posición inicial.

`AttackController.debug_enabled=false` oculta el texto de fases, hitbox/hurtboxes,
indicadores de vida de entrenamiento y resaltado naranja de ACTIVE. La espada
provisional permanece visible. La depuración de esquivas tiene su flag separado.
No hay efectos avanzados ni animaciones de la cápsula.

Interfaces para animaciones futuras: `attack_started`, `phase_changed`,
`attack_finished` y modo opcional `animation_driven`. Con ese modo, los eventos
`set_phase_from_animation(ACTIVE/RECOVERY)` y `finish_from_animation()` deben
llegar en orden; no existe finalización automática si faltan. Se debe calibrar
la ventana de buffer en segundos con esas animaciones. El modo por defecto usa
el reloj de física. No se añadió AnimationTree ni clips provisionales complejos.

DEAD interrumpe de inmediato, desactiva hitbox y limpia cola/buffer. La interfaz
explícita `interrupt_for_damage()` completa la propiedad y entra en el STAGGERED
provisional; no se llama automáticamente por impactos ni implementa poise,
animación o sistema de stagger. Sirve para integración posterior bajo reglas
explícitas. Las llamadas directas a atributos siguen siendo técnicas; los golpes
normales pasan por Hurtbox y respetan i-frames.

Pruebas 2C: crear `load("res://tests/phase_2c_checks.gd").new()`, conservarlo en
metadata `phase_2c_suite`, llamar `start(get_tree())` y consultar metadata
`phase_2c_result` hasta `status="complete"`. No tocar controles durante suites.
El runner histórico ahora incluye 2B. No se cambiaron checks individuales ni se
desactivaron ataques: las seis suites corren con AttackController habilitado.
Se conserva solo el aislamiento de toque corto previo para 1B/1D/2A, detallado
arriba. Informe y límites: `tests/phase_2c_results.md`.


## Fase 2D — Bloqueo, parry y riposte

La arquitectura, fórmula de estabilidad, orden de impactos, parámetros, reglas de
críticos, controles técnicos y límites están documentados en
[el informe 2D](tests/phase_2d_results.md). Los resultados automatizados se guardan
en `tests/phase_2d_results.json`; las regresiones incluyen ahora 2C.



## Fase 2E — Backstab, Estus y empuñadura

Parámetros, archivos, reglas, perfiles, resultados y aislamientos explícitos de
regresión: [informe 2E](tests/phase_2e_results.md).
Para probar backstab, acercarse por detrás del marcador frontal de un muñeco
y pulsar RB/R1/J orientándose hacia él. Para Estus hay que haber perdido vida;
F1–F4 permiten recibir daño técnico. F5 reinicia vida, cargas y empuñadura.


## Fase 3A — Soldado autónomo

F5 inicia un encuentro con una sola IA delante del jugador. El soldado usa los
mismos componentes de combate y críticos; puede derrotarse sin modelos externos.
Parámetros, estados, limitaciones de persecución directa, pruebas e aislamientos
están en [el informe 3A](tests/phase_3a_results.md). No tocar controles durante suites.


## Fase 3B — Hoguera y reaparición

Se inicia junto a la hoguera. F / A / Cruz la enciende y permite descansar:
restaura vida, stamina, cinco Estus, una mano y el soldado de la misma instancia.
Al morir, YOU DIED aparece tras 0,6 s y dura 2 s; luego se reaparece junto a la
hoguera. Soltá los botones de acción mantenidos para recuperar el control.
No hay guardado entre ejecuciones; F5 reinicia el checkpoint de la sesión.
Arquitectura, políticas, archivos y validación: [informe 3B](tests/phase_3b_results.md).


## Fase 3C — Jefe de dos fases

[Boss arena](scenes/levels/boss_arena.tscn) es una prueba independiente; se conserva
la escena principal. El Guardián de las Ruinas usa combate compartido, tres patrones
iniciales y un área advertida en fase 2. F para hoguera; los controles previos
siguen disponibles. La derrota/victoria y los reintentos usan los checkpoints.
[Informe 3C](tests/phase_3c_results.md): arquitectura, parámetros, políticas y validación.
