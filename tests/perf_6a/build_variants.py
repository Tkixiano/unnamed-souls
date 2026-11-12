from pathlib import Path
p=Path('tests/perf_6a')
for variant in ['baseline','optimized']:
 source=Path('scripts/enemies')
 q=(p/'baseline_enemy_world_queries.gd').read_text() if variant=='baseline' else (source/'enemy_world_queries.gd').read_text()
 # Uninstrumented baseline keeps its own immutable query dependency.
 ai=(p/'baseline_soldier_ai.gd').read_text() if variant=='baseline' else (source/'soldier_ai.gd').read_text()
 ai=ai.replace('res://scripts/enemies/enemy_world_queries.gd',f'res://tests/perf_6a/{variant}_queries_raw.gd')
 (p/f'{variant}_queries_raw.gd').write_text(q)
 (p/f'{variant}_ai_raw.gd').write_text(ai)
 q=q.replace('extends RefCounted','extends RefCounted\nstatic var stats: Dictionary = {}\nstatic func bump(key: String, value: int = 1) -> void:\n\tstats[key] = int(stats.get(key,0))+value',1)
 q=q.replace('space.intersect_shape(query,1)','timed_shape(space,query)').replace('space.cast_motion(query)','timed_cast(space,query)').replace('space.intersect_ray(ground)','timed_ray(space,ground,"ground")').replace('actor.get_world_3d().direct_space_state.intersect_ray(ray)','timed_ray(actor.get_world_3d().direct_space_state,ray,"los")')
 q=q.replace('CapsuleShape3D.new()','new_capsule()').replace('PhysicsShapeQueryParameters3D.new()','new_shape_query()').replace('PhysicsRayQueryParameters3D.create(','new_ray(').replace('PhysicsRayQueryParameters3D.new()','new_empty_ray()')
 q+='''
static func timed_shape(space: PhysicsDirectSpaceState3D, query: PhysicsShapeQueryParameters3D) -> Array[Dictionary]:
	var begin := Time.get_ticks_usec()
	var result := space.intersect_shape(query,1)
	bump("shape_us",Time.get_ticks_usec()-begin)
	bump("shape_calls")
	return result
static func timed_cast(space: PhysicsDirectSpaceState3D, query: PhysicsShapeQueryParameters3D) -> PackedFloat32Array:
	var begin := Time.get_ticks_usec()
	var result := space.cast_motion(query)
	bump("cast_us",Time.get_ticks_usec()-begin)
	bump("cast_calls")
	return result
static func timed_ray(space: PhysicsDirectSpaceState3D, query: PhysicsRayQueryParameters3D, kind: String) -> Dictionary:
	var begin := Time.get_ticks_usec()
	var result := space.intersect_ray(query)
	bump(kind+"_us",Time.get_ticks_usec()-begin)
	bump(kind+"_calls")
	return result
static func new_capsule() -> CapsuleShape3D:
	bump("capsule_allocations")
	return CapsuleShape3D.new()
static func new_shape_query() -> PhysicsShapeQueryParameters3D:
	bump("shape_query_allocations")
	return PhysicsShapeQueryParameters3D.new()
static func new_ray(a: Vector3,b: Vector3,mask: int,excluded: Array[RID]) -> PhysicsRayQueryParameters3D:
	bump("ray_query_allocations")
	return PhysicsRayQueryParameters3D.create(a,b,mask,excluded)
static func new_empty_ray() -> PhysicsRayQueryParameters3D:
	bump("ray_query_allocations")
	return PhysicsRayQueryParameters3D.new()
'''
 if 'class StepProbe:' in q:
  head,tail=q.split('static func has_sight',1)
  head=head.replace('new_capsule()','CapsuleShape3D.new()').replace('new_shape_query()','PhysicsShapeQueryParameters3D.new()').replace('new_empty_ray()','PhysicsRayQueryParameters3D.new()')
  q=head+'static func has_sight'+tail
 (p/f'{variant}_queries_profiled.gd').write_text(q)
 ai=ai.replace(f'{variant}_queries_raw.gd',f'{variant}_queries_profiled.gd')
 ai=ai.replace('extends Node','extends Node\nvar perf: Dictionary = {}\nfunc perf_add(key: String, value: int) -> void:\n\tperf[key] = int(perf.get(key,0))+value',1)
 for name,args,ret,call in [('_physics_process','delta: float','void','delta'),('can_detect','','bool',''),('can_travel','direction: Vector3','bool','direction')]:
  ai=ai.replace('func '+name+'(', 'func raw_'+name+'(',1)
  if ret=='void':body=f'\traw_{name}({call})\n'
  else: body=f'\tvar result: bool = raw_{name}({call})\n'
  ai+=f'\nfunc {name}({args}) -> {ret}:\n\tvar begin := Time.get_ticks_usec()\n'+body+f'\tperf_add("{name}_us",Time.get_ticks_usec()-begin)\n\tperf_add("{name}_calls",1)\n'+ ('\treturn result\n' if ret!='void' else '')
 (p/f'{variant}_ai_profiled.gd').write_text(ai)
actor=(p/'baseline_soldier_actor.gd').read_text()
actor=actor.replace('extends CharacterBody3D','extends CharacterBody3D\nvar perf: Dictionary = {}\nfunc perf_add(key: String, value: int) -> void:\n\tperf[key] = int(perf.get(key,0))+value',1).replace('func _physics_process(', 'func raw_physics(',1)
actor=actor.replace('\tmove_and_slide()','\tvar movement_begin := Time.get_ticks_usec()\n\tmove_and_slide()\n\tperf_add("move_and_slide_us",Time.get_ticks_usec()-movement_begin)\n\tperf_add("move_and_slide_calls",1)',1)
actor+='\nfunc _physics_process(delta: float) -> void:\n\tvar begin := Time.get_ticks_usec()\n\traw_physics(delta)\n\tperf_add("actor_physics_us",Time.get_ticks_usec()-begin)\n\tperf_add("actor_physics_calls",1)\n'
(p/'profiled_actor.gd').write_text(actor)
print('Benchmark variants generated; production untouched')
