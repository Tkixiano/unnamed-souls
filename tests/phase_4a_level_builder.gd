extends RefCounted
## Offline composition, preserving scene instances and existing combat.
var p: RefCounted
func add(root: Node, node: Node, name: String) -> Node:
	node.name = name
	root.add_child(node)
	node.owner = root
	return node
func own(node: Node, root: Node) -> void:
	for c in node.get_children():
		if c.owner == null: c.owner = root
		if c.owner == root: own(c,root)
func fire(root: Node3D, name: String, position: Vector3, manager: Node, id: StringName) -> Node3D:
	var node: Node3D = load("res://scenes/environment/integrated_bonfire.tscn").instantiate()
	add(root,node,name)
	node.position = position
	node.manager = manager
	node.bonfire_id = id
	return node
func build(tree: SceneTree) -> void:
	p = load("res://tests/phase_4a_pipeline.gd").new()
	p._make_materials()
	var base_fire: Node3D = load("res://scenes/props/bonfire.tscn").instantiate()
	base_fire.scene_file_path = ""
	for name in ["Ash","LogA","LogB","Sword"]: base_fire.get_node("Visual/"+name).visible = false
	var visual: Node3D = load("res://scenes/environment/bonfire_visual.tscn").instantiate()
	base_fire.get_node("Visual").add_child(visual)
	visual.owner = base_fire
	own(base_fire,base_fire)
	p._save_scene(base_fire,"res://scenes/environment/integrated_bonfire.tscn")
	base_fire.free()
	var rock: Node3D = load("res://scenes/environment/decorative_rock.tscn").instantiate()
	rock.scene_file_path = ""
	p._cylinder(rock,"SimpleCollision",Vector3(0,0.35,0),0.5,0.7)
	p._save_scene(rock,"res://scenes/environment/rock_prop.tscn")
	rock.free()
	for full in [false,true]:
		var root: Node3D = load("res://scenes/levels/boss_arena.tscn").instantiate()
		root.scene_file_path = ""
		root.name = "DryForestLevel" if full else "IntegratedBossArena"
		root.set_script(load("res://scripts/systems/integrated_level.gd"))
		root.direct_boss_test = not full
		for name in ["Ground","Walls","EntryLabel"]:
			var old: Node = root.get_node(name)
			root.remove_child(old)
			old.free()
		var center := Vector3(0,0,-48) if full else Vector3.ZERO
		var art: Node3D = add(root,load("res://scenes/environment/ruins_arena.tscn").instantiate(),"ArenaArt")
		art.position = center+Vector3(0,-0.95,0)
		art.rotation.y = PI
		var solid: StaticBody3D = add(root,StaticBody3D.new(),"ArenaCollision")
		for n in art.find_children("*","MeshInstance3D",true,false):
			var collision := CollisionShape3D.new()
			collision.shape = n.mesh.create_trimesh_shape()
			solid.add_child(collision)
			collision.owner = root
			collision.transform = art.transform*n.transform
		var player: CharacterBody3D = root.get_node("Player")
		player.position = Vector3(0,0.15,20) if full else Vector3(0,0.15,15)
		root.get_node("CameraRig").position = player.position+Vector3.UP*1.25
		root.get_node("CameraRig/YawPivot/PitchPivot/SpringArm3D/Camera3D").far = 140
		var boss: CharacterBody3D = root.get_node("Boss")
		root.set_editable_instance(boss,true)
		boss.position = center+Vector3(0,0.1,-3)
		boss.get_node("SoldierAI").arena_center = center
		boss.get_node("SoldierAI").arena_half_extents = Vector2(9,9)
		boss.get_node("CombatPivot/AreaWarning").position.y = 0.16
		root.get_node("EncounterEntry").position = center+Vector3(0,1,7)
		var old_fire: Node = root.get_node("Bonfire")
		root.remove_child(old_fire)
		old_fire.free()
		var manager: Node = root.get_node("CheckpointManager")
		var start_fire: Node3D = fire(root,"Bonfire",Vector3(2,0,20) if full else Vector3(2,0,15),manager,&"forest_start" if full else &"art_guardian")
		root.set_editable_instance(start_fire,true)
		start_fire.get_node("RespawnPoint").position = Vector3(-2,0.1,0)
		manager.initial_spawn = start_fire.get_node("RespawnPoint")
		p._box(root,"Approach",center+Vector3(0,-0.25,16),Vector3(6,0.5,10),p.mats.earth)
		p._box(root,"ApproachLeft",center+Vector3(-3.5,0.8,16),Vector3(1,1.6,10),p.mats.ruins)
		p._box(root,"ApproachRight",center+Vector3(3.5,0.8,16),Vector3(1,1.6,10),p.mats.ruins)
		if full:
			add(root,load("res://scenes/environment/dry_forest.tscn").instantiate(),"Forest")
			p._box(root,"LinkFloor",Vector3(0,-0.25,-27),Vector3(6,0.5,8),p.mats.earth)
			fire(root,"GateBonfire",Vector3(1.8,0,-32),manager,&"forest_gate")
			var dummy: Node3D = add(root,load("res://scenes/props/training_dummy.tscn").instantiate(),"TutorialDummy")
			dummy.position = Vector3(2.5,0,12)
			dummy.get_node("Visual").rotation.y = PI
			root.set_editable_instance(dummy,true)
			dummy.target_id = &"tutorial_dummy_4a"
			for i in range(2):
				var actor: CharacterBody3D = add(root,load("res://scenes/enemies/soldier.tscn").instantiate(),"Soldier"+str(i+1))
				root.set_editable_instance(actor,true)
				actor.position = Vector3(0,0.1,1-15*i)
				actor.get_node("Visual").rotation.y = PI
				actor.get_node("SoldierAI").target = player
				actor.get_node("LockableTarget").target_id = StringName("forest_soldier_"+str(i+1))
			for i in range(4):
				var prop: Node3D = add(root,load("res://scenes/environment/rock_prop.tscn").instantiate(),"Rock"+str(i))
				prop.position = Vector3(-5.5 if i%2==0 else 5.5,0,16-i*11)
				prop.rotation_degrees.y = [17,103,211,289][i]
				prop.scale = Vector3.ONE*[0.85,1.0,1.1,0.95][i]
		var env: Environment = root.get_node("WorldEnvironment").environment.duplicate()
		env.background_color = Color(0.12,0.14,0.16)
		env.ambient_light_energy = 0.8
		root.get_node("WorldEnvironment").environment = env
		root.get_node("DirectionalLight3D").shadow_enabled = false
		var hint := Label.new()
		root.get_node("HUD").add_child(hint)
		hint.name = "RouteHint"
		hint.owner = root
		hint.position = Vector2(24,225)
		hint.size = Vector2(1160,48)
		hint.add_theme_font_size_override("font_size",16)
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		root.get_node("HUD/Margin/Info/Title").text = "FASE 4A · BOSQUE SECO" if full else "FASE 4A · ARENA DEL GUARDIÁN"
		root.get_node("HUD/Margin/Info/Hint").text = "Hoguera → Tutorial → Camino → Arco → Jefe · Esc / Menu: selector"
		own(root,root)
		p._save_scene(root,"res://scenes/levels/"+("main_level.tscn" if full else "ruins_boss_arena.tscn"))
		root.free()
		await tree.process_frame
	tree.root.set_meta("phase4a_levels_ready",true)
