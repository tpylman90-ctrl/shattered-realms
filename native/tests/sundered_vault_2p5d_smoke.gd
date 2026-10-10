extends SceneTree


func _initialize() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var packed_scene := load("res://scenes/SunderedVault.tscn") as PackedScene
	assert(packed_scene != null, "SunderedVault must load")
	var dungeon := packed_scene.instantiate()
	root.add_child(dungeon)
	await process_frame
	await process_frame
	assert(dungeon.get("camera") is Camera3D, "Dungeon needs a perspective camera")
	var camera := dungeon.get("camera") as Camera3D
	assert(camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "Character scale must come from camera depth")
	assert(camera.fov < 60.0, "Fixed camera should use the authored narrow perspective")
	var room_ids := ["entrance", "crossing", "gallery", "shrine", "bridge", "seal"]
	assert(dungeon.call("_room_ids").size() == room_ids.size(), "Sundered Vault must expose six connected rooms")
	var room_spawns := {
		"entrance": Vector2(0.50, 0.84),
		"crossing": Vector2(0.50, 0.83),
		"gallery": Vector2(0.50, 0.83),
		"shrine": Vector2(0.22, 0.55),
		"bridge": Vector2(0.50, 0.83),
		"seal": Vector2(0.50, 0.83)
	}
	for room_id_value in room_ids:
		var room_id := str(room_id_value)
		dungeon.call("_load_room", room_id, Vector2(0.50, 0.84), false)
		await process_frame
		var material := dungeon.get("background_material") as StandardMaterial3D
		assert(material != null and material.albedo_texture != null, "%s needs its painted room art" % room_id)
		var paths: Array = dungeon.get("screen_walk_paths")
		assert(not paths.is_empty(), "%s needs an authored walkmesh path" % room_id)
		var walkmesh := dungeon.get("walkmesh_body") as StaticBody3D
		assert(walkmesh != null and not walkmesh.get_children().is_empty(), "%s needs a 3D walkmesh collider" % room_id)
		for exit_data in dungeon.call("_exits_for_room", room_id):
			var exit_point: Vector2 = exit_data.get("point", Vector2.ZERO)
			assert(dungeon.call("_is_walkable_uv", exit_point), "%s exit %s must lie on a walkable path" % [room_id, str(exit_data.get("label", "door"))])
			var route: PackedVector2Array = dungeon.call("_find_walk_path", room_spawns[room_id], exit_point)
			assert(not route.is_empty(), "%s exit %s must be reachable on the walkmesh" % [room_id, str(exit_data.get("label", "door"))])
		for interaction in dungeon.call("_interactions_for_room", room_id):
			var point: Vector2 = interaction.get("point", Vector2.ZERO)
			assert(dungeon.call("_is_walkable_uv", point), "%s interaction %s must lie on a walkable path" % [room_id, str(interaction.get("id", "poi"))])
			var interaction_route: PackedVector2Array = dungeon.call("_find_walk_path", room_spawns[room_id], point)
			assert(not interaction_route.is_empty(), "%s interaction %s must be reachable" % [room_id, str(interaction.get("id", "poi"))])
	print("Sundered Vault 2.5D smoke passed: six painted rooms, perspective scaling, connected doors, and path-only walkmeshes.")
	quit(0)
