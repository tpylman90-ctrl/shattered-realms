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
const HERO_MOVE_POINTS := 3

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

func _process(delta: float) -> void:
    glow_time += delta
    var pulse := 1.0 + sin(glow_time * 1.35) * 0.08
    vault_glow.scale = Vector3.ONE * pulse
    vault_glow.position.y = 4.5 + sin(glow_time * 0.8) * 0.12
    vault_light.light_energy = 5.0 + sin(glow_time * 1.7) * 0.65
    if selected_ring.visible:
        var ring_pulse := 1.0 + sin(glow_time * 2.3) * 0.12
        selected_ring.scale = Vector3.ONE * ring_pulse

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
    if collider.is_in_group("unit"):
        _select_unit(collider)
    elif collider.is_in_group("move_node") and unit_selected:
        _select_move_destination(collider)
    elif collider.is_in_group("poi") and not unit_selected:
        _select_poi(collider)

func _select_unit(_unit: Area3D) -> void:
    _close_poi_panel()
    unit_selected = true
    pending_move_node = ""
    pending_path.clear()
    movement_panel.visible = true
    movement_confirm.disabled = true
    movement_stats.text = "Hero selected. Movement points: %d\nTap a highlighted destination." % HERO_MOVE_POINTS
    status_label.text = "Hero selected"
    _show_reachable_move_nodes()

func _show_reachable_move_nodes() -> void:
    var reachable := _reachable_nodes(current_move_node, HERO_MOVE_POINTS)
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
    var reachable := _reachable_nodes(current_move_node, HERO_MOVE_POINTS)
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
        HERO_MOVE_POINTS,
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
    status_label.text = "Hero moved to %s" % current_move_node

func _animate_unit_path(path: Array[String]) -> void:
    for i in range(1, path.size()):
        var node := move_nodes_root.get_node(path[i]) as Area3D
        var target := node.global_position + Vector3(0, 0.25, 0)
        var tween := create_tween()
        tween.set_trans(Tween.TRANS_SINE)
        tween.set_ease(Tween.EASE_IN_OUT)
        tween.tween_property(hero_unit, "global_position", target, 0.55)
        await tween.finished

func _cancel_unit_move() -> void:
    unit_selected = false
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
