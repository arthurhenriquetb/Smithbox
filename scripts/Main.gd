extends Node3D

const Shape = preload("res://scripts/ShapeFactory.gd")
const SAVE_FILE := "user://casa_livre.json"
const TILE_COLORS := {
	"grass": Color("86aa6f"), "tall_grass": Color("6f9458"),
	"dirt": Color("b9784b"), "slab": Color("a9aeb0")
}

var settings: Dictionary = {
	"width": 18, "depth": 16, "context": "Rural", "horizon": "Flat",
	"ground": "grass", "fence": true, "fence_height": 2.0,
	"fence_finish": "Painted", "fence_color": "#b5b8b3"
}
var cells: Dictionary = {}
var pieces: Array[Dictionary] = []
var next_id := 1
var mode := "Terrain"
var terrain_brush := "grass"
var opening_type := "Window"
var furniture_type := "Sink"
var roof_type := "Gable"
var wall_turned := false
var item_color := Color("d1d0c9")
var paint_color := Color("eee7d7")
var window_width := 0.68
var window_height := 1.0
var window_sill := 0.95
var door_width := 0.80
var door_height := 2.1
var furniture_width := 1.2
var furniture_depth := 0.7
var furniture_height := 0.85
var roof_pitch := 25.0
var roof_first_corner := Vector2i(-1, -1)
var live := false
var camera_yaw := deg_to_rad(40.0)
var camera_pitch := deg_to_rad(-22.0)
var player_position := Vector3(9.0,1.7,8.0)
var walk_speed := 4.0
var mouse_look_locked := false
var touch_movement := Vector2.ZERO
var dragging := false
var last_touch := Vector2.ZERO

var camera: Camera3D
var world: Node3D
var terrain_mesh: MeshInstance3D
var built: Node3D
var hint_label: Label
var tools_content: VBoxContainer
var setup_ui: Control
var game_ui: Control
var setup_refs: Dictionary = {}
var ghost: MeshInstance3D


func _ready() -> void:
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -30, 0)
	sun.light_energy = 0.8
	sun.shadow_enabled = false
	add_child(sun)
	var ambient := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("b3cde4")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("ecefe7")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	ambient.environment = env
	add_child(ambient)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 57
	add_child(camera)
	create_setup_ui()


func ui_label(parent: Node, value: String, size: int = 14) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label


func ui_button(parent: Node, value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 34
	parent.add_child(button)
	button.pressed.connect(action)
	return button


func ui_spin(parent: Node, value: float, low: float, high: float, step: float, callback: Callable) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = step
	spin.value = value
	spin.custom_minimum_size.x = 110
	parent.add_child(spin)
	spin.value_changed.connect(callback)
	return spin


func ui_option(parent: Node, values: Array, selected: String, callback: Callable) -> OptionButton:
	var option := OptionButton.new()
	for value in values:
		option.add_item(str(value))
	var idx := values.find(selected)
	option.selected = maxi(idx, 0)
	option.custom_minimum_size.y = 32
	parent.add_child(option)
	option.item_selected.connect(func(i: int): callback.call(values[i]))
	return option


func ui_color(parent: Node, value: Color, callback: Callable) -> ColorPickerButton:
	var picker := ColorPickerButton.new()
	picker.color = value
	picker.custom_minimum_size = Vector2(110, 32)
	parent.add_child(picker)
	picker.color_changed.connect(callback)
	return picker


func labeled_spin(parent: Node, title: String, value: float, low: float, high: float, step: float, callback: Callable) -> SpinBox:
	var line := HBoxContainer.new()
	parent.add_child(line)
	var label := ui_label(line, title, 13)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return ui_spin(line, value, low, high, step, callback)


func create_setup_ui() -> void:
	setup_ui = Control.new()
	setup_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var overlay := CanvasLayer.new()
	overlay.name = "Setup"
	add_child(overlay)
	overlay.add_child(setup_ui)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	setup_ui.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(425, 0)
	center.add_child(panel)
	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 16)
	padding.add_theme_constant_override("margin_right", 16)
	padding.add_theme_constant_override("margin_top", 14)
	padding.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(padding)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	padding.add_child(v)
	ui_label(v, "CASA LIVRE", 23)
	ui_label(v, "Set up your building lot", 14)
	var size_row := HBoxContainer.new()
	v.add_child(size_row)
	ui_label(size_row, "Lot (meters)", 13)
	setup_refs["width"] = ui_spin(size_row, settings.width, 6, 40, 1, func(_v): pass)
	setup_refs["depth"] = ui_spin(size_row, settings.depth, 6, 40, 1, func(_v): pass)
	ui_label(v, "Surroundings", 13)
	setup_refs["context"] = ui_option(v, ["Rural", "Urban"], settings.context, func(_v): pass)
	setup_refs["horizon"] = ui_option(v, ["Flat", "Mountainous"], settings.horizon, func(_v): pass)
	ui_label(v, "Starting ground", 13)
	setup_refs["ground"] = ui_option(v, ["Grass", "Tall grass", "Dirt", "Concrete slab"], "Grass", func(_v): pass)
	var fence_row := HBoxContainer.new()
	v.add_child(fence_row)
	var check := CheckBox.new()
	check.text = "Perimeter wall"
	check.button_pressed = settings.fence
	fence_row.add_child(check)
	setup_refs["fence"] = check
	ui_label(fence_row, "Height", 12)
	setup_refs["fence_height"] = ui_spin(fence_row, settings.fence_height, 0.5, 5, 0.1, func(_v): pass)
	setup_refs["fence_finish"] = ui_option(v, ["Painted", "Gray blocks"], settings.fence_finish, func(_v): pass)
	var paint_row := HBoxContainer.new()
	v.add_child(paint_row)
	ui_label(paint_row, "Perimeter color", 13)
	setup_refs["fence_color"] = ui_color(paint_row, Color(settings.fence_color), func(_v): pass)
	ui_button(v, "START BUILDING", start_from_setup)
	if FileAccess.file_exists(SAVE_FILE):
		ui_button(v, "Load saved house", load_project)
	ui_label(v, "Low-poly • no textures • 1 m grid", 12)
	update_camera()


func start_from_setup() -> void:
	settings.width = int(setup_refs.width.value)
	settings.depth = int(setup_refs.depth.value)
	settings.context = setup_refs.context.get_item_text(setup_refs.context.selected)
	settings.horizon = setup_refs.horizon.get_item_text(setup_refs.horizon.selected)
	var grounds := ["grass", "tall_grass", "dirt", "slab"]
	settings.ground = grounds[setup_refs.ground.selected]
	settings.fence = setup_refs.fence.button_pressed
	settings.fence_height = float(setup_refs.fence_height.value)
	settings.fence_finish = setup_refs.fence_finish.get_item_text(setup_refs.fence_finish.selected)
	settings.fence_color = setup_refs.fence_color.color.to_html()
	cells.clear()
	pieces.clear()
	next_id = 1
	terrain_brush = settings.ground
	if settings.fence:
		add_perimeter()
	enter_game()


func add_perimeter() -> void:
	var w: float = settings.width
	var d: float = settings.depth
	var h: float = settings.fence_height
	var c: String = settings.fence_color if settings.fence_finish == "Painted" else "#969b9a"
	for data in [
		{"x": w/2.0, "z": 0.0, "w": w, "d": 0.17},
		{"x": w/2.0, "z": d, "w": w, "d": 0.17},
		{"x": 0.0, "z": d/2.0, "w": 0.17, "d": d},
		{"x": w, "z": d/2.0, "w": 0.17, "d": d}
	]:
		pieces.append({"id": next_id, "type": "fence", "x":data.x,"z":data.z,"w":data.w,"d":data.d,"h":h,"color":c,"faces":{}})
		next_id += 1


func enter_game() -> void:
	live = true
	if is_instance_valid(setup_ui):
		setup_ui.get_parent().queue_free()
	player_position = Vector3(settings.width/2.0,1.7,settings.depth/2.0)
	camera_yaw = 0
	camera_pitch = deg_to_rad(-22.0)
	mouse_look_locked = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	update_camera()
	build_world()
	create_game_ui()


func build_world() -> void:
	for child in world.get_children():
		child.queue_free()
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	world.add_child(ground)
	ground.position = Vector3(settings.width/2.0, -0.12, settings.depth/2.0)
	var shape := BoxShape3D.new()
	shape.size = Vector3(settings.width, 0.24, settings.depth)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	ground.add_child(collider)
	var backdrop := MeshInstance3D.new()
	backdrop.name = "DistantEarth"
	var earth := BoxMesh.new()
	var outer := maxf(settings.width,settings.depth)*4.5
	earth.size = Vector3(outer,0.6,outer)
	backdrop.mesh = earth
	backdrop.position = Vector3(settings.width/2.0,-0.55,settings.depth/2.0)
	backdrop.material_override = Shape.material(Color("7e9a75") if settings.context == "Rural" else Color("9a9e9e"))
	world.add_child(backdrop)
	terrain_mesh = MeshInstance3D.new()
	terrain_mesh.name = "Terrain"
	world.add_child(terrain_mesh)
	rebuild_ground()
	add_grid()
	add_background()
	built = Node3D.new()
	built.name = "Construction"
	world.add_child(built)
	redraw_pieces()
	ghost = MeshInstance3D.new()
	ghost.name = "Preview"
	var box := BoxMesh.new()
	box.size = Vector3(1, 0.12, 0.17)
	ghost.mesh = box
	ghost.material_override = Shape.material(Color(0.32, 0.82, 1.0, 0.4), true)
	world.add_child(ghost)


func rebuild_ground() -> void:
	# Every tile is a one-square-meter quad; one mesh keeps old devices fast.
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	for x in range(int(settings.width)):
		for z in range(int(settings.depth)):
			var key := "%d:%d" % [x, z]
			var tile_style: String = str(cells.get(key,settings.ground))
			var color: Color = Color(tile_style) if tile_style.begins_with("#") else TILE_COLORS.get(tile_style,TILE_COLORS.grass)
			for p in [Vector3(x,0,z),Vector3(x,0,z+1),Vector3(x+1,0,z+1),Vector3(x,0,z),Vector3(x+1,0,z+1),Vector3(x+1,0,z)]:
				verts.append(p)
				colors.append(color)
			if tile_style == "tall_grass":
				# Four flat triangles read as tufts without textures or extra draw calls.
				var cx := x+0.5
				var cz := z+0.5
				for tuft in [
					[Vector3(cx-0.18,0.01,cz),Vector3(cx,0.38,cz),Vector3(cx+0.18,0.01,cz)],
					[Vector3(cx,0.01,cz-0.18),Vector3(cx,0.32,cz),Vector3(cx,0.01,cz+0.18)]
				]:
					for point in tuft:
						verts.append(point)
						colors.append(Color("547a46"))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)
	terrain_mesh.mesh = mesh


func add_grid() -> void:
	var lines := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.16,0.24,0.22,0.22)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lines.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	for x in range(int(settings.width)+1):
		lines.surface_add_vertex(Vector3(x,0.018,0))
		lines.surface_add_vertex(Vector3(x,0.018,settings.depth))
	for z in range(int(settings.depth)+1):
		lines.surface_add_vertex(Vector3(0,0.018,z))
		lines.surface_add_vertex(Vector3(settings.width,0.018,z))
	lines.surface_end()
	var instance := MeshInstance3D.new()
	instance.name = "OneMeterGrid"
	instance.mesh = lines
	world.add_child(instance)


func add_background() -> void:
	# Silhouette scenery outside the editable plot; never consumes terrain tiles.
	var middle := Vector3(settings.width/2.0, 0, settings.depth/2.0)
	var radius: float = maxf(settings.width, settings.depth)*0.9 + 8
	for i in 16:
		var a: float = TAU * i / 16.0
		var pos := middle + Vector3(cos(a)*radius, 0, sin(a)*radius)
		var obj := MeshInstance3D.new()
		if settings.context == "Urban":
			var building := BoxMesh.new()
			var h := 3.0 + float((i*13)%7)
			building.size = Vector3(3.2+(i%3),h,3.3)
			obj.mesh = building
			obj.position = pos + Vector3(0,h/2.0-0.2,0)
			obj.material_override = Shape.material(Color("9aadaf") if i%2 else Color("899da4"))
		else:
			var hill := CylinderMesh.new()
			var h := 1.2 if settings.horizon == "Flat" else 7.0 + float(i%4)*2.0
			hill.top_radius = 0.0
			hill.bottom_radius = 6.0 if settings.horizon == "Flat" else 8.0
			hill.height = h
			hill.radial_segments = 5
			obj.mesh = hill
			obj.position = pos + Vector3(0,h/2.0-0.6,0)
			obj.material_override = Shape.material(Color("8ba188") if i%2 else Color("9eac8f"))
		world.add_child(obj)


func create_game_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "GameControls"
	add_child(canvas)
	game_ui = Control.new()
	game_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(game_ui)
	var sidebar := PanelContainer.new()
	sidebar.position = Vector2(10,10)
	sidebar.custom_minimum_size = Vector2(223,0)
	game_ui.add_child(sidebar)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 9)
	sidebar.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	margin.add_child(v)
	ui_label(v, "CASA LIVRE", 19)
	ui_label(v, "Tool", 12)
	ui_option(v, ["Terrain", "Walls", "Openings", "Roof", "Furniture", "Paint"], mode, func(value): mode=value; refresh_tool_options())
	tools_content = VBoxContainer.new()
	tools_content.add_theme_constant_override("separation", 5)
	v.add_child(tools_content)
	refresh_tool_options()
	ui_button(v, "Save project", save_project)
	hint_label = ui_label(v, "", 11)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var bottom := HBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -62
	bottom.offset_bottom = -8
	bottom.offset_left = 260
	bottom.offset_right = -10
	bottom.alignment = BoxContainer.ALIGNMENT_END
	game_ui.add_child(bottom)
	ui_button(bottom, "Rotate", rotate_piece)
	ui_button(bottom, "Lower all", func(): change_walls(false, true))
	ui_button(bottom, "Raise all", func(): change_walls(true, true))
	ui_button(bottom, "Delete", delete_aimed)
	var place := ui_button(bottom, "PLACE", place_aimed)
	place.custom_minimum_size.x = 95
	# Camera controls are also available on phones without a keyboard.
	var nav := VBoxContainer.new()
	nav.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	nav.position = Vector2(10,-95)
	game_ui.add_child(nav)
	var up_row := HBoxContainer.new()
	nav.add_child(up_row)
	ui_movement_button(up_row,"↑",Vector2(0,-1))
	var move_row := HBoxContainer.new()
	nav.add_child(move_row)
	ui_movement_button(move_row,"←",Vector2(-1,0))
	ui_movement_button(move_row,"↓",Vector2(0,1))
	ui_movement_button(move_row,"→",Vector2(1,0))
	var cross := Label.new()
	cross.text = "+"
	cross.add_theme_font_size_override("font_size", 25)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cross.offset_left = -8
	cross.offset_top = -20
	cross.offset_right = 18
	cross.offset_bottom = 10
	game_ui.add_child(cross)
	var tip := Label.new()
	tip.text = "FIRST PERSON  •  WASD: walk  •  drag: look  •  Tab: mouse lock"
	tip.add_theme_font_size_override("font_size", 12)
	tip.position = Vector2(245,12)
	game_ui.add_child(tip)
	ui_button(v, "Lock/unlock mouse (Tab)",toggle_mouse_look)


func ui_movement_button(parent: Node, caption: String, direction: Vector2) -> Button:
	var b := ui_button(parent,caption,func(): pass)
	b.custom_minimum_size.x = 41
	b.button_down.connect(func(): touch_movement = direction)
	b.button_up.connect(func():
		if touch_movement == direction:
			touch_movement = Vector2.ZERO
	)
	return b


func toggle_mouse_look() -> void:
	mouse_look_locked = not mouse_look_locked
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if mouse_look_locked else Input.MOUSE_MODE_VISIBLE)
	dragging = false


func refresh_tool_options() -> void:
	if not is_instance_valid(tools_content):
		return
	for child in tools_content.get_children():
		child.queue_free()
	match mode:
		"Terrain":
			ui_label(tools_content, "Set each 1 m² square", 12)
			var grounds := ["Grass", "Tall grass", "Dirt", "Concrete slab", "Custom color", "Pitanga tree"]
			var values := ["grass", "tall_grass", "dirt", "slab", "custom", "tree"]
			ui_option(tools_content, grounds, grounds[maxi(0,values.find(terrain_brush))], func(v): terrain_brush=values[grounds.find(v)])
			ui_color(tools_content,paint_color,func(c): paint_color=c)
		"Walls":
			ui_label(tools_content, "Place 1 m wall courses", 12)
			ui_label(tools_content, "Rotate to change direction", 12)
			ui_color(tools_content, item_color, func(c): item_color=c)
			ui_button(tools_content, "Raise aimed wall", func(): change_walls(true,false))
			ui_button(tools_content, "Lower aimed wall", func(): change_walls(false,false))
		"Openings":
			ui_label(tools_content, "Aim at an existing wall", 12)
			ui_option(tools_content, ["Window","Door","Remove opening"], opening_type, func(v): opening_type=v; refresh_tool_options())
			if opening_type == "Window":
				labeled_spin(tools_content,"Width (m)", window_width,0.25,0.9,0.05,func(v): window_width=v)
				labeled_spin(tools_content,"Height (m)",window_height,0.25,1.8,0.05,func(v): window_height=v)
				labeled_spin(tools_content,"Sill (m)",window_sill,0.3,1.9,0.05,func(v): window_sill=v)
			elif opening_type == "Door":
				labeled_spin(tools_content,"Width (m)",door_width,0.4,0.92,0.05,func(v): door_width=v)
				labeled_spin(tools_content,"Height (m)",door_height,1.5,2.5,0.05,func(v): door_height=v)
		"Roof":
			ui_label(tools_content, "Pick two rectangle corners", 12)
			ui_option(tools_content, ["Gable","Shed"],roof_type,func(v): roof_type=v)
			labeled_spin(tools_content,"Pitch (°)",roof_pitch,5,55,1,func(v): roof_pitch=v)
			ui_color(tools_content,item_color,func(c): item_color=c)
			ui_button(tools_content, "Cancel corners",func(): roof_first_corner=Vector2i(-1,-1))
		"Furniture":
			ui_option(tools_content,["Sink","Table","Bed","Sofa","Cabinet"],furniture_type,func(v): furniture_type=v)
			labeled_spin(tools_content,"Width (m)",furniture_width,0.3,4.0,0.1,func(v): furniture_width=v)
			labeled_spin(tools_content,"Depth (m)",furniture_depth,0.3,3.0,0.1,func(v): furniture_depth=v)
			labeled_spin(tools_content,"Height (m)",furniture_height,0.2,2.7,0.1,func(v): furniture_height=v)
			ui_color(tools_content,item_color,func(c): item_color=c)
		"Paint":
			ui_label(tools_content,"Aim at a face, then PLACE",12)
			ui_label(tools_content,"Each polygon side is separate",12)
			ui_color(tools_content,paint_color,func(c): paint_color=c)
			ui_button(tools_content,"Paint entire object",paint_whole_aimed)


func update_camera() -> void:
	if not is_instance_valid(camera):
		return
	camera.position = player_position
	camera.rotation = Vector3(camera_pitch,camera_yaw,0)


func move_camera(x: float, z: float) -> void:
	var forward := Vector3(-sin(camera_yaw),0,-cos(camera_yaw))
	var right := Vector3(cos(camera_yaw),0,-sin(camera_yaw))
	player_position += right*x + forward*z
	player_position.x = clampf(player_position.x,0.45,settings.width-0.45)
	player_position.z = clampf(player_position.z,0.45,settings.depth-0.45)
	update_camera()


func _process(delta: float) -> void:
	if not live:
		return
	var movement := touch_movement
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): movement.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): movement.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): movement.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): movement.x += 1
	if movement.length() > 0:
		var forward := Vector3(-sin(camera_yaw),0,-cos(camera_yaw))
		var right := Vector3(cos(camera_yaw),0,-sin(camera_yaw))
		player_position += (right*movement.x-forward*movement.y).normalized()*delta*walk_speed
		player_position.x = clampf(player_position.x,0.45,settings.width-0.45)
		player_position.z = clampf(player_position.z,0.45,settings.depth-0.45)
		update_camera()
	update_preview()


func _input(event: InputEvent) -> void:
	# Handle this before the UI consumes Tab for focus navigation.
	if live and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB or (event.keycode == KEY_ESCAPE and mouse_look_locked):
			toggle_mouse_look()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not live:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			walk_speed = minf(10,walk_speed+0.5)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			walk_speed = maxf(1,walk_speed-0.5)
		elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			place_aimed()
	elif event is InputEventMouseMotion and (dragging or mouse_look_locked):
		camera_yaw -= event.relative.x*0.007
		camera_pitch = clampf(camera_pitch-event.relative.y*0.006,-1.45,1.45)
		update_camera()
	elif event is InputEventScreenDrag:
		camera_yaw -= event.relative.x*0.006
		camera_pitch = clampf(camera_pitch-event.relative.y*0.006,-1.45,1.45)
		update_camera()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			rotate_piece()
		elif event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			delete_aimed()


func aim_point() -> Vector3:
	var screen := get_viewport().get_visible_rect().size*0.5
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if dir.y > -0.0001:
		return Vector3(-999,0,-999)
	var p := from+dir*(-from.y/dir.y)
	return p


func within_lot(p: Vector3) -> bool:
	return p.x >= 0 and p.z >= 0 and p.x < settings.width and p.z < settings.depth


func update_preview() -> void:
	if not is_instance_valid(ghost):
		return
	var p := aim_point()
	ghost.visible = within_lot(p) and mode != "Paint"
	if not ghost.visible:
		return
	if mode == "Walls":
		var q := wall_snap(p)
		ghost.position = Vector3(q.x,0.16,q.y)
		ghost.rotation.y = PI/2 if wall_turned else 0
		(ghost.mesh as BoxMesh).size = Vector3(1,0.32,0.17)
	elif mode == "Roof":
		ghost.position = Vector3(floorf(p.x)+0.5,0.14,floorf(p.z)+0.5)
		ghost.rotation.y = 0
		(ghost.mesh as BoxMesh).size = Vector3(1,0.24,1)
	else:
		ghost.position = Vector3(floorf(p.x)+0.5,0.07,floorf(p.z)+0.5)
		ghost.rotation.y = 0
		(ghost.mesh as BoxMesh).size = Vector3(1,0.12,1)
	if is_instance_valid(hint_label):
		hint_label.text = "X %d m  |  Z %d m\n%s" % [int(p.x),int(p.z),mode]


func wall_snap(p: Vector3) -> Vector2:
	if wall_turned:
		return Vector2(roundf(p.x),floorf(p.z)+0.5)
	return Vector2(floorf(p.x)+0.5,roundf(p.z))


func place_aimed() -> void:
	if not live:
		return
	if mode == "Paint":
		paint_aimed(false)
		return
	var p := aim_point()
	if not within_lot(p):
		return
	var x := int(floorf(p.x))
	var z := int(floorf(p.z))
	match mode:
		"Terrain":
			if terrain_brush == "tree":
				add_piece({"type":"tree", "x":x+0.5, "z":z+0.5,"color":"#598c52"})
			else:
				cells["%d:%d" % [x,z]] = paint_color.to_html() if terrain_brush == "custom" else terrain_brush
				rebuild_ground()
		"Walls":
			var q := wall_snap(p)
			for other in pieces:
				if other.type == "wall" and absf(other.x-q.x)<0.05 and absf(other.z-q.y)<0.05 and other.turn == wall_turned:
					return
			add_piece({"type":"wall", "x":q.x,"z":q.y,"turn":wall_turned,"raised":false,"opening":"none","color":item_color.to_html()})
		"Openings":
			var wall := nearest_wall(p)
			if wall.is_empty(): return
			wall.opening = "none" if opening_type == "Remove opening" else opening_type.to_lower()
			wall.window_width = window_width
			wall.window_height = window_height
			wall.window_sill = window_sill
			wall.door_width = door_width
			wall.door_height = door_height
			redraw_pieces()
		"Roof":
			var point := Vector2i(x,z)
			if roof_first_corner.x == -1:
				roof_first_corner = point
			else:
				var a := roof_first_corner
				roof_first_corner = Vector2i(-1,-1)
				var min_x := mini(a.x,point.x)
				var min_z := mini(a.y,point.y)
				var w := maxi(2,absi(a.x-point.x)+1)
				var d := maxi(2,absi(a.y-point.y)+1)
				add_piece({"type":"roof","x":min_x+w/2.0,"z":min_z+d/2.0,"w":w,"d":d,"pitch":roof_pitch,"roof_type":roof_type,"color":item_color.to_html()})
		"Furniture":
			add_piece({"type":"furniture","kind":furniture_type,"x":x+0.5,"z":z+0.5,"w":furniture_width,"d":furniture_depth,"h":furniture_height,"turn":wall_turned,"color":item_color.to_html()})


func add_piece(info: Dictionary) -> void:
	info.id = next_id
	info.faces = {}
	next_id += 1
	pieces.append(info)
	render_piece(info)


func nearest_wall(p: Vector3) -> Dictionary:
	var best := {}
	var dist := 0.84
	for part in pieces:
		if part.type != "wall": continue
		var d := Vector2(p.x-part.x,p.z-part.z).length()
		if d < dist:
			best = part
			dist = d
	return best


func find_piece(id: int) -> Dictionary:
	for part in pieces:
		if int(part.id) == id:
			return part
	return {}


func change_walls(raise: bool, all_walls: bool) -> void:
	var p := aim_point()
	var nearest := nearest_wall(p)
	for piece in pieces:
		if piece.type == "wall" and (all_walls or (not nearest.is_empty() and piece.id == nearest.id)):
			piece.raised = raise
	redraw_pieces()


func rotate_piece() -> void:
	wall_turned = not wall_turned


func delete_aimed() -> void:
	var target := aimed_piece()
	var id := int(target.get("id",-1))
	if id == -1:
		var wall := nearest_wall(aim_point())
		id = int(wall.get("id",-1))
	if id < 0: return
	for n in range(pieces.size()-1,-1,-1):
		if int(pieces[n].id) == id:
			pieces.remove_at(n)
			break
	redraw_pieces()


func aimed_piece() -> Dictionary:
	var mid := get_viewport().get_visible_rect().size*0.5
	var origin := camera.project_ray_origin(mid)
	var dir := camera.project_ray_normal(mid)
	var query := PhysicsRayQueryParameters3D.create(origin,origin+dir*120.0)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return {}
	var body: Object = hit.collider
	if not body.has_meta("item_id") or int(body.get_meta("item_id")) < 0:
		return {}
	return {"id":int(body.get_meta("item_id")),"component":int(body.get_meta("component_id")),"body":body,"normal":hit.normal}


func paint_aimed(whole: bool) -> void:
	var target := aimed_piece()
	if target.is_empty(): return
	var part := find_piece(target.id)
	if part.is_empty(): return
	if whole:
		part.color = paint_color.to_html()
		for other in target.body.get_parent().get_children():
			if other is StaticBody3D and other.has_meta("component_id"):
				var all_faces := []
				for f in 6: all_faces.append(paint_color.to_html())
				part.faces[str(other.get_meta("component_id"))] = all_faces
		redraw_pieces()
		return
	var body: StaticBody3D = target.body
	var mesh: MeshInstance3D = body.get_node("Surface")
	var comp := str(target.component)
	var data: Array = part.faces.get(comp,[])
	if data.size() != 6:
		data = []
		for i in 6: data.append(str(part.get("color","#cccccc")))
	var local_normal: Vector3 = body.global_transform.basis.inverse()*target.normal
	var face := Shape.face_from_local_normal(local_normal)
	data[face] = paint_color.to_html()
	part.faces[comp] = data
	var new_colors := []
	for c in data: new_colors.append(Color(c))
	Shape.recolor(body,new_colors)


func paint_whole_aimed() -> void:
	paint_aimed(true)


func redraw_pieces() -> void:
	if not is_instance_valid(built): return
	for child in built.get_children():
		child.queue_free()
	for part in pieces:
		render_piece(part)


func paintable_box(parent: Node3D, p: Vector3, size: Vector3, part: Dictionary, component: int, rotation: Vector3 = Vector3.ZERO, alt_color: String = "") -> void:
	var hex_color: String = alt_color if alt_color != "" else str(part.get("color","#d1d0c9"))
	var body: StaticBody3D = Shape.cube(parent,p,size,Color(hex_color),int(part.id),component,rotation)
	var color_list: Array = part.get("faces",{}).get(str(component),[])
	if color_list.size() == 6:
		var new_colors := []
		for face_hex in color_list:
			new_colors.append(Color(face_hex))
		Shape.recolor(body,new_colors)


func render_piece(part: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "%s_%s" % [part.type,part.id]
	root.position = Vector3(float(part.x),0,float(part.z))
	built.add_child(root)
	var item_id := int(part.id)
	match part.type:
		"fence":
			paintable_box(root,Vector3(0,float(part.h)/2,0),Vector3(float(part.w),float(part.h),float(part.d)),part,0)
		"wall":
			root.rotation.y = PI/2 if part.get("turn",false) else 0
			var h := 2.7 if part.get("raised",false) else 0.22
			var opening: String = str(part.get("opening","none"))
			if h < 0.3 or opening == "none":
				paintable_box(root,Vector3(0,h/2,0),Vector3(1,h,0.16),part,0)
			else:
				var is_window := opening == "window"
				var w := clampf(float(part.get("window_width",0.68) if is_window else part.get("door_width",0.8)),0.2,0.92)
				var sill := clampf(float(part.get("window_sill",0.95)) if is_window else 0.0,0.0,2.0)
				var gap_h := clampf(float(part.get("window_height",1.0) if is_window else part.get("door_height",2.1)),0.3,2.6-sill)
				var side := (1.0-w)/2
				paintable_box(root,Vector3(-(w+side)/2,h/2,0),Vector3(side,h,0.16),part,0)
				paintable_box(root,Vector3((w+side)/2,h/2,0),Vector3(side,h,0.16),part,1)
				if sill > 0.01:
					paintable_box(root,Vector3(0,sill/2,0),Vector3(w,sill,0.16),part,2)
				var header := h-sill-gap_h
				if header > 0.01:
					paintable_box(root,Vector3(0,h-header/2,0),Vector3(w,header,0.16),part,3)
			if opening != "none":
				var is_window := opening == "window"
				var w := float(part.get("window_width",0.68)) if is_window else float(part.get("door_width",0.8))
				var fh := float(part.get("window_height",1.0)) if is_window else float(part.get("door_height",2.1))
				var sill := float(part.get("window_sill",0.95)) if is_window else 0.0
				var preview := MeshInstance3D.new()
				var mesh := BoxMesh.new()
				mesh.size = Vector3(w,fh,0.045)
				preview.mesh = mesh
				preview.position = Vector3(0,sill+fh/2,0)
				preview.material_override = Shape.material(Color(0.28,0.75,0.95,0.3) if is_window else Color(0.95,0.72,0.3,0.28),true)
				root.add_child(preview)
		"roof":
			var w := float(part.w)+0.5
			var d := float(part.d)+0.5
			var a := deg_to_rad(float(part.get("pitch",25)))
			var rise := tan(a)*d/2
			if str(part.get("roof_type","Gable")) == "Shed":
				var sloping := d/cos(a)
				paintable_box(root,Vector3(0,2.7+rise,0),Vector3(w,0.15,sloping),part,0,Vector3(a,0,0))
			else:
				var length := (d/2)/cos(a)
				paintable_box(root,Vector3(0,2.7+rise/2,d/4),Vector3(w,0.15,length),part,0,Vector3(a,0,0))
				paintable_box(root,Vector3(0,2.7+rise/2,-d/4),Vector3(w,0.15,length),part,1,Vector3(-a,0,0))
		"tree":
			paintable_box(root,Vector3(0,0.58,0),Vector3(0.2,1.16,0.2),part,0,Vector3.ZERO,"#79553b")
			paintable_box(root,Vector3(0,1.43,0),Vector3(1.55,1.2,1.4),part,1,Vector3.ZERO,"#61945a")
		"furniture":
			root.rotation.y = PI/2 if part.get("turn",false) else 0
			var w := float(part.w)
			var d := float(part.d)
			var h := float(part.h)
			match str(part.get("kind","Sink")):
				"Table":
					paintable_box(root,Vector3(0,h-0.05,0),Vector3(w,0.1,d),part,0)
					for xx in [-1,1]:
						for zz in [-1,1]:
							paintable_box(root,Vector3(xx*(w/2-0.07),(h-0.10)/2,zz*(d/2-0.07)),Vector3(0.1,h-0.1,0.1),part,1+int(xx+1)+int((zz+1)/2))
				"Bed":
					paintable_box(root,Vector3(0,h*0.35,0),Vector3(w,h*0.7,d),part,0)
					paintable_box(root,Vector3(0,h*0.8,0),Vector3(w*0.95,h*0.2,d*0.95),part,1,Vector3.ZERO,"#e4e6dd")
				"Sofa":
					paintable_box(root,Vector3(0,h*0.3,0),Vector3(w,h*0.6,d),part,0)
					paintable_box(root,Vector3(0,h*0.72,-d*0.38),Vector3(w,h*0.55,d*0.22),part,1)
				"Sink":
					paintable_box(root,Vector3(0,h/2,0),Vector3(w,h,d),part,0)
					paintable_box(root,Vector3(0,h+0.035,0),Vector3(w+0.08,0.07,d+0.08),part,1,Vector3.ZERO,"#c2c9c8")
				_:
					paintable_box(root,Vector3(0,h/2,0),Vector3(w,h,d),part,0)


func save_project() -> void:
	var file := FileAccess.open(SAVE_FILE,FileAccess.WRITE)
	if file == null:
		if is_instance_valid(hint_label): hint_label.text = "Could not save file"
		return
	file.store_string(JSON.stringify({"version":1,"settings":settings,"cells":cells,"pieces":pieces,"next_id":next_id},"  "))
	file.close()
	if is_instance_valid(hint_label): hint_label.text = "Saved on this device"


func load_project() -> void:
	if not FileAccess.file_exists(SAVE_FILE): return
	var file := FileAccess.open(SAVE_FILE,FileAccess.READ)
	if file == null: return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary: return
	settings = parsed.get("settings",settings)
	cells = parsed.get("cells",{})
	pieces.clear()
	for data in parsed.get("pieces",[]):
		if data is Dictionary:
			pieces.append(data)
	next_id = int(parsed.get("next_id",pieces.size()+1))
	enter_game()
