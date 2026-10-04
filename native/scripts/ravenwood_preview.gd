extends Node3D

const GRID_PATH := "res://data/generated/ravenwood_nav_grid.json"
const HERO_SCENE_PATH := "res://scenes/ChosenHeroPiece.tscn"
const HEX_DIRECTIONS: Array[Vector2i] = [
    Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
    Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
]
const MOVEMENT_PER_TURN := 3
const NAV_COLLISION_LAYER := 2
const HEX_RADIUS := 0.407

@onready var camera: Camera3D = $Camera3D
@onready var movement_root: Node3D = $MovementRoot
@onready var terrain_root: Node3D = $TerrainRoot
@onready var toggle_button: Button = $UI/TopBar/Row/MovementButton
@onready var title_label: Label = $UI/TopBar/Row/Title

var orbit_angle := 0.0
var distance := 36.0
var camera_target := Vector3(0.0, 4.5, 0.0)
var mouse_down := false
var pan_dragging := false
var mouse_dragged := false
var mouse_start := Vector2.ZERO
var touches: Dictionary = {}
var touch_start := Vector2.ZERO
var touch_moved := false
var last_pinch := 0.0
var last_two_finger_center := Vector2.ZERO

var tiles: Dictionary = {}
var axial_by_key: Dictionary = {}
var current_key := ""
var movement_left := MOVEMENT_PER_TURN
var turn_number := 1
var moving := false
var planning_mode := true

var hero_root: Node3D
var range_outline: MeshInstance3D
var range_material: StandardMaterial3D
var status_label: Label
var end_turn_button: Button

func _ready() -> void:
    _apply_terrain_material()
    _prepare_navigation_collision()
    _load_grid()
    _create_hero()
    _create_hud()

    title_label.text = "RAVENWOOD • EXPEDITION BOARD"
    toggle_button.text = "HIDE MOVE RANGE"
    toggle_button.pressed.connect(_toggle_movement)
    $UI/TopBar/Row/WorldButton.pressed.connect(
        func(): get_tree().change_scene_to_file("res://scenes/FrontEnd.tscn")
    )

    current_key = _find_start_tile()
    if current_key == "":
        _set_status("Ravenwood movement data could not be loaded.")
        return

    _place_hero(current_key)
    _refresh_move_range()
    _update_camera()
    await get_tree().physics_frame
    _set_status("Turn 1 • Move 3/3 • Tap green hexes to travel • Drag to orbit • Two-finger drag to pan and zoom")

func _apply_terrain_material() -> void:
    var terrain_material := StandardMaterial3D.new()
    terrain_material.albedo_texture = preload("res://assets/3d/game-ready/ravenwood-board/ravenwood_albedo.jpg")
    terrain_material.normal_enabled = true
    terrain_material.normal_texture = preload("res://assets/3d/game-ready/ravenwood-board/ravenwood_normal.jpg")
    var metal_rough := preload("res://assets/3d/game-ready/ravenwood-board/ravenwood_metal_rough.jpg")
    terrain_material.metallic = 1.0
    terrain_material.metallic_texture = metal_rough
    terrain_material.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
    terrain_material.roughness = 1.0
    terrain_material.roughness_texture = metal_rough
    terrain_material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
    for mesh in terrain_root.find_children("*", "MeshInstance3D", true, false):
        (mesh as MeshInstance3D).material_override = terrain_material

    range_material = StandardMaterial3D.new()
    range_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    range_material.albedo_color = Color(0.25, 0.95, 0.55, 0.92)
    range_material.emission_enabled = true
    range_material.emission = Color(0.06, 0.58, 0.25)
    range_material.emission_energy_multiplier = 0.7

    range_outline = MeshInstance3D.new()
    range_outline.name = "ReachableHexOutlines"
    add_child(range_outline)

func _prepare_navigation_collision() -> void:
    movement_root.visible = false
    for item in movement_root.find_children("*", "MeshInstance3D", true, false):
        var mesh_node := item as MeshInstance3D
        if mesh_node.mesh == null:
            continue
        var shape := mesh_node.mesh.create_trimesh_shape()
        if shape == null:
            continue
        var body := StaticBody3D.new()
        body.name = "RavenwoodNavigationCollision"
        body.collision_layer = NAV_COLLISION_LAYER
        body.collision_mask = 0
        var collision := CollisionShape3D.new()
        collision.shape = shape
        body.add_child(collision)
        add_child(body)
        body.global_transform = mesh_node.global_transform

func _load_grid() -> void:
    var file := FileAccess.open(GRID_PATH, FileAccess.READ)
    if file == null:
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        return
    var raw_tiles: Variant = parsed.get("tiles", {})
    if not (raw_tiles is Dictionary):
        return
    for raw_key in raw_tiles.keys():
        var key := str(raw_key)
        var parts := key.split(",")
        if parts.size() != 2:
            continue
        var tile: Variant = raw_tiles[raw_key]
        if not (tile is Dictionary):
            continue
        tiles[key] = tile
        axial_by_key[key] = Vector2i(int(parts[0]), int(parts[1]))

func _create_hero() -> void:
    hero_root = Node3D.new()
    hero_root.name = "RavenwoodHero"
    add_child(hero_root)

    var packed := load(HERO_SCENE_PATH) as PackedScene
    if packed:
        var model := packed.instantiate() as Node3D
        if model:
            var profile_value: Variant = get_tree().get_meta("chosen_hero_profile", {})
            var profile: Dictionary = {}
            if profile_value is Dictionary:
                profile = profile_value.duplicate(true)
            if profile.is_empty():
                profile = {
                    "name": "Chosen Hero",
                    "gender": "Female",
                    "starting_class": "Ranger",
                    "starting_class_id": "ranger",
                    "skin_tone": "Olive",
                    "hair_style": "Braided",
                    "hair_color": "Auburn"
                }
            if model.has_method("set_profile"):
                model.call("set_profile", profile)
            model.scale = Vector3.ONE * 0.42
            model.rotation.y = PI
            hero_root.add_child(model)

    var ring := MeshInstance3D.new()
    var ring_mesh := TorusMesh.new()
    ring_mesh.inner_radius = 0.22
    ring_mesh.outer_radius = 0.29
    ring_mesh.rings = 20
    ring_mesh.ring_segments = 8
    ring.mesh = ring_mesh
    ring.position.y = 0.055
    var ring_material := StandardMaterial3D.new()
    ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    ring_material.albedo_color = Color(0.45, 0.95, 0.64, 0.95)
    ring_material.emission_enabled = true
    ring_material.emission = Color(0.12, 0.7, 0.31)
    ring_material.emission_energy_multiplier = 1.1
    ring.material_override = ring_material
    hero_root.add_child(ring)

func _create_hud() -> void:
    end_turn_button = Button.new()
    end_turn_button.text = "END TURN"
    end_turn_button.custom_minimum_size = Vector2(112, 48)
    end_turn_button.pressed.connect(_end_turn)
    $UI/TopBar/Row.add_child(end_turn_button)

    var panel := PanelContainer.new()
    panel.name = "ExpeditionStatus"
    panel.anchor_left = 0.02
    panel.anchor_right = 0.98
    panel.anchor_top = 1.0
    panel.anchor_bottom = 1.0
    panel.offset_top = -66.0
    panel.offset_bottom = -12.0
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.025, 0.045, 0.04, 0.88)
    panel_style.border_color = Color(0.3, 0.63, 0.42, 0.75)
    panel_style.set_border_width_all(1)
    panel_style.set_corner_radius_all(9)
    panel.add_theme_stylebox_override("panel", panel_style)
    $UI.add_child(panel)

    status_label = Label.new()
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    status_label.add_theme_font_size_override("font_size", 14)
    status_label.add_theme_color_override("font_color", Color(0.88, 0.93, 0.84))
    panel.add_child(status_label)

func _find_start_tile() -> String:
    var best_key := ""
    var best_distance := INF
    for key_value in tiles.keys():
        var key := str(key_value)
        if _is_blocked(key):
            continue
        var tile: Dictionary = tiles[key]
        var xz := Vector2(float(tile.get("x", 0.0)), float(tile.get("z", 0.0)))
        var candidate_distance := xz.length_squared()
        if candidate_distance < best_distance:
            best_distance = candidate_distance
            best_key = key
    return best_key

func _place_hero(key: String) -> void:
    current_key = key
    hero_root.position = _tile_position(key) + Vector3.UP * 0.04
    camera_target = Vector3(hero_root.position.x, 4.5, hero_root.position.z)

func _tile_position(key: String) -> Vector3:
    var tile: Dictionary = tiles.get(key, {})
    return Vector3(float(tile.get("x", 0.0)), float(tile.get("y", 0.0)), float(tile.get("z", 0.0)))

func _key_for_axial(axial: Vector2i) -> String:
    return "%d,%d" % [axial.x, axial.y]

func _is_blocked(key: String) -> bool:
    var tile: Dictionary = tiles.get(key, {})
    return bool(tile.get("auto_blocked", false))

func _reachable_from(start: String, max_cost: int) -> Dictionary:
    var costs: Dictionary = {start: 0}
    var parents: Dictionary = {start: ""}
    var queue: Array[String] = [start]
    var queue_index := 0

    while queue_index < queue.size():
        var key := queue[queue_index]
        queue_index += 1
        var cost := int(costs[key])
        if cost >= max_cost:
            continue
        var axial: Vector2i = axial_by_key[key]
        var current_tile: Dictionary = tiles[key]
        var blocked_edges: Array = current_tile.get("blocked_edges", [])
        for direction in HEX_DIRECTIONS:
            var next_key := _key_for_axial(axial + direction)
            if not tiles.has(next_key) or _is_blocked(next_key) or costs.has(next_key):
                continue
            if blocked_edges.has(next_key):
                continue
            var next_tile: Dictionary = tiles[next_key]
            var reverse_edges: Array = next_tile.get("blocked_edges", [])
            if reverse_edges.has(key):
                continue
            costs[next_key] = cost + 1
            parents[next_key] = key
            queue.append(next_key)

    return {"costs": costs, "parents": parents}

func _route_to(start: String, destination: String, parents: Dictionary) -> Array[String]:
    var path: Array[String] = [destination]
    var key := destination
    while key != start:
        if not parents.has(key):
            return []
        key = str(parents[key])
        path.push_front(key)
    return path

func _refresh_move_range() -> void:
    if not planning_mode or current_key == "" or moving:
        range_outline.mesh = ImmediateMesh.new()
        return

    var movement: Dictionary = _reachable_from(current_key, movement_left)
    var costs: Dictionary = movement["costs"]
    var mesh := ImmediateMesh.new()
    mesh.surface_begin(Mesh.PRIMITIVE_LINES, range_material)
    for key_value in costs.keys():
        var key := str(key_value)
        if key == current_key:
            continue
        var center := _tile_position(key) + Vector3.UP * 0.075
        for corner in range(6):
            var angle_a := deg_to_rad(30.0 + 60.0 * corner)
            var angle_b := deg_to_rad(30.0 + 60.0 * (corner + 1))
            var a := center + Vector3(cos(angle_a) * HEX_RADIUS, 0.0, sin(angle_a) * HEX_RADIUS)
            var b := center + Vector3(cos(angle_b) * HEX_RADIUS, 0.0, sin(angle_b) * HEX_RADIUS)
            mesh.surface_add_vertex(a)
            mesh.surface_add_vertex(b)
    mesh.surface_end()
    range_outline.mesh = mesh

func _toggle_movement() -> void:
    planning_mode = not planning_mode
    toggle_button.text = "HIDE MOVE RANGE" if planning_mode else "PLAN MOVE"
    _refresh_move_range()

func _end_turn() -> void:
    if moving:
        return
    turn_number += 1
    movement_left = MOVEMENT_PER_TURN
    _refresh_move_range()
    _set_status("Turn %d • Move %d/%d • Tap a green hex to travel" % [turn_number, movement_left, MOVEMENT_PER_TURN])

func _set_status(message: String) -> void:
    if status_label:
        status_label.text = message

func _move_to(destination: String) -> void:
    if moving or movement_left <= 0:
        _set_status("No movement remains. End the turn to continue.")
        return
    var movement: Dictionary = _reachable_from(current_key, movement_left)
    var costs: Dictionary = movement["costs"]
    if not costs.has(destination):
        _set_status("That hex is blocked or beyond this turn's movement range.")
        return

    var parents: Dictionary = movement["parents"]
    var path := _route_to(current_key, destination, parents)
    var cost := path.size() - 1
    if cost <= 0:
        return

    moving = true
    range_outline.mesh = ImmediateMesh.new()
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_SINE)
    tween.set_ease(Tween.EASE_IN_OUT)
    for index in range(1, path.size()):
        var next_position := _tile_position(path[index]) + Vector3.UP * 0.04
        hero_root.look_at(Vector3(next_position.x, hero_root.position.y, next_position.z), Vector3.UP)
        tween.tween_property(hero_root, "position", next_position, 0.24)
    tween.finished.connect(func():
        current_key = destination
        movement_left = maxi(0, movement_left - cost)
        moving = false
        camera_target = Vector3(hero_root.position.x, 4.5, hero_root.position.z)
        _update_camera()
        _refresh_move_range()
        if movement_left == 0:
            _set_status("Turn %d • Movement spent • End turn to continue" % turn_number)
        else:
            _set_status("Turn %d • Move %d/%d • Tap a green hex to travel" % [turn_number, movement_left, MOVEMENT_PER_TURN])
    )

func _select_at(screen_position: Vector2) -> void:
    if moving or tiles.is_empty():
        return
    var origin := camera.project_ray_origin(screen_position)
    var direction := camera.project_ray_normal(screen_position)
    var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 120.0)
    query.collision_mask = NAV_COLLISION_LAYER
    query.collide_with_areas = false
    var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return
    var point: Vector3 = hit["position"]
    var nearest_key := ""
    var nearest_distance := INF
    for key_value in tiles.keys():
        var key := str(key_value)
        var position := _tile_position(key)
        var planar_distance := Vector2(position.x - point.x, position.z - point.z).length_squared()
        if planar_distance < nearest_distance:
            nearest_distance = planar_distance
            nearest_key = key
    if nearest_key == "" or nearest_distance > 0.30:
        return
    _move_to(nearest_key)

func _update_camera() -> void:
    camera.position = camera_target + Vector3(sin(orbit_angle) * distance * 0.72, distance * 0.72, cos(orbit_angle) * distance * 0.72)
    camera.look_at(camera_target, Vector3.UP)

func _pan_camera(delta: Vector2) -> void:
    var basis := camera.global_transform.basis
    var screen_right := Vector3(basis.x.x, 0.0, basis.x.z).normalized()
    var screen_up := Vector3(basis.y.x, 0.0, basis.y.z).normalized()
    var factor := distance * 0.0015
    camera_target += -screen_right * delta.x * factor + screen_up * delta.y * factor
    _update_camera()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                mouse_down = true
                mouse_dragged = false
                mouse_start = event.position
            elif mouse_down:
                mouse_down = false
                if not mouse_dragged:
                    _select_at(event.position)
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            pan_dragging = event.pressed
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            distance = clampf(distance - 2.0, 17.0, 65.0)
            _update_camera()
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            distance = clampf(distance + 2.0, 17.0, 65.0)
            _update_camera()
    elif event is InputEventMouseMotion and pan_dragging:
        _pan_camera(event.relative)
    elif event is InputEventMouseMotion and mouse_down:
        if mouse_start.distance_to(event.position) > 8.0:
            mouse_dragged = true
        if mouse_dragged:
            orbit_angle -= event.relative.x * 0.006
            _update_camera()
    elif event is InputEventScreenTouch:
        if event.pressed:
            touches[event.index] = event.position
            if touches.size() == 1:
                touch_start = event.position
                touch_moved = false
            elif touches.size() == 2:
                var points: Array = touches.values()
                last_two_finger_center = ((points[0] as Vector2) + (points[1] as Vector2)) * 0.5
                touch_moved = true
        else:
            var is_tap := touches.size() == 1 and not touch_moved
            touches.erase(event.index)
            if is_tap:
                _select_at(event.position)
            if touches.is_empty():
                touch_moved = false
            last_pinch = 0.0
    elif event is InputEventScreenDrag:
        touches[event.index] = event.position
        if touches.size() == 1:
            if touch_start.distance_to(event.position) > 8.0:
                touch_moved = true
            if touch_moved:
                orbit_angle -= event.relative.x * 0.006
                _update_camera()
        elif touches.size() == 2:
            touch_moved = true
            var points: Array = touches.values()
            var pinch := (points[0] as Vector2).distance_to(points[1] as Vector2)
            var center := ((points[0] as Vector2) + (points[1] as Vector2)) * 0.5
            if last_pinch > 0.0:
                distance = clampf(distance - (pinch - last_pinch) * 0.065, 17.0, 65.0)
                _pan_camera(center - last_two_finger_center)
            last_two_finger_center = center
            last_pinch = pinch
