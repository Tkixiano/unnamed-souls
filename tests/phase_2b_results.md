# Fase 2B — Rodadas, backstep e invulnerabilidad

7 de noviembre de 2026. Godot 4.6.3-stable, proyecto existente
`C:/JUEGOs 3D/soul-game/`. Inspección y ejecución mediante Godot AI MCP.

## Archivos y arquitectura

Se inspeccionaron PlayerController, ActionState, SprintDodgeInput, atributos,
lock-on, referencias de movimiento, InputMap y suites antes de editar.
InputMap conserva sus 21 acciones; detector y cámara no fueron reemplazados.

Creados:
- `scripts/player/dodge_profile.gd`: Resource configurable y validación de perfil.
- `scripts/player/dodge_controller.gd`: petición, dirección fija, tiempo,
  desplazamiento, coste, invulnerabilidad y finalización de esquiva.
- `resources/dodges/fast.tres`, `medium.tres`, `heavy.tres`, `backstep.tres`.
- `scripts/systems/dodge_debug.gd`: indicador textual desactivable.
- `tests/phase_2b_checks.gd`: pruebas de funcionalidad actual.
- `tests/legacy_regressions.gd`: ejecución secuencial con aislamiento explícito.
- Este informe. Los scripts incluyen los UID generados por Godot.

Modificados:
- `scripts/player/player_controller.gd`: procesa solicitudes y recibe velocidad
  horizontal de esquiva; expone referencia de movimiento, invulnerabilidad y
  consulta para un futuro receptor de impactos. Sigue siendo dueño de la física.
- `scripts/player/action_state.gd`: reclamación de estado por dueño y finalización
  exclusiva, sin permitir cancelación normal del DODGING reclamado.
- `scripts/systems/actor_attributes.gd`: método para reiniciar el retraso de
  regeneración al acabar la acción, sin consumo adicional.
- `scenes/player/player.tscn`: componente y referencias a cuatro recursos.
- `scenes/levels/test_arena.tscn`: texto de ayuda, título y debug de esquivas.
- `README.md`: reglas actuales, parámetros, APIs, referencias y pruebas.

Sin cambios en SprintDodgeInput, selección/cambio de lock-on, scripts de cámara,
InputMap ni parámetros originales de locomoción. No se borraron pruebas o
informes históricos. Sin plugins, modelos externos, inventario o archivos Blender.

## Interpretación y dirección

El receptor escucha la señal corta ya existente. Captura entrada/dirección al
soltar y procesa la petición en física, sin una nueva interpretación paralela
del botón. Una liberación larga no genera esquiva. Un tap entre ticks se captura
por eventos y puede tener duración informada cero. Pérdida de foco cancela el gesto
como antes. El umbral de carrera permanece en 0,25 s de tiempo de física.

Aquí rodada y backstep empiezan al soltar un toque corto; no se verificó el frame
exacto de activación original de DS1. No hay buffer de acciones ocupadas, salto
desde carrera o running roll especial. Son diferencias/alcances explícitos.

Libre: dirección analógica relativa a cámara, normalizada y fijada al comienzo.
Fijado: cuatro cardinales relativas a la referencia horizontal del objetivo.
Gana el eje de mayor magnitud; empate exacto de diagonal gana adelante/atrás.
La orientación y selección del objetivo no se reescriben. Visual conserva su
orientación inicial durante la acción y vuelve a su control habitual al terminar.

Sin dirección se hace backstep opuesto al frente de Visual, con coste y perfil
propios. No se deforma, inclina ni hace rodar físicamente la cápsula.

## Peso y perfiles

`equipment_load_percent` provisional, inicial 25%, sin inventario ni equipo real:
FAST ≤25%; MEDIUM >25% y ≤50%; HEAVY >50% y ≤100%; OVERLOADED >100%.

| Perfil | Total s | Movimiento s | Distancia m | I-frames s, inicio incluido/fin excluido | Recuperación s |
| --- | --- | --- | --- | --- | --- |
| FAST | 0,60 | 0,30 | 3,00 | [0,04; 0,30) | 0,20 |
| MEDIUM | 0,78 | 0,36 | 2,60 | [0,06; 0,30) | 0,30 |
| HEAVY | 1,10 | 0,45 | 2,00 | [0,10; 0,28) | 0,45 |
| BACKSTEP | 0,45 | 0,18 | 1,00 | [0,00; 0,10) | 0,18 |

**Son parámetros provisionales, no datos de animación ni frames exactos de DS1.**
Backstep tiene ventana independiente breve, no la de una rodada. No se afirma
que 0,10 s reproduzca el backstep original. Puede anularse con inicio=fin.
No se añadieron efectos de anillos ni variantes especiales.

Recuperación ocupa el final del tiempo total; puede existir una pausa entre fin
del desplazamiento y recuperación. El perfil se valida (tiempos, fin de ventana,
distancia) y se copia al iniciar para que un cambio de Inspector no altere una
acción ya comprometida. El tiempo efectivo se cuantiza a ticks: MEDIUM termina
a 0,7833 s con física de 60 Hz para su valor nominal de 0,78 s.

OVERLOADED rechaza rodada y backstep sin cobrar, mover o simular una animación
de fallo. El porcentaje solo gobierna esquivas en esta fase; no cambia marcha
ni carrera anteriores. No pretende completar todas las penalizaciones de carga
del juego original.

## Stamina, estado y colisiones

Costes configurables: rodada 25, backstep 15. Inicio solo con suelo, vida,
disponibilidad FREE, perfil válido y stamina suficiente. El coste es atómico
y ocurre una vez. Una segunda solicitud no cobra. Chocar no reembolsa coste.

DODGING se reclama por dueño antes de emitir state_changed. Solo el dueño
puede completarlo normalmente; solicitudes normales a FREE u otros estados
se rechazan durante toda la acción y recuperación, incluso dentro de callbacks.
DEAD puede interrumpir y reset explícito limpia acción/impulso/ventana. No se
duplicaron estados de locomoción IDLE/WALK/RUN.

Player conserva el único `move_and_slide()`. El componente integra una curva
ease-out de distancia por intervalo y devuelve velocidad horizontal para ese
tick. La dirección no cambia con stick, carrera, cámara o objetivo durante la
acción. Gravedad y colisión principal siguen activas. No se escribe posición
para atravesar geometría ni se deshabilita CollisionShape3D.

Paredes limitan el desplazamiento; suelo y pendientes usan la física anterior.
Al cruzar un borde se cae por gravedad y no puede iniciarse otra esquiva en aire.
La acción no añade levitación, salto, barreras invisibles o respawn.

Regeneración bloqueada hasta el final de recuperación; entonces se reinicia el
retraso de 0,75 s existente. No hay consumo duplicado al reiniciarlo. Carrera
conserva coste continuo e histéresis de agotamiento de 2A. Stamina no altera
selección/seguimiento del objetivo ni mueve el cuerpo físico por orientación.

`Player.is_invulnerable()` y `can_receive_attack()` permiten a una futura capa
de impactos consultar la ventana y rechazar DEAD. No se conectó daño real ni
hitboxes: `Attributes.apply_damage` sigue siendo una API técnica y no consulta
automáticamente i-frames. Esta consulta no protege de futuras caídas/hazards por sí sola.

## Depuración y APIs

Texto discreto con perfil, DODGING/RECUPERACIÓN e I-FRAMES en color. Se oculta con
`DodgeController.debug_enabled=false`. Sin deformación/animación de cápsula.
`input_enabled` controla solo el receptor de liberaciones cortas, no el motor de
esquivas; inicia true en el juego. API: `try_dodge(Vector2)`, `is_active()`,
`is_invulnerable()`, `is_recovering()`, `get_weight_class()`, `get_profile_name()`;
señales `dodge_started`, `dodge_finished`, `dodge_rejected`.

## Validación final

Suite 2B: **63/63 aprobadas** con esquivas habilitadas, ejecución `r16668006-22`.
Comprueba ocho direcciones libres, cuatro cardinales y diagonales fijadas,
backstep, taps por evento incluso entre ticks, carrera frente a toque corto,
dirección inmutable, exclusión mutua, consumo único, falta de stamina, límites de
carga, perfiles, sobrecarga, recuperación, ventanas por tick, muerte/interrupción,
propiedad del estado incluso dentro de su señal, gravedad, paredes, suelo,
bordes, cámara y conservación de fijación/regeneración.

| Medición | Resultado |
| --- | --- |
| Distancias FAST / MEDIUM / HEAVY | 3,000 / 2,600 / 2,000 m |
| Duraciones medidas | 0,600 / 0,7833 / 1,100 s |
| Integración a deltas 1/30, 1/60, 1/120 s | 3,000 m en las tres |
| Muestras FAST invulnerables a 60 Hz | desde 0,050 hasta 0,2833 s |

Los deltas alternativos son integración numérica, no prueba de tres framerates
gráficos. Las colisiones y caídas se ejecutaron con física real de Godot.

Regresiones anteriores, archivos originales intactos, mediante runner explícito:

| Suite | Resultado | Receptor nuevo de toque corto |
| --- | --- | --- |
| 1A | 16/16 | habilitado |
| 1B | 44/44 | aislado |
| 1C | 38/38 | habilitado |
| 1D | 47/47 | aislado |
| 2A | 59/59 | aislado |

Las **204 comprobaciones históricas** pasaron. 1B/1D/2A contienen expectativas
explícitas de que un toque corto no ejecute acción ni gasto, contrato sustituido
intencionalmente por 2B. Para preservarlas se desactiva solo ese receptor durante
esas suites; movimiento, stamina, estados, lock-on y cámara permanecen activos.
No se eliminaron condiciones ni se ampliaron tolerancias. La suite 2B prueba
la nueva reacción integrada con el receptor activo. No se presentan estas 204
como pruebas de todos los controles actuales con el nuevo receptor habilitado.
El runner reactiva entrada y restaura atributos al terminar. Sus resultados
se obtuvieron antes de la última recarga; ejecutar el runner y consultar metadata
`legacy_regressions` para repetir.

No hubo errores/warnings de runtime en la ejecución final ni nuevos errores del
editor desde cursor 10. Un error inicial de inferencia bool en el test fue
corregido antes de la ejecución completa; no afectaba el controlador de juego.
Se reforzó la propiedad del estado antes de emitir su señal y se comprobó ese
caso; la consulta de impactos también rechaza el estado DEAD explícito.

Revisión visual: captura con simulación del jugador congelada a t=0,10 s para
inspeccionar texto FAST/DODGING/I-FRAMES y stamina 75. Es una revisión estática
de depuración, no una observación de animaciones ni game feeling continuo.
También se verificó que el debug puede desactivarse; el jugador fue restaurado.

No había joystick físico conectado. B se generó con eventos normalizados ID 7;
otras entradas se simularon mediante acciones. No se probaron USB, Bluetooth,
drivers ni mandos reales. No se midió rendimiento en la PC objetivo de 4 GB RAM.

## Referencias y límites de fidelidad

El [manual oficial de FromSoftware](https://www.fromsoftware.jp/manual/darksoulsremastered/ps4/action1.html)
describe dirección con stick, carrera mantenida y backstep sin dirección. La
[wiki de carga](https://darksouls.wikidot.com/equipment-load) documenta los umbrales
25/50/100. Una [referencia comunitaria de backstep](https://estus.com.br/wiki/dark-souls/guia/recuo)
describe una ventana breve distinta de la rodada. No se obtuvo una verificación
primaria de los frames exactos del backstep/rodadas: se usan segundos provisionales
editables, sin afirmar reproducción exacta ni equiparar todos los juegos de la saga.

Quedan para una fase futura el receptor de impactos que consulte las ventanas,
animaciones definitivas y ajuste jugable con mando. No se implementaron ataques,
parry, Estus, bloqueo, enemigos funcionales, daño de enemigos, inventario o equipo
real. No se avanzó a 2C.
