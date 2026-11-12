# Hotfix integral: jefe, rodadas 360° y lock-on durante carrera

Fecha de intervención: 12 de noviembre de 2026. Motor comprobado mediante Godot AI MCP: Godot 4.6.3 stable, Compatibility. Alcance exclusivo de las partes A, B y C; sin nueva exportación.

## A. Jefe

### Causa raíz y reproducción

`guardian_brain.gd::_physics_process()` llamaba a `actor.restore_at_checkpoint()` cuando el jugador **o el jefe** quedaban fuera de `inside_arena()`. En ambas escenas artísticas, el semiancho lógico seguía siendo 9 m, heredado del prototipo. La colisión artística tiene una extensión horizontal aproximada de 27,94 × 27,99 m. Por eso existía suelo jugable fuera del rectángulo de 18 × 18 m.

Se reprodujo mediante `game_eval` de Godot AI MCP, colocando al jugador en posiciones controladas: encuentro iniciado en z=7, jefe en INTRO con 550 HP; después de colocar al jugador en z=-10 y avanzar dos ticks, el jefe aparecía en IDLE con 600 HP, posición inicial z=-3 y encuentro desactivado. **Fue una reproducción automatizada, no una reproducción visual con un mando físico.** Datos en `hotfix/baseline_reproduction.json`; arnés original en `hotfix/probe.txt`.

La niebla no tenía una señal de salida que cancelara el combate: `encounter_entry.gd` solicita el inicio mientras el jugador está en su área. Después del reinicio indebido, el jugador tenía que volver a esa área para iniciar otra vez, lo que explicaba el síntoma observado.

### Corrección mínima

- Eliminada la restauración implícita por separación espacial. La vida y la fase no dependen de la proximidad a la niebla.
- Ajustados los semianchos lógicos de **las dos escenas artísticas** a 13,9 m, dentro de las dimensiones de colisión medidas, con sus centros existentes (z=0 y z=-48). No se amplió arbitrariamente un radio para ocultar el reinicio.
- Se conserva `inside_arena()` para adquisición/movimiento, la comprobación de suelo/obstáculos `Queries.can_step()`, `CharacterBody3D`, gravedad y colisiones.
- Se mantienen muerte/reintento, restauración mediante checkpoint, nueva partida, derrota de sesión y prioridad de DEAD. No se cambiaron daño, patrones, velocidad ni tiempos del jefe.

Archivos de juego: `scripts/bosses/guardian_brain.gd`, `scenes/levels/ruins_boss_arena.tscn`, `scenes/levels/main_level.tscn`.

### Pruebas y limitaciones

`hotfix/a_checks.gd`: 60/60 comprobaciones específicas en ambas escenas, fase 1 y fase 2; centro, fondo y laterales; suelo real, objetivo, vida, fase, movimiento de persecución, ausencia de reinicio espacial y restauración explícita. La fixture permite acabar la INTRO antes de medir el desplazamiento de persecución.

La caja lógica sigue siendo una envolvente sencilla; no sustituye la colisión de la geometría ni acredita cada punto continuo de su superficie. No se modificó el arte. La revisión jugable humana del extremo de la arena queda recomendada; el recorrido automatizado y la caminata física adicional se detallan en la validación general.

## B. Rodadas

### Causa y cálculo direccional

`dodge_controller.gd::_resolve_request()` conservaba diagonales en modo libre, pero cuando existía una referencia de movimiento (lock-on) elegía un único eje mediante `abs(x) > abs(y)`. Los empates diagonales elegían el eje longitudinal. Era una cuantización cardinal intencional de la fase 2B, incompatible con el nuevo requisito.

Se eliminó esa cuantización. La dirección usa ahora `player.camera_relative_direction(input_vector)`, también durante lock-on. Esa API existente proyecta el frente de la cámara al plano horizontal, lo normaliza y combina sus ejes con **ambas componentes** de la entrada. Finalmente se anula y y se normaliza la dirección del desplazamiento.

El controlador no accede a índices físicos de mando. La entrada normal continúa usando `Input.get_vector()` con la deadzone configurable existente; la API técnica `try_dodge()` recibe un vector ya procesado, como antes. No se redondea el ángulo a cuatro ni ocho sectores. Se captura al soltar la pulsación corta y se guarda al iniciar; cambiar el stick o la cámara durante la acción no redirige la trayectoria.

### Integración y conservación de reglas

- Teclado: se conservan las acciones del InputMap y sus combinaciones diagonales normalizadas.
- Mando: cualquier ángulo analógico horizontal, sin alterar la distancia del perfil por la magnitud del vector.
- Con lock-on: se mantiene el objetivo y el seguimiento de cámara; la dirección de esquiva es relativa a cámara. La locomoción normal sigue usando su referencia al objetivo existente.
- Backstep: una entrada nula después de la deadzone conserva la dirección posterior visual y su perfil propio. No se convirtió en rodada.
- Sin cambios en FAST, MEDIUM, HEAVY, OVERLOADED, costes, distancias, duración, recuperación, integración del desplazamiento o i-frames. El bloqueo de acciones, colisiones y gravedad permanecen en sus componentes anteriores.

Archivo de juego: `scripts/player/dodge_controller.gd`.

### Pruebas y limitaciones

`hotfix/b_checks.gd`: 185/185 comprobaciones específicas. Se verificaron ocho direcciones básicas y ángulos analógicos de 15°, 30°, 45°, 60°, 120°, 225° y 315°, con/sin lock-on; cámara girada/inclinada; desplazamiento real del CharacterBody3D, distancia normalizada, dirección fija, suelo, coste, duración física, i-frames, perfiles y restricciones, backstep y deadzone.

La medición temporal final se toma del contador físico al emitir `dodge_finished`, evitando confundir muestras de renderizado con ticks de simulación. Las primeras mediciones fallidas del arnés se conservaron en `hotfix/b_first_results.json`; no motivaron cambios en tiempos del juego. `hotfix/a_first_results.json` conserva igualmente la primera medición de persecución tomada antes de terminar INTRO.

Se añadieron eventos sintéticos de teclado obtenidos de los bindings reales para comprobar la ruta completa del botón, además de las pruebas por API. Los resultados de esta suite y las comprobaciones integradas figuran abajo.

No hubo mando físico conectado. Las entradas y ángulos fueron simulados; no se evaluó el game feeling ni una equivalencia exacta con Dark Souls.

## C. Lock-on

### Condición anterior y corrección

`lock_on_controller.gd::_physics_process()` contenía `if player.is_sprinting: release_lock(&"sprint"); return`. Se eliminó exclusivamente esa salida. WALK/RUN/DODGING no invalidan por sí mismos un objetivo.

Se mantienen la referencia al objetivo, el modo EXTERNAL de cámara y la orientación contextual existente. Correr hacia delante, atrás, lateral o diagonal utiliza la locomoción ya implementada. No se cambiaron velocidad, aceleración, coste de stamina, agotamiento ni umbral de recuperación. El hotfix tampoco modifica selección/cambio de objetivos.

Condiciones conservadas: cancelación manual, objetivo inválido/no disponible/muerto, muerte del protagonista, distancia máxima y oclusión prolongada. Sus distancias y temporizadores conservan los valores anteriores; correr no evita esas rupturas válidas.

Archivo de juego: `scripts/player/lock_on_controller.gd`.

### Pruebas específicas

`hotfix/c_checks.gd`: 44/44 comprobaciones. Caminata y carrera en ocho direcciones, detención, coste continuo por tick, agotamiento, secuencia correr → rodada diagonal → correr → ataque → bloqueo, referencia de objetivo, cámara, pausa durante esquiva, cancelación manual, objetivo no disponible y distancia. La suite histórica 1D mantiene sus pruebas de oclusión, destrucción y demás rupturas.

### Validación general y archivos de pruebas

Resultados generados durante este hotfix (sin sumar repetidamente los agregados anidados):

| Suite nueva | Aprobadas/total | Fallidas |
|---|---:|---:|
| `a_results.json` | 60/60 | 0 |
| `b_results.json` | 185/185 | 0 |
| `c_results.json` | 44/44 | 0 |
| `keyboard_results.json` | 40/40 | 0 |
| `d_results.json` | 33/33 | 0 |

**Pruebas nuevas: 362/362 aprobadas; 0 fallidas. Regresiones: 1096/1096 aprobadas; 0 fallidas.** A/B/C se repitieron después de aplicar las tres correcciones. No se cuentan dos veces sus primeras ejecuciones ni los agregados anidados. La carga de ocho scripts se comprobó además mediante una prueba MCP independiente; el launcher solo acredita el arranque del runner, no suma pruebas de juego.

| Regresión ejecutada | Aprobadas/total | Fallidas |
|---|---:|---:|
| Fase 1A | 16/16 | 0 |
| Fase 1B | 44/44 | 0 |
| Fase 1C | 38/38 | 0 |
| Fase 1D | 47/47 | 0 |
| Fase 2A | 59/59 | 0 |
| Fase 2B | 63/63 | 0 |
| Fase 2C | 60/60 | 0 |
| Fase 2D | 63/63 | 0 |
| Fase 2E | 77/77 | 0 |
| Fase 3A | 61/61 | 0 |
| Fase 3B | 62/62 | 0 |
| Fase 3C | 74/74 | 0 |
| Fase 4A | 64/64 | 0 |
| Fase 4B recorrido | 47/47 | 0 |
| Fase 4B espacial | 26/26 | 0 |
| Fase 4B reintento | 8/8 | 0 |
| Fase 5A | 53/53 | 0 |
| Fase 5A contexto | 10/10 | 0 |
| aggro_checks.gd | 38/38 | 0 |
| phase_5b_checks.gd | 73/73 | 0 |
| phase_5c_checks.gd | 95/95 | 0 |
| phase_5c_followup.gd | 5/5 | 0 |
| query_results.json | 11/11 | 0 |
| detection_results.json | 2/2 | 0 |

Los resultados individuales, el agregado y `regressions_native.log` quedan en `tests/hotfix/`. El recorrido 4B utiliza combate con los actores reales y daño mediante hitboxes del jugador hasta victoria; su fixture histórica aumenta la vida del jugador para sobrevivir al ensayo automatizado, sin cambiar stamina ni daño. El reintento 4B conserva los atributos normales y la muerte por ataques autónomos. La prueba integrada nueva D conserva los atributos normales y todos los controladores/IA; coloca actores para delimitar casos y aplica daño técnico solo al forzar fase, muerte y victoria. No se interpreta ninguna de estas pruebas como valoración manual de equilibrio o dificultad.

La suite adicional de teclado pasó 40/40: eventos sintéticos clonados de las teclas configuradas, ocho combinaciones con/sin lock-on, intérprete de pulsación corta y distancia física. La suite integrada D pasó 33/33: diagonal en bosque, junto al soldado y arena del jefe, tutorial completado por señal real de esquiva, persistencia de instrucción al morir, aggro del soldado sin cambios, pausas en rodada/carrera/combate/encuentro, caminata real al fondo, ataque posterior sin reentrada en niebla, fase 2, muerte/reintento, victoria, persistencia de derrota y nueva partida.

**F5 y F6:** inicio mediante MCP `project_run(mode="main")` comprobado en `res://scenes/ui/main_menu.tscn`; nueva partida/recorrido cubiertos por suites nativas. `project_run(mode="current")`, equivalente a F6, carga `res://scenes/levels/ruins_boss_arena.tscn`. Se recargó esa escena desde disco y quedó abierta y ejecutándose, con vida/stamina 100, cinco Estus y jefe no activado. No se afirma haber pulsado físicamente F5/F6. Evidencia: `f5_startup.json`, `f5_game_log.json`, `f6_startup.json`, `f6_game_log.json`.

**Errores y advertencias:** sin errores de parser/runtime en la ejecución final de suites ni en ambos arranques; el registro nativo tampoco contiene errores. El editor conserva 10 advertencias de código preexistente: nombres que ocultan propiedades en `action_state.gd` (57/69), `scene_audio_bridge.gd` (123/126) y `attack_controller.gd` (205/230); ternarios de tipos distintos en `audio_director.gd` (73/97); referencias locales `best` implícitamente nulas en `lock_on_controller.gd` (116/168 después de retirar la rama de carrera). No se borraron ni se ampliaron los cambios del hotfix para corregirlas. La presencia anterior de las declaraciones `best` también se comprobó contra Git. Detalle íntegro: `editor_log_review.json`. El mensaje de modo ventana incrustado es una limitación informativa del editor; las opciones se probaron en instancia nativa.


### Cambios justificados en pruebas históricas

- `tests/phase_1d_checks.gd`: las expectativas de liberación por carrera y cámara libre ahora exigen conservar objetivo y cámara fijada. Misma cobertura de carrera/velocidad; 47 comprobaciones.
- `tests/phase_2a_checks.gd`: la carrera consumiendo stamina ahora debe mantener lock-on; 59 comprobaciones. Se conserva la pulsación corta y el agotamiento.
- `tests/phase_2b_checks.gd`: los seis casos cardinales fijados pasan a comprobar el vector completo relativo a cámara; siguen verificando que el lock-on sobrevive. 63 comprobaciones.
- `tests/phase_3c_checks.gd`: la separación espacial ahora debe conservar el encuentro y el ataque comprometido; se añade una prueba de restauración explícita segura. Pasa de 73 a 74 comprobaciones. No se eliminó cobertura del reinicio, muerte/reintento o victoria.

No se cambiaron informes históricos ni expectativas ajenas a las modificaciones deliberadas. Los runners copian únicamente rutas de salida para escribir dentro de `tests/hotfix/`. Se mantiene la preparación histórica documentada: aislamiento del soldado en fixtures anteriores a su incorporación, del listener de pulsación corta en 1B/1D/2A, del backstab contextual en 2C y de restauración automática en fixtures previas a 3B. Los casos integrados conservan los componentes reales activos. Solo se aísla la pantalla de victoria automática para que las suites mecánicas posteriores a la muerte del jefe puedan continuar; las regresiones de menús prueban esa pantalla activada. La preparación 4B de contacto con la hoguera espera suelo/área, según el ajuste ya documentado en fases previas.

Infraestructura nueva: `tests/hotfix/` contiene suites A/B/C/D/teclado, runners, resultados, registros, reproducción e integridad. `tests/test_hotfix_native.gd` inicia la regresión nativa mediante Godot AI MCP y `tests/test_hotfix_parse.gd` comprueba carga de scripts.

### Integridad, límites de validación y repetición manual

La comparación SHA-256 con el inicio de esta intervención identifica únicamente los cinco archivos de juego enumerados arriba. Los recursos de ataques y rodadas, materiales, IA de soldados, configuración del proyecto y archivos de `soulgameexported/` se conservan sin cambios. No se exportó el juego y Preview 6B no contiene este hotfix.

Las comprobaciones son automatizadas/simuladas con física real del motor cuando se indica. No constituyen pruebas físicas con joystick, evaluación manual de combate, garantía exhaustiva de colisiones ni medición de rendimiento en hardware escolar. La advertencia del editor sobre modo ventana incrustado se distingue de errores del juego; las pruebas nativas permiten comprobar las opciones de pantalla sin esa restricción.

Para repetir manualmente: iniciar por F5, entrar al jefe desde el nivel y recorrer fondo/laterales en ambas fases; correr con un objetivo válido, soltar, rodar en diagonal, correr de nuevo, atacar y bloquear; probar pausa y muerte/reintento. Abrir `ruins_boss_arena.tscn` y usar F6 para el acceso directo. Revisar con mando físico todos los ángulos analógicos, drift, orientación visual y estabilidad subjetiva de cámara.
