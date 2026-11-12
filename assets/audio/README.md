# Entrega de audio — integración pendiente

No hay archivos de sonido artístico asignados. No se requieren archivos de relleno.

Colocar archivos reales del músico en `music/`, `sfx/` o `ambient/`. Godot importa WAV (preferentemente PCM), Ogg Vorbis y MP3 sin complementos. Revisar el audio antes de asignarlo; no se ha evaluado mezcla ni calidad sonora.

Abrir `res://resources/audio/game_audio_catalog.tres` en Godot, expandir `cues`, buscar el `id` y arrastrar el AudioStream importado a `stream`. Los nombres de archivo quedan a elección del músico: no hay rutas de audio ficticias en los scripts.

Cada entrada permite ajustar ganancia, pitch, loop, distancia y unidad de atenuación. Music usa el bus Music, efectos el SFX y ambientes el Ambient; todos envían a Master. Los volúmenes del menú se conservan independientemente de las ganancias de cada cue.

El catálogo contiene cinco contextos musicales: music_menu, music_level, music_boss_1, music_boss_2 y music_victory. Los cuatro primeros repiten; victoria no repite por defecto. Se usan copias de los streams, sin cambiar los originales.

Ambiente: ambient_forest y ambient_wind globales; ambient_ruins y ambient_bonfire posicionales. Los bucles deben entregarse preparados para repetición; los archivos originales no son reparados ni normalizados automáticamente.

Efectos: ver la lista completa de IDs y sus señales en `tests/phase_5c_results.md`. Los pasos tienen cadencia provisional sin animaciones. La futura animación podrá llamar `SceneAudioBridge.emit_footstep()` después de desactivar `AudioDirector.approximate_footsteps`.

Los clips nulos son silencio intencional; no se acumulan solicitudes para reproducirlas después. Reiniciar F5 tras asignar recursos y verificar F6, pausa, cambio de fase, distancias, picos y mezcla en hardware real. No se incluye audio descargado o generado para reemplazar al músico.
