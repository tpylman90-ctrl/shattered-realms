extends Node3D

var camera: Camera3D
var hero: Area3D
var hero_model: Node3D
var selected_hero_id := "ignis"
var hero_health := 100
var hero_xp := 0
var current_node := 0
var sentinel_defeated := false
var relic_claimed := false
var ember_seal_effect_applied := false
var moving := false

var status_label: Label
var objective_label: Label
var action_panel: PanelContainer
var action_title: Label
var action_body: Label
var action_primary: Button
var action_secondary: Button

const NODES: Array[Vector3] = [
    Vector3(0.0, 0.03, 7.0),
    Vector3(0.0, 0.03, 2.8),
    Vector3(-2.4, 0.03, -1.0),
    Vector3(0.0, 0.03, -4.8)
]

func _ready() -> void:
    _load_campaign_state()
    _build_environment()
    _build_dungeon_geometry()
    _build_hero()
    _build_ui()
    _refresh_objective()
    _refresh_node_markers()

func _build_environment() -> void:
    var world_env := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.012, 0.016, 0.022)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.10, 0.13, 0.16)
    env.ambient_light_energy = 0.65
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.glow_enabled = true
    world_env.environment = env
    add_child(world_env)

    var rig := Node3D.new()
    rig.position = Vector3(0.0, 5.0, 4.0)
    rig.rotation_degrees = Vector3(-38.0, 0.0, 0.0)
    add_child(rig)

    camera = Camera3D.new()
    camera.position = Vector3(0.0, 0.0, 13.0)
    camera.current = true
    rig.add_child(camera)

    var moon := DirectionalLight3D.new()
    moon.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
    moon.light_color = Color(0.42, 0.52, 0.62)
    moon.light_energy = 1.3
    moon.shadow_enabled = true
    add_child(moon)

func _make_material(color: Color, emission: Color = Color(0,0,0,1), energy: float = 0.0) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.9
    if energy > 0.0:
        material.emission_enabled = true
        material.emission = emission
        material.emission_energy_multiplier = energy
    return material

func _add_box(name_value: String, position_value: Vector3, size_value: Vector3, material: Material) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = name_value
    var box := BoxMesh.new()
    box.size = size_value
    mesh_instance.mesh = box
    mesh_instance.position = position_value
    mesh_instance.material_override = material
    add_child(mesh_instance)
    return mesh_instance

func _build_dungeon_geometry() -> void:
    var stone := _make_material(Color(0.055, 0.065, 0.075))
    var floor_mat := _make_material(Color(0.075, 0.075, 0.07))
    var teal := _make_material(Color(0.03, 0.16, 0.17), Color(0.02, 0.85, 0.82), 2.4)
    var ember := _make_material(Color(0.19, 0.065, 0.025), Color(1.0, 0.22, 0.04), 2.0)

    _add_box("Floor", Vector3(0,-0.22,1.0), Vector3(9.5,0.4,16.5), floor_mat)
    _add_box("LeftWall", Vector3(-4.7,2.1,1.0), Vector3(0.55,4.6,16.5), stone)
    _add_box("RightWall", Vector3(4.7,2.1,1.0), Vector3(0.55,4.6,16.5), stone)
    _add_box("BackWall", Vector3(0,2.1,-7.1), Vector3(9.5,4.6,0.55), stone)
    _add_box("EntryArchTop", Vector3(0,3.25,8.0), Vector3(4.5,1.0,0.75), stone)
    _add_box("EntryArchL", Vector3(-2.0,1.4,8.0), Vector3(0.75,2.8,0.75), stone)
    _add_box("EntryArchR", Vector3(2.0,1.4,8.0), Vector3(0.75,2.8,0.75), stone)

    for z in [5.5, 1.2, -3.1]:
        _add_box("PillarL_%s" % str(z), Vector3(-3.3,1.45,z), Vector3(0.8,2.9,0.8), stone)
        _add_box("PillarR_%s" % str(z), Vector3(3.3,1.45,z), Vector3(0.8,2.9,0.8), stone)

    for z in [4.3, -0.2, -4.7]:
        var glow_l := _add_box("RuneL_%s" % str(z), Vector3(-4.34,1.45,z), Vector3(0.08,0.7,0.7), teal)
        var glow_r := _add_box("RuneR_%s" % str(z), Vector3(4.34,1.45,z), Vector3(0.08,0.7,0.7), teal)
        glow_l.rotation_degrees.z = 45.0
        glow_r.rotation_degrees.z = 45.0

    var chamber := _add_box("RelicDais", Vector3(0.0,0.2,-5.3), Vector3(3.0,0.4,2.2), stone)
    chamber.rotation_degrees.y = 0.0
    _add_box("RelicGlow", Vector3(0.0,0.85,-5.3), Vector3(0.75,1.0,0.75), ember)

    var teal_light := OmniLight3D.new()
    teal_light.position = Vector3(0.0,2.2,-1.0)
    teal_light.light_color = Color(0.05,0.85,0.78)
    teal_light.light_energy = 4.0
    teal_light.omni_range = 9.0
    add_child(teal_light)

    var ember_light := OmniLight3D.new()
    ember_light.position = Vector3(0.0,1.6,-5.3)
    ember_light.light_color = Color(1.0,0.18,0.035)
    ember_light.light_energy = 5.0
    ember_light.omni_range = 5.5
    add_child(ember_light)

func _build_hero() -> void:
    hero = Area3D.new()
    hero.name = "DungeonHero"
    hero.position = NODES[0]
    add_child(hero)

    var hit := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.55
    capsule.height = 1.8
    hit.shape = capsule
    hit.position.y = 0.9
    hero.add_child(hit)

    var catalog_file := FileAccess.open("res://data/world_catalog.json", FileAccess.READ)
    if catalog_file:
        var parsed = JSON.parse_string(catalog_file.get_as_text())
        if parsed is Dictionary:
            var heroes: Dictionary = parsed.get("heroes", {})
            if heroes.has(selected_hero_id):
                var data: Dictionary = heroes[selected_hero_id]
                var asset_path: String = str(data.get("piece_asset", ""))
                if asset_path != "" and ResourceLoader.exists(asset_path):
                    var packed := load(asset_path) as PackedScene
                    if packed:
                        var instance := packed.instantiate()
                        if instance is Node3D:
                            hero_model = instance as Node3D
                            hero_model.scale = Vector3.ONE * float(data.get("piece_scale", 1.0))
                            var offset = data.get("piece_offset", [0.0,0.0,0.0])
                            hero_model.position = Vector3(float(offset[0]),0.0,float(offset[2]))
                            hero.add_child(hero_model)

    if not hero_model:
        var placeholder := MeshInstance3D.new()
        var mesh := CapsuleMesh.new()
        mesh.radius = 0.36
        mesh.height = 1.4
        placeholder.mesh = mesh
        placeholder.position.y = 0.7
        placeholder.material_override = _make_material(Color(0.20,0.62,0.70), Color(0.10,0.75,0.85), 1.4)
        hero.add_child(placeholder)

    _build_move_markers()

func _build_move_markers() -> void:
    for i in range(NODES.size()):
        var marker := Area3D.new()
        marker.name = "DungeonNode_%d" % i
        marker.position = NODES[i]
        marker.set_meta("node_index", i)
        marker.add_to_group("dungeon_move_node")

        var collision := CollisionShape3D.new()
        var shape := CylinderShape3D.new()
        shape.radius = 0.75
        shape.height = 0.25
        collision.shape = shape
        collision.position.y = 0.1
        marker.add_child(collision)

        var visual := MeshInstance3D.new()
        visual.name = "Marker"
        var torus := TorusMesh.new()
        torus.inner_radius = 0.48
        torus.outer_radius = 0.58
        visual.mesh = torus
        visual.position.y = 0.04
        visual.material_override = _make_material(Color(0.02,0.55,0.55,0.72), Color(0.02,0.9,0.82), 1.6)
        marker.add_child(visual)
        add_child(marker)

func _build_ui() -> void:
    var canvas := CanvasLayer.new()
    add_child(canvas)

    var top := PanelContainer.new()
    top.offset_left = 18
    top.offset_top = 16
    top.offset_right = 630
    top.offset_bottom = 116
    canvas.add_child(top)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 14)
    margin.add_theme_constant_override("margin_top", 10)
    margin.add_theme_constant_override("margin_right", 14)
    margin.add_theme_constant_override("margin_bottom", 10)
    top.add_child(margin)

    var box := VBoxContainer.new()
    margin.add_child(box)

    var title := Label.new()
    title.text = "SUNDERED VAULT  •  FIRST CHAMBER"
    title.add_theme_font_size_override("font_size", 24)
    box.add_child(title)

    status_label = Label.new()
    status_label.text = "The seal closes behind you."
    box.add_child(status_label)

    objective_label = Label.new()
    box.add_child(objective_label)

    var leave := Button.new()
    leave.text = "Return to Ashenreach"
    leave.offset_left = 1030
    leave.offset_top = 18
    leave.offset_right = 1255
    leave.offset_bottom = 66
    leave.pressed.connect(_return_to_map)
    canvas.add_child(leave)

    action_panel = PanelContainer.new()
    action_panel.visible = false
    action_panel.anchor_left = 0.5
    action_panel.anchor_top = 0.5
    action_panel.anchor_right = 0.5
    action_panel.anchor_bottom = 0.5
    action_panel.offset_left = -245
    action_panel.offset_top = -130
    action_panel.offset_right = 245
    action_panel.offset_bottom = 130
    canvas.add_child(action_panel)

    var am := MarginContainer.new()
    am.add_theme_constant_override("margin_left",18)
    am.add_theme_constant_override("margin_top",16)
    am.add_theme_constant_override("margin_right",18)
    am.add_theme_constant_override("margin_bottom",16)
    action_panel.add_child(am)

    var ab := VBoxContainer.new()
    ab.add_theme_constant_override("separation",8)
    am.add_child(ab)

    action_title = Label.new()
    action_title.add_theme_font_size_override("font_size",22)
    ab.add_child(action_title)
    action_body = Label.new()
    action_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    ab.add_child(action_body)
    action_primary = Button.new()
    action_primary.custom_minimum_size = Vector2(0,44)
    ab.add_child(action_primary)
    action_secondary = Button.new()
    action_secondary.text = "Back"
    action_secondary.custom_minimum_size = Vector2(0,40)
    action_secondary.pressed.connect(_close_action)
    ab.add_child(action_secondary)

func _unhandled_input(event: InputEvent) -> void:
    if moving or action_panel.visible:
        return
    if event is InputEventScreenTouch and not event.pressed:
        _try_select_node(event.position)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
        _try_select_node(event.position)

func _try_select_node(screen_pos: Vector2) -> void:
    var origin := camera.project_ray_origin(screen_pos)
    var end := origin + camera.project_ray_normal(screen_pos) * 100.0
    var query := PhysicsRayQueryParameters3D.create(origin,end)
    query.collide_with_areas = true
    query.collide_with_bodies = false
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return
    var collider = hit.get("collider")
    if collider and collider.is_in_group("dungeon_move_node"):
        var target_index: int = int(collider.get_meta("node_index"))
        _try_move_to(target_index)

func _try_move_to(target_index: int) -> void:
    if abs(target_index - current_node) != 1:
        status_label.text = "Move through the chamber one section at a time."
        return
    if current_node == 1 and target_index == 2 and not sentinel_defeated:
        _open_sentinel_encounter()
        return
    await _move_to(target_index)
    if current_node == 3 and not relic_claimed:
        _open_relic_chamber()

func _move_to(target_index: int) -> void:
    moving = true
    _refresh_node_markers()
    var target := NODES[target_index]
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(hero,"position",target,0.75)
    await tween.finished
    current_node = target_index
    moving = false
    status_label.text = "Advanced deeper into the Sundered Vault."
    _refresh_node_markers()
    _refresh_objective()

func _refresh_node_markers() -> void:
    for child in get_children():
        if child is Area3D and child.is_in_group("dungeon_move_node"):
            var idx: int = int(child.get_meta("node_index"))
            var marker := child.get_node_or_null("Marker") as MeshInstance3D
            if marker:
                marker.visible = not moving and abs(idx-current_node) == 1

func _open_sentinel_encounter() -> void:
    action_title.text = "Vault Sentinel"
    action_body.text = "An ancient armored guardian animates between you and the relic chamber.\n\nHealth: %d  •  Victory reward: 50 XP" % hero_health
    action_primary.text = "Fight"
    for connection in action_primary.pressed.get_connections():
        action_primary.pressed.disconnect(connection.callable)
    action_primary.pressed.connect(_fight_sentinel)
    action_panel.visible = true

func _fight_sentinel() -> void:
    hero_health = maxi(1, hero_health - 18)
    hero_xp += 50
    sentinel_defeated = true
    action_panel.visible = false
    status_label.text = "The Vault Sentinel falls. The inner chamber is open."
    _save_campaign_state()
    await _move_to(2)

func _open_relic_chamber() -> void:
    action_title.text = "Ember Seal"
    action_body.text = "A fragment of the old Ashenreach warding seal still burns on the dais. It can be claimed as proof that the Sundered Vault was breached."
    action_primary.text = "Claim Relic"
    for connection in action_primary.pressed.get_connections():
        action_primary.pressed.disconnect(connection.callable)
    action_primary.pressed.connect(_claim_relic)
    action_panel.visible = true

func _claim_relic() -> void:
    relic_claimed = true
    hero_xp += 75
    action_panel.visible = false
    status_label.text = "Ember Seal claimed. The first chamber is cleared."
    _refresh_objective()
    _save_campaign_state()
    _save_dungeon_state()

func _close_action() -> void:
    action_panel.visible = false

func _refresh_objective() -> void:
    if relic_claimed:
        objective_label.text = "OBJECTIVE COMPLETE • Ember Seal recovered"
    elif sentinel_defeated:
        objective_label.text = "OBJECTIVE • Reach the relic chamber"
    else:
        objective_label.text = "OBJECTIVE • Defeat the Vault Sentinel and breach the inner chamber"

func _load_campaign_state() -> void:
    var cfg := ConfigFile.new()
    if cfg.load("user://ashenreach_save.cfg") == OK:
        selected_hero_id = str(cfg.get_value("board","selected_hero_id","ignis"))
        hero_health = int(cfg.get_value("board","hero_health",100))
        hero_xp = int(cfg.get_value("board","hero_xp",0))

    var dungeon := ConfigFile.new()
    if dungeon.load("user://sundered_vault_save.cfg") == OK:
        sentinel_defeated = bool(dungeon.get_value("vault","sentinel_defeated",false))
        relic_claimed = bool(dungeon.get_value("vault","relic_claimed",false))
        ember_seal_effect_applied = bool(dungeon.get_value("vault","ember_seal_effect_applied",false))

func _save_campaign_state() -> void:
    var cfg := ConfigFile.new()
    cfg.load("user://ashenreach_save.cfg")
    cfg.set_value("board","hero_health",hero_health)
    cfg.set_value("board","hero_xp",hero_xp)
    cfg.set_value("board","sundered_vault_cleared",relic_claimed)
    if relic_claimed and not ember_seal_effect_applied:
        var current_heat: int = int(cfg.get_value("board","vulgrim_heat",0))
        cfg.set_value("board","vulgrim_heat",maxi(0,current_heat - 15))
        ember_seal_effect_applied = true
    cfg.save("user://ashenreach_save.cfg")

func _save_dungeon_state() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("vault","sentinel_defeated",sentinel_defeated)
    cfg.set_value("vault","relic_claimed",relic_claimed)
    cfg.set_value("vault","ember_seal_effect_applied",ember_seal_effect_applied)
    cfg.save("user://sundered_vault_save.cfg")

func _return_to_map() -> void:
    _save_dungeon_state()
    _save_campaign_state()
    get_tree().change_scene_to_file("res://scenes/AshenreachDemo.tscn")
