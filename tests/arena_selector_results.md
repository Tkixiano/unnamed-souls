# Selector temporal de arenas

## Archivos

- Creados: scenes/ui/arena_selector.tscn, scripts/systems/arena_selector.gd,
  scenes/ui/arena_menu_link.tscn y scripts/systems/arena_menu_link.gd.
- Modificados: project.godot (solo escena principal), ambas escenas de arena
  (referencia e instancia opcional ArenaMenuLink) y README.md.
- Sin cambios en InputMap, autoloads, movimiento, combate, checkpoints o IA.

## Uso y reemplazo

F5 / arranque del juego abre el selector. Mouse, flechas, WASD, cruceta y stick
izquierdo seleccionan; Enter / A / Cruz confirman. Salir cierra el juego.
Escape / Menu / Options o botón Menú regresa desde cada arena. No es pausa:
descarga la escena y al volver empieza una prueba nueva. La derrota del jefe
se conserva durante la sesión mediante el sistema existente.

Para reemplazarlo basta cambiar application/run/main_scene. Cada arena conserva
su ejecución directa con F6. El enlace de retorno es opcional y su ruta se puede
editar desde Inspector o quitar la instancia. No hay dependencias de combate
con el controlador del menú, ni un singleton nuevo. Las referencias PackedScene
del selector incluyen ambas arenas y sus dependencias como recursos del arranque.

## Validación por Godot AI MCP — Godot 4.6.3

- Arranque desde main: selector correcto y foco inicial Arena de pruebas.
- Teclado: Enter abre test_arena; Escape regresa al selector.
- Mouse simulado: botón Arena de pruebas abre la escena; botón Menú regresa.
- Mando simulado ID 7: stick vertical selecciona Arena del jefe; mantenerlo
  inclinado conserva la selección; neutral rearma. A confirma y carga boss_arena
  con jefe a 600 de vida. Menu regresa al selector.
- Se corrigió durante la prueba un doble avance del stick, provocado por
  navegación ui_down de Godot y la navegación analógica propia. El menú consume
  solo esos eventos del stick antes de GUI; la cruceta usa navegación nativa.
- El botón Salir cerró el proceso correctamente durante la primera prueba.
- Captura visual final real: guía completa, botones y pie visibles a 1280 × 720.
  Comprobación de geometría: pie termina en y=699,5 dentro del viewport de 720.
- Guía de 48 celdas: encabezado y 15 acciones, equivalencias Xbox/PlayStation,
  controles técnicos, umbral de carrera y advertencia para mandos genéricos.
- Logs finales: sin errores nuevos de parser ni runtime. Se dejó el selector
  ejecutándose con teclado/mouse visibles y sin mando físico conectado.

No se generó ni ejecutó un binario exportado en esta tarea. Se configuró el
arranque que utilizará la exportación. No se validó hardware físico de mando.
Las entradas descritas son eventos simulados en ejecución real del editor.

No se repitieron las suites completas de combate, pues sus componentes no se
modificaron. Los resultados históricos siguen intactos. La comprobación histórica
phase_3c_checks.main_scene_configuration_preserved esperaba explícitamente
test_arena como escena principal: esa expectativa dejó de aplicar por el cambio
de arranque solicitado. No se alteró silenciosamente ese test ni sus resultados.
