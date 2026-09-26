extends Node3D

@onready var yaw: Node3D = $CameraRig
@onready var pitch: Node3D = $CameraRig/Pitch
@onready var camera: Camera3D = $CameraRig/Pitch/Camera3D
@onready var poi_panel: PanelContainer = $UI/POIPanel
@onready var poi_type: Label = $UI/POIPanel/Margin/VBox/Type
@onready var poi_title: Label = $UI/POIPanel/Margin/VBox/Title
@onready var poi_body: Label = $UI/POIPanel/Margin/VBox/Body
@onready var poi_action: Button = $UI/POIPanel/Margin/VBox/ActionButton
@onready var selected_label: Label3D = $SelectedLabel
@onready var selected_ring: MeshInstance3D = $SelectedPOIRing
@onready var status_label: Label = $UI/TopBar/Status
@onready var vault_glow: MeshInstance3D = $VaultMistGlow
@onready var vault_light: OmniLight3D = $VaultMistLight
@onready var hero_unit: Area3D = $MovementBoard/HeroUnit
@onready var move_nodes_root: Node3D = $MovementBoard/MoveNodes
@onready var movement_panel: PanelContainer = $UI/MovementPanel
@onready var movement_stats: Label = $UI/MovementPanel/Margin/VBox/Stats
@onready var movement_confirm: Button = $UI/MovementPanel/Margin/VBox/ConfirmButton
@onready var hero_select_panel: PanelContainer = $UI/HeroSelectPanel
@onready var hero_roster_box: VBoxContainer = $UI/HeroSelectPanel/Margin/VBox/Roster
@onready var hero_label: Label3D = $MovementBoard/HeroUnit/HeroLabel

var touches: Dictionary = {}
var previous_pinch_distance := 0.0
var touch_start := Vector2.ZERO
var touch_moved := false
var zoom_distance := 30.0
var selected_poi := ""
var glow_time := 0.0
var unit_selected := false
var current_move_node := "BasaltCenter"
var pending_move_node := ""
var pending_path: Array[String] = []
var selected_hero_id := "ignis"
var owned_collectibles: Array[String] = ["vesper_chestplate", "magma_heart_cuirass"]
var unlocked_heroes: Array[String] = []
var hero_catalog: Dictionary = {}
var active_hero_model: Node3D
var hero_move_points := 3

const MIN_ZOOM := 16.0
const MAX_ZOOM := 48.0
const ROTATE_SPEED := 0.0055

const MOVE_GRAPH := {
    "BasaltCenter": ["Rattal", "CapitalSouth", "VaultRoad"],
    "Rattal": ["BasaltCenter", "CapitalSouth", "EastBridge"],
    "CapitalSouth": ["BasaltCenter", "Rattal", "CapitalNorth"],
    "CapitalNorth": ["CapitalSouth"],
    "EastBridge": ["Rattal"],
    "VaultRoad": ["BasaltCenter", "VaultGate"],
    "VaultGate": ["VaultRoad"]
}

# Ordered road-center waypoints. These force pieces to follow the board's
# visible roads, bridges and passes instead of interpolating straight across terrain.
const ROAD_PATHS := {
    "BasaltCenter|Rattal": [
        Vector3(0.0, 4.75, 7.5),
        Vector3(1.8, 4.82, 6.7),
        Vector3(3.6, 4.92, 5.6),
        Vector3(5.2, 5.02, 4.4),
        Vector3(7.0, 5.15, 3.0)
    ],
    "BasaltCenter|CapitalSouth": [
        Vector3(0.0, 4.75, 7.5),
        Vector3(0.35, 4.86, 5.8),
        Vector3(0.8, 5.02, 4.2),
        Vector3(1.35, 5.28, 2.6),
        Vector3(2.0, 5.55, 1.0)
    ],
    "BasaltCenter|VaultRoad": [
        Vector3(0.0, 4.75, 7.5),
        Vector3(-1.8, 4.70, 7.45),
        Vector3(-3.6, 4.67, 7.30),
        Vector3(-5.2, 4.65, 7.35),
        Vector3(-6.8, 4.65, 7.4)
    ],
    "Rattal|CapitalSouth": [
        Vector3(7.0, 5.15, 3.0),
        Vector3(5.8, 5.18, 2.8),
        Vector3(4.5, 5.26, 2.35),
        Vector3(3.2, 5.40, 1.7),
        Vector3(2.0, 5.55, 1.0)
    ],
    "Rattal|EastBridge": [
        Vector3(7.0, 5.15, 3.0),
        Vector3(7.9, 5.10, 3.55),
        Vector3(8.8, 5.04, 4.15),
        Vector3(9.45, 5.00, 4.75),
        Vector3(10.0, 5.0, 5.2)
    ],
    "CapitalSouth|CapitalNorth": [
        Vector3(2.0, 5.55, 1.0),
        Vector3(1.9, 5.72, 0.25),
        Vector3(1.75, 5.91, -0.55),
        Vector3(1.6, 6.08, -1.3),
        Vector3(1.5, 6.25, -2.0)
    ],
    "VaultRoad|VaultGate": [
        Vector3(-6.8, 4.65, 7.4),
        Vector3(-7.9, 4.70, 7.35),
        Vector3(-9.0, 4.78, 7.25),
        Vector3(-10.0, 4.88, 7.12),
        Vector3(-11.0, 5.0, 7.0)
    ]
}

const POI_DATA := {
    "SunderedVault": {
        "title": "Sundered Vault",
        "type": "DUNGEON ENTRANCE",
        "body": "An ancient sealed entrance beneath Ashenreach. Cold teal mist leaks from the forgotten vault.",
        "action": "Enter"
    },
    "CapitalRuins": {
        "title": "Ashenreach Capital Ruins",
        "type": "PRIMARY OBJECTIVE",
        "body": "The shattered seat of regional control. Claiming the capital will decide control of Ashenreach.",
        "action": "Inspect"
    },
    "AshenPlains": {
        "title": "Ashen Plains",
        "type": "REGION",
        "body": "Wind-scoured flats of ash, dead brush, and broken stone.",
        "action": "Inspect"
    },
    "HighlandRidges": {
        "title": "Highland Ridges",
        "type": "REGION",
        "body": "Broken high ground overlooking the eastern approaches.",
        "action": "Inspect"
    },
    "AmbushPass": {
        "title": "Ambush Pass",
        "type": "CHOKEPOINT",
        "body": "A narrow crossing ideal for raids, traps, and sudden attacks.",
        "action": "Inspect"
    },
    "RattalPass": {
        "title": "Rattal Pass",
        "type": "CHOKEPOINT",
        "body": "A constricted route between ruined walls and fractured cliffs.",
        "action": "Inspect"
    },
    "ElevatedOutpost": {
        "title": "Elevated Outpost",
        "type": "TACTICAL POINT",
        "body": "A raised defensive position with long sightlines over the eastern terrain.",
        "action": "Inspect"
    },
    "Overlook": {
        "title": "Overlook",
        "type": "VANTAGE POINT",
        "body": "A high observation point above the lower routes.",
        "action": "Inspect"
    },
    "BasaltBarrens": {
        "title": "Basalt Barrens",
        "type": "REGION",
        "body": "Cracked volcanic ground and weathered ruins stretching through central Ashenreach.",
        "action": "Inspect"
    },
    "RitualTotems": {
        "title": "Ritual Totems",
        "type": "RITUAL SITE",
        "body": "Ancient standing relics marking a forgotten ceremonial ground.",
        "action": "Inspect"
    },
    "SunkenRemnants": {
        "title": "Sunken Remnants",
        "type": "RUIN FIELD",
        "body": "Collapsed structures half-swallowed by the broken land.",
        "action": "Inspect"
    },
    "DeadForest": {
        "title": "Battle-Scarred Dead Forest",
        "type": "REGION",
        "body": "A ruined woodland burned, splintered, and scarred by old conflict.",
        "action": "Inspect"
    }
}

func _ready() -> void:
    _tune_imported_terrain_materials($TerrainRoot)
    reset_camera()
    poi_panel.visible = false
    poi_action.pressed.connect(_on_poi_action)
    $UI/POIPanel/Margin/VBox/CloseButton.pressed.connect(_close_poi_panel)
    $UI/TopBar/ResetButton.pressed.connect(reset_camera)
    movement_confirm.pressed.connect(_confirm_unit_move)
    $UI/MovementPanel/Margin/VBox/CancelButton.pressed.connect(_cancel_unit_move)
    movement_panel.visible = false
    $UI/TopBar/Row/HeroButton.pressed.connect(_open_hero_select)
    $UI/HeroSelectPanel/Margin/VBox/CloseButton.pressed.connect(_close_hero_select)
    _load_hero_catalog()
    _refresh_unlocked_heroes()
    _apply_selected_hero()
    hero_label.visible = false

func _process(delta: float) -> void:
    glow_time += delta
    var pulse := 1.0 + sin(glow_time * 1.35) * 0.08
    vault_glow.scale = Vector3.ONE * pulse
    vault_glow.position.y = 4.5 + sin(glow_time * 0.8) * 0.12
    vault_light.light_energy = 5.0 + sin(glow_time * 1.7) * 0.65
    if selected_ring.visible:
        var ring_pulse := 1.0 + sin(glow_time * 2.3) * 0.12
        selected_ring.scale = Vector3.ONE * ring_pulse
    var hero_ring := hero_unit.get_node_or_null("BaseRing") as MeshInstance3D
    if hero_ring:
        var hero_pulse := 0.92 + sin(glow_time * 2.0) * 0.08
        hero_ring.scale = Vector3.ONE * hero_pulse

func reset_camera() -> void:
    yaw.rotation.y = deg_to_rad(-28.0)
    pitch.rotation.x = deg_to_rad(-38.0)
    zoom_distance = 30.0
    yaw.position = Vector3(0.0, 3.5, 0.0)
    camera.position = Vector3(0.0, 0.0, zoom_distance)
    poi_panel.visible = false
    selected_label.visible = false
    selected_ring.visible = false
    selected_poi = ""
    status_label.text = "Explore Ashenreach"
    _cancel_unit_move()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            touches[event.index] = event.position
            if touches.size() == 1:
                touch_start = event.position
                touch_moved = false
            if touches.size() == 2:
                previous_pinch_distance = _touch_distance()
        else:
            var released_position: Vector2 = event.position
            var was_single := touches.size() == 1
            touches.erase(event.index)
            previous_pinch_distance = 0.0
            if was_single and not touch_moved and released_position.distance_to(touch_start) < 18.0:
                _try_select(released_position)

    elif event is InputEventScreenDrag:
        if touches.has(event.index):
            touches[event.index] = event.position
        if touches.size() == 1:
            touch_moved = true
            yaw.rotation.y -= event.relative.x * ROTATE_SPEED
            pitch.rotation.x = clamp(
                pitch.rotation.x - event.relative.y * ROTATE_SPEED,
                deg_to_rad(-72.0),
                deg_to_rad(-18.0)
            )
        elif touches.size() >= 2:
            touch_moved = true
            var current := _touch_distance()
            if previous_pinch_distance > 0.0:
                zoom_distance = clamp(
                    zoom_distance - (current - previous_pinch_distance) * 0.025,
                    MIN_ZOOM,
                    MAX_ZOOM
                )
                camera.position.z = zoom_distance
            previous_pinch_distance = current

    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        yaw.rotation.y -= event.relative.x * ROTATE_SPEED
        pitch.rotation.x = clamp(
            pitch.rotation.x - event.relative.y * ROTATE_SPEED,
            deg_to_rad(-72.0),
            deg_to_rad(-18.0)
        )
    elif event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
            zoom_distance = clamp(zoom_distance - 1.4, MIN_ZOOM, MAX_ZOOM)
            camera.position.z = zoom_distance
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
            zoom_distance = clamp(zoom_distance + 1.4, MIN_ZOOM, MAX_ZOOM)
            camera.position.z = zoom_distance
        elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
            _try_select(event.position)

func _touch_distance() -> float:
    if touches.size() < 2:
        return 0.0
    var points := touches.values()
    return (points[0] as Vector2).distance_to(points[1] as Vector2)

func _try_select(screen_position: Vector2) -> void:
    var origin := camera.project_ray_origin(screen_position)
    var end := origin + camera.project_ray_normal(screen_position) * 200.0
    var query := PhysicsRayQueryParameters3D.create(origin, end)
    query.collide_with_areas = true
    query.collide_with_bodies = true
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return
    var collider = hit.get("collider")
    if not collider:
        return
    if collider.is_in_group("board_piece"):
        _select_unit(collider)
    elif collider.is_in_group("move_node") and unit_selected:
        _select_move_destination(collider)
    elif collider.is_in_group("poi") and not unit_selected:
        _select_poi(collider)

func _load_hero_catalog() -> void:
    if not FileAccess.file_exists("res://data/world_catalog.json"):
        return
    var file := FileAccess.open("res://data/world_catalog.json", FileAccess.READ)
    var parsed = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        hero_catalog = parsed.get("heroes", {})

func _refresh_unlocked_heroes() -> void:
    unlocked_heroes.clear()
    for hero_id in hero_catalog.keys():
        var data: Dictionary = hero_catalog[hero_id]
        var unlock_item: String = data.get("unlock_item", "")
        if unlock_item == "":
            # Heroes without a relic requirement can remain available by default.
            unlocked_heroes.append(hero_id)
        elif unlock_item in owned_collectibles:
            unlocked_heroes.append(hero_id)

    if selected_hero_id not in unlocked_heroes and not unlocked_heroes.is_empty():
        selected_hero_id = unlocked_heroes[0]

func grant_collectible(collectible_id: String) -> void:
    if collectible_id in owned_collectibles:
        return
    owned_collectibles.append(collectible_id)
    _refresh_unlocked_heroes()

func _open_hero_select() -> void:
    _cancel_unit_move()
    _close_poi_panel()
    for child in hero_roster_box.get_children():
        child.queue_free()
    for hero_id in unlocked_heroes:
        if not hero_catalog.has(hero_id):
            continue
        var data: Dictionary = hero_catalog[hero_id]
        var button := Button.new()
        button.text = "%s  •  %s" % [data.get("name", hero_id), data.get("class", "Hero")]
        button.custom_minimum_size = Vector2(0, 52)
        button.disabled = hero_id == selected_hero_id
        button.pressed.connect(_select_hero.bind(hero_id))
        hero_roster_box.add_child(button)
    hero_select_panel.visible = true

func _close_hero_select() -> void:
    hero_select_panel.visible = false

func _select_hero(hero_id: String) -> void:
    if hero_id not in unlocked_heroes or not hero_catalog.has(hero_id):
        return
    selected_hero_id = hero_id
    _apply_selected_hero()
    hero_select_panel.visible = false

func _apply_selected_hero() -> void:
    if not hero_catalog.has(selected_hero_id):
        return
    var data: Dictionary = hero_catalog[selected_hero_id]
    hero_move_points = int(data.get("movement_points", 3))
    var display_name: String = data.get("name", selected_hero_id)
    var short_name := display_name.split(",")[0].to_upper()
    hero_label.text = short_name
    status_label.text = "%s selected" % display_name
    $UI/TopBar/Row/HeroButton.text = short_name
    _apply_hero_visual(data)

func _apply_hero_visual(data: Dictionary) -> void:
    if active_hero_model and is_instance_valid(active_hero_model):
        active_hero_model.queue_free()
        active_hero_model = null

    var placeholder := hero_unit.get_node_or_null("Body") as MeshInstance3D
    var asset_path: String = data.get("piece_asset", "")
    if asset_path == "" or not ResourceLoader.exists(asset_path):
        if placeholder:
            placeholder.visible = true
        return

    var packed := load(asset_path) as PackedScene
    if not packed:
        if placeholder:
            placeholder.visible = true
        return

    var instance := packed.instantiate()
    if not instance is Node3D:
        instance.queue_free()
        if placeholder:
            placeholder.visible = true
        return

    active_hero_model = instance as Node3D
    active_hero_model.name = "HeroModel"
    var piece_scale := float(data.get("piece_scale", 1.0))
    var y_offset := float(data.get("piece_y_offset", 0.0))
    var piece_offset = data.get("piece_offset", [0.0, 0.0, 0.0])
    var x_offset := float(piece_offset[0]) if piece_offset.size() > 0 else 0.0
    var extra_y := float(piece_offset[1]) if piece_offset.size() > 1 else 0.0
    var z_offset := float(piece_offset[2]) if piece_offset.size() > 2 else 0.0
    active_hero_model.scale = Vector3.ONE * piece_scale
    active_hero_model.position = Vector3(x_offset, y_offset + extra_y, z_offset)
    hero_unit.add_child(active_hero_model)

    if placeholder:
        placeholder.visible = false

func _select_unit(_unit: Area3D) -> void:
    _close_poi_panel()
    unit_selected = true
    hero_label.visible = true
    pending_move_node = ""
    pending_path.clear()
    movement_panel.visible = true
    movement_confirm.disabled = true
    var hero_name: String = str(hero_catalog.get(selected_hero_id, {}).get("name", "Hero"))
    movement_stats.text = "%s selected. Movement points: %d\nTap a highlighted destination." % [hero_name, hero_move_points]
    status_label.text = "%s — choose a destination" % hero_name
    _focus_on_poi(hero_unit.global_position)
    _show_reachable_move_nodes()

func _show_reachable_move_nodes() -> void:
    var reachable := _reachable_nodes(current_move_node, hero_move_points)
    for child in move_nodes_root.get_children():
        var marker := child.get_node_or_null("Marker") as MeshInstance3D
        if marker:
            marker.visible = child.name in reachable and child.name != current_move_node

func _reachable_nodes(start: String, max_steps: int) -> Array[String]:
    var result: Array[String] = []
    var frontier: Array = [[start, 0]]
    var visited := {start: 0}
    while not frontier.is_empty():
        var item = frontier.pop_front()
        var node_name: String = item[0]
        var depth: int = item[1]
        if node_name != start:
            result.append(node_name)
        if depth >= max_steps:
            continue
        for neighbor in MOVE_GRAPH.get(node_name, []):
            if not visited.has(neighbor) or visited[neighbor] > depth + 1:
                visited[neighbor] = depth + 1
                frontier.append([neighbor, depth + 1])
    return result

func _shortest_move_path(start: String, goal: String) -> Array[String]:
    if start == goal:
        return [start]
    var frontier: Array[String] = [start]
    var came_from := {start: ""}
    while not frontier.is_empty():
        var current: String = frontier.pop_front()
        for neighbor in MOVE_GRAPH.get(current, []):
            if came_from.has(neighbor):
                continue
            came_from[neighbor] = current
            if neighbor == goal:
                var path: Array[String] = [goal]
                var cursor: String = current
                while cursor != "":
                    path.push_front(cursor)
                    cursor = came_from[cursor]
                return path
            frontier.append(neighbor)
    return []

func _select_move_destination(node: Area3D) -> void:
    var destination := String(node.name)
    var reachable := _reachable_nodes(current_move_node, hero_move_points)
    if destination not in reachable:
        return
    pending_path = _shortest_move_path(current_move_node, destination)
    if pending_path.is_empty():
        return
    pending_move_node = destination
    var cost := pending_path.size() - 1
    movement_stats.text = "Destination: %s\nMovement cost: %d / %d\nRoute: %s" % [
        destination,
        cost,
        hero_move_points,
        " → ".join(pending_path)
    ]
    movement_confirm.disabled = false
    for child in move_nodes_root.get_children():
        var marker := child.get_node_or_null("Marker") as MeshInstance3D
        if marker:
            marker.visible = child.name in reachable and child.name != current_move_node
    var target_marker := node.get_node_or_null("Marker") as MeshInstance3D
    if target_marker:
        target_marker.visible = true

func _confirm_unit_move() -> void:
    if pending_move_node == "" or pending_path.size() < 2:
        return
    movement_confirm.disabled = true
    movement_stats.text = "Moving..."
    _hide_move_nodes()
    await _animate_unit_path(pending_path)
    current_move_node = pending_move_node
    pending_move_node = ""
    pending_path.clear()
    unit_selected = false
    movement_panel.visible = false
    var moved_hero_name: String = str(hero_catalog.get(selected_hero_id, {}).get("name", "Hero"))
    status_label.text = "%s moved to %s" % [moved_hero_name, current_move_node]

func _road_key(a: String, b: String) -> String:
    if ROAD_PATHS.has("%s|%s" % [a, b]):
        return "%s|%s" % [a, b]
    return "%s|%s" % [b, a]

func _road_points(a: String, b: String) -> Array:
    var key := _road_key(a, b)
    if not ROAD_PATHS.has(key):
        var fallback_node := move_nodes_root.get_node(b) as Area3D
        return [hero_unit.global_position, fallback_node.global_position]

    var points: Array = ROAD_PATHS[key].duplicate()
    if key != "%s|%s" % [a, b]:
        points.reverse()
    return points

func _animate_unit_path(path: Array[String]) -> void:
    for edge_index in range(path.size() - 1):
        var from_node := path[edge_index]
        var to_node := path[edge_index + 1]
        var road_points := _road_points(from_node, to_node)

        # point 0 is the current node; walk every subsequent road-center point.
        for point_index in range(1, road_points.size()):
            var target: Vector3 = road_points[point_index]
            var segment_distance := hero_unit.global_position.distance_to(target)
            var duration := clamp(segment_distance * 0.16, 0.14, 0.42)
            var tween := create_tween()
            tween.set_trans(Tween.TRANS_SINE)
            tween.set_ease(Tween.EASE_IN_OUT)
            tween.tween_property(hero_unit, "global_position", target, duration)
            await tween.finished

func _cancel_unit_move() -> void:
    unit_selected = false
    hero_label.visible = false
    pending_move_node = ""
    pending_path.clear()
    if movement_panel:
        movement_panel.visible = false
    if movement_confirm:
        movement_confirm.disabled = true
    _hide_move_nodes()

func _hide_move_nodes() -> void:
    if not move_nodes_root:
        return
    for child in move_nodes_root.get_children():
        var marker := child.get_node_or_null("Marker") as MeshInstance3D
        if marker:
            marker.visible = false

func _select_poi(node: Node3D) -> void:
    if not POI_DATA.has(node.name):
        return
    selected_poi = node.name
    var data: Dictionary = POI_DATA[selected_poi]
    poi_type.text = data["type"]
    poi_title.text = data["title"]
    poi_body.text = data["body"]
    poi_action.text = data["action"]
    poi_panel.visible = true
    selected_label.visible = false
    selected_ring.global_position = node.global_position + Vector3(0, 0.18, 0)
    selected_ring.visible = true
    status_label.text = data["title"]
    _focus_on_poi(node.global_position)

func _on_poi_action() -> void:
    if selected_poi == "SunderedVault":
        poi_body.text = "The vault is sealed in this environment build. Dungeon exploration is the next gameplay layer."
    elif selected_poi != "":
        poi_body.text += "\n\nLocation recorded for future territory gameplay."


func _focus_on_poi(target: Vector3) -> void:
    var desired := Vector3(target.x, max(target.y, 3.5), target.z)
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_CUBIC)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(yaw, "position", desired, 0.45)

func _close_poi_panel() -> void:
    poi_panel.visible = false
    selected_label.visible = false
    selected_ring.visible = false
    selected_poi = ""
    status_label.text = "Explore Ashenreach"

func _tune_imported_terrain_materials(node: Node) -> void:
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        if mesh_instance.mesh:
            for surface_index in range(mesh_instance.mesh.get_surface_count()):
                var material := mesh_instance.get_active_material(surface_index)
                if material is StandardMaterial3D:
                    var tuned := (material as StandardMaterial3D).duplicate() as StandardMaterial3D
                    tuned.metallic = 0.0
                    tuned.metallic_texture = null
                    tuned.roughness = 0.88
                    tuned.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
                    mesh_instance.set_surface_override_material(surface_index, tuned)
    for child in node.get_children():
        _tune_imported_terrain_materials(child)
