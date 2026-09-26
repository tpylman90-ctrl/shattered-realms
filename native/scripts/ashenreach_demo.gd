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
@onready var ui_root: CanvasLayer = $UI

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
var moves_remaining := 3
var pending_move_cost := 0
var turn_number := 1
var hero_health := 100
var hero_xp := 0
var vulgrim_heat := 0
var board_data: Dictionary = {}
var discovered_pois: Dictionary = {}
var claimed_pois: Dictionary = {}
var completed_encounters: Dictionary = {}
var current_encounter_node := ""
var territory_secured := false
var vulgrim_available := false
var vulgrim_defeated := false
var signature_ability_used := false
var signature_ability_primed := false
var sundered_vault_cleared := false

var game_hud: PanelContainer
var turn_label: Label
var hero_stats_label: Label
var objective_label: Label
var threat_label: Label
var event_log_label: Label
var encounter_panel: PanelContainer
var encounter_title: Label
var encounter_body: Label
var boss_button: Button
var campaign_status_label: Label
var ability_button: Button
var enemy_root: Node3D
var enemy_pieces: Dictionary = {}
var route_preview: MeshInstance3D
var victory_panel: PanelContainer
var hud_expanded := false
var hud_details_button: Button
var restart_button: Button
var fog_root: Node3D
var fog_tiles: Dictionary = {}
var revealed_fog_cells: Dictionary = {}

const MIN_ZOOM := 16.0
const MAX_ZOOM := 48.0
const ROTATE_SPEED := 0.0055
const HERO_GROUND_CLEARANCE := 0.025
const ROAD_SAMPLE_SPACING := 0.45
const FOG_CELL_SIZE := 4.0
const FOG_REVEAL_RADIUS := 6.5

const MOVE_GRAPH := {
    "BasaltCenter": ["Rattal", "CapitalSouth", "VaultRoad", "RitualTotemsNode", "SunkenRemnantsNode"],
    "Rattal": ["BasaltCenter", "CapitalSouth", "EastBridge", "AmbushPassNode"],
    "CapitalSouth": ["BasaltCenter", "Rattal", "CapitalNorth"],
    "CapitalNorth": ["CapitalSouth", "HighlandRidgesNode", "AshenPlainsNode"],
    "EastBridge": ["Rattal", "ElevatedOutpostNode"],
    "VaultRoad": ["BasaltCenter", "VaultGate", "DeadForestNode", "SunkenRemnantsNode"],
    "VaultGate": ["VaultRoad"],
    "AmbushPassNode": ["Rattal", "ElevatedOutpostNode"],
    "ElevatedOutpostNode": ["AmbushPassNode", "EastBridge", "OverlookNode", "HighlandRidgesNode"],
    "OverlookNode": ["ElevatedOutpostNode", "RitualTotemsNode"],
    "HighlandRidgesNode": ["ElevatedOutpostNode", "CapitalNorth", "AshenPlainsNode"],
    "AshenPlainsNode": ["CapitalNorth", "HighlandRidgesNode", "DeadForestNode"],
    "DeadForestNode": ["VaultRoad", "AshenPlainsNode", "SunkenRemnantsNode"],
    "RitualTotemsNode": ["BasaltCenter", "OverlookNode", "SunkenRemnantsNode"],
    "SunkenRemnantsNode": ["BasaltCenter", "VaultRoad", "DeadForestNode", "RitualTotemsNode"]
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
,
    "Rattal|AmbushPassNode": [
        Vector3(7.0, 5.15, 3.0), Vector3(8.8, 5.0, 2.2), Vector3(10.6, 4.9, 1.0), Vector3(12.5, 4.8, 0.0)
    ],
    "AmbushPassNode|ElevatedOutpostNode": [
        Vector3(12.5, 4.8, 0.0), Vector3(13.2, 5.0, 1.8), Vector3(14.0, 5.3, 3.4), Vector3(15.0, 5.6, 5.0)
    ],
    "EastBridge|ElevatedOutpostNode": [
        Vector3(10.0, 5.0, 5.2), Vector3(11.8, 5.2, 5.1), Vector3(13.4, 5.4, 5.0), Vector3(15.0, 5.6, 5.0)
    ],
    "ElevatedOutpostNode|OverlookNode": [
        Vector3(15.0, 5.6, 5.0), Vector3(14.8, 5.7, 6.6), Vector3(14.4, 5.7, 7.8), Vector3(14.0, 5.6, 9.0)
    ],
    "ElevatedOutpostNode|HighlandRidgesNode": [
        Vector3(15.0, 5.6, 5.0), Vector3(14.2, 5.8, 1.8), Vector3(13.0, 6.0, -1.8), Vector3(11.5, 6.1, -5.0), Vector3(10.0, 6.0, -8.0)
    ],
    "CapitalNorth|HighlandRidgesNode": [
        Vector3(1.5, 6.25, -2.0), Vector3(3.8, 6.2, -3.0), Vector3(6.0, 6.1, -4.5), Vector3(8.0, 6.0, -6.2), Vector3(10.0, 6.0, -8.0)
    ],
    "CapitalNorth|AshenPlainsNode": [
        Vector3(1.5, 6.25, -2.0), Vector3(-1.8, 6.0, -3.2), Vector3(-5.2, 5.7, -4.7), Vector3(-8.8, 5.4, -6.2), Vector3(-12.0, 5.2, -8.0)
    ],
    "HighlandRidgesNode|AshenPlainsNode": [
        Vector3(10.0, 6.0, -8.0), Vector3(5.0, 5.9, -8.5), Vector3(0.0, 5.7, -8.8), Vector3(-6.0, 5.5, -8.5), Vector3(-12.0, 5.2, -8.0)
    ],
    "VaultRoad|DeadForestNode": [
        Vector3(-6.8, 4.65, 7.4), Vector3(-8.2, 4.4, 8.4), Vector3(-9.5, 4.1, 9.7), Vector3(-10.8, 3.9, 10.9), Vector3(-12.0, 3.8, 12.0)
    ],
    "AshenPlainsNode|DeadForestNode": [
        Vector3(-12.0, 5.2, -8.0), Vector3(-12.2, 4.9, -3.0), Vector3(-12.1, 4.5, 2.0), Vector3(-12.0, 4.1, 7.0), Vector3(-12.0, 3.8, 12.0)
    ],
    "BasaltCenter|RitualTotemsNode": [
        Vector3(0.0, 4.75, 7.5), Vector3(1.3, 4.5, 9.0), Vector3(2.6, 4.2, 10.5), Vector3(4.5, 4.0, 12.5)
    ],
    "OverlookNode|RitualTotemsNode": [
        Vector3(14.0, 5.6, 9.0), Vector3(11.3, 5.2, 10.0), Vector3(8.5, 4.7, 11.0), Vector3(4.5, 4.0, 12.5)
    ],
    "BasaltCenter|SunkenRemnantsNode": [
        Vector3(0.0, 4.75, 7.5), Vector3(-0.5, 4.4, 9.3), Vector3(-1.2, 4.1, 11.0), Vector3(-2.5, 3.8, 13.5)
    ],
    "VaultRoad|SunkenRemnantsNode": [
        Vector3(-6.8, 4.65, 7.4), Vector3(-5.8, 4.3, 9.2), Vector3(-4.5, 4.0, 11.2), Vector3(-2.5, 3.8, 13.5)
    ],
    "DeadForestNode|SunkenRemnantsNode": [
        Vector3(-12.0, 3.8, 12.0), Vector3(-9.0, 3.8, 12.5), Vector3(-6.0, 3.8, 13.0), Vector3(-2.5, 3.8, 13.5)
    ],
    "RitualTotemsNode|SunkenRemnantsNode": [
        Vector3(4.5, 4.0, 12.5), Vector3(2.2, 3.9, 13.0), Vector3(0.0, 3.9, 13.3), Vector3(-2.5, 3.8, 13.5)
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
    _build_terrain_collision($TerrainRoot)
    await get_tree().physics_frame
    await get_tree().physics_frame
    _ground_move_nodes()
    _ground_hero_to_surface()
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
    _load_board_data()
    _refresh_unlocked_heroes()
    _load_game_state()
    _apply_selected_hero()
    moves_remaining = clamp(moves_remaining, 0, hero_move_points)
    hero_label.visible = false
    _build_game_hud()
    _build_victory_panel()
    _build_route_preview()
    _build_enemy_board()
    _build_fog_of_war()
    _refresh_fog_reveal()
    _reveal_nearby_pois()
    _refresh_poi_visibility()
    _refresh_claimed_poi_style()
    _refresh_enemy_visibility()
    _refresh_game_hud()
    if sundered_vault_cleared and event_log_label:
        event_log_label.text = "Sundered Vault cleared. Ember Seal recovered."
    if vulgrim_defeated and victory_panel:
        victory_panel.visible = true

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
    for enemy_id in enemy_pieces.keys():
        var piece := enemy_pieces[enemy_id] as Node3D
        if piece and is_instance_valid(piece):
            var pulse_scale: float = 1.0 + sin(glow_time * 2.0 + float(String(enemy_id).length())) * 0.04
            piece.scale = Vector3.ONE * pulse_scale

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

func _load_board_data() -> void:
    if not FileAccess.file_exists("res://data/ashenreach_board.json"):
        board_data = {}
        return
    var file := FileAccess.open("res://data/ashenreach_board.json", FileAccess.READ)
    var parsed = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        board_data = parsed

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
    pending_move_cost = 0
    pending_path.clear()
    movement_panel.visible = true
    movement_confirm.disabled = true
    var hero_name: String = str(hero_catalog.get(selected_hero_id, {}).get("name", "Hero"))
    movement_stats.text = "%s selected. Movement points: %d\nTap a highlighted destination." % [hero_name, hero_move_points]
    status_label.text = "%s — choose a destination" % hero_name
    _focus_on_poi(hero_unit.global_position)
    _show_reachable_move_nodes()

func _show_reachable_move_nodes() -> void:
    var reachable := _reachable_nodes(current_move_node, moves_remaining)
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
    var reachable := _reachable_nodes(current_move_node, moves_remaining)
    if destination not in reachable:
        return
    pending_path = _shortest_move_path(current_move_node, destination)
    if pending_path.is_empty():
        return
    pending_move_node = destination
    var cost := pending_path.size() - 1
    if cost > moves_remaining:
        pending_path.clear()
        pending_move_node = ""
        movement_confirm.disabled = true
        movement_stats.text = "That route costs %d movement points. %d remain this turn." % [cost, moves_remaining]
        return
    pending_move_cost = cost
    movement_stats.text = "Destination: %s\nMovement cost: %d / %d remaining\nRoute: %s" % [
        destination,
        cost,
        moves_remaining,
        " → ".join(pending_path)
    ]
    movement_confirm.disabled = false
    _show_route_preview(pending_path)
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
    moves_remaining = max(0, moves_remaining - pending_move_cost)
    _hide_move_nodes()
    await _animate_unit_path(pending_path)
    current_move_node = pending_move_node
    var landed_node := move_nodes_root.get_node(current_move_node) as Area3D
    if landed_node:
        hero_unit.global_position = _ground_point(landed_node.global_position)
    pending_move_node = ""
    pending_path.clear()
    unit_selected = false
    hero_label.visible = false
    movement_panel.visible = false
    pending_move_cost = 0
    var moved_hero_name: String = str(hero_catalog.get(selected_hero_id, {}).get("name", "Hero"))
    status_label.text = "%s moved to %s" % [moved_hero_name, current_move_node]
    _reveal_nearby_pois()
    _refresh_poi_visibility()
    _trigger_node_encounter(current_move_node)
    _refresh_game_hud()
    _save_game_state()

func _road_key(a: String, b: String) -> String:
    if ROAD_PATHS.has("%s|%s" % [a, b]):
        return "%s|%s" % [a, b]
    return "%s|%s" % [b, a]

func _road_points(a: String, b: String) -> Array:
    var key := _road_key(a, b)
    var control_points: Array = []

    if not ROAD_PATHS.has(key):
        var fallback_node := move_nodes_root.get_node(b) as Area3D
        control_points = [hero_unit.global_position, fallback_node.global_position]
    else:
        control_points = ROAD_PATHS[key].duplicate()
        if key != "%s|%s" % [a, b]:
            control_points.reverse()

    return _densify_and_ground_path(control_points)

func _densify_and_ground_path(control_points: Array) -> Array:
    var result: Array = []
    if control_points.is_empty():
        return result

    var first: Vector3 = control_points[0]
    first = _ground_point(first)
    result.append(first)

    for i in range(control_points.size() - 1):
        var a: Vector3 = control_points[i]
        var b: Vector3 = control_points[i + 1]
        var flat_distance: float = Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
        var steps: int = maxi(1, int(ceil(flat_distance / ROAD_SAMPLE_SPACING)))

        for step in range(1, steps + 1):
            var t: float = float(step) / float(steps)
            var p: Vector3 = a.lerp(b, t)
            p = _ground_point(p)
            result.append(p)

    return result

func _animate_unit_path(path: Array[String]) -> String:
    var reached_node: String = path[0]
    for edge_index in range(path.size() - 1):
        var from_node: String = path[edge_index]
        var to_node: String = path[edge_index + 1]
        var road_points: Array = _road_points(from_node, to_node)

        for point_index in range(1, road_points.size()):
            var target: Vector3 = road_points[point_index]
            var segment_distance: float = hero_unit.global_position.distance_to(target)
            var duration: float = clampf(segment_distance * 0.16, 0.14, 0.42)
            var tween := create_tween()
            tween.set_trans(Tween.TRANS_SINE)
            tween.set_ease(Tween.EASE_IN_OUT)
            tween.tween_property(hero_unit, "global_position", target, duration)
            await tween.finished

        reached_node = to_node
        moves_remaining = maxi(0, moves_remaining - 1)

        if _node_has_active_encounter(to_node):
            return reached_node

        if moves_remaining <= 0:
            return reached_node

    return reached_node

func _build_terrain_collision(node: Node) -> void:
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        if mesh_instance.mesh and mesh_instance.mesh.get_surface_count() > 0:
            var shape := mesh_instance.mesh.create_trimesh_shape()
            if shape:
                var body := StaticBody3D.new()
                body.name = "RuntimeTerrainCollision"
                body.collision_layer = 8
                body.collision_mask = 0

                var collision := CollisionShape3D.new()
                collision.shape = shape
                body.add_child(collision)
                mesh_instance.add_child(body)

    for child in node.get_children():
        if child.name != "RuntimeTerrainCollision":
            _build_terrain_collision(child)

func _ground_point(point: Vector3) -> Vector3:
    var from := Vector3(point.x, 30.0, point.z)
    var to := Vector3(point.x, -10.0, point.z)
    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.collide_with_areas = false
    query.collide_with_bodies = true
    query.collision_mask = 8

    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty():
        point.y = (hit["position"] as Vector3).y + HERO_GROUND_CLEARANCE
    return point

func _ground_move_nodes() -> void:
    for child in move_nodes_root.get_children():
        if child is Area3D:
            var node := child as Area3D
            node.global_position = _ground_point(node.global_position)

func _ground_hero_to_surface() -> void:
    hero_unit.global_position = _ground_point(hero_unit.global_position)

func _cancel_unit_move() -> void:
    _hide_route_preview()
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


func _build_game_hud() -> void:
    game_hud = PanelContainer.new()
    game_hud.name = "GameHUD"
    game_hud.offset_left = 18.0
    game_hud.offset_top = 88.0
    game_hud.offset_right = 350.0
    game_hud.offset_bottom = 252.0
    ui_root.add_child(game_hud)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 14)
    margin.add_theme_constant_override("margin_top", 12)
    margin.add_theme_constant_override("margin_right", 14)
    margin.add_theme_constant_override("margin_bottom", 12)
    game_hud.add_child(margin)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 7)
    margin.add_child(box)

    turn_label = Label.new()
    turn_label.add_theme_font_size_override("font_size", 16)
    box.add_child(turn_label)

    hero_stats_label = Label.new()
    box.add_child(hero_stats_label)

    objective_label = Label.new()
    objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    objective_label.add_theme_font_size_override("font_size", 12)
    objective_label.visible = false
    box.add_child(objective_label)

    threat_label = Label.new()
    box.add_child(threat_label)

    campaign_status_label = Label.new()
    campaign_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    campaign_status_label.add_theme_font_size_override("font_size", 12)
    box.add_child(campaign_status_label)

    ability_button = Button.new()
    ability_button.custom_minimum_size = Vector2(0, 42)
    ability_button.pressed.connect(_prime_signature_ability)
    box.add_child(ability_button)

    boss_button = Button.new()
    boss_button.text = "Confront Vulgrim"
    boss_button.custom_minimum_size = Vector2(0, 44)
    boss_button.visible = false
    boss_button.pressed.connect(_open_vulgrim_encounter)
    box.add_child(boss_button)

    var actions := HBoxContainer.new()
    actions.add_theme_constant_override("separation", 6)
    box.add_child(actions)

    var end_turn := Button.new()
    end_turn.text = "End Turn"
    end_turn.custom_minimum_size = Vector2(122, 38)
    end_turn.pressed.connect(_end_turn)
    actions.add_child(end_turn)

    hud_details_button = Button.new()
    hud_details_button.text = "Details"
    hud_details_button.custom_minimum_size = Vector2(92, 38)
    hud_details_button.pressed.connect(_toggle_hud_details)
    actions.add_child(hud_details_button)

    restart_button = Button.new()
    restart_button.text = "Restart Ashenreach"
    restart_button.custom_minimum_size = Vector2(0, 36)
    restart_button.visible = false
    restart_button.pressed.connect(_restart_campaign)
    box.add_child(restart_button)

    event_log_label = Label.new()
    event_log_label.text = "Ashenreach expedition begun."
    event_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    event_log_label.add_theme_font_size_override("font_size", 11)
    event_log_label.visible = false
    box.add_child(event_log_label)

    _build_encounter_panel()

func _toggle_hud_details() -> void:
    hud_expanded = not hud_expanded
    if objective_label:
        objective_label.visible = hud_expanded
    if event_log_label:
        event_log_label.visible = hud_expanded
    if restart_button:
        restart_button.visible = hud_expanded
    if hud_details_button:
        hud_details_button.text = "Hide" if hud_expanded else "Details"
    if game_hud:
        game_hud.offset_bottom = 460.0 if hud_expanded else 252.0

func _build_encounter_panel() -> void:
    encounter_panel = PanelContainer.new()
    encounter_panel.name = "EncounterPanel"
    encounter_panel.visible = false
    encounter_panel.anchor_left = 0.5
    encounter_panel.anchor_top = 0.5
    encounter_panel.anchor_right = 0.5
    encounter_panel.anchor_bottom = 0.5
    encounter_panel.offset_left = -250.0
    encounter_panel.offset_top = -150.0
    encounter_panel.offset_right = 250.0
    encounter_panel.offset_bottom = 150.0
    ui_root.add_child(encounter_panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 18)
    margin.add_theme_constant_override("margin_top", 16)
    margin.add_theme_constant_override("margin_right", 18)
    margin.add_theme_constant_override("margin_bottom", 16)
    encounter_panel.add_child(margin)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 10)
    margin.add_child(box)

    var type_label := Label.new()
    type_label.text = "ENCOUNTER"
    type_label.add_theme_font_size_override("font_size", 13)
    box.add_child(type_label)

    encounter_title = Label.new()
    encounter_title.add_theme_font_size_override("font_size", 24)
    box.add_child(encounter_title)

    encounter_body = Label.new()
    encounter_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(encounter_body)

    var engage := Button.new()
    engage.text = "Engage"
    engage.custom_minimum_size = Vector2(0, 48)
    engage.pressed.connect(_resolve_encounter.bind(true))
    box.add_child(engage)

    var withdraw := Button.new()
    withdraw.text = "Withdraw"
    withdraw.custom_minimum_size = Vector2(0, 44)
    withdraw.pressed.connect(_resolve_encounter.bind(false))
    box.add_child(withdraw)

func _refresh_game_hud() -> void:
    if not game_hud:
        return
    var hero_name: String = str(hero_catalog.get(selected_hero_id, {}).get("name", "Hero"))
    turn_label.text = "TURN %d  •  MOVE %d/%d" % [turn_number, moves_remaining, hero_move_points]
    var level: int = 1 + int(hero_xp / 100)
    hero_stats_label.text = "%s\nLevel %d  •  Health %d/100  •  XP %d" % [hero_name, level, hero_health, hero_xp]
    objective_label.text = _objective_text()
    var objective_total: int = board_data.get("objectives", []).size()
    var objective_done: int = 0
    for raw_objective in board_data.get("objectives", []):
        if raw_objective is Dictionary and _objective_complete(raw_objective):
            objective_done += 1
    threat_label.text = "Objectives %d/%d  •  Vulgrim %d%% %s" % [objective_done, objective_total, vulgrim_heat, _threat_stage()]
    if vulgrim_defeated:
        campaign_status_label.text = "ASHENREACH SECURED • VULGRIM DEFEATED"
    elif territory_secured:
        campaign_status_label.text = "Stronghold secured. Vulgrim can now be hunted."
    elif _all_objectives_complete():
        campaign_status_label.text = "Primary objectives complete. Secure the territory."
    else:
        campaign_status_label.text = "Explore, survive, and secure Ashenreach."
    if ability_button:
        var ability_name: String = str(hero_catalog.get(selected_hero_id, {}).get("signature_ability", "Signature Ability"))
        ability_button.text = ("%s READY" % ability_name) if not signature_ability_used else ("%s USED" % ability_name)
        ability_button.disabled = signature_ability_used
    var bonuses: Array[String] = []
    if claimed_pois.has("CapitalRuins"):
        bonuses.append("Capital: recovery")
    if claimed_pois.has("Overlook"):
        bonuses.append("Overlook: +reveal")
    if claimed_pois.has("ElevatedOutpost"):
        bonuses.append("Outpost: enemy intel")
    if claimed_pois.has("RitualTotems"):
        bonuses.append("Totems: slower threat")
    if not bonuses.is_empty():
        campaign_status_label.text += "\n" + " • ".join(bonuses)
    if boss_button:
        boss_button.visible = vulgrim_available and not vulgrim_defeated

func _objective_text() -> String:
    var lines: Array[String] = ["OBJECTIVES"]
    var objectives = board_data.get("objectives", [])
    for raw in objectives:
        if not raw is Dictionary:
            continue
        var objective: Dictionary = raw
        var done := _objective_complete(objective)
        var mark := "✓" if done else "◇"
        lines.append("%s %s" % [mark, str(objective.get("label", "Objective"))])
    return "\n".join(lines)

func _objective_complete(objective: Dictionary) -> bool:
    var kind: String = str(objective.get("type", ""))
    if kind == "discover_poi":
        return discovered_pois.has(str(objective.get("target", "")))
    if kind == "claim_poi":
        return claimed_pois.has(str(objective.get("target", "")))
    if kind == "discover_count":
        return discovered_pois.size() >= int(objective.get("target", 0))
    if kind == "dungeon_clear":
        return sundered_vault_cleared
    return false

func _all_objectives_complete() -> bool:
    var objectives = board_data.get("objectives", [])
    if objectives.is_empty():
        return false
    for raw in objectives:
        if raw is Dictionary and not _objective_complete(raw):
            return false
    return true

func _threat_stage() -> String:
    if vulgrim_heat >= 80:
        return "ERUPTION IMMINENT"
    if vulgrim_heat >= 55:
        return "Violent"
    if vulgrim_heat >= 30:
        return "Stirring"
    return "Dormant"

func _prime_signature_ability() -> void:
    if signature_ability_used:
        return
    signature_ability_used = true
    signature_ability_primed = true
    var ability_name: String = str(hero_catalog.get(selected_hero_id, {}).get("signature_ability", "Signature Ability"))
    event_log_label.text = "%s primed for the next encounter." % ability_name
    _refresh_game_hud()
    _save_game_state()

func _end_turn() -> void:
    if encounter_panel and encounter_panel.visible:
        return
    turn_number += 1
    moves_remaining = hero_move_points
    signature_ability_used = false
    signature_ability_primed = false
    if claimed_pois.has("CapitalRuins") and current_move_node in ["CapitalSouth", "CapitalNorth"]:
        hero_health = min(100, hero_health + 10)
    var threat: Dictionary = board_data.get("legendary_threat", {})
    var escalation: int = int(threat.get("escalation_per_turn", 5))
    if claimed_pois.has("RitualTotems"):
        escalation = maxi(1, escalation - 2)
    vulgrim_heat = mini(int(threat.get("max_heat", 100)), vulgrim_heat + escalation)
    if vulgrim_heat >= 100:
        vulgrim_available = true
        event_log_label.text = "Inferno-Lord Vulgrim has awakened. The apex threat can now be confronted."
    else:
        event_log_label.text = "Turn %d begins. The Ashen Wastes grow more unstable." % turn_number
    _refresh_enemy_visibility()
    _refresh_game_hud()
    _save_game_state()

func _reveal_nearby_pois() -> void:
    var rules: Dictionary = board_data.get("poi_rules", {})
    for child in $POIs.get_children():
        if not child is Area3D:
            continue
        var poi := child as Area3D
        var radius := 5.0
        if rules.has(poi.name):
            var rule: Dictionary = rules[poi.name]
            radius = float(rule.get("discovery_radius", 5.0))
        var hero_flat := Vector2(hero_unit.global_position.x, hero_unit.global_position.z)
        var poi_flat := Vector2(poi.global_position.x, poi.global_position.z)
        if hero_flat.distance_to(poi_flat) <= radius and not discovered_pois.has(poi.name):
            discovered_pois[poi.name] = true
            if event_log_label:
                event_log_label.text = "Discovered: %s" % str(POI_DATA.get(poi.name, {}).get("title", poi.name))

func _refresh_poi_visibility() -> void:
    for child in $POIs.get_children():
        if not child is Area3D:
            continue
        var poi := child as Area3D
        var marker := poi.get_node_or_null("Marker") as MeshInstance3D
        if marker:
            marker.visible = discovered_pois.has(poi.name)

func _build_victory_panel() -> void:
    victory_panel = PanelContainer.new()
    victory_panel.name = "VictoryPanel"
    victory_panel.visible = false
    victory_panel.anchor_left = 0.5
    victory_panel.anchor_top = 0.5
    victory_panel.anchor_right = 0.5
    victory_panel.anchor_bottom = 0.5
    victory_panel.offset_left = -280.0
    victory_panel.offset_top = -155.0
    victory_panel.offset_right = 280.0
    victory_panel.offset_bottom = 155.0
    ui_root.add_child(victory_panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 20)
    margin.add_theme_constant_override("margin_top", 18)
    margin.add_theme_constant_override("margin_right", 20)
    margin.add_theme_constant_override("margin_bottom", 18)
    victory_panel.add_child(margin)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 10)
    margin.add_child(box)

    var title := Label.new()
    title.text = "ASHENREACH SECURED"
    title.add_theme_font_size_override("font_size", 30)
    box.add_child(title)

    var body := Label.new()
    body.text = "Inferno-Lord Vulgrim has fallen. The Ashen Wastes stronghold is under your control.\n\nThis territory is complete, but you may continue exploring or restart the Ashenreach campaign."
    body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(body)

    var continue_button := Button.new()
    continue_button.text = "Continue Exploring"
    continue_button.custom_minimum_size = Vector2(0, 48)
    continue_button.pressed.connect(func(): victory_panel.visible = false)
    box.add_child(continue_button)

    var restart_button := Button.new()
    restart_button.text = "Restart Ashenreach"
    restart_button.custom_minimum_size = Vector2(0, 44)
    restart_button.pressed.connect(func():
        victory_panel.visible = false
        _restart_campaign()
    )
    box.add_child(restart_button)

func _build_fog_of_war() -> void:
    fog_root = Node3D.new()
    fog_root.name = "FogOfWar"
    add_child(fog_root)

    var fog_material := ShaderMaterial.new()
    var fog_shader := Shader.new()
    fog_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

void fragment() {
    vec2 p = UV - vec2(0.5);
    float d = length(p);
    float soft_edge = 1.0 - smoothstep(0.33, 0.72, d);
    float center_texture = 0.90 + 0.10 * sin((UV.x + UV.y) * 18.0);
    ALBEDO = vec3(0.01, 0.014, 0.018);
    ALPHA = soft_edge * 0.58 * center_texture;
}
"""
    fog_material.shader = fog_shader

    var x_index: int = 0
    var x: float = -16.0
    while x <= 16.0:
        var z_index: int = 0
        var z: float = -12.0
        while z <= 16.0:
            var key := "%d_%d" % [x_index, z_index]
            var tile := MeshInstance3D.new()
            tile.name = "Fog_%s" % key
            var plane := PlaneMesh.new()
            plane.size = Vector2(FOG_CELL_SIZE * 1.9, FOG_CELL_SIZE * 1.9)
            tile.mesh = plane
            tile.material_override = fog_material
            tile.position = Vector3(x, 7.05, z)
            tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            fog_root.add_child(tile)
            fog_tiles[key] = tile
            z += FOG_CELL_SIZE
            z_index += 1
        x += FOG_CELL_SIZE
        x_index += 1

    _refresh_fog_tiles()

func _refresh_fog_reveal() -> void:
    if not fog_root:
        return
    var hero_flat := Vector2(hero_unit.global_position.x, hero_unit.global_position.z)
    for key_variant in fog_tiles.keys():
        var key: String = str(key_variant)
        var tile := fog_tiles[key] as MeshInstance3D
        if not tile:
            continue
        var tile_flat := Vector2(tile.global_position.x, tile.global_position.z)
        var reveal_radius: float = FOG_REVEAL_RADIUS
        if claimed_pois.has("Overlook"):
            reveal_radius += 3.0
        if hero_flat.distance_to(tile_flat) <= reveal_radius:
            revealed_fog_cells[key] = true
    _refresh_fog_tiles()

func _refresh_fog_tiles() -> void:
    for key_variant in fog_tiles.keys():
        var key: String = str(key_variant)
        var tile := fog_tiles[key] as MeshInstance3D
        if tile:
            tile.visible = not revealed_fog_cells.has(key)

func _build_route_preview() -> void:
    route_preview = MeshInstance3D.new()
    route_preview.name = "RoutePreview"
    route_preview.visible = false
    add_child(route_preview)

func _show_route_preview(path: Array[String]) -> void:
    if not route_preview or path.size() < 2:
        return

    var mesh := ImmediateMesh.new()
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.albedo_color = Color(0.12, 0.82, 0.72, 0.85)
    material.emission_enabled = true
    material.emission = Color(0.08, 0.9, 0.78, 1.0)
    material.emission_energy_multiplier = 1.4

    mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)

    for edge_index in range(path.size() - 1):
        var from_node: String = path[edge_index]
        var to_node: String = path[edge_index + 1]
        var points: Array = _road_points(from_node, to_node)
        for i in range(points.size() - 1):
            var a: Vector3 = points[i] + Vector3(0.0, 0.055, 0.0)
            var b: Vector3 = points[i + 1] + Vector3(0.0, 0.055, 0.0)
            mesh.surface_add_vertex(a)
            mesh.surface_add_vertex(b)

    mesh.surface_end()
    route_preview.mesh = mesh
    route_preview.visible = true

func _hide_route_preview() -> void:
    if route_preview:
        route_preview.visible = false
        route_preview.mesh = null

func _build_enemy_board() -> void:
    enemy_root = Node3D.new()
    enemy_root.name = "EnemyBoard"
    add_child(enemy_root)
    _refresh_enemy_board()

func _refresh_enemy_board() -> void:
    if not enemy_root:
        return

    for child in enemy_root.get_children():
        child.queue_free()
    enemy_pieces.clear()

    var encounters: Dictionary = board_data.get("encounters", {})
    for node_name_variant in encounters.keys():
        var node_name: String = str(node_name_variant)
        if completed_encounters.has(node_name):
            continue
        if not move_nodes_root.has_node(node_name):
            continue

        var move_node := move_nodes_root.get_node(node_name) as Area3D
        if not move_node:
            continue

        var data: Dictionary = encounters[node_name]
        var piece := Node3D.new()
        piece.name = "Enemy_%s" % node_name
        piece.global_position = _ground_point(move_node.global_position)
        enemy_root.add_child(piece)

        var body := MeshInstance3D.new()
        var mesh := CapsuleMesh.new()
        mesh.radius = 0.30
        mesh.height = 1.05
        mesh.radial_segments = 12
        mesh.rings = 6
        body.mesh = mesh
        body.position = Vector3(0.0, 0.52, 0.0)

        var material := StandardMaterial3D.new()
        material.albedo_color = Color(0.34, 0.08, 0.045, 1.0)
        material.emission_enabled = true
        material.emission = Color(0.7, 0.12, 0.04, 1.0)
        material.emission_energy_multiplier = 1.1
        material.roughness = 0.72
        body.material_override = material
        piece.add_child(body)

        var ring := MeshInstance3D.new()
        var ring_mesh := TorusMesh.new()
        ring_mesh.inner_radius = 0.44
        ring_mesh.outer_radius = 0.53
        ring_mesh.rings = 18
        ring_mesh.ring_segments = 8
        ring.mesh = ring_mesh
        ring.position = Vector3(0.0, 0.035, 0.0)

        var ring_material := StandardMaterial3D.new()
        ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        ring_material.albedo_color = Color(0.8, 0.12, 0.04, 0.62)
        ring_material.emission_enabled = true
        ring_material.emission = Color(0.9, 0.11, 0.03, 1.0)
        ring_material.emission_energy_multiplier = 1.45
        ring.material_override = ring_material
        piece.add_child(ring)

        var label := Label3D.new()
        label.text = str(data.get("name", "Threat"))
        label.font_size = 16
        label.pixel_size = 0.014
        label.position = Vector3(0.0, 1.55, 0.0)
        label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        label.no_depth_test = true
        piece.add_child(label)

        enemy_pieces[node_name] = piece

    _refresh_enemy_visibility()

func _refresh_enemy_visibility() -> void:
    if enemy_pieces.is_empty():
        return
    var hero_flat := Vector2(hero_unit.global_position.x, hero_unit.global_position.z)
    for node_name_variant in enemy_pieces.keys():
        var node_name: String = str(node_name_variant)
        var piece := enemy_pieces[node_name] as Node3D
        if not piece or not is_instance_valid(piece):
            continue
        var enemy_flat := Vector2(piece.global_position.x, piece.global_position.z)
        var visibility_radius: float = 9.0
        if claimed_pois.has("ElevatedOutpost"):
            visibility_radius = 18.0
        piece.visible = hero_flat.distance_to(enemy_flat) <= visibility_radius or node_name == current_move_node

func _node_has_active_encounter(node_name: String) -> bool:
    var encounters: Dictionary = board_data.get("encounters", {})
    return encounters.has(node_name) and not completed_encounters.has(node_name)

func _refresh_claimed_poi_style() -> void:
    for child in $POIs.get_children():
        if not child is Area3D:
            continue
        var poi := child as Area3D
        var marker := poi.get_node_or_null("Marker") as MeshInstance3D
        if not marker:
            continue
        if poi.name == "SunderedVault" and sundered_vault_cleared:
            var vault_material := StandardMaterial3D.new()
            vault_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
            vault_material.albedo_color = Color(0.82, 0.42, 0.12, 0.72)
            vault_material.emission_enabled = true
            vault_material.emission = Color(1.0, 0.30, 0.06, 1.0)
            vault_material.emission_energy_multiplier = 1.5
            vault_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            marker.material_override = vault_material
        elif claimed_pois.has(poi.name):
            var controlled_material := StandardMaterial3D.new()
            controlled_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
            controlled_material.albedo_color = Color(0.18, 0.72, 0.34, 0.66)
            controlled_material.emission_enabled = true
            controlled_material.emission = Color(0.12, 0.8, 0.28, 1.0)
            controlled_material.emission_energy_multiplier = 1.25
            controlled_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            marker.material_override = controlled_material

func _hero_near_poi(poi: Node3D, radius: float = 2.2) -> bool:
    var hero_flat := Vector2(hero_unit.global_position.x, hero_unit.global_position.z)
    var poi_flat := Vector2(poi.global_position.x, poi.global_position.z)
    return hero_flat.distance_to(poi_flat) <= radius

func _poi_rule(poi_name: String) -> Dictionary:
    var rules: Dictionary = board_data.get("poi_rules", {})
    if rules.has(poi_name):
        return rules[poi_name]
    return {}

func _trigger_node_encounter(node_name: String) -> void:
    var encounters: Dictionary = board_data.get("encounters", {})
    if not encounters.has(node_name) or completed_encounters.has(node_name):
        return
    var data: Dictionary = encounters[node_name]
    current_encounter_node = node_name
    encounter_title.text = str(data.get("name", "Encounter"))
    encounter_body.text = "%s\n\nDanger %d  •  Reward %d XP" % [
        str(data.get("description", "")),
        int(data.get("danger", 1)),
        int(data.get("xp", 0))
    ]
    encounter_panel.visible = true
    movement_panel.visible = false
    event_log_label.text = "Encounter: %s" % str(data.get("name", "Unknown threat"))

func _resolve_encounter(engage: bool) -> void:
    if current_encounter_node == "__VULGRIM__":
        if engage:
            _resolve_vulgrim()
        else:
            encounter_panel.visible = false
            current_encounter_node = ""
            moves_remaining = 0
            event_log_label.text = "You withdrew from Vulgrim. Movement exhausted this turn."
            _refresh_game_hud()
            _save_game_state()
        return
    if current_encounter_node == "":
        encounter_panel.visible = false
        return
    var encounters: Dictionary = board_data.get("encounters", {})
    if not encounters.has(current_encounter_node):
        encounter_panel.visible = false
        current_encounter_node = ""
        return

    var data: Dictionary = encounters[current_encounter_node]
    if engage:
        var loss: int = int(data.get("health_loss", 0))
        var gain: int = int(data.get("xp", 0))
        var ability_note := ""
        if signature_ability_primed:
            if selected_hero_id == "vesper":
                loss = 0
                ability_note = " Glacial Bastion absorbed the incoming damage."
            elif selected_hero_id == "ignis":
                loss = int(floor(float(loss) * 0.5))
                gain += 10
                ability_note = " Eruption Strike broke the enemy line."
            signature_ability_primed = false
        hero_health = max(0, hero_health - loss)
        hero_xp += gain
        completed_encounters[current_encounter_node] = true
        _refresh_enemy_board()
        event_log_label.text = "%s defeated. +%d XP, -%d health.%s" % [str(data.get("name", "Enemy")), gain, loss, ability_note]
        if hero_health <= 0:
            _handle_hero_defeat()
    else:
        moves_remaining = 0
        event_log_label.text = "Withdrew from %s. Movement exhausted this turn." % str(data.get("name", "encounter"))

    current_encounter_node = ""
    encounter_panel.visible = false
    _refresh_game_hud()
    _save_game_state()

func _open_vulgrim_encounter() -> void:
    if not vulgrim_available or vulgrim_defeated:
        return
    current_encounter_node = "__VULGRIM__"
    encounter_title.text = "Inferno-Lord Vulgrim"
    encounter_body.text = "WORLD-ENDING THREAT / APEX ENTITY\n\nVulgrim erupts from the Ashen Wastes in a storm of magma and catastrophic heat. This is the territory's legendary confrontation.\n\nRecommended: secure Ashenreach first and enter with high health."
    encounter_panel.visible = true

func _resolve_vulgrim() -> void:
    var damage: int = 35
    if territory_secured:
        damage = 22
    if signature_ability_primed:
        if selected_hero_id == "vesper":
            damage = int(floor(float(damage) * 0.5))
        elif selected_hero_id == "ignis":
            damage = int(floor(float(damage) * 0.65))
        signature_ability_primed = false
    hero_health = max(0, hero_health - damage)
    hero_xp += 150
    vulgrim_defeated = true
    vulgrim_available = false
    territory_secured = true
    encounter_panel.visible = false
    current_encounter_node = ""
    event_log_label.text = "Inferno-Lord Vulgrim defeated. Ashenreach is fully secured."
    _refresh_game_hud()
    _save_game_state()
    if victory_panel:
        victory_panel.visible = true

func _handle_hero_defeat() -> void:
    hero_health = 50
    turn_number += 1
    moves_remaining = hero_move_points
    signature_ability_used = false
    signature_ability_primed = false
    vulgrim_heat = min(100, vulgrim_heat + 10)
    current_move_node = "BasaltCenter"
    if move_nodes_root.has_node(current_move_node):
        var retreat_node := move_nodes_root.get_node(current_move_node) as Area3D
        if retreat_node:
            hero_unit.global_position = _ground_point(retreat_node.global_position)
    event_log_label.text = "The hero was defeated and forced to retreat. Returned with 50 health; Vulgrim's threat increased."
    encounter_panel.visible = false
    current_encounter_node = ""

func _restart_campaign() -> void:
    if victory_panel:
        victory_panel.visible = false
    turn_number = 1
    hero_health = 100
    hero_xp = 0
    vulgrim_heat = 0
    territory_secured = false
    vulgrim_available = false
    vulgrim_defeated = false
    signature_ability_used = false
    signature_ability_primed = false
    sundered_vault_cleared = false
    moves_remaining = hero_move_points
    current_move_node = "BasaltCenter"
    pending_move_node = ""
    pending_move_cost = 0
    pending_path.clear()
    _hide_route_preview()
    discovered_pois.clear()
    claimed_pois.clear()
    completed_encounters.clear()
    revealed_fog_cells.clear()
    if FileAccess.file_exists("user://sundered_vault_save.cfg"):
        DirAccess.remove_absolute(ProjectSettings.globalize_path("user://sundered_vault_save.cfg"))

    if move_nodes_root.has_node(current_move_node):
        var start_node := move_nodes_root.get_node(current_move_node) as Area3D
        if start_node:
            hero_unit.global_position = _ground_point(start_node.global_position)

    _refresh_enemy_board()
    _refresh_fog_reveal()
    _reveal_nearby_pois()
    _refresh_poi_visibility()
    _refresh_enemy_visibility()
    event_log_label.text = "A new Ashenreach expedition has begun."
    _refresh_game_hud()
    _save_game_state()
    reset_camera()

func _save_game_state() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("board", "turn", turn_number)
    cfg.set_value("board", "moves_remaining", moves_remaining)
    cfg.set_value("board", "current_move_node", current_move_node)
    cfg.set_value("board", "selected_hero_id", selected_hero_id)
    cfg.set_value("board", "hero_health", hero_health)
    cfg.set_value("board", "hero_xp", hero_xp)
    cfg.set_value("board", "vulgrim_heat", vulgrim_heat)
    cfg.set_value("board", "territory_secured", territory_secured)
    cfg.set_value("board", "vulgrim_available", vulgrim_available)
    cfg.set_value("board", "vulgrim_defeated", vulgrim_defeated)
    cfg.set_value("board", "signature_ability_used", signature_ability_used)
    cfg.set_value("board", "signature_ability_primed", signature_ability_primed)
    cfg.set_value("board", "sundered_vault_cleared", sundered_vault_cleared)
    cfg.set_value("board", "discovered_pois", discovered_pois.keys())
    cfg.set_value("board", "claimed_pois", claimed_pois.keys())
    cfg.set_value("board", "completed_encounters", completed_encounters.keys())
    cfg.set_value("board", "revealed_fog_cells", revealed_fog_cells.keys())
    cfg.save("user://ashenreach_save.cfg")

func _load_game_state() -> void:
    var cfg := ConfigFile.new()
    if cfg.load("user://ashenreach_save.cfg") != OK:
        moves_remaining = hero_move_points
        return

    turn_number = int(cfg.get_value("board", "turn", 1))
    moves_remaining = int(cfg.get_value("board", "moves_remaining", hero_move_points))
    current_move_node = str(cfg.get_value("board", "current_move_node", "BasaltCenter"))
    selected_hero_id = str(cfg.get_value("board", "selected_hero_id", selected_hero_id))
    hero_health = int(cfg.get_value("board", "hero_health", 100))
    hero_xp = int(cfg.get_value("board", "hero_xp", 0))
    vulgrim_heat = int(cfg.get_value("board", "vulgrim_heat", 0))
    territory_secured = bool(cfg.get_value("board", "territory_secured", false))
    vulgrim_available = bool(cfg.get_value("board", "vulgrim_available", false))
    vulgrim_defeated = bool(cfg.get_value("board", "vulgrim_defeated", false))
    signature_ability_used = bool(cfg.get_value("board", "signature_ability_used", false))
    signature_ability_primed = bool(cfg.get_value("board", "signature_ability_primed", false))
    sundered_vault_cleared = bool(cfg.get_value("board", "sundered_vault_cleared", false))

    discovered_pois.clear()
    for key in cfg.get_value("board", "discovered_pois", []):
        discovered_pois[str(key)] = true

    claimed_pois.clear()
    for key in cfg.get_value("board", "claimed_pois", []):
        claimed_pois[str(key)] = true

    completed_encounters.clear()
    for key in cfg.get_value("board", "completed_encounters", []):
        completed_encounters[str(key)] = true

    revealed_fog_cells.clear()
    for key in cfg.get_value("board", "revealed_fog_cells", []):
        revealed_fog_cells[str(key)] = true

    if move_nodes_root.has_node(current_move_node):
        var node := move_nodes_root.get_node(current_move_node) as Area3D
        if node:
            hero_unit.global_position = _ground_point(node.global_position)

func _select_poi(node: Node3D) -> void:
    if not POI_DATA.has(node.name) or not discovered_pois.has(node.name):
        return
    selected_poi = node.name
    var data: Dictionary = POI_DATA[selected_poi]
    poi_type.text = data["type"]
    poi_title.text = data["title"]
    poi_body.text = data["body"]
    var rule := _poi_rule(String(node.name))
    if node.name == "SunderedVault" and sundered_vault_cleared:
        poi_body.text = "The Sundered Vault has been breached. The Ember Seal was recovered and the lower halls are secure."
        poi_action.text = "Re-enter"
        poi_action.disabled = false
    elif bool(rule.get("claimable", false)) and not claimed_pois.has(node.name):
        if _hero_near_poi(node):
            poi_action.text = "Claim"
            poi_action.disabled = false
        else:
            poi_action.text = "Move Closer"
            poi_action.disabled = true
    elif claimed_pois.has(node.name):
        poi_action.text = "Controlled"
        poi_action.disabled = true
    else:
        poi_action.text = data["action"]
        poi_action.disabled = false
    poi_panel.visible = true
    selected_label.visible = false
    selected_ring.global_position = node.global_position + Vector3(0, 0.18, 0)
    selected_ring.visible = true
    status_label.text = data["title"]
    _focus_on_poi(node.global_position)

func _on_poi_action() -> void:
    if selected_poi == "":
        return

    var rule := _poi_rule(selected_poi)
    if bool(rule.get("claimable", false)) and not claimed_pois.has(selected_poi):
        var poi_node := $POIs.get_node_or_null(selected_poi) as Node3D
        if not poi_node or not _hero_near_poi(poi_node):
            poi_body.text += "\n\nMove the hero onto this location before claiming it."
            return
        claimed_pois[selected_poi] = true
        _refresh_claimed_poi_style()
        _refresh_fog_reveal()
        _refresh_enemy_visibility()
        poi_action.text = "Controlled"
        poi_action.disabled = true
        poi_body.text += "\n\nThis strategic location is now under your control."
        event_log_label.text = "Claimed: %s" % str(POI_DATA.get(selected_poi, {}).get("title", selected_poi))
        _refresh_game_hud()
        _save_game_state()
        if _all_objectives_complete():
            territory_secured = true
            vulgrim_available = true
            event_log_label.text = "Ashenreach secured. Inferno-Lord Vulgrim can now be confronted."
            _refresh_game_hud()
            _save_game_state()
        return

    if selected_poi == "SunderedVault":
        var vault_gate := move_nodes_root.get_node_or_null("VaultGate") as Area3D
        if not vault_gate:
            poi_body.text = "The Sundered Vault entrance is unavailable in this build."
            return
        var hero_flat := Vector2(hero_unit.global_position.x, hero_unit.global_position.z)
        var gate_flat := Vector2(vault_gate.global_position.x, vault_gate.global_position.z)
        if hero_flat.distance_to(gate_flat) > 1.5:
            poi_body.text = "The Sundered Vault has been discovered. Move your hero to the Vault Gate before entering."
            return
        _save_game_state()
        get_tree().change_scene_to_file("res://scenes/SunderedVault.tscn")
    else:
        poi_body.text += "\n\nLocation recorded in the Ashenreach campaign map."


func _focus_on_poi(target: Vector3) -> void:
    var desired := Vector3(target.x, max(target.y, 3.5), target.z)
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_CUBIC)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_property(yaw, "position", desired, 0.45)

func _close_poi_panel() -> void:
    poi_panel.visible = false
    poi_action.disabled = false
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
