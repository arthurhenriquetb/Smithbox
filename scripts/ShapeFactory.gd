extends RefCounted
class_name ShapeFactory

# Six separately paintable surfaces per block, including door/window reveals.
# Index order: front, back, left, right, top, bottom.
const FACE_NORMALS := [Vector3.BACK, Vector3.FORWARD, Vector3.LEFT, Vector3.RIGHT, Vector3.UP, Vector3.DOWN]
static var shared_box_material: StandardMaterial3D

static func cube(parent: Node3D, local_pos: Vector3, size: Vector3, color: Color, item_id: int, component_id: int, rotation: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Part_%d_%d" % [item_id, component_id]
	body.position = local_pos
	body.rotation = rotation
	body.set_meta("item_id", item_id)
	body.set_meta("component_id", component_id)
	body.set_meta("paintable", true)
	parent.add_child(body)
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.name = "Collision"
	col.shape = shape
	body.add_child(col)
	var mesh := MeshInstance3D.new()
	mesh.name = "Surface"
	mesh.mesh = create_box_mesh(size, [color,color,color,color,color,color])
	mesh.material_override = color_vertex_material()
	body.add_child(mesh)
	return body

static func color_vertex_material() -> StandardMaterial3D:
	if shared_box_material == null:
		shared_box_material = StandardMaterial3D.new()
		shared_box_material.vertex_color_use_as_albedo = true
		shared_box_material.roughness = 1.0
	return shared_box_material


static func create_box_mesh(size: Vector3, face_colors: Array) -> ArrayMesh:
	var p := size * 0.5
	var corners := [
		[Vector3(-p.x,-p.y,p.z), Vector3(p.x,-p.y,p.z), Vector3(p.x,p.y,p.z), Vector3(-p.x,p.y,p.z)],
		[Vector3(p.x,-p.y,-p.z), Vector3(-p.x,-p.y,-p.z), Vector3(-p.x,p.y,-p.z), Vector3(p.x,p.y,-p.z)],
		[Vector3(-p.x,-p.y,-p.z), Vector3(-p.x,-p.y,p.z), Vector3(-p.x,p.y,p.z), Vector3(-p.x,p.y,-p.z)],
		[Vector3(p.x,-p.y,p.z), Vector3(p.x,-p.y,-p.z), Vector3(p.x,p.y,-p.z), Vector3(p.x,p.y,p.z)],
		[Vector3(-p.x,p.y,p.z), Vector3(p.x,p.y,p.z), Vector3(p.x,p.y,-p.z), Vector3(-p.x,p.y,-p.z)],
		[Vector3(-p.x,-p.y,-p.z), Vector3(p.x,-p.y,-p.z), Vector3(p.x,-p.y,p.z), Vector3(-p.x,-p.y,p.z)]
	]
	var mesh := ArrayMesh.new()
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	for f in 6:
		for n in [0, 1, 2, 0, 2, 3]:
			verts.append(corners[f][n])
			norms.append(FACE_NORMALS[f])
			cols.append(face_colors[f])
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = verts
	a[Mesh.ARRAY_NORMAL] = norms
	a[Mesh.ARRAY_COLOR] = cols
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return mesh


static func recolor(body: StaticBody3D, face_colors: Array) -> void:
	var mesh: MeshInstance3D = body.get_node("Surface")
	var col: CollisionShape3D = body.get_node("Collision")
	var shape: BoxShape3D = col.shape
	mesh.mesh = create_box_mesh(shape.size,face_colors)

static func material(color: Color, transparent: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mat.metallic = 0.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

static func face_from_local_normal(normal: Vector3) -> int:
	var x := absf(normal.x)
	var y := absf(normal.y)
	var z := absf(normal.z)
	if y > x and y > z:
		return 4 if normal.y > 0 else 5
	if x > z:
		return 3 if normal.x > 0 else 2
	return 0 if normal.z > 0 else 1
