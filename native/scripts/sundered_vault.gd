extends Node3D

const HeroEquipmentService = preload("res://scripts/hero_equipment.gd")
const VAULT_BACKGROUND: Texture2D = preload("res://assets/dungeons/sundered_vault/sundered_vault_background.png")
const VAULT_DEPTH_ATLAS: Texture2D = preload("res://assets/dungeons/sundered_vault/sundered_vault_depth_cards.png")
const DEPTH_CARD_CELL := Vector2i(384, 512)

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
var shrine_used := false
var trap_triggered := false
var cache_claimed := false
var raid_id := 0

var status_label: Label
var objective_label: Label
var action_panel: PanelContainer
var action_title: Label
var action_body: Label
var action_primary: Button
var action_secondary: Button
var sentinel_piece: Node3D
var relic_glow: Sprite3D
var shrine_glow: Sprite3D
var trap_glow: Sprite3D

const NODES: Array[Vector3] = [
    Vector3(0.0, 0.03, 7.0),
    Vector3(0.0, 0.03, 2.8),
    Vector3(-2.4, 0.03, -0.8),
    Vector3(2.4, 0.03, -0.8),
    Vector3(0.0, 0.03, -3.3),
    Vector3(0.0, 0.03, -5.3)
]

const DUNGEON_GRAPH := {
    0: [1],
    1: [0, 2, 3],
    2: [1, 4],
    3: [1, 4],
    4: [2, 3, 5],
    5: [4]
}

func _ready() -> void:
    _load_campaign_state()
    _build_environment()
    _build_dungeon_geometry()
    _build_hero()
    _build_sentinel_visual()
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
    camera.fov = 75.0
    camera.far = 180.0
    camera.current = true
    rig.add_child(camera)

    var background := Sprite3D.new()
    background.name = "PaintedVaultBackground"
    background.texture = VAULT_BACKGROUND
    background.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
    background.shaded = false
    background.position = Vector3(0.0, 0.0, -60.0)
    var texture_size := Vector2(VAULT_BACKGROUND.get_size())
    var visible_size := get_viewport().get_visible_rect().size
    var aspect := visible_size.x / maxf(visible_size.y, 1.0)
    var image_aspect := texture_size.x / maxf(texture_size.y, 1.0)
    if absf(image_aspect - aspect) > 0.01:
        background.region_enabled = true
        var crop_height := texture_size.x / aspect
        background.region_rect = Rect2(0.0, (texture_size.y - crop_height) * 0.5, texture_size.x, crop_height)
    var distance := 60.0
    var view_width := 2.0 * distance * tan(deg_to_rad(camera.fov * 0.5)) * aspect
    background.pixel_size = view_width / texture_size.x
    camera.add_child(background)

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
    var card_stage := Node3D.new()
    card_stage.name = "PaintedDepthLayers"
    add_child(card_stage)

    # Each scenery element is a transparent illustrated card, not generated
    # block geometry. The fixed camera and real floor depth handle scale/occlusion.
    for z in [5.8, 1.7, -3.3]:
        _make_depth_card(card_stage, "BasaltPillarL", 0, Vector3(-3.65, 0.0, z), 4.4)
        _make_depth_card(card_stage, "BasaltPillarR", 0, Vector3(3.65, 0.0, z), 4.4)

    _make_depth_card(card_stage, "VaultArch", 2, Vector3(0.0, 0.0, -6.7), 5.0)
    for z in [4.1, -0.5]:
        _make_depth_card(card_stage, "RuneSconceL", 1, Vector3(-3.75, 0.0, z), 1.9)
        _make_depth_card(card_stage, "RuneSconceR", 1, Vector3(3.75, 0.0, z), 1.9)

    for z in [0.7, -4.3]:
        _make_depth_card(card_stage, "EmberBrazierL", 3, Vector3(-3.35, 0.0, z), 2.1)
        _make_depth_card(card_stage, "EmberBrazierR", 3, Vector3(3.35, 0.0, z), 2.1)

    _make_depth_card(card_stage, "ObsidianCrystalL", 4, Vector3(-3.35, 0.0, -1.5), 2.3)
    _make_depth_card(card_stage, "ObsidianCrystalR", 4, Vector3(3.35, 0.0, -1.5), 2.3)
    _make_depth_card(card_stage, "BrokenBridgeL", 6, Vector3(-2.45, 0.0, 3.6), 2.2)
    _make_depth_card(card_stage, "BrokenBridgeR", 6, Vector3(2.45, 0.0, 3.6), 2.2)
    _make_depth_card(card_stage, "ForegroundRubbleL", 5, Vector3(-3.55, 0.0, 7.5), 1.8)
    _make_depth_card(card_stage, "ForegroundRubbleR", 5, Vector3(3.55, 0.0, 7.5), 1.8)

    shrine_glow = _make_depth_card(card_stage, "ShrineRuneCard", 1, NODES[3], 1.9)
    shrine_glow.visible = not shrine_used
    trap_glow = _make_depth_card(card_stage, "TrapEmberCard", 3, NODES[4], 1.6)
    trap_glow.visible = not trap_triggered
    relic_glow = _make_depth_card(card_stage, "RelicCrystalCard", 4, NODES[5], 2.5)
    relic_glow.visible = not relic_claimed


func _make_depth_card(parent: Node3D, node_name: String, cell: int, floor_position: Vector3, world_height: float) -> Sprite3D:
    var card := Sprite3D.new()
    card.name = node_name
    card.texture = VAULT_DEPTH_ATLAS
    card.region_enabled = true
    var column := cell % 4
    var row := floori(float(cell) / 4.0)
    card.region_rect = Rect2(
        float(column * DEPTH_CARD_CELL.x),
        float(row * DEPTH_CARD_CELL.y),
        float(DEPTH_CARD_CELL.x),
        float(DEPTH_CARD_CELL.y)
    )
    card.centered = true
    card.position = floor_position + Vector3.UP * world_height * 0.5
    card.pixel_size = world_height / float(DEPTH_CARD_CELL.y)
    card.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    card.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
    card.shaded = false
    card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(card)
    return card

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

func _build_sentinel_visual() -> void:
    sentinel_piece = Node3D.new()
    sentinel_piece.name = "VaultSentinel"
    sentinel_piece.position = NODES[2]
    sentinel_piece.visible = not sentinel_defeated
    add_child(sentinel_piece)

    _make_depth_card(sentinel_piece, "SentinelIllustration", 7, Vector3.ZERO, 2.8)

    var label := Label3D.new()
    label.text = "VAULT SENTINEL"
    label.font_size = 16
    label.pixel_size = 0.012
    label.position = Vector3(0.0, 3.0, 0.0)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.no_depth_test = true
    sentinel_piece.add_child(label)

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
    title.text = "SUNDERED VAULT  •  LOWER HALLS"
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
    var neighbors: Array = DUNGEON_GRAPH.get(current_node, [])
    if target_index not in neighbors:
        status_label.text = "That chamber is not connected from here."
        return
    if target_index == 2 and not sentinel_defeated:
        _open_sentinel_encounter()
        return

    await _move_to(target_index)

    if current_node == 3 and not shrine_used:
        _open_shrine()
    elif current_node == 4 and not trap_triggered:
        _trigger_trap()
    elif current_node == 5 and not relic_claimed:
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
                var neighbors: Array = DUNGEON_GRAPH.get(current_node, [])
                marker.visible = not moving and idx in neighbors

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
    if sentinel_piece:
        sentinel_piece.visible = false
    action_panel.visible = false
    status_label.text = "The Vault Sentinel falls. The inner chamber is open."
    _save_campaign_state()
    await _move_to(2)

func _open_shrine() -> void:
    action_title.text = "Rune Shrine"
    action_body.text = "Ancient cooling runes still hold power here. The shrine can restore 25 health once before its light fades.\n\nHealth: %d/100" % hero_health
    action_primary.text = "Rest at Shrine"
    for connection in action_primary.pressed.get_connections():
        action_primary.pressed.disconnect(connection.callable)
    action_primary.pressed.connect(_use_shrine)
    action_panel.visible = true

func _use_shrine() -> void:
    shrine_used = true
    hero_health = mini(100, hero_health + 25)
    if shrine_glow:
        shrine_glow.visible = false
    action_panel.visible = false
    status_label.text = "The Rune Shrine restores your strength."
    _save_campaign_state()
    _save_dungeon_state()
    _refresh_objective()

func _trigger_trap() -> void:
    trap_triggered = true
    var trap_damage: int = 10
    hero_health = maxi(1, hero_health - trap_damage)
    if trap_glow:
        trap_glow.visible = false
    status_label.text = "A buried ember ward erupts beneath you. -%d health." % trap_damage
    _save_campaign_state()
    _save_dungeon_state()
    _refresh_objective()

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
    if relic_glow:
        relic_glow.visible = false
    action_panel.visible = false
    status_label.text = "Ember Seal claimed. The first chamber is cleared."
    var loot_id := HeroEquipmentService.claim_reward("dungeon", "sundered_vault")
    var gear_drop := HeroEquipmentService.claim_vault_drop("ashen_wastes", raid_id)
    if not gear_drop.is_empty():
        status_label.text += " Raid loot: %s (%s, quality %d). Return and raid again for another roll." % [str(gear_drop.get("name", "")), str(gear_drop.get("rarity", "")).capitalize(), int(gear_drop.get("quality", 0))]
    if loot_id != "":
        status_label.text += " Ember Seal added to Loadout."
    _refresh_objective()
    _save_campaign_state()
    _save_dungeon_state()

func _close_action() -> void:
    action_panel.visible = false

func _refresh_objective() -> void:
    if relic_claimed:
        objective_label.text = "OBJECTIVE COMPLETE • Ember Seal recovered • Return to Ashenreach"
    elif sentinel_defeated:
        objective_label.text = "OBJECTIVE • Navigate the lower halls and reach the Ember Seal"
    else:
        objective_label.text = "OBJECTIVE • Find a route past the Vault Sentinel"

func _load_campaign_state() -> void:
    var cfg := ConfigFile.new()
    if cfg.load("user://ashenreach_save.cfg") == OK:
        selected_hero_id = str(cfg.get_value("board","selected_hero_id","ignis"))
        hero_health = int(cfg.get_value("board","hero_health",100))
        hero_xp = int(cfg.get_value("board","hero_xp",0))

    var dungeon := ConfigFile.new()
    if dungeon.load("user://sundered_vault_save.cfg") == OK:
        raid_id = int(dungeon.get_value("vault", "raid_id", 0))
        sentinel_defeated = bool(dungeon.get_value("vault","sentinel_defeated",false))
        relic_claimed = bool(dungeon.get_value("vault","relic_claimed",false))
        ember_seal_effect_applied = bool(dungeon.get_value("vault","ember_seal_effect_applied",false))
        shrine_used = bool(dungeon.get_value("vault","shrine_used",false))
        trap_triggered = bool(dungeon.get_value("vault","trap_triggered",false))

func _save_campaign_state() -> void:
    var cfg := ConfigFile.new()
    cfg.load("user://ashenreach_save.cfg")
    cfg.set_value("board","hero_health",hero_health)
    cfg.set_value("board","hero_xp",hero_xp)
    cfg.set_value("board","sundered_vault_cleared",relic_claimed or bool(cfg.get_value("board", "sundered_vault_cleared", false)))
    if relic_claimed and not ember_seal_effect_applied:
        var current_heat: int = int(cfg.get_value("board","vulgrim_heat",0))
        cfg.set_value("board","vulgrim_heat",maxi(0,current_heat - 15))
        ember_seal_effect_applied = true
    cfg.save("user://ashenreach_save.cfg")

func _save_dungeon_state() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("vault", "raid_id", raid_id)
    cfg.set_value("vault","sentinel_defeated",sentinel_defeated)
    cfg.set_value("vault","relic_claimed",relic_claimed)
    cfg.set_value("vault","ember_seal_effect_applied",ember_seal_effect_applied)
    cfg.set_value("vault","shrine_used",shrine_used)
    cfg.set_value("vault","trap_triggered",trap_triggered)
    cfg.save("user://sundered_vault_save.cfg")

func _return_to_map() -> void:
    _save_dungeon_state()
    _save_campaign_state()
    get_tree().change_scene_to_file("res://scenes/AshenreachDemo.tscn")
