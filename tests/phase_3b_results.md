# Fase 3B — Hogueras, muerte y reaparición

Godot AI MCP confirmó Godot 4.6.3-stable oficial, proyecto existente
C:/JUEGOs 3D/soul-game. Se revisaron PlayerController, atributos, DEAD,
Estus, propietarios de acción, cámara, lock-on, soldado, arena, InputMap y suites.
Se reutiliza restore_all y sus señales; no hay otro sistema de daño o vida.

## Archivos

Creados (más UID generados por Godot):
- scripts/systems/checkpoint_manager.gd.
- scripts/systems/bonfire.gd.
- scripts/systems/death_screen.gd y checkpoint_status.gd.
- scenes/props/bonfire.tscn.
- scenes/ui/death_screen.tscn.
- tests/phase_3b_checks.gd, phase_3b_results.json, phase_3b_regressions.json y este informe.

Modificados:
- scripts/player/player_controller.gd: API de restauración y barrera temporal de entrada.
- scripts/player/attack_controller.gd, estus_controller.gd y grip_controller.gd:
  respetan la disponibilidad de entrada tras reaparición; conservan sus ejecutores.
- scripts/combat/defense_controller.gd y riposte_controller.gd: misma barrera,
  sin cambiar selección, fases, daño, estabilidad ni costes.
- scripts/enemies/soldier_actor.gd: restauración en la instancia existente,
  clasificación de entidad y memoria de jefe derrotado durante la sesión.
- scripts/combat/defense_test_attacker.gd: cancelación/recolocación técnica al restaurar.
- scenes/levels/test_arena.tscn: hoguera, gestor, pantalla, ayuda y punto inicial seguro.
- tests/legacy_regressions.gd: incluye 3A, con aislamientos registrados explícitamente.
- README.md: uso actual de F, ciclo de prueba y enlace al informe.

No se cambió InputMap ni la distribución cómoda de teclado/mouse. Tampoco
atributos, ActionState, SoldierAI, daño, hit/hurtboxes, perfiles, rodadas,
movimiento/cámara orbital o valores de combate. Sin plugins ni assets externos.
No se modificaron scripts de checks históricos ni recursos de Blender.

## Arquitectura y APIs

CheckpointManager vive en el nivel, con referencias exportadas a jugador,
LockOnController, CameraRig y marcador inicial. No hay rutas absolutas ni autoload
nuevo. Sus APIs son register_bonfire, unregister_bonfire, get_active_bonfire,
get_respawn_transform, activate_bonfire, rest_at, request_respawn y restore_enemies.
Las señales checkpoint_activated, rested, death_started, death_visibility_changed
y respawned permiten sustituir interfaz o integrar un nivel definitivo.

El registro usa StringName único, rechaza ID vacío/duplicado de otra instancia
y permite registrar la misma instancia de forma idempotente. active_id es memoria
solo de esta ejecución. Antes de activar nada se usa initial_spawn; si falta, se
conserva el transform inicial del jugador. Si desaparece la representación de una
hoguera activa se conserva su último punto registrado como respaldo.

Bonfire contiene Visual (cenizas, dos leños, espada y esfera naranja), InteractionArea,
RespawnPoint y Prompt. No tiene partículas, fuentes externas, luz costosa ni colisión
sólida ornamental. El área es esfera de radio 1,8 m, máscara Actor=2; solo consulta
la identidad del protagonista, no se activa por enemigos o el actor técnico.
lit controla la primitiva naranja encendida/apagada. El ID se asigna por instancia.

## Interacción y descanso

F / A / Cruz usa la acción interact existente. Se detecta flanco de pulsación,
ignora repetición de tecla y consume una sola solicitud. Mantener pulsado no
produce descansos sucesivos. Entre varias áreas se elige la más cercana.
Se exige estar en el área, vivo, en suelo, FREE y sin ciclo o restauración en curso.
No se permite cancelar ATTACKING, DODGING, BLOCKING, PARRYING, HEALING o STAGGERED
usando la hoguera. FREE puede descansar aunque estuviera caminando/corriendo.

Descansar activa/enciende el checkpoint y, en una operación física síncrona:
- Libera lock-on y referencia de movimiento fijado.
- Restaura vida/stamina con ActorAttributes.restore_all.
- Esa señal limpia propietarios, acciones, buffers, críticos y repone Estus.
- Vuelve a ONE_HANDED y anula velocidad horizontal/vertical e intención de carrera.
- Restaura enemigos y detiene los ataques técnicos pendientes.

No recoloca al jugador al descansar; solo al reaparecer. La fase RESTORING bloquea
reentrada por señales durante la transacción. Activar un checkpoint por la API
activate_bonfire solo registra/enciende; rest_at incluye la restauración completa.

## Muerte y secuencia

Player ya entra en DEAD mediante su señal died. Los controladores existentes
cancelan ataque, hitbox, buffer, esquiva/i-frames, escudo/parry, curación,
cambio de empuñadura y crítico; lock-on se libera por disponibilidad del actor.
El gestor coordina después el tiempo y la presentación, sin aplicar daño.

| Fase | Comportamiento | Valor inicial |
|---|---|---:|
| DEATH_DELAY | Permanece muerto; cámara estable, sin overlay | 0,60 s |
| DEATH_SCREEN | YOU DIED y fondo oscuro, sigue DEAD | 2,00 s |
| RESTORING | Overlay oculto; restaura en el siguiente tick | 1 tick de separación |
| NONE | Encuentro restaurado; entrada espera botones neutrales | — |

Los tiempos son exportados y se copian al comenzar cada secuencia. El reloj usa
delta de física; no se pausa SceneTree, no hay sleep ni temporizadores por acción.
La cámara guarda sus ángulos, suspende control libre y seguimiento mientras está
muerto, conservando la posición. Los enemigos siguen su física y reaccionan a un
objetivo DEAD con las reglas de 3A. No se restaura vida al comenzar la pantalla.

La pantalla es un Control reemplazable dentro de CanvasLayer=100, con ColorRect
y Label de fuente por defecto, sin imágenes. death_visibility_changed la actualiza.
El overlay se oculta un tick ANTES de restaurar vida/control, verificado por señales.

## Reaparición y limpieza de entradas

Al terminar se restauran enemigos y se mueve al jugador al RespawnPoint. El cuerpo
físico conserva orientación independiente; Visual toma el yaw del marcador. Se
limpian velocidad, estado de locomoción, referencia fijada y buffers mediante las
APIs existentes. Estado FREE, vida/stamina al máximo, Estus repuesto a su capacidad
inicial (cinco por defecto) y política explícita ONE_HANDED, incluso si murió a dos manos.

CameraRig recupera seguimiento del jugador, modo libre, yaw del marcador y pitch
inicial. Se hace snap/reset de interpolación para evitar interpolar el teletransporte.
La colocación del marcador debe ser válida y libre, configurada por el nivel;
no se añadió búsqueda automática de espacios libres o validación de navmesh.

checkpoint_input_blocked requiere soltar ataques, bloqueo, parry, B/Espacio,
Estus, empuñadura, interacción y lock-on mantenidos. La ayuda avisa mientras
espera. APIs de inicio también consultan can_accept_action_input, por lo que no
basta llamar directamente al controlador para saltar la barrera. Soltar y pulsar
otra vez permite actuar; no se reproducen combos, ataques, curaciones o bloqueo
anteriores. Movimiento/cámara mantenidos no son solicitudes ofensivas almacenadas.

La barrera solo se activa por restore_at_checkpoint; no cambia el contrato técnico
histórico de attributes.restore_all. Un restore_all externo durante una secuencia
cancela su pantalla/reaparición pendiente para no disparar un segundo reset tardío.

## Enemigos y jefes futuros

Soldier entra al grupo checkpoint_enemies y expone restore_at_checkpoint. Conserva
su transform de aparición y yaw visual desde ready. Se restaura la MISMA instancia:
atributos, posición/orientación, velocidades, material vivo, hitbox desactivada,
Hurtbox habilitada y disponibilidad de lock-on. Las señales limpian acciones y
reservas. Se reinician IDLE, memoria de adquisición, stagger, contador de ataques,
esperas y semilla; se conserva la referencia exportada al jugador para detectarlo
de nuevo. No se añade otra IA ni se duplica/recrea el soldado.

EntityKind contiene NORMAL_ENEMY y BOSS. Los normales se restauran aunque hayan
muerto. Un BOSS derrotado registra boss_defeated_this_session y no se restaura al
descansar durante esta ejecución. Un jefe vivo podría restaurarse según esta API;
no hay implementación de jefe, solo política y simulación cambiando temporalmente
el tipo del soldado en una fixture. El indicador vive en memoria, sin disco.

El controlador técnico F1–F4 está en checkpoint_auxiliary_resets: cancela su cola,
restaura su actor y lo devuelve a la ubicación técnica inicial. Así un ataque
de depuración previo no queda activo al reaparecer. Los muñecos inertes conservan
sus funciones y no se clasifican como enemigos normales de IA.

## Arena y uso

Hoguera en (7;0;1,3), marcador relativo (0;0;-1,3); inicio/reaparición en (7;0;0),
cerca de la hoguera y fuera del radio inicial de detección del soldado. El yaw
del marcador (aprox. 61,5°) orienta Visual y cámara hacia el encuentro; no se
modifican sensibilidades ni el cuerpo físico. Pulsar F
la enciende/restaura; acercarse al soldado inicia combate. Al morir se ve YOU DIED,
se vuelve junto a la hoguera y el soldado reaparece en (0;0;-3,8), con 180 de vida.
F vuelve a descansar. Antes de activarla, morir usa el punto inicial del nivel.
F5 reinicia toda la ejecución: hoguera apagada, sin checkpoint persistido.

No se añadió una tecla de suicidio al comportamiento de juego: las pruebas usan
APIs técnicas de daño y también una muerte causada por contacto real de la IA.
Se mantienen F1–F4 como pruebas técnicas separadas, junto a los muñecos existentes.

## Pruebas

Suite nueva final **62/62** (incluye dos checks de orientación tras revisión visual), resultados en phase_3b_results.json. Cubre los 28 puntos
solicitados: registro/ID/área, teclado F y mando normalizado A simulado, restauración,
muerte y cancelaciones, YOU DIED, orden de overlay/control, posición/estado,
botones mantenidos, reservas, reset de IA/hitboxes, múltiples descansos y muertes,
no duplicación y jefe derrotado simulado. Usa referencias y componentes reales,
sin mocks de atributos, daño, acción, IA, cámara, pantalla o críticos.

Para acelerar pruebas temporales se configuran 0,10 s de retraso y 0,20 s de pantalla;
se restauran los valores originales al terminar. La fixture no congela la física.
El caso integrado coloca al protagonista con 20 de vida frente al soldado; la IA
detecta, ataca, mata y el gestor completa reaparición/restauración real. También
se verificó manualmente mediante MCP el ciclo de duración por defecto antes de
la suite: DEAD con vida cero y, después de 165 ticks, FREE/vida completa/Estus 5
en el punto registrado. Eso es ejecución automatizada real del motor, no mando físico.

Regresiones finales 1A–3A: **528/528**, repetidas tras el ajuste visual del punto
inicial y orientación. Reporte completo: phase_3b_regressions.json.

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
| 2E | 77/77 |
| 3A | 61/61 |

Ningún check histórico individual se modificó. El runner aísla interacción y
reaparición automática nuevas porque las suites anteriores requieren que DEAD
permanezca hasta su reset técnico y no teletransportarse durante una fixture.
Conserva los aislamientos anteriores de toque corto (1B/1D/2A), backstab (2C) y
soldado autónomo (1A–2E). En 3A se vuelve a habilitar el soldado real. 3B se prueba
integrada con gestor, IA e interacción activos. Al terminar se restauran flags,
visibilidad, proceso y posiciones. No se alteran tolerancias para ocultar fallos.

La revisión visual detectó columna delante de la cámara en la primera ubicación
del checkpoint y un aviso de interacción demasiado grande. Se movió el inicio
al lateral despejado y se orientó jugador/cámara según el marcador de aparición;
el aviso se redujo. Son ajustes del nivel/checkpoint, sin cambiar sensibilidades
ni reescribir colisión/órbita. La suite final vuelve a probar esa orientación.

Se revisaron capturas reales estáticas a 1280 × 720 de la hoguera/aviso y YOU DIED.
Para capturar la pantalla se amplió su duración solo en runtime a 20 s, sin
pausar ni congelar la física. Se descartó esa ejecución y se volvió a iniciar
con los valores reales 0,60/2,00 s. No se guardó el ajuste de captura.

Arranque final r70759023-52 mediante project_run(main): helper vivo y sin errores
de parser/runtime ni warnings. Se ejecutó otra muerte con tiempos reales; tras
165 ticks: vida/stamina 100, Estus 5, ONE_HANDED, FREE, overlay oculto, posición
(7;0;0), yaw de cámara 1,0735 rad y soldado IDLE con 180 de vida. El checkpoint
comenzó vacío al reiniciar, comprobando ausencia de persistencia. Los logs del
editor no tuvieron entradas nuevas desde cursor 13. Se dejó el juego detenido
y test_arena abierta, lista para empezar un encuentro limpio con F5.

La comparación de InputMap mediante MCP confirmó las mismas 21 acciones y todos
los bindings de teclado/mouse/mando existentes. No se alteraron controles.

## Límites y siguiente integración

No hay persistencia entre ejecuciones, viaje rápido, menú de hoguera, almas,
inventario, jefe real, animaciones definitivas, música ni efectos avanzados.
Descansar es una restauración inmediata controlada, sin animación de sentarse.
No hay joystick físico conectado: F/A son eventos simulados, no pruebas USB/Bluetooth.
No se midió rendimiento en hardware de 4 GB RAM ni se afirma sensación jugable
de DS1 por automatización. Los marcadores deben colocarse fuera de geometría
sólida y zonas de daño del nivel definitivo.

Quedan interfaces de registro, activación, señales de ciclo, restauración por
grupo, política de entidad y puntos de aparición para otro nivel o interfaz.
No se implementó ninguna mecánica de la siguiente fase. La escena principal
permanece test_arena y se ejecuta con F5.
