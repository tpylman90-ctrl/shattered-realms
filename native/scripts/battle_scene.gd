extends Node3D

const HeroProgressionService = preload("res://scripts/hero_progression.gd")
const HeroEquipmentService = preload("res://scripts/hero_equipment.gd")

const RETURN_SCENE := "res://scenes/AshenreachDemo.tscn"
const CONTEXT_PATH := "user://battle_context.cfg"
const RESULT_PATH := "user://battle_result.cfg"
const CATALOG_PATH := "res://data/world_catalog.json"
const BACKDROP_PATH := "res://assets/battle/generated/ashenreach_battle_arena.png"

var context: Dictionary = {}
var hero_data: Dictionary = {}

var hero_id := "ignis"
var encounter_id := ""
var enemy_name := "Enemy"
var enemy_family := "skirmisher"
var hero_name := "Hero"

var hero_hp := 100
var hero_max_hp := 100
var hero_xp := 0
var hero_level := 1
var hero_mp := 0
var hero_max_mp := 0
var hero_stats: Dictionary = {}
var hero_profile: Dictionary = {}
var enemy_effects: Dictionary = {}
var hero_effects: Dictionary = {}
var enemy_hp := 70
var enemy_max_hp := 70
var enemy_attack := 10
var reward_xp := 25
var danger := 1

var hero_atb := 0.0
var enemy_atb := 0.0
var hero_ready := false
var active_actor_id := ""
var command_position := "rear"
var army_slots: Array[Dictionary] = []
var army_anchors: Array[Node3D] = []
var army_slot_panels: Array[PanelContainer] = []
var army_slot_labels: Array[Label] = []
var army_slot_hp_bars: Array[ProgressBar] = []
var army_slot_atb_bars: Array[ProgressBar] = []
var battle_over := false
var defending := false
var guard_multiplier := 0.45
var item_used := false
var action_locked := false

var hero_anchor: Node3D
var enemy_anchor: Node3D
var battle_camera: Camera3D
var transition_rect: ColorRect
var battle_ui_layer: CanvasLayer
var backdrop_loaded := false

var hero_hp_label: Label
var hero_mp_label: Label
var enemy_hp_label: Label
var hero_hp_bar: ProgressBar
var enemy_hp_bar: ProgressBar
var hero_atb_bar: ProgressBar
var enemy_atb_bar: ProgressBar
var message_label: Label
var command_box: Control
var command_center_label: Label
var attack_button: Button
var skills_button: Button
var defend_button: Button
var item_button: Button
var skill_panel: PanelContainer
var skill_list: VBoxContainer
var formation_strip: HBoxContainer


func _ready() -> void:
    action_locked = true
    _load_context()
    _load_hero_data()
    _load_progression_profile()
    _build_background()
    _build_world()
    _build_army_formation()
    _build_ui()
    _spawn_hero()
    _spawn_army_placeholders()
    _spawn_enemy_placeholder()
    _refresh_ui()
    message_label.text = "%s confronts %s." % [hero_name, enemy_name]
    if not backdrop_loaded:
        message_label.text += "  [Backdrop asset failed to load]"
    await _play_battle_intro()
    action_locked = false


func _process(delta: float) -> void:
    if battle_over or action_locked:
        return

    if command_box and command_box.visible:
        _update_command_ring_position()

    # Wait-mode ATB: once any controllable actor is ready, battle time pauses
    # until that actor receives a command.
    if active_actor_id != "":
        _refresh_gauges()
        return

    hero_atb = minf(1.0, hero_atb + delta * 0.31)
    for slot in army_slots:
        if int(slot.get("hp", 0)) <= 0:
            continue
        var atb := float(slot.get("atb", 0.0))
        var speed_scale := float(slot.get("speed_scale", 1.0))
        slot["atb"] = minf(1.0, atb + delta * 0.27 * speed_scale)

    if hero_hp > 0 and hero_atb >= 1.0:
        hero_atb = 1.0
        hero_ready = true
        _begin_actor_turn("hero")
        return

    for i in range(army_slots.size()):
        var slot: Dictionary = army_slots[i]
        if int(slot.get("hp", 0)) > 0 and float(slot.get("atb", 0.0)) >= 1.0:
            slot["atb"] = 1.0
            _begin_actor_turn("army_%d" % i)
            return

    var slow_factor := 0.65 if enemy_effects.has("slow") else 1.0
    enemy_atb = minf(1.0, enemy_atb + delta * (0.20 + float(danger) * 0.025) * slow_factor)
    if enemy_atb >= 1.0:
        enemy_atb = 0.0
        _enemy_turn()

    _refresh_gauges()

func _load_context() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(CONTEXT_PATH) != OK:
        return

    hero_id = str(cfg.get_value("battle", "hero_id", "ignis"))
    encounter_id = str(cfg.get_value("battle", "encounter_id", ""))
    enemy_name = str(cfg.get_value("battle", "enemy_name", "Enemy"))
    enemy_family = str(cfg.get_value("battle", "enemy_family", "skirmisher"))
    hero_hp = int(cfg.get_value("battle", "hero_hp", 100))
    hero_max_hp = int(cfg.get_value("battle", "hero_max_hp", 100))
    hero_xp = int(cfg.get_value("battle", "hero_xp", 0))
    enemy_max_hp = int(cfg.get_value("battle", "enemy_hp", 70))
    enemy_hp = enemy_max_hp
    enemy_attack = int(cfg.get_value("battle", "enemy_attack", 10))
    reward_xp = int(cfg.get_value("battle", "reward_xp", 25))
    danger = int(cfg.get_value("battle", "danger", 1))


func _load_hero_data() -> void:
    if not FileAccess.file_exists(CATALOG_PATH):
        return

    var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
    if not file:
        return

    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        return

    var catalog: Dictionary = parsed as Dictionary
    var heroes_variant: Variant = catalog.get("heroes", {})
    if not heroes_variant is Dictionary:
        return

    var heroes: Dictionary = heroes_variant as Dictionary
    if heroes.has(hero_id):
        hero_data = (heroes[hero_id] as Dictionary).duplicate(true)
        hero_name = str(hero_data.get("name", hero_id))


func _load_progression_profile() -> void:
    hero_profile = HeroProgressionService.ensure_profile(hero_id, hero_xp)
    if hero_profile.is_empty():
        hero_level = 1
        hero_stats = {"hp": 100, "mp": 40, "power": 15, "magic": 15, "defense": 10, "resistance": 10, "speed": 10, "crit": 5.0}
        hero_max_hp = 100
        hero_max_mp = 40
        hero_mp = hero_max_mp
        return

    hero_level = int(hero_profile.get("level", 1))
    hero_xp = int(hero_profile.get("xp", hero_xp))
    hero_stats = (hero_profile.get("stats", {}) as Dictionary).duplicate(true)
    hero_stats = HeroEquipmentService.effective_stats(hero_id, hero_stats)
    hero_max_hp = int(hero_stats.get("hp", 100))
    hero_max_mp = int(hero_stats.get("mp", 40))
    hero_mp = hero_max_mp
    hero_hp = clampi(hero_hp, 1, hero_max_hp)


func _build_background() -> void:
    var backdrop := MeshInstance3D.new()
    backdrop.name = "BattleBackdrop"

    # Oversize the backdrop so camera framing changes can never expose the
    # viewport clear color around the image.
    var quad := QuadMesh.new()
    quad.size = Vector2(24.0, 13.5)
    backdrop.mesh = quad
    backdrop.position = Vector3(0.0, 1.05, -6.0)
    backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    mat.albedo_color = Color.WHITE

    var texture := load(BACKDROP_PATH) as Texture2D
    if texture:
        mat.albedo_texture = texture
        backdrop_loaded = true
    else:
        # Bright diagnostic fallback: if this ever appears we know immediately
        # that asset loading failed rather than camera framing being wrong.
        mat.albedo_color = Color(0.34, 0.015, 0.015, 1.0)
        backdrop_loaded = false
        push_error("Battle backdrop failed to load: %s" % BACKDROP_PATH)

    backdrop.material_override = mat
    add_child(backdrop)

func _build_world() -> void:
    battle_camera = Camera3D.new()
    battle_camera.position = Vector3(0.0, 2.35, 8.2)
    battle_camera.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
    battle_camera.fov = 42.0
    add_child(battle_camera)
    battle_camera.current = true

    var key_light := DirectionalLight3D.new()
    key_light.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
    key_light.light_energy = 2.0
    key_light.shadow_enabled = true
    add_child(key_light)

    var warm_light := OmniLight3D.new()
    warm_light.position = Vector3(0.0, 2.0, 1.0)
    warm_light.light_color = Color(1.0, 0.34, 0.10)
    warm_light.light_energy = 5.0
    warm_light.omni_range = 10.0
    add_child(warm_light)

    hero_anchor = Node3D.new()
    hero_anchor.position = Vector3(-2.35, -1.28, 0.15)
    hero_anchor.rotation_degrees.y = -12.0
    add_child(hero_anchor)

    enemy_anchor = Node3D.new()
    enemy_anchor.position = Vector3(2.30, -1.22, 0.10)
    enemy_anchor.rotation_degrees.y = 168.0
    add_child(enemy_anchor)

    _add_shadow_disc(hero_anchor, 0.80)
    _add_shadow_disc(enemy_anchor, 0.92)


func _build_army_formation() -> void:
    army_slots.clear()
    army_anchors.clear()

    var definitions := [
        {"name":"Vanguard I","hp":72,"max_hp":72,"power":11,"defense":8,"speed_scale":1.02,"ability_name":"Shield Bash","ability_bonus":8},
        {"name":"Vanguard II","hp":72,"max_hp":72,"power":11,"defense":8,"speed_scale":0.98,"ability_name":"Shield Bash","ability_bonus":8},
        {"name":"Ranger I","hp":60,"max_hp":60,"power":13,"defense":6,"speed_scale":1.10,"ability_name":"Aimed Shot","ability_bonus":12},
        {"name":"Ranger II","hp":60,"max_hp":60,"power":13,"defense":6,"speed_scale":1.06,"ability_name":"Aimed Shot","ability_bonus":12},
    ]

    var positions := [
        Vector3(-1.45, -1.24, 0.58),
        Vector3(-1.55, -1.24, -0.38),
        Vector3(-2.35, -1.24, 0.86),
        Vector3(-2.48, -1.24, -0.68),
    ]

    # Commander defaults to rear. This is deliberately stored as formation data
    # so front/middle/rear can become a pre-battle selection later.
    if command_position == "front":
        hero_anchor.position = Vector3(-1.15, -1.28, 0.10)
    elif command_position == "middle":
        hero_anchor.position = Vector3(-2.05, -1.28, 0.10)
    else:
        hero_anchor.position = Vector3(-3.15, -1.28, 0.10)

    for i in range(4):
        var anchor := Node3D.new()
        anchor.name = "ArmySlot%d" % (i + 1)
        anchor.position = positions[i]
        anchor.rotation_degrees.y = -10.0
        add_child(anchor)
        army_anchors.append(anchor)
        _add_shadow_disc(anchor, 0.48)

        var slot: Dictionary = definitions[i].duplicate(true)
        slot["atb"] = 0.0
        slot["defending"] = false
        slot["guard_multiplier"] = 0.50
        army_slots.append(slot)


func _spawn_army_placeholders() -> void:
    var colors := [
        Color(0.22, 0.48, 0.78),
        Color(0.20, 0.42, 0.72),
        Color(0.32, 0.64, 0.42),
        Color(0.28, 0.58, 0.38),
    ]
    for i in range(army_anchors.size()):
        var anchor := army_anchors[i]
        _spawn_base_unit_placeholder(anchor, colors[i], i < 2)


func _spawn_base_unit_placeholder(parent: Node3D, color: Color, armored: bool) -> void:
    var body := MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.radius = 0.26 if armored else 0.23
    mesh.height = 1.02
    body.mesh = mesh
    body.position.y = 0.55
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = 0.30 if armored else 0.12
    mat.roughness = 0.58
    body.material_override = mat
    parent.add_child(body)


func _add_shadow_disc(parent: Node3D, radius: float) -> void:
    var shadow := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = 0.02
    mesh.radial_segments = 32
    shadow.mesh = mesh
    shadow.position.y = 0.02

    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_color = Color(0.0, 0.0, 0.0, 0.48)
    shadow.material_override = mat
    parent.add_child(shadow)


func _spawn_hero() -> void:
    var asset_path := str(hero_data.get("piece_asset", ""))
    if asset_path == "" or not ResourceLoader.exists(asset_path):
        _spawn_placeholder(hero_anchor, Color(0.15, 0.75, 0.95), 1.0)
        return

    var packed := load(asset_path) as PackedScene
    if not packed:
        _spawn_placeholder(hero_anchor, Color(0.15, 0.75, 0.95), 1.0)
        return

    var instance := packed.instantiate()
    if not instance is Node3D:
        instance.queue_free()
        _spawn_placeholder(hero_anchor, Color(0.15, 0.75, 0.95), 1.0)
        return

    var model := instance as Node3D
    var scale_value := float(hero_data.get("piece_scale", 3.0)) * 0.72
    var piece_offset: Array = hero_data.get("piece_offset", [0.0, 0.0, 0.0])
    var x_offset := float(piece_offset[0]) if piece_offset.size() > 0 else 0.0
    var y_offset := float(piece_offset[1]) if piece_offset.size() > 1 else 0.0
    var z_offset := float(piece_offset[2]) if piece_offset.size() > 2 else 0.0

    model.scale = Vector3.ONE * scale_value
    model.position = Vector3(x_offset, y_offset, z_offset)
    hero_anchor.add_child(model)


func _spawn_enemy_placeholder() -> void:
    if enemy_family == "hound":
        _spawn_hound_placeholder()
    elif enemy_family == "revenant":
        _spawn_wraith_placeholder()
    elif enemy_family == "warden":
        _spawn_placeholder(enemy_anchor, Color(0.46, 0.12, 0.06), 1.34)
    elif enemy_family == "stalker":
        _spawn_placeholder(enemy_anchor, Color(0.28, 0.08, 0.05), 0.96)
    else:
        _spawn_placeholder(enemy_anchor, Color(0.85, 0.12, 0.035), 1.10)


func _spawn_wraith_placeholder() -> void:
    var body := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.30
    mesh.bottom_radius = 0.70
    mesh.height = 1.75
    mesh.radial_segments = 20
    body.mesh = mesh
    body.position.y = 0.92

    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.16, 0.04, 0.03, 0.94)
    mat.emission_enabled = true
    mat.emission = Color(0.95, 0.10, 0.025)
    mat.emission_energy_multiplier = 1.25
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    body.material_override = mat
    enemy_anchor.add_child(body)

    var core := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.30
    sphere.height = 0.60
    core.mesh = sphere
    core.position.y = 1.55
    var core_mat := mat.duplicate() as StandardMaterial3D
    core_mat.albedo_color = Color(1.0, 0.18, 0.03)
    core_mat.emission_energy_multiplier = 2.1
    core.material_override = core_mat
    enemy_anchor.add_child(core)


func _spawn_hound_placeholder() -> void:
    var body := MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.radius = 0.38
    mesh.height = 1.35
    body.mesh = mesh
    body.rotation_degrees.z = 90.0
    body.position = Vector3(0.0, 0.58, 0.0)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.20, 0.045, 0.02)
    mat.emission_enabled = true
    mat.emission = Color(0.95, 0.16, 0.02)
    mat.emission_energy_multiplier = 0.85
    body.material_override = mat
    enemy_anchor.add_child(body)

    var head := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.34
    sphere.height = 0.68
    head.mesh = sphere
    head.position = Vector3(-0.70, 0.67, 0.0)
    head.material_override = mat
    enemy_anchor.add_child(head)

func _spawn_placeholder(parent: Node3D, color: Color, scale_value: float) -> void:
    var body := MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.radius = 0.48
    mesh.height = 1.55
    body.mesh = mesh
    body.position.y = 0.82
    body.scale = Vector3.ONE * scale_value

    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.emission_enabled = true
    mat.emission = color * 0.45
    mat.emission_energy_multiplier = 0.8
    mat.metallic = 0.2
    mat.roughness = 0.62
    body.material_override = mat
    parent.add_child(body)


func _build_ui() -> void:
    battle_ui_layer = CanvasLayer.new()
    battle_ui_layer.layer = 10
    add_child(battle_ui_layer)

    var mode_label := Label.new()
    mode_label.text = "ASHENREACH • ATB WAIT"
    mode_label.position = Vector2(28.0, 8.0)
    mode_label.add_theme_font_size_override("font_size", 12)
    mode_label.modulate = Color(1.0, 0.72, 0.45, 0.92)
    battle_ui_layer.add_child(mode_label)

    var top := PanelContainer.new()
    top.anchor_left = 0.0
    top.anchor_top = 0.0
    top.anchor_right = 1.0
    top.anchor_bottom = 0.0
    top.offset_left = 22.0
    top.offset_top = 18.0
    top.offset_right = -22.0
    top.offset_bottom = 102.0
    battle_ui_layer.add_child(top)

    var top_margin := MarginContainer.new()
    top_margin.add_theme_constant_override("margin_left", 16)
    top_margin.add_theme_constant_override("margin_top", 10)
    top_margin.add_theme_constant_override("margin_right", 16)
    top_margin.add_theme_constant_override("margin_bottom", 10)
    var top_style := StyleBoxFlat.new()
    top_style.bg_color = Color(0.025, 0.02, 0.025, 0.84)
    top_style.corner_radius_top_left = 8
    top_style.corner_radius_top_right = 8
    top_style.corner_radius_bottom_left = 8
    top_style.corner_radius_bottom_right = 8
    top.add_theme_stylebox_override("panel", top_style)
    top.add_child(top_margin)

    var top_row := HBoxContainer.new()
    top_row.add_theme_constant_override("separation", 18)
    top_margin.add_child(top_row)

    var hero_box := VBoxContainer.new()
    hero_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top_row.add_child(hero_box)

    hero_hp_label = Label.new()
    hero_box.add_child(hero_hp_label)
    hero_hp_bar = ProgressBar.new()
    hero_hp_bar.show_percentage = false
    hero_box.add_child(hero_hp_bar)

    hero_mp_label = Label.new()
    hero_box.add_child(hero_mp_label)

    hero_atb_bar = ProgressBar.new()
    hero_atb_bar.show_percentage = false
    hero_box.add_child(hero_atb_bar)

    var enemy_box := VBoxContainer.new()
    enemy_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top_row.add_child(enemy_box)

    enemy_hp_label = Label.new()
    enemy_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    enemy_box.add_child(enemy_hp_label)
    enemy_hp_bar = ProgressBar.new()
    enemy_hp_bar.show_percentage = false
    enemy_box.add_child(enemy_hp_bar)
    enemy_atb_bar = ProgressBar.new()
    enemy_atb_bar.show_percentage = false
    enemy_box.add_child(enemy_atb_bar)

    # Lightweight battle feed: no blocking panel over the battlefield.
    message_label = Label.new()
    message_label.anchor_left = 0.5
    message_label.anchor_top = 0.0
    message_label.anchor_right = 0.5
    message_label.anchor_bottom = 0.0
    message_label.offset_left = -300.0
    message_label.offset_top = 108.0
    message_label.offset_right = 300.0
    message_label.offset_bottom = 142.0
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    message_label.add_theme_font_size_override("font_size", 14)
    message_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.82, 0.94))
    message_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.92))
    message_label.add_theme_constant_override("shadow_offset_x", 2)
    message_label.add_theme_constant_override("shadow_offset_y", 2)
    message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    battle_ui_layer.add_child(message_label)

    # Radial command wheel inspired by classic console RPG input, but with
    # Shattered Realms' own four-command layout and visual treatment.
    command_box = Control.new()
    command_box.name = "CommandWheel"
    command_box.anchor_left = 0.0
    command_box.anchor_top = 0.0
    command_box.anchor_right = 0.0
    command_box.anchor_bottom = 0.0
    command_box.position = Vector2.ZERO
    command_box.size = Vector2(360.0, 275.0)
    command_box.pivot_offset = Vector2(180.0, 137.5)
    command_box.visible = false
    battle_ui_layer.add_child(command_box)

    var ring := Panel.new()
    ring.position = Vector2(104.0, 58.0)
    ring.size = Vector2(152.0, 152.0)
    ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var ring_style := StyleBoxFlat.new()
    ring_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
    ring_style.border_width_left = 4
    ring_style.border_width_top = 4
    ring_style.border_width_right = 4
    ring_style.border_width_bottom = 4
    ring_style.border_color = Color(0.45, 0.50, 0.56, 0.88)
    ring_style.corner_radius_top_left = 76
    ring_style.corner_radius_top_right = 76
    ring_style.corner_radius_bottom_left = 76
    ring_style.corner_radius_bottom_right = 76
    ring.add_theme_stylebox_override("panel", ring_style)
    command_box.add_child(ring)

    var center := Panel.new()
    center.position = Vector2(132.0, 86.0)
    center.size = Vector2(96.0, 96.0)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var center_style := StyleBoxFlat.new()
    center_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
    center_style.border_width_left = 3
    center_style.border_width_top = 3
    center_style.border_width_right = 3
    center_style.border_width_bottom = 3
    center_style.border_color = Color(0.95, 0.42, 0.16, 0.92)
    center_style.corner_radius_top_left = 48
    center_style.corner_radius_top_right = 48
    center_style.corner_radius_bottom_left = 48
    center_style.corner_radius_bottom_right = 48
    center.add_theme_stylebox_override("panel", center_style)
    command_box.add_child(center)

    command_center_label = Label.new()
    command_center_label.position = Vector2(0.0, 26.0)
    command_center_label.size = Vector2(96.0, 44.0)
    command_center_label.text = "WAIT"
    command_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    command_center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    command_center_label.add_theme_font_size_override("font_size", 14)
    command_center_label.modulate = Color(1.0, 0.72, 0.45)
    center.add_child(command_center_label)

    skills_button = _make_radial_button("SKILLS", Vector2(126.0, 4.0), _open_skill_panel)
    attack_button = _make_radial_button("ATTACK", Vector2(246.0, 109.0), _on_attack)
    defend_button = _make_radial_button("DEFEND", Vector2(126.0, 214.0), _on_defend)
    item_button = _make_radial_button("ITEM", Vector2(6.0, 109.0), _on_item)

    _build_formation_strip()
    _build_skill_panel()
    _set_commands_enabled(false)

    transition_rect = ColorRect.new()
    transition_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    transition_rect.color = Color(0.0, 0.0, 0.0, 1.0)
    battle_ui_layer.add_child(transition_rect)


func _build_formation_strip() -> void:
    formation_strip = HBoxContainer.new()
    formation_strip.anchor_left = 0.5
    formation_strip.anchor_top = 1.0
    formation_strip.anchor_right = 0.5
    formation_strip.anchor_bottom = 1.0
    formation_strip.offset_left = -300.0
    formation_strip.offset_top = -74.0
    formation_strip.offset_right = 300.0
    formation_strip.offset_bottom = -16.0
    formation_strip.alignment = BoxContainer.ALIGNMENT_CENTER
    formation_strip.add_theme_constant_override("separation", 7)
    battle_ui_layer.add_child(formation_strip)

    army_slot_panels.clear()
    army_slot_labels.clear()
    army_slot_hp_bars.clear()
    army_slot_atb_bars.clear()

    for i in range(4):
        var panel := PanelContainer.new()
        panel.custom_minimum_size = Vector2(132.0, 54.0)
        var style := StyleBoxFlat.new()
        style.bg_color = Color(0.025, 0.022, 0.03, 0.86)
        style.border_width_left = 2
        style.border_width_top = 2
        style.border_width_right = 2
        style.border_width_bottom = 2
        style.border_color = Color(0.30, 0.34, 0.40, 0.9)
        style.corner_radius_top_left = 7
        style.corner_radius_top_right = 7
        style.corner_radius_bottom_left = 7
        style.corner_radius_bottom_right = 7
        panel.add_theme_stylebox_override("panel", style)
        formation_strip.add_child(panel)

        var box := VBoxContainer.new()
        panel.add_child(box)

        var label := Label.new()
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size", 10)
        box.add_child(label)

        var hp := ProgressBar.new()
        hp.show_percentage = false
        hp.custom_minimum_size = Vector2(120.0, 8.0)
        box.add_child(hp)

        var atb := ProgressBar.new()
        atb.show_percentage = false
        atb.custom_minimum_size = Vector2(120.0, 6.0)
        box.add_child(atb)

        army_slot_panels.append(panel)
        army_slot_labels.append(label)
        army_slot_hp_bars.append(hp)
        army_slot_atb_bars.append(atb)


func _begin_actor_turn(actor_id: String) -> void:
    active_actor_id = actor_id
    _set_commands_enabled(true)

    if actor_id == "hero":
        hero_ready = true
        skills_button.text = "SKILLS"
        item_button.text = "ITEM"
        message_label.text = "%s is ready." % hero_name
    else:
        hero_ready = false
        item_button.text = "HOLD"
        var index := int(actor_id.trim_prefix("army_"))
        var slot: Dictionary = army_slots[index]
        skills_button.text = str(slot.get("ability_name", "ABILITY")).to_upper()
        message_label.text = "%s is ready." % str(slot.get("name", "Unit"))

    _configure_commands_for_active_actor()
    _update_command_ring_position()
    _animate_command_ring_open()
    _refresh_gauges()


func _configure_commands_for_active_actor() -> void:
    var is_hero := active_actor_id == "hero"
    attack_button.text = "ATTACK"
    if is_hero:
        skills_button.text = "SKILLS"
    else:
        var index := int(active_actor_id.trim_prefix("army_"))
        skills_button.text = str(army_slots[index].get("ability_name", "ABILITY")).to_upper()
    defend_button.text = "DEFEND"
    item_button.text = "ITEM" if is_hero else "HOLD"
    skills_button.disabled = false
    item_button.disabled = item_used if is_hero else false


func _animate_command_ring_open() -> void:
    if not command_box:
        return
    command_box.scale = Vector2(0.86, 0.86)
    command_box.modulate.a = 0.0
    var tween := create_tween()
    tween.set_parallel(true)
    tween.set_trans(Tween.TRANS_BACK)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(command_box, "scale", Vector2.ONE, 0.16)
    tween.tween_property(command_box, "modulate:a", 1.0, 0.12)


func _active_actor_anchor() -> Node3D:
    if active_actor_id == "hero":
        return hero_anchor
    if active_actor_id.begins_with("army_"):
        var index := int(active_actor_id.trim_prefix("army_"))
        if index >= 0 and index < army_anchors.size():
            return army_anchors[index]
    return null


func _update_command_ring_position() -> void:
    if not command_box or not command_box.visible or not battle_camera:
        return
    var anchor := _active_actor_anchor()
    if not anchor:
        return

    var world_pos := anchor.global_position + Vector3(0.0, 0.95, 0.0)
    var screen_pos := battle_camera.unproject_position(world_pos)
    var view := get_viewport().get_visible_rect().size
    var top_left := screen_pos - Vector2(180.0, 137.0)
    top_left.x = clampf(top_left.x, 6.0, maxf(6.0, view.x - 366.0))
    top_left.y = clampf(top_left.y, 112.0, maxf(112.0, view.y - 281.0))
    command_box.position = top_left


func _consume_active_turn() -> void:
    if active_actor_id == "hero":
        _tick_effects(hero_effects)
        hero_ready = false
        hero_atb = 0.0
    elif active_actor_id.begins_with("army_"):
        var index := int(active_actor_id.trim_prefix("army_"))
        if index >= 0 and index < army_slots.size():
            army_slots[index]["atb"] = 0.0

    active_actor_id = ""
    if command_box:
        command_box.visible = false
    _set_commands_enabled(false)


func _play_battle_intro() -> void:
    var hero_home: Vector3 = hero_anchor.position
    var enemy_home: Vector3 = enemy_anchor.position
    hero_anchor.position = hero_home + Vector3(-1.2, 0.0, 0.0)
    enemy_anchor.position = enemy_home + Vector3(1.2, 0.0, 0.0)

    var entrance := create_tween()
    entrance.set_parallel(true)
    entrance.set_trans(Tween.TRANS_QUAD)
    entrance.set_ease(Tween.EASE_OUT)
    entrance.tween_property(hero_anchor, "position", hero_home, 0.42)
    entrance.tween_property(enemy_anchor, "position", enemy_home, 0.42)
    entrance.tween_property(transition_rect, "color:a", 0.0, 0.50)
    await entrance.finished


func _show_damage_popup(anchor: Node3D, amount: int, is_heal: bool = false) -> void:
    var label := Label3D.new()
    label.text = ("+%d" % amount) if is_heal else str(amount)
    label.font_size = 52
    label.outline_size = 9
    label.modulate = Color(0.35, 1.0, 0.45) if is_heal else Color(1.0, 0.82, 0.28)
    label.position = anchor.position + Vector3(0.0, 2.05, 0.35)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    add_child(label)

    var start: Vector3 = label.position
    var tween := create_tween()
    tween.set_parallel(true)
    tween.tween_property(label, "position", start + Vector3(0.0, 0.72, 0.0), 0.68)
    tween.tween_property(label, "modulate:a", 0.0, 0.68)
    await tween.finished
    label.queue_free()


func _impact_bump(actor: Node3D, strength: float = 0.10) -> void:
    var start_scale: Vector3 = actor.scale
    var tween := create_tween()
    tween.tween_property(actor, "scale", start_scale * (1.0 + strength), 0.07)
    tween.tween_property(actor, "scale", start_scale, 0.12)
    await tween.finished


func _camera_impact(strength: float = 0.08) -> void:
    if not battle_camera:
        return
    var start: Vector3 = battle_camera.position
    var tween := create_tween()
    tween.tween_property(battle_camera, "position", start + Vector3(strength, 0.0, 0.0), 0.045)
    tween.tween_property(battle_camera, "position", start - Vector3(strength * 0.65, 0.0, 0.0), 0.045)
    tween.tween_property(battle_camera, "position", start, 0.055)
    await tween.finished


func _make_radial_button(label_text: String, position: Vector2, callback: Callable) -> Button:
    var button := Button.new()
    button.text = label_text
    button.position = position
    button.size = Vector2(108.0, 50.0)
    button.add_theme_font_size_override("font_size", 14)

    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.045, 0.04, 0.05, 0.94)
    normal.border_width_left = 2
    normal.border_width_top = 2
    normal.border_width_right = 2
    normal.border_width_bottom = 2
    normal.border_color = Color(0.40, 0.44, 0.50, 0.92)
    normal.corner_radius_top_left = 25
    normal.corner_radius_top_right = 25
    normal.corner_radius_bottom_left = 25
    normal.corner_radius_bottom_right = 25

    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = Color(0.18, 0.075, 0.04, 0.98)
    hover.border_color = Color(1.0, 0.48, 0.18, 1.0)

    var pressed := hover.duplicate() as StyleBoxFlat
    pressed.bg_color = Color(0.30, 0.10, 0.035, 1.0)

    var disabled := normal.duplicate() as StyleBoxFlat
    disabled.bg_color = Color(0.025, 0.025, 0.03, 0.70)
    disabled.border_color = Color(0.23, 0.25, 0.28, 0.70)

    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("disabled", disabled)
    button.pressed.connect(callback)
    command_box.add_child(button)
    return button

func _set_commands_enabled(enabled: bool) -> void:
    if not attack_button:
        return
    attack_button.disabled = not enabled
    skills_button.disabled = not enabled
    defend_button.disabled = not enabled
    item_button.disabled = not enabled or item_used
    if command_box:
        command_box.visible = enabled and active_actor_id != ""
        if not enabled:
            command_box.modulate.a = 0.0
    if command_center_label:
        command_center_label.text = "READY" if enabled else "WAIT"
        command_center_label.modulate = Color(1.0, 0.72, 0.45) if enabled else Color(0.62, 0.64, 0.68)


func _refresh_gauges() -> void:
    hero_atb_bar.value = hero_atb * 100.0
    enemy_atb_bar.value = enemy_atb * 100.0

    for i in range(mini(army_slots.size(), army_slot_atb_bars.size())):
        var slot: Dictionary = army_slots[i]
        army_slot_atb_bars[i].max_value = 100.0
        army_slot_atb_bars[i].value = float(slot.get("atb", 0.0)) * 100.0
        army_slot_hp_bars[i].max_value = int(slot.get("max_hp", 1))
        army_slot_hp_bars[i].value = int(slot.get("hp", 0))
        var hp_now := int(slot.get("hp", 0))
        var hp_max := int(slot.get("max_hp", 1))
        var state_suffix := "  DEF" if bool(slot.get("defending", false)) else ""
        army_slot_labels[i].text = "%s  %d/%d%s" % [
            str(slot.get("name", "Unit")),
            hp_now,
            hp_max,
            state_suffix
        ]

        var actor_match := active_actor_id == "army_%d" % i
        if hp_now <= 0:
            army_slot_panels[i].modulate = Color(0.38, 0.38, 0.38, 0.58)
            army_slot_labels[i].modulate = Color(0.60, 0.60, 0.60)
        elif actor_match:
            army_slot_panels[i].modulate = Color(1.18, 0.86, 0.48, 1.0)
            army_slot_labels[i].modulate = Color(1.0, 0.82, 0.45)
        elif float(hp_now) / float(maxi(1, hp_max)) <= 0.30:
            army_slot_panels[i].modulate = Color(1.0, 0.62, 0.62, 1.0)
            army_slot_labels[i].modulate = Color(1.0, 0.48, 0.42)
        else:
            army_slot_panels[i].modulate = Color.WHITE
            army_slot_labels[i].modulate = Color.WHITE


func _refresh_ui() -> void:
    hero_hp_bar.max_value = hero_max_hp
    hero_hp_bar.value = hero_hp
    enemy_hp_bar.max_value = enemy_max_hp
    enemy_hp_bar.value = enemy_hp
    hero_atb_bar.max_value = 100.0
    enemy_atb_bar.max_value = 100.0

    var hero_status := ""
    for effect in hero_effects.keys():
        hero_status += " • %s %d" % [str(effect).to_upper(), int(hero_effects[effect])]
    hero_hp_label.text = "%s  LV %d  •  HP %d/%d%s" % [hero_name, hero_level, hero_hp, hero_max_hp, hero_status]
    hero_mp_label.text = "MP %d/%d  •  SP %d" % [hero_mp, hero_max_mp, int(hero_profile.get("skill_points", 0))]
    var enemy_status := ""
    for effect in enemy_effects.keys():
        enemy_status += " • %s %d" % [str(effect).to_upper(), int(enemy_effects[effect])]
    enemy_hp_label.text = "%s  HP %d/%d%s" % [enemy_name, enemy_hp, enemy_max_hp, enemy_status]

    var hero_ratio := float(hero_hp) / float(maxi(1, hero_max_hp))
    if hero_ratio <= 0.30:
        hero_hp_label.modulate = Color(1.0, 0.42, 0.36)
    elif active_actor_id == "hero":
        hero_hp_label.modulate = Color(1.0, 0.78, 0.42)
    else:
        hero_hp_label.modulate = Color.WHITE

    _refresh_gauges()


func _consume_hero_turn() -> void:
    _consume_active_turn()


func _on_attack() -> void:
    if active_actor_id == "" or action_locked or battle_over:
        return

    action_locked = true
    var actor_id := active_actor_id
    var actor_anchor := _active_actor_anchor()
    var actor_name := hero_name
    var power := int(hero_stats.get("power", 15))

    if actor_id.begins_with("army_"):
        var index := int(actor_id.trim_prefix("army_"))
        var slot: Dictionary = army_slots[index]
        actor_name = str(slot.get("name", "Unit"))
        power = int(slot.get("power", 10))

    _consume_active_turn()
    var damage := 6 + int(round(float(power) * 0.72)) + randi_range(0, 4)
    if enemy_effects.has("sunder"):
        damage = int(round(float(damage) * 1.25))
    if actor_id == "hero" and hero_effects.has("rally"):
        damage = int(round(float(damage) * 1.20))
    message_label.text = "%s attacks for %d damage!" % [actor_name, damage]

    await _lunge(actor_anchor, 0.34)
    enemy_hp = maxi(0, enemy_hp - damage)
    _refresh_ui()
    _show_damage_popup(enemy_anchor, damage)
    _impact_bump(enemy_anchor, 0.10)
    _camera_impact(0.06)
    await get_tree().create_timer(0.45).timeout
    action_locked = false
    _check_battle_end()


func _build_skill_panel() -> void:
    skill_panel = PanelContainer.new()
    skill_panel.visible = false
    skill_panel.anchor_left = 0.0
    skill_panel.anchor_top = 1.0
    skill_panel.anchor_right = 0.0
    skill_panel.anchor_bottom = 1.0
    skill_panel.offset_left = 735.0
    skill_panel.offset_top = -365.0
    skill_panel.offset_right = 1165.0
    skill_panel.offset_bottom = -55.0

    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.025, 0.02, 0.025, 0.94)
    panel_style.border_width_left = 2
    panel_style.border_width_top = 2
    panel_style.border_width_right = 2
    panel_style.border_width_bottom = 2
    panel_style.border_color = Color(0.68, 0.30, 0.14, 0.92)
    panel_style.corner_radius_top_left = 14
    panel_style.corner_radius_top_right = 14
    panel_style.corner_radius_bottom_left = 14
    panel_style.corner_radius_bottom_right = 14
    skill_panel.add_theme_stylebox_override("panel", panel_style)
    battle_ui_layer.add_child(skill_panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 14)
    margin.add_theme_constant_override("margin_top", 12)
    margin.add_theme_constant_override("margin_right", 14)
    margin.add_theme_constant_override("margin_bottom", 12)
    skill_panel.add_child(margin)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 7)
    margin.add_child(box)

    var title := Label.new()
    title.text = "%s • LEARNED SKILLS" % hero_name.to_upper()
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 17)
    box.add_child(title)

    skill_list = VBoxContainer.new()
    skill_list.add_theme_constant_override("separation", 5)
    box.add_child(skill_list)

    var close := Button.new()
    close.text = "BACK"
    close.pressed.connect(_close_skill_panel)
    box.add_child(close)

    _refresh_skill_list()


func _refresh_skill_list() -> void:
    if not skill_list:
        return

    for child in skill_list.get_children():
        child.queue_free()

    var equipped: Array = hero_profile.get("equipped_skills", [])
    for skill_id_variant in equipped:
        var skill_id := str(skill_id_variant)
        var skill := HeroProgressionService.skill_by_id(hero_id, skill_id)
        if skill.is_empty() or str(skill.get("type", "active")) != "active":
            continue

        var button := Button.new()
        var mp_cost := int(skill.get("mp", 0))
        button.text = "%s   •   MP %d" % [str(skill.get("name", skill_id)).to_upper(), mp_cost]
        button.custom_minimum_size = Vector2(0.0, 48.0)
        button.disabled = hero_mp < mp_cost
        button.tooltip_text = "Power %d • %s" % [int(skill.get("power", 0)), str(skill.get("element", "none")).capitalize()]
        button.pressed.connect(_use_skill.bind(skill_id))
        skill_list.add_child(button)


func _open_skill_panel() -> void:
    if active_actor_id == "" or action_locked or battle_over:
        return
    if active_actor_id != "hero":
        _use_army_ability()
        return
    _refresh_skill_list()
    skill_panel.visible = true
    _set_commands_enabled(false)


func _close_skill_panel() -> void:
    skill_panel.visible = false
    if active_actor_id == "hero" and not action_locked and not battle_over:
        _set_commands_enabled(true)


func _use_army_ability() -> void:
    if not active_actor_id.begins_with("army_") or action_locked or battle_over:
        return

    action_locked = true
    var index := int(active_actor_id.trim_prefix("army_"))
    var slot: Dictionary = army_slots[index]
    var anchor := army_anchors[index]
    var name := str(slot.get("name", "Unit"))
    var ability_name := str(slot.get("ability_name", "Formation Strike"))
    var power := int(slot.get("power", 10))
    var bonus := int(slot.get("ability_bonus", 8))
    var damage := bonus + int(round(float(power) * 0.90)) + randi_range(0, 4)
    if enemy_effects.has("sunder"):
        damage = int(round(float(damage) * 1.25))

    _consume_active_turn()
    message_label.text = "%s uses %s! %d damage." % [name, ability_name, damage]
    await _lunge(anchor, 0.42)
    enemy_hp = maxi(0, enemy_hp - damage)
    _show_damage_popup(enemy_anchor, damage)
    _impact_bump(enemy_anchor, 0.12)
    _camera_impact(0.08)
    _refresh_ui()
    await get_tree().create_timer(0.50).timeout
    action_locked = false
    _check_battle_end()


func _use_skill(skill_id: String) -> void:
    if active_actor_id != "hero" or action_locked or battle_over:
        return

    var skill := HeroProgressionService.skill_by_id(hero_id, skill_id)
    if skill.is_empty() or not hero_profile.get("equipped_skills", []).has(skill_id):
        return

    var mp_cost := int(skill.get("mp", 0))
    if hero_mp < mp_cost:
        message_label.text = "Not enough MP."
        return

    skill_panel.visible = false
    action_locked = true
    hero_mp -= mp_cost
    _consume_hero_turn()

    var effect := str(skill.get("combat_effect", skill.get("effect", "")))
    var skill_name := str(skill.get("name", "Skill"))
    var base_power := int(skill.get("power", 0))
    var scaling := str(skill.get("scaling", "power"))
    var scale_stat := 0.0

    if scaling == "magic":
        scale_stat = float(hero_stats.get("magic", 15))
    elif scaling == "power_magic":
        scale_stat = (float(hero_stats.get("power", 15)) + float(hero_stats.get("magic", 15))) * 0.5
    elif scaling == "none":
        scale_stat = 0.0
    else:
        scale_stat = float(hero_stats.get("power", 15))

    if effect.begins_with("guard_") or effect == "resist_guard" or effect == "fire_guard" or effect == "shield":
        defending = true
        if effect == "guard_75" or effect == "shield":
            guard_multiplier = 0.25
        elif effect == "guard_70":
            guard_multiplier = 0.30
        elif effect == "guard_60":
            guard_multiplier = 0.40
        else:
            guard_multiplier = 0.38
        message_label.text = "%s uses %s." % [hero_name, skill_name]
        await _ability_flash()
    elif effect == "heal" or effect == "regen" or effect == "evade" or effect == "rally":
        if effect == "heal":
            var restored := mini(hero_max_hp - hero_hp, 18 + int(round(float(hero_stats.get("magic", 15)) * 0.7)))
            hero_hp += restored
            _show_damage_popup(hero_anchor, restored, true)
            message_label.text = "%s restores %d HP." % [hero_name, restored]
        else:
            hero_effects[effect] = 3
            message_label.text = "%s gains %s for three turns." % [hero_name, effect]
        await _ability_flash()
    else:
        var damage := maxi(1, base_power + int(round(scale_stat * 0.55)) + randi_range(-2, 4))
        if enemy_effects.has("sunder"):
            damage = int(round(float(damage) * 1.25))
        if hero_effects.has("rally"):
            damage = int(round(float(damage) * 1.20))
        enemy_hp = maxi(0, enemy_hp - damage)
        message_label.text = "%s uses %s! %d damage." % [hero_name, skill_name, damage]
        await _ability_flash()
        _show_damage_popup(enemy_anchor, damage)
        _impact_bump(enemy_anchor, 0.17)
        _camera_impact(0.12)

        if ["burn", "poison", "bleed", "shock", "sunder", "slow", "stagger", "weaken"].has(effect):
            enemy_effects[effect] = 3
            if effect == "shock" or effect == "stagger":
                enemy_atb *= 0.30
            message_label.text += " %s applied." % effect.capitalize()
        if effect == "lifesteal" or effect == "heal_self" or effect == "drain":
            var healed := mini(hero_max_hp - hero_hp, maxi(1, int(round(float(damage) * 0.30))))
            hero_hp += healed
            if healed > 0:
                _show_damage_popup(hero_anchor, healed, true)

    _refresh_ui()
    await get_tree().create_timer(0.55).timeout
    action_locked = false
    _check_battle_end()


func _on_defend() -> void:
    if active_actor_id == "" or action_locked or battle_over:
        return

    if active_actor_id == "hero":
        defending = true
        guard_multiplier = 0.45
        message_label.text = "%s braces for the next attack." % hero_name
    else:
        var index := int(active_actor_id.trim_prefix("army_"))
        army_slots[index]["defending"] = true
        army_slots[index]["guard_multiplier"] = 0.45
        message_label.text = "%s takes a defensive stance." % str(army_slots[index].get("name", "Unit"))

    _consume_active_turn()


func _on_item() -> void:
    if active_actor_id == "" or action_locked or battle_over:
        return

    if active_actor_id != "hero":
        var index := int(active_actor_id.trim_prefix("army_"))
        var unit_name := str(army_slots[index].get("name", "Unit"))
        _consume_active_turn()
        message_label.text = "%s holds position." % unit_name
        return

    if item_used:
        return

    item_used = true
    var before_hp: int = hero_hp
    hero_hp = mini(hero_max_hp, hero_hp + 28)
    var restored: int = hero_hp - before_hp
    _consume_active_turn()
    message_label.text = "%s restores %d health." % [hero_name, restored]
    _refresh_ui()
    _show_damage_popup(hero_anchor, restored, true)


func _enemy_turn() -> void:
    if battle_over:
        return

    var damage_over_time := 0
    for effect in ["burn", "poison", "bleed"]:
        if enemy_effects.has(effect):
            damage_over_time += maxi(2, int(round(float(hero_stats.get("magic", 15)) * 0.16)))
    if damage_over_time > 0:
        enemy_hp = maxi(0, enemy_hp - damage_over_time)
        _show_damage_popup(enemy_anchor, damage_over_time)
    if hero_effects.has("regen"):
        hero_hp = mini(hero_max_hp, hero_hp + maxi(3, int(round(float(hero_stats.get("magic", 15)) * 0.20))))
    if enemy_hp <= 0:
        _refresh_ui()
        _finish_battle(true)
        return

    action_locked = true
    _set_commands_enabled(false)

    var targets: Array[String] = []
    if hero_hp > 0:
        targets.append("hero")
    for i in range(army_slots.size()):
        if int(army_slots[i].get("hp", 0)) > 0:
            targets.append("army_%d" % i)

    if targets.is_empty():
        action_locked = false
        _finish_battle(false)
        return

    var target_id := targets[randi_range(0, targets.size() - 1)]
    var target_anchor: Node3D
    var target_name := hero_name
    var defense := int(hero_stats.get("defense", 10))
    var guarded := defending
    var guard := guard_multiplier

    if target_id == "hero":
        target_anchor = hero_anchor
    else:
        var index := int(target_id.trim_prefix("army_"))
        var slot: Dictionary = army_slots[index]
        target_anchor = army_anchors[index]
        target_name = str(slot.get("name", "Unit"))
        defense = int(slot.get("defense", 7))
        guarded = bool(slot.get("defending", false))
        guard = float(slot.get("guard_multiplier", 0.50))

    var damage := enemy_attack + randi_range(-2, 3) - int(round(float(defense) * 0.18))
    damage = maxi(1, damage)
    if enemy_effects.has("weaken"):
        damage = maxi(1, int(round(float(damage) * 0.72)))
    if target_id == "hero" and hero_effects.has("evade") and randf() < 0.35:
        damage = 0
    if guarded:
        damage = maxi(1, int(round(float(damage) * guard)))

    message_label.text = "%s attacks %s for %d damage!" % [enemy_name, target_name, damage]
    await _lunge(enemy_anchor, -0.32)

    if target_id == "hero":
        hero_hp = maxi(0, hero_hp - damage)
        defending = false
        guard_multiplier = 0.45
    else:
        var index := int(target_id.trim_prefix("army_"))
        army_slots[index]["hp"] = maxi(0, int(army_slots[index].get("hp", 0)) - damage)
        army_slots[index]["defending"] = false
        army_slots[index]["guard_multiplier"] = 0.50

    _refresh_ui()
    _tick_effects(enemy_effects)
    _show_damage_popup(target_anchor, damage)
    _impact_bump(target_anchor, 0.10)
    _camera_impact(0.055)
    await get_tree().create_timer(0.45).timeout

    action_locked = false
    _check_battle_end()


func _tick_effects(effects: Dictionary) -> void:
    for key in effects.keys():
        effects[key] = int(effects[key]) - 1
        if int(effects[key]) <= 0:
            effects.erase(key)


func _lunge(actor: Node3D, amount: float) -> void:
    var start := actor.position
    var forward := Vector3(amount, 0.0, 0.0)
    var tween := create_tween()
    tween.tween_property(actor, "position", start + forward, 0.11)
    tween.tween_property(actor, "position", start, 0.14)
    await tween.finished


func _ability_flash() -> void:
    var light := OmniLight3D.new()
    light.position = hero_anchor.position + Vector3(0.0, 1.2, 0.5)
    light.light_color = Color(1.0, 0.25, 0.05) if hero_id == "ignis" else Color(0.25, 0.75, 1.0)
    light.light_energy = 9.0
    light.omni_range = 7.0
    add_child(light)

    var tween := create_tween()
    tween.tween_property(light, "light_energy", 0.0, 0.45)
    await tween.finished
    light.queue_free()


func _check_battle_end() -> void:
    if battle_over:
        return
    if enemy_hp <= 0:
        _finish_battle(true)
    elif hero_hp <= 0:
        _finish_battle(false)


func _finish_battle(victory: bool) -> void:
    battle_over = true
    action_locked = true
    _set_commands_enabled(false)

    if victory:
        var progression := HeroProgressionService.add_xp(hero_id, reward_xp, hero_xp)
        var gained_levels := int(progression.get("levels_gained", 0))
        hero_xp = int(progression.get("xp", hero_xp + reward_xp))
        hero_level = int(progression.get("level", hero_level))
        hero_profile = progression
        hero_stats = (progression.get("stats", hero_stats) as Dictionary).duplicate(true)
        if gained_levels > 0:
            message_label.text = "VICTORY! +%d XP • LEVEL %d! • +%d SP" % [reward_xp, hero_level, gained_levels]
        else:
            message_label.text = "VICTORY! %s defeated. +%d XP" % [enemy_name, reward_xp]
    else:
        message_label.text = "%s has fallen..." % hero_name

    var cfg := ConfigFile.new()
    cfg.set_value("battle", "encounter_id", encounter_id)
    cfg.set_value("battle", "victory", victory)
    cfg.set_value("battle", "hero_hp", hero_hp)
    cfg.set_value("battle", "hero_xp", hero_xp)
    cfg.set_value("battle", "hero_level", hero_level)
    cfg.set_value("battle", "enemy_name", enemy_name)
    cfg.save(RESULT_PATH)

    await get_tree().create_timer(1.05).timeout
    if transition_rect:
        var fade := create_tween()
        fade.tween_property(transition_rect, "color:a", 1.0, 0.40)
        await fade.finished
    get_tree().change_scene_to_file(RETURN_SCENE)
