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
@onready var status_label: Label = $UI/TopBar/Status
@onready var vault_glow: MeshInstance3D = $VaultMistGlow
@onready var vault_light: OmniLight3D = $VaultMistLight

var touches: Dictionary = {}
var previous_pinch_distance := 0.0
var touch_start := Vector2.ZERO
var touch_moved := false
var zoom_distance := 30.0
var selected_poi := ""
var glow_time := 0.0

const MIN_ZOOM := 16.0
const MAX_ZOOM := 48.0
const ROTATE_SPEED := 0.0055

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
    reset_camera()
    poi_panel.visible = false
    poi_action.pressed.connect(_on_poi_action)
    $UI/TopBar/ResetButton.pressed.connect(reset_camera)

func _process(delta: float) -> void:
    glow_time += delta
    var pulse := 1.0 + sin(glow_time * 1.35) * 0.08
    vault_glow.scale = Vector3.ONE * pulse
    vault_light.light_energy = 5.0 + sin(glow_time * 1.7) * 0.65

func reset_camera() -> void:
    yaw.rotation.y = deg_to_rad(-28.0)
    pitch.rotation.x = deg_to_rad(-38.0)
    zoom_distance = 30.0
    camera.position = Vector3(0.0, 0.0, zoom_distance)
    poi_panel.visible = false
    selected_label.visible = false
    selected_poi = ""
    status_label.text = "Explore Ashenreach"

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
    if collider and collider.is_in_group("poi"):
        _select_poi(collider)

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
    selected_label.text = data["title"]
    selected_label.global_position = node.global_position + Vector3(0, 2.7, 0)
    selected_label.visible = true
    status_label.text = data["title"]

func _on_poi_action() -> void:
    if selected_poi == "SunderedVault":
        poi_body.text = "The vault is sealed in this environment build. Dungeon exploration is the next gameplay layer."
    elif selected_poi != "":
        poi_body.text += "\n\nLocation recorded for future territory gameplay."


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
