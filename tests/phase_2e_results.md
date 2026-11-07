# Fase 2E — Backstab, Estus y dos manos

Proyecto existente: C:/JUEGOs 3D/soul-game. Godot AI MCP confirmó Godot
4.6.3-stable oficial, sesión soul-game@90b7, escena principal test_arena.tscn.
Se inspeccionaron controlador, estados, atributos, ataques, daño, hit/hurtboxes,
defensa, críticos, lock-on, esquivas, InputMap, HUD y suites antes de editar.

## Archivos

Creados:
- scripts/player/estus_controller.gd y grip_controller.gd.
- scripts/combat/attack_variant.gd y action_debug.gd.
- scripts/systems/estus_hud.gd y scenes/ui/estus_hud.tscn.
- resources/attacks/two_hand_light_1.tres, two_hand_light_2.tres y two_hand_heavy_1.tres.
- tests/phase_2e_checks.gd, phase_2e_results.json, phase_2e_regressions.json y este informe.
- UID de scripts generados por Godot.

Modificados:
- scripts/combat/riposte_controller.gd: misma ejecución crítica, ahora con dos subtipos.
- scripts/combat/critical_vulnerability.gd: reserva por backstab y reglas de interrupción.
- scripts/combat/hurtbox.gd: identifica el subtipo crítico autorizado en el resultado.
- scripts/combat/defense_controller.gd: consulta disponibilidad del escudo y liberación
  explícita de su bloqueo al cambiar empuñadura.
- scripts/combat/training_dummy.gd: protocolo crítico reutilizable y estado de acción.
- scripts/player/player_controller.gd: conecta y procesa los dos nuevos componentes.
- scripts/player/attack_controller.gd: elige perfiles y expone el subtipo crítico real.
- scripts/player/action_state.gd: añade SWITCHING_GRIP al final, sin renumerar estados.
- scenes/player/player.tscn: componentes y primitivas de frasco, escudo bajo y segunda mano.
- scenes/props/training_dummy.tscn: estado, componente crítico y marcador de frente.
- scenes/levels/test_arena.tscn: HUD, texto de fase/controles y depuración nuevos.
- tests/legacy_regressions.gd: incluye 2D y registra aislamientos explícitos.
- README.md: controles actuales y enlace a este informe.

Sin cambios de InputMap, parámetros de locomoción/cámara, detector de mandos,
SprintDodgeInput, DodgeController, selección/cambio de lock-on, recursos de ataques
de una mano, ActorAttributes, capas de física/combate ni pruebas históricas individuales.
No se instalaron plugins ni assets. No se modificó Blender ni archivos externos.

## Backstab y ejecución crítica compartida

Se conserva RiposteController y su API try_contextual, estados con propietario,
señal riposte_event y reserva CriticalVulnerability. No hay segundo ejecutor de
daño crítico. current_critical_name y current_attack_name distinguen RIPOSTE/BACKSTAB.
Se comprueban primero todos los candidatos de riposte; luego backstab; sin candidato
válido, AttackController inicia LIGHT_1. Falta de stamina con candidato válido
rechaza la solicitud, sin convertirla en golpe normal.

Backstab provisional, configurable desde Inspector:

| Parámetro | Valor |
|---|---:|
| Distancia máxima | 1,6 m |
| Cono trasero del objetivo | 80° total (±40°) |
| Orientación del jugador hacia el objetivo | ±45° |
| Desnivel máximo compartido con críticos | 1 m |
| Coste de stamina | 30 |
| Daño a una mano | 140 |
| Instante de daño | 0,45 s |
| Duración total | 1,20 s |

Se usa el frente horizontal de Visual del objetivo, no la cámara. Si u es la
dirección horizontal jugador→objetivo y f el frente del objetivo, se exige
f·u ≥ cos(40°), y frente_jugador·u ≥ cos(45°). Esto coloca al jugador detrás,
sin admitir costados ni frente. Raycast World y corredor de CapsuleShape3D
de radio 0,20/altura 1,40 comprueban trayectoria libre, excluyendo los cuerpos
de la pareja. No hay desplazamiento de alineación ni teletransporte.

Objetivos con atributos, estado y Hurtbox pueden reutilizar CriticalVulnerability.
Se acepta FREE o ataque normal explícitamente interrumpible; una vulnerabilidad
de parry ya abierta también puede reservarse desde atrás. Otras acciones ocupadas
no se interrumpen. Player.can_interrupt_for_backstab excluye críticos porque
solo acepta el AttackController normal activo. El muñeco estático no tiene ataque
saliente: no acepta parry, pero sí reserva desde FREE. Sus tres instancias tienen
un marcador frontal visible y conservan sus IDs/posiciones y vida anteriores.

La reserva posee STAGGERED del objetivo y ATTACKING del ejecutante. Consume stamina
una vez, congela locomoción y mantiene gravedad y cápsulas físicas. No activa
hitbox ofensiva normal. El instante de daño usa el mismo token de autorización
de un uso y el único apply_damage de Hurtbox. El resultado distingue backstab
y riposte. Se revalida alcance/orientación/corredor al impactar; un fallo no
devuelve coste. Los valores de daño/tiempo se copian al iniciar, sin cambiar a
mitad del crítico por modificar Inspector.

Muerte, destrucción o reset del objetivo invalidan la reserva; el sobreviviente
recupera su estado sin sobrescribir DEAD. Al terminar se liberan ambas reservas.
Se conserva la regla provisional de 2D: impactos normales de terceros no dañan
a la pareja comprometida. No es una nueva ventana de i-frames de rodada.

## Estus

EstusController posee HEALING y tiene reloj físico independiente de renderizado.
X/Cuadrado/E genera una solicitud por flanco; mantener el botón no bebe repetidamente.
Solo FREE, en suelo, vivo, con vida incompleta y al menos una carga permite iniciar.
No consume stamina; durante HEALING la regeneración permanece bloqueada por la
política de estados existente. Al completar reinicia el retraso de regeneración.

| Parámetro configurable | Valor inicial |
|---|---:|
| Cargas iniciales | 5 |
| Curación | 60 |
| Preparación | 0,45 s |
| Consumo y curación desde inicio | 0,85 s |
| Fin de recuperación | 1,50 s |

Fases lógicas: PREPARATION [0;0,45), DRINKING [0,45;0,85), RECOVERY [0,85;1,50).
Se detiene el movimiento horizontal; gravedad/colisión continúan. No se puede
atacar, rodar, correr, levantar escudo, parry ni cambiar empuñadura. No se cura
al pulsar; en t=0,85 se enclava uso y descuenta exactamente una carga antes de
emitir señales/aplicar restore_health. Se limita la vida al máximo y nunca revive.
Si otro sistema cura al jugador después de empezar, el uso comprometido igualmente
consume la carga al llegar a su instante, aunque la curación adicional sea cero.

interrupt_for_stagger es el punto explícito para un futuro impacto que provoque
stagger: interrumpe la acción propia y entra en STAGGERED. Antes de consumir no
gasta ni cura; después conserva ambos efectos. No se convirtió automáticamente
todo impacto en stagger ni se añadió un sistema de poise. La recuperación de ese
stagger corresponde al futuro propietario del daño, igual que el interruptor
de daño de ataques existente. DEAD cancela sin curar ni consumir tardíamente.
restore_all reinicia atributos y cargas para pruebas; F5 recarga la escena.

Señales charges_changed, phase_changed y used permiten reemplazar HUD y sincronizar
animaciones futuras. EstusHUD usa señal de cargas, un rectángulo ámbar como símbolo
y texto: no consulta recursos por frame ni requiere imágenes externas.

## Una y dos manos

GripController usa la acción two_hand_toggle existente (Y/Triángulo/R). Desde FREE
o bloqueo propio puede iniciar; en este último caso libera únicamente el estado
BLOCKING que posee DefenseController. No puede cancelar ataques, esquivas, parries,
HEALING, STAGGERED, críticos o DEAD. Una pulsación inicia una transición de 0,40 s,
con cambio de modo en 0,20 s; SWITCHING_GRIP posee el estado hasta completarla.
Se añadió al final del enum (ID 8), preservando todos los IDs anteriores, DEAD=7.
No consume stamina, pero bloquea movimiento/acciones y regeneración mientras dura.
Muerte antes del punto de cambio no aplica el modo tardíamente; restore_all vuelve
a ONE_HANDED. No existe buffer que cambie el modo al terminar otra acción.

ONE_HANDED conserva perfiles originales, escudo y parry. TWO_HANDED los deshabilita
mediante shield_available, sin sustituir DefenseController. La espada pasa del
lado derecho al centro, se oculta el escudo y aparece una segunda mano geométrica.
Una mano muestra el escudo bajo al estar libre; la geometría defensiva elevada
original conserva su comportamiento y las expectativas históricas.

AttackVariant genera snapshots desde un Resource fuente. Multiplica daño y daño
de stamina por 1,35, coste por 1,20. En fuerte multiplica startup/recovery por 1,10.
Los tres recursos nuevos son independientes y ajustables; nunca mutan los de una mano.
El combo y buffer siguen en el mismo AttackController, con un solo ejecutor e hitbox.

| Perfil | Startup | Active | Recovery | Daño | Stamina |
|---|---:|---:|---:|---:|---:|
| LIGHT_1 | 0,25 | 0,15 | 0,40 | 20 | 18 |
| LIGHT_2 | 0,30 | 0,15 | 0,45 | 25 | 20 |
| HEAVY_1 | 0,55 | 0,20 | 0,65 | 45 | 35 |
| TWO_HAND_LIGHT_1 | 0,25 | 0,15 | 0,40 | 27 | 21,6 |
| TWO_HAND_LIGHT_2 | 0,30 | 0,15 | 0,45 | 33,75 | 24 |
| TWO_HAND_HEAVY_1 | 0,605 | 0,20 | 0,715 | 60,75 | 42 |

Multiplicador crítico independiente de dos manos: 1,20 (riposte 144, backstab 168).
Coste crítico se conserva en 30. El modo no puede cambiar durante un golpe.
La hitbox frontal provisional conserva orientación y alcance de 2C; no se afirma
un barrido de espada real ni alcance distinto. Los perfiles/snapshots y eventos
existentes permiten añadir animaciones y shapes específicos después.

## Integración y depuración

Si llegan solicitudes incompatibles en un tick, el orden físico es cambio de
empuñadura, defensa, Estus, esquiva y ataque. La primera acción que obtiene el
estado excluye a las demás. Se conservan intérprete B, lock-on, cámara, hitboxes,
hurtboxes, consumo/regeneración y estados IDLE/WALK/RUN. Bloqueo a dos manos se
rechaza por modo incluso si LB permanece pulsado.

ActionDebug muestra modo/transición, fase de Estus y subtipo crítico. El frasco
ámbar aparece solo durante HEALING, sin animar/deformar cápsula. La depuración
nueva se oculta con ActionDebug.enabled=false o AttackController.debug_enabled=false;
el HUD de cargas y las primitivas de juego permanecen como representación provisional.
La ayuda de F1–F4 del atacante técnico continúa disponible, sin IA ni secuencia autónoma.

## Pruebas y resultados

Godot AI MCP ejecutó la suite nueva: **77/77**. Reporte completo en
phase_2e_results.json. Incluye los 28 puntos solicitados y estas verificaciones:
- Backstab trasero, frente/lateral/rango/orientación/corredor, independencia de cámara,
  prioridad frente a ligero y prioridad de riposte frente a otro candidato trasero.
- Reserva atómica, daño diferido/único, no daño normal adicional, muerte/reset,
  destrucción del objetivo y componentes de muñeco reutilizables.
- Estus por X normalizado, carga/curación diferidas y únicas, límites, fases,
  recuperación, HUD, interrupción antes/después de uso y DEAD sin uso tardío.
- Cambio por Y normalizado, compromiso temporal, dos manos, combo, costes,
  daño real por Hitbox, fuerte más lento, fuentes intactas, retorno de escudo,
  rechazo de parry/bloqueo, lock-on y esquiva a dos manos.

La suite 2E mantiene activos todos los listeners y componentes reales del
protagonista. Daño por hitbox y parry se prueban integrados; para interrupción de
Estus se aplica un impacto por Hurtbox y se llama explícitamente a la API de
stagger, sin inventar un sistema automático de stagger. Eventos RB/X/Y se simulan
como mando normalizado ID 7; otras entradas usan acciones. No había mando físico.

Regresiones 1A–2D: **390/390**, guardadas en phase_2e_regressions.json:

| Fase | Resultado |
|---|---:|
| 1A | 16/16 |
| 1B | 44/44 |
| 1C | 38/38 |
| 1D | 47/47 |
| 2A | 59/59 |
| 2B | 63/63 |
| 2C | 60/60 |
| 2D | 63/63 |

No se modificó ningún check histórico. Se conserva el aislamiento anterior de
toque corto en 1B/1D/2A, cuyo contrato original esperaba cero acción/coste antes
de existir esquivas. Se añade aislamiento SOLO de adquisición de backstab en 2C:
sus pruebas esperan golpes normales sobre muñecos vistos desde atrás, que ahora
son contextualmente críticos. Riposte, defensa, Estus y empuñadura permanecen
activos. El nuevo comportamiento se prueba integrado en 2E, incluyendo golpes
normales frontales, sin desactivar adquisición de críticos.

Problema encontrado durante implementación: al ampliar selección de perfiles
a Resource se requirió declarar explícitamente Dictionary para snapshot; el
parser lo rechazó hasta corregirlo. No se alteraron expectativas para ocultarlo.
Los tiempos/daños son provisionales configurables, no datos exactos de DS1.

Revisión visual: capturas estáticas del juego a 1280 × 720 con HEALING a t=0,50 s
(BEBIENDO, 5 cargas, vida 20) y t=0,90 s (RECUPERACIÓN, 4 cargas, vida 80), en dos
manos. Se congeló únicamente el proceso físico del protagonista durante esas
capturas para conservar las fases, no durante las suites. HUD y textos no se
superponen. No es una evaluación de game feeling ni una prueba física de mando.
Se reinicia la escena tras revisar; la congelación no se guarda en archivos.
La ejecución de pruebas r47173864-37 y la revisión r47680461-38 terminaron con
helper vivo y logs de juego sin errores ni warnings. Arranque final r47819289-39 verificado: helper vivo, sin errores de parser/runtime
ni warnings en el juego y sin nuevas entradas del editor desde cursor 13.
Vida/stamina 100, Estus 5, ONE_HANDED, FREE, física activa, cámara actual y
adquisición de backstab habilitada. Se verificó que el debug nuevo se oculta
sin ocultar el HUD de cargas. El proyecto queda ejecutándose desde su escena principal.

## Límites y próxima integración

No se evaluó sensación de combate mediante automatización. No hay pruebas físicas
de USB/Bluetooth/mandos reales ni medición en hardware de 4 GB RAM. El daño normal
sigue usando volumen estático frontal; no hay animaciones, alineación crítica,
root motion ni sincronización de espada definitiva. Estus no tiene inventario,
hogueras ni guardado; sus cargas se restablecen solo por reset técnico/F5.

Se preparan subtipo crítico, reserva compartida, señales de curación, interrupción
por stagger, modo de empuñadura y snapshots de variantes para futuras animaciones
y combate. No se implementó IA, jefe, arma nueva, estadísticas RPG, inventario,
hogueras, guardado ni mecánicas de la siguiente fase. F5 conserva test_arena como
escena principal y el renderizador Compatibility.
