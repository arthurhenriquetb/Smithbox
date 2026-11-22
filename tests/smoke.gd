extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var scene: Node3D = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.start_from_setup()
	await process_frame
	assert(scene.live)
	assert(scene.terrain_mesh.mesh.get_surface_count() == 1)
	scene.add_piece({"type":"wall", "x":3.5,"z":4.0,"turn":false,"raised":false,"opening":"window","window_width":0.7,"window_height":1.0,"window_sill":1.0,"color":"#cccccc"})
	scene.add_piece({"type":"wall", "x":4.5,"z":4.0,"turn":false,"raised":true,"opening":"door","door_width":0.8,"door_height":2.1,"color":"#cccccc"})
	scene.add_piece({"type":"roof", "x":5.0,"z":6.0,"w":6,"d":6,"pitch":25.0,"roof_type":"Gable","color":"#985c4d"})
	scene.add_piece({"type":"furniture", "kind":"Table", "x":3.5,"z":3.5,"w":1.2,"d":0.8,"h":0.75,"turn":false,"color":"#c7a56d"})
	scene.add_piece({"type":"tree", "x":11.5,"z":11.5,"color":"#61945a"})
	var wall_parts: Node3D = scene.built.get_node("wall_5")
	var first_box: StaticBody3D = wall_parts.get_node("Part_5_0")
	var skin: MeshInstance3D = first_box.get_node("Surface")
	assert(skin.mesh.get_surface_count() == 1)
	scene.Shape.recolor(first_box,[Color.RED,Color.BLUE,Color.WHITE,Color.BLACK,Color.GRAY,Color.GREEN])
	assert((skin.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_COLOR].size() == 36)
	scene.cells["1:1"] = "dirt"
	scene.rebuild_ground()
	scene.save_project()
	assert(FileAccess.file_exists(scene.SAVE_FILE))
	assert(scene.built.get_child_count() >= 8)
	print("CASA_LIVRE_SMOKE_OK parts=",scene.pieces.size())
	quit(0)
