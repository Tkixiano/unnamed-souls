# Fase 1B — Informe de validación

Fecha: 6 de noviembre de 2026. Godot AI MCP, Godot 4.6.3-stable.
Proyecto existente: `C:/JUEGOs 3D/soul-game/`.

## Inspección previa

Se leyeron escenas, scripts y InputMap antes de editar. Player es CharacterBody3D,
con CollisionShape3D y Visual/Placeholder. Cámara en (0, 4, 7), yaw 0° y pitch
−24°, mirando hacia −Z. El cuerpo no tenía controlador y la cápsula era simétrica.
Se conservan InputMap (21 acciones), detector/autoload, cámara fija, suelo,
renderer Compatibility, 1280 × 720, física a 60 Hz y estructura de carpetas.

## Archivos

Creados:
- `scripts/player/player_controller.gd` y su UID generado por Godot.
- `scripts/player/sprint_dodge_input.gd` y su UID generado por Godot.
- `tests/phase_1b_checks.gd` y su UID generado por Godot.
- Este informe.

Modificados:
- `scenes/player/player.tscn`: controlador, parámetros de suelo y marca frontal.
- `scenes/levels/test_arena.tscn`: referencia a cámara y textos de la fase.
- `tests/phase_1a_checks.gd`: la condición estática ante entrada se reemplaza por
  estabilidad en reposo, porque la fase 1B incorpora movimiento deliberadamente.
- `README.md`: controles, parámetros, arquitectura y ejecución de pruebas.

No se modificó el detector, el InputMap ni la configuración general del proyecto.

## Resultado

Ejecución `r1277682-5`: **44/44 comprobaciones de movimiento aprobadas**, sin
fallos. Regresión de fase 1A actualizada: **16/16 aprobadas**.

Cobertura de la suite 1B:
- Adelante, atrás, izquierda y derecha: desplazamiento, orientación, estado WALK
  y ausencia de rotación del cuerpo físico en las cuatro direcciones.
- Diagonal sin aumento de velocidad; deadzone y tres intensidades analógicas.
- Aceleración progresiva, frenado gradual, detención e inmovilidad del giro en reposo.
- Reversa con frenado previo; giro de 180° limitado y orientación final correcta.
- Movimiento relativo a yaw de cámara y velocidad sin reducción por su pitch.
- Umbral de carrera, RUN al mantener B, vuelta a WALK al soltar y reposo con B.
- Liberación corta, liberación larga y tap completo entre ticks conservados.
- Caída por gravedad, aterrizaje, estabilidad de suelo y colisión contra pared.
- Orientación automática desactivable independientemente del movimiento físico.
- Consistencia numérica del integrador con deltas de 1/30, 1/60 y 1/120 s.

Mediciones:

| Magnitud | Resultado |
| --- | --- |
| Velocidad diagonal normal | 3,200 m/s |
| Entrada 0,30 | 0,328 m/s |
| Entrada 0,55 | 1,354 m/s |
| Entrada 1,00 | 3,200 m/s |
| Carrera | 6,000 m/s |
| Velocidad inicial / estable / frenando | 0,467 / 3,200 / 2,533 m/s |
| Distancia integrada en 1 s a deltas 30/60/120 | 2,887 / 2,861 / 2,847 m |

La diferencia numérica máxima de integración fue 0,039 m. Esta comprobación
varía delta en el integrador, no simula tres rendimientos gráficos distintos.
La integración de colisiones se probó con la física real del proyecto a 60 Hz.
Pendientes configuradas a 45° y snap 0,25 m; no se ensayó un circuito de pendientes.

Godot AI confirmó carga de la escena principal y helper activo, sin errores
de arranque. Logs del editor desde cursor 6 sin errores nuevos; logs de esta
ejecución sin errores ni warnings de juego. Captura revisada de la escena y HUD.
La primera invocación de la suite superó el límite de 8 s de game_eval; se pasó
a ejecución asíncrona con consulta de resultado, sin reducir la cobertura.

## Hardware y alcance

No hay joystick físico conectado. Se usaron eventos normalizados sintéticos de
joystick ID 7 que atraviesan InputMap; la suite 1A verificó inventario sin mandos,
RB sintético y señales sintéticas de conexión/desconexión. No se probaron entradas
físicas, USB/Bluetooth ni drivers de Xbox, PlayStation o genéricos.

Los parámetros iniciales son 3,2/6 m/s, aceleración 14 m/s², desaceleración
20 m/s², giro 540°/s, deadzone 0,22 y umbral 0,25 s. No son valores exactos de
Dark Souls 1 ni implican equivalencia de game feeling; requieren prueba jugable.
El personaje provisional carece de animaciones y la cámara es fija. La arena
tiene bordes abiertos: salir y caer requiere reiniciar la ejecución.

Quedan preparados para fase 1C: referencia reemplazable de cámara, orientación
visual controlable por separado, señal de liberación del botón compartido y
estados/velocidad accesibles para animaciones. No se implementaron ataques,
stamina, rodadas, lock-on, cámara orbital ni una máquina de estados de combate.
