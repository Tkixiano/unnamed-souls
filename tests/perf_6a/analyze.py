from pathlib import Path
import json,statistics as st,collections
p=Path('tests/perf_6a');summary={}
for variant in ['baseline','optimized']:
 capture='reuse_only' if variant=='optimized' else 'baseline'
 d=json.loads((p/(capture+'_results.json')).read_text());c=json.loads((p/(capture+'_cpu.json')).read_text());assert not d['failures'] and c['ended']
 grouped=collections.defaultdict(list)
 for x in c['samples']:grouped[x['label']].append(x)
 cpu={k:100*sum(x['cpu_s'] for x in v)/sum(x['wall_s'] for x in v) for k,v in grouped.items()}
 out={}
 for count,blocked in [(0,False),(1,False),(2,False),(2,True)]:
  label=str(count)+('_blocked' if blocked else '_chase');raw=[x for x in d['samples'] if not x['profiled'] and x['aggro_count']==count and x['blocked']==blocked];profiles=[x for x in d['samples'] if x['profiled'] and x['aggro_count']==count and x['blocked']==blocked]
  cv=[cpu[x['label']] for x in raw]
  row={'cpu_one_core_percent_median':st.median(cv),'cpu_machine_percent_median':st.median(cv)/c['logical_cpus'],'cpu_one_core_range':[min(cv),max(cv)],'cpu_trials':cv}
  for metric,kind in [('ai_total','_physics_process_us'),('detection','can_detect_us'),('travel','can_travel_us'),('actor_total','actor_physics_us'),('move_and_slide','move_and_slide_us')]:
   # Each profile sees two soldiers with the same number of callbacks.
   vals=[sum(a['ai' if metric in ['ai_total','detection','travel'] else 'actor'].get(kind,0) for a in x['actors'])/sum(a['ai']['_physics_process_calls'] for a in x['actors'])*2 for x in profiles]
   row[metric+'_us_per_tick_median']=st.median(vals)
  row['query_calls_per_tick']={}
  row['query_us_per_tick']={}
  for metric in ['shape','cast','ground','los']:
   row['query_calls_per_tick'][metric]=st.median(x['queries'].get(metric+'_calls',0)/(sum(a['ai']['_physics_process_calls'] for a in x['actors'])/2) for x in profiles)
   row['query_us_per_tick'][metric]=st.median(x['queries'].get(metric+'_us',0)/(sum(a['ai']['_physics_process_calls'] for a in x['actors'])/2) for x in profiles)
  row['parameter_allocations_per_physics_second']=st.median(sum(x['queries'].get(key,0) for key in ['capsule_allocations','shape_query_allocations','ray_query_allocations'])/(sum(a['ai']['_physics_process_calls'] for a in x['actors'])/2)*60 for x in profiles)
  for metric in ['fps','physics_ms','process_ms','objects','memory_static','physics_pairs']:
   vals=[v[metric] for x in raw for v in x['monitors']];row[metric+'_median']=st.median(vals);row[metric+'_range']=[min(vals),max(vals)]
  out[label]=row
 summary[variant]={'capture_prefix':capture,'hardware':{'processor':d['processor'],'logical_cpus':d['logical_cpus'],'physical_memory_bytes':d['system_memory']['physical']},'scenarios':out}
for filename,key in [('query_results.json','travel_micro'),('detection_results.json','detection_micro')]:
 d=json.loads((p/filename).read_text());rows=d.get('microbenchmark',d.get('samples'));summary[key]={}
 for blocked in [False,True]:
  r=[x for x in rows if x['blocked']==blocked];o=[x['times']['old_us_per_call'] for x in r];n=[x['times']['new_us_per_call'] for x in r]
  summary[key][str(blocked)]={'old_median':st.median(o),'new_median':st.median(n),'old_range':[min(o),max(o)],'new_range':[min(n),max(n)],'ratio_percent':(st.median(n)/st.median(o)-1)*100,'batches':len(r)}
(p/'analysis.json').write_text(json.dumps(summary,indent=2))
for variant in ['baseline','optimized']:
 print(variant)
 for k,v in summary[variant]['scenarios'].items(): print(k,'CPU',round(v['cpu_machine_percent_median'],2),'range onecore',list(map(lambda x:round(x,1),v['cpu_one_core_range'])),'AI',round(v['ai_total_us_per_tick_median'],2),'travel',round(v['travel_us_per_tick_median'],2),'physical',round(v['actor_total_us_per_tick_median'],2),'move',round(v['move_and_slide_us_per_tick_median'],2),'physicsframe',round(v['physics_ms_median'],3),'fps',v['fps_median'],'alloc',v['parameter_allocations_per_physics_second'])
