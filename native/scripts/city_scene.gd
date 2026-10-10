extends Control

const WORLD_DATA_PATH := "res://data/world_catalog.json"
const ASHENREACH_CITY_ART := "res://assets/cities/ashenreach/ashenreach_crossroads.webp"
const ASHENREACH_DEPTH_CARD_PATHS := {
	"balustrade": "res://assets/cities/ashenreach/foreground/basalt_balustrade.png",
	"brazier": "res://assets/cities/ashenreach/foreground/iron_brazier.png",
	"lantern": "res://assets/cities/ashenreach/foreground/street_lantern.png",
	"banner": "res://assets/cities/ashenreach/foreground/crimson_banner.png"
}
const CAMPAIGN_SERVICE = preload("res://scripts/campaign_director.gd")
const HERO_EQUIPMENT_SERVICE = preload("res://scripts/hero_equipment.gd")
const HERO_PROGRESSION_SERVICE = preload("res://scripts/hero_progression.gd")
const SPRITE_FRAME_SIZE := Vector2i(24, 32)
const CITY_SAVE_PATH := "user://city_checkpoint.cfg"
const CITY_STORY_PATH := "user://city_story.cfg"
const CITY_NETWORK_PATH := "user://city_network.cfg"
const CITY_NAV_CELL_SIZE := 24.0
const CITY_SCREENS := {
	"plaza": {"art": "res://assets/cities/ashenreach/ashenreach_crossroads_depth_plate.webp", "title": "CITADEL CROSSROADS", "district": "THE CENTRAL WARD", "spawn": Vector2(0.50, 0.70)},
	"market": {"art": "res://assets/cities/ashenreach/cinder_market.webp", "title": "CINDER MARKET", "district": "THE COMMERCE WARD", "spawn": Vector2(0.50, 0.72)},
	"living": {"art": "res://assets/cities/ashenreach/living_quarter.webp", "title": "LIVING QUARTER", "district": "THE LOWER WARD", "spawn": Vector2(0.50, 0.74)},
	"forge": {"art": "res://assets/cities/ashenreach/cinder_foundry.webp", "title": "THE CINDER FOUNDRY", "district": "THE COMMERCE WARD", "spawn": Vector2(0.52, 0.72)},
	"inn": {"art": "res://assets/cities/ashenreach/wayfarer_inn.webp", "title": "THE WAYFARER'S INN", "district": "THE LOWER WARD", "spawn": Vector2(0.50, 0.76)},
	"keep": {"art": "res://assets/cities/ashenreach/keep_hall.webp", "title": "ASHENREACH KEEP", "district": "THE CITADEL", "spawn": Vector2(0.52, 0.76)},
	"gate": {"art": "res://assets/cities/ashenreach/outer_gate.webp", "title": "THE OUTER GATE", "district": "THE FRONTIER WARD", "spawn": Vector2(0.50, 0.76)}
}
const CITY_TRANSITIONS := {
	"plaza": [
		{"to": "market", "label": "CINDER MARKET", "point": Vector2(0.25, 0.53), "radius": Vector2(0.06, 0.07), "spawn": Vector2(0.37, 0.78)},
		{"to": "living", "label": "LIVING QUARTER", "point": Vector2(0.75, 0.53), "radius": Vector2(0.06, 0.07), "spawn": Vector2(0.65, 0.78)},
		{"to": "keep", "label": "THE KEEP", "point": Vector2(0.50, 0.23), "radius": Vector2(0.08, 0.05), "spawn": Vector2(0.50, 0.72)},
		{"to": "gate", "label": "OUTER GATE", "point": Vector2(0.50, 0.80), "radius": Vector2(0.08, 0.035), "spawn": Vector2(0.50, 0.38)}
	],
	"market": [
		{"to": "plaza", "label": "CENTRAL WARD", "point": Vector2(0.50, 0.17), "radius": Vector2(0.07, 0.05), "spawn": Vector2(0.50, 0.66)},
		{"to": "forge", "label": "CINDER FOUNDRY", "point": Vector2(0.24, 0.48), "radius": Vector2(0.06, 0.07), "spawn": Vector2(0.78, 0.60)},
		{"to": "living", "label": "LOWER WARD ALLEY", "point": Vector2(0.25, 0.68), "radius": Vector2(0.06, 0.07), "spawn": Vector2(0.38, 0.77)}
	],
	"living": [
		{"to": "plaza", "label": "CENTRAL WARD", "point": Vector2(0.50, 0.17), "radius": Vector2(0.07, 0.05), "spawn": Vector2(0.50, 0.66)},
		{"to": "market", "label": "CINDER MARKET", "point": Vector2(0.16, 0.68), "radius": Vector2(0.06, 0.07), "spawn": Vector2(0.38, 0.77)},
		{"to": "inn", "label": "WAYFARER'S INN", "point": Vector2(0.76, 0.51), "radius": Vector2(0.06, 0.07), "spawn": Vector2(0.82, 0.66)}
	],
	"forge": [
		{"to": "market", "label": "CINDER MARKET", "point": Vector2(0.66, 0.32), "radius": Vector2(0.055, 0.045), "spawn": Vector2(0.72, 0.55)}
	],
	"inn": [
		{"to": "living", "label": "LIVING QUARTER", "point": Vector2(0.14, 0.28), "radius": Vector2(0.06, 0.06), "spawn": Vector2(0.38, 0.77)}
	],
	"keep": [
		{"to": "plaza", "label": "CENTRAL WARD", "point": Vector2(0.12, 0.25), "radius": Vector2(0.06, 0.07), "spawn": Vector2(0.50, 0.42)}
	],
	"gate": [
		{"to": "plaza", "label": "CITADEL CROSSROADS", "point": Vector2(0.50, 0.19), "radius": Vector2(0.08, 0.05), "spawn": Vector2(0.50, 0.64)},
		{"to": "territory", "label": "FRONTIER ROAD", "point": Vector2(0.50, 0.79), "radius": Vector2(0.08, 0.035), "spawn": Vector2.ZERO}
	]
}
const CITY_POIS := {
	"plaza": [
		{"id": "fallen_standard", "label": "INSPECT FALLEN STANDARD", "kind": "lore", "point": Vector2(0.68, 0.61), "text": "A scorched banner is pinned beneath a block of black stone. Its colors have almost vanished under ash."}
	],
	"market": [
		{"id": "sealed_storehouse", "label": "SEALED STOREHOUSE", "kind": "chest_anchor", "point": Vector2(0.70, 0.58), "text": "The delivery hatch is buried under cinders. A box-shaped lump presses against the warped timber."},
		{"id": "market_notice", "label": "READ IRON NOTICE", "kind": "lore", "point": Vector2(0.42, 0.61), "text": "The notice lists ration prices, closed streets, and a warning about the unstable lower tunnels."},
		{"id": "apothecary_stall", "label": "ASH APOTHECARY", "kind": "shop_anchor", "point": Vector2(0.58, 0.65), "text": "Bottles rattle behind the chained shutters. Their labels have all been blackened by smoke."},
		{"id": "ration_stall", "label": "CINDER RATIONS", "kind": "shop_anchor", "point": Vector2(0.82, 0.69), "text": "A ration stall sits beneath a patched awning. Its owner has gone to help reinforce the lower gate."}
	],
	"living": [
		{"id": "vacant_house", "label": "CHECK VACANT HOUSE", "kind": "chest_anchor", "point": Vector2(0.32, 0.63), "text": "Cold ash coats the empty hearth. A loose floorboard clicks underfoot."},
		{"id": "old_cistern", "label": "INSPECT OLD CISTERN", "kind": "interaction", "point": Vector2(0.65, 0.67), "text": "A chain descends into the cistern. Something metallic taps far below whenever the ground shakes."},
		{"id": "blacksmith_family_home", "label": "KNOCK ON THE IRONWORKER'S HOME", "kind": "house_anchor", "point": Vector2(0.25, 0.76), "text": "A dim light still burns upstairs. The ironworker's family has not answered the door."}
	]
}
const CITY_MOMENTS := {
	"ashen_wastes": {
		"plaza": [
			{"id": "beacon_without_flame", "title": "A BEACON WITHOUT FLAME", "beats": [
				{"speaker": "ELRIC • KEEP STEWARD", "text": "The old beacon used to answer every border light. Now it answers only in ash."},
				{"speaker": "MARA • INNKEEPER", "text": "Then we send word by hand. A dark road is still a road if someone is waiting at the other end."}
			]},
		],
		"market": [
			{"id": "sera_and_the_sealed_letter", "title": "SERA AND THE SEALED LETTER", "beats": [
				{"speaker": "SERA • CINDER MARKET", "text": "Blackthorn's quartermaster once kept my family alive through a winter blockade. If the roads have opened, this should reach them."},
				{"speaker": "BROM • MASTER SMITH", "text": "I'll seal it in a slagglass tube. Rain, ash, and most bandits can't read through one of those."}
			]},
		],
		"inn": [
			{"id": "names_at_the_hearth", "title": "NAMES AT THE HEARTH", "beats": [
				{"speaker": "MARA • INNKEEPER", "text": "Every traveler asks how many beds are left. No one asks how many families are still on the road."},
				{"speaker": "BROM • MASTER SMITH", "text": "Then keep the fire lit. When the roads join again, they'll need somewhere to come home to."}
			]},
		]
	}
}
const CITY_POST_LETTERS := [
	{"id": "sera_to_blackthorn", "from": "ashen_wastes", "to": "ravenwood", "title": "A sealed note for Blackthorn", "text": "Sera asks you to carry her family's old trade pledge to the quartermaster at Blackthorn. The sealed slagglass tube is warm to the touch.", "reward": 40, "requires": []},
	{"id": "blackthorn_reply", "from": "ravenwood", "to": "ashen_wastes", "title": "A reply from Blackthorn", "text": "Blackthorn's quartermaster sends a reply for Sera: the northern track is still watched, but a forester can guide a small company through.", "reward": 55, "requires": ["sera_to_blackthorn"]}
]
const CITY_SYNTHESIS := {
	"cinder_sovereign": {"ingredients": ["ashen_wastes_vanguard", "ashen_wastes_sigil"], "output": "ashen_wastes_signature", "cost": 90}
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
var character_stage: Node2D
var foreground_card_nodes: Array[Sprite2D] = []
var foreground_card_textures: Dictionary = {}
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
var a_button: Button
var mini_map_button: Button
var mini_map_panel: Panel
var mini_map_hero: Panel
var mini_map_pois: Array[Panel] = []
var joystick_base: Panel
var joystick_knob: Panel
var npc_sprites: Array[Sprite2D] = []
var npc_textures: Dictionary = {}
var hotspot_targets: Array[Dictionary] = []
var dialogue_layer: Control
var dialogue_moment_id := ""
var walkable_polygons: Array[PackedVector2Array] = []
var walk_path: Array[Vector2] = []
var walk_path_index := 0
var walking_to_target := false
var transition_cooldown := 0.0
var walk_clock := 0.0
var walking := false
var player_direction := 0
var pending_location := ""
var interaction_prompt: Label
var city_fade_overlay: ColorRect
var changing_city_screen := false
var city_embers: CPUParticles2D


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
	if not player_sprite:
		return
	if changing_city_screen:
		return
	transition_cooldown = maxf(0.0, transition_cooldown - delta)
	var movement := Vector2.ZERO
	if not (selection_layer and selection_layer.visible):
		if walking_to_target:
			while walk_path_index < walk_path.size() and player_sprite.position.distance_to(walk_path[walk_path_index]) < 4.0:
				walk_path_index += 1
			if walk_path_index >= walk_path.size():
				_finish_walk()
			else:
				movement = player_sprite.position.direction_to(walk_path[walk_path_index])
		else:
			movement = joystick_vector if joystick_vector.length() > 0.12 else Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if movement.length() > 0.12:
		movement = movement.normalized()
		player_direction = 2 if absf(movement.x) > absf(movement.y) and movement.x >= 0.0 else player_direction
		if absf(movement.x) > absf(movement.y) and movement.x < 0.0:
			player_direction = 1
		elif absf(movement.y) >= absf(movement.x):
			player_direction = 0 if movement.y > 0.0 else 3
		var stride := movement * 205.0 * delta
		if walking_to_target:
			stride = movement * minf(205.0 * delta, player_sprite.position.distance_to(walk_path[walk_path_index]))
		if _try_move_player(stride):
			walking = true
		else:
			if walking_to_target:
				_cancel_walk()
			else:
				walking = false
	elif walking and not walking_to_target:
		walking = false
		player_sprite.frame = player_direction * 4
	if not (selection_layer and selection_layer.visible) and not (dialogue_layer and is_instance_valid(dialogue_layer)):
		_check_city_transition()
	_update_minimap_markers()
	_update_joystick_knob()
	_update_city_perspective()
	_update_interaction_prompt()
	if not walking:
		return
	walk_clock += delta
	var walk_phase := 1 if int(walk_clock / 0.14) % 2 == 0 else 3
	player_sprite.frame = player_direction * 4 + walk_phase
	_update_city_perspective()
	_update_minimap_markers()


func _unhandled_input(event: InputEvent) -> void:
	if changing_city_screen:
		return
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.keycode == KEY_BACKSPACE):
		_on_b_pressed()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
		_on_b_pressed()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		_on_a_pressed()
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
	if not _is_walkable_position(target):
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
	_build_city_embers()

	var top_bar := PanelContainer.new()
	top_bar.anchor_right = 1.0
	top_bar.offset_bottom = 76.0
	top_bar.z_index = 8
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
	bottom_panel.z_index = 8
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
	scene_back_button = _button("◀  EXIT AREA", _return_to_plaza)
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
	city_fade_overlay = ColorRect.new()
	city_fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	city_fade_overlay.color = Color(0.008, 0.012, 0.016, 1.0)
	city_fade_overlay.modulate.a = 0.0
	city_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	city_fade_overlay.z_index = 45
	add_child(city_fade_overlay)
	interaction_prompt = _label("?", 24, Color("f2d38e"))
	interaction_prompt.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	interaction_prompt.add_theme_constant_override("shadow_offset_x", 2)
	interaction_prompt.add_theme_constant_override("shadow_offset_y", 2)
	interaction_prompt.z_index = 6
	interaction_prompt.visible = false
	interaction_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(interaction_prompt)

	if city_names.size() > 1:
		_build_city_selector(top_row)


func _build_touch_controls() -> void:
	mini_map_panel = Panel.new()
	mini_map_panel.position = Vector2(size.x - 157.0, 99.0)
	mini_map_panel.size = Vector2(132.0, 132.0)
	mini_map_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini_map_panel.z_index = 3
	mini_map_panel.add_theme_stylebox_override("panel", _circle_style(Color(0.015, 0.025, 0.03, 0.90), Color("d0aa69"), 66))
	add_child(mini_map_panel)
	mini_map_hero = _map_dot(Color("77d5a3"), Vector2(8.0, 8.0))
	mini_map_hero.z_index = 4
	add_child(mini_map_hero)
	_create_minimap_pois()
	joystick_base = Panel.new()
	joystick_base.size = Vector2(118.0, 118.0)
	joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_base.z_index = 7
	joystick_base.add_theme_stylebox_override("panel", _circle_style(Color(0.015, 0.025, 0.03, 0.68), Color(0.82, 0.69, 0.46, 0.72), 59))
	add_child(joystick_base)
	joystick_area = Control.new()
	joystick_area.position = Vector2(18.0, size.y - 174.0)
	joystick_area.size = Vector2(144.0, 144.0)
	joystick_area.mouse_filter = Control.MOUSE_FILTER_STOP
	joystick_area.z_index = 8
	joystick_area.gui_input.connect(_on_joystick_input)
	add_child(joystick_area)
	joystick_knob = Panel.new()
	joystick_knob.size = Vector2(44.0, 44.0)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_knob.z_index = 9
	joystick_knob.add_theme_stylebox_override("panel", _circle_style(Color(0.63, 0.48, 0.28, 0.90), Color("e0c28b"), 22))
	add_child(joystick_knob)
	_update_joystick_knob()
	b_button = _button("B", _on_b_pressed)
	b_button.custom_minimum_size = Vector2(72.0, 72.0)
	b_button.anchor_left = 1.0
	b_button.anchor_top = 1.0
	b_button.anchor_right = 1.0
	b_button.anchor_bottom = 1.0
	b_button.offset_left = -102.0
	b_button.offset_top = -254.0
	b_button.offset_right = -24.0
	b_button.offset_bottom = -176.0
	b_button.add_theme_font_size_override("font_size", 25)
	b_button.z_index = 8
	add_child(b_button)
	a_button = _button("A", _on_a_pressed)
	a_button.custom_minimum_size = Vector2(72.0, 72.0)
	a_button.anchor_left = 1.0
	a_button.anchor_top = 1.0
	a_button.anchor_right = 1.0
	a_button.anchor_bottom = 1.0
	a_button.offset_left = -190.0
	a_button.offset_top = -254.0
	a_button.offset_right = -112.0
	a_button.offset_bottom = -176.0
	a_button.add_theme_font_size_override("font_size", 25)
	a_button.z_index = 50
	add_child(a_button)
	b_button.z_index = 50


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
	tabs.add_child(_button("POST", _show_selection_post))
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
	_cancel_walk()
	_update_joystick_knob()
	selection_layer.visible = true
	_show_selection_map()


func _open_selection_map() -> void:
	_open_selection()
	_show_selection_map()


func _close_selection() -> void:
	selection_layer.visible = false


func _show_selection_map() -> void:
	_clear_selection_content()
	selection_status.text = "Nearby doors and streets from %s. Choose one to walk there." % str(CITY_SCREENS.get(current_screen, {}).get("title", current_screen)).capitalize()
	var local_transitions := _transitions_for_screen(current_screen)
	selection_content.add_child(_label("DISTRICT ROUTES", 15, Color("e6bd78")))
	for transition in local_transitions:
		var destination := str(transition.get("to", ""))
		var title := str(CITY_SCREENS.get(destination, {}).get("title", "THE FRONTIER" if destination == "territory" else destination.to_upper()))
		var route_button := _button("WALK TO  •  %s" % title, _travel_to_screen.bind(destination))
		route_button.custom_minimum_size.y = 48
		selection_content.add_child(route_button)
	var local_pois: Array = CITY_POIS.get(current_screen, [])
	if not local_pois.is_empty():
		selection_content.add_child(_label("STREET INTERACTIONS", 15, Color("e6bd78")))
		for poi in local_pois:
			var poi_button := _button("INSPECT  •  %s" % str(poi.get("label", "LOCAL POINT")), _travel_to_poi.bind(str(poi.get("id", ""))))
			poi_button.custom_minimum_size.y = 48
			selection_content.add_child(poi_button)
	var moments: Array = CITY_MOMENTS.get(region_id, {}).get(current_screen, [])
	var available_moments: Array[Dictionary] = []
	for moment in moments:
		if not _city_moment_completed(str(moment.get("id", ""))):
			available_moments.append(moment)
	if not available_moments.is_empty():
		selection_content.add_child(_label("PARTY CUTAWAYS  •  OPTIONAL", 15, Color("e6bd78")))
		for moment in available_moments:
			var moment_button := _button("VIEW CITY MOMENT  •  %s" % str(moment.get("title", "PARTY SCENE")), _open_city_moment.bind(str(moment.get("id", ""))))
			moment_button.custom_minimum_size.y = 48
			selection_content.add_child(moment_button)
	if local_transitions.is_empty() and local_pois.is_empty():
		selection_content.add_child(_label("There are no marked exits or points in this room.", 15, Color("d5ddda")))


func _travel_to_screen(screen_id: String) -> void:
	var transition := _transition_for_destination(current_screen, screen_id)
	if transition.is_empty():
		return
	_close_selection()
	_walk_to_location(screen_id, Vector2(size.x * float(transition.point.x), size.y * float(transition.point.y)))


func _travel_to_poi(poi_id: String) -> void:
	for poi in CITY_POIS.get(current_screen, []):
		if str(poi.get("id", "")) != poi_id:
			continue
		_close_selection()
		var point: Vector2 = poi.get("point", Vector2(0.5, 0.6))
		_walk_to_location("poi:" + poi_id, Vector2(size.x * point.x, size.y * point.y))
		return


func _transitions_for_screen(screen_id: String) -> Array:
	return CITY_TRANSITIONS.get(screen_id, [])


func _transition_for_destination(screen_id: String, destination: String) -> Dictionary:
	for transition in _transitions_for_screen(screen_id):
		if str(transition.get("to", "")) == destination:
			return transition
	return {}


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
	if region_id == "ashen_wastes" and current_screen == "forge":
		var recipe: Dictionary = CITY_SYNTHESIS["cinder_sovereign"]
		var components: Array = recipe.ingredients
		selection_content.add_child(_label("CINDER FOUNDRY SYNTHESIS", 17, Color("e6bd78")))
		selection_content.add_child(_label("Ashen Greatblade + Ashen Sigil  •  %d gold" % int(recipe.cost), 14, Color("d5ddda")))
		var available := HERO_EQUIPMENT_SERVICE.unassigned_inventory_references()
		var ready := true
		for component in components:
			ready = ready and available.has(str(component))
		var craft_button := _button("FORGE CINDER SOVEREIGN", _synthesize_cinder_sovereign)
		craft_button.disabled = not ready or HERO_EQUIPMENT_SERVICE.owns_template(str(recipe.output))
		selection_content.add_child(craft_button)
		if not ready:
			selection_content.add_child(_label("Both components must be recovered and unequipped. Equipped gear is protected.", 13, Color("aebbb9")))


func _show_selection_post() -> void:
	_clear_selection_content()
	selection_status.text = "Carry sealed messages between territory hubs. Deliveries are optional, saved, and rewarded once."
	selection_content.add_child(_label("EMBERPOST  •  THE COURIER NETWORK", 17, Color("e6bd78")))
	var state := _load_city_network_state()
	var accepted: Array = state.get("accepted", [])
	var delivered: Array = state.get("delivered", [])
	var has_local_message := false
	for letter in CITY_POST_LETTERS:
		var letter_id := str(letter.get("id", ""))
		var from_region := str(letter.get("from", ""))
		var to_region := str(letter.get("to", ""))
		var requirements: Array = letter.get("requires", [])
		var unlocked := true
		for required in requirements:
			unlocked = unlocked and delivered.has(str(required))
		if delivered.has(letter_id):
			continue
		if not accepted.has(letter_id) and region_id == from_region and unlocked:
			has_local_message = true
			selection_content.add_child(_label("%s  •  TO %s" % [str(letter.get("title", "LETTER")).to_upper(), _city_hub_name(to_region)], 15, Color("f1dbac")))
			selection_content.add_child(_label(str(letter.get("text", "A sealed message awaits.")), 14, Color("d5ddda")))
			selection_content.add_child(_button("ACCEPT SEALED LETTER", _accept_city_letter.bind(letter_id)))
		elif accepted.has(letter_id) and region_id == to_region:
			has_local_message = true
			selection_content.add_child(_label("DELIVER  •  %s" % str(letter.get("title", "LETTER")).to_upper(), 15, Color("f1dbac")))
			selection_content.add_child(_label(str(letter.get("text", "A sealed message is ready.")), 14, Color("d5ddda")))
			selection_content.add_child(_button("DELIVER TO %s  •  %d GOLD" % [_city_hub_name(to_region).to_upper(), int(letter.get("reward", 0))], _deliver_city_letter.bind(letter_id)))
		elif accepted.has(letter_id):
			has_local_message = has_local_message or region_id == from_region
			selection_content.add_child(_label("CARRYING: %s  →  %s" % [_city_hub_name(from_region), _city_hub_name(to_region)], 14, Color("d5ddda")))
	if not has_local_message:
		selection_content.add_child(_label("No new letter is waiting here. Messages you carry will appear when you reach their destination.", 14, Color("aebbb9")))
	if not accepted.is_empty() or not delivered.is_empty():
		selection_content.add_child(_label("NETWORK RECORD  •  %d delivered" % delivered.size(), 13, Color("aebbb9")))


func _city_moment_completed(moment_id: String) -> bool:
	var cfg := ConfigFile.new()
	cfg.load(CITY_STORY_PATH)
	return (cfg.get_value(region_id, "completed_moments", []) as Array).has(moment_id)


func _open_city_moment(moment_id: String) -> void:
	var found: Dictionary = {}
	for moment in CITY_MOMENTS.get(region_id, {}).get(current_screen, []):
		if str(moment.get("id", "")) == moment_id:
			found = moment
			break
	if found.is_empty() or _city_moment_completed(moment_id):
		return
	if dialogue_layer and is_instance_valid(dialogue_layer):
		dialogue_layer.queue_free()
	dialogue_layer = Control.new()
	dialogue_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialogue_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	dialogue_layer.z_index = 40
	add_child(dialogue_layer)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.015, 0.02, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_layer.add_child(shade)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.14
	panel.anchor_top = 0.14
	panel.anchor_right = 0.86
	panel.anchor_bottom = 0.51
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.035, 0.04, 0.98), Color("d0aa69")))
	dialogue_layer.add_child(panel)
	var margin := MarginContainer.new()
	_set_margins(margin, 22, 18, 22, 18)
	panel.add_child(margin)
	var copy := VBoxContainer.new()
	copy.add_theme_constant_override("separation", 10)
	margin.add_child(copy)
	copy.add_child(_label("CITY MOMENT  •  OPTIONAL PARTY CUTAWAY", 13, Color("aebbb9")))
	copy.add_child(_label(str(found.get("title", "A CITY MOMENT")), 20, Color("f1dbac")))
	for beat in found.get("beats", []):
		copy.add_child(_label(str(beat.get("speaker", "COMPANION")), 13, Color("e6bd78")))
		var words := _label(str(beat.get("text", "")), 15, Color("f0e8d5"))
		words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		copy.add_child(words)
	var close_button := _button("A  •  CONTINUE", _close_city_dialogue)
	close_button.custom_minimum_size.y = 42
	copy.add_child(close_button)
	dialogue_moment_id = moment_id
	joystick_vector = Vector2.ZERO
	_update_joystick_knob()


func _load_city_network_state() -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(CITY_NETWORK_PATH)
	return {
		"accepted": cfg.get_value("letters", "accepted", []),
		"delivered": cfg.get_value("letters", "delivered", [])
	}


func _save_city_network_state(state: Dictionary) -> bool:
	var cfg := ConfigFile.new()
	cfg.load(CITY_NETWORK_PATH)
	cfg.set_value("letters", "accepted", state.get("accepted", []))
	cfg.set_value("letters", "delivered", state.get("delivered", []))
	return cfg.save(CITY_NETWORK_PATH) == OK


func _city_hub_name(id: String) -> String:
	return str(territories.get(id, {}).get("stronghold", territories.get(id, {}).get("name", id.replace("_", " ").capitalize())))


func _accept_city_letter(letter_id: String) -> void:
	var state := _load_city_network_state()
	var accepted: Array = state.accepted
	var delivered: Array = state.delivered
	for letter in CITY_POST_LETTERS:
		if str(letter.get("id", "")) != letter_id or str(letter.get("from", "")) != region_id:
			continue
		var unlocked := true
		for required in letter.get("requires", []):
			unlocked = unlocked and delivered.has(str(required))
		if unlocked and not accepted.has(letter_id):
			accepted.append(letter_id)
			state["accepted"] = accepted
			if _save_city_network_state(state):
				_show_selection_post()
				selection_status.text = "Letter accepted. Deliver it when you reach %s." % _city_hub_name(str(letter.to))
			return


func _deliver_city_letter(letter_id: String) -> void:
	var state := _load_city_network_state()
	var accepted: Array = state.accepted
	var delivered: Array = state.delivered
	if not accepted.has(letter_id) or delivered.has(letter_id):
		return
	for letter in CITY_POST_LETTERS:
		if str(letter.get("id", "")) != letter_id or str(letter.get("to", "")) != region_id:
			continue
		delivered.append(letter_id)
		state["delivered"] = delivered
		if not _save_city_network_state(state):
			return
		var gold_awarded := HERO_EQUIPMENT_SERVICE.award_gold("city_mail", letter_id, int(letter.get("reward", 0)))
		HERO_PROGRESSION_SERVICE.add_xp(HERO_PROGRESSION_SERVICE.CHOSEN_HERO_ID, 35)
		gold_label.text = "◈ %d GOLD" % HERO_EQUIPMENT_SERVICE.gold()
		_show_selection_post()
		selection_status.text = "Delivered at %s.  +%d gold  •  +35 XP" % [_city_hub_name(region_id), gold_awarded]
		return


func _synthesize_cinder_sovereign() -> void:
	if not CITY_SYNTHESIS.has("cinder_sovereign"):
		return
	var recipe: Dictionary = CITY_SYNTHESIS["cinder_sovereign"]
	var components: Array[String] = []
	for component in recipe.get("ingredients", []):
		components.append(str(component))
	var result := HERO_EQUIPMENT_SERVICE.synthesize("cinder_sovereign", components, str(recipe.get("output", "")), int(recipe.get("cost", 0)))
	_show_selection_equipment()
	if bool(result.get("ok", false)):
		selection_status.text = "Synthesis complete: %s. Components were consumed; equipped gear was untouched." % str(result.get("item", {}).get("name", "Cinder Sovereign"))
	else:
		selection_status.text = str(result.get("reason", "The synthesis failed."))


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
	cfg.load(CITY_SAVE_PATH)
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
	player_sprite.position = _nearest_walkable_position(Vector2(size.x * float(cfg.get_value(region_id, "player_x", 0.5)), size.y * float(cfg.get_value(region_id, "player_y", 0.7))))
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
	player_sprite.position = _nearest_walkable_position(Vector2(size.x * float(cfg.get_value(region_id, "player_x", 0.5)), size.y * float(cfg.get_value(region_id, "player_y", 0.7))))
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


func _update_joystick(local_position: Vector2) -> void:
	# GUI touch coordinates can be viewport-relative while mouse coordinates
	# are control-local. Pick the representation nearest the joystick center;
	# this also keeps a captured drag usable after it leaves the control bounds.
	var center := joystick_area.size * 0.5
	var transformed := joystick_area.get_global_transform_with_canvas().affine_inverse() * local_position
	if transformed.distance_squared_to(center) < local_position.distance_squared_to(center):
		local_position = transformed
	joystick_vector = ((local_position - joystick_area.size * 0.5) / 48.0).limit_length(1.0)
	if joystick_vector.length() > 0.12:
		_cancel_walk()
	queue_redraw()


func _on_b_pressed() -> void:
	if dialogue_layer and is_instance_valid(dialogue_layer):
		_close_city_dialogue()
	elif selection_layer and selection_layer.visible:
		_close_selection()
	elif gear_dialog and gear_dialog.visible:
		gear_dialog.hide()
	elif current_screen != "plaza":
		_return_to_plaza()


func _on_a_pressed() -> void:
	if dialogue_layer and is_instance_valid(dialogue_layer):
		_close_city_dialogue()
		return
	if selection_layer and selection_layer.visible:
		_close_selection()
		return
	if hotspot_targets.is_empty() or not player_sprite:
		return
	var closest: Dictionary = {}
	var closest_distance := INF
	for target in hotspot_targets:
		var point: Vector2 = target.get("point", Vector2.ZERO)
		var distance := player_sprite.position.distance_to(Vector2(size.x * point.x, size.y * point.y))
		if distance < closest_distance:
			closest = target
			closest_distance = distance
	if not closest.is_empty():
		_on_hotspot_pressed(str(closest.get("id", "")), closest.get("point", Vector2.ZERO))


func _screen_routes(screen_id: String) -> Array:
	var routes: Array = []
	for transition in _transitions_for_screen(screen_id):
		routes.append(str(transition.get("to", "")))
	return routes


func _create_minimap_pois() -> void:
	for poi in mini_map_pois:
		if is_instance_valid(poi):
			poi.queue_free()
	mini_map_pois.clear()
	for index in range(8):
		var dot := _map_dot(Color("d0aa69"), Vector2(7.0, 7.0))
		dot.set_meta("marker_color", Color("d0aa69"))
		dot.z_index = 4
		mini_map_pois.append(dot)
		add_child(dot)
	_update_minimap_markers()


func _update_minimap_markers() -> void:
	if not mini_map_panel or not mini_map_hero:
		return
	mini_map_panel.position = Vector2(size.x - 157.0, 99.0)
	var map_center := mini_map_panel.position + mini_map_panel.size * 0.5
	if player_sprite:
		var offset := Vector2((player_sprite.position.x / maxf(1.0, size.x) - 0.5) * 30.0, (player_sprite.position.y / maxf(1.0, size.y) - 0.65) * 24.0)
		mini_map_hero.position = map_center + offset - mini_map_hero.size * 0.5
	var markers: Array[Dictionary] = []
	var hero_point := Vector2(0.5, 0.5)
	if player_sprite:
		hero_point = Vector2(player_sprite.position.x / maxf(1.0, size.x), player_sprite.position.y / maxf(1.0, size.y))
	for transition in _transitions_for_screen(current_screen):
		markers.append({"point": transition.get("point", Vector2(0.5, 0.5)), "color": Color("d0aa69")})
	for poi in CITY_POIS.get(current_screen, []):
		markers.append({"point": poi.get("point", Vector2(0.5, 0.5)), "color": Color("f08155")})
	for index in range(mini_map_pois.size()):
		var poi := mini_map_pois[index]
		poi.visible = index < markers.size()
		if index < markers.size():
			var field_point: Vector2 = markers[index].get("point", Vector2(0.5, 0.5))
			var relative := Vector2((field_point.x - hero_point.x) * 116.0, (field_point.y - hero_point.y) * 92.0).limit_length(50.0)
			poi.position = map_center + relative - poi.size * 0.5
			var marker_color: Color = markers[index].get("color", Color("d0aa69"))
			if poi.get_meta("marker_color", Color("d0aa69")) != marker_color:
				poi.add_theme_stylebox_override("panel", _circle_style(marker_color, marker_color, 3))
				poi.set_meta("marker_color", marker_color)


func _update_joystick_knob() -> void:
	if not joystick_area or not joystick_base or not joystick_knob:
		return
	joystick_area.position = Vector2(18.0, size.y - 174.0)
	joystick_base.position = joystick_area.position + Vector2(13.0, 13.0)
	joystick_knob.position = joystick_area.position + Vector2(72.0, 72.0) + joystick_vector * 34.0 - joystick_knob.size * 0.5


func _map_dot(color: Color, dot_size: Vector2) -> Panel:
	var dot := Panel.new()
	dot.size = dot_size
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.add_theme_stylebox_override("panel", _circle_style(color, color, int(dot_size.x * 0.5)))
	return dot


func _circle_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2 if radius > 10 else 1)
	style.set_corner_radius_all(radius)
	return style


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
	character_stage = Node2D.new()
	character_stage.y_sort_enabled = true
	character_stage.z_index = 1
	add_child(character_stage)
	player_sprite = Sprite2D.new()
	player_sprite.texture = _build_pixel_sprite_sheet()
	player_sprite.hframes = 4
	player_sprite.vframes = 4
	player_sprite.frame = 0
	player_sprite.scale = Vector2(2.35, 2.35)
	player_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player_sprite.z_index = 0
	character_stage.add_child(player_sprite)
	_update_city_perspective()


func _build_city_embers() -> void:
	city_embers = CPUParticles2D.new()
	city_embers.name = "VolcanicEmbers"
	city_embers.z_index = 1
	city_embers.amount = 20
	city_embers.lifetime = 4.5
	city_embers.preprocess = 2.0
	city_embers.emitting = true
	city_embers.direction = Vector2(-0.18, -1.0)
	city_embers.spread = 24.0
	city_embers.gravity = Vector2(-5.0, -28.0)
	city_embers.initial_velocity_min = 8.0
	city_embers.initial_velocity_max = 26.0
	city_embers.scale_amount_min = 0.7
	city_embers.scale_amount_max = 1.4
	city_embers.color = Color(1.0, 0.39, 0.10, 0.64)
	city_embers.texture = _build_ember_texture()
	city_embers.z_as_relative = false
	city_embers.position = Vector2(size.x * 0.5, size.y * 0.82)
	city_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	city_embers.emission_rect_extents = Vector2(size.x * 0.58, size.y * 0.42)
	city_embers.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(city_embers)


func _build_ember_texture() -> Texture2D:
	var image := Image.create(5, 5, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y in range(5):
		for x in range(5):
			var distance := Vector2(x - 2, y - 2).length()
			if distance <= 1.8:
				image.set_pixel(x, y, Color(1.0, 0.67, 0.26, clampf(1.0 - distance * 0.25, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)




func _foreground_layout_for_screen() -> Array[Dictionary]:
	if current_screen != "plaza":
		return []
	return [
		{"asset": "balustrade", "point": Vector2(0.065, 0.87), "width": 0.155},
		{"asset": "balustrade", "point": Vector2(0.935, 0.87), "width": 0.155, "flip_h": true}
	]

func _refresh_foreground_cards() -> void:
	if not character_stage:
		return
	for card in foreground_card_nodes:
		if is_instance_valid(card):
			card.queue_free()
	foreground_card_nodes.clear()
	if region_id != "ashen_wastes":
		return
	for card_data in _foreground_layout_for_screen():
		var asset_id := str(card_data.get("asset", ""))
		var texture := foreground_card_textures.get(asset_id) as Texture2D
		if not texture:
			var asset_path := str(ASHENREACH_DEPTH_CARD_PATHS.get(asset_id, ""))
			if asset_path == "" or not ResourceLoader.exists(asset_path):
				continue
			texture = load(asset_path) as Texture2D
			if not texture:
				continue
			foreground_card_textures[asset_id] = texture
		var point: Vector2 = card_data.get("point", Vector2(0.5, 0.7))
		var width_fraction := float(card_data.get("width", 0.10))
		var depth_scale := lerpf(0.58, 1.0, clampf(point.y, 0.12, 0.95))
		var target_width := maxf(1.0, size.x * width_fraction * depth_scale)
		var scale_factor := target_width / maxf(1.0, float(texture.get_width()))
		var sprite := Sprite2D.new()
		sprite.name = "AshenreachDepthCard_" + asset_id
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.position = Vector2(size.x * point.x, size.y * point.y)
		sprite.scale = Vector2.ONE * scale_factor
		sprite.offset = Vector2(0.0, -float(texture.get_height()) * 0.5)
		sprite.flip_h = bool(card_data.get("flip_h", false))
		character_stage.add_child(sprite)
		foreground_card_nodes.append(sprite)


func _update_city_perspective() -> void:
	if not player_sprite:
		return
	# Screen Y is the depth axis of these fixed-camera, painted rooms. This is
	# the sprite projection for the room's walk plane: farther points shrink.
	var player_depth := clampf(player_sprite.position.y / maxf(1.0, size.y), 0.12, 0.94)
	player_sprite.scale = Vector2.ONE * (2.35 * (0.50 + player_depth * 0.72))
	for resident in npc_sprites:
		if not is_instance_valid(resident):
			continue
		var resident_depth := clampf(resident.position.y / maxf(1.0, size.y), 0.12, 0.94)
		resident.scale = Vector2.ONE * (2.0 * (0.50 + resident_depth * 0.72))
	if city_embers:
		city_embers.position = Vector2(size.x * 0.5, size.y * 0.82)
		city_embers.emission_rect_extents = Vector2(size.x * 0.58, size.y * 0.42)
		city_embers.emitting = region_id == "ashen_wastes"


func _update_interaction_prompt() -> void:
	if not interaction_prompt or not is_instance_valid(interaction_prompt) or not player_sprite:
		return
	if changing_city_screen or (selection_layer and selection_layer.visible) or (dialogue_layer and is_instance_valid(dialogue_layer)):
		interaction_prompt.visible = false
		return
	var nearest: Dictionary = {}
	var nearest_distance := INF
	for target in hotspot_targets:
		var point: Vector2 = target.get("point", Vector2.ZERO)
		var target_position := Vector2(size.x * point.x, size.y * point.y)
		var distance := player_sprite.position.distance_to(target_position)
		if distance < nearest_distance:
			nearest = target
			nearest_distance = distance
	if nearest.is_empty() or nearest_distance > 94.0:
		interaction_prompt.visible = false
		return
	var target_id := str(nearest.get("id", ""))
	interaction_prompt.text = "!" if not target_id.begins_with("poi:") else "?"
	if target_id.begins_with("npc:"):
		interaction_prompt.text = "?"
	interaction_prompt.position = player_sprite.position + Vector2(-8.0, -48.0 * player_sprite.scale.y)
	interaction_prompt.visible = true


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


func _build_magma_sprite_sheet(variant: String) -> Texture2D:
	var image := Image.create(SPRITE_FRAME_SIZE.x * 4, SPRITE_FRAME_SIZE.y * 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var skin := Color("342d2c")
	var skin_lit := Color("51403a")
	var ember := Color("ff8a35")
	var ember_bright := Color("ffd16a")
	var hair := Color("201d20")
	var cloth := Color("49352f")
	var cloth_trim := Color("9a5535")
	var accessory := Color("a98250")
	match variant:
		"ash_elder":
			hair = Color("9b8a79")
			cloth = Color("48443f")
			cloth_trim = Color("897558")
			accessory = Color("c08b51")
		"forge_guard":
			hair = Color("332b26")
			cloth = Color("3d4040")
			cloth_trim = Color("a34929")
			accessory = Color("76736c")
		"ember_scout":
			hair = Color("a64a25")
			cloth = Color("455044")
			cloth_trim = Color("bd6031")
			accessory = Color("d0a15b")
	for direction in range(4):
		for frame_index in range(4):
			var cell_x := frame_index * SPRITE_FRAME_SIZE.x
			var cell_y := direction * SPRITE_FRAME_SIZE.y
			var stride := -2 if frame_index == 1 else (2 if frame_index == 3 else 0)
			_paint_pixel_rect(image, cell_x, cell_y, 6, 28, 12, 2, Color(0.02, 0.015, 0.012, 0.42))
			if direction == 0:
				_paint_pixel_rect(image, cell_x, cell_y, 8, 3, 8, 3, hair)
				_paint_pixel_rect(image, cell_x, cell_y, 7, 5, 2, 7, hair)
				_paint_pixel_rect(image, cell_x, cell_y, 15, 5, 2, 7, hair)
				_paint_pixel_rect(image, cell_x, cell_y, 9, 5, 6, 7, skin_lit)
				_paint_pixel_rect(image, cell_x, cell_y, 10, 8, 1, 1, ember_bright)
				_paint_pixel_rect(image, cell_x, cell_y, 13, 8, 1, 1, ember_bright)
			elif direction == 3:
				_paint_pixel_rect(image, cell_x, cell_y, 8, 3, 8, 9, hair)
				_paint_pixel_rect(image, cell_x, cell_y, 7, 6, 2, 7, hair)
				_paint_pixel_rect(image, cell_x, cell_y, 15, 6, 2, 7, hair)
			else:
				_paint_pixel_rect(image, cell_x, cell_y, 8, 3, 8, 3, hair)
				_paint_pixel_rect(image, cell_x, cell_y, 7, 5, 3, 7, hair)
				_paint_pixel_rect(image, cell_x, cell_y, 10, 5, 5, 7, skin_lit)
				_paint_pixel_rect(image, cell_x, cell_y, 8 if direction == 1 else 15, 8, 1, 1, ember_bright)
			# Elder has a visible ash beard; scouts have swept-back ember hair.
			if variant == "ash_elder" and direction != 3:
				_paint_pixel_rect(image, cell_x, cell_y, 9, 10, 6, 3, hair)
			if variant == "ember_scout" and direction != 3:
				_paint_pixel_rect(image, cell_x, cell_y, 7, 3, 3, 2, hair.lightened(0.12))
			var arm_swing := int(stride / 2)
			_paint_pixel_rect(image, cell_x, cell_y, 5, 13 + arm_swing, 3, 8, skin)
			_paint_pixel_rect(image, cell_x, cell_y, 16, 13 - arm_swing, 3, 8, skin)
			_paint_pixel_rect(image, cell_x, cell_y, 5, 15 + arm_swing, 3, 1, ember)
			_paint_pixel_rect(image, cell_x, cell_y, 16, 18 - arm_swing, 3, 1, ember)
			_paint_pixel_rect(image, cell_x, cell_y, 7, 12, 10, 11, cloth)
			_paint_pixel_rect(image, cell_x, cell_y, 8, 13, 2, 7, skin_lit)
			_paint_pixel_rect(image, cell_x, cell_y, 12, 15, 1, 5, ember)
			_paint_pixel_rect(image, cell_x, cell_y, 7, 19, 10, 2, cloth_trim)
			_paint_pixel_rect(image, cell_x, cell_y, 13, 20, 2, 2, accessory)
			_paint_pixel_rect(image, cell_x, cell_y, 8 + stride, 23, 4, 5, skin)
			_paint_pixel_rect(image, cell_x, cell_y, 12 - stride, 23, 4, 5, skin_lit)
			_paint_pixel_rect(image, cell_x, cell_y, 7 + stride, 27, 5, 2, Color("251f1c"))
			_paint_pixel_rect(image, cell_x, cell_y, 12 - stride, 27, 5, 2, Color("251f1c"))
			if variant == "forge_guard":
				_paint_pixel_rect(image, cell_x, cell_y, 5, 12, 4, 3, accessory)
				_paint_pixel_rect(image, cell_x, cell_y, 15, 12, 4, 3, accessory)
			elif variant == "ash_elder":
				_paint_pixel_rect(image, cell_x, cell_y, 17, 12, 2, 16, Color("78634a"))
	return ImageTexture.create_from_image(image)


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
	hotspot.z_index = 4
	add_child(hotspot)
	hotspot_buttons.append(hotspot)
	hotspot_targets.append({"id": id, "point": point})


func _refresh_residents() -> void:
	for resident in npc_sprites:
		if is_instance_valid(resident):
			resident.queue_free()
	npc_sprites.clear()
	npc_textures.clear()
	if region_id != "ashen_wastes":
		return
	var residents: Array[Dictionary] = []
	match current_screen:
		"plaza":
			residents = [
				{"talk": "steward", "point": Vector2(0.53, 0.55), "look": "ash_elder"},
				{"point": Vector2(0.35, 0.63), "look": "ember_scout"},
				{"point": Vector2(0.68, 0.61), "look": "forge_guard"}
			]
		"market":
			residents = [
				{"talk": "merchant", "point": Vector2(0.62, 0.54), "look": "ember_scout"},
				{"point": Vector2(0.34, 0.65), "look": "ash_elder"},
				{"point": Vector2(0.78, 0.62), "look": "forge_guard"}
			]
		"living":
			residents = [
				{"talk": "innkeeper", "point": Vector2(0.70, 0.60), "look": "ash_elder"},
				{"point": Vector2(0.35, 0.69), "look": "forge_guard"},
				{"point": Vector2(0.55, 0.73), "look": "ember_scout"}
			]
		"forge":
			residents = [
				{"talk": "smith", "point": Vector2(0.59, 0.57), "look": "forge_guard"},
				{"point": Vector2(0.33, 0.63), "look": "ash_elder"}
			]
		"inn":
			residents = [
				{"talk": "innkeeper", "point": Vector2(0.72, 0.54), "look": "ember_scout"},
				{"point": Vector2(0.34, 0.65), "look": "ash_elder"},
				{"point": Vector2(0.54, 0.64), "look": "forge_guard"}
			]
		"keep":
			residents = [
				{"talk": "steward", "point": Vector2(0.52, 0.57), "look": "ash_elder"},
				{"point": Vector2(0.32, 0.64), "look": "forge_guard"},
				{"point": Vector2(0.72, 0.64), "look": "ember_scout"}
			]
		"gate":
			residents = [{"talk": "gate_guard", "point": Vector2(0.68, 0.58), "look": "forge_guard"}]
	for resident in residents:
		var point: Vector2 = resident.get("point", Vector2(0.5, 0.6))
		var look := str(resident.get("look", "ember_scout"))
		var sprite := Sprite2D.new()
		if not npc_textures.has(look):
			npc_textures[look] = _build_magma_sprite_sheet(look)
		sprite.texture = npc_textures[look]
		sprite.hframes = 4
		sprite.vframes = 4
		sprite.frame = 0
		sprite.scale = Vector2(2.0, 2.0)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = Vector2(size.x * point.x, size.y * point.y)
		character_stage.add_child(sprite)
		npc_sprites.append(sprite)
		var talk_id := str(resident.get("talk", ""))
		if talk_id != "":
			_add_hotspot("npc:" + talk_id, "✦ TALK", Vector2(point.x, point.y - 0.075))


func _show_city_dialogue(npc_id: String) -> void:
	var conversations := {
		"innkeeper": {
			"name": "MARA • INNKEEPER",
			"portrait": "innkeeper",
			"text": "Welcome in, traveler. The roads are rough, but the hearth is warm. A night's rest costs 25 gold; the gate is where the hard news waits."
		},
		"smith": {
			"name": "BROM • MASTER SMITH",
			"portrait": "smith",
			"text": "Bring me the gear you recover out there. I can tell you what it is worth and which pieces were made for fighting the Ashen Wastes."
		},
		"merchant": {
			"name": "SERA • CINDER MARKET",
			"portrait": "innkeeper",
			"text": "The stalls are open when the ashfall lets up. If you need a blade, start at the foundry; if you need a bed, take the alley into the lower ward."
		},
		"steward": {
			"name": "ELRIC • KEEP STEWARD",
			"portrait": "steward",
			"text": "The old borders are opening again. Each road leads into a different realm; choose your route carefully, but remember that no single road decides the whole campaign."
		},
		"gate_guard": {
			"name": "GATE WARDEN",
			"portrait": "steward",
			"text": "Beyond this arch, the territory roads reconnect with the frontier. Check the city map if you need to find your way back."
		}
	}
	var conversation: Dictionary = conversations.get(npc_id, conversations["steward"])
	if dialogue_layer and is_instance_valid(dialogue_layer):
		dialogue_layer.queue_free()
	dialogue_layer = Control.new()
	dialogue_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialogue_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	dialogue_layer.z_index = 40
	add_child(dialogue_layer)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.07
	panel.anchor_top = 0.14
	panel.anchor_right = 0.93
	panel.anchor_bottom = 0.53
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.035, 0.04, 0.96), Color("d0aa69")))
	dialogue_layer.add_child(panel)
	var margin := MarginContainer.new()
	_set_margins(margin, 20, 14, 16, 12)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 8)
	row.add_child(copy)
	var speaker := _label(str(conversation.get("name", "TOWNSFOLK")), 16, Color("e6bd78"))
	copy.add_child(speaker)
	var words := _label(str(conversation.get("text", "")), 16, Color("f0e8d5"))
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.size_flags_vertical = Control.SIZE_EXPAND_FILL
	copy.add_child(words)
	var continue_button := _button("B  •  CONTINUE", _close_city_dialogue)
	continue_button.custom_minimum_size.x = 176
	copy.add_child(continue_button)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(190.0, 210.0)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait_path := "res://assets/cities/ashenreach/portraits/%s.webp" % str(conversation.get("portrait", "steward"))
	if ResourceLoader.exists(portrait_path):
		portrait.texture = load(portrait_path)
	row.add_child(portrait)
	joystick_vector = Vector2.ZERO
	_update_joystick_knob()


func _close_city_dialogue() -> void:
	if dialogue_layer and is_instance_valid(dialogue_layer):
		dialogue_layer.queue_free()
	dialogue_layer = null
	if dialogue_moment_id != "":
		var cfg := ConfigFile.new()
		cfg.load(CITY_STORY_PATH)
		var completed: Array = cfg.get_value(region_id, "completed_moments", [])
		if not completed.has(dialogue_moment_id):
			completed.append(dialogue_moment_id)
		cfg.set_value(region_id, "completed_moments", completed)
		cfg.save(CITY_STORY_PATH)
		dialogue_moment_id = ""


func _on_hotspot_pressed(id: String, point: Vector2) -> void:
	_walk_to_location(id, Vector2(size.x * point.x, size.y * point.y))


func _walk_to_location(location_id: String, destination: Vector2) -> void:
	if location_id.begins_with("npc:"):
		pending_location = location_id
	elif location_id.begins_with("poi:"):
		var found_local_poi := false
		for poi in CITY_POIS.get(current_screen, []):
			if str(poi.get("id", "")) == location_id.trim_prefix("poi:"):
				found_local_poi = true
				break
		if not found_local_poi:
			return
		pending_location = location_id
	else:
		if _transition_for_destination(current_screen, location_id).is_empty():
			return
		pending_location = ""
	_walk_player_to(destination)


func _walk_player_to(destination: Vector2) -> void:
	if not player_sprite:
		return
	var safe_target := _nearest_walkable_position(destination)
	if not _is_walkable_position(safe_target):
		pending_location = ""
		return
	var route := _find_walk_path(player_sprite.position, safe_target)
	if route.is_empty():
		pending_location = ""
		return
	for hotspot in hotspot_buttons:
		hotspot.disabled = true
	if scene_back_button:
		scene_back_button.disabled = true
	if action_button:
		action_button.disabled = true
	var travel := safe_target - player_sprite.position
	if absf(travel.x) > absf(travel.y):
		player_direction = 2 if travel.x >= 0.0 else 1
	else:
		player_direction = 0 if travel.y >= 0.0 else 3
	player_sprite.frame = player_direction * 4 + 1
	walk_clock = 0.0
	walking = true
	walk_path = route
	walk_path_index = 0
	walking_to_target = true


func _finish_walk() -> void:
	walking = false
	walking_to_target = false
	walk_path.clear()
	walk_path_index = 0
	player_sprite.frame = player_direction * 4
	for hotspot in hotspot_buttons:
		hotspot.disabled = false
	if scene_back_button:
		scene_back_button.disabled = false
	if action_button:
		action_button.disabled = false
	var destination := pending_location
	pending_location = ""
	if destination.begins_with("npc:"):
		_show_city_dialogue(destination.trim_prefix("npc:"))
	elif destination.begins_with("poi:"):
		_show_city_poi_dialogue(destination.trim_prefix("poi:"))


func _cancel_walk() -> void:
	walking = false
	walking_to_target = false
	walk_path.clear()
	walk_path_index = 0
	pending_location = ""
	if player_sprite:
		player_sprite.frame = player_direction * 4
	for hotspot in hotspot_buttons:
		if is_instance_valid(hotspot):
			hotspot.disabled = false
	if scene_back_button:
		scene_back_button.disabled = false
	if action_button:
		action_button.disabled = false


func _on_city_resized() -> void:
	_update_joystick_knob()
	_update_minimap_markers()
	_refresh_foreground_cards()
	if not player_sprite:
		return
	player_sprite.position = _nearest_walkable_position(player_sprite.position)
	queue_redraw()


func _configure_city_walkable_areas() -> void:
	walkable_polygons.clear()
	match current_screen:
		"plaza":
			walkable_polygons = [
				PackedVector2Array([
					Vector2(0.43, 0.10), Vector2(0.57, 0.10), Vector2(0.58, 0.39), Vector2(0.66, 0.47),
					Vector2(0.62, 0.62), Vector2(0.58, 0.69), Vector2(0.57, 0.91), Vector2(0.43, 0.91),
					Vector2(0.42, 0.68), Vector2(0.37, 0.62), Vector2(0.34, 0.49), Vector2(0.42, 0.40)
				]),
				PackedVector2Array([
					Vector2(0.26, 0.38), Vector2(0.73, 0.38), Vector2(0.82, 0.48), Vector2(0.80, 0.63),
					Vector2(0.70, 0.70), Vector2(0.30, 0.70), Vector2(0.20, 0.62), Vector2(0.18, 0.49)
				]),
				PackedVector2Array([
					Vector2(0.01, 0.46), Vector2(0.34, 0.45), Vector2(0.39, 0.50), Vector2(0.36, 0.59),
					Vector2(0.01, 0.63)
				]),
				PackedVector2Array([
					Vector2(0.64, 0.45), Vector2(0.99, 0.43), Vector2(0.99, 0.62), Vector2(0.65, 0.59),
					Vector2(0.61, 0.52)
				])
			]
		"market":
			walkable_polygons = [
				PackedVector2Array([
					Vector2(0.40, 0.12), Vector2(0.57, 0.12), Vector2(0.61, 0.32), Vector2(0.74, 0.45),
					Vector2(0.82, 0.58), Vector2(0.94, 0.73), Vector2(0.98, 0.88), Vector2(0.05, 0.88),
					Vector2(0.10, 0.76), Vector2(0.20, 0.63), Vector2(0.30, 0.53), Vector2(0.38, 0.40)
				]),
				PackedVector2Array([
					Vector2(0.08, 0.37), Vector2(0.25, 0.35), Vector2(0.40, 0.42), Vector2(0.39, 0.54),
					Vector2(0.22, 0.58), Vector2(0.08, 0.51)
				])
			]
		"living":
			walkable_polygons = [
				PackedVector2Array([
					Vector2(0.43, 0.12), Vector2(0.56, 0.12), Vector2(0.58, 0.39), Vector2(0.67, 0.52),
					Vector2(0.78, 0.64), Vector2(0.90, 0.77), Vector2(0.98, 0.90), Vector2(0.12, 0.90),
					Vector2(0.17, 0.77), Vector2(0.30, 0.68), Vector2(0.38, 0.58), Vector2(0.41, 0.40)
				]),
				PackedVector2Array([
					Vector2(0.56, 0.48), Vector2(0.80, 0.48), Vector2(0.87, 0.58), Vector2(0.80, 0.69),
					Vector2(0.62, 0.62)
				]),
				PackedVector2Array([
					Vector2(0.12, 0.62), Vector2(0.38, 0.56), Vector2(0.43, 0.64), Vector2(0.30, 0.74),
					Vector2(0.16, 0.76)
				])
			]
		"forge":
			walkable_polygons = [
				PackedVector2Array([
					Vector2(0.56, 0.27), Vector2(0.75, 0.27), Vector2(0.81, 0.36), Vector2(0.79, 0.47),
					Vector2(0.75, 0.54), Vector2(0.84, 0.62), Vector2(0.91, 0.75), Vector2(0.94, 0.91),
					Vector2(0.28, 0.91), Vector2(0.30, 0.81), Vector2(0.38, 0.70), Vector2(0.31, 0.61),
					Vector2(0.37, 0.52), Vector2(0.48, 0.45), Vector2(0.55, 0.39)
				])
			]
		"inn":
			walkable_polygons = [
				PackedVector2Array([
					Vector2(0.04, 0.36), Vector2(0.12, 0.27), Vector2(0.87, 0.27), Vector2(0.97, 0.38),
					Vector2(0.98, 0.78), Vector2(0.03, 0.78)
				])
			]
		"keep":
			walkable_polygons = [
				PackedVector2Array([
					Vector2(0.10, 0.18), Vector2(0.22, 0.18), Vector2(0.29, 0.32), Vector2(0.31, 0.45),
					Vector2(0.39, 0.54), Vector2(0.42, 0.65), Vector2(0.52, 0.70), Vector2(0.79, 0.70),
					Vector2(0.86, 0.76), Vector2(0.27, 0.78), Vector2(0.17, 0.71), Vector2(0.16, 0.58),
					Vector2(0.12, 0.42)
				])
			]
		"gate":
			walkable_polygons = [
				PackedVector2Array([
					Vector2(0.40, 0.16), Vector2(0.60, 0.16), Vector2(0.66, 0.35), Vector2(0.75, 0.50),
					Vector2(0.96, 0.72), Vector2(0.99, 0.90), Vector2(0.02, 0.90), Vector2(0.04, 0.72),
					Vector2(0.25, 0.50), Vector2(0.34, 0.35)
				])
			]
		_:
			walkable_polygons = [
				PackedVector2Array([Vector2(0.25, 0.40), Vector2(0.75, 0.40), Vector2(0.86, 0.88), Vector2(0.14, 0.88)])
			]


func _is_walkable_position(position: Vector2) -> bool:
	if position.x < 28.0 or position.x > size.x - 28.0 or position.y < 104.0 or position.y > size.y - 160.0:
		return false
	if size.x <= 0.0 or size.y <= 0.0:
		return false
	# Keep the whole lower sprite footprint on the walk surface, not only its
	# center point. This keeps boots and shoulders from clipping into facades.
	for offset: Vector2 in [Vector2.ZERO, Vector2(-16.0, -8.0), Vector2(16.0, -8.0), Vector2(-16.0, 8.0), Vector2(16.0, 8.0)]:
		if not _is_inside_walkable_polygon_union(position + offset):
			return false
	return true


func _is_inside_walkable_polygon_union(position: Vector2) -> bool:
	if size.x <= 0.0 or size.y <= 0.0:
		return false
	var normalized := Vector2(position.x / size.x, position.y / size.y)
	for polygon in walkable_polygons:
		if Geometry2D.is_point_in_polygon(normalized, polygon):
			return true
	return false


func _nearest_walkable_position(target: Vector2) -> Vector2:
	var clamped := Vector2(clampf(target.x, 28.0, size.x - 28.0), clampf(target.y, 104.0, size.y - 160.0))
	if _is_walkable_position(clamped):
		return clamped
	for radius in range(8, 321, 8):
		for sample in range(32):
			var angle := TAU * float(sample) / 32.0
			var candidate := clamped + Vector2(cos(angle), sin(angle)) * float(radius)
			candidate.x = clampf(candidate.x, 28.0, size.x - 28.0)
			candidate.y = clampf(candidate.y, 104.0, size.y - 160.0)
			if _is_walkable_position(candidate):
				return candidate
	return Vector2(size.x * 0.5, size.y * 0.70)


func _try_move_player(stride: Vector2) -> bool:
	var origin := player_sprite.position
	var target := origin + stride
	if _is_walkable_position(target):
		player_sprite.position = target
		return true
	var horizontal := Vector2(target.x, origin.y)
	if _is_walkable_position(horizontal):
		player_sprite.position = horizontal
		return true
	var vertical := Vector2(origin.x, target.y)
	if _is_walkable_position(vertical):
		player_sprite.position = vertical
		return true
	return false


func _segment_is_walkable(from: Vector2, to: Vector2) -> bool:
	var sample_count := maxi(1, ceili(from.distance_to(to) / 8.0))
	for index in range(sample_count + 1):
		if not _is_walkable_position(from.lerp(to, float(index) / float(sample_count))):
			return false
	return true


func _nav_cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CITY_NAV_CELL_SIZE


func _nearest_walkable_nav_cell(seed: Vector2i) -> Vector2i:
	for radius in range(0, 9):
		for x_offset in range(-radius, radius + 1):
			for y_offset in range(-radius, radius + 1):
				if radius > 0 and maxi(absi(x_offset), absi(y_offset)) != radius:
					continue
				var candidate := seed + Vector2i(x_offset, y_offset)
				if _is_walkable_position(_nav_cell_center(candidate)):
					return candidate
	return Vector2i(-1, -1)


func _find_walk_path(start: Vector2, destination: Vector2) -> Array[Vector2]:
	var path: Array[Vector2] = []
	if start.distance_to(destination) < 4.0:
		path.append(destination)
		return path
	if _segment_is_walkable(start, destination):
		path.append(destination)
		return path
	var start_seed := Vector2i(floori(start.x / CITY_NAV_CELL_SIZE), floori(start.y / CITY_NAV_CELL_SIZE))
	var end_seed := Vector2i(floori(destination.x / CITY_NAV_CELL_SIZE), floori(destination.y / CITY_NAV_CELL_SIZE))
	var start_cell := _nearest_walkable_nav_cell(start_seed)
	var end_cell := _nearest_walkable_nav_cell(end_seed)
	if start_cell.x < 0 or end_cell.x < 0:
		return path
	var open_set: Array[Vector2i] = [start_cell]
	var came_from: Dictionary = {}
	var travel_cost: Dictionary = {start_cell: 0.0}
	var score: Dictionary = {start_cell: _nav_cell_center(start_cell).distance_to(_nav_cell_center(end_cell))}
	var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	var reached := false
	while not open_set.is_empty():
		var best_index := 0
		for index in range(1, open_set.size()):
			if float(score.get(open_set[index], INF)) < float(score.get(open_set[best_index], INF)):
				best_index = index
		var current: Vector2i = open_set.pop_at(best_index)
		if current == end_cell:
			reached = true
			break
		for direction: Vector2i in directions:
			var neighbor: Vector2i = current + direction
			var neighbor_center := _nav_cell_center(neighbor)
			if not _is_walkable_position(neighbor_center) or not _segment_is_walkable(_nav_cell_center(current), neighbor_center):
				continue
			var move_cost := 1.0 if direction.x == 0 or direction.y == 0 else 1.41421356
			var new_cost := float(travel_cost[current]) + move_cost
			if new_cost >= float(travel_cost.get(neighbor, INF)):
				continue
			came_from[neighbor] = current
			travel_cost[neighbor] = new_cost
			score[neighbor] = new_cost + neighbor_center.distance_to(_nav_cell_center(end_cell)) / CITY_NAV_CELL_SIZE
			if not open_set.has(neighbor):
				open_set.append(neighbor)
	if not reached:
		return path
	var cells: Array[Vector2i] = [end_cell]
	while cells[0] != start_cell:
		if not came_from.has(cells[0]):
			return []
		cells.push_front(came_from[cells[0]])
	var previous := start
	for cell in cells:
		var center := _nav_cell_center(cell)
		if previous.distance_to(center) > 4.0:
			if not _segment_is_walkable(previous, center):
				return []
			path.append(center)
			previous = center
	if previous.distance_to(destination) > 4.0:
		if not _segment_is_walkable(previous, destination):
			return []
		path.append(destination)
	return path


func _refresh_hotspots() -> void:
	for hotspot in hotspot_buttons:
		if is_instance_valid(hotspot):
			hotspot.queue_free()
	hotspot_buttons.clear()
	hotspot_targets.clear()
	for transition in _transitions_for_screen(current_screen):
		_add_hotspot(str(transition.to), str(transition.label), transition.point)
	for poi in CITY_POIS.get(current_screen, []):
		_add_hotspot("poi:" + str(poi.get("id", "")), "✦ INSPECT", poi.get("point", Vector2(0.5, 0.6)))


func _show_city_poi_dialogue(poi_id: String) -> void:
	for poi in CITY_POIS.get(current_screen, []):
		if str(poi.get("id", "")) != poi_id:
			continue
		if dialogue_layer and is_instance_valid(dialogue_layer):
			dialogue_layer.queue_free()
		dialogue_layer = Control.new()
		dialogue_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dialogue_layer.mouse_filter = Control.MOUSE_FILTER_STOP
		dialogue_layer.z_index = 40
		add_child(dialogue_layer)
		var panel := PanelContainer.new()
		panel.anchor_left = 0.12
		panel.anchor_top = 0.18
		panel.anchor_right = 0.88
		panel.anchor_bottom = 0.50
		panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.035, 0.04, 0.96), Color("d0aa69")))
		dialogue_layer.add_child(panel)
		var margin := MarginContainer.new()
		_set_margins(margin, 18, 12, 18, 10)
		panel.add_child(margin)
		var copy := VBoxContainer.new()
		copy.add_theme_constant_override("separation", 8)
		margin.add_child(copy)
		copy.add_child(_label(str(poi.get("label", "CITY DETAIL")), 16, Color("e6bd78")))
		var words := _label(str(poi.get("text", "Nothing stirs here.")), 14, Color("f0e8d5"))
		words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		copy.add_child(words)
		var continue_button := _button("B  •  CLOSE", _close_city_dialogue)
		copy.add_child(continue_button)
		joystick_vector = Vector2.ZERO
		_update_joystick_knob()
		return


func _show_city_screen(screen_id: String, place_hero: bool = true, spawn_override: Vector2 = Vector2(-1.0, -1.0)) -> void:
	if not CITY_SCREENS.has(screen_id):
		screen_id = "plaza"
	current_screen = screen_id
	_configure_city_walkable_areas()
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
	city_subtitle.text = "%s  •  %s" % [str(screen.get("district", "CITY DISTRICT")), str(region_data.get("name", region_id.replace("_", " ").capitalize())).to_upper()]
	scene_back_button.visible = current_screen != "plaza"
	if place_hero:
		var spawn: Vector2 = spawn_override if spawn_override.x >= 0.0 else screen.get("spawn", Vector2(0.5, 0.72))
		player_sprite.position = _nearest_walkable_position(Vector2(size.x * spawn.x, size.y * spawn.y))
		player_sprite.frame = 0
	_refresh_hotspots()
	_refresh_residents()
	_refresh_foreground_cards()
	_update_city_perspective()
	queue_redraw()


func _check_city_transition() -> void:
	if transition_cooldown > 0.0 or not player_sprite or not _is_walkable_position(player_sprite.position):
		return
	var normalized := Vector2(player_sprite.position.x / maxf(1.0, size.x), player_sprite.position.y / maxf(1.0, size.y))
	for transition in _transitions_for_screen(current_screen):
		var point: Vector2 = transition.get("point", Vector2.ZERO)
		var radius: Vector2 = transition.get("radius", Vector2(0.04, 0.04))
		if absf(normalized.x - point.x) > radius.x or absf(normalized.y - point.y) > radius.y:
			continue
		var destination := str(transition.get("to", ""))
		transition_cooldown = 0.65
		_cancel_walk()
		joystick_vector = Vector2.ZERO
		if destination == "territory":
			if not _enter_territory():
				player_sprite.position = _nearest_walkable_position(player_sprite.position + Vector2(0.0, 48.0))
			return
		if CITY_SCREENS.has(destination):
			var spawn: Vector2 = transition.get("spawn", CITY_SCREENS[destination].get("spawn", Vector2(0.5, 0.7)))
			_transition_city_screen(destination, spawn)
		return


func _transition_city_screen(destination: String, spawn: Vector2) -> void:
	if changing_city_screen or not CITY_SCREENS.has(destination):
		return
	changing_city_screen = true
	_cancel_walk()
	joystick_vector = Vector2.ZERO
	city_fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var fade_out := create_tween()
	fade_out.tween_property(city_fade_overlay, "modulate:a", 1.0, 0.16)
	await fade_out.finished
	_show_city_screen(destination, true, spawn)
	_select_location(destination)
	var fade_in := create_tween()
	fade_in.tween_property(city_fade_overlay, "modulate:a", 0.0, 0.22)
	await fade_in.finished
	city_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	changing_city_screen = false
	transition_cooldown = 0.35


func _walk_to_local_exit() -> void:
	var transitions := _transitions_for_screen(current_screen)
	if transitions.is_empty():
		return
	var transition: Dictionary = transitions[0]
	for candidate in transitions:
		if str(candidate.get("to", "")) == "plaza":
			transition = candidate
			break
	var point: Vector2 = transition.get("point", Vector2.ZERO)
	_walk_to_location(str(transition.get("to", "")), Vector2(size.x * point.x, size.y * point.y))


func _select_location(id: String) -> void:
	if CITY_SCREENS.has(id) and id != current_screen:
		return
	selected_location = id
	var descriptions := {
		"plaza": ["CITADEL CROSSROADS", "Four roads split from the central ward. Walk west for the cinder market, east for the living quarter, north to the keep, or south to the outer gate."],
		"market": ["CINDER MARKET", "Stalls and the foundry line the ash-dark street. The alley loops back toward the lower ward; walk to each doorway to enter."],
		"living": ["LIVING QUARTER", "Crowded houses and sealed doors press against the lower ward's road. The inn and side alleys open only from this district."],
		"keep": ["ASHENREACH KEEP", "The keep's audience hall is cut into the volcanic fortress. Return through the western arch to the central ward."],
		"forge": ["THE CINDER FOUNDRY", "The foundry opens directly onto Cinder Market. Return through its arch to reach the district street."],
		"inn": ["THE WAYFARER'S INN", "This smoke-dark refuge opens onto the living quarter. Walk back through the street door to leave."],
		"gate": ["THE OUTER GATE", "Walk through the inner arch to the citadel or head down the outer road to the Ashen Wastes."]
	}
	var data: Array = descriptions.get(id, descriptions["plaza"])
	info_title.text = str(data[0])
	info_body.text = "%s\n\nTap or click the floor to walk." % str(data[1])
	match id:
		"market", "forge": action_button.text = "BROWSE REGIONAL GEAR"
		"inn": action_button.text = "REST • 25 GOLD"
		"gate": action_button.text = "FOLLOW FRONTIER ROAD"
		"living": action_button.text = "VIEW DISTRICT ROUTES"
		_: action_button.text = "VIEW OPEN ROUTES"
	scene_back_button.visible = current_screen != "plaza"


func _activate_location() -> void:
	match selected_location:
		"market", "forge":
			_show_armory()
		"inn":
			_rest_at_inn()
		"gate":
			_travel_to_screen("territory")
		"living":
			_open_selection_map()
		_:
			var open := CAMPAIGN_SERVICE.open_routes()
			var names: PackedStringArray = []
			for territory_id in open:
				names.append(str(CAMPAIGN_SERVICE.territory(territory_id).get("name", territory_id)))
			info_body.text = "Open routes: %s" % (", ".join(names) if not names.is_empty() else "secure a connected territory to reopen the roads")


func _return_to_plaza() -> void:
	_walk_to_local_exit()


func _show_armory() -> void:
	_open_selection()
	_show_selection_equipment()


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


func _enter_territory() -> bool:
	if not CAMPAIGN_SERVICE.is_route_open(region_id) and not (CAMPAIGN_SERVICE.state().get("secured_territories", []) as Array).has(region_id):
		info_body.text = "This city's road is sealed. Reconnect a neighboring territory first."
		return false
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
	return true


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
