# Resultado de verificación — Fase 1A

Fecha: 6 de noviembre de 2026. Herramientas: Godot AI MCP.

## Inspección

- Godot 4.6.3-stable oficial; sesión `soul-game@90b7`.
- Raíz confirmada: `C:/JUEGOs 3D/soul-game/`.
- Proyecto existente abierto correctamente. Inicialmente sin escena principal
  ni escenas/scripts de juego. Ya incluía Godot AI, icono y configuración Jolt.
- Se trabajó dentro de esta carpeta, sin crear otro proyecto ni añadir plugins.

## Ejecución final

`scene_open` cargó la arena desde disco y `project_run(mode="main")` confirmó
helper activo y `current_run_errors=[]` (ejecución `r643418-3`).

La suite `phase_1a_checks.gd`, invocada por `editor_manage(game_eval)`, pasó
**16/16 comprobaciones**, sin fallos:

1. Escena principal correcta.
2. CharacterBody3D, colisión y Visual/Placeholder presentes.
3. Suelo, luz y cámara activa presentes.
4. Física a 60 ticks/s.
5. Viewport de 1280 × 720.
6. Renderer efectivo `gl_compatibility`.
7. Mouse visible.
8. Las 20 acciones requeridas con eventos de teclado y mando.
9. Bindings de mando para cualquier ID (`device=-1`).
10. RB sintético desde ID 7 activa `light_attack`.
11. Inventario inicial coincide con Godot.
12. Disponibilidad de mando coincide con el inventario.
13. Señales sintéticas de conexión/desconexión llegan al detector.
14. Las señales sintéticas no inventan dispositivos físicos.
15. Indicador de estado contiene texto.
16. El personaje permanece inmóvil al simular `move_forward`.

`input_map_manage(list)` confirmó las 20 acciones y `toggle_fullscreen`.
`get_scene_tree` confirmó los 17 nodos de la arena.
Captura de juego revisada: cápsula y suelo visibles, texto legible y cámara fija.
Logs finales: sin errores/warnings de runtime; sin nuevos errores del editor
desde cursor 6. Los mensajes de hotplug con ID 9999 provienen de la suite.

## Hardware y limitaciones

`Input.get_connected_joypads()` devolvió una lista vacía. Se verificó que el
inicio sin joystick funciona. **No se pudo comprobar una conexión/desconexión
real ni entradas físicas de mandos Xbox, PlayStation o genéricos.**
Los eventos sintéticos verifican el software, no USB/Bluetooth/drivers.
Los mandos desconocidos se detectan pero su distribución requiere un mapping
o remapeo posterior; no se promete compatibilidad universal sin configuración.

La prueba F11 envió eventos de teclado sintéticos, pero el juego se ejecuta
embebido en el editor. Godot informó `Embedded window only supports Windowed
mode`. Se mantuvo en ventana. El cambio real a pantalla completa queda pendiente
de probar en una ejecución independiente; no se cambiaron preferencias globales.
No se midió rendimiento en el hardware objetivo de 4 GB de RAM.

## Problemas corregidos durante la preparación

- El script de arena se importó antes de registrar el autoload: errores de
  resolución del singleton en editor. Se registró y se usó una referencia tipada
  al nodo raíz; la escena se recargó y la ejecución final quedó limpia.
- Godot AI creó inicialmente eventos solo para dispositivo 0. Se corrigieron
  los eventos persistidos y del editor a cualquier ID, comprobados en runtime.
- La primera prueba de RB consultaba antes de procesar el buffer de entrada y
  reutilizaba el mismo evento. Se corrigió el test para vaciar el buffer, esperar
  un frame y usar otro evento para soltar el botón. La ejecución final pasó.

No se implementaron movimiento, combate, stamina, IA, lock-on, cámara controlable
ni sistemas de fases posteriores.
