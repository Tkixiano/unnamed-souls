from pathlib import Path
import json, re, statistics, hashlib

p = Path(__file__).resolve().parent
s = json.loads((p / 'analysis.json').read_text(encoding='utf-8'))
b = s['baseline']['scenarios']
a = s['optimized']['scenarios']
m = s['travel_micro']
d = s['detection_micro']
report = p / 'INFORME_AGGRO_RENDIMIENTO.md'
text = report.read_text(encoding='utf-8')
text = text.replace('distancia/cone/raycast', 'distancia/cono/raycast')
text = text.replace(' y evita reenviar geometría de cápsula idéntica', '')

def paragraph(start, replacement):
    global text
    text = re.sub(re.escape(start) + r'[^\n]+', lambda _: replacement, text)

paragraph('Los incrementos descriptivos',
    f"Los incrementos descriptivos de dos perseguidores sobre IDLE son +{b['2_chase']['cpu_machine_percent_median']-b['0_chase']['cpu_machine_percent_median']:.2f} puntos porcentuales antes y +{a['2_chase']['cpu_machine_percent_median']-a['0_chase']['cpu_machine_percent_median']:.2f} después. No son una estimación causal: las medianas de CPU no mejoran de forma consistente y sus intervalos varían ampliamente. No se demuestra ahorro de CPU global.")
paragraph('Los datos crudos de CPU',
    'Los datos crudos de CPU finales están en baseline_cpu.json y reuse_only_cpu.json; sus ventanas y monitores en baseline_results.json y reuse_only_results.json. reuse_only es copia exacta de candidate_*, la primera captura de reutilización y la implementación que se entrega. optimized_* / float_check_* conservan la pasada con chequeos flotantes descartada. capture_manifest.json registra esa selección; no se editan los valores capturados.')
paragraph('La IA adicional sobre IDLE',
    f"La IA adicional sobre IDLE para dos perseguidores fue {b['2_chase']['ai_total_us_per_tick_median']-b['0_chase']['ai_total_us_per_tick_median']:.2f} µs/tick antes y {a['2_chase']['ai_total_us_per_tick_median']-a['0_chase']['ai_total_us_per_tick_median']:.2f} después; bloqueados, {b['2_blocked']['ai_total_us_per_tick_median']-b['0_chase']['ai_total_us_per_tick_median']:.2f} y {a['2_blocked']['ai_total_us_per_tick_median']-a['0_chase']['ai_total_us_per_tick_median']:.2f}. No se demuestra reducción agregada con estos tiempos instrumentados; el ahorro local se comprueba por llamadas pareadas y asignaciones de recursos.")
paragraph('Los monitores del nivel completo',
    'Los monitores del nivel completo registraron física antes/después: ' + '; '.join(f"{k}: {b[k]['physics_ms_median']:.2f}/{a[k]['physics_ms_median']:.2f} ms" for k in b) + '. Son observaciones inclusivas del nivel y no una atribución causal a la optimización.')
paragraph('El sondeo de detecci',
    f"El sondeo de detección compara 20 lotes pareados de 300 llamadas por versión en el nivel real. Visión libre: {d['False']['old_median']:.2f}/{d['False']['new_median']:.2f} µs; pared: {d['True']['old_median']:.2f}/{d['True']['new_median']:.2f} µs. Las respuestas coinciden y el algoritmo de detección no cambia. Las variaciones temporales no se presentan como una mejora de detección.")
for key, label in [('False', 'Paso libre'), ('True', 'Paso bloqueado')]:
    row = m[key]
    text = re.sub(r'\| ' + label + r' \|[^\n]+',
                  f"| {label} | {row['old_median']:.2f} | {row['new_median']:.2f} | {row['ratio_percent']:.1f}% |", text)
q = json.loads((p / 'query_results.json').read_text(encoding='utf-8'))
wins, ratios = {}, {}
for blocked in [False, True]:
    pairs = [r['times'] for r in q['microbenchmark'] if r['blocked'] == blocked]
    wins[blocked] = sum(r['new_us_per_call'] < r['old_us_per_call'] for r in pairs)
    ratios[blocked] = statistics.median((1-r['new_us_per_call']/r['old_us_per_call'])*100 for r in pairs)
paragraph('La vía nueva fue',
    f"La vía nueva fue más rápida en {wins[False]}/10 pares libres y {wins[True]}/10 bloqueados. Las reducciones medianas por par fueron {ratios[False]:.1f}% y {ratios[True]:.1f}%; son una estadística distinta de dividir las medianas de las columnas. No equivalen a una ganancia porcentual del juego completo.")
paragraph('- Radio/altura', '- Radio y altura se asignan en cada consulta, igual que antes. No se omiten cambios de geometría por una comparación aproximada.')
minimum_fps = min(v['fps_range'][0] for group in [b,a] for v in group.values())
maximum_fps = max(v['fps_range'][1] for group in [b,a] for v in group.values())
paragraph('Las capturas son cortas',
    f'Las capturas son cortas y de depuración, en el equipo disponible. TIME_FPS tuvo mediana 60 con rango observado {minimum_fps:.0f}–{maximum_fps:.0f}; su contador de un segundo puede incluir preparación anterior a la ventana. Este rango no es un 1% low y no demuestra estabilidad a 60 FPS. Se requieren pruebas prolongadas y jugables en el equipo objetivo; no se certifica rendimiento de exportación ni con 4 GB.')
precision = ('Se ensayó omitir setters por igualdad directa, pero Godot devuelve radio=0,349999994 y altura=1,600000024 tras asignar 0,35/1,6. El chequeo no evitaba los setters y se descartó. Se entrega la reutilización simple ya medida; las comprobaciones afectadas se repitieron sobre ese código. No se atribuye ahorro a omitir setters. precision_probe.txt y capture_manifest.json conservan la evidencia y trazabilidad.')
if precision not in text:
    text = text.replace('Se evaluó bajar la frecuencia', precision + '\n\nSe evaluó bajar la frecuencia')

text += '\n## Incidencia del agregador de regresiones\n\n' if '## Incidencia del agregador' not in text else ''
if 'El primer agregador buscó' not in text:
    text += ('El primer agregador buscó el resultado 4A fuera de perf_6a y produjo null. El sondeo de estado accedió después a ese null. Se conservan integration_first_aggregate.json y harness_first_editor_log.json. Las aserciones de las suites ya habían terminado; el agregado se recuperó de sus JSON reales sin cambiar resultados ni expectativas. Se corrigieron las rutas del wrapper y se repitió 4A: confirm4a_results.json, 64/64. La incidencia pertenece al harness, no a la IA.\n')

historical = json.loads((p / 'perf6a_historical_regressions.json').read_text())
integration = json.loads((p / 'perf6a_integration_regressions.json').read_text())
native = json.loads((p / 'native_results.json').read_text())
total = sum(v['total'] for v in historical['historical']['results'].values()) + historical['3c']['total']
total += sum(integration[k]['total'] for k in ['4a','4b_checks','4b_spatial','4b_retry','5a_checks','5a_context_checks'])
total += sum(v['total'] for v in native.values())
assert total == 1082
for v in list(historical['historical']['results'].values()) + [historical['3c']] + [integration[k] for k in ['4a','4b_checks','4b_spatial','4b_retry','5a_checks','5a_context_checks']] + list(native.values()):
    assert v['passed'] == v['total'] and not v.get('failed', [])
if '## Verificación final consolidada' in text:
    text = text.split('## Verificación final consolidada')[0]
text += ('\n## Verificación final consolidada\n\n'
         '**13/13 contratos nuevos y 1082/1082 comprobaciones de regresión aprobados**, incluidos los 38 contratos de aggro persistente en el runner nativo. Las 450 comparaciones de consultas forman parte de uno de esos contratos; no se suman de nuevo. Tampoco se cuentan los launchers ni se suman resultados repetidos de fases anteriores.\n\n')
focus_path = p / 'final_focus_results.json'
if focus_path.exists():
    focus = json.loads(focus_path.read_text())
    assert focus['status'] == 'complete'
    values = [focus[k] for k in ['queries','detection','aggro','3c']] + list(focus['3a_3b']['results'].values())
    assert all(v['passed'] == v['total'] and not v.get('failed', []) for v in values)
    text += ('Después de retirar los chequeos flotantes se repitieron consultas, detección, aggro, soldado/checkpoints y jefe sobre el código final: **247/247** contratos (final_focus_results.json). Es una confirmación focalizada de cobertura ya contada, no un incremento de 247 pruebas distintas.\n\n')
baseline = json.loads((p / 'integrity_baseline.json').read_text())
changed = [f for f, digest in baseline.items() if hashlib.sha256(Path(f).read_bytes()).hexdigest() != digest]
assert set(changed) == {'scripts/enemies/soldier_ai.gd', 'scripts/enemies/enemy_world_queries.gd'}
(p / 'integrity.json').write_text(json.dumps({'checked':len(baseline),'changed':changed,'unchanged':len(baseline)-len(changed)}, indent=2))
text += f'Auditoría SHA-256: {len(baseline)} archivos jugables, únicamente los dos scripts de consultas/IA modificados; {len(baseline)-2} intactos. Ninguna prueba histórica se modificó en esta ampliación.\n'
logs = ['final_focus_game_log.json','f5_game_log.json','f6_game_log.json']
if all((p / name).exists() for name in logs):
    for name in logs:
        log = json.loads((p / name).read_text(encoding='utf-8-sig'))
        assert log.get('editor_errors_count',0) == 0
        assert not any(row.get('level') == 'error' for row in log.get('lines', []))
    text += ('\nF5 verificado mediante main: menú principal, foco Nueva partida y preferencias conservadas. '
             'F6 verificado mediante current con la arena artística abierta: protagonista en suelo, vida 100, cinco Estus, jefe con 600 de vida en fase 1. '
             'Los logs finales de esas ejecuciones y de la confirmación focalizada no registran errores del run. '
             'Las incidencias anteriores del harness se conservan separadas. El juego quedó detenido, con F5/F6 configurados como antes.\n')
report.write_text(text, encoding='utf-8')
print('Final report reconciled with captures and executed suites')
