extends RefCounted

static func wire_box(size: Vector3, color: Color) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var half := size * 0.5
	var points: Array[Vector3] = []
	for x in [-1,1]:
		for y in [-1,1]:
			for z in [-1,1]:
				points.append(Vector3(x*half.x,y*half.y,z*half.z))
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(8):
		for bit in [1,2,4]:
			var j: int = i ^ bit
			if i < j:
				mesh.surface_add_vertex(points[i])
				mesh.surface_add_vertex(points[j])
	mesh.surface_end()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	mesh.surface_set_material(0,material)
	return mesh
