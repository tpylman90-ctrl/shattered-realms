extends SceneTree


func _initialize() -> void:
	set_meta("city_region_id", "stormcrown_mountains")
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var packed_scene := load("res://scenes/CityScene.tscn") as PackedScene
	assert(packed_scene != null, "CityScene must load")
	var city := packed_scene.instantiate()
	root.add_child(city)
	await process_frame
	await process_frame
	assert(str(city.get("region_id")) == "stormcrown_mountains", "Stormcrown profile must be selected")
	var screens: Dictionary = city.call("_city_screens")
	assert(screens.size() == 11, "Stormcrown must expose all eleven locations")
	var city_size: Vector2 = city.get("size")
	for screen_value in screens.keys():
		var screen_id := str(screen_value)
		city.call("_show_city_screen", screen_id, false)
		await process_frame
		var background := city.get("background") as TextureRect
		assert(background != null and background.texture != null, "%s must load its background" % screen_id)
		var room_3d: Node = city.get("city_room_3d")
		assert(room_3d != null and int(room_3d.call("depth_layer_count")) >= 5, "%s must load foreground and midground layers" % screen_id)
		var walkable: Array = city.get("walkable_polygons")
		assert(not walkable.is_empty(), "%s must define a walk surface" % screen_id)
		for transition in city.call("_transitions_for_screen", screen_id):
			var exit_point: Vector2 = transition.get("point", Vector2.ZERO)
			assert(city.call("_is_walkable_position", city_size * exit_point), "%s exit %s must be reachable by walking" % [screen_id, str(transition.get("label", "door"))])
	print("Stormcrown city smoke passed: %d rooms, backgrounds, 3D depth layers, walk surfaces, and reachable exits." % screens.size())
	quit(0)
