extends RefCounted
## Offline, non-destructive Godot asset integration. Run only through MCP.
const DIR = "res://resources/environment_4a/"
var tree: SceneTree
var report: Dictionary = {}
var originals: Dictionary = {}
var source: Dictionary = {}
var mats: Dictionary = {}
var mesh_cache: Dictionary = {}
var material_cache: Dictionary = {}
var texture_cache: Dictionary = {}
var serial: int = 0
var phase: String = ""
func start(t: SceneTree) -> void:
	tree = t
	tree.root.set_meta("phase4a_pipeline",self)
	phase = "loading"
	DirAccess.make_dir_recursive_absolute(DIR)
	DirAccess.make_dir_recursive_absolute("res://scenes/environment")
	for folder in ["scripts","scenes","resources","assets/models"]:
		_hash_folder("res://"+folder)
	for path in ["res://project.godot","res://scripts/player/attack_controller.gd"]:
		originals[path] = FileAccess.get_sha256(path)
	_write("res://tests/phase_4a_originals.json",originals)
	var paths: Array[String] = ["res://assets/models/escenario 1.glb","res://assets/models/Arena_del_jefe.glb","res://assets/models/hoguera.glb","res://assets/models/Roca_decorativa.glb","res://assets/models/Frasco_Estus.glb"]
	for path in paths: ResourceLoader.load_threaded_request(path)
	for path in paths:
		while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await tree.process_frame
		if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_LOADED:
			report[path] = {"classification":"NO UTILIZABLE","error":"load failed"}
			continue
		var packed: PackedScene = ResourceLoader.load_threaded_get(path)
		source[path] = packed
		var node: Node3D = packed.instantiate()
		var rows: Array = []
		var material_info: Dictionary = {}
		var surfaces: int = 0
		var triangles: int = 0
		var missing: int = 0
		var box := AABB()
		var first: bool = true
		for mesh_node in node.find_children("*","MeshInstance3D",true,false):
			var mesh: Mesh = mesh_node.mesh
			if mesh == null: continue
			var transform: Transform3D = _relative(mesh_node,node)
			var b: AABB = transform * mesh.get_aabb()
			box = b if first else box.merge(b)
			first = false
			var slots: Array = []
			for s in range(mesh.get_surface_count()):
				surfaces += 1
				var index_count: int = mesh.surface_get_array_index_len(s)
				triangles += int((index_count if index_count > 0 else mesh.surface_get_array_len(s))/3)
				var mat: Material = mesh_node.get_active_material(s)
				if mat == null:
					missing += 1
					slots.append("MISSING")
				else:
					var key: String = mat.resource_path
					slots.append(key)
					if not material_info.has(key):
						material_info[key] = {"name":mat.resource_name}
						if mat is BaseMaterial3D:
							material_info[key]["color"] = str(mat.albedo_color)
							material_info[key]["roughness"] = mat.roughness
							var tex: Texture2D = mat.albedo_texture
							material_info[key]["texture_size"] = [tex.get_width(),tex.get_height()] if tex != null else []
			rows.append({"path":str(node.get_path_to(mesh_node)),"position":str(b.position),"size":str(b.size),"materials":slots})
		report[path] = {"loaded":true,"classification":"REQUIERE AJUSTES","triangles":triangles,"mesh_count":rows.size(),"surfaces":surfaces,"missing_slots":missing,"bounds_position":str(box.position),"bounds_size":str(box.size),"collisions":node.find_children("*","CollisionShape3D",true,false).size(),"materials":material_info,"meshes":rows}
		node.free()
		await tree.process_frame
	_write("res://tests/phase_4a_asset_audit.json",report)
	phase = "audited"
func _hash_folder(path: String) -> void:
	for name in DirAccess.get_files_at(path):
		if not name.ends_with(".uid") and not name.ends_with(".import"): originals[path+"/"+name] = FileAccess.get_sha256(path+"/"+name)
	for name in DirAccess.get_directories_at(path): _hash_folder(path+"/"+name)
func _write(path: String, value: Variant) -> void:
	var f: FileAccess = FileAccess.open(path,FileAccess.WRITE)
	f.store_string(JSON.stringify(value,"\t"))
func _relative(node: Node3D, root: Node3D) -> Transform3D:
	var result: Transform3D = node.transform
	var parent: Node = node.get_parent()
	while parent != null:
		if parent is Node3D: result = parent.transform * result
		if parent == root: break
		parent = parent.get_parent()
	return result

func build_assets() -> void:
	phase = "building_assets"
	_make_materials()
	var forest := Node3D.new()
	forest.name = "DryForest"
	var imported: Node3D = source["res://assets/models/escenario 1.glb"].instantiate()
	var kept: Array = []
	var excluded: Array = []
	var tree_number: int = 0
	var building_count: int = 0
	for n in imported.find_children("*","MeshInstance3D",true,false):
		var transform: Transform3D = _relative(n,imported)
		var bound: AABB = transform * n.mesh.get_aabb()
		var center: Vector3 = bound.get_center() * 0.2
		var name: String = str(n.name)
		if name.begins_with("tripo"):
			# Preserve the authored horizontal placement of selected outer trees.
			if absf(center.x) < 7.0 or tree_number >= 12:
				excluded.append(name+": dense central/duplicate tree")
				continue
			var copy: MeshInstance3D = _mesh_copy(n,3500)
			forest.add_child(copy)
			copy.owner = forest
			copy.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*0.2),Vector3.ZERO)*transform
			var box: AABB = copy.transform * copy.mesh.get_aabb()
			copy.position.y -= box.position.y
			copy.set_meta("source_mesh",name)
			copy.visibility_range_end = 75.0
			# A simple trunk proxy; branches and ground scraps stay decorative.
			var trunk_position: Vector3 = (copy.transform * copy.mesh.get_aabb()).get_center()
			trunk_position.y = 1.6
			_cylinder(forest,"Trunk"+str(tree_number),trunk_position,0.35,3.2)
			tree_number += 1
			kept.append(name)
		elif name.begins_with("Cube") or name.begins_with("Cylinder") or name.begins_with("Plane"):
			# Keep a coherent ruin sector, with all retained pieces at authored transforms.
			if center.x < 14.0 or center.x > 27.0 or center.z < -27.0 or center.z > -14.0:
				excluded.append(name+": outside selected ruin sector")
				continue
			var copy: MeshInstance3D = _mesh_copy(n,2500)
			forest.add_child(copy)
			copy.owner = forest
			copy.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*0.2),Vector3.ZERO)*transform
			kept.append(name)
			building_count += 1
			var b: AABB = copy.transform * copy.mesh.get_aabb()
			if b.position.y < 3.0 and b.size.y > 0.6 and b.size.x*b.size.z > 0.12:
				_box(forest,"SolidRuin"+str(building_count),b.get_center(),b.size.max(Vector3.ONE*0.15))
		elif name == "Object_4_001":
			# This authored ground plane is XY-oriented and uses different units.
			var ground: MeshInstance3D = _mesh_copy(n,1000)
			forest.add_child(ground)
			ground.owner = forest
			var fix := Transform3D(Basis(Vector3.RIGHT,-PI/2).scaled(Vector3.ONE*0.012),Vector3.ZERO)
			ground.transform = fix*transform
			var gb: AABB = ground.transform * ground.mesh.get_aabb()
			ground.position -= Vector3(gb.get_center().x,gb.position.y,gb.get_center().z)
			kept.append(name)
		else:
			excluded.append(name+": misoriented/displaced terrain or duplicate sky; excluded")
		if kept.size()%24 == 0: await tree.process_frame
	# Native simple floor covers the selected rectangular walkable footprint.
	_box(forest,"ForestGround",Vector3(0,-0.25,0),Vector3(56,0.5,52))
	# Physical limits correspond to the retained sector, no open world.
	_box(forest,"WestBoundary",Vector3(-24,2,0),Vector3(1,4,52),mats.mountain)
	_box(forest,"EastBoundary",Vector3(27,2,0),Vector3(1,4,52),mats.mountain)
	_box(forest,"SouthBoundary",Vector3(1,2,25),Vector3(52,4,1),mats.mountain)
	_box(forest,"NorthWest",Vector3(-14,2,-26),Vector3(20,4,1),mats.mountain)
	_box(forest,"NorthEast",Vector3(17,2,-26),Vector3(20,4,1),mats.mountain)
	_save_scene(forest,"res://scenes/environment/dry_forest.tscn")
	forest.free()
	imported.free()
	report["integration"] = {"kept_source_meshes":kept,"excluded_source_meshes":excluded,"trees":tree_number,"ruin_meshes":building_count,"note":"Source mixes incompatible units/orientations. Selected forest/ruin subset kept in XZ at 0.2. Authored XY ground independently normalized. No original overwritten."}
	for spec in [
		["res://assets/models/Arena_del_jefe.glb","ruins_arena",28.0,12000],
		["res://assets/models/hoguera.glb","bonfire_visual",1.5,5000],
		["res://assets/models/Roca_decorativa.glb","decorative_rock",1.4,2000],
		["res://assets/models/Frasco_Estus.glb","estus_visual",0.25,3500]]:
		var raw: Node3D = source[spec[0]].instantiate()
		var wrapper := Node3D.new()
		wrapper.name = str(spec[1]).to_pascal_case()
		var meshes: Array = raw.find_children("*","MeshInstance3D",true,false)
		var bounds := AABB()
		var first: bool = true
		for n in meshes:
			var b: AABB = _relative(n,raw)*n.mesh.get_aabb()
			bounds = b if first else bounds.merge(b)
			first = false
		var factor: float = float(spec[2])/(bounds.size.y if spec[1]=="estus_visual" else maxf(bounds.size.x,bounds.size.z))
		for n in meshes:
			var copy: MeshInstance3D = _mesh_copy(n,int(spec[3]))
			wrapper.add_child(copy)
			copy.owner = wrapper
			copy.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*factor),Vector3.ZERO)*_relative(n,raw)
			copy.position -= Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*factor
		wrapper.set_meta("source_asset",spec[0])
		wrapper.set_meta("unit_scale",factor)
		_save_scene(wrapper,"res://scenes/environment/"+spec[1]+".tscn")
		report[spec[0]]["unit_scale"] = factor
		report[spec[0]]["classification"] = "REQUIERE AJUSTES: derived mesh/texture/scale; usable"
		wrapper.free()
		raw.free()
		await tree.process_frame
	report["res://assets/models/escenario 1.glb"]["classification"] = "REQUIERE MATERIAL PROVISIONAL + AJUSTES: partial sector usable; displaced geometry excluded"
	_write("res://tests/phase_4a_asset_audit.json",report)
	phase = "assets_ready"

func _make_materials() -> void:
	for spec in [
		["stone",Color(0.28,0.29,0.29)],["earth",Color(0.27,0.21,0.15)],
		["sand",Color(0.39,0.33,0.24)],["bark",Color(0.18,0.13,0.09)],
		["wood",Color(0.25,0.18,0.12)],["rust",Color(0.3,0.18,0.12)],
		["ruins",Color(0.32,0.32,0.29)],["ash",Color(0.14,0.14,0.13)],
		["mountain",Color(0.22,0.23,0.23)],["dark",Color(0.07,0.08,0.08)]]:
		var mat := StandardMaterial3D.new()
		mat.resource_name = "Provisional_"+spec[0]
		mat.albedo_color = spec[1]
		mat.roughness = 0.95
		if spec[0] == "rust": mat.metallic = 0.15
		var path: String = DIR+spec[0]+".tres"
		ResourceSaver.save(mat,path)
		mats[spec[0]] = load(path)
func _material(mat: Material, node_name: String) -> Material:
	if mat == null: return mats.ruins
	if not mat is StandardMaterial3D: return mat
	var key: String = mat.resource_path
	if material_cache.has(key): return material_cache[key]
	var name: String = mat.resource_name.to_lower()
	if mat.albedo_texture == null and mat.albedo_color.is_equal_approx(Color.WHITE):
		var fallback: Material = mats.ruins
		if "holz" in name or "madera" in name: fallback = mats.wood
		elif "stahl" in name: fallback = mats.rust
		elif "fenster" in name: fallback = mats.dark
		elif "dach" in name: fallback = mats.ash
		elif "tierra" in name: fallback = mats.earth
		material_cache[key] = fallback
		return fallback
	var copy: StandardMaterial3D = mat.duplicate()
	for prop in ["albedo_texture","normal_texture","roughness_texture","metallic_texture","ao_texture"]:
		var texture: Texture2D = copy.get(prop)
		if texture == null: continue
		
		var texture_key: String = texture.resource_path
		if texture_cache.has(texture_key):
			copy.set(prop,texture_cache[texture_key])
			continue
		var img: Image = texture.get_image()
		if img.is_compressed(): img.decompress()
		var ratio: float = minf(1.0,1024.0/maxf(img.get_width(),img.get_height()))
		img.resize(maxi(1,int(img.get_width()*ratio)),maxi(1,int(img.get_height()*ratio)),Image.INTERPOLATE_LANCZOS)
		img.generate_mipmaps()
		var smaller := ImageTexture.create_from_image(img)
		serial += 1
		var tp: String = DIR+"texture_"+str(serial)+".res"
		ResourceSaver.save(smaller,tp)
		texture_cache[texture_key] = load(tp)
		copy.set(prop,texture_cache[texture_key])
	serial += 1
	var mp: String = DIR+"art_material_"+str(serial)+".tres"
	ResourceSaver.save(copy,mp)
	material_cache[key] = load(mp)
	return material_cache[key]
func _mesh_copy(node: MeshInstance3D, target: int) -> MeshInstance3D:
	var input: Mesh = node.mesh
	var key: String = input.resource_path+"_"+str(target)
	var output: ArrayMesh
	if mesh_cache.has(key):
		output = mesh_cache[key]
	else:
		var importer := ImporterMesh.new()
		for s in range(input.get_surface_count()):
			importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,input.surface_get_arrays(s))
		importer.generate_lods(60.0,25.0,[])
		output = ArrayMesh.new()
		var original_triangles: int = 0
		var final_triangles: int = 0
		for s in range(importer.get_surface_count()):
			var arrays: Array = importer.get_surface_arrays(s)
			var original_count: int = arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null else arrays[Mesh.ARRAY_VERTEX].size()
			original_triangles += original_count/3
			var best: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			for l in range(importer.get_surface_lod_count(s)):
				var indices: PackedInt32Array = importer.get_surface_lod_indices(s,l)
				if indices.size()/3 <= target and (best.size()/3 > target or indices.size() > best.size()): best = indices
			if not best.is_empty(): arrays[Mesh.ARRAY_INDEX] = best
			var temp := ArrayMesh.new()
			temp.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			var surface := SurfaceTool.new()
			surface.create_from(temp,0)
			surface.deindex()
			surface.index()
			var compact: ArrayMesh = surface.commit()
			output.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,compact.surface_get_arrays(0))
			output.surface_set_material(s,_material(node.get_active_material(s),str(node.name)))
			final_triangles += output.surface_get_array_index_len(s)/3
		serial += 1
		var path: String = DIR+"mesh_"+str(serial)+".res"
		ResourceSaver.save(output,path)
		output = load(path)
		mesh_cache[key] = output
		if not report.has("derived_meshes"): report["derived_meshes"] = []
		report.derived_meshes.append({"source":input.resource_path,"output":path,"original_triangles":original_triangles,"derived_triangles":final_triangles})
	var copy := MeshInstance3D.new()
	copy.name = node.name
	copy.mesh = output
	copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return copy
func _box(parent: Node3D, name: String, center: Vector3, size: Vector3, material: Material = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	parent.add_child(body)
	body.owner = parent
	body.position = center
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	collision.owner = parent
	if material != null:
		var visual := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh.material = material
		visual.mesh = mesh
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(visual)
		visual.owner = parent
	return body
func _cylinder(parent: Node3D, name: String, center: Vector3, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.name = name
	parent.add_child(body)
	body.owner = parent
	body.position = center
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	body.add_child(collision)
	collision.owner = parent
func _save_scene(node: Node, path: String) -> void:
	var packed := PackedScene.new()
	var err: int = packed.pack(node)
	assert(err == OK)
	assert(ResourceSaver.save(packed,path) == OK)
