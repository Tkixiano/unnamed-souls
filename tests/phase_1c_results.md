# Fase 1C — Cámara orbital y validación

Godot 4.6.3-stable, proyecto `C:/JUEGOs 3D/soul-game/`.
Inspección y ejecución con Godot AI MCP; fuentes y escenas leídas antes de editar.

## Inspección e integración

Se verificaron por MCP sesión, versión, jerarquía, propiedades de Camera3D,
InputMap y API nativa de SpringArm3D. Se revisó el controlador del jugador y las
pruebas anteriores. La cámara provisional estaba en (0,4,7), yaw 0° y pitch −24°.
El movimiento ya proyectaba el frente de `movement_camera` al plano horizontal.

No se modificó el código del controlador del jugador ni el InputMap. La arena
asigna `Player.movement_camera` a la cámara orbital y `CameraRig.follow_target`
a Player mediante referencias exportadas. Se conservan el detector de mandos,
las capas World=1/Player=2, física a 60 Hz y Compatibility a 1280 × 720.

## Archivos creados

- `scenes/props/camera_rig.tscn`.
- `scripts/systems/orbit_camera.gd` y UID generado por Godot.
- `scripts/systems/camera_spring_arm.gd` y UID generado por Godot.
- `tests/phase_1c_checks.gd` y UID generado por Godot.
- Este informe.

Archivos modificados:
- `scenes/levels/test_arena.tscn`: rig y referencias; elimina solo la cámara fija;
  añade dos paredes y una columna con mallas/colisiones primitivas; actualiza HUD.
- `project.godot`: habilita interpolación física para el render de poses a 60 Hz.
- `tests/phase_1a_checks.gd`: consulta cámara activa del viewport.
- `tests/phase_1b_checks.gd`: consulta `Player.movement_camera`.
- `README.md`: configuración, interfaz, pruebas y limitaciones actuales.
- Se retiró el marcador vacío `.gitkeep` de props, ahora con una escena real.

Los informes históricos y todas las comprobaciones de fases anteriores se
conservan. Los dos cambios de pruebas eliminan dependencias de la antigua ruta
`TestArena/Camera3D`, sin eliminar comprobaciones ni reducir cobertura.

## Jerarquía y parámetros

```text
CameraRig                         orbit_camera.gd
└── YawPivot
    └── PitchPivot
        └── SpringArm3D            camera_spring_arm.gd
            └── Camera3D
```

| Parámetro | Inicial |
| --- | --- |
| Altura / distancia normal | 1,25 m / 4,5 m |
| Distancia mínima preferida | 0,55 m, subordinada a la colisión |
| Seguimiento / recuperación de distancia | 14 s⁻¹ / 8 s⁻¹ |
| Sensibilidad horizontal / vertical | 150°/s / 110°/s |
| Deadzone circular | 0,22 |
| Pitch mínimo / máximo / inicial | −65° / +35° / −18° |
| Yaw inicial / inversión vertical | 0° / desactivada |
| Mouse técnico | arrastrar con botón derecho, 0,16°/píxel |
| SpringArm | esfera de radio 0,25 m, margen 0,08 m, máscara 1 |
| Camera3D | FOV 60°, near 0,05 m, far 60 m |

Valores ajustables y aproximados; no son mediciones exactas de Dark Souls 1.
La órbita usa acciones semánticas existentes y delta. No se gira al personaje
al mover solo la cámara. El mouse técnico no captura el cursor y no sustituye
el joystick. No hay recentrado automático ni balanceo.

El jugador procesa física a prioridad 0, el rig a 10 y el brazo a 20. Seguimiento
exponencial en física y render interpolado evitan mezclar dos controladores de
transformación en física/render. Se ofrece `snap_to_target()` para teletransportes.

## Colisiones

SpringArm3D realiza el barrido nativo de esfera sobre World. Además de separar
capas, se excluye explícitamente el RID del objetivo si es CollisionObject3D.
El pequeño script del brazo usa su longitud segura: contrae inmediatamente
para no atravesar obstáculos y suaviza la recuperación hacia la distancia normal.
La contracción no se demora artificialmente por un filtro que deje la cámara
detrás de una pared. El radio/margen reducen roces en esquinas y columnas.

Si hay menos espacio que el mínimo preferido, la seguridad permite una distancia
inferior: imponer 0,55 m de manera absoluta atravesaría la pared. No se añadió
transparencia del personaje ni reubicación de un pivote que esté dentro de geometría.

## Pruebas ejecutadas

Suite 1C final: **38/38 aprobadas**, sin fallos, ejecución `r2630819-9`.
Regresión 1B: **44/44 aprobadas** con la nueva cámara y obstáculos.
Regresión 1A: **16/16 aprobadas**, incluyendo el detector y bindings existentes.

Cobertura automatizada 1C:
- Jerarquía, referencias explícitas, interpolación y órbita horizontal de 360°.
- Límites verticales, inversión, sensibilidad analógica y deadzone sin drift.
- Independencia de cuerpo/Visual ante entrada de cámara.
- Mouse técnico y ausencia de movimiento residual tras el evento.
- Modo EXTERNAL, control de ángulos y regreso a FREE.
- Seguimiento con error acotado, estabilidad al frenar y al invertir dirección.
- Movimiento relativo a yaw ±90°/180°, derecha tras órbita, velocidad independiente
  del pitch, diagonal, carrera y desaceleración.
- Contracción contra ambas paredes y columna; longitud segura aplicada en el
  mismo tick, estabilidad en contacto y recuperación suavizada.
- Exclusión explícita del jugador, incluso cambiando temporalmente su capa a 1.
- Respeto a geometría cuando el espacio es menor al mínimo preferido.
- Sonda esférica de 0,1 m en la posición de cámara: sin solapamientos con World
  en las 144 muestras de una órbita completa.
- Consistencia numérica de yaw/seguimiento usando deltas 1/30, 1/60 y 1/120 s.

| Medición | Resultado |
| --- | --- |
| Órbita acumulada | −360° |
| Error máximo de seguimiento caminando | 0,203 m |
| Yaw tras 1 s con deltas 30/60/120 | −150° / −150° / −150° |
| Rotación en 12 ticks con entrada 0,5 / 1,0 | 0,188 / 0,524 rad |
| Distancia en contacto con pared | 2,628 m |
| Primera muestra de recuperación | 2,862 m |
| Distancia recuperada | 4,499 m de 4,5 m |

Los cambios de delta son una comprobación numérica del controlador; no equivalen
a medir tres rendimientos gráficos. Las colisiones usan física real de Godot.
La estabilidad temporal está verificada por muestras; no se hizo una revisión
visual continua de todas las trayectorias ni una comparación jugable con DS1.

Revisión visual mediante capturas MCP: encuadre inicial con cápsula, obstáculos
y HUD; encuadre contra la pared tras contraer la cámara. No se detectaron problemas
en esas capturas. Los logs de la ejecución final no contienen errores/warnings de
runtime; el editor no agregó errores desde cursor 8. Arranque de escena principal
confirmado por MCP con helper activo y `current_run_errors=[]`.

## Correcciones y limitaciones

Las suites antiguas dependían del nodo de cámara provisional. Se adaptaron para
consultar sus referencias reales y conservar todas las comprobaciones.
En la nueva suite se corrigió un error de inferencia de tipo de un Vector3;
se reinició el juego y la ejecución final del archivo actualizado pasó completa.

No hay mando físico conectado. Entradas de stick/mouse y hotplug se probaron con
eventos sintéticos; USB, Bluetooth, drivers y game feeling con mando real quedan
pendientes. No se midió rendimiento en el equipo objetivo de 4 GB RAM.
El cursor puede alcanzar los bordes de ventana al usar el mouse técnico sin captura.
La arena tiene bordes abiertos y no hay respawn. Espacios extremadamente estrechos
pueden acercar la cámara mucho a la cápsula; no se implementó ocultamiento visual.

## Interfaces para fase 1D

`get_orbit_angles()` / `set_orbit_angles(yaw, pitch)` en radianes;
`get_follow_target()` / `set_follow_target(target, snap=true)`;
`snap_to_target()`; `set_control_mode(FREE/EXTERNAL)` y propiedades públicas
`camera`, `spring_arm`, `control_mode`. EXTERNAL suspende entrada manual y mantiene
seguimiento; FREE retoma el control desde la orientación actual.

No se implementó lock-on funcional, selección de objetivos, enemigos, combate,
rodadas, stamina, animaciones ni efectos cinematográficos. Fase 1D no iniciada.
