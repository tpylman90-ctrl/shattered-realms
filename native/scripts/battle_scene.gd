extends Node3D

const RETURN_SCENE := "res://scenes/AshenreachDemo.tscn"
const CONTEXT_PATH := "user://battle_context.cfg"
const RESULT_PATH := "user://battle_result.cfg"
const CATALOG_PATH := "res://data/world_catalog.json"
const BACKDROP_PATH := "res://assets/battle/ashenreach_fortress_arena.jpg"

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
var enemy_hp := 70
var enemy_max_hp := 70
var enemy_attack := 10
var reward_xp := 25
var danger := 1

var hero_atb := 0.0
var enemy_atb := 0.0
var hero_ready := false
var battle_over := false
var defending := false
var item_used := false
var action_locked := false

var hero_anchor: Node3D
var enemy_anchor: Node3D
var battle_camera: Camera3D
var transition_rect: ColorRect
var battle_ui_layer: CanvasLayer

var hero_hp_label: Label
var enemy_hp_label: Label
var hero_hp_bar: ProgressBar
var enemy_hp_bar: ProgressBar
var hero_atb_bar: ProgressBar
var enemy_atb_bar: ProgressBar
var message_label: Label
var command_box: VBoxContainer
var attack_button: Button
var ability_button: Button
var defend_button: Button
var item_button: Button


func _ready() -> void:
    action_locked = true
    _load_context()
    _load_hero_data()
    _build_background()
    _build_world()
    _build_ui()
    _spawn_hero()
    _spawn_enemy_placeholder()
    _refresh_ui()
    message_label.text = "%s confronts %s." % [hero_name, enemy_name]
    await _play_battle_intro()
    action_locked = false


func _process(delta: float) -> void:
    if battle_over or action_locked:
        return

    # "Wait" ATB behavior: once the hero is ready, combat time pauses until
    # the player chooses a command. This prevents enemies from continuing to
    # cycle attacks while the command menu is open.
    if hero_ready:
        _refresh_gauges()
        return

    hero_atb = minf(1.0, hero_atb + delta * 0.31)
    if hero_atb >= 1.0:
        hero_atb = 1.0
        hero_ready = true
        _set_commands_enabled(true)
        message_label.text = "%s is ready." % hero_name
        _refresh_gauges()
        return

    enemy_atb = minf(1.0, enemy_atb + delta * (0.20 + float(danger) * 0.025))
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


func _build_background() -> void:
    var texture := load(BACKDROP_PATH) as Texture2D
    if not texture:
        push_error("Battle backdrop failed to load: %s" % BACKDROP_PATH)
        return

    # Use a physical 3D quad behind the combatants. This is intentionally not
    # a negative CanvasLayer: several mobile renderers can clear over that path.
    var backdrop := MeshInstance3D.new()
    backdrop.name = "BattleBackdrop"

    var quad := QuadMesh.new()
    quad.size = Vector2(16.8, 9.45)
    backdrop.mesh = quad
    backdrop.position = Vector3(0.0, 0.72, -4.0)
    backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    mat.albedo_texture = texture
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

    var bottom := PanelContainer.new()
    bottom.anchor_left = 0.0
    bottom.anchor_top = 1.0
    bottom.anchor_right = 1.0
    bottom.anchor_bottom = 1.0
    bottom.offset_left = 22.0
    bottom.offset_top = -190.0
    bottom.offset_right = -22.0
    bottom.offset_bottom = -18.0
    battle_ui_layer.add_child(bottom)

    var bottom_margin := MarginContainer.new()
    bottom_margin.add_theme_constant_override("margin_left", 16)
    bottom_margin.add_theme_constant_override("margin_top", 12)
    bottom_margin.add_theme_constant_override("margin_right", 16)
    bottom_margin.add_theme_constant_override("margin_bottom", 12)
    var bottom_style := StyleBoxFlat.new()
    bottom_style.bg_color = Color(0.025, 0.018, 0.02, 0.88)
    bottom_style.corner_radius_top_left = 8
    bottom_style.corner_radius_top_right = 8
    bottom_style.corner_radius_bottom_left = 8
    bottom_style.corner_radius_bottom_right = 8
    bottom.add_theme_stylebox_override("panel", bottom_style)
    bottom.add_child(bottom_margin)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 16)
    bottom_margin.add_child(row)

    message_label = Label.new()
    message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    message_label.add_theme_font_size_override("font_size", 16)
    row.add_child(message_label)

    command_box = VBoxContainer.new()
    command_box.custom_minimum_size = Vector2(250.0, 0.0)
    command_box.add_theme_constant_override("separation", 5)
    row.add_child(command_box)

    var command_label := Label.new()
    command_label.text = "COMMAND"
    command_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    command_label.modulate = Color(1.0, 0.72, 0.45)
    command_box.add_child(command_label)

    attack_button = _make_command_button("ATTACK", _on_attack)
    ability_button = _make_command_button(str(hero_data.get("signature_ability", "ABILITY")).to_upper(), _on_ability)
    defend_button = _make_command_button("DEFEND", _on_defend)
    item_button = _make_command_button("ITEM", _on_item)

    _set_commands_enabled(false)

    transition_rect = ColorRect.new()
    transition_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    transition_rect.color = Color(0.0, 0.0, 0.0, 1.0)
    battle_ui_layer.add_child(transition_rect)


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


func _make_command_button(label_text: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = label_text
    button.custom_minimum_size = Vector2(0.0, 34.0)
    button.pressed.connect(callback)
    command_box.add_child(button)
    return button


func _set_commands_enabled(enabled: bool) -> void:
    if not attack_button:
        return
    attack_button.disabled = not enabled
    ability_button.disabled = not enabled
    defend_button.disabled = not enabled
    item_button.disabled = not enabled or item_used


func _refresh_gauges() -> void:
    hero_atb_bar.value = hero_atb * 100.0
    enemy_atb_bar.value = enemy_atb * 100.0


func _refresh_ui() -> void:
    hero_hp_bar.max_value = hero_max_hp
    hero_hp_bar.value = hero_hp
    enemy_hp_bar.max_value = enemy_max_hp
    enemy_hp_bar.value = enemy_hp
    hero_atb_bar.max_value = 100.0
    enemy_atb_bar.max_value = 100.0

    hero_hp_label.text = "%s  HP %d/%d" % [hero_name, hero_hp, hero_max_hp]
    enemy_hp_label.text = "%s  HP %d/%d" % [enemy_name, enemy_hp, enemy_max_hp]
    _refresh_gauges()


func _consume_hero_turn() -> void:
    hero_ready = false
    hero_atb = 0.0
    _set_commands_enabled(false)


func _on_attack() -> void:
    if not hero_ready or action_locked or battle_over:
        return
    action_locked = true
    _consume_hero_turn()

    var damage := 13 + randi_range(0, 6)
    message_label.text = "%s attacks for %d damage!" % [hero_name, damage]
    await _lunge(hero_anchor, 0.38)
    enemy_hp = maxi(0, enemy_hp - damage)
    _refresh_ui()
    _show_damage_popup(enemy_anchor, damage)
    _impact_bump(enemy_anchor, 0.12)
    _camera_impact(0.07)
    await get_tree().create_timer(0.55).timeout
    action_locked = false
    _check_battle_end()


func _on_ability() -> void:
    if not hero_ready or action_locked or battle_over:
        return
    action_locked = true
    _consume_hero_turn()

    var ability_name := str(hero_data.get("signature_ability", "Signature Ability"))
    var damage := 25 + randi_range(0, 7)
    if hero_id == "vesper":
        damage = 19 + randi_range(0, 5)
        defending = true

    message_label.text = "%s uses %s! %d damage." % [hero_name, ability_name, damage]
    await _ability_flash()
    enemy_hp = maxi(0, enemy_hp - damage)
    _refresh_ui()
    _show_damage_popup(enemy_anchor, damage)
    _impact_bump(enemy_anchor, 0.17)
    _camera_impact(0.12)
    await get_tree().create_timer(0.65).timeout
    action_locked = false
    _check_battle_end()


func _on_defend() -> void:
    if not hero_ready or action_locked or battle_over:
        return
    defending = true
    _consume_hero_turn()
    message_label.text = "%s braces for the next attack." % hero_name


func _on_item() -> void:
    if not hero_ready or action_locked or battle_over or item_used:
        return
    item_used = true
    var before_hp: int = hero_hp
    hero_hp = mini(hero_max_hp, hero_hp + 28)
    var restored: int = hero_hp - before_hp
    _consume_hero_turn()
    message_label.text = "%s restores %d health." % [hero_name, restored]
    _refresh_ui()
    _show_damage_popup(hero_anchor, restored, true)


func _enemy_turn() -> void:
    if battle_over:
        return

    action_locked = true
    _set_commands_enabled(false)

    var damage := enemy_attack + randi_range(-2, 3)
    damage = maxi(1, damage)
    if defending:
        damage = maxi(1, int(round(float(damage) * 0.45)))
        defending = false

    message_label.text = "%s attacks for %d damage!" % [enemy_name, damage]
    await _lunge(enemy_anchor, -0.32)
    hero_hp = maxi(0, hero_hp - damage)
    _refresh_ui()
    _show_damage_popup(hero_anchor, damage)
    _impact_bump(hero_anchor, 0.10)
    _camera_impact(0.065)
    await get_tree().create_timer(0.50).timeout

    action_locked = false
    if hero_ready:
        _set_commands_enabled(true)
    _check_battle_end()


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
        hero_xp += reward_xp
        message_label.text = "VICTORY! %s defeated. +%d XP" % [enemy_name, reward_xp]
    else:
        message_label.text = "%s has fallen..." % hero_name

    var cfg := ConfigFile.new()
    cfg.set_value("battle", "encounter_id", encounter_id)
    cfg.set_value("battle", "victory", victory)
    cfg.set_value("battle", "hero_hp", hero_hp)
    cfg.set_value("battle", "hero_xp", hero_xp)
    cfg.set_value("battle", "enemy_name", enemy_name)
    cfg.save(RESULT_PATH)

    await get_tree().create_timer(1.05).timeout
    if transition_rect:
        var fade := create_tween()
        fade.tween_property(transition_rect, "color:a", 1.0, 0.40)
        await fade.finished
    get_tree().change_scene_to_file(RETURN_SCENE)
