from pathlib import Path
import json, re, html
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parents[1]
API = json.loads((OUT/'_verificacion/auditoria_api.json').read_text(encoding='utf-8'))
FONT = 'C:/Windows/Fonts/arial.ttf'
BOLD = 'C:/Windows/Fonts/arialbd.ttf'

def diagram(name, title, boxes, edges, size):
    im=Image.new('RGB',size,'white'); d=ImageDraw.Draw(im)
    svg=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{size[0]}" height="{size[1]}" viewBox="0 0 {size[0]} {size[1]}">', '<rect width="100%" height="100%" fill="white"/>']
    def text(x,y,s,bold=False,fs=23):
        d.text((x,y),s,font=ImageFont.truetype(BOLD if bold else FONT,fs),fill='#163148')
        svg.append(f'<text x="{x}" y="{y+fs}" font-family="Arial,sans-serif" font-size="{fs}" font-weight="{"bold" if bold else "normal"}" fill="#163148">{html.escape(s)}</text>')
    text(24,18,title,True,30)
    for points,label in edges:
        d.line(points,fill='#587287',width=3)
        pts=' '.join(f'{x},{y}' for x,y in points)
        svg.append(f'<polyline points="{pts}" fill="none" stroke="#587287" stroke-width="3"/>')
        x,y=points[-1]; px,py=points[-2]
        if abs(x-px)>abs(y-py):
            s=1 if x>px else -1; tri=[(x,y),(x-s*12,y-6),(x-s*12,y+6)]
        else:
            s=1 if y>py else -1;tri=[(x,y),(x-6,y-s*12),(x+6,y-s*12)]
        d.polygon(tri,fill='#587287');svg.append('<polygon points="'+' '.join(f'{a},{b}' for a,b in tri)+'" fill="#587287"/>')
        if False and label:
            a,b=points[len(points)//2]; text(a+6,b+5,label,False,19)
    for x,y,w,h,lines in boxes:
        d.rounded_rectangle((x,y,x+w,y+h),radius=8,fill='#edf3f6',outline='#345b73',width=2)
        svg.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" fill="#edf3f6" stroke="#345b73" stroke-width="2"/>')
        for n,line in enumerate(lines):
            fs=23 if n==0 else 21
            while ImageFont.truetype(BOLD if n==0 else FONT,fs).getlength(line)>w-28: fs-=1
            text(x+14,y+12+30*n,line,n==0,fs)
    im.save(OUT/'DIAGRAMAS'/f'{name}.png')
    (OUT/'DIAGRAMAS'/f'{name}.svg').write_text('\n'.join(svg+['</svg>']),encoding='utf-8')

diagram('01_componentes','Arquitectura compartida del prototipo',[
 (20,90,330,120,['Entrada e inventario','InputMap / ControllerRegistry','Selector: acceso a las arenas']),
 (435,90,330,120,['Actores físicos','PlayerController / SoldierActor','RuinsGuardian hereda soldado']),
 (850,90,330,120,['Decisiones de adversarios','SoldierAI / GuardianBrain','Percepción y patrones']),
 (20,335,330,150,['Cámara y fijación','LockOnController / objetivos','LockableTarget / CameraRig','SpringArm: colisión']),
 (435,335,330,150,['Acciones del protagonista','ActionState, Dodge, Defense','Riposte, Estus y Grip','Propiedad y exclusión mutua']),
 (850,335,330,150,['Ataque compartido','AttackController','AttackData / AttackVariant','Startup, Active, Recovery']),
 (20,610,330,140,['CheckpointManager','Bonfire: descanso y restauración','SessionProgress: derrota por ID','Memoria de sesión, sin disco']),
 (435,610,330,140,['ActorAttributes','Vida y stamina con límites','health_changed / stamina_changed','HUD de atributos por señales']),
 (850,610,330,140,['AttackHitbox / Hurtbox','Facciones y deduplicación','Defensa / i-frames / crítico','Único descuento final de vida'])
], [([(350,150),(435,150)],''), ([(850,150),(765,150)],''), ([(600,210),(600,335)],'coordina'),
 ([(1015,210),(1015,335)],'solicita'), ([(185,335),(185,270),(465,270),(465,210)],'base y ángulos'),
 ([(765,410),(850,410)],'acción'), ([(600,485),(600,610)],'costes'), ([(1015,485),(1015,610)],'ACTIVE'),
 ([(850,680),(765,680)],'daño'), ([(350,680),(435,680)],'restore_all'),
 ([(80,610),(80,530),(410,530),(410,195),(435,195)],'reset')], (1200,795))

left=[['AttackHitbox: ACTIVE','Consulta por swing y actor'],['Hurtbox: identidad y facción','Rechaza inválidos / aliados'],['Pareja crítica / i-frames','Rechazo o evasión sin vida perdida'],['Crítico: token autorizado','O defensa: parry / bloqueo / rotura'],['ActorAttributes.apply_damage','Una sola aplicación de vida'],['Señales de impacto / muerte','HUD, reacción e invalidación']]
right=[['Vida llega a cero','ActionState: DEAD'],['Cancelación de acciones','Hitboxes, buffers y lock-on limpios'],['CheckpointManager','Retraso 0,60 s y YOU DIED 2 s'],['Ocultar overlay antes de revivir','Restore de enemigos y protagonista'],['FREE, atributos y Estus completos','Una mano, cámara y posición'],['Esperar neutral de botones','Reintento; jefe vencido no revive']]
boxes=[];edges=[]
for col,rows in enumerate([left,right]):
 x=25+col*600
 for i,lines in enumerate(rows):
  y=105+i*120;boxes.append((x,y,550,85,lines))
  if i<5: edges.append(([(x+275,y+85),(x+275,y+120)],''))
diagram('02_flujos','Resolución de impactos y ciclo de reaparición',boxes,edges,(1200,825))

(OUT/'DIAGRAMAS/01_componentes.mmd').write_text('''flowchart TD
  I[InputMap y ControllerRegistry] --> P[PlayerController]
  AI[SoldierAI o GuardianBrain] --> S[SoldierActor o RuinsGuardian]
  P --> AS[ActionState y componentes de acción]
  P --> AC[AttackController]
  S --> AC
  DATA[AttackData y AttackVariant] --> AC
  AC --> HB[AttackHitbox]
  HB --> HU[Hurtbox]
  HU --> DF[DefenseController / crítico / i-frames]
  DF --> AT[ActorAttributes]
  AT --> HUD[HUD por señales]
  LO[LockOnController y LockableTarget] --> P
  LO --> CAM[CameraRig y SpringArm]
  CP[CheckpointManager y Bonfire] --> P
  CP --> S
  S --> SS[SessionProgress: ID derrotado]
''',encoding='utf-8')
(OUT/'DIAGRAMAS/02_flujos.mmd').write_text('''flowchart TD
  A[ACTIVE: consulta Hitbox] --> B{Identidad y facción válidas}
  B -- No --> X[Sin impacto]
  B -- Sí --> C{Pareja crítica o i-frames}
  C -- Protegido --> X
  C -- Disponible --> D[Crítico autenticado o defensa por contacto]
  D --> E[Único apply_damage de Hurtbox hacia atributos]
  E --> F{Vida cero}
  F -- Sí --> G[DEAD cancela acciones y lock-on]
  G --> H[DEATH_DELAY: 0,60 s]
  H --> J[YOU DIED: 2 s]
  J --> K[Ocultar overlay y restaurar en otro tick]
  K --> L[FREE y espera de botones neutrales]
''',encoding='utf-8')

reg=json.loads((ROOT/'tests/phase_3c_regressions.json').read_text(encoding='utf-8'))
new=json.loads((ROOT/'tests/phase_3c_results.json').read_text(encoding='utf-8'))
rows=reg['historical']['results']
an=['# Anexo técnico del informe parcial','', 'Corte: 7 de noviembre de 2026. Rutas relativas a la raíz del proyecto. La nomenclatura descriptiva de componentes no implica que todos los scripts declaren class_name. No se crearon clases ni sistemas nuevos.','',
'## 1. Configuración comprobada','',
'Godot 4.6.3-stable oficial; GDScript; Compatibility/gl_compatibility; Jolt Physics; física efectiva 60 Hz; interpolación activada; viewport 1280 × 720; arranque arena_selector. Autoloads: ControllerRegistry y helper de Godot AI. Hay 21 acciones propias en InputMap. No hay guardado de partida.','',
'El preset Windows Desktop existente usa x86_64 e incluye todos los recursos. No se ejecutó una exportación en esta auditoría ni se ensayó un binario externo. Revisar los metadatos de publicación del preset: sus valores no deben tomarse como identidad institucional ni nombre del equipo.','',
'## 2. Escenas y dependencias','',
'- arena_selector referencia PackedScene de test_arena y boss_arena. ArenaMenuLink es navegación opcional con ruta configurable al selector.','- test_arena compone Player, Soldier, objetivos de entrenamiento y actor técnico; cámara/lock-on; hoguera/checkpoint; HUD y DeathScreen.','- boss_arena instancia el mismo Player, cámara y servicios de ciclo, además de Boss, EncounterEntry y BossHUD.','- ruins_guardian hereda soldier.tscn; mantiene el nodo SoldierAI con guardian_brain.gd para conservar el protocolo del actor.','- La escena player asigna scripts/combat/defense_controller.gd, no scripts/player/defense_controller.gd. Este último archivo también existe, pero no se encontró una referencia activa a él en escenas o preloads del juego: no se le atribuye funcionalidad operativa adicional.','',
'## 3. Reglas y orden de integración','',
'PlayerController procesa solicitudes en física: cambio de empuñadura, defensa, Estus, esquiva y ataque. Los propietarios de estado impiden iniciar acciones incompatibles. El actor conserva el único move_and_slide.','',
'Prioridad contextual del ataque ligero: riposte, backstab, LIGHT_1. Los críticos comparten ejecutor/reserva; el token admite un único daño. La stamina se consulta antes de reclamar acción y se consume una vez; el gasto de carrera es continuo.','',
'Hurtbox valida identidad/facción, protección de pareja crítica, disponibilidad e i-frames, token o defensa, y descuenta vida una sola vez. AttackHitbox reserva al actor antes de callbacks. Un contacto evadido no se consume: si ACTIVE continúa al terminar la invulnerabilidad puede impactar.','',
'DEAD=7 y SWITCHING_GRIP=8; las incorporaciones preservaron los IDs anteriores. La muerte cancela acciones; solo un reset explícito puede volver desde DEAD. El checkpoint devuelve ONE_HANDED y bloquea acciones hasta neutral.','',
'## 4. Índice de APIs auditadas','',
'Cada entrada enumera métodos públicos encontrados en la fuente; no implica que todos tengan una prueba independiente. Para firmas completas y dependencias consultar _verificacion/auditoria_api.json.','']
for path,v in sorted(API.items()):
 methods=[m.split(' ->')[0].rstrip(':') for m in v['methods'] if not m.startswith('_')]
 an.extend([f'### {path}',f"Hereda: `{', '.join(v['extends'])}`."])
 an.append('APIs públicas: '+('; '.join('`'+m+'`' for m in methods) if methods else 'sin métodos públicos adicionales; callbacks del motor.') )
 if v['signals']:an.append('Señales: '+', '.join('`'+x+'`' for x in v['signals'])+'.')
 if v['dependencies']:an.append('Referencias de carga: '+', '.join('`'+x+'`' for x in v['dependencies'])+'.')
 an.append('')
an.extend(['## 5. Matriz de pruebas históricas','', '| Fase | Aprobadas/total en regresión final 3C | Fallos finales |','|---|---:|---|'])
for phase,r in rows.items(): an.append(f"| {phase.upper()} | {int(r['passed'])}/{int(r['total'])} | {', '.join(r['failed']) or 'Ninguno'} |")
an.extend(['',f"Suma dentro de una sola pasada histórica: {sum(int(r['passed']) for r in rows.values())}/590. Suite nueva 3C: {int(new['passed'])}/{int(new['total'])}. No sumar columnas de regresiones entre fases.", '',
'### Checks nuevos de 3C',''])
for key,val in new['checks'].items(): an.append(f'- {key}: {"aprobado" if val else "falló"}.')
an.extend(['','### Aislamientos y compatibilidad de expectativas','',
'Listener corto aislado en 1B/1D/2A; adquisición de backstab aislada en 2C; IA normal apartada de fixtures anteriores a 3A; ciclo automático de checkpoint aislado cuando las suites esperan DEAD terminal. Se mantienen casos integrados con componentes activos. Ver informes originales para cada contrato.','',
'El selector posterior cambia intencionalmente application/run/main_scene. El check main_scene_configuration_preserved de 3C aún exige test_arena. El resultado 73/73 corresponde al cierre de 3C antes de ese cambio; no certifica que la suite sin adaptar pase actualmente. No se modificaron los tests históricos en esta auditoría.','',
'No se reejecutaron suites que escriben JSON en tests/, para preservar íntegros los informes históricos. La verificación actual se limitó a arranques, consultas de configuración, estados de captura y logs.','',
'## 6. Parámetros y recursos','',
'Los valores detallados de marcha, cámara, esquivas, ataques, defensa, críticos, Estus y jefe constan en el informe principal. Los datos de ataques son .tres; se pueden revisar sin reescribir ejecutores. No son valores medidos de Dark Souls.','',
'### Inventario de escenas y recursos',''])
for folder,ext in [('scenes','*.tscn'),('resources','*.tres')]:
 for p in sorted((ROOT/folder).rglob(ext)):an.append('- '+p.relative_to(ROOT).as_posix())
an.extend(['','## 7. Evidencia gráfica y trazabilidad','',
'Ver CAPTURAS/LEEME.md para método de captura y staging. Las originales no se retocaron. Los diagramas son representaciones documentales, identificados como D1 y D2; no son capturas del motor.','',
'_verificacion/hashes_antes.json registra los archivos protegidos; la comparación final queda en _verificacion/validacion_final.json. Los scripts de generación están dentro de la entrega excluida de Godot. Las previsualizaciones del PDF son solo material de QA.','',
'## 8. Observaciones que requieren completar o verificar','',
'- No se encontraron .blend, .glb, .gltf, modelos externos ni audio dentro de assets. No se infiere que el equipo no trabaje en ellos fuera de esta carpeta.','- No se encontró un tutorial o recorrido completo integrado. El menú actual es un selector técnico, no una interfaz final.','- No se midieron gráficos integrados/4 GB, ni se probó joystick físico o distribución Windows final.','- scripts/player/player_controller.gd y action_state.gd conservan comentarios iniciales de fases anteriores que no describen todas las dependencias actuales; la auditoría usa el código efectivo y referencias de escena.','- README contiene párrafos históricos sobre F5 y ausencia de sistemas posteriores. Prevalece su apartado actual del selector y la configuración real.','- Falta completar identidades académicas y responsabilidades del equipo; Fase 4A no iniciada.',''])
(OUT/'ANEXO_TECNICO.md').write_text('\n\n'.join(an),encoding='utf-8')
(OUT/'CAPTURAS/LEEME.md').write_text('''# Procedencia de las capturas

Capturadas el 7 de noviembre de 2026 por Godot AI MCP mediante game_eval, aguardando RenderingServer.frame_post_draw y guardando get_viewport().get_texture().get_image().save_png. Son framebuffer real de Godot a 1280 × 720, sin generación ni retoque. Se usó project_run con autosave=false; ninguna escena se guardó.

1. 01_selector.png: arranque principal, sin staging.
2. 02_hoguera_hud.png: inicio de test_arena, jugador (7,0,0), soldado IDLE, sin staging.
3. 03_soldado_lockon.png: jugador colocado en (0,0,-0.8), soldado en (0,0,-3.8), cámara ajustada por su API, lock-on try_acquire=true y target_id=arena_soldier. Actor y cerebro del soldado detenidos solo en memoria para encuadrar.
4. 04_arena_jefe.png: inicio de boss_arena sin staging.
5. 05_jefe_fase_1.png: jugador (0,0,-0.6), start_encounter aceptado, espera de decisión prolongada, captura después de INTRO; jefe 600, fase 1. Actor/IA detenidos en memoria.
6. 06_jefe_fase_2_area.png: actor/IA reactivados, daño técnico de 300, 90 ticks de física para la transición; transition_count=1, phase_two=true. start_pattern(RUIN_BURST) aceptado y warning visible; actor/IA detenidos en startup para fotografiar. Vida 300, sin daño de área aplicado en esta toma.

Las pausas de encuadre no se presentan como pruebas de física o experiencia jugable. El proceso se detuvo después para descartar todos los cambios. Los diagramas no son capturas y se guardan aparte. No se obtuvo evidencia nueva de YOU DIED en esta sesión documental; su validación se apoya en el informe histórico 3B, no en una imagen fabricada.
''',encoding='utf-8')
print('Annex, diagrams and capture provenance generated.')
