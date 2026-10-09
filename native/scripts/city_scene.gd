extends Control

const WORLD_DATA_PATH := "res://data/world_catalog.json"
const ASHENREACH_CITY_ART := "res://assets/cities/ashenreach_city.jpg"
const CAMPAIGN_SERVICE = preload("res://scripts/campaign_director.gd")
const HERO_EQUIPMENT_SERVICE = preload("res://scripts/hero_equipment.gd")
const HERO_PROGRESSION_SERVICE = preload("res://scripts/hero_progression.gd")
const SPRITE_FRAME_SIZE := Vector2i(24, 32)
const CITY_SAVE_PATH := "user://city_checkpoint.cfg"
const CITY_SCREENS := {
	"plaza": {"art": "res://assets/cities/ashenreach_city.jpg", "title": "ASHENREACH PLAZA", "spawn": Vector2(0.50, 0.70)},
	"market": {"art": "res://assets/cities/ashenreach/market.jpg", "title": "MARKET LANE", "spawn": Vector2(0.50, 0.75)},
	"forge": {"art": "res://assets/cities/ashenreach/forge.jpg", "title": "THE FORGE", "spawn": Vector2(0.50, 0.76)},
	"inn": {"art": "res://assets/cities/ashenreach/inn.jpg", "title": "THE WAYFARER'S INN", "spawn": Vector2(0.50, 0.76)},
	"keep": {"art": "res://assets/cities/ashenreach/keep.jpg", "title": "ASHENREACH KEEP", "spawn": Vector2(0.50, 0.80)},
	"gate": {"art": "res://assets/cities/ashenreach/gate.jpg", "title": "THE CITY GATE", "spawn": Vector2(0.50, 0.80)}
}

var world_data: Dictionary = {}
var territories: Dictionary = {}
var locations: Dictionary = {}
var region_id := "ashen_wastes"
var region_data: Dictionary = {}
var selected_location := "plaza"
var current_screen := "plaza"
var city_names: Array[String] = []

var background: TextureRect
var player_sprite: Sprite2D
var scene_back_button: Button
var city_title: Label
var city_subtitle: Label
var gold_label: Label
var info_title: Label
var info_body: Label
var action_button: Button
var gear_dialog: AcceptDialog
var hotspot_buttons: Array[Button] = []
var selection_layer: Control
var selection_content: VBoxContainer
var selection_status: Label
var joystick_area: Control
var joystick_vector := Vector2.ZERO
var joystick_touch_index := -1
var joystick_mouse_down := false
var b_button: Button
var mini_map_button: Button
var walking_tween: Tween
var walk_clock := 0.0
var walking := false
var player_direction := 0
var pending_location := ""


func _ready() -> void:
	region_id = str(get_tree().get_meta("city_region_id", "ashen_wastes"))
	_load_world_data()
	_build_city_view()
	resized.connect(_on_city_resized)
	_show_city_screen("plaza")
	_select_location("plaza")
	_restore_city_checkpoint()
	call_deferred("_on_city_resized")


func _process(delta: float) -> void:
	var movement := joystick_vector if joystick_vector.length() > 0.12 else Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if movement.length() > 0.12 and player_sprite and not (selection_layer and selection_layer.visible):
		movement = movement.normalized()
		player_direction = 2 if absf(movement.x) > absf(movement.y) and movement.x >= 0.0 else player_direction
		if absf(movement.x) > absf(movement.y) and movement.x < 0.0:
			player_direction = 1
		elif absf(movement.y) >= absf(movement.x):
			player_direction = 0 if movement.y > 0.0 else 3
		walking = true
		player_sprite.position += movement * 205.0 * delta
		player_sprite.position.x = clampf(player_sprite.position.x, 28.0, size.x - 28.0)
		player_sprite.position.y = clampf(player_sprite.position.y, 104.0, size.y - 160.0)
		queue_redraw()
	elif walking and not walking_tween:
		walking = false
		player_sprite.frame = player_direction * 4
	if not walking or not player_sprite:
		return
	walk_clock += delta
	var walk_phase := 1 if int(walk_clock / 0.14) % 2 == 0 else 3
	player_sprite.frame = player_direction * 4 + walk_phase
	queue_redraw()


func _draw() -> void:
	# Circular room minimap: the current room is central and nearby exits are plotted around it.
	var map_center := Vector2(size.x - 91.0, 165.0)
	draw_circle(map_center, 66.0, Color(0.015, 0.025, 0.03, 0.86))
	draw_arc(map_center, 66.0, 0.0, TAU, 64, Color("d0aa69"), 2.0, true)
	draw_arc(map_center, 43.0, 0.0, TAU, 48, Color(0.65, 0.58, 0.43, 0.38), 1.0, true)
	var exits := _screen_routes(current_screen)
	for index in range(exits.size()):
		var angle := -PI * 0.5 + TAU * float(index) / float(maxi(1, exits.size()))
		var point := map_center + Vector2(cos(angle), sin(angle)) * 43.0
		draw_line(map_center, point, Color(0.7, 0.57, 0.34, 0.5), 1.0, true)
		draw_circle(point, 4.2, Color("d0aa69"))
	draw_circle(map_center, 6.0, Color("f4e3b9"))
	# A subtle marker on the minimap shows where the hero is within the current room.
	var room_pos := Vector2((player_sprite.position.x / maxf(1.0, size.x) - 0.5) * 30.0, (player_sprite.position.y / maxf(1.0, size.y) - 0.65) * 24.0)
	draw_circle(map_center + room_pos, 3.0, Color("77d5a3"))
	var stick_center := Vector2(90.0, size.y - 102.0)
	draw_circle(stick_center, 59.0, Color(0.015, 0.025, 0.03, 0.68))
	draw_arc(stick_center, 59.0, 0.0, TAU, 48, Color(0.82, 0.69, 0.46, 0.72), 2.0, true)
	draw_line(stick_center + Vector2(-34.0, 0.0), stick_center + Vector2(34.0, 0.0), Color(0.75, 0.68, 0.54, 0.28), 1.0)
	draw_line(stick_center + Vector2(0.0, -34.0), stick_center + Vector2(0.0, 34.0), Color(0.75, 0.68, 0.54, 0.28), 1.0)
	draw_circle(stick_center + joystick_vector * 34.0, 22.0, Color(0.63, 0.48, 0.28, 0.82))
	draw_arc(stick_center + joystick_vector * 34.0, 22.0, 0.0, TAU, 32, Color("e0c28b"), 2.0, true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.keycode == KEY_BACKSPACE):
		_on_b_pressed()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
		_on_b_pressed()
		get_viewport().set_input_as_handled()
		return
	var target := Vector2(-1, -1)
	if event is InputEventScreenTouch and event.pressed:
		target = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		target = event.position
	if target.x < 0.0 or walking or (gear_dialog and gear_dialog.visible):
		return
	if target.y < 84.0 or target.y > size.y - 152.0:
		return
	_walk_player_to(target)


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
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var selection_button := _button("☰  SELECT", _open_selection)
	selection_button.anchor_left = 1.0
	selection_button.anchor_right = 1.0
	selection_button.offset_left = -168.0
	selection_button.offset_top = 84.0
	selection_button.offset_right = -18.0
	selection_button.offset_bottom = 128.0
	selection_button.z_index = 5
	add_child(selection_button)
	mini_map_button = _button("ROOM MAP", _open_selection_map)
	mini_map_button.anchor_left = 1.0
	mini_map_button.anchor_right = 1.0
	mini_map_button.offset_left = -151.0
	mini_map_button.offset_top = 191.0
	mini_map_button.offset_right = -31.0
	mini_map_button.offset_bottom = 225.0
	mini_map_button.z_index = 5
	add_child(mini_map_button)

	_build_city_hero()

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
	scene_back_button = _button("◀  CITY PLAZA", _return_to_plaza)
	scene_back_button.custom_minimum_size = Vector2(154, 52)
	scene_back_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	scene_back_button.visible = false
	bottom_row.add_child(scene_back_button)
	action_button = _button("", _activate_location)
	action_button.custom_minimum_size = Vector2(190, 52)
	action_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom_row.add_child(action_button)

	gear_dialog = AcceptDialog.new()
	gear_dialog.title = "CITY ARMORY"
	gear_dialog.ok_button_text = "CLOSE"
	gear_dialog.dialog_text = ""
	gear_dialog.size = Vector2i(470, 430)
	add_child(gear_dialog)
	_build_selection_layer()
	_build_touch_controls()

	if city_names.size() > 1:
		_build_city_selector(top_row)


func _build_touch_controls() -> void:
	joystick_area = Control.new()
	joystick_area.position = Vector2(18.0, size.y - 174.0)
	joystick_area.size = Vector2(144.0, 144.0)
	joystick_area.mouse_filter = Control.MOUSE_FILTER_STOP
	joystick_area.z_index = 8
	joystick_area.gui_input.connect(_on_joystick_input)
	add_child(joystick_area)
	b_button = _button("B", _on_b_pressed)
	b_button.custom_minimum_size = Vector2(72.0, 72.0)
	b_button.anchor_left = 1.0
	b_button.anchor_top = 1.0
	b_button.anchor_right = 1.0
	b_button.anchor_bottom = 1.0
	b_button.offset_left = -102.0
	b_button.offset_top = -112.0
	b_button.offset_right = -24.0
	b_button.offset_bottom = -34.0
	b_button.add_theme_font_size_override("font_size", 25)
	b_button.z_index = 8
	add_child(b_button)


func _build_selection_layer() -> void:
	selection_layer = Control.new()
	selection_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	selection_layer.visible = false
	selection_layer.z_index = 20
	add_child(selection_layer)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.015, 0.02, 0.76)
	selection_layer.add_child(shade)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.12
	panel.anchor_top = 0.10
	panel.anchor_right = 0.88
	panel.anchor_bottom = 0.90
	panel.add_theme_stylebox_override("panel", _panel_style(Color("11191b"), Color("c5a068")))
	selection_layer.add_child(panel)
	var margin := MarginContainer.new()
	_set_margins(margin, 18, 16, 18, 16)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)
	var heading := HBoxContainer.new()
	stack.add_child(heading)
	var title := _label("CITY SELECTION", 22, Color("f1dbac"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	heading.add_child(_button("✕  CLOSE", _close_selection))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	stack.add_child(tabs)
	tabs.add_child(_button("CITY MAP", _show_selection_map))
	tabs.add_child(_button("EQUIPMENT", _show_selection_equipment))
	tabs.add_child(_button("SAVE", _show_selection_save))
	selection_status = _label("Equipment and campaign rewards save automatically on this device.", 13, Color("aebbb9"))
	stack.add_child(selection_status)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(scroll)
	selection_content = VBoxContainer.new()
	selection_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_content.add_theme_constant_override("separation", 8)
	scroll.add_child(selection_content)
	_show_selection_map()


func _open_selection() -> void:
	joystick_vector = Vector2.ZERO
	selection_layer.visible = true
	_show_selection_map()


func _open_selection_map() -> void:
	_open_selection()
	_show_selection_map()


func _close_selection() -> void:
	selection_layer.visible = false


func _show_selection_map() -> void:
	_clear_selection_content()
	selection_status.text = "You are in %s. Select a room to travel there." % str(CITY_SCREENS.get(current_screen, {}).get("title", current_screen)).capitalize()
	for screen_id in ["plaza", "market", "forge", "inn", "keep", "gate"]:
		var item: Dictionary = CITY_SCREENS[screen_id]
		var label_text := ("●  " if screen_id == current_screen else "○  ") + str(item.get("title", screen_id))
	var route_button := _button(label_text, _travel_to_screen.bind(screen_id))
		route_button.custom_minimum_size.y = 48
		selection_content.add_child(route_button)


func _travel_to_screen(screen_id: String) -> void:
	_select_location(screen_id)
	_close_selection()


func _show_selection_equipment() -> void:
	_clear_selection_content()
	selection_status.text = "Your inventory, loadout, and gold are saved automatically as you earn or equip items."
	var loadout := HERO_EQUIPMENT_SERVICE.loadout(HERO_PROGRESSION_SERVICE.CHOSEN_HERO_ID)
	var catalog := HERO_EQUIPMENT_SERVICE.items()
	var has_equipment := false
	for slot in HERO_EQUIPMENT_SERVICE.SLOTS:
		var reference := str(loadout.get(slot, ""))
		if reference == "":
			continue
		has_equipment = true
		var item := HERO_EQUIPMENT_SERVICE.item_for(reference)
		selection_content.add_child(_label("%s  •  %s" % [str(slot).replace("_", " ").to_upper(), str(item.get("name", reference))], 16, Color("e6d3ab")))
	if not has_equipment:
		selection_content.add_child(_label("No equipment is currently assigned to the loadout.", 15, Color("d5ddda")))
	selection_content.add_child(_label("INVENTORY  •  %d items     ◈ %d GOLD" % [HERO_EQUIPMENT_SERVICE.inventory().size(), HERO_EQUIPMENT_SERVICE.gold()], 17, Color("f0cf7d")))
	var owned := HERO_EQUIPMENT_SERVICE.inventory()
	if owned.is_empty():
		selection_content.add_child(_label("No battle loot collected yet. Visit the forge after finding equipment.", 14, Color("aebbb9")))
	else:
		for reference in owned:
			var item: Dictionary = catalog.get(reference, {})
			selection_content.add_child(_label("%s  ·  %s" % [str(item.get("name", reference)), str(item.get("slot", "equipment")).replace("_", " ").capitalize()], 15, Color("d5ddda")))


func _show_selection_save() -> void:
	_clear_selection_content()
	selection_status.text = "Equipment, gold, and campaign progress are already written to this device as they change."
	selection_content.add_child(_label("Save your current city room and position as a checkpoint.", 16, Color("d5ddda")))
	selection_content.add_child(_button("SAVE CITY CHECKPOINT", _save_city_checkpoint))
	selection_content.add_child(_button("LOAD CITY CHECKPOINT", _load_city_checkpoint))


func _clear_selection_content() -> void:
	for child in selection_content.get_children():
		child.queue_free()


func _save_city_checkpoint() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(region_id, "screen", current_screen)
	cfg.set_value(region_id, "player_x", player_sprite.position.x / maxf(1.0, size.x))
	cfg.set_value(region_id, "player_y", player_sprite.position.y / maxf(1.0, size.y))
	cfg.set_value(region_id, "selected_location", selected_location)
	var result := cfg.save(CITY_SAVE_PATH)
	selection_status.text = "City checkpoint saved." if result == OK else "Could not write the city checkpoint."


func _load_city_checkpoint() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CITY_SAVE_PATH) != OK or not cfg.has_section_key(region_id, "screen"):
		selection_status.text = "No city checkpoint has been saved for this territory yet."
		return
	var screen := str(cfg.get_value(region_id, "screen", "plaza"))
	_show_city_screen(screen)
	selected_location = str(cfg.get_value(region_id, "selected_location", screen))
	player_sprite.position = Vector2(size.x * float(cfg.get_value(region_id, "player_x", 0.5)), size.y * float(cfg.get_value(region_id, "player_y", 0.7)))
	_select_location(selected_location)
	selection_status.text = "City checkpoint loaded."
	queue_redraw()


func _restore_city_checkpoint() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CITY_SAVE_PATH) != OK or not cfg.has_section_key(region_id, "screen"):
		return
	var screen := str(cfg.get_value(region_id, "screen", "plaza"))
	_show_city_screen(screen)
	selected_location = str(cfg.get_value(region_id, "selected_location", screen))
	player_sprite.position = Vector2(size.x * float(cfg.get_value(region_id, "player_x", 0.5)), size.y * float(cfg.get_value(region_id, "player_y", 0.7)))
	_select_location(selected_location)


func _on_joystick_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			joystick_touch_index = event.index
			_update_joystick(event.position)
		else:
			if event.index == joystick_touch_index:
				joystick_touch_index = -1
				joystick_vector = Vector2.ZERO
				queue_redraw()
	elif event is InputEventScreenDrag and event.index == joystick_touch_index:
		_update_joystick(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		joystick_mouse_down = event.pressed
		if event.pressed:
			_update_joystick(event.position)
		else:
			joystick_vector = Vector2.ZERO
			queue_redraw()
	elif event is InputEventMouseMotion and joystick_mouse_down:
		_update_joystick(event.position)


func _update_joystick(global_position: Vector2) -> void:
	var local := joystick_area.get_global_transform_with_canvas().affine_inverse() * global_position
	joystick_vector = ((local - joystick_area.size * 0.5) / 48.0).limit_length(1.0)
	if joystick_vector.length() > 0.12:
		if walking_tween and walking_tween.is_running():
			walking_tween.kill()
			walking_tween = null
			walking = false
	queue_redraw()


func _on_b_pressed() -> void:
	if selection_layer and selection_layer.visible:
		_close_selection()
	elif gear_dialog and gear_dialog.visible:
		gear_dialog.hide()
	elif current_screen != "plaza":
		_return_to_plaza()


func _screen_routes(screen_id: String) -> Array:
	match screen_id:
		"plaza": return ["market", "keep", "forge", "inn", "gate"]
		"market": return ["plaza", "keep", "forge", "inn", "gate"]
		"forge", "inn": return ["market"]
		"keep", "gate": return ["plaza"]
	return []


func _city_background() -> Texture2D:
	var screen_art := "res://assets/cities/%s/%s.jpg" % [region_id, current_screen]
	if ResourceLoader.exists(screen_art):
		return load(screen_art)
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
	player_sprite = Sprite2D.new()
	player_sprite.texture = _build_pixel_sprite_sheet()
	player_sprite.hframes = 4
	player_sprite.vframes = 4
	player_sprite.frame = 0
	player_sprite.scale = Vector2(2.35, 2.35)
	player_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player_sprite.z_index = 0
	add_child(player_sprite)


func _build_pixel_sprite_sheet() -> Texture2D:
	var image := Image.create(SPRITE_FRAME_SIZE.x * 4, SPRITE_FRAME_SIZE.y * 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var profile := HERO_PROGRESSION_SERVICE.chosen_hero_appearance()
	var skin := Color("d39a70")
	match str(profile.get("skin_tone", "Olive")).to_lower():
		"light": skin = Color("efc29d")
		"brown": skin = Color("a96845")
		"deep": skin = Color("74442f")
	var hair := Color("463024")
	match str(profile.get("hair_color", "Brown")).to_lower():
		"black": hair = Color("211c20")
		"auburn": hair = Color("8a3f28")
		"silver": hair = Color("b8bec2")
	var tunic := Color("775139")
	match str(profile.get("starting_class_id", "warrior")):
		"warrior": tunic = Color("8a3d36")
		"ranger": tunic = Color("41624c")
		"black_mage": tunic = Color("56416f")
		"white_mage": tunic = Color("d4c8a6")
	var pants := Color("39404b")
	var boots := Color("30251f")
	var belt := Color("c0904e")
	for direction in range(4):
		for frame_index in range(4):
			var cell_x := frame_index * SPRITE_FRAME_SIZE.x
			var cell_y := direction * SPRITE_FRAME_SIZE.y
			var stride := 0
			if frame_index == 1:
				stride = -2
			elif frame_index == 3:
				stride = 2
			_paint_pixel_rect(image, cell_x, cell_y, 6, 28, 12, 2, Color(0.05, 0.05, 0.06, 0.34))
			if direction == 0:
				_paint_pixel_rect(image, cell_x, cell_y, 8, 3, 8, 3, hair)
				_paint_pixel_rect(image, cell_x, cell_y, 7, 5, 2, 7, hair)
				_paint_pixel_rect(image, cell_x, cell_y, 15, 5, 2, 7, hair)
				_paint_pixel_rect(image, cell_x, cell_y, 9, 5, 6, 7, skin)
				_paint_pixel_rect(image, cell_x, cell_y, 10, 8, 1, 1, Color("302720"))
				_paint_pixel_rect(image, cell_x, cell_y, 13, 8, 1, 1, Color("302720"))
			elif direction == 3:
				_paint_pixel_rect(image, cell_x, cell_y, 8, 3, 8, 9, hair)
				_paint_pixel_rect(image, cell_x, cell_y, 7, 6, 2, 7, hair)
				_paint_pixel_rect(image, cell_x, cell_y, 15, 6, 2, 7, hair)
			else:
				_paint_pixel_rect(image, cell_x, cell_y, 8, 3, 8, 3, hair)
				_paint_pixel_rect(image, cell_x, cell_y, 7, 5, 3, 7, hair)
				_paint_pixel_rect(image, cell_x, cell_y, 10, 5, 5, 7, skin)
				if direction == 1:
					_paint_pixel_rect(image, cell_x, cell_y, 8, 8, 1, 1, Color("302720"))
					_paint_pixel_rect(image, cell_x, cell_y, 14, 9, 2, 2, skin.lightened(0.16))
				else:
					_paint_pixel_rect(image, cell_x, cell_y, 15, 8, 1, 1, Color("302720"))
					_paint_pixel_rect(image, cell_x, cell_y, 8, 9, 2, 2, skin.lightened(0.16))
			var arm_swing := int(stride / 2)
			_paint_pixel_rect(image, cell_x, cell_y, 5, 13 + arm_swing, 3, 8, tunic.darkened(0.08))
			_paint_pixel_rect(image, cell_x, cell_y, 16, 13 - arm_swing, 3, 8, tunic.darkened(0.08))
			_paint_pixel_rect(image, cell_x, cell_y, 5, 19 + arm_swing, 3, 2, skin)
			_paint_pixel_rect(image, cell_x, cell_y, 16, 19 - arm_swing, 3, 2, skin)
			_paint_pixel_rect(image, cell_x, cell_y, 7, 12, 10, 11, tunic)
			_paint_pixel_rect(image, cell_x, cell_y, 9, 12, 6, 2, tunic.lightened(0.18))
			_paint_pixel_rect(image, cell_x, cell_y, 7, 21, 10, 2, belt)
			_paint_pixel_rect(image, cell_x, cell_y, 11, 21, 2, 2, Color("e0b765"))
			_paint_pixel_rect(image, cell_x, cell_y, 8 + stride, 23, 4, 5, pants)
			_paint_pixel_rect(image, cell_x, cell_y, 12 - stride, 23, 4, 5, pants.darkened(0.08))
			_paint_pixel_rect(image, cell_x, cell_y, 7 + stride, 27, 5, 2, boots)
			_paint_pixel_rect(image, cell_x, cell_y, 12 - stride, 27, 5, 2, boots)
	return ImageTexture.create_from_image(image)


func _paint_pixel_rect(image: Image, cell_x: int, cell_y: int, x: int, y: int, width: int, height: int, color: Color) -> void:
	for pixel_y in range(y, y + height):
		for pixel_x in range(x, x + width):
			image.set_pixel(cell_x + pixel_x, cell_y + pixel_y, color)


func _add_hotspot(id: String, label_text: String, point: Vector2) -> void:
	var hotspot := _button(label_text, _on_hotspot_pressed.bind(id, point))
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
	hotspot_buttons.append(hotspot)


func _on_hotspot_pressed(id: String, point: Vector2) -> void:
	_walk_to_location(id, Vector2(size.x * point.x, size.y * point.y))


func _walk_to_location(location_id: String, destination: Vector2) -> void:
	pending_location = location_id
	_walk_player_to(destination)


func _walk_player_to(destination: Vector2) -> void:
	if not player_sprite:
		return
	for hotspot in hotspot_buttons:
		hotspot.disabled = true
	if scene_back_button:
		scene_back_button.disabled = true
	if action_button:
		action_button.disabled = true
	var safe_target := Vector2(
		clampf(destination.x, 28.0, size.x - 28.0),
		clampf(destination.y, 104.0, size.y - 160.0)
	)
	var travel := safe_target - player_sprite.position
	if absf(travel.x) > absf(travel.y):
		player_direction = 2 if travel.x >= 0.0 else 1
	else:
		player_direction = 0 if travel.y >= 0.0 else 3
	player_sprite.frame = player_direction * 4 + 1
	walk_clock = 0.0
	walking = true
	var duration := clampf(travel.length() / 260.0, 0.18, 1.6)
	walking_tween = create_tween()
	walking_tween.set_trans(Tween.TRANS_SINE)
	walking_tween.set_ease(Tween.EASE_IN_OUT)
	walking_tween.tween_property(player_sprite, "position", safe_target, duration)
	walking_tween.finished.connect(_finish_walk)


func _finish_walk() -> void:
	walking = false
	walking_tween = null
	player_sprite.frame = player_direction * 4
	for hotspot in hotspot_buttons:
		hotspot.disabled = false
	if scene_back_button:
		scene_back_button.disabled = false
	if action_button:
		action_button.disabled = false
	var destination := pending_location
	pending_location = ""
	if destination != "":
		_select_location(destination)


func _on_city_resized() -> void:
	if joystick_area:
		joystick_area.position = Vector2(18.0, size.y - 174.0)
	if not player_sprite:
		return
	player_sprite.position.x = clampf(player_sprite.position.x, 28.0, size.x - 28.0)
	player_sprite.position.y = clampf(player_sprite.position.y, 104.0, size.y - 160.0)
	queue_redraw()


func _refresh_hotspots() -> void:
	for hotspot in hotspot_buttons:
		if is_instance_valid(hotspot):
			hotspot.queue_free()
	hotspot_buttons.clear()
	var routes: Array = []
	match current_screen:
		"plaza":
			routes = [
				["market", "MARKET LANE", Vector2(0.19, 0.43)],
				["keep", "KEEP", Vector2(0.52, 0.18)],
				["forge", "FORGE", Vector2(0.27, 0.49)],
				["inn", "INN", Vector2(0.70, 0.53)],
				["gate", "GATE", Vector2(0.87, 0.43)]
			]
		"market":
			routes = [
				["plaza", "PLAZA", Vector2(0.12, 0.48)],
				["keep", "KEEP", Vector2(0.53, 0.18)],
				["forge", "FORGE", Vector2(0.25, 0.46)],
				["inn", "INN", Vector2(0.75, 0.46)],
				["gate", "GATE", Vector2(0.88, 0.47)]
			]
		"forge":
			routes = [["market", "BACK TO MARKET", Vector2(0.50, 0.20)]]
		"inn":
			routes = [["market", "BACK TO MARKET", Vector2(0.50, 0.20)]]
		"keep":
			routes = [["plaza", "BACK TO PLAZA", Vector2(0.50, 0.20)]]
		"gate":
			routes = [["plaza", "RETURN TO CITY", Vector2(0.50, 0.20)]]
	for route in routes:
		_add_hotspot(str(route[0]), str(route[1]), route[2])


func _show_city_screen(screen_id: String, place_hero: bool = true) -> void:
	if not CITY_SCREENS.has(screen_id):
		screen_id = "plaza"
	current_screen = screen_id
	var screen: Dictionary = CITY_SCREENS[screen_id]
	if region_id == "ashen_wastes":
		var art_path := str(screen.get("art", ASHENREACH_CITY_ART))
		if ResourceLoader.exists(art_path):
			background.texture = load(art_path)
		else:
			background.texture = _city_background()
	else:
		background.texture = _city_background()
	city_title.text = str(screen.get("title", city_names[0].to_upper())) if region_id == "ashen_wastes" else city_names[0].to_upper()
	city_subtitle.text = str(region_data.get("name", region_id.replace("_", " ").capitalize())).to_upper()
	scene_back_button.visible = current_screen != "plaza"
	if place_hero:
		var spawn: Vector2 = screen.get("spawn", Vector2(0.5, 0.72))
		player_sprite.position = Vector2(size.x * spawn.x, size.y * spawn.y)
		player_sprite.frame = 0
	_refresh_hotspots()
	queue_redraw()


func _select_location(id: String) -> void:
	selected_location = id
	if CITY_SCREENS.has(id) and id != current_screen:
		_show_city_screen(id)
	var descriptions := {
		"plaza": ["ASHENREACH PLAZA", "The roads meet beneath the keep. Tap or click the ground to walk; choose a marked place to explore it."],
		"market": ["MARKET LANE", "Stalls, smiths, and travelers crowd the old stone road. The forge and inn are just ahead."],
		"keep": ["THE KEEP", "The stronghold's beacon chamber overlooks the roads between territories."],
		"forge": ["THE FORGE", "Review the equipment recovered from battles and regional expeditions."],
		"inn": ["THE INN", "Rest your hero before returning to the roads beyond the city walls."],
		"gate": ["THE CITY GATE", "Choose a route out of the city and return to the territory board."]
	}
	var data: Array = descriptions.get(id, descriptions["plaza"])
	info_title.text = str(data[0])
	info_body.text = "%s\n\nTap or click the floor to walk." % str(data[1])
	match id:
		"market", "forge": action_button.text = "BROWSE REGIONAL GEAR"
		"inn": action_button.text = "REST • 25 GOLD"
		"gate": action_button.text = "ENTER TERRITORY"
		_: action_button.text = "VIEW OPEN ROUTES"
	scene_back_button.visible = current_screen != "plaza"


func _activate_location() -> void:
	match selected_location:
		"market", "forge":
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


func _return_to_plaza() -> void:
	_walk_to_location("plaza", Vector2(size.x * 0.5, size.y * 0.68))


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
