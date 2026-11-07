# Fase 3C — Guardián de las Ruinas

Godot AI MCP confirmó Godot 4.6.3-stable oficial. Proyecto existente
C:/JUEGOs 3D/soul-game, Compatibility, 1280 × 720. Antes de editar se auditaron
soldado/percepción/movimiento, ataques, Hitbox/Hurtbox, daño, stamina, acciones,
críticos, lock-on, checkpoints, muerte, HUD y pruebas. No se creó otro proyecto.

## Acceso y escenas

Abrir scenes/levels/boss_arena.tscn y ejecutar F6. La escena queda preparada para
prueba directa: jugador junto a hoguera, entrada entre muros al norte y jefe.
F5 sigue ejecutando scenes/levels/test_arena.tscn, sin reemplazarla ni eliminarla.
Los controles cómodos de teclado/mouse y los de mando se conservan.

La arena tiene suelo de 24 × 28 m, muros físicos, puerta abierta de 4 m y entrada
Area3D. El jugador comienza en (0;0;11), el jefe en (0;0;-3), con hoguera cercana.
El área válida de combate es ±8,8 m en X/Z. Cruzar el área de entrada con jugador
vivo, línea de visión y jefe no derrotado inicia INTRO. No se crea niebla ni una
cinemática. Salir de los límites reinicia de forma explícita el encuentro no ganado.

## Archivos creados

- scripts/bosses/ruins_guardian.gd y guardian_brain.gd.
- scripts/bosses/boss_pattern.gd, encounter_entry.gd y boss_hud.gd.
- scripts/enemies/enemy_world_queries.gd: consultas extraídas del soldado.
- scripts/systems/session_progress.gd: registro de derrotas en memoria por ID.
- scenes/bosses/ruins_guardian.tscn.
- scenes/levels/boss_arena.tscn y scenes/ui/boss_hud.tscn.
- resources/attacks/boss/: horizontal_slash, vertical_slam, combo_first,
  combo_second y ruin_burst (.tres).
- resources/bosses/: horizontal_slash, vertical_slam, two_hit_combo y ruin_burst (.tres).
- tests/phase_3c_checks.gd, phase_3c_regressions.gd y este informe.
- JSON de resultados y UID de scripts generados por Godot.

Modificados:
- scripts/combat/attack_data.gd: Shape3D/offset opcionales por golpe.
- scripts/combat/attack_hitbox.gd: configuración de volumen, copia del shape y debug.
- scripts/player/attack_controller.gd: configura el volumen antes de cada golpe.
- scripts/combat/critical_vulnerability.gd: políticas por instancia para parry,
  riposte y backstab, sin desactivar mecánicas globales.
- scripts/enemies/soldier_actor.gd: nombre visible configurable, manteniendo física
  y restauración compartidas.
- scripts/enemies/soldier_ai.gd: delega LOS y probes a las mismas consultas extraídas.
- tests/legacy_regressions.gd: añade 3B y restaura su fixture inicial de checkpoint.
- README.md: acceso y referencia de la fase.

No se cambian el proyecto principal, sus mapas, InputMap, valores de movimiento/
cámara, datos de ataques del jugador, atributos, reglas de escudo, rodadas,
checkpoint o daño. No hay plugins, Blender ni assets externos.

## Arquitectura

RuinsGuardian hereda SoldierActor y su escena, conservando CharacterBody3D,
CollisionShape3D, Attributes, ActionState, AttackController, Hitbox, Hurtbox,
CriticalVulnerability y LockableTarget. Solo sustituye el cerebro por GuardianBrain.
El nodo heredado SoldierAI conserva su ruta para no rehacer el actor base;
contiene el script del jefe. SpawnPoint coincide con el origen de aparición.
boss_id estable por instancia: ruins_guardian; se aplica al identificador de lock-on.

Visual separado a escala 1,45, casco/hombreras de cajas y espada grande. La forma
física mide 2,70 m, radio 0,55; Hurtbox radio 0,70. Vida 600, stamina 300,
regeneración 50/s. Velocidad 2,2 m/s, giro visual 120°/s. Mantiene capas World/Actor
y combate 4/8, gravedad y move_and_slide. Ninguna ventana de daño desactiva el
cuerpo físico.

BossPattern es Resource de selección: ID, lista de golpes, mínimo/máximo de
distancia, semiángulo, cooldown y pesos por fase. Cada golpe sigue siendo AttackData
y lo ejecuta el AttackController existente: no hay un segundo reloj de daño.
La secuencia del combo solicita dos ejecuciones completas, cada una con su propio
swing_id, STARTUP/ACTIVE/RECOVERY y deduplicación. No hay buffer infinito del jefe.

Los volúmenes opcionales se copian por golpe. Si no se define shape, se usa el
volumen original del actor, preservando jugador/soldado. El debug sigue el BoxShape.
La hitbox frontal estática no reproduce el recorrido exacto de una espada animada.

## FSM

| Estado | Entrada y salida |
|---|---|
| IDLE | Inicial/reset; entrada válida → INTRO |
| INTRO | Alerta de 1 s, sin decisiones ofensivas; luego APPROACH |
| APPROACH | Orientación/avance; selección válida → ATTACK |
| REPOSITION | Espera de decisión y paso lateral seguro; luego selección/aproximación |
| ATTACK | STARTUP/ACTIVE del ejecutor; fase recovery → RECOVERY |
| RECOVERY | Recuperación obligatoria; siguiente golpe comprometido del combo o REPOSITION |
| PHASE_TRANSITION | Umbral pendiente y patrón terminado; 1,4 s → fase 2/REPOSITION |
| STAGGERED | Interrupción permitida o crítico opt-in; termina propietario → REPOSITION/transición pendiente |
| DEAD | Vida cero, prioridad absoluta, sin nuevas acciones |

DEAD cancela inmediatamente, incluso durante transición. Llegar al umbral de fase
no cancela un golpe ni el segundo golpe ya comprometido de un combo: termina el
patrón y luego transiciona antes de escoger otro. Un stagger legítimo de startup
puede interrumpir según su regla independiente. Perder al jugador por muerte
cancela el ataque y oculta el HUD; el checkpoint hace el reset completo después.

## Datos de patrones

Valores provisionales editables, no frames ni estadísticas verificadas de DS1.

| Golpe | Startup | Active | Recovery | Vida | Stamina damage | Coste propio |
|---|---:|---:|---:|---:|---:|---:|
| HORIZONTAL_SLASH | 0,70 | 0,20 | 0,80 | 24 | 35 | 14 |
| VERTICAL_SLAM | 1,05 | 0,18 | 1,15 | 36 | 90 | 20 |
| COMBO_FIRST | 0,55 | 0,15 | 0,35 | 20 | 30 | 12 |
| COMBO_SECOND | 0,50 | 0,18 | 0,85 | 26 | 45 | 14 |
| RUIN_BURST | 1,35 | 0,20 | 1,20 | 40 | 75 | 25 |

Tajo: caja 5 × 2 × 2,6, centro (0;1,4;-1,7). Slam: 1,6 × 2,7 × 3,4,
centro (0;1,4;-1,9). Combo: cajas 3,8 × 2 × 2,6 y 3,6 × 2,4 × 3. Área:
6 × 2,5 × 6 centrada en el jefe. Alcances de selección 3 / 3,6 / 3 / 3 m.
Todos salvo área admiten bloqueo; ninguno admite parry por defecto.

Corrección durante startup: 65°/s, máximo 20°. ACTIVE y RECOVERY conservan dirección.
El área no gira durante preparación. El combo tiene impactos separados alrededor
de t=0,55 y t=1,55 s, suficientes para dos esquivas separadas; no es daño duplicado
del mismo swing. Cooldowns: 2,2 / 4 / 4 / 7 s por patrón.

Pesos fase 1: 1 / 0,8 / 0,9 / 0; fase 2: 1,2 / 0,9 / 1,1 / 0,65.
Se exige distancia, ángulo y LOS; cooldown y último patrón excluyen candidatos.
Semilla exportada 3301. Si no hay candidato válido no se fuerza un golpe: aproxima
o reposiciona. Espera 0,85 ±0,15 s; paso lateral hasta 0,6 s al 50% de velocidad.
Las consultas de cuerpo completo/suelo compartidas impiden atravesar obstáculos.
No hay navmesh ni búsqueda de rutas alternativas.

## Segunda fase y área

A vida ≤50% (300) se encola transición una sola vez, sin curar. Tras 1,4 s con
marcador de suelo y texto de transición, el cuerpo cambia a naranja y el HUD
muestra FASE 2. Recuperaciones ×0,80, decisiones ×0,70; daños y startups se conservan.
AttackVariant genera snapshots sin mutar recursos de fase 1. Por ejemplo slam:
recovery 1,15 → 0,92 s. El umbral no se reactiva con daño posterior.

RUIN_BURST solo entra en la selección de fase 2. La caja de impacto se anticipa
con un cuadrado ámbar translúcido en el suelo durante 1,35 s; cambia a rojo en
ACTIVE y se oculta en RECOVERY. Es geometría barata, sin partículas. Fuera de
ACTIVE no hay daño. Es no bloqueable/no parryable: se evita saliendo de la zona
o con i-frames correctamente temporizadas. No hay seguimiento perfecto ni daño
instantáneo al comenzar. La forma es cuadrada y provisional, no una onda circular.

## Daño y política de críticos

El único descuento de vida sigue siendo Hurtbox→ActorAttributes. Respeta las
i-frames del protagonista, facciones, bloqueo, estabilidad y guard break existentes.
Una guardia de estabilidad 60 gasta 14 contra tajo, 36 contra slam; si no alcanza
se usa el guard break de 2D, sin inventar otra resolución.

Stagger sencillo: un golpe normal aplicado ≥55 interrumpe FREE/STARTUP durante
0,8 s. ACTIVE/RECOVERY y la transición no se interrumpen por este umbral; siguen
recibiendo daño, y DEAD siempre interrumpe. No hay poise acumulativo ni estadísticas
RPG adicionales. Los críticos comprometidos conservan su propietario.

Por defecto CriticalVulnerability tiene parry_allowed/riposte_allowed/backstab_allowed
en false. Además cada ataque del jefe declara parryable=false. La habilitación
futura requiere política del actor y metadatos del golpe compatibles. Las otras
entidades mantienen true y el jugador sigue pudiendo usar sus mecánicas. Se prueba
también el opt-in de parry/riposte y backstab independiente, con recursos de fixture.

## HUD, victoria y checkpoints

BossHUD aparece por señal al iniciar, con nombre Guardián de las Ruinas, vida
actualizada por señales y fase. Se oculta al terminar el encuentro. Al morir el
jefe: DEAD, IA detenida, hitbox/Hurtbox desactivadas, lock-on inválido, cuerpo oscuro
y VICTORIA. No se añadió cinemática ni otro nivel después de ganar.

Se usa entity_kind=BOSS y la restauración del soldado/checkpoint ya existente.
Si no está derrotado, descansar/reaparecer lo restaura en la MISMA instancia:
600 de vida, fase 1, IDLE, seed/history/cooldowns limpios, sin transición/ataque/
advertencia residual. Si está derrotado, el checkpoint no lo restaura. Los
enemigos normales mantienen sus reglas en la arena principal.

SessionProgress guarda los identificadores derrotados en metadatos de la raíz de
SceneTree. Sobrevive al cambio/recarga de escenas durante la misma ejecución,
sin autoload nuevo ni escritura de progreso en disco. Al cargar otra vez el jefe,
se establece DEAD mediante sus atributos y componentes existentes; no reaparece.
Cerrar y volver a ejecutar el juego inicia una sesión nueva sin derrotas registradas.

## Validación

Suite nueva inicial: 68/70; se corrigieron dos fixtures. Una comprobaba el final
del combo dos ticks antes de acabar recovery; se amplió solo la espera hasta el
tiempo correcto. La otra pedía repetir el último patrón, que la regla de historial
rechazaba, y leía el snapshot anterior. Ahora verifica aceptación de un patrón
legal y su recuperación de fase 2. No se cambiaron reglas para hacerlas pasar.

Segunda pasada: **71/71**; pasada final con persistencia por ID y recarga:
**73/73**. Resultados completos en phase_3c_results.json. Incluye
entrada/IA autónoma, reglas de selección, los patrones, fases, daño único,
bloqueo/guard break, parry/backstab por defecto y opt-in, stagger/armor, transición,
área advertida/rodada/salida caminando, muerte del jugador por contacto real,
reintento con checkpoint, muerte/victoria y descansos repetidos sin duplicar jefe.

En consultas de selección se detiene solo la decisión automática del cerebro
para medir rango/ángulo/LOS/semilla sin empezar otro golpe entre consultas.
Se reactiva antes de las pruebas integradas. Estas mantienen actores, daño,
Hitbox/Hurtbox, atributos, cámara, HUD y checkpoint reales activos. Las fixtures
independientes usan reset técnico del indicador de derrota entre casos; el caso
de victoria/descanso conserva ese indicador para probar que no hay reaparición.
Se usan APIs/acciones simuladas, no joystick físico ni evaluación manual de sensación.

Las regresiones cambian temporalmente a test_arena, ejecutan 1A–3B sin modificar
sus checks y vuelven a boss_arena. Se conservan los aislamientos históricos
documentados. 3B recibe su punto inicial/orientación y ciclo real activo, porque
su contrato es distinto del DEAD terminal de las suites previas. El jefe no se
inyecta en fixtures históricas que nunca lo contenían. Ambas ejecuciones completas:
**590/590**. La última guarda phase_3c_regressions.json. Desglose: 1A 16, 1B 44,
1C 38, 1D 47, 2A 59, 2B 63, 2C 60, 2D 63, 2E 77, 3A 61 y 3B 62.
No se modificaron checks históricos.

Reproducción mediante Godot AI MCP, con una ejecución nueva de boss_arena:
crear load("res://tests/phase_3c_checks.gd").new(), conservar la referencia en un
metadato de la raíz y llamar start(get_tree()). Es asíncrona: consultar el metadato
phase_3c_result hasta status=complete. Luego phase_3c_regressions.gd usa el mismo
protocolo con phase_3c_regressions. Ambas suites escriben sus JSON al completar;
estos archivos son evidencia de pruebas, no guardado de partida.

Las pruebas distinguen consultas de componentes, integración física con contactos
reales entre primitivas y ejecución desde el editor. Se revisó una captura real
1280 × 720: jefe provisional, jugador, barra/nombre/fase y HUD existentes dentro
del área visible. También se revisaron cuerpo naranja/FASE 2 y cuadrado ámbar de
advertencia. Para capturar esa ventana se detuvieron únicamente el reloj físico
del actor y su cerebro después de iniciar RUIN_BURST; no se usa esa captura como
prueba temporal ni de daño. Las pruebas integradas previas ejecutaron ambos activos.
Es una revisión estática, no una evaluación jugable manual. Después se reinició
el juego para descartar posiciones, tiempos y pausas de depuración.

Un comando temporal de inspección MCP tuvo indentación mezclada y detuvo el
depurador; no se escribió a un script del proyecto. Se reinició el proceso,
se corrigió la consulta y se repitieron las suites con resultados persistidos.
Los arranques finales no reportaron errores de parser/runtime del proyecto.

## Límites y preparación para Fase 4

Geometría/poses/volúmenes estáticos, sin rig ni animaciones definitivas. No se
afirma fidelidad exacta de DS1 ni game feeling por pruebas automatizadas. No hay
mando físico conectado ni benchmark en hardware de 4 GB RAM. La persecución es
directa: no resuelve rodeos/laberintos. No hay guardado, inventario, música,
cinemáticas, nivel completo ni efectos avanzados. El borde de arena reinicia el
encuentro no ganado; no hay niebla que encierre al jugador.

Se preparan Resources de patrones/volúmenes, eventos de fases, políticas críticas,
identificador estable, señales de encuentro/fase/victoria y Visual separado para
animaciones y ajustes posteriores. No se implementó mecánica de Fase 4.
