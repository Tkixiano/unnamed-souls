# Fase 3A — Soldado con IA y combate funcional

Proyecto existente C:/JUEGOs 3D/soul-game, Godot 4.6.3-stable oficial,
renderizador Compatibility. Inspección y ejecución mediante Godot AI MCP.
Se auditaron PlayerController, ActionState, atributos, ataques, Hitbox/Hurtbox,
resolución de daño, críticos, defensa, esquivas, lock-on, arena y pruebas antes
de modificar. No se instaló nada ni se crearon assets externos.

## Archivos

Creados, con UID de scripts generados por Godot:
- scenes/enemies/soldier.tscn.
- scripts/enemies/soldier_actor.gd.
- scripts/enemies/soldier_ai.gd.
- resources/attacks/soldier_light.tres.
- tests/phase_3a_checks.gd, phase_3a_results.json, phase_3a_regressions.json y este informe.

Modificados:
- scripts/player/attack_controller.gd: dos interfaces opcionales del actor para
  variantes de ataque y dirección de startup; conserva ejecutor/fases/buffer/hitboxes.
- scripts/player/player_controller.gd: get_attack_variant delega en GripController
  exactamente como antes. No cambia movimiento, stamina, orientación ni valores.
- scenes/levels/test_arena.tscn: una instancia Soldier con referencia explícita al
  protagonista y frente hacia él; título de fase. Los props técnicos permanecen.
- tests/legacy_regressions.gd: añade 2E y aislamiento explícito del soldado completo.
- README.md: controles/contexto del encuentro y enlace a este informe.

No cambian InputMap, componentes de daño/defensa/críticos, atributos, ActionState,
perfiles del jugador, cámara, detector de mandos, rodadas ni checks históricos.
Sin jefes, nuevos tipos de arma, modelos, animaciones, música, inventario,
hogueras, guardado, plugins o modificaciones de Blender.

## Actor y componentes compartidos

Soldier es un CharacterBody3D con CollisionShape3D, Visual/Body/FacingMarker,
CombatPivot/Sword/Hitbox, Hurtbox, Attributes, ActionState, CriticalVulnerability,
LockableTarget/AimPoint, SoldierAI y StatusLabel. Los meshes son cápsula y cajas
de pocos segmentos. Visual está separado del cuerpo físico para poder cambiar
por un rig después. El cuerpo nunca rota al orientar la vista del soldado.

Usa los MISMOS AttackController, AttackData, Hitbox, Hurtbox, ActorAttributes,
ActionState, CriticalVulnerability y LockableTarget existentes. No hereda los
controles/Estus/esquivas del jugador ni construye un segundo motor de combate.
AttackController admite get_attack_aim_direction en el actor de IA; sin esa
interfaz conserva la dirección por entrada/cámara del jugador. Los perfiles
del jugador siguen pasando por GripController mediante get_attack_variant.

SoldierActor integra gravedad, aceleración, move_and_slide y ordena el reloj
compartido de ataques en física. Velocidad 2 m/s, aceleración 8 m/s², giro visual
150°/s, snap 0,25 m, pendiente máxima 45°. Vida 180, stamina 100, coste de golpe
12; regeneración reutiliza atributos/estados existentes. Facción hostile.

Capa física del soldado = World | Actor (valor 3), máscara 3. Esto hace que el
jugador, cuya máscara World original permanece intacta, también choque con él.
Las consultas de combate/visión excluyen los cuerpos participantes por RID.
Hitbox/Hurtbox conservan capas de combate 4/8 separadas de colisión física.
El soldado y los obstáculos también pueden limitar el SpringArm de cámara.

## Estados y transiciones

La FSM de IA es independiente de ActionState (propiedad de acciones) y se ejecuta
en física con prioridad -10, antes del actor. No hay árbol de comportamiento.

| Estado IA | Entrada | Salida |
|---|---|---|
| IDLE | Inicio o retorno terminado | Tras retraso y detección válida → ALERT |
| ALERT | Jugador visto | Pausa 0,45 s → CHASE; pérdida/leash → RETURNING |
| CHASE | Alerta terminada o decisión disponible | Alcance, LOS, orientación y stamina → ATTACK; pérdida → RETURNING |
| ATTACK | AttackController acepta golpe | ACTIVE/STARTUP comprometidos; fase RECOVERY → RECOVERY; interrupción → STAGGERED; muerte → DEAD |
| RECOVERY | Fase de recuperación o fin del golpe | Espera de decisión terminada → CHASE; pérdida → RETURNING |
| STAGGERED | Daño interruptor o reserva/vulnerabilidad crítica | Termina su propietario → RECOVERY o RETURNING; muerte → DEAD |
| RETURNING | Pérdida, leash o jugador muerto | Dentro de 0,15 m del origen → IDLE con pausa |
| DEAD | Vida cero | Sin salida de juego; solo reset técnico/F5 |

Durante fases ocupadas no se desplaza. STAGGERED de parry/backstab pertenece a
CriticalVulnerability: la IA nunca lo completa por su propio temporizador.
Un stagger de daño ordinario sí pertenece a SoldierAI y dura 0,65 s.

## Percepción y persecución

| Parámetro configurable | Inicial |
|---|---:|
| Detección | 7 m |
| Cono visual total | 130° |
| Radio de pérdida | 12 m |
| Tolerancia sin LOS | 1,20 s |
| Leash máximo desde origen | 8 m |
| Retraso inicial | 1 s |
| Alerta | 0,45 s |
| Distancia preferida | 1,85 m |
| Alcance para iniciar ataque | 1,75 m |
| Tolerancia de orientación al iniciar | ±15° |

Adquisición exige distancia, cono del frente visual real y raycast World desde
altura 1,35 m hacia el torso del jugador. DEAD no se adquiere. Tras adquirir,
se mantiene memoria con LOS omnidireccional y tolerancia temporal, sin perderlo
por girar un frame. Pérdida por distancia, falta prolongada de visión, o jugador/
soldado fuera del leash inicia retorno. El objetivo se asigna por referencia
exportada; una escena sin objetivo permanece segura en IDLE.

Persecución directa apropiada para esta arena abierta: cápsula de radio 0,35 m
y altura 1,60 m consulta ocupación/cast a corto alcance; raycast de suelo adelante
rechaza vacío o desniveles mayores de 0,35 m. Además, move_and_slide conserva la
colisión real. Si el camino no está libre, se detiene; no atraviesa paredes ni
se teletransporta. Retorna caminando hacia el origen y conserva vida perdida.

No existe NavigationAgent/navmesh ni búsqueda de rutas alternativas. Una pared
que cierre el regreso puede dejarlo en RETURNING detenido. No resuelve laberintos,
puertas, escaleras complejas o rodeos; esa es una limitación explícita de 3A.

## Ataque y ritmo

SOLDIER_LIGHT usa el recurso compartido y física:

| Startup | Active | Recovery | Daño | Stamina damage | Coste propio |
|---:|---:|---:|---:|---:|---:|
| 0,55 s | 0,18 s | 0,75 s | 20 | 25 | 12 |

Es bloqueable y parryable explícitamente. No tiene combo (ventana [0;0)). Solo
se solicita cuando hay alcance, LOS y orientación suficiente. Durante STARTUP
permite corrección limitada de 75°/s, máximo 25° desde el frente inicial; ACTIVE
y RECOVERY conservan la dirección. No hay giro perfecto durante el golpe.
La hitbox frontal estática es la aproximación provisional de 2C, no un recorrido
de espada real. Aplica daño una vez por actor y golpe; respeta i-frames, escudo,
estabilidad, guard break y parry en la resolución de Hurtbox existente.

Después del golpe completo se esperan 0,90 ±0,20 s. Tras un máximo de dos
ataques completados se añaden 2 s de pausa y se reinicia el contador. No hay
encadenado indefinido ni cancelación de recovery. Probabilidad de reposición
lateral 0,35, a 45% de velocidad, con las mismas comprobaciones de suelo/pared.
Se retrocede si el jugador está demasiado cerca cuando no se inicia golpe.
RandomNumberGenerator tiene semilla exportada 3101 para repetir pruebas.
Los tiempos y valores son provisionales, no frames ni estadísticas exactas DS1.

## Daño, críticos y muerte

El soldado recibe daño exclusivamente por Hurtbox→ActorAttributes. Un impacto
normal de daño aplicado ≥15 interrumpe su ataque normal si existe, reclama
STAGGERED durante 0,65 s y luego concede una pausa de decisión. Un daño menor
actualiza vida/feedback sin interrumpir. No hay poise acumulativo ni estadísticas
RPG. Impactos críticos no provocan otro stagger ni sobrescriben su reserva.

Parry interrumpe el golpe mediante interrupt_for_parry y abre la vulnerabilidad
ya existente; el jugador puede hacer riposte. Desde detrás se puede reservar
backstab desde FREE o ataque normal interrumpible. Se conserva el token de daño
único, compromiso de pareja y liberación por fin, muerte, destrucción o reset.
El soldado no ejecuta críticos ni defiende con escudo en esta fase.

Vida cero tiene prioridad: DEAD del actor interrumpe ataque, limpia buffer,
desactiva hitbox/Hurtbox y marca LockableTarget no disponible/muerto. Se detiene
el procesamiento de SoldierAI. Las reservas críticas se invalidan por el estado
DEAD, y lock-on se libera en su siguiente actualización. El cuerpo gris y etiqueta
DEAD son la reacción provisional; conserva cuerpo físico, sin ragdoll ni animación.
No vuelve a atacar, no se cura al retornar y no reaparece automáticamente.
El reset de atributos es exclusivamente técnico, igual que las fases anteriores.

## Arena

Hay una sola IA activa: Soldier en (0,0,-3,8), mirando hacia el protagonista.
Es el objetivo frontal más cercano y adquiere al jugador tras 1 s más alerta.
Los muñecos originales quedan detrás/laterales (sus nombres, IDs y posiciones
se conservan para pruebas) y el atacante F1–F4 permanece en su zona técnica,
sin IA. No se añadieron otros soldados. F5 reinicia el encuentro completo.

Permite fijar R3/Q, esquivar B/Espacio, bloquear LB/U, parry LT/I, atacar RB/J o
RT/K, riposte frontal tras parry, y backstab desde detrás del marcador rojo.
Estus y dos manos conservan sus acciones X/E e Y/R. Escudo/parry siguen
inhabilitados a dos manos. No hay cambios de InputMap ni HUD de inventario.

## Validación

Resultados completos y medidas se guardan en JSON al finalizar.
Suite 3A final: **61/61**, 14 comprobaciones de componente y 47 de integración.
Eventos medidos: STARTUP t=0; ACTIVE t=0,55; RECOVERY t=0,733333; fin t=1,483333.
Las ventanas de 0,18/0,75 s se discretizan a ticks de 1/60 s, sin FPS renderizados.
Paso máximo observado durante retorno: 0,0222223 m, sin recolocación instantánea.
La suite distingue comprobaciones de componentes (reglas/percepción/probes/datos/
semilla) e integración (FSM autónoma, movimiento, contactos reales, críticos y
muerte). Todas usan física y componentes reales del proyecto; las de reglas
mantienen la IA habilitada con un retraso inicial de fixture para poder consultar
condiciones estables. Los tests integrados usan decisiones y ataques de la IA,
sin reemplazar AttackController, Hurtbox, atributos o defensa por mocks.

No hay joystick conectado. Las acciones del jugador se simulan con InputMap o
APIs de acción; los contactos, raycasts, colisiones y relojes son reales de Godot.
El caso de muerte durante crítico fuerza un impacto letal autenticado para
probar liberación de reservas, además de probar el daño normal configurado de
riposte/backstab en otros casos. No demuestra entradas físicas ni game feeling.

Primera pasada: 58/59; la fixture de muerte durante backstab estaba a 1,65 m,
fuera del alcance de 1,60 m. Se corrigió a 1,40 m y se añadieron comprobaciones
de que el crítico se inicia y que el daño letal se aplica. No se relajó la regla.
También se reforzó i-frames para conservar contacto dentro del volumen ofensivo,
y se midieron pasos de retorno para descartar saltos de posición.

Regresiones: el runner incluye 1A–2E. Aísla explícitamente el soldado autónomo
completo (proceso deshabilitado, oculto y fuera del área de consultas) mientras
corren fixtures que antes no contenían hostiles. Conserva los aislamientos
previos del receptor de toque corto en 1B/1D/2A y adquisición de backstab en 2C.
Ningún check individual histórico se cambia. 3A integrada verifica combate con
la IA activa y todos los sistemas del jugador habilitados. Al terminar, el runner
restaura soldado/atributos/visibilidad/proceso para dejar el encuentro jugable.

Resultado histórico final: **467/467**, en phase_3a_regressions.json.

| Fase | Aprobadas |
|---|---:|
| 1A | 16/16 |
| 1B | 44/44 |
| 1C | 38/38 |
| 1D | 47/47 |
| 2A | 59/59 |
| 2B | 63/63 |
| 2C | 60/60 |
| 2D | 63/63 |
| 2E | 77/77 |

Comprobación posterior al runner: Soldier visible y process_mode INHERIT,
sin dejar el aislamiento persistido. Ejecución final desde escena principal
r50152406-42: helper vivo y arranque sin errores de parser/runtime. La revisión
visual fue una captura real y estática a 1280 × 720, sin congelar ni reemplazar
la IA: soldado en RECOVERY con 180 de vida y protagonista con 60 tras dos golpes.
HUD, primitivas, marcador frontal y etiqueta son visibles; no constituye una
evaluación continua de sensación de combate ni prueba física de joystick.

Los logs de las ejecuciones completas no mostraron errores ni warnings, y no
aparecieron entradas nuevas del editor desde cursor 13. Se verificó main con
project_run y se detuvo el juego después de revisar, dejando test_arena abierta
y el editor listo para F5. Así el próximo intento carga vida/stamina/Estus y
enemigo desde cero, en lugar de dejar al jugador expuesto a la IA mientras espera.

## Límites y preparación

Sin animaciones definitivas, root motion, patrullas, rutas alternativas, combate
grupal, jefe, guardado ni reaparición. No se midió rendimiento en la PC de 4 GB RAM.
El daño ordinario al protagonista conserva las reglas previas: no se añadió
stagger automático a todos sus impactos ni se modificó Estus para este enemigo.
Señales de estado/fase/impacto, Resource del golpe, Visual separado, percepción
exportada y semilla quedan preparados para animaciones y navegación posteriores.
No se implementó la siguiente fase.
