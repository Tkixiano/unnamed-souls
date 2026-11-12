# Fase 4A — Integración de escenario, materiales y recursos 3D
Fecha: 10 de noviembre de 2026. Godot 4.6.3-stable oficial; Compatibility; 1280 × 720; física 60 Hz. Trabajo realizado exclusivamente mediante Godot AI MCP para inspección, generación y ejecución dentro del motor. No se utilizó Blender ni Blender MCP.

## Alcance y archivos inspeccionados
Se verificaron mediante MCP la sesión existente, todas las PackedScene registradas (20 al iniciar, incluidos cinco GLB), ambas arenas técnicas, player, soldado, jefe, hoguera, cámara, HUD y selector. Se leyeron las referencias y APIs de Player/ActionState, AttackController, defensa/críticos, checkpoint, AI y suites históricas. La auditoría de modelos recorrió MeshInstance3D, superficies, AABB transformadas, materiales, texturas y colisiones. Datos detallados: phase_4a_asset_audit.json.

## Clasificación inicial
| Recurso real | Geometría original | Clasificación inicial | Resultado |
|---|---:|---|---|
| assets/models/escenario 1.glb | 982 mallas, 1069 superficies, 3.150.051 triángulos | REQUIERE AJUSTES y MATERIAL PROVISIONAL | Sector aprovechable de bosque/ruina y suelo separado en dry_forest.tscn. |
| assets/models/Arena_del_jefe.glb | 321.618 triángulos | REQUIERE AJUSTES | Texturas válidas; escala, orientación, malla derivada y colisión estática. |
| assets/models/hoguera.glb | 355.720 triángulos | REQUIERE AJUSTES | Visual derivado aplicado al contrato Bonfire existente. |
| assets/models/Roca_decorativa.glb | 95.128 triángulos | REQUIERE AJUSTES | Escena reutilizable con proxy de colisión simple. |
| assets/models/Frasco_Estus.glb | 127.050 triángulos | REQUIERE AJUSTES | Escena visual reutilizable de 0,25 m de altura, aún sin conectar a una animación. |

Los cinco recursos están presentes y cargan en Godot. Ninguno traía CollisionShape3D. No se encontraron slots nulos en los GLB, pero numerosos materiales del mapa eran blancos sin textura; una asignación existente no equivale a un material artístico terminado. El mapa contiene 156 recursos de material.

Las extensiones originales extremas del mapa eran aproximadamente 28.417 × 33.735 × 73.289 unidades, con partes orientadas en XY y otras en XZ, escalas incompatibles, cielos duplicados y piezas muy desplazadas. No se trató como un nivel listo para jugar.

## Partes excluidas y cambios de distribución
Se conserva un subconjunto explícito de 141 mallas fuente: 12 árboles exteriores, piezas de un sector coherente de ruinas y el plano de suelo identificado por Tierra. El detalle de cada inclusión/exclusión está en asset_audit.integration. No se recrearon estructuras complejas sustitutivas.

Los árboles/ruinas retenidos mantienen posiciones horizontales y orientación relativa del conjunto con escala uniforme 0,2. Se corrige la altura de apoyo de los árboles; se excluyen duplicados centrales para dejar un corredor practicable. El suelo XY usa rotación -90° sobre X y escala 0,012, centrado independientemente porque no compartía las unidades de las construcciones.

NO UTILIZABLE temporalmente dentro de este recorrido: fragmentos de montañas/terreno desplazados o desorientados y cielos duplicados. Permanecen intactos en el GLB, pero no se cargan en el nivel derivado. Las montañas originales no se presentan como integradas correctamente. Su normalización final requiere una entrega artística coherente o revisión específica posterior. Esto aplica la alternativa de utilizar solo partes aprovechables del mapa.

## Materiales y texturas
Se generaron StandardMaterial3D compartidos en resources/environment_4a:
stone, earth, sand, bark, wood, rust, ruins, ash, mountain y dark (.tres).
Albedos apagados, roughness 0,95; rust tiene metallic 0,15. Sin shaders complejos, efectos volumétricos o sombras dinámicas.

Se usan overrides/materiales derivados según nombre y geometría: Holz/Madera para madera, Stahl para metal envejecido, Fenster para huecos oscuros, Dach para cubierta y piedra provisional para el sector de ruina. Los recursos sin textura se consideran soluciones provisionales de color uniforme, no recuperación de una textura UV original. No se inventaron detalles pictóricos.

Los materiales artísticos texturizados se conservan en copias, con las mismas UV/mapas y propiedades; se extraen sus texturas a recursos independientes y se limita su tamaño a 1024 px con mipmaps. Las imágenes originales no se sobrescriben. Las escenas derivadas no dependen de subrecursos GLB que obliguen a cargar el mapa completo. El análisis de dependencias registró 258 recursos, cero referencias rotas y cero GLB originales cargados como dependencias.

## Geometría derivada no destructiva
La densidad original era desproporcionada para props pequeños y el objetivo de RAM. Se utilizó ImporterMesh.generate_lods en Godot, se eligieron índices reducidos y se compactaron vértices con SurfaceTool, guardando nuevas mallas .res. No hay reducción durante la partida ni cambios a los GLB.

| Modelo | Triángulos derivados |
|---|---:|
| Arena | 10.044 |
| Hoguera | 3.400 |
| Roca | 1.486 |
| Estus | 1.984 |

Los 145 recursos de malla generados suman 65.098 triángulos frente a 1.905.132 de sus fuentes seleccionadas. El bosque derivado suma 48.184; las instancias repetidas añaden su coste visible por instancia. Esta reducción cuantitativa no sustituye una evaluación visual cercana de todos los detalles; puede perder detalle fino.

## Escenas y archivos nuevos
- scenes/environment/dry_forest.tscn: bosque y ruinas seleccionados, suelo y límites.
- scenes/environment/ruins_arena.tscn: arena artística normalizada.
- scenes/environment/bonfire_visual.tscn e integrated_bonfire.tscn: visual y hoguera funcional reutilizada.
- scenes/environment/decorative_rock.tscn y rock_prop.tscn: visual y proxy físico.
- scenes/environment/estus_visual.tscn: frasco preparado para futura animación.
- scenes/levels/main_level.tscn: recorrido completo con un solo jugador.
- scenes/levels/ruins_boss_arena.tscn: acceso directo al encuentro artístico.
- scripts/systems/integrated_level.gd: presentación de indicaciones por sector; extiende el script de arena existente.
- resources/environment_4a/: materiales, mallas y texturas derivados.
- tests/phase_4a_pipeline.gd y phase_4a_level_builder.gd: utilidades de generación fuera del flujo de juego.
- tests/phase_4a_checks.gd, phase_4a_regressions.gd, JSON de auditoría/resultados y este informe.

Modificados: scripts/systems/arena_selector.gd y scenes/ui/arena_selector.tscn para añadir Nivel integrado y enlazar la arena artística; README.md para acceso/documentación. Las arenas técnicas originales se conservan. No se modifican PlayerController, ActionState, atributos, IA, hit/hurtboxes ni tiempos/perfiles de ataque, esquiva, defensa o Estus.

## Recorrido y conexión
Hoguera inicial (0/2,0,20) → tutorial (z≈12) → primer soldado (z≈1) → camino/segundo soldado (z≈-14) → hoguera de acceso (z≈-32) → arco → jefe (centro de arena z=-48, aparición del jefe z=-51).

Todo vive en la misma escena. Cruzar el arco no cambia de SceneTree ni duplica al protagonista: se conservan vida, stamina, Estus, empuñadura, checkpoint activo y memoria de victoria. La arena independiente se conserva para F6. F5 abre el selector con Nivel integrado, arena técnica y jefe artístico.

No hay mundo abierto ni tutorial complejo. Un muñeco permite practicar lock-on/ataques, y las indicaciones del HUD explican movimiento, bloqueo, rodada y parry en los sectores despejados. Solo se usan los dos soldados existentes, con la IA de persecución directa sin navegación avanzada. Los cuerpos derrotados conservan colisión: el recorrido permite rodearlos. Las ruinas se mantienen fuera del corredor principal.

La meta de 15–25 minutos no está validada: este recorrido es una base demostrable y no se afirma que tenga esa duración. Se necesita evaluación manual y diseño de progresión para medirla.

## Colisiones y cámara
Suelo/límites, puente de conexión y fragmentos bajos sólidos de ruina utilizan cajas. Árboles y rocas usan proxies cilíndricos sencillos, sin colisión detallada de ramas o pequeños ornamentos. La arena es una única malla de suelo/muros/arco: se utiliza ConcavePolygonShape3D estática derivada (~10k triángulos), justificada por su geometría inseparable.

Se verificó por raycasts el corredor desde z=20 hasta el centro/sector norte de la arena. El terreno de la arena se normaliza a y≈0 con desniveles centrales inferiores a 0,3 m en las muestras. El acceso se recorre por física real, sin teletransporte. La cámara mantiene SpringArm y su exclusión del protagonista; las paredes/proxies participan en World.

El punto inicial se retiró del límite trasero para que el SpringArm no quedara excesivamente contraído al arrancar. No se alteró sensibilidad, FOV, locomoción o gravedad. La advertencia de área del jefe se elevó a 0,16 m para verse sobre el relieve del nuevo suelo; no cambia la ventana ni la zona de daño.

## Hogueras, Estus y reintento
Se sustituye solo Visual: permanecen Bonfire, InteractionArea, RespawnPoint, Flame y su script. Los props primitivos de apoyo quedan ocultos. CheckpointManager sigue siendo el único coordinador, sin segundo sistema de hogueras. Descanso/restauración, cancelación, DEAD, YOU DIED y barrera de botones neutrales conservan sus reglas.

La hoguera inicial y la de acceso pueden activarse. Se restaura al jugador en la última activa y a los enemigos en las mismas instancias. El jefe vivo vuelve a 600 de vida/fase 1 sin hitboxes residuales. La derrota de jefe no se borra al descansar, volver al menú o recargar el nivel durante la sesión; no hay guardado en disco.

El frasco artístico está preparado con origen en su base y altura 0,25 m; se conserva la orientación importada. Para una fase posterior deberá adjuntarse a un socket de mano y mostrarse con señales/eventos de EstusController. No se reemplazó el frasco provisional del jugador ni se implementó beber/rigging/animaciones.

## Pruebas nuevas
Suite phase_4a_checks.gd: **64/64 aprobadas**, resultados en phase_4a_results.json. Mezcla consultas de componentes, eventos de acción simulados e integración física real:
- cinco importaciones, auditoría de materiales/dimensiones, hashes de originales;
- materiales del bosque, reducción, escenas reutilizables y protagonista único;
- suelo, límites, movimiento/frenado, órbita y contracción de cámara;
- hoguera, atributos/Estus/una mano, lock-on y desplazamiento fijado;
- daño único del ataque, combate autónomo, bloqueo y parry real de soldado, riposte;
- rodadas/i-frames, curación diferida y HUD;
- caminar por el tutorial/camino al acceso y atravesar el arco sin cambio de jugador;
- tres patrones de jefe, daño por golpe, fase 2 única, advertencia y evasión del área;
- muerte por contacto del área, reaparición en checkpoint de acceso, reset de jefe/soldados;
- victoria, pérdida de lock-on y ausencia de duplicación/reaparición de jefe derrotado;
- conservación del arranque F5 y existencia de escena directa F6.

En las fixtures de patrones se suspenden las decisiones automáticas del cerebro, pero actor, reloj de ataque, hurtbox, stamina y física siguen activos. Para medir todos los golpes se amplía temporalmente la vida del protagonista a 1000; luego se restituye 100 antes de la prueba letal. El encuentro autónomo y el reintento se prueban con las referencias reales. Para el test largo de recorrido se derrotan los soldados y se camina por un lateral libre; no se borran colliders ni se teletransporta durante el trayecto.

Primera pasada: 61/64. Se corrigieron la orientación de cámara de la fixture hacia el muro, el frente del muñeco para solicitar un ataque normal en lugar de un backstab, y la ruta que atravesaba un cadáver sólido. Una recarga de PackedScene desde caché conservaba el muñeco anterior; se reinició el proceso para verificar el archivo actualizado. La pasada final de 64/64 usa escena recién cargada. No se debilitaron reglas de combate.

## Regresiones
- **1A–3B: 590/590**, sin fallos en la pasada completa. Resultados por fase conservados en phase_4a_regressions.json.
- **3C: 72/73**. La única expectativa fallida es main_scene_configuration_preserved, que exige que la escena principal sea test_arena.tscn. El proyecto ya utilizaba el selector desde la tarea anterior; se conserva ese arranque. No es un fallo de patrones/daño/cámara/respawn, pero se informa como check no aprobado y no se presenta la suite como 73/73.
- La primera ejecución del wrapper entró a la fixture de adquisición antes de agotar el bloqueo inicial real de 1,5 s del jefe. Se corrigió solo la preparación del wrapper a 100 ticks antes de ejecutar run(), sin tocar la suite histórica; la repetición corrigió entry_starts_real_encounter_intro. El resultado previo y sus fallos quedan registrados en el JSON.
- No se sobrescribieron los resultados JSON ni los scripts de checks históricos.
- La comprobación de integridad final verificó **107 archivos** de modelos/texturas y componentes/perfiles de combate: **cero cambios** (phase_4a_integrity.json).

Los checks históricos se ejecutan sin modificar sus archivos. El wrapper nuevo llama run() de 3C para no sobrescribir su JSON histórico, y usa el runner existente para 1A–3B. Se conservan aislamientos explícitos históricos de toque corto, backstab, IA y restauración según contrato de cada suite. Estos resultados no se presentan como todos los sistemas habilitados simultáneamente en todas las fixtures.

## Revisión visual y rendimiento
Se revisaron capturas reales del menú a 1280 × 720 (cuatro opciones y pie dentro del viewport), bosque/hoguera/rocas, encuentro en la arena con lock-on, fase 2 con advertencia y frasco preparado. Evidencia en tests/phase_4a_evidence/ (excluida de importación con .gdignore).

Las tomas del jefe utilizan posicionamiento técnico del protagonista y espera de decisión prolongada. Para capturar el startup del área se detuvieron únicamente el actor jefe y su cerebro después de solicitar el patrón; no se utiliza esa captura como prueba temporal. La vista del frasco es una previsualización aislada con cámara temporal. Todos los ajustes se descartan al detener el proceso.

**Observación de rendimiento**, no benchmark completo: 10 muestras durante 5,006 s, posición inicial estacionaria del nivel integrado, 1280 × 720 y editor activo. Ryzen 5 3450U / AMD Radeon(TM) Graphics; memoria física informada por el sistema ≈6,32 GB. TIME_FPS entre 59 y 60 (media de muestras 59,6); 75.050 primitivas y 217 draw calls por frame en esa vista. Memoria estática monitorizada por Godot ≈94,2 MiB; texturas ≈52,7 MiB; vídeo ≈65,6 MiB. El monitor de memoria estática no representa toda la RAM del proceso/sistema.

Datos originales: phase_4a_performance.json. No se ensayaron todos los ángulos, combate prolongado, percentiles de tiempo de frame, carga fría exportada ni el equipo Ryzen 7 con 4 GB. **No se garantiza 60 FPS ni funcionamiento suficiente en 4 GB por esta muestra.** Falta prueba jugable manual y medición en el equipo escolar.

Los arranques finales revisados no contienen errores de parser/runtime del juego. Las pruebas son automatizadas o visuales estáticas; no hubo mando físico ni evaluación manual continua del game feeling.

## Problemas y limitaciones
- El mapa original no era una composición homogénea: se excluyen cielos/montañas y piezas desorientadas, con lista explícita.
- Se corrigieron errores de las herramientas de integración: consulta temporal de cámara inválida, ruta de objetivo del muñeco (el muñeco es el propio LockableTarget) y consulta de índices sobre BoxMesh en el test. No requirieron cambiar combate ni originales.
- Colisiones de árboles/ruinas aproximadas; ramas y ornamentos no son barreras exactas.
- IA directa, sin rodeos complejos. No se garantiza que todos los rincones del arte sirvan como zona de pelea.
- El recorrido no acredita 15–25 minutos ni balance final.
- Las copias reducidas requieren evaluación visual y ajuste posterior si algún detalle es importante.
- Sin joystick físico ni ensayo USB/Bluetooth; las entradas verificadas son simuladas.
- Sin modelos/animaciones definitivas de actores, sin animación de beber, sin nuevas mecánicas RPG.
- No se generó una exportación Windows en esta fase. El preset que incluye todos los recursos puede empaquetar originales aunque no se carguen en juego; revisar empaquetado antes de distribución final.
- La documentación académica del 07/11 queda como corte histórico; no se reescribió para simular que 4A existía entonces.
No se avanzó automáticamente de fase.


## Comprobación final de entrega
Se ejecutó desde el editor la escena abierta ruins_boss_arena.tscn (equivalente a F6): jugador en suelo, vida/stamina 100, Estus 5; jefe IDLE con 600 de vida, fase 1, física/IA activas y hitbox ofensiva apagada; hoguera registrada. El log de esa ejecución no mostró errores ni warnings. Detalles: phase_4a_final_startup.json.

Se dejó el proceso detenido para no exponer al jugador mientras espera, con la arena integrada abierta para F6. application/run/main_scene sigue siendo arena_selector.tscn y F5 abre el selector. No se guardaron pausas, daño o esperas de las capturas en las escenas.
