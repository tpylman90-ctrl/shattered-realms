extends Control

const WORLD_DATA_PATH := "res://data/world_catalog.json"
const ASHENREACH_CITY_ART := "res://assets/cities/ashenreach_city.jpg"
const CAMPAIGN_SERVICE = preload("res://scripts/campaign_director.gd")
const HERO_EQUIPMENT_SERVICE = preload("res://scripts/hero_equipment.gd")
const HERO_PROGRESSION_SERVICE = preload("res://scripts/hero_progression.gd")

var world_data: Dictionary = {}
var territories: Dictionary = {}
var locations: Dictionary = {}
var region_id := "ashen_wastes"
var region_data: Dictionary = {}
var selected_location := "keep"
var city_names: Array[String] = []

var background: TextureRect
var city_title: Label
var city_subtitle: Label
var gold_label: Label
var info_title: Label
var info_body: Label
var action_button: Button
var gear_dialog: AcceptDialog


func _ready() -> void:
	region_id = str(get_tree().get_meta("city_region_id", "ashen_wastes"))
	_load_world_data()
	_build_city_view()
	_select_location("keep")


func _load_world_data() -> void:
	if not FileAccess.file_exists(WORLD_DATA_PATH):
		return
	var file := FileAccess.open(WORLD_DATA_PATH, FileAccess.READ)
	if not file:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	world_data = parsed
	territories = world_data.get("territories", {})
	locations = world_data.get("locations", {})
	region_data = territories.get(region_id, {})
	var stronghold := str(region_data.get("stronghold", ""))
	if stronghold != "":
		city_names.append(stronghold)
	for location_id in region_data.get("locations", []):
		var city := str(locations.get(str(location_id), {}).get("name", location_id))
		if not city_names.has(city):
			city_names.append(city)
	if city_names.is_empty():
		city_names.append(str(region_data.get("name", region_id.replace("_", " ").capitalize())))


func _build_city_view() -> void:
	background = TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture = _city_background()
	add_child(background)

	var top_bar := PanelContainer.new()
	top_bar.anchor_right = 1.0
	top_bar.offset_bottom = 76.0
	top_bar.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.035, 0.04, 0.88), Color("c5a068")))
	add_child(top_bar)
	var top_margin := MarginContainer.new()
	_set_margins(top_margin, 18, 14, 18, 14)
	top_bar.add_child(top_margin)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 16)
	top_margin.add_child(top_row)
	var back_button := _button("◀  WORLD ATLAS", _return_to_atlas)
	back_button.custom_minimum_size.x = 180
	top_row.add_child(back_button)
	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 0)
	top_row.add_child(title_stack)
	city_title = _label(city_names[0].to_upper(), 23, Color("f1dbac"))
	title_stack.add_child(city_title)
	city_subtitle = _label(str(region_data.get("name", region_id.replace("_", " ").capitalize())).to_upper(), 12, Color("aebbb9"))
	title_stack.add_child(city_subtitle)
	gold_label = _label("◈ %d GOLD" % HERO_EQUIPMENT_SERVICE.gold(), 16, Color("f0cf7d"))
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_row.add_child(gold_label)

	_build_city_hero()
	_add_hotspot("keep", "KEEP", Vector2(0.52, 0.17))
	_add_hotspot("forge", "FORGE", Vector2(0.27, 0.49))
	_add_hotspot("inn", "INN", Vector2(0.70, 0.53))
	_add_hotspot("gate", "GATE", Vector2(0.88, 0.43))

	var bottom_panel := PanelContainer.new()
	bottom_panel.anchor_left = 0.12
	bottom_panel.anchor_top = 1.0
	bottom_panel.anchor_right = 0.88
	bottom_panel.anchor_bottom = 1.0
	bottom_panel.offset_top = -148.0
	bottom_panel.offset_bottom = -14.0
	bottom_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.04, 0.045, 0.94), Color("c5a068")))
	add_child(bottom_panel)
	var bottom_margin := MarginContainer.new()
	_set_margins(bottom_margin, 18, 12, 18, 12)
	bottom_panel.add_child(bottom_margin)
	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 22)
	bottom_margin.add_child(bottom_row)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 4)
	bottom_row.add_child(copy)
	info_title = _label("", 21, Color("f0d59e"))
	copy.add_child(info_title)
	info_body = _label("", 14, Color("d5ddda"))
	info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(info_body)
	action_button = _button("", _activate_location)
	action_button.custom_minimum_size = Vector2(190, 52)
	action_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom_row.add_child(action_button)

	gear_dialog = AcceptDialog.new()
	gear_dialog.title = "CITY ARMORY"
	gear_dialog.ok_button_text = "CLOSE"
	gear_dialog.dialog_text = ""
	gear_dialog.custom_minimum_size = Vector2(470, 430)
	add_child(gear_dialog)

	if city_names.size() > 1:
		_build_city_selector(top_row)


func _city_background() -> Texture2D:
	var direct_path := "res://assets/cities/%s.png" % region_id
	if ResourceLoader.exists(direct_path):
		return load(direct_path)
	var city_art := "res://assets/boards/concept/%s.webp" % region_id
	if ResourceLoader.exists(city_art):
		return load(city_art)
	var board_art := "res://assets/territory_boards/%s.webp" % region_id
	if ResourceLoader.exists(board_art):
		return load(board_art)
	return load(ASHENREACH_CITY_ART)


func _build_city_selector(parent: HBoxContainer) -> void:
	var selector := HBoxContainer.new()
	selector.add_theme_constant_override("separation", 6)
	parent.add_child(selector)
	for city_index in range(city_names.size()):
		var name := city_names[city_index]
		var choice := _button(name.to_upper(), func(): _select_city(name))
		choice.custom_minimum_size.x = 110
		selector.add_child(choice)


func _select_city(city_name: String) -> void:
	city_title.text = city_name.to_upper()
	city_subtitle.text = str(region_data.get("name", region_id.replace("_", " ").capitalize())).to_upper()
	_select_location(selected_location)


func _build_city_hero() -> void:
	var container := SubViewportContainer.new()
	container.anchor_left = 0.50
	container.anchor_top = 0.48
	container.anchor_right = 0.50
	container.anchor_bottom = 0.48
	container.offset_left = -54.0
	container.offset_top = -88.0
	container.offset_right = 54.0
	container.offset_bottom = 88.0
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 416)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-28, -22, 0)
	light.light_energy = 1.8
	world.add_child(light)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.2, 5.2)
	camera.look_at(Vector3(0, 1.05, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.0
	camera.current = true
	world.add_child(camera)
	var hero_scene := load("res://scenes/ChosenHeroPiece.tscn") as PackedScene
	if hero_scene:
		var hero := hero_scene.instantiate()
		var profile := HERO_PROGRESSION_SERVICE.chosen_hero_appearance()
		if not profile.is_empty():
			hero.call("set_profile", profile)
		world.add_child(hero)


func _add_hotspot(id: String, label_text: String, point: Vector2) -> void:
	var hotspot := _button(label_text, func(): _select_location(id))
	hotspot.anchor_left = point.x
	hotspot.anchor_top = point.y
	hotspot.anchor_right = point.x
	hotspot.anchor_bottom = point.y
	hotspot.offset_left = -58.0
	hotspot.offset_top = -23.0
	hotspot.offset_right = 58.0
	hotspot.offset_bottom = 23.0
	hotspot.add_theme_font_size_override("font_size", 13)
	add_child(hotspot)


func _select_location(id: String) -> void:
	selected_location = id
	var descriptions := {
		"keep": ["THE KEEP", "The stronghold's beacon chamber overlooks the roads between territories."],
		"forge": ["THE FORGE", "Review the equipment recovered from battles and regional expeditions."],
		"inn": ["THE INN", "Rest your hero before returning to the roads beyond the city walls."],
		"gate": ["THE CITY GATE", "Choose a route out of the city and return to the territory board."]
	}
	var data: Array = descriptions.get(id, descriptions["keep"])
	info_title.text = str(data[0])
	info_body.text = str(data[1])
	match id:
		"forge": action_button.text = "BROWSE REGIONAL GEAR"
		"inn": action_button.text = "REST • 25 GOLD"
		"gate": action_button.text = "ENTER TERRITORY"
		_: action_button.text = "VIEW OPEN ROUTES"


func _activate_location() -> void:
	match selected_location:
		"forge":
			_show_armory()
		"inn":
			_rest_at_inn()
		"gate":
			_enter_territory()
		_:
			var open := CAMPAIGN_SERVICE.open_routes()
			var names: PackedStringArray = []
			for territory_id in open:
				names.append(str(CAMPAIGN_SERVICE.territory(territory_id).get("name", territory_id)))
			info_body.text = "Open routes: %s" % (", ".join(names) if not names.is_empty() else "secure a connected territory to reopen the roads")


func _show_armory() -> void:
	var pool := HERO_EQUIPMENT_SERVICE.region_pool(region_id)
	var item_catalog := HERO_EQUIPMENT_SERVICE.items()
	var lines: PackedStringArray = ["PURSE: %d GOLD" % HERO_EQUIPMENT_SERVICE.gold(), "", "Regional designs:"]
	for item_id in pool.get("common", []):
		lines.append("• %s" % str(item_catalog.get(str(item_id), {}).get("name", item_id)))
	var signature := str(pool.get("signature", ""))
	if signature != "":
		lines.append("• %s  (signature)" % str(item_catalog.get(signature, {}).get("name", signature)))
	if pool.is_empty():
		lines.append("No regional gear designs are listed here yet.")
	var owned_items := HERO_EQUIPMENT_SERVICE.inventory()
	lines.append("\nFound: %d equipment templates" % owned_items.size())
	gear_dialog.dialog_text = "\n".join(lines)
	gear_dialog.popup_centered()


func _rest_at_inn() -> void:
	const REST_COST := 25
	if not HERO_EQUIPMENT_SERVICE.spend_gold(REST_COST):
		info_body.text = "Rest costs %d gold. Earn more by winning battles." % REST_COST
		return
	if region_id == "ashen_wastes":
		var save := ConfigFile.new()
		save.load("user://ashenreach_save.cfg")
		save.set_value("board", "hero_health", 100)
		save.save("user://ashenreach_save.cfg")
	gold_label.text = "◈ %d GOLD" % HERO_EQUIPMENT_SERVICE.gold()
	info_body.text = "Your hero is rested and ready for the road. 25 gold paid."


func _enter_territory() -> void:
	if not CAMPAIGN_SERVICE.is_route_open(region_id) and not (CAMPAIGN_SERVICE.state().get("secured_territories", []) as Array).has(region_id):
		info_body.text = "This city's road is sealed. Reconnect a neighboring territory first."
		return
	get_tree().set_meta("preview_territory", region_id)
	var scene_path := "res://scenes/TerritoryBoardPreview.tscn"
	if region_id == "ashen_wastes":
		scene_path = "res://scenes/AshenreachDemo.tscn"
	elif region_id == "ravenwood":
		scene_path = "res://scenes/RavenwoodPreview.tscn"
	elif region_id == "iron_plains":
		scene_path = "res://scenes/IronPlainsPreview.tscn"
	elif region_id == "golden_expanse":
		scene_path = "res://scenes/GoldenExpansePreview.tscn"
	get_tree().change_scene_to_file(scene_path)


func _return_to_atlas() -> void:
	get_tree().set_meta("city_return_region", region_id)
	get_tree().change_scene_to_file("res://scenes/FrontEnd.tscn")


func _panel_style(color: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style


func _button(text_value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 42
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.035, 0.055, 0.06, 0.88), Color("92764e")))
	button.add_theme_stylebox_override("hover", _panel_style(Color(0.12, 0.14, 0.13, 0.95), Color("f0cc83")))
	button.add_theme_color_override("font_color", Color("f0e0c2"))
	button.pressed.connect(action)
	return button


func _label(text_value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _set_margins(container: MarginContainer, left: int, top: int, right: int, bottom: int) -> void:
	container.add_theme_constant_override("margin_left", left)
	container.add_theme_constant_override("margin_top", top)
	container.add_theme_constant_override("margin_right", right)
	container.add_theme_constant_override("margin_bottom", bottom)
