# Fase 2D — Defensa, parry y riposte

Godot 4.6.3-stable, proyecto existente C:/JUEGOs 3D/soul-game.
Inspección, arranque, simulación física y validación mediante Godot AI MCP.

## Archivos

Creados (más UID de scripts generados por Godot):
- scripts/combat/defense_controller.gd: bloqueo, parry y guard break.
- scripts/combat/critical_vulnerability.gd: incapacitación y reserva crítica.
- scripts/combat/riposte_controller.gd: selección contextual y ejecución crítica.
- scripts/combat/defense_test_attacker.gd: disparador técnico sin IA.
- scripts/combat/defense_debug.gd: indicadores desactivables.
- tests/phase_2d_checks.gd, phase_2d_results.json, phase_2d_regressions.json y este informe.

Modificados:
- scripts/player/player_controller.gd: conecta componentes y sus relojes,
  movimiento defensivo, interfaces de defensa/crítico y facción/entrada del actor.
- scripts/player/attack_controller.gd: prioridad contextual de RB, metadatos de
  impacto, interrupción explícita por parry y subtipo RIPOSTE.
- scripts/combat/attack_data.gd: capacidades defensivas explícitas.
- scripts/combat/attack_hitbox.gd: contexto y deduplicación de contactos absorbidos.
- scripts/combat/hurtbox.gd: resolución previa al único descuento de vida.
- scripts/systems/actor_attributes.gd: multiplicadores de regeneración por motivo.
- resources/attacks/light_1.tres, light_2.tres, heavy_1.tres: propiedades defensivas.
- scenes/player/player.tscn: componentes y escudo BoxMesh.
- scenes/levels/test_arena.tscn: atacante técnico, objetivo fijable e indicadores.
- tests/legacy_regressions.gd: añade 2C, registra defensa habilitada.
- README.md: controles actuales y referencia a este informe.

No se modificaron ActionState, SprintDodgeInput, DodgeController, selección de
lock-on, cámara orbital, valores de locomoción/cámara ni InputMap. Los checks
individuales históricos permanecen intactos. Sin dependencias, IA ni recursos externos.

## Arquitectura y reglas

DefenseController posee BLOCKING/PARRYING/STAGGERED mediante claim_state y
complete_owned_state existentes. Solo FREE y reemplazo explícito del bloqueo
propio permiten parry. Muerte interrumpe cualquier estado; acciones normales
no pueden sobrescribir propietario ni DEAD. Locomoción IDLE/WALK/RUN sigue separada.

Bloqueo mantenido: movimiento ×0,45 (1,44 m/s), sin carrera, ataques ni esquivas.
Sin lock-on conserva el frente inicial. Con fijación gira deliberadamente hacia
el objetivo a 120°/s; solo rota Visual. Sostener escudo no gasta stamina.
Regenera al 20% (5 pt/s con base 25), conservando retraso 0,75 s tras consumo.
Los multiplicadores por motivo se multiplican; bloqueos duros prevalecen.

Absorción física 100%, estabilidad 60%, cono frontal total 120°:

`coste_guardia = stamina_damage × (1 - clamp(estabilidad/100, 0, 1))`

`daño_residual = daño_entrante × (1 - clamp(absorción/100, 0, 1))`

Ejemplo probado: stamina_damage=40 requiere 16 puntos; daño=30 resulta en cero vida.
Igualar el saldo es bloqueo exitoso a cero; superarlo agota la stamina, aplica
daño entrante completo (multiplicador configurable 1) y produce guard break.
STAGGERED dura 1 s, sin regeneración ni acciones normales. Mantener LB no rearma
la guardia: debe soltarse después del impacto y volver a pulsarse; durante la
recuperación no puede levantarse. No hay animación ni stagger avanzado.

Parry provisional: startup 0,12 s, ACTIVE 0,15 s, recovery 0,55 s, coste 15 al inicio.
Fases procesadas en física. Se exige contacto, flag parryable, cono frontal y
dirección entrante hacia el defensor con tolerancia de 60°. Proximidad sin golpe
no produce éxito. Startup/recovery fallan; un fallo recibe daño normal, sin
partial parry ni absorción automática. Valores editables, no frames DS1 verificados.

Orden de resolución en Hurtbox:
1. Actor habilitado/vivo, importe finito, identidad y facción contraria.
2. Reserva crítica: se rechazan impactos normales contra la pareja comprometida.
3. Disponibilidad/i-frames: resultado evaded, sin alterar colisión física.
4. Crítico autorizado por reserva y token de un solo uso.
5. Parry válido por contacto: interrupción explícita de ataque normal y vulnerabilidad.
6. Bloqueo frontal si blockable y físico; coste de guardia o guard break.
7. Único apply_damage: daño normal, residual o crítico, seguido de señales.

resolve_hit devuelve outcome, damage, consumed, parryable y stamina_cost.
receive_hit conserva retorno float histórico. Parryable/no parryable es una
propiedad del paquete, no un éxito automático. Hitbox consume el contacto de
bloqueos/parries aunque quiten cero vida; hit_count mantiene significado histórico
de golpes que redujeron vida. I-frames no consumen contacto: un volumen aún activo
puede impactar cuando terminan, regla conservada de 2C.

AttackData: blockable/parryable false por defecto; damage_type physical,
stamina_damage configurable. Ligeros declarados blockable/parryable, daño stamina
30/35; fuerte blockable, no parryable, 65. Tipos distintos de physical reciben
daño normal: queda la interfaz, sin implementar absorción elemental completa.

CriticalVulnerability es reutilizable y no conoce mallas ni clases de enemigo.
Requiere protocolo de actor (atributos, estados, interrupt_attack_for_critical)
y referencia explícita a Hurtbox. Parry interrumpe solo un ataque normal activo
que acepte ese protocolo; críticos no son interrumpibles por parry. Posee
STAGGERED por 1,8 s, expira a FREE y rechaza acciones normales mientras está abierto.
La reserva atómica impide críticos duplicados y suspende expiración hasta finalizar.

RiposteController: rival vulnerable a ≤2,1 m, desnivel ≤1 m, orientación del jugador
±45° y del objetivo ±60°, LOS World. RB prioriza RIPOSTE sobre LIGHT_1. Si existe
candidato válido pero falta stamina, rechaza sin fallback; sin candidato, ataque
ligero normal. Coste 30, duración 1,05 s, daño crítico 120 una vez en t=0,35 s.
ATTACKING queda reservado al crítico; current_attack_name devuelve RIPOSTE.
No se habilita hitbox normal, ambos actores quedan inmóviles sin recolocación.
Se revalida alcance/LOS al impactar; un fallo no devuelve coste. DEAD cancela y
libera al sobreviviente; no se fuerza FREE sobre DEAD. Durante compromiso se
rechazan impactos normales de terceros, regla provisional explícita distinta
de las ventanas de invulnerabilidad de esquiva.

## Prueba técnica y depuración

El atacante es otra instancia del actor existente, controls_enabled=false y
facción test_attacker. Usa los MISMOS AttackController, Hitbox, Hurtbox y atributos;
no hay segundo sistema de ataques ni decisiones autónomas. Tiene 250 de vida.
LockableTarget existente permite fijarlo y se desactiva al morir.

F1/F2/F3/F4 o execute_test(0..3) preparan respectivamente frontal parryable,
frontal no parryable, trasero y rompeguardia no parryable. Startup 0,30, active
0,12, recovery 0,45 s; daño/stamina_damage 30/40 o 40/300; coste técnico propio cero.
El preparativo coloca al actor a 1,6 m y comprueba pared/volumen libre. Esta
recolocación es exclusivamente de test, antes del golpe; nunca parte del riposte.
No se ejecutan secuencias autónomas. Puede matarse al atacante y al protagonista;
reiniciar F5 restaura la escena. Sin joystick, usar U para escudo, I para parry,
J para ataque/riposte. No se agregaron acciones.

DefenseDebug muestra escudo, fase del parry, éxito de bloqueo/parry, guard break,
objetivo vulnerable y eventos de riposte. El objetivo cambia color de etiqueta
al estar vulnerable. DefenseController.debug_enabled=false o DefenseDebug.enabled=false
oculta estos indicadores; AttackController.debug_enabled=false oculta además bounds
y el resto de debug de combate. Escudo/espada siguen siendo geometría de juego
provisional, no deformaciones o animaciones complejas de cápsula. HUD conservado.

## Resultados

Suite 2D integrada: **63/63**, con todos los nuevos sistemas y los listeners de
ataque/esquiva/defensa del protagonista habilitados. Inputs mediante acciones y
eventos normalizados RB/LT ID 7 simulados; los contactos emplean consultas físicas
de Godot y los componentes reales. Algunas pruebas de resolución de daño llaman
directamente a Hurtbox para aislar sus condiciones; también se ejecutan golpes
integrados del atacante técnico sin desactivar sistemas.

Cubre los 26 puntos solicitados: bloqueo, movimiento, orientación, cono, stamina,
absorción y residual, guard break/recuperación/rearme, regeneración, fases y fallos
de parry, contacto válido, vulnerabilidad/expiración, prioridad contextual, token
crítico, coste, i-frames, lock-on, cámara, ataques normales, HUD y DEAD.
Medición: después de consumir 50 y esperar 2 s con escudo, stamina 56,1667,
incluyendo retraso inicial y tick de consumo. No se usa tiempo renderizado.

Regresiones históricas: **327/327**, con defensa y ataques habilitados:

| Fase | Resultado |
|---|---:|
| 1A | 16/16 |
| 1B | 44/44 |
| 1C | 38/38 |
| 1D | 47/47 |
| 2A | 59/59 |
| 2B | 63/63 |
| 2C | 60/60 |

Se conserva el aislamiento histórico del listener de toque corto de esquiva
en 1B/1D/2A: esas suites esperan que un toque no ejecute acción ni gasto, contrato
sustituido por 2B. Solo ese listener se deshabilita en esas tres suites; cámara,
movimiento, estados, stamina, lock-on, ataques y defensa permanecen activos.
No se modificó ningún check histórico ni su tolerancia. 2B y 2D integradas
verifican el comportamiento nuevo con el listener habilitado. El atacante técnico
permanece presente con todos sus componentes; su entrada humana está deshabilitada
por diseño y no ataca automáticamente. No se deshabilitó para hacer pasar suites.

Durante desarrollo se corrigió una llamada de la suite nueva a toggle_lock
(la interfaz real es try_acquire), y una consulta MCP de resumen con indentación
mixta. Esa consulta pausó el debugger; se reinició la ejecución completa.
No se cambiaron expectativas históricas para ocultar fallos.

Se verificó también F1 mediante evento de teclado simulado: golpe bloqueado,
vida 100 y stamina 84. La revisión visual fue una captura estática a 1280 × 720,
con física de los dos actores/atributos congelada solo durante la captura para
conservar el feedback. Se detectó y corrigió superposición de ayuda con vida:
F1–F4 se trasladó al borde inferior y se redujo la etiqueta del atacante.
Después se reinició el juego completo; ese aislamiento visual no forma parte
de las suites integradas ni queda persistido en escena.

La captura final confirma ayuda inferior y HUD sin superposición a 1280 × 720.
Se comprobó que desactivar debug oculta texto defensivo, ayuda técnica y etiqueta
del atacante; luego se restauró. Ejecución final r45822374-35: arranque mediante
project_run(main), helper vivo, sin errores de parser/runtime ni warnings en
el log de esa ejecución. Protagonista 100/100 vida y stamina, física del jugador
y atacante activas. Los ajustes finales tras las suites fueron solo texto,
tamaño de etiqueta y visibilidad de ayuda, revisados con arranque y captura;
no se repitieron las suites de combate por esos cambios visuales.

## Límites y siguiente integración

No hay joystick físico conectado: no se probaron botones físicos, USB/Bluetooth
ni drivers. La simulación normalizada no demuestra compatibilidad de un mando
concreto. No se afirma fidelidad exacta de frames o sensación jugable de DS1.
El alcance ofensivo sigue siendo volumen estático provisional, sin recorrido
de espada ni animaciones críticas. No hay posicionamiento automático, IA,
backstab, Estus, equipamiento real, resistencias elementales ni efectos avanzados.
No se midió rendimiento en hardware objetivo de 4 GB RAM.

Quedan para 2E las señales de defensa, resultados estructurados, metadatos de
ataque, protocolo de vulnerabilidad/reserva y subtipo crítico. No se implementó
ninguna mecánica de esa fase. F5 utiliza la escena principal existente.
