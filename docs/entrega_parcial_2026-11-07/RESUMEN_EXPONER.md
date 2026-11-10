# Guion de exposición oral

Duración estimada: 4 minutos a un ritmo de 125 a 140 palabras por minuto. Los nombres se completan por el equipo. No leer las indicaciones entre corchetes.

## 0:00 a 0:40 - Presentación

Nuestro proyecto consiste en desarrollar un videojuego soulslike 3D de fantasía medieval oscura. Un soulslike propone un combate que exige observar, administrar recursos y elegir cuándo actuar. Tomamos como referencia las mecánicas de Dark Souls 1, pero no afirmamos haber reproducido exactamente sus animaciones, tiempos o dificultad.

Este es un informe parcial al 7 de noviembre. Tenemos un prototipo funcional, construido con geometría sencilla. La Fase 4A, dedicada a la siguiente etapa de integración, todavía no comenzó.

## 0:40 a 1:20 - Herramientas y equipo

Usamos Godot 4.6.3 y GDScript para la lógica. El trabajo del equipo se divide en programación, arte 3D y música. Blender forma parte del flujo de arte, aunque los modelos y animaciones definitivos todavía no están integrados en esta carpeta.

Codex nos asiste con programación y documentación, y Godot AI MCP permite inspeccionar el editor, ejecutar verificaciones y obtener capturas. Las personas definimos requisitos, revisamos decisiones y supervisamos los resultados. La asistencia automática no reemplaza las pruebas jugables ni la responsabilidad del equipo.

## 1:20 a 2:10 - Arquitectura y mecánicas

[Mostrar el diagrama de componentes.]

Separamos el movimiento físico, la orientación visual y la disponibilidad de acciones. El personaje se mueve respecto a la cámara y usa stamina para correr, rodar y atacar. La cámara orbital evita obstáculos, y el lock-on cambia el movimiento a desplazamiento alrededor de un objetivo.

Los ataques tienen anticipación, ventana activa y recuperación. Solo durante la ventana activa puede producirse un impacto. Jugador, soldado y jefe comparten los componentes de ataques y daño. Así evitamos construir tres sistemas distintos y podemos corregir una regla en un solo lugar.

También funcionan el escudo, el parry, los críticos contextuales, Estus y el cambio a dos manos. Cada acción reserva su estado para impedir cancelaciones incompatibles.

## 2:10 a 2:55 - Encuentros y reintentos

[Mostrar las capturas del soldado, la hoguera y el jefe.]

El soldado detecta por distancia, ángulo y línea de visión, persigue sin atravesar paredes y ataca con pausas. Su navegación es sencilla: todavía no busca caminos alternativos.

Las hogueras restauran atributos, Estus y enemigos normales. Al morir, se cancelan las acciones, aparece YOU DIED y el jugador reaparece en el checkpoint sin conservar ataques pendientes.

El jefe tiene dos fases. Al llegar al cincuenta por ciento de vida termina el patrón comprometido y cambia de fase. Se vuelve más agresivo y agrega un ataque de área con advertencia. Su derrota queda registrada durante la ejecución, sin guardar una partida en disco.

## 2:55 a 3:35 - Evidencia de pruebas

La entrega histórica de la Fase 3C registra 73 comprobaciones nuevas y 590 de regresión aprobadas. No sumamos las regresiones de todas las fases porque repiten comprobaciones anteriores.

Los tests verifican reglas, contactos y restauraciones dentro del motor. No prueban por sí mismos que el juego sea divertido o se vea terminado. No se usó joystick físico: las entradas fueron simuladas. La revisión visual fue principalmente estática, y falta medir el rendimiento en el hardware escolar.

## 3:35 a 4:10 - Cierre

El principal aprendizaje fue integrar componentes que comparten datos y respetan estados, tiempos y colisiones. El prototipo ya permite demostrar un ciclo de combate, muerte y victoria.

Falta integrar modelos, rigging, animaciones, escenario, música, efectos e interfaz definitiva. También necesitamos evaluación manual, joystick real y una exportación Windows probada. La posibilidad de terminar para el 17 de noviembre depende de esas entregas y del tiempo de ensayo. Por eso presentamos el avance con evidencia, sin confundir una base funcional con un videojuego finalizado.

## Preparación de la demostración

- Abrir F5 y elegir una arena en el selector. Escape / Menu / Options vuelve al menú; no pausa el combate.
- Teclado: WASD, Espacio, Q, clic izquierdo/J, Shift/K, Ctrl/L, C/I, E, R y F. La guía completa está en el menú.
- Preparar capturas y PDF como respaldo si el equipo de exposición no ejecuta correctamente el prototipo.
- Para repetir una victoria del jefe, cerrar y volver a abrir el juego: su derrota se conserva durante la sesión.
- No improvisar afirmaciones sobre rendimiento, compatibilidad de mandos o animaciones todavía pendientes.
