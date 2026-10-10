extends Node3D

const HeroEquipmentService = preload("res://scripts/hero_equipment.gd")

var camera: Camera3D
var hero: Area3D
var hero_model: Node3D
var selected_hero_id := "ignis"
var hero_health := 100
var hero_xp := 0
var current_room := "entrance"
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
var shrine_glow: MeshInstance3D
var trap_glow: MeshInstance3D
var relic_sprite: Sprite3D
var walkmesh_body: StaticBody3D
var background_mesh: MeshInstance3D
var background_material: StandardMaterial3D
var room_name_label: Label
var screen_walk_paths: Array[PackedVector2Array] = []
var foreground_cards: Array[Sprite3D] = []
var room_transitioning := false

const ROOM_CONFIGS := {
    "entrance": {"title": "BROKEN SEAL HALL", "art": "res://assets/dungeons/sundered_vault/vault_entrance.webp"},
    "crossing": {"title": "THE LOWER CROSSING", "art": "res://assets/dungeons/sundered_vault/lower_crossing.webp"},
    "gallery": {"title": "SENTINEL GALLERY", "art": "res://assets/dungeons/sundered_vault/sentinel_gallery.webp"},
    "shrine": {"title": "THE RUNE SHRINE", "art": "res://assets/dungeons/sundered_vault/rune_shrine.webp"},
    "bridge": {"title": "EMBER BRIDGE", "art": "res://assets/dungeons/sundered_vault/ember_bridge.webp"},
    "seal": {"title": "EMBER SEAL SANCTUM", "art": "res://assets/dungeons/sundered_vault/ember_seal_chamber.webp"}
}

const ROOM_EXITS := {
    "entrance": [{"to": "crossing", "point": Vector2(0.50, 0.48), "spawn": Vector2(0.50, 0.83), "label": "Lower Crossing"}],
    "crossing": [
        {"to": "entrance", "point": Vector2(0.50, 0.91), "spawn": Vector2(0.50, 0.82), "label": "Entry Hall"},
        {"to": "gallery", "point": Vector2(0.50, 0.44), "spawn": Vector2(0.50, 0.83), "label": "Sentinel Gallery"},
        {"to": "shrine", "point": Vector2(0.16, 0.53), "spawn": Vector2(0.22, 0.55), "label": "Rune Shrine"}
    ],
    "gallery": [
        {"to": "crossing", "point": Vector2(0.50, 0.90), "spawn": Vector2(0.50, 0.82), "label": "Lower Crossing"},
        {"to": "bridge", "point": Vector2(0.50, 0.46), "spawn": Vector2(0.50, 0.84), "label": "Ember Bridge"}
    ],
    "shrine": [{"to": "crossing", "point": Vector2(0.18, 0.49), "spawn": Vector2(0.18, 0.58), "label": "Lower Crossing"}],
    "bridge": [
        {"to": "gallery", "point": Vector2(0.50, 0.90), "spawn": Vector2(0.50, 0.82), "label": "Sentinel Gallery"},
        {"to": "seal", "point": Vector2(0.50, 0.46), "spawn": Vector2(0.50, 0.84), "label": "Ember Seal Sanctum"}
    ],
    "seal": [{"to": "bridge", "point": Vector2(0.50, 0.91), "spawn": Vector2(0.50, 0.82), "label": "Ember Bridge"}]
}

const ROOM_INTERACTIONS := {
    "gallery": [{"id": "guardian", "point": Vector2(0.50, 0.50), "radius": 0.075}],
    "shrine": [{"id": "shrine", "point": Vector2(0.76, 0.55), "radius": 0.085}],
    "bridge": [{"id": "trap", "point": Vector2(0.50, 0.65), "radius": 0.075}],
    "seal": [{"id": "relic", "point": Vector2(0.50, 0.56), "radius": 0.075}]
}

func _ready() -> void:
    _load_campaign_state()
    _build_environment()
    _build_dungeon_geometry()
    _build_hero()
    _build_sentinel_visual()
    _build_poi_markers()
    _build_ui()
    _refresh_objective()
    _refresh_room_label()

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

    camera = Camera3D.new()
    camera.position = Vector3(0.0, 9.0, 14.0)
    camera.fov = 40.0
    add_child(camera)
    camera.look_at(Vector3(0.0, 0.0, -3.0), Vector3.UP)
    camera.current = true
    var fill_light := DirectionalLight3D.new()
    fill_light.rotation_degrees = Vector3(-38.0, -26.0, 0.0)
    fill_light.light_color = Color(0.64, 0.70, 0.78)
    fill_light.light_energy = 0.8
    fill_light.shadow_enabled = false
    add_child(fill_light)
    get_viewport().size_changed.connect(_fit_background_card)

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
    background_mesh = MeshInstance3D.new()
    background_mesh.name = "PaintedRoomPlate"
    var quad := QuadMesh.new()
    quad.size = Vector2(1.0, 1.0)
    background_mesh.mesh = quad
    background_mesh.position = Vector3(0.0, 0.0, -80.0)
    background_material = StandardMaterial3D.new()
    background_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    background_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    background_mesh.material_override = background_material
    camera.add_child(background_mesh)
    _fit_background_card()

    walkmesh_body = StaticBody3D.new()
    walkmesh_body.name = "WalkmeshCollision"
    walkmesh_body.collision_layer = 0
    walkmesh_body.collision_mask = 0
    add_child(walkmesh_body)
    _build_depth_cards()
    _load_room(current_room, _initial_spawn_for_room(current_room), false)
    _build_relic_sprite()

func _fit_background_card() -> void:
    if not camera or not background_mesh:
        return
    var view_size := get_viewport().get_visible_rect().size
    if view_size.y <= 0.0:
        return
    var distance := 80.0
    var height := 2.0 * distance * tan(deg_to_rad(camera.fov * 0.5))
    var width := height * view_size.x / view_size.y
    var quad := background_mesh.mesh as QuadMesh
    if quad:
        quad.size = Vector2(width, height)

func _room_walk_paths(room_id: String) -> Array[PackedVector2Array]:
    match room_id:
        "entrance":
            return [PackedVector2Array([Vector2(0.40,0.94), Vector2(0.60,0.94), Vector2(0.57,0.70), Vector2(0.54,0.56), Vector2(0.53,0.45), Vector2(0.47,0.45), Vector2(0.46,0.56), Vector2(0.43,0.70)])]
        "crossing":
            return [
                PackedVector2Array([Vector2(0.43,0.95), Vector2(0.57,0.95), Vector2(0.57,0.60), Vector2(0.43,0.60)]),
                PackedVector2Array([Vector2(0.12,0.47), Vector2(0.88,0.47), Vector2(0.82,0.67), Vector2(0.18,0.67)]),
                PackedVector2Array([Vector2(0.44,0.50), Vector2(0.56,0.50), Vector2(0.56,0.40), Vector2(0.44,0.40)])
            ]
        "gallery":
            return [PackedVector2Array([Vector2(0.37,0.94), Vector2(0.63,0.94), Vector2(0.59,0.72), Vector2(0.57,0.55), Vector2(0.56,0.45), Vector2(0.44,0.45), Vector2(0.43,0.55), Vector2(0.41,0.72)])]
        "shrine":
            return [
                PackedVector2Array([Vector2(0.25,0.95), Vector2(0.75,0.95), Vector2(0.75,0.65), Vector2(0.25,0.65)]),
                PackedVector2Array([Vector2(0.12,0.46), Vector2(0.46,0.46), Vector2(0.46,0.68), Vector2(0.12,0.68)]),
                PackedVector2Array([Vector2(0.42,0.46), Vector2(0.82,0.46), Vector2(0.82,0.66), Vector2(0.42,0.66)])
            ]
        "bridge":
            return [PackedVector2Array([Vector2(0.37,0.95), Vector2(0.63,0.95), Vector2(0.59,0.74), Vector2(0.57,0.55), Vector2(0.56,0.43), Vector2(0.44,0.43), Vector2(0.43,0.55), Vector2(0.41,0.74)])]
        "seal":
            return [PackedVector2Array([Vector2(0.34,0.95), Vector2(0.66,0.95), Vector2(0.64,0.73), Vector2(0.60,0.59), Vector2(0.57,0.49), Vector2(0.43,0.49), Vector2(0.40,0.59), Vector2(0.36,0.73)])]
    return [PackedVector2Array([Vector2(0.40,0.94), Vector2(0.60,0.94), Vector2(0.57,0.70), Vector2(0.54,0.56), Vector2(0.53,0.45), Vector2(0.47,0.45), Vector2(0.46,0.56), Vector2(0.43,0.70)])]

func _room_ids() -> Array:
    return ROOM_CONFIGS.keys()

func _initial_spawn_for_room(room_id: String) -> Vector2:
    if room_id == "shrine":
        return Vector2(0.22, 0.55)
    return Vector2(0.50, 0.84)

func _exits_for_room(room_id: String) -> Array:
    return ROOM_EXITS.get(room_id, [])

func _interactions_for_room(room_id: String) -> Array:
    return ROOM_INTERACTIONS.get(room_id, [])

func _screen_to_floor(screen_uv: Vector2) -> Vector3:
    var view_size := get_viewport().get_visible_rect().size
    var ray_origin := camera.project_ray_origin(screen_uv * view_size)
    var ray_direction := camera.project_ray_normal(screen_uv * view_size)
    if absf(ray_direction.y) < 0.0001:
        return Vector3.ZERO
    var distance := -ray_origin.y / ray_direction.y
    return ray_origin + ray_direction * distance

func _load_room(room_id: String, spawn_uv: Vector2, animate: bool = true) -> void:
    if not ROOM_CONFIGS.has(room_id):
        room_id = "entrance"
    current_room = room_id
    var room: Dictionary = ROOM_CONFIGS[current_room]
    var texture := load(str(room.get("art", ""))) as Texture2D
    if texture and background_material:
        background_material.albedo_texture = texture
    screen_walk_paths = _room_walk_paths(current_room)
    _rebuild_walkmesh()
    _refresh_room_label()
    if hero:
        hero.position = _screen_to_floor(spawn_uv)
        hero.position.y = 0.03
    if sentinel_piece:
        sentinel_piece.position = _screen_to_floor(Vector2(0.50, 0.50))
        sentinel_piece.visible = current_room == "gallery" and not sentinel_defeated
    if relic_sprite:
        relic_sprite.position = _screen_to_floor(Vector2(0.50, 0.54))
        relic_sprite.position.y += 0.82
        relic_sprite.visible = current_room == "seal" and not relic_claimed
    if shrine_glow:
        shrine_glow.visible = current_room == "shrine" and not shrine_used
    if trap_glow:
        trap_glow.visible = current_room == "bridge" and not trap_triggered
    for card in foreground_cards:
        card.visible = current_room in ["entrance", "crossing"]
    _build_room_markers()
    if animate:
        var fade := ColorRect.new()
        fade.color = Color(0.015, 0.01, 0.008, 1.0)
        fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        var canvas := get_node_or_null("DungeonUI") as CanvasLayer
        if canvas:
            canvas.add_child(fade)
            var tween := create_tween()
            tween.tween_property(fade, "color:a", 0.0, 0.22)
            tween.tween_callback(fade.queue_free)

func _rebuild_walkmesh() -> void:
    for child in walkmesh_body.get_children():
        child.queue_free()
    var faces := PackedVector3Array()
    for path in screen_walk_paths:
        var world_polygon := PackedVector2Array()
        for uv in path:
            var world_point := _screen_to_floor(uv)
            world_polygon.append(Vector2(world_point.x, world_point.z))
        var indices := Geometry2D.triangulate_polygon(world_polygon)
        for index in indices:
            var point := world_polygon[index]
            faces.append(Vector3(point.x, 0.03, point.y))
    if faces.is_empty():
        return
    var shape := ConcavePolygonShape3D.new()
    shape.set_faces(faces)
    var collider := CollisionShape3D.new()
    collider.name = "WalkSurface"
    collider.shape = shape
    walkmesh_body.add_child(collider)

func _build_room_markers() -> void:
    for child in get_children():
        if child.is_in_group("room_marker"):
            child.queue_free()
    var teal := _make_material(Color(0.02,0.35,0.36,0.55), Color(0.02,0.86,0.88), 1.3)
    for exit_data in ROOM_EXITS.get(current_room, []):
        var marker := MeshInstance3D.new()
        marker.name = "Doorway_%s" % str(exit_data.get("to", ""))
        marker.add_to_group("room_marker")
        var ring := TorusMesh.new()
        ring.inner_radius = 0.29
        ring.outer_radius = 0.36
        marker.mesh = ring
        marker.material_override = teal
        marker.position = _screen_to_floor(exit_data.get("point", Vector2(0.5,0.5)))
        marker.position.y = 0.045
        add_child(marker)

func _refresh_room_label() -> void:
    if room_name_label and ROOM_CONFIGS.has(current_room):
        room_name_label.text = str(ROOM_CONFIGS[current_room].get("title", "SUNDERED VAULT"))

func _build_relic_sprite() -> void:
    relic_sprite = Sprite3D.new()
    relic_sprite.name = "EmberSealDepthSprite"
    relic_sprite.texture = load("res://assets/items/rewards/ember_seal.webp") as Texture2D
    relic_sprite.pixel_size = 0.0032
    relic_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    relic_sprite.no_depth_test = false
    relic_sprite.position = _screen_to_floor(Vector2(0.50, 0.54))
    relic_sprite.position.y += 0.82
    relic_sprite.visible = current_room == "seal" and not relic_claimed
    add_child(relic_sprite)

func _build_depth_cards() -> void:
    var texture := load("res://assets/dungeons/sundered_vault/vault_banner_column.webp") as Texture2D
    if not texture:
        return
    for layer_index in range(2):
        for side in [-1.0, 1.0]:
            var card := Sprite3D.new()
            card.name = "DepthPropCard_%d" % layer_index
            card.texture = texture
            card.pixel_size = 0.0024
            card.billboard = BaseMaterial3D.BILLBOARD_ENABLED
            card.no_depth_test = false
            var uv_y := 0.60 if layer_index == 0 else 0.78
            var uv_x := 0.06 if side < 0.0 else 0.94
            card.position = _screen_to_floor(Vector2(uv_x, uv_y))
            card.position.y += 1.85
            card.flip_h = side > 0.0
            card.visible = false
            add_child(card)
            foreground_cards.append(card)

func _build_poi_markers() -> void:
    shrine_glow = _create_floor_marker("RuneShrineFloorSigil", Vector2(0.76, 0.55), Color(0.02,0.62,0.65), Color(0.02,0.88,0.90))
    trap_glow = _create_floor_marker("EmberWardFloorSigil", Vector2(0.50, 0.65), Color(0.68,0.12,0.025), Color(1.0,0.19,0.025))
    shrine_glow.visible = current_room == "shrine" and not shrine_used
    trap_glow.visible = current_room == "bridge" and not trap_triggered

func _create_floor_marker(marker_name: String, point_uv: Vector2, tint: Color, glow: Color) -> MeshInstance3D:
    var marker := MeshInstance3D.new()
    marker.name = marker_name
    var ring := TorusMesh.new()
    ring.inner_radius = 0.33
    ring.outer_radius = 0.39
    marker.mesh = ring
    marker.material_override = _make_material(tint, glow, 1.8)
    marker.position = _screen_to_floor(point_uv)
    marker.position.y = 0.055
    add_child(marker)
    return marker

func _build_hero() -> void:
    hero = Area3D.new()
    hero.name = "DungeonHero"
    hero.position = _screen_to_floor(_initial_spawn_for_room(current_room))
    hero.position.y = 0.03
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

func _build_sentinel_visual() -> void:
    sentinel_piece = Node3D.new()
    sentinel_piece.name = "VaultSentinel"
    sentinel_piece.position = _screen_to_floor(Vector2(0.50, 0.50))
    sentinel_piece.visible = current_room == "gallery" and not sentinel_defeated
    add_child(sentinel_piece)

    var body := MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.radius = 0.48
    mesh.height = 1.75
    mesh.radial_segments = 14
    mesh.rings = 7
    body.mesh = mesh
    body.position.y = 0.88
    body.material_override = _make_material(
        Color(0.18,0.07,0.035),
        Color(1.0,0.12,0.025),
        1.8
    )
    sentinel_piece.add_child(body)

    var ring := MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = 0.55
    torus.outer_radius = 0.66
    ring.mesh = torus
    ring.position.y = 0.035
    ring.material_override = _make_material(
        Color(0.42,0.06,0.025),
        Color(1.0,0.10,0.02),
        2.1
    )
    sentinel_piece.add_child(ring)

    var label := Label3D.new()
    label.text = "VAULT SENTINEL"
    label.font_size = 16
    label.pixel_size = 0.012
    label.position = Vector3(0.0,1.85,0.0)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.no_depth_test = true
    sentinel_piece.add_child(label)

func _build_ui() -> void:
    var canvas := CanvasLayer.new()
    canvas.name = "DungeonUI"
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
    title.text = "SUNDERED VAULT"
    title.add_theme_font_size_override("font_size", 24)
    box.add_child(title)

    room_name_label = Label.new()
    room_name_label.add_theme_font_size_override("font_size", 16)
    box.add_child(room_name_label)

    status_label = Label.new()
    status_label.text = "Tap the flagstone path to move. Teal arches mark connected rooms."
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
    if moving or room_transitioning or (action_panel and action_panel.visible):
        return
    if event is InputEventScreenTouch and not event.pressed:
        _walk_to_screen_point(event.position)
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
        _walk_to_screen_point(event.position)

func _is_walkable_uv(point: Vector2) -> bool:
    for path in screen_walk_paths:
        if Geometry2D.is_point_in_polygon(point, path):
            return true
    return false

func _screen_uv_from_world(point: Vector3) -> Vector2:
    var view_size := get_viewport().get_visible_rect().size
    if view_size.x <= 0.0 or view_size.y <= 0.0:
        return Vector2.ZERO
    return camera.unproject_position(point) / view_size

func _find_walk_path(start_uv: Vector2, target_uv: Vector2) -> PackedVector2Array:
    const GRID_X := 44
    const GRID_Y := 28
    var start := Vector2i(clampi(roundi(start_uv.x * GRID_X), 0, GRID_X), clampi(roundi(start_uv.y * GRID_Y), 0, GRID_Y))
    var goal := Vector2i(clampi(roundi(target_uv.x * GRID_X), 0, GRID_X), clampi(roundi(target_uv.y * GRID_Y), 0, GRID_Y))
    if start == goal:
        return PackedVector2Array([target_uv])
    var queue: Array[Vector2i] = [start]
    var came_from: Dictionary = {start: start}
    var cursor := 0
    var directions: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
    while cursor < queue.size() and not came_from.has(goal):
        var cell := queue[cursor]
        cursor += 1
        for direction in directions:
            var next := cell + direction
            if next.x < 0 or next.x > GRID_X or next.y < 0 or next.y > GRID_Y or came_from.has(next):
                continue
            var next_uv := Vector2(float(next.x) / GRID_X, float(next.y) / GRID_Y)
            if not _is_walkable_uv(next_uv):
                continue
            came_from[next] = cell
            queue.append(next)
    if not came_from.has(goal):
        return PackedVector2Array()
    var reversed_cells: Array[Vector2i] = []
    var cursor_cell := goal
    while cursor_cell != start:
        reversed_cells.append(cursor_cell)
        cursor_cell = came_from[cursor_cell]
    reversed_cells.reverse()
    var raw_points := PackedVector2Array([start_uv])
    for cell in reversed_cells:
        raw_points.append(Vector2(float(cell.x) / GRID_X, float(cell.y) / GRID_Y))
    raw_points.append(target_uv)
    var result := PackedVector2Array()
    var anchor := 0
    while anchor < raw_points.size() - 1:
        var furthest := anchor + 1
        for candidate in range(anchor + 2, raw_points.size()):
            if _walk_segment_is_clear(raw_points[anchor], raw_points[candidate]):
                furthest = candidate
        result.append(raw_points[furthest])
        anchor = furthest
    return result

func _walk_segment_is_clear(start_uv: Vector2, end_uv: Vector2) -> bool:
    var steps := maxi(2, ceili(start_uv.distance_to(end_uv) * 120.0))
    for index in range(1, steps):
        var point := start_uv.lerp(end_uv, float(index) / steps)
        if not _is_walkable_uv(point):
            return false
    return true

func _walk_to_screen_point(screen_pos: Vector2) -> void:
    var view_size := get_viewport().get_visible_rect().size
    if view_size.x <= 0.0 or view_size.y <= 0.0:
        return
    var target_uv := screen_pos / view_size
    if not _is_walkable_uv(target_uv):
        status_label.text = "Stay on the lit flagstone paths."
        return
    var exit_data := _exit_near(target_uv)
    if not exit_data.is_empty() and str(exit_data.get("to", "")) == "bridge" and not sentinel_defeated:
        status_label.text = "The Vault Sentinel still bars the Ember Bridge."
        return
    var start_uv := _screen_uv_from_world(hero.global_position)
    var path := _find_walk_path(start_uv, target_uv)
    if path.is_empty():
        status_label.text = "The broken floor blocks that route."
        return
    moving = true
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_IN_OUT)
    for point_uv in path:
        var target_world := _screen_to_floor(point_uv)
        target_world.y = 0.03
        var travel_time := maxf(0.08, hero.global_position.distance_to(target_world) / 4.2)
        tween.tween_property(hero, "global_position", target_world, travel_time)
    await tween.finished
    moving = false
    var final_uv := _screen_uv_from_world(hero.global_position)
    if _activate_room_interaction(final_uv):
        return
    var reached_exit := _exit_near(final_uv)
    if not reached_exit.is_empty():
        await _transition_room(reached_exit)
        return
    status_label.text = "You move along the worn stone path."

func _exit_near(point_uv: Vector2) -> Dictionary:
    for exit_data in ROOM_EXITS.get(current_room, []):
        if point_uv.distance_to(exit_data.get("point", Vector2.ZERO)) <= 0.055:
            return exit_data
    return {}

func _activate_room_interaction(point_uv: Vector2) -> bool:
    for interaction in ROOM_INTERACTIONS.get(current_room, []):
        if point_uv.distance_to(interaction.get("point", Vector2.ZERO)) > float(interaction.get("radius", 0.07)):
            continue
        match str(interaction.get("id", "")):
            "guardian":
                if not sentinel_defeated:
                    _open_sentinel_encounter()
                    return true
            "shrine":
                if not shrine_used:
                    _open_shrine()
                    return true
            "trap":
                if not trap_triggered:
                    _trigger_trap()
                    return true
            "relic":
                if not relic_claimed:
                    _open_relic_chamber()
                    return true
    return false

func _transition_room(exit_data: Dictionary) -> void:
    var destination := str(exit_data.get("to", "entrance"))
    var overlay := ColorRect.new()
    overlay.color = Color(0.01, 0.008, 0.006, 0.0)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var canvas := get_node_or_null("DungeonUI") as CanvasLayer
    if canvas:
        canvas.add_child(overlay)
    room_transitioning = true
    var fade_out := create_tween()
    fade_out.tween_property(overlay, "color:a", 1.0, 0.16)
    await fade_out.finished
    var spawn: Vector2 = exit_data.get("spawn", Vector2(0.50,0.84))
    _load_room(destination, spawn, false)
    status_label.text = "Entered %s." % str(ROOM_CONFIGS[destination].get("title", "the vault"))
    _save_dungeon_state()
    var fade_in := create_tween()
    fade_in.tween_property(overlay, "color:a", 0.0, 0.20)
    await fade_in.finished
    overlay.queue_free()
    room_transitioning = false
    _refresh_objective()

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
    status_label.text = "The Vault Sentinel falls. The teal arch to Ember Bridge is open."
    _save_campaign_state()
    _save_dungeon_state()
    _refresh_objective()

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
    if relic_sprite:
        relic_sprite.visible = false
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
        objective_label.text = "OBJECTIVE • Cross the Ember Bridge and recover the Ember Seal"
    else:
        objective_label.text = "OBJECTIVE • Find the Sentinel Gallery; the Ember Bridge is sealed"

func _load_campaign_state() -> void:
    var cfg := ConfigFile.new()
    if cfg.load("user://ashenreach_save.cfg") == OK:
        selected_hero_id = str(cfg.get_value("board","selected_hero_id","ignis"))
        hero_health = int(cfg.get_value("board","hero_health",100))
        hero_xp = int(cfg.get_value("board","hero_xp",0))

    var dungeon := ConfigFile.new()
    if dungeon.load("user://sundered_vault_save.cfg") == OK:
        raid_id = int(dungeon.get_value("vault", "raid_id", 0))
        current_room = str(dungeon.get_value("vault", "current_room", "entrance"))
        if not ROOM_CONFIGS.has(current_room):
            current_room = "entrance"
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
    cfg.set_value("vault", "current_room", current_room)
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
