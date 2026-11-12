# Fase 6B — Unnamed Souls, Preview 6B para Windows

Exportación iniciada el 11 de noviembre y validación final completada el **12 de noviembre de 2026**. Godot 4.6.3 oficial, Compatibility, Windows x86_64. Entrega en la carpeta existente `soulgameexported/`; no se utiliza `builds/windows/preview_6b/`.

## Resultado de la entrega

Se generaron `Unnamed Souls.exe` y `Unnamed Souls.rar`, con README, licencias y sumas SHA-256. El ejecutable incorpora su PCK y no requiere un PCK separado. El RAR histórico permanece intacto. La copia extraída se ejecutó y cargó el nivel con el editor cerrado en esta misma computadora.

La validación combina pruebas directas del Release y pruebas automatizadas de sus recursos exportados mediante un motor con soporte de pruebas. **Estas últimas no se presentan como ejecución automatizada del binario Release ni como evaluación jugable manual completa.**

## Inspección y protección de archivos previos

La carpeta contenía únicamente `soulgameexported.rar`, de 26 823 312 bytes, modificado previamente el 9 de noviembre. No había un ejecutable con el nombre de destino ni otro `Unnamed Souls.rar`, por lo que no fue necesario renombrar archivos previos.

SHA-256 del respaldo histórico: `7ee4d18475b4f62db62076c6011f9cb19931c837d8e136a4e8777e4a75b318b2`. Se verificó otra vez al finalizar. No se extrajo sobre él, eliminó ni modificó.

Se inspeccionaron project.godot, export_presets.cfg, escenas de menú/nivel/arena, controles, autoloads, recursos, plantillas instaladas, herramienta de compresión y plugin de exportación Godot AI. No hay GDExtensions ni DLL propias del proyecto. Los imports PE del ejecutable corresponden a bibliotecas de Windows; el controlador gráfico OpenGL debe estar instalado en el equipo receptor.

## Configuración de exportación

| Campo | Valor |
|---|---|
| Preset reutilizado | Windows Desktop |
| Modo | Release |
| Arquitectura | x86_64; PE Machine 0x8664 |
| Motor y plantilla | Godot 4.6.3 oficial |
| Destino | soulgameexported/Unnamed Souls.exe |
| Datos | PCK incorporado, formato 3 |
| Resolución inicial | 1280 × 720 |
| Renderizador | Compatibility / OpenGL |
| Ventana | Valor inicial en ventana; completa desde Opciones |
| Escena inicial | res://scenes/ui/main_menu.tscn |
| ProductName | Unnamed Souls |
| FileDescription | Unnamed Souls - Preview 6B |
| Versiones PE | 0.6.2.0, numeración técnica provisional para Preview 6B |
| Empresa / firma | Sin empresa atribuida y sin firma digital |

Se conservaron embed_pck, arquitectura, texturas y renderizador correctos. Se corrigió el destino anterior `../soulgameexported/SoulGame.exe`, que apuntaba fuera de la carpeta solicitada. La configuración anterior se conserva en `phase_6b/original_export_presets.cfg`.

Se excluyen tests, docs, addons, exportaciones, archivos comprimidos, Blender y otros archivos auxiliares del proyecto. `.gdignore` evita que Godot importe la carpeta de salida. El manifiesto del PCK contiene **600 entradas**; no hay archivos de tests, docs, addons ni la exportación histórica dentro del paquete.

El plugin Godot AI existente retiró el autoload `_mcp_game_helper` de la exportación y conservó la configuración de desarrollo. El runtime solo tiene ControllerRegistry, GameMenus y AudioDirector. No se instaló ningún plugin ni herramienta nueva.

Se comprobó la metadata PE después de exportar. No hubo errores ni advertencias de exportación. Godot aplicó los recursos de Windows sin requerir instalar rcedit. Se conserva el icono provisional existente; no se crea un icono definitivo.

El nombre interno del proyecto y el título visible siguen siendo **Soul game**, según la restricción de no cambiarlo innecesariamente. La identidad de Windows, archivos y README es Unnamed Souls. No se modificó project.godot, escenas, arte, combate ni IA.

## Archivos entregados

Todos los siguientes están dentro de `soulgameexported/`:

| Archivo | Bytes | MiB |
|---|---:|---:|
| soulgameexported.rar | 26,823,312 | 25.58 |
| Unnamed Souls.exe | 400,362,880 | 381.82 |
| Unnamed Souls.rar | 212,326,266 | 202.49 |
| README.txt | 4,413 | 0.00 |
| Godot-License.txt | 105,181 | 0.10 |
| SHA256SUMS.txt | 248 | 0.00 |

El histórico no forma parte del nuevo RAR. `.gdignore` permanece como auxiliar local y tampoco se distribuye. La nueva compresión contiene exactamente cuatro archivos: ejecutable, README.txt, Godot-License.txt y SHA256SUMS.txt. No hay dependencias auxiliares propias que copiar ni PCK externo.

El ejecutable mide aproximadamente 400,36 MB decimales y el RAR 212,33 MB. El aumento frente al archivo histórico responde al contenido artístico y al nivel actual; no se realizó optimización destructiva de modelos o texturas para reducir el tamaño.

## Compresión y verificación de extracción

Se detectó y utilizó **RAR 7.22 x64 de WinRAR**, ya instalado. Se creó un RAR5 con compresión normal y una lista explícita de archivos; no se comprimió la carpeta completa ni se mezclaron versiones.

`rar t` terminó con código 0. Se extrajeron sus cuatro archivos en una carpeta temporal independiente, fuera del proyecto. Las sumas SHA-256 de todos los archivos extraídos coinciden exactamente con los originales. `extract_location.json` registra el destino y `extracted_manifest.json` sus tamaños y hashes.

La copia extraída arrancó mediante su propio EXE, desde su carpeta temporal, sin Godot Editor abierto. Cargó el menú y una nueva partida: suelo, ruinas, árboles, roca/hoguera, personajes provisionales, HUD y tutorial aparecieron. Se confirmó también el reinicio con su diálogo.

Las rutas de recursos del PCK son virtuales/relativas; el manifiesto no contiene la carpeta fuente. La prueba del PCK informa que `res://tests/aggro_checks.gd` no existe y que el helper MCP no está presente. Los controladores de QA externos usan rutas absolutas para sus propios archivos, pero **no están incluidos en el RAR ni son necesarios para iniciar el juego**.

Esto verifica ejecución portable en la computadora actual; no prueba compatibilidad ni portabilidad en otra computadora.

## Pruebas directas del ejecutable Release

Se usó la habilidad Computer Use para inspección visual e interacción de Windows. No hubo mando físico.

- Arranque del EXE sin editor, menú, Nueva partida y carga del bosque integrado.
- HUD, cinco Estus, tutorial contextual inicial, primitivas y recursos artísticos visibles.
- Interacción F: encendido real de la hoguera y cambio del indicador a Descansar.
- Pausa por Esc y regreso al menú principal.
- Opciones: cambio del volumen general de 100 a 95, pantalla completa y vuelta a ventana.
- Salida mediante el botón Salir. Reinicio del EXE con el editor cerrado y verificación visual del volumen 95 persistido. Después se restauró a 100 y se guardó.
- En la copia extraída: Nueva partida, carga visual del nivel y confirmación de Reiniciar partida. Se volvió a mostrar el estado inicial del tutorial y atributos.
- Cierre de la copia extraída por Alt+F4.

El editor se cerró sin cambios pendientes durante la prueba; no era un proceso requerido por el Release. Después se reabrió en la arena artística para conservar F6.

No se afirma haber completado manualmente todo el combate, muerte, reintento y jefe en el Release. Ese recorrido se validó de forma automatizada con los recursos del PCK, como se detalla a continuación. Las pulsaciones breves de cámara no sustituyen una evaluación manual de control continuo o game feeling.

## Regresiones automatizadas sobre el contenido exportado

La plantilla Release de Godot 4.6.3 bloquea la sustitución de escenas por línea de comandos (`disable_path_overrides`). Un primer intento de añadir una escena externa de QA fue rechazado con código 1; se conserva probe.log. Fue una restricción de la prueba, no un fallo del arranque normal. No se debilitó esa protección ni se incorporó un controlador de pruebas al producto.

Para probar el contenido se ejecutó el motor instalado en modo juego, sin interfaz del editor, con `--main-pack` apuntando al mismo EXE y un driver externo. Los recursos y scripts jugables proceden del PCK incorporado; los scripts de pruebas se leen fuera de él. Esta es una validación del paquete exportado bajo un runtime con soporte de pruebas, **no del EXE Release exacto**.

| Suite | Aprobadas |
|---|---:|
| aggro_checks | 38/38 |
| phase_3c_checks | 73/73 |
| phase_4b_checks | 47/47 |
| phase_4b_retry | 8/8 |
| phase_5a_checks | 53/53 |
| phase_5a_context_checks | 10/10 |
| phase_5b_checks | 73/73 |
| phase_5c_checks | 95/95 |

Resultado consolidado: **397/397 comprobaciones**. No se cuentan de nuevo los intentos repetidos ni se suman resultados históricos de otras fases.

La primera ejecución conjunta dio 396/397: las pruebas de menús habían generado una muerte de jefe y la suite de audio esperaba un contador diagnóstico global inicial vacío. El dato acumulado fue boss_death=2. Se conservan la salida original y `pack_qa_first/`. Se repitió audio en un proceso limpio, obteniendo 95/95, sin modificar la aserción. El runner ahora ordena audio antes de menús para respetar esa precondición. El consolidado utiliza los resultados reales de cada suite; no oculta la primera discrepancia.

Se conserva el aislamiento histórico de la apertura automática de la pantalla de victoria solo en suites mecánicas que necesitan continuar física. Menús/audio la prueban habilitada. La ruta larga de 4B conserva su fixture documentada de 1000 puntos de vida, sin aumentar stamina ni apagar soldados; el reintento de 4B y aggro comprueban muerte/reaparición con valores normales. La preparación del descanso espera suelo/área como ya estaba documentado; no se debilitan expectativas.

## Cobertura de los puntos de validación solicitados

| Punto | Evidencia y alcance |
|---|---|
| Inicio y menú | Release normal y extraído, inspección visual; menús automatizados sobre PCK |
| Nueva partida y nivel integrado | Release normal/extraído; suites 5B y 4B |
| Tutorial | Panel observado en Release; progresión/acciones y conservación tras muerte en 5A |
| Movimiento y cámara | Pruebas físicas del recorrido PCK; evaluación continua manual pendiente |
| Soldados y aggro persistente | Recorrido 4B y 38 contratos de aggro, componentes reales del PCK |
| Hoguera y checkpoint | Encendido por F observado en Release; descanso/restauración/reintento en PCK |
| Estus | HUD observado; consumo diferido, pausa y recuperación en PCK |
| Acceso al jefe y dos fases | Recorrido integrado 4B y suite 3C sobre PCK |
| Muerte y reintento | Suite de reintento 4B y aggro sobre PCK |
| Victoria | Daño/flags/HUD y pantalla final en suites 3C, 4B y 5B sobre PCK |
| Pausa y opciones | Interacción directa Release; congelación de relojes y buses verificada sobre PCK |
| Reinicio | Confirmación observada en copia extraída; limpieza de sesión en PCK |
| Salida | Botón Salir en Release y cierre de copia extraída |
| Preferencias | Valor 95 conservado tras cierre/reapertura real; después restaurado a 100 |

## Métricas observadas

- Equipo: AMD Ryzen 5 3450U with Radeon Vega Mobile Gfx, 8 procesadores lógicos. Gráfica AMD Radeon integrada, OpenGL 3.3, Compatibility.
- SO informado por Godot: `Windows 10.0.26200` (API Windows/build 26200).
- Memoria física informada: 6,323,187,712 bytes, aproximadamente 5.89 GiB. No es el equipo objetivo de 4 GB.
- Copia extraída: primer PNG del menú a los **2.51 s**, desde el lanzamiento; incluye render, codificación e I/O. Captura automática de tres frames y salida en 2.98 s. No es una medición exacta de disponibilidad interactiva.
- Durante esa captura de menú: working set máximo muestreado 231.7 MiB; private bytes máximos 194.6 MiB.
- Bosque inicial, copia Release extraída y detenida en su posición: ocho muestras de working set entre **176.9 y 197.3 MiB**, con pico de proceso informado por Windows de 297.7 MiB y private bytes de 388.0 MiB. Estas medidas no incluyen toda la memoria gráfica/sistema ni el máximo de todo el recorrido.
- Se observaron 14 muestras consecutivas de **59–61 FPS, mediana 60**, estando quieto en el bosque inicial. El registro completo incluye carga, menús y pausa; no es una garantía de 60 FPS en combate, jefe o hardware escolar.

La captura produjo `startup.wav` como auxiliar silencioso de Movie Maker; está solo en tests, no es un recurso del músico ni forma parte del paquete. No hay audio artístico definitivo asignado y no se evaluó calidad sonora.

## Errores, advertencias y límites pendientes

Los logs finales de exportación, Release normal, reinicio, copia extraída, arranque y PCK no contienen errores de parser/runtime. Permanecen documentadas las dos incidencias del harness: escena externa bloqueada por la plantilla y contador de audio que requería proceso limpio.

El límite de uso interrumpió antes una lectura de métricas: la revisión automática no llegó a autorizarla por agotamiento de cuota, no por considerarla insegura. La continuación ejecutó esa medición correctamente. No se instaló software ni se alteró la seguridad del sistema.

Quedan pendientes una partida manual completa en el Release, joystick físico, prueba en otra PC, medición prolongada en el equipo escolar de 4 GB, personajes/animaciones finales y audio definitivo. Las primitivas, materiales y volúmenes de depuración siguen visibles. El panel de opciones se observó alineado a la izquierda; sus controles permanecen legibles y funcionales y no se alteró la UI en esta fase.

No se cambiaron mecánicas, daño, IA, modelos o pruebas históricas. La comparación SHA-256 encontró **515 archivos jugables intactos**, incluido project.godot. Solo se actualizó el preset de exportación y se añadieron salida/documentación/herramientas de verificación.

## Estado final

F5 fue verificado iniciando en el menú principal y F6 en la arena artística antes de exportar. El editor se restauró abierto en `ruins_boss_arena.tscn`; ambos accesos conservan sus configuraciones. Los archivos de desarrollo no son necesarios para ejecutar el paquete.

Entregables: `soulgameexported/Unnamed Souls.exe`, `soulgameexported/Unnamed Souls.rar`, README, licencias y SHA256SUMS; histórico conservado. Evidencias, manifiestos y resultados en `tests/phase_6b/`. No se avanza a otra fase.
