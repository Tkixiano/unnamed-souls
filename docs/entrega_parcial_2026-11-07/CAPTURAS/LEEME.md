# Procedencia de las capturas

Capturadas el 7 de noviembre de 2026 por Godot AI MCP mediante game_eval, aguardando RenderingServer.frame_post_draw y guardando get_viewport().get_texture().get_image().save_png. Son framebuffer real de Godot a 1280 × 720, sin generación ni retoque. Se usó project_run con autosave=false; ninguna escena se guardó.

1. 01_selector.png: arranque principal, sin staging.
2. 02_hoguera_hud.png: inicio de test_arena, jugador (7,0,0), soldado IDLE, sin staging.
3. 03_soldado_lockon.png: jugador colocado en (0,0,-0.8), soldado en (0,0,-3.8), cámara ajustada por su API, lock-on try_acquire=true y target_id=arena_soldier. Actor y cerebro del soldado detenidos solo en memoria para encuadrar.
4. 04_arena_jefe.png: inicio de boss_arena sin staging.
5. 05_jefe_fase_1.png: jugador (0,0,-0.6), start_encounter aceptado, espera de decisión prolongada, captura después de INTRO; jefe 600, fase 1. Actor/IA detenidos en memoria.
6. 06_jefe_fase_2_area.png: actor/IA reactivados, daño técnico de 300, 90 ticks de física para la transición; transition_count=1, phase_two=true. start_pattern(RUIN_BURST) aceptado y warning visible; actor/IA detenidos en startup para fotografiar. Vida 300, sin daño de área aplicado en esta toma.

Las pausas de encuadre no se presentan como pruebas de física o experiencia jugable. El proceso se detuvo después para descartar todos los cambios. Los diagramas no son capturas y se guardan aparte. No se obtuvo evidencia nueva de YOU DIED en esta sesión documental; su validación se apoya en el informe histórico 3B, no en una imagen fabricada.
