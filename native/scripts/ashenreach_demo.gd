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
@onready var hero_unit: Area3D = $MovementBoard/HeroUnit
@onready var movement_panel: PanelContainer = $UI/MovementPanel
@onready var movement_stats: Label = $UI/MovementPanel/Margin/VBox/Stats
@onready var movement_title: Label = $UI/MovementPanel/Margin/VBox/Title
@onready var movement_confirm: Button = $UI/MovementPanel/Margin/VBox/ConfirmButton
@onready var hero_select_panel: PanelContainer = $UI/HeroSelectPanel
@onready var hero_roster_box: VBoxContainer = $UI/HeroSelectPanel/Margin/VBox/Roster
@onready var hero_label: Label3D = $MovementBoard/HeroUnit/HeroLabel
@onready var ui_root: CanvasLayer = $UI

var touches: Dictionary = {}
var previous_pinch_distance := 0.0
var previous_two_finger_center := Vector2.ZERO
var touch_start := Vector2.ZERO
var touch_moved := false
var zoom_distance := 30.0
var selected_poi := ""
var glow_time := 0.0
var unit_selected := false
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
var enemy_hex_positions: Dictionary = {}
var campaign_phase := "PLAYER"
var last_enemy_phase_summary := ""
const PHASE_PLAYER := "PLAYER"
const PHASE_ENEMY := "ENEMY"
const PHASE_WORLD := "WORLD"
var route_preview: MeshInstance3D
var victory_panel: PanelContainer
var hud_expanded := false
var hud_details_button: Button
var restart_button: Button
var end_turn_button: Button
var fog_root: Node3D
var fog_tiles: Dictionary = {}
var revealed_fog_cells: Dictionary = {}
var hex_root: Node3D
var hex_cells: Dictionary = {}
var current_hex_key := ""
var pending_hex_key := ""
var pending_hex_path: Array[String] = []
var hex_material_idle: StandardMaterial3D
var hex_material_reachable: StandardMaterial3D
var hex_material_target: StandardMaterial3D
var hex_material_current: StandardMaterial3D
var hex_material_blocked: StandardMaterial3D
var hex_material_forced_open: StandardMaterial3D
var hex_material_forced_blocked: StandardMaterial3D
var hex_material_nav_edit: StandardMaterial3D
var hex_material_nav_selected: StandardMaterial3D
var hex_material_bridge_candidate: StandardMaterial3D
var hex_grid_overlay: MeshInstance3D
var nav_mask_data: Dictionary = {}
var nav_grid_data: Dictionary = {}
var nav_grid_tiles: Dictionary = {}
var nav_blocked_edges: Dictionary = {}
var nav_debug_forced_open: Dictionary = {}
var nav_debug_forced_blocked: Dictionary = {}
var nav_debug_mode := false
var nav_debug_button: Button
var nav_edit_panel: PanelContainer
var nav_edit_info: Label
var nav_selected_hex := ""

const MIN_ZOOM := 16.0
const MAX_ZOOM := 48.0
const ROTATE_SPEED := 0.0055
const PAN_SPEED := 0.016
const PAN_LIMIT := 15.5
const CAMERA_MIN_PITCH_DEG := -84.0
const CAMERA_MAX_PITCH_DEG := -18.0
const TOP_DOWN_SNAP_START_DEG := -76.0
const HERO_GROUND_CLEARANCE := 0.025
# The baked Ashenreach board uses a dense flat-top lattice. The source-board
# repeat is roughly half the spacing of the original prototype grid.
const HEX_SIZE := 0.55
const HEX_WORLD_LIMIT := 17.3
const HEX_GRID_OFFSET := Vector2(0.0, 0.0)
const HEX_SAMPLE_RADIUS := 0.16
const HEX_MAX_LOCAL_VARIANCE := 0.58
const HEX_MAX_STEP := 0.94
const HEX_MIN_UP_DOT := 0.52
const HEX_HIGH_OUTLIER := 0.46
const HEX_MIN_PLAYABLE_HEIGHT := 3.25
const HEX_GRID_VERSION := 12
const HEX_DEPRESSION_RADIUS := 3
const HEX_DEPRESSION_DEPTH := 0.86
const FOG_CELL_SIZE := 4.0
const FOG_REVEAL_RADIUS := 6.5

const ENCOUNTER_START_POSITIONS := {
    "Rattal": Vector3(7.0, 5.15, 3.0),
    "CapitalSouth": Vector3(2.0, 5.55, 1.0),
    "EastBridge": Vector3(10.0, 5.0, 5.2),
    "VaultRoad": Vector3(-6.8, 4.65, 7.4),
    "AmbushPassNode": Vector3(12.5, 4.8, 0.0),
    "ElevatedOutpostNode": Vector3(15.0, 5.6, 5.0),
    "DeadForestNode": Vector3(-12.0, 3.8, 12.0),
    "AshenPlainsNode": Vector3(-12.0, 5.2, -8.0)
}
const CAMPAIGN_START_POSITION := Vector3(0.0, 4.75, 7.5)

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
    _load_generated_nav_grid()
    _load_nav_mask_data()
    _load_nav_debug_overrides()
    _build_hex_board()
    _snap_hero_to_nearest_hex()
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
    _restore_hex_state()
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
            elif touches.size() == 2:
                previous_pinch_distance = _touch_distance()
                previous_two_finger_center = _touch_center()
                touch_moved = true
        else:
            var released_position: Vector2 = event.position
            var was_single := touches.size() == 1
            touches.erase(event.index)

            if touches.size() < 2:
                previous_pinch_distance = 0.0
                previous_two_finger_center = Vector2.ZERO

            if was_single and not touch_moved and released_position.distance_to(touch_start) < 18.0:
                _try_select(released_position)

    elif event is InputEventScreenDrag:
        if touches.has(event.index):
            touches[event.index] = event.position

        if touches.size() == 1:
            touch_moved = true
            _pan_camera(event.relative)

        elif touches.size() >= 2:
            touch_moved = true

            var current_distance := _touch_distance()
            if previous_pinch_distance > 0.0:
                zoom_distance = clamp(
                    zoom_distance - (current_distance - previous_pinch_distance) * 0.025,
                    MIN_ZOOM,
                    MAX_ZOOM
                )
                camera.position.z = zoom_distance
            previous_pinch_distance = current_distance

            var current_center: Vector2 = _touch_center()
            if previous_two_finger_center != Vector2.ZERO:
                var center_delta: Vector2 = current_center - previous_two_finger_center
                var top_down_factor: float = _top_down_factor()
                var orbit_scale: float = lerpf(1.0, 0.48, top_down_factor)
                var tilt_scale: float = lerpf(1.0, 0.42, top_down_factor)

                yaw.rotation.y -= center_delta.x * ROTATE_SPEED * 1.25 * orbit_scale

                var target_pitch: float = pitch.rotation.x - center_delta.y * ROTATE_SPEED * 0.85 * tilt_scale
                target_pitch = clampf(
                    target_pitch,
                    deg_to_rad(CAMERA_MIN_PITCH_DEG),
                    deg_to_rad(CAMERA_MAX_PITCH_DEG)
                )

                if rad_to_deg(target_pitch) <= TOP_DOWN_SNAP_START_DEG:
                    target_pitch = lerpf(target_pitch, deg_to_rad(CAMERA_MIN_PITCH_DEG), 0.34)

                pitch.rotation.x = target_pitch
            previous_two_finger_center = current_center

    elif event is InputEventMouseMotion:
        if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
            var top_down_factor: float = _top_down_factor()
            var orbit_scale: float = lerpf(1.0, 0.48, top_down_factor)
            var tilt_scale: float = lerpf(1.0, 0.42, top_down_factor)
            yaw.rotation.y -= event.relative.x * ROTATE_SPEED * orbit_scale
            var target_pitch: float = pitch.rotation.x - event.relative.y * ROTATE_SPEED * tilt_scale
            target_pitch = clampf(
                target_pitch,
                deg_to_rad(CAMERA_MIN_PITCH_DEG),
                deg_to_rad(CAMERA_MAX_PITCH_DEG)
            )
            if rad_to_deg(target_pitch) <= TOP_DOWN_SNAP_START_DEG:
                target_pitch = lerpf(target_pitch, deg_to_rad(CAMERA_MIN_PITCH_DEG), 0.34)
            pitch.rotation.x = target_pitch
        elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
            _pan_camera(event.relative)

    elif event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
            zoom_distance = clamp(zoom_distance - 1.4, MIN_ZOOM, MAX_ZOOM)
            camera.position.z = zoom_distance
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
            zoom_distance = clamp(zoom_distance + 1.4, MIN_ZOOM, MAX_ZOOM)
            camera.position.z = zoom_distance
        elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
            _try_select(event.position)

func _touch_center() -> Vector2:
    if touches.is_empty():
        return Vector2.ZERO
    var sum := Vector2.ZERO
    for point_variant in touches.values():
        sum += point_variant as Vector2
    return sum / float(touches.size())

func _top_down_factor() -> float:
    var pitch_degrees: float = absf(rad_to_deg(pitch.rotation.x))
    return clampf((pitch_degrees - 50.0) / 34.0, 0.0, 1.0)

func _pan_camera(screen_delta: Vector2) -> void:
    var zoom_scale: float = clampf(zoom_distance / 30.0, 0.65, 1.55)
    var top_down_boost: float = lerpf(1.0, 1.75, _top_down_factor())

    var right: Vector3 = yaw.global_transform.basis.x
    right.y = 0.0
    right = right.normalized()

    var forward: Vector3 = -yaw.global_transform.basis.z
    forward.y = 0.0
    forward = forward.normalized()

    var world_delta: Vector3 = (-right * screen_delta.x + forward * screen_delta.y) * PAN_SPEED * zoom_scale * top_down_boost
    yaw.position += world_delta
    yaw.position.x = clamp(yaw.position.x, -PAN_LIMIT, PAN_LIMIT)
    yaw.position.z = clamp(yaw.position.z, -PAN_LIMIT, PAN_LIMIT)
    yaw.position.y = 3.5

func _touch_distance() -> float:
    if touches.size() < 2:
        return 0.0
    var points := touches.values()
    return (points[0] as Vector2).distance_to(points[1] as Vector2)

func _try_select(screen_position: Vector2) -> void:
    if campaign_phase != PHASE_PLAYER:
        return
    if nav_debug_mode:
        _try_select_nav_hex(screen_position)
        return

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
    elif collider.is_in_group("hex_cell") and unit_selected:
        _select_hex_destination(collider)
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
    if movement_title:
        movement_title.text = "MOVE %s" % short_name

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
    await get_tree().process_frame
    _snap_visual_to_ground(active_hero_model, 0.0)

    if placeholder:
        placeholder.visible = false

func _snap_visual_to_ground(root: Node3D, target_y: float = 0.02) -> void:
    var lowest: float = INF
    lowest = _lowest_mesh_y_in_parent(root, root.get_parent() as Node3D, lowest)
    if lowest < INF:
        root.position.y += target_y - lowest

func _lowest_mesh_y_in_parent(node: Node, parent_space: Node3D, current_lowest: float) -> float:
    var lowest := current_lowest

    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        if mesh_instance.mesh:
            var box: AABB = mesh_instance.get_aabb()
            var corners: Array[Vector3] = [
                box.position,
                box.position + Vector3(box.size.x, 0.0, 0.0),
                box.position + Vector3(0.0, box.size.y, 0.0),
                box.position + Vector3(0.0, 0.0, box.size.z),
                box.position + Vector3(box.size.x, box.size.y, 0.0),
                box.position + Vector3(box.size.x, 0.0, box.size.z),
                box.position + Vector3(0.0, box.size.y, box.size.z),
                box.position + box.size
            ]
            for corner in corners:
                var world_corner: Vector3 = mesh_instance.to_global(corner)
                var parent_corner: Vector3 = parent_space.to_local(world_corner)
                lowest = minf(lowest, parent_corner.y)

    for child in node.get_children():
        lowest = _lowest_mesh_y_in_parent(child, parent_space, lowest)

    return lowest

func _select_unit(_unit: Area3D) -> void:
    if nav_debug_mode:
        return
    if campaign_phase != PHASE_PLAYER or moves_remaining <= 0:
        return
    _close_poi_panel()
    unit_selected = true
    hero_label.visible = true
    pending_move_cost = 0
    movement_panel.visible = true
    movement_confirm.disabled = true
    var hero_name: String = str(hero_catalog.get(selected_hero_id, {}).get("name", "Hero"))
    var hero_short: String = hero_name.split(",")[0].to_upper()
    if movement_title:
        movement_title.text = "MOVE %s" % hero_short
    var neighbor_count: int = _hex_neighbors(current_hex_key).size()
    var raw_neighbor_count: int = _hex_raw_neighbor_count(current_hex_key)
    movement_stats.text = "%s selected. Action points remaining: %d\nAdjacent open hexes: %d / %d. Each hex costs 1 AP." % [
        hero_name, moves_remaining, neighbor_count, raw_neighbor_count
    ]
    status_label.text = "%s — choose a destination" % hero_name
    _focus_on_poi(hero_unit.global_position)
    if hex_grid_overlay:
        hex_grid_overlay.visible = true
    _show_reachable_hexes()

func _confirm_unit_move() -> void:
    if pending_hex_key != "":
        await _confirm_hex_move()

func _build_hex_board() -> void:
    hex_root = Node3D.new()
    hex_root.name = "HexBoard"
    add_child(hex_root)

    hex_material_idle = StandardMaterial3D.new()
    hex_material_idle.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    hex_material_idle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    hex_material_idle.albedo_color = Color(0.07, 0.30, 0.26, 0.22)
    hex_material_idle.emission_enabled = true
    hex_material_idle.emission = Color(0.08, 0.32, 0.28, 1.0)
    hex_material_idle.emission_energy_multiplier = 0.48

    hex_material_reachable = hex_material_idle.duplicate() as StandardMaterial3D
    hex_material_reachable.albedo_color = Color(0.10, 0.82, 0.68, 0.46)
    hex_material_reachable.emission = Color(0.08, 0.92, 0.74, 1.0)
    hex_material_reachable.emission_energy_multiplier = 0.9

    hex_material_target = hex_material_idle.duplicate() as StandardMaterial3D
    hex_material_target.albedo_color = Color(0.95, 0.58, 0.12, 0.38)
    hex_material_target.emission = Color(1.0, 0.42, 0.05, 1.0)
    hex_material_target.emission_energy_multiplier = 1.2

    hex_material_current = hex_material_idle.duplicate() as StandardMaterial3D
    hex_material_current.albedo_color = Color(0.20, 0.62, 0.95, 0.34)
    hex_material_current.emission = Color(0.12, 0.52, 1.0, 1.0)
    hex_material_current.emission_energy_multiplier = 1.1

    hex_material_blocked = hex_material_idle.duplicate() as StandardMaterial3D
    hex_material_blocked.albedo_color = Color(0.34, 0.06, 0.035, 0.16)
    hex_material_blocked.emission = Color(0.42, 0.05, 0.02, 1.0)
    hex_material_blocked.emission_energy_multiplier = 0.22

    hex_material_forced_open = hex_material_idle.duplicate() as StandardMaterial3D
    hex_material_forced_open.albedo_color = Color(0.08, 0.72, 0.30, 0.34)
    hex_material_forced_open.emission = Color(0.05, 0.95, 0.30, 1.0)
    hex_material_forced_open.emission_energy_multiplier = 0.9

    hex_material_forced_blocked = hex_material_idle.duplicate() as StandardMaterial3D
    hex_material_forced_blocked.albedo_color = Color(0.78, 0.08, 0.04, 0.34)
    hex_material_forced_blocked.emission = Color(1.0, 0.12, 0.04, 1.0)
    hex_material_forced_blocked.emission_energy_multiplier = 0.85

    hex_material_nav_edit = hex_material_idle.duplicate() as StandardMaterial3D
    hex_material_nav_edit.albedo_color = Color(0.06, 0.62, 0.72, 0.40)
    hex_material_nav_edit.emission = Color(0.04, 0.72, 0.86, 1.0)
    hex_material_nav_edit.emission_energy_multiplier = 0.75

    hex_material_nav_selected = hex_material_idle.duplicate() as StandardMaterial3D
    hex_material_nav_selected.albedo_color = Color(0.98, 0.72, 0.10, 0.62)
    hex_material_nav_selected.emission = Color(1.0, 0.58, 0.04, 1.0)
    hex_material_nav_selected.emission_energy_multiplier = 1.35

    hex_material_bridge_candidate = hex_material_idle.duplicate() as StandardMaterial3D
    hex_material_bridge_candidate.albedo_color = Color(0.66, 0.18, 0.92, 0.48)
    hex_material_bridge_candidate.emission = Color(0.72, 0.20, 1.0, 1.0)
    hex_material_bridge_candidate.emission_energy_multiplier = 1.0

    var q_min := -23
    var q_max := 23
    var r_min := -30
    var r_max := 30

    for r in range(r_min, r_max + 1):
        for q in range(q_min, q_max + 1):
            var center2 := _hex_to_world_2d(q, r)
            if absf(center2.x) > HEX_WORLD_LIMIT or absf(center2.y) > HEX_WORLD_LIMIT:
                continue

            var key := _hex_key(q, r)
            var sample: Dictionary = _sample_hex_surface(key, center2.x, center2.y)
            var has_surface: bool = bool(sample.get("has_surface", false))
            var sampled_position: Vector3 = sample.get(
                "position",
                Vector3(center2.x, CAMPAIGN_START_POSITION.y, center2.y)
            ) as Vector3

            var area := Area3D.new()
            area.name = "Hex_%s" % key
            area.add_to_group("hex_cell")
            area.set_meta("hex_key", key)
            area.position = sampled_position
            area.collision_layer = 2
            area.collision_mask = 0

            var collision := CollisionShape3D.new()
            collision.name = "PickShape"
            var shape := CylinderShape3D.new()
            shape.radius = HEX_SIZE * 0.82
            shape.height = 0.20
            collision.shape = shape
            collision.position.y = 0.08
            collision.disabled = not has_surface
            area.add_child(collision)

            var visual := MeshInstance3D.new()
            visual.name = "Visual"
            var mesh := CylinderMesh.new()
            mesh.top_radius = HEX_SIZE * 0.93
            mesh.bottom_radius = HEX_SIZE * 0.93
            mesh.height = 0.018
            mesh.radial_segments = 6
            visual.mesh = mesh
            visual.position.y = 0.045
            visual.rotation_degrees.y = 30.0
            visual.material_override = hex_material_idle
            visual.visible = has_surface
            area.add_child(visual)

            hex_root.add_child(area)
            hex_cells[key] = {
                "q": q,
                "r": r,
                "position": area.position,
                "area": area,
                "height": float(area.position.y),
                "has_surface": has_surface,
                "generated_has_surface": has_surface,
                "generated_position": area.position,
                "generated_height": float(area.position.y),
                "up_dot": float(sample.get("up_dot", -1.0)),
                "inferred_bridge": bool(sample.get("inferred_bridge", false)),
                "auto_blocked": bool(sample.get("auto_blocked", false)),
                "walkable": has_surface and not bool(sample.get("auto_blocked", false)),
                "auto_walkable": has_surface and not bool(sample.get("auto_blocked", false)),
                "blocked_reason": "auto_hazard" if bool(sample.get("auto_blocked", false)) else ("" if has_surface else "void"),
                "nav_source": "auto"
            }

    _normalize_hex_surface_heights()
    _classify_hex_cells()
    _build_hex_grid_overlay()
    _clear_hex_highlights()

func _normalize_hex_surface_heights() -> void:
    # Correct obvious prop-top outliers against the complete neighboring lattice.
    # Nothing is deleted here.
    var corrections: Dictionary = {}
    var directions := [
        Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
        Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
    ]

    for key_variant in hex_cells.keys():
        var key := str(key_variant)
        var cell: Dictionary = hex_cells[key]
        if not bool(cell.get("has_surface", false)):
            continue

        var q: int = int(cell["q"])
        var r: int = int(cell["r"])
        var neighbor_heights: Array[float] = []

        for d in directions:
            var neighbor_key := _hex_key(q + d.x, r + d.y)
            if not hex_cells.has(neighbor_key):
                continue
            var neighbor: Dictionary = hex_cells[neighbor_key]
            if bool(neighbor.get("has_surface", false)):
                neighbor_heights.append(float(neighbor["height"]))

        if neighbor_heights.size() < 3:
            continue

        neighbor_heights.sort()
        var median_height: float = neighbor_heights[int(neighbor_heights.size() / 2)]
        var cell_height: float = float(cell["height"])
        if cell_height - median_height >= HEX_HIGH_OUTLIER:
            corrections[key] = median_height

    for key_variant in corrections.keys():
        var key := str(key_variant)
        if not hex_cells.has(key):
            continue
        var corrected_height: float = float(corrections[key])
        var cell: Dictionary = hex_cells[key]
        var area := cell["area"] as Area3D
        var pos: Vector3 = cell["position"]
        pos.y = corrected_height
        cell["height"] = corrected_height
        cell["position"] = pos
        hex_cells[key] = cell
        if area:
            area.position = pos

func _classify_hex_cells() -> void:
    # Generated nav data provides the cleaned board footprint, repaired bridge
    # continuity, and conservative auto-hazard hints. The authored mask remains
    # the final gameplay authority.
    for key_variant in hex_cells.keys():
        var key := str(key_variant)
        var cell: Dictionary = hex_cells[key]
        var has_surface: bool = bool(cell.get("has_surface", false))
        var auto_blocked: bool = bool(cell.get("auto_blocked", false))
        var auto_open: bool = has_surface and not auto_blocked

        cell["walkable"] = auto_open
        cell["auto_walkable"] = auto_open
        cell["blocked_reason"] = "auto_hazard" if auto_blocked else ("" if has_surface else "void")
        cell["nav_source"] = "auto"
        hex_cells[key] = cell

    _apply_nav_mask_overrides()
    _apply_hex_classification_visuals()

func _apply_hex_classification_visuals() -> void:
    for key_variant in hex_cells.keys():
        var key := str(key_variant)
        var cell: Dictionary = hex_cells[key]
        var area := cell["area"] as Area3D
        if not area:
            continue

        var walkable: bool = bool(cell.get("walkable", false))
        var has_surface: bool = bool(cell.get("has_surface", false))
        var bridge_candidate: bool = nav_debug_mode and (not has_surface) and _is_bridge_repair_candidate(key)
        var visual := area.get_node_or_null("Visual") as MeshInstance3D
        var pick_shape := area.get_node_or_null("PickShape") as CollisionShape3D

        # Reset to the cell's current authoritative position before applying
        # editor-only preview placement for missing bridge cells.
        area.position = cell["position"]

        if bridge_candidate:
            var bridge_height: float = _estimate_bridge_repair_height(key)
            if bridge_height > -INF:
                var preview_position: Vector3 = area.position
                preview_position.y = bridge_height
                area.position = preview_position

        if visual:
            visual.visible = has_surface or bridge_candidate
            var source: String = str(cell.get("nav_source", "auto"))

            if nav_debug_mode and key == nav_selected_hex:
                visual.material_override = hex_material_nav_selected
            elif bridge_candidate:
                visual.material_override = hex_material_bridge_candidate
            elif source == "debug_open" or source == "mask_open":
                visual.material_override = hex_material_forced_open
            elif source == "debug_blocked" or source == "mask_blocked":
                visual.material_override = hex_material_forced_blocked
            elif nav_debug_mode and bool(cell.get("auto_blocked", false)):
                visual.material_override = hex_material_blocked
            elif nav_debug_mode:
                visual.material_override = hex_material_nav_edit
            else:
                visual.material_override = hex_material_idle if walkable else hex_material_blocked

        if pick_shape:
            pick_shape.disabled = not (has_surface or bridge_candidate)

func _build_hex_grid_overlay() -> void:
    if hex_grid_overlay and is_instance_valid(hex_grid_overlay):
        hex_grid_overlay.queue_free()

    hex_grid_overlay = MeshInstance3D.new()
    hex_grid_overlay.name = "HexGridOverlay"
    hex_grid_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    hex_root.add_child(hex_grid_overlay)

    var mesh := ImmediateMesh.new()
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.albedo_color = Color(0.18, 0.78, 0.72, 0.34)
    material.emission_enabled = true
    material.emission = Color(0.10, 0.62, 0.58, 1.0)
    material.emission_energy_multiplier = 0.55

    mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
    for key_variant in hex_cells.keys():
        var key := str(key_variant)
        var overlay_cell: Dictionary = hex_cells[key]
        if not bool(overlay_cell.get("has_surface", false)):
            continue
        var center: Vector3 = overlay_cell["position"] + Vector3(0.0, 0.065, 0.0)
        for i in range(6):
            var a_angle := deg_to_rad(60.0 * float(i))
            var b_angle := deg_to_rad(60.0 * float((i + 1) % 6))
            var a := center + Vector3(cos(a_angle) * HEX_SIZE * 0.93, 0.0, sin(a_angle) * HEX_SIZE * 0.93)
            var b := center + Vector3(cos(b_angle) * HEX_SIZE * 0.93, 0.0, sin(b_angle) * HEX_SIZE * 0.93)
            mesh.surface_add_vertex(a)
            mesh.surface_add_vertex(b)
    mesh.surface_end()

    hex_grid_overlay.mesh = mesh
    hex_grid_overlay.visible = false

func _hex_to_world_2d(q: int, r: int) -> Vector2:
    # Flat-top axial coordinates aligned to the hex pattern baked into Ashenreach.
    var x: float = HEX_SIZE * 1.5 * float(q)
    var z: float = HEX_SIZE * sqrt(3.0) * (float(r) + float(q) * 0.5)
    return Vector2(x, z) + HEX_GRID_OFFSET

func _hex_key(q: int, r: int) -> String:
    return "%d,%d" % [q, r]

func _sample_hex_surface(key: String, x: float, z: float) -> Dictionary:
    # The build-time generator already solved the cleaned navigation height for
    # every supported cell. Read that result directly instead of raycasting the
    # generated mesh and rediscovering the same data at runtime.
    if not nav_grid_tiles.has(key):
        return {
            "has_surface": false
        }

    var tile_variant: Variant = nav_grid_tiles[key]
    if not tile_variant is Dictionary:
        return {
            "has_surface": false
        }

    var tile: Dictionary = tile_variant as Dictionary
    var position := Vector3(
        float(tile.get("x", x)),
        float(tile.get("y", CAMPAIGN_START_POSITION.y)) + HERO_GROUND_CLEARANCE,
        float(tile.get("z", z))
    )

    return {
        "has_surface": true,
        "position": position,
        "up_dot": 1.0,
        "inferred_bridge": bool(tile.get("inferred_bridge", false)),
        "auto_blocked": bool(tile.get("auto_blocked", false))
    }

func _hex_raw_neighbor_count(key: String) -> int:
    if not hex_cells.has(key):
        return 0
    var cell: Dictionary = hex_cells[key]
    var q: int = int(cell["q"])
    var r: int = int(cell["r"])
    var directions := [
        Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
        Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
    ]
    var count := 0
    for d in directions:
        if hex_cells.has(_hex_key(q + d.x, r + d.y)):
            count += 1
    return count

func _hex_neighbors(key: String) -> Array[String]:
    if not _is_hex_walkable(key):
        return []

    var cell: Dictionary = hex_cells[key]
    var q: int = int(cell["q"])
    var r: int = int(cell["r"])
    var directions := [
        Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
        Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
    ]
    var result: Array[String] = []

    for d in directions:
        var neighbor_key := _hex_key(q + d.x, r + d.y)
        if not _is_hex_walkable(neighbor_key):
            continue
        if _is_nav_edge_blocked(key, neighbor_key):
            continue
        result.append(neighbor_key)

    return result

func _is_hex_walkable(key: String) -> bool:
    if key == "" or not hex_cells.has(key):
        return false
    var cell: Dictionary = hex_cells[key]
    return bool(cell.get("walkable", false))

func _canonical_edge_key(a: String, b: String) -> String:
    if a < b:
        return "%s|%s" % [a, b]
    return "%s|%s" % [b, a]

func _is_nav_edge_blocked(a: String, b: String) -> bool:
    return nav_blocked_edges.has(_canonical_edge_key(a, b))

func _nearest_hex_key(world_position: Vector3) -> String:
    var best_key := ""
    var best_distance := INF
    var p := Vector2(world_position.x, world_position.z)
    for key_variant in hex_cells.keys():
        var key: String = str(key_variant)
        var cell: Dictionary = hex_cells[key]
        if not bool(cell.get("walkable", false)):
            continue
        var pos: Vector3 = cell["position"]
        var distance := p.distance_to(Vector2(pos.x, pos.z))
        if distance < best_distance:
            best_distance = distance
            best_key = key
    return best_key

func _snap_hero_to_nearest_hex() -> void:
    if hex_cells.is_empty():
        return
    if not _is_hex_walkable(current_hex_key):
        current_hex_key = _nearest_hex_key(hero_unit.global_position)
    if not _is_hex_walkable(current_hex_key):
        return
    var cell: Dictionary = hex_cells[current_hex_key]
    hero_unit.global_position = cell["position"]

func _hex_reachable(start_key: String, max_steps: int) -> Dictionary:
    var reached := {start_key: 0}
    var frontier: Array[String] = [start_key]

    while not frontier.is_empty():
        var current: String = frontier.pop_front()
        var depth: int = int(reached[current])
        if depth >= max_steps:
            continue
        for neighbor in _hex_neighbors(current):
            if reached.has(neighbor):
                continue
            reached[neighbor] = depth + 1
            frontier.append(neighbor)
    return reached

func _show_reachable_hexes() -> void:
    _clear_hex_highlights()
    if current_hex_key == "":
        current_hex_key = _nearest_hex_key(hero_unit.global_position)
    var reachable := _hex_reachable(current_hex_key, moves_remaining)
    for key_variant in reachable.keys():
        var key: String = str(key_variant)
        if not hex_cells.has(key):
            continue
        var cell: Dictionary = hex_cells[key]
        var area := cell["area"] as Area3D
        var visual := area.get_node_or_null("Visual") as MeshInstance3D
        if not visual:
            continue
        if key == current_hex_key:
            visual.material_override = hex_material_current
        else:
            visual.material_override = hex_material_reachable

    var walkable_count := 0
    for cell_variant in hex_cells.values():
        var cell: Dictionary = cell_variant
        if bool(cell.get("walkable", false)):
            walkable_count += 1

    var inferred_count := 0
    var hazard_count := 0
    for cell_variant in hex_cells.values():
        var nav_cell: Dictionary = cell_variant
        if bool(nav_cell.get("inferred_bridge", false)):
            inferred_count += 1
        if bool(nav_cell.get("auto_blocked", false)):
            hazard_count += 1

    status_label.text = "Grid %d • Nav %d • Open %d • Bridge+ %d • Hazard %d • Reach %d • AP %d" % [
        hex_cells.size(),
        nav_grid_tiles.size(),
        walkable_count,
        inferred_count,
        hazard_count,
        maxi(0, reachable.size() - 1),
        moves_remaining
    ]

func _clear_hex_highlights() -> void:
    _apply_hex_classification_visuals()

func _select_hex_destination(area: Area3D) -> void:
    if campaign_phase != PHASE_PLAYER or moves_remaining <= 0:
        return
    var key: String = str(area.get_meta("hex_key", ""))
    if key == "" or key == current_hex_key:
        return
    if not hex_cells.has(key) or not bool(hex_cells[key].get("walkable", false)):
        return
    var reachable := _hex_reachable(current_hex_key, moves_remaining)
    if not reachable.has(key):
        return

    pending_hex_path = _shortest_hex_path(current_hex_key, key)
    if pending_hex_path.size() < 2:
        return

    pending_hex_key = key
    pending_move_cost = pending_hex_path.size() - 1
    movement_stats.text = "Destination hex: %s\nMovement cost: %d / %d remaining" % [
        key, pending_move_cost, moves_remaining
    ]
    movement_confirm.disabled = false
    _show_hex_route_preview(pending_hex_path)

    var target_cell: Dictionary = hex_cells[key]
    var target_area := target_cell["area"] as Area3D
    var target_visual := target_area.get_node_or_null("Visual") as MeshInstance3D
    if target_visual:
        target_visual.material_override = hex_material_target

func _shortest_hex_path(start_key: String, goal_key: String) -> Array[String]:
    var frontier: Array[String] = [start_key]
    var came_from := {start_key: ""}

    while not frontier.is_empty():
        var current: String = frontier.pop_front()
        if current == goal_key:
            break
        for neighbor in _hex_neighbors(current):
            if came_from.has(neighbor):
                continue
            came_from[neighbor] = current
            frontier.append(neighbor)

    if not came_from.has(goal_key):
        return []

    var path: Array[String] = [goal_key]
    var cursor: String = str(came_from[goal_key])
    while cursor != "":
        path.push_front(cursor)
        cursor = str(came_from[cursor])
    return path

func _show_hex_route_preview(path: Array[String]) -> void:
    if not route_preview or path.size() < 2:
        return
    var mesh := ImmediateMesh.new()
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.albedo_color = Color(0.10, 0.78, 0.68, 0.62)
    material.emission_enabled = true
    material.emission = Color(0.06, 0.88, 0.72, 1.0)
    material.emission_energy_multiplier = 0.8
    mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)

    for i in range(path.size() - 1):
        var a: Vector3 = hex_cells[path[i]]["position"] + Vector3(0.0, 0.08, 0.0)
        var b: Vector3 = hex_cells[path[i + 1]]["position"] + Vector3(0.0, 0.08, 0.0)
        mesh.surface_add_vertex(a)
        mesh.surface_add_vertex(b)

    mesh.surface_end()
    route_preview.mesh = mesh
    route_preview.visible = true

func _confirm_hex_move() -> void:
    if campaign_phase != PHASE_PLAYER or pending_hex_path.size() < 2:
        return

    movement_confirm.disabled = true
    movement_stats.text = "Moving..."
    _clear_hex_highlights()
    _hide_route_preview()

    for i in range(1, pending_hex_path.size()):
        var key: String = pending_hex_path[i]
        var target: Vector3 = hex_cells[key]["position"]
        var tween := create_tween()
        tween.set_trans(Tween.TRANS_SINE)
        tween.set_ease(Tween.EASE_IN_OUT)
        tween.tween_property(hero_unit, "global_position", target, 0.22)
        await tween.finished

    var spent_ap := pending_move_cost
    moves_remaining = maxi(0, moves_remaining - spent_ap)
    current_hex_key = pending_hex_key
    pending_hex_key = ""
    pending_hex_path.clear()
    pending_move_cost = 0
    unit_selected = false
    hero_label.visible = false
    movement_panel.visible = false
    if hex_grid_overlay:
        hex_grid_overlay.visible = false

    _refresh_fog_reveal()
    _reveal_nearby_pois()
    _refresh_poi_visibility()
    _refresh_enemy_visibility()
    _resolve_hex_contact()
    status_label.text = "Moved %d tile%s • %d AP remaining" % [
        spent_ap,
        "" if spent_ap == 1 else "s",
        moves_remaining
    ]
    _refresh_game_hud()
    _save_game_state()

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

func _cancel_unit_move() -> void:
    _hide_route_preview()
    _clear_hex_highlights()
    pending_hex_key = ""
    pending_hex_path.clear()
    unit_selected = false
    movement_panel.visible = false
    hero_label.visible = false
    if hex_grid_overlay:
        hex_grid_overlay.visible = false

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

    end_turn_button = Button.new()
    end_turn_button.text = "End Turn"
    end_turn_button.custom_minimum_size = Vector2(122, 38)
    end_turn_button.pressed.connect(_end_turn)
    actions.add_child(end_turn_button)

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

    nav_debug_button = Button.new()
    nav_debug_button.text = "NAV EDIT: OFF"
    nav_debug_button.custom_minimum_size = Vector2(0, 36)
    nav_debug_button.visible = false
    nav_debug_button.pressed.connect(_toggle_nav_debug)
    box.add_child(nav_debug_button)

    event_log_label = Label.new()
    event_log_label.text = "Ashenreach expedition begun."
    event_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    event_log_label.add_theme_font_size_override("font_size", 11)
    event_log_label.visible = false
    box.add_child(event_log_label)

    _build_encounter_panel()
    _build_nav_edit_panel()

func _toggle_hud_details() -> void:
    hud_expanded = not hud_expanded
    if objective_label:
        objective_label.visible = hud_expanded
    if event_log_label:
        event_log_label.visible = hud_expanded
    if restart_button:
        restart_button.visible = hud_expanded
    if nav_debug_button:
        nav_debug_button.visible = hud_expanded
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
    var phase_text := campaign_phase.capitalize()
    turn_label.text = "TURN %d  •  %s PHASE  •  AP %d/%d" % [turn_number, phase_text, moves_remaining, hero_move_points]
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
        ability_button.disabled = signature_ability_used or campaign_phase != PHASE_PLAYER
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
    if end_turn_button:
        end_turn_button.disabled = campaign_phase != PHASE_PLAYER
        if campaign_phase == PHASE_ENEMY:
            end_turn_button.text = "Enemy Phase"
        elif campaign_phase == PHASE_WORLD:
            end_turn_button.text = "World Phase"
        elif moves_remaining <= 0:
            end_turn_button.text = "End Turn • Ready"
        else:
            end_turn_button.text = "End Turn"
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
    if campaign_phase != PHASE_PLAYER or signature_ability_used:
        return
    signature_ability_used = true
    signature_ability_primed = true
    var ability_name: String = str(hero_catalog.get(selected_hero_id, {}).get("signature_ability", "Signature Ability"))
    event_log_label.text = "%s primed for the next encounter." % ability_name
    _refresh_game_hud()
    _save_game_state()

func _end_turn() -> void:
    if campaign_phase != PHASE_PLAYER:
        return
    if encounter_panel and encounter_panel.visible:
        return
    _cancel_unit_move()
    campaign_phase = PHASE_ENEMY
    last_enemy_phase_summary = ""
    _refresh_game_hud()
    await _run_enemy_phase()

    campaign_phase = PHASE_WORLD
    _refresh_game_hud()
    await get_tree().create_timer(0.35).timeout
    _resolve_world_phase()

    if hero_health <= 0:
        _handle_hero_defeat()
        return

    turn_number += 1
    moves_remaining = hero_move_points
    signature_ability_used = false
    signature_ability_primed = false
    campaign_phase = PHASE_PLAYER

    if claimed_pois.has("CapitalRuins") and _hero_near_named_poi("CapitalRuins", 4.0):
        hero_health = mini(100, hero_health + 10)

    if last_enemy_phase_summary != "":
        event_log_label.text = "Turn %d • %s" % [turn_number, last_enemy_phase_summary]
    else:
        event_log_label.text = "Turn %d begins. Choose how to spend your %d action points." % [turn_number, hero_move_points]

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
    float wave_a = sin((UV.x * 17.0) + (UV.y * 11.0));
    float wave_b = sin((UV.x * 7.0) - (UV.y * 19.0));
    float center_texture = 0.88 + 0.08 * wave_a + 0.04 * wave_b;
    ALBEDO = vec3(0.01, 0.014, 0.018);
    ALPHA = soft_edge * 0.48 * center_texture;
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
        if not ENCOUNTER_START_POSITIONS.has(node_name):
            continue

        var data: Dictionary = encounters[node_name]
        var piece := Node3D.new()
        piece.name = "Enemy_%s" % node_name
        enemy_root.add_child(piece)
        piece.global_position = ENCOUNTER_START_POSITIONS[node_name]

        var material := StandardMaterial3D.new()
        material.albedo_color = Color(0.17, 0.055, 0.035, 1.0)
        material.emission_enabled = true
        material.emission = Color(0.48, 0.07, 0.025, 1.0)
        material.emission_energy_multiplier = 0.48
        material.roughness = 0.86

        var body := MeshInstance3D.new()
        var body_mesh := SphereMesh.new()
        body_mesh.radius = 0.36
        body_mesh.height = 0.72
        body_mesh.radial_segments = 12
        body_mesh.rings = 6
        body.mesh = body_mesh
        body.scale = Vector3(1.25, 0.78, 1.65)
        body.position = Vector3(0.0, 0.38, 0.0)
        body.material_override = material
        piece.add_child(body)

        var head := MeshInstance3D.new()
        var head_mesh := SphereMesh.new()
        head_mesh.radius = 0.20
        head_mesh.height = 0.40
        head_mesh.radial_segments = 10
        head_mesh.rings = 5
        head.mesh = head_mesh
        head.position = Vector3(0.0, 0.58, -0.46)
        head.material_override = material
        piece.add_child(head)

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
        ring_material.albedo_color = Color(0.72, 0.10, 0.035, 0.42)
        ring_material.emission_enabled = true
        ring_material.emission = Color(0.72, 0.09, 0.025, 1.0)
        ring_material.emission_energy_multiplier = 0.75
        ring.material_override = ring_material
        piece.add_child(ring)

        var label := Label3D.new()
        label.text = str(data.get("name", "Threat"))
        label.font_size = 14
        label.pixel_size = 0.012
        label.position = Vector3(0.0, 1.22, 0.0)
        label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        label.no_depth_test = true
        piece.add_child(label)

        await get_tree().process_frame
        _snap_visual_children_to_ground(piece, 0.0)
        if not hex_cells.is_empty():
            var enemy_hex := str(enemy_hex_positions.get(node_name, ""))
            if enemy_hex == "" or not hex_cells.has(enemy_hex):
                enemy_hex = _nearest_hex_key(piece.global_position)
            if enemy_hex != "" and hex_cells.has(enemy_hex):
                enemy_hex_positions[node_name] = enemy_hex
                piece.global_position = hex_cells[enemy_hex]["position"]
        enemy_pieces[node_name] = piece

    _refresh_enemy_visibility()

func _snap_visual_children_to_ground(root: Node3D, target_y: float = 0.02) -> void:
    var visual_nodes: Array[Node3D] = []
    for child in root.get_children():
        if child is MeshInstance3D and child.name != "BaseRing":
            visual_nodes.append(child as Node3D)

    if visual_nodes.is_empty():
        return

    var lowest: float = INF
    for visual in visual_nodes:
        lowest = _lowest_mesh_y_in_parent(visual, root, lowest)

    if lowest >= INF:
        return

    var shift: float = target_y - lowest
    for visual in visual_nodes:
        visual.position.y += shift

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
        piece.visible = hero_flat.distance_to(enemy_flat) <= visibility_radius or str(enemy_hex_positions.get(node_name, "")) == current_hex_key

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
    current_hex_key = _nearest_hex_key(CAMPAIGN_START_POSITION)
    if current_hex_key != "" and hex_cells.has(current_hex_key):
        hero_unit.global_position = hex_cells[current_hex_key]["position"]
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
    pending_move_cost = 0
    _hide_route_preview()
    discovered_pois.clear()
    claimed_pois.clear()
    completed_encounters.clear()
    revealed_fog_cells.clear()
    if FileAccess.file_exists("user://sundered_vault_save.cfg"):
        DirAccess.remove_absolute(ProjectSettings.globalize_path("user://sundered_vault_save.cfg"))

    current_hex_key = _nearest_hex_key(CAMPAIGN_START_POSITION)
    if current_hex_key != "" and hex_cells.has(current_hex_key):
        hero_unit.global_position = hex_cells[current_hex_key]["position"]

    _refresh_enemy_board()
    _refresh_fog_reveal()
    _reveal_nearby_pois()
    _refresh_poi_visibility()
    _refresh_enemy_visibility()
    event_log_label.text = "A new Ashenreach expedition has begun."
    _refresh_game_hud()
    _save_game_state()
    reset_camera()

func _restore_hex_state() -> void:
    if hex_cells.is_empty():
        return
    if not _is_hex_walkable(current_hex_key):
        current_hex_key = _nearest_hex_key(hero_unit.global_position)
    if _is_hex_walkable(current_hex_key):
        hero_unit.global_position = hex_cells[current_hex_key]["position"]

func _hero_near_named_poi(poi_name: String, radius: float) -> bool:
    var poi := $POIs.get_node_or_null(poi_name) as Node3D
    if not poi:
        return false
    var hero_flat := Vector2(hero_unit.global_position.x, hero_unit.global_position.z)
    var poi_flat := Vector2(poi.global_position.x, poi.global_position.z)
    return hero_flat.distance_to(poi_flat) <= radius

func _resolve_hex_contact() -> void:
    if current_hex_key == "":
        return
    for encounter_variant in enemy_hex_positions.keys():
        var encounter_id := str(encounter_variant)
        if completed_encounters.has(encounter_id):
            continue
        if str(enemy_hex_positions.get(encounter_id, "")) == current_hex_key:
            _trigger_node_encounter(encounter_id)
            return

func _run_enemy_phase() -> void:
    if enemy_pieces.is_empty() or current_hex_key == "":
        last_enemy_phase_summary = "No enemy forces acted."
        await get_tree().create_timer(0.25).timeout
        return

    var attacks := 0
    var total_damage := 0
    var occupied: Dictionary = {}
    for id_variant in enemy_hex_positions.keys():
        var id := str(id_variant)
        if not completed_encounters.has(id):
            occupied[str(enemy_hex_positions[id])] = id

    var enemy_ids: Array[String] = []
    for id_variant in enemy_pieces.keys():
        enemy_ids.append(str(id_variant))
    enemy_ids.sort()

    for enemy_id in enemy_ids:
        if completed_encounters.has(enemy_id):
            continue
        var piece := enemy_pieces.get(enemy_id) as Node3D
        if not piece or not is_instance_valid(piece):
            continue
        var enemy_hex := str(enemy_hex_positions.get(enemy_id, ""))
        if enemy_hex == "" or not hex_cells.has(enemy_hex):
            enemy_hex = _nearest_hex_key(piece.global_position)
        if enemy_hex == "":
            continue

        if current_hex_key in _hex_neighbors(enemy_hex) or enemy_hex == current_hex_key:
            var damage := _enemy_campaign_damage(enemy_id)
            hero_health = maxi(0, hero_health - damage)
            attacks += 1
            total_damage += damage
            await _enemy_attack_bump(piece)
            if hero_health <= 0:
                break
            continue

        var path := _shortest_hex_path(enemy_hex, current_hex_key)
        if path.size() >= 2:
            var next_hex := path[1]
            if not occupied.has(next_hex) and next_hex != current_hex_key:
                occupied.erase(enemy_hex)
                occupied[next_hex] = enemy_id
                enemy_hex_positions[enemy_id] = next_hex
                var tween := create_tween()
                tween.set_trans(Tween.TRANS_SINE)
                tween.set_ease(Tween.EASE_IN_OUT)
                tween.tween_property(piece, "global_position", hex_cells[next_hex]["position"], 0.24)
                await tween.finished
                enemy_hex = next_hex

        if current_hex_key in _hex_neighbors(enemy_hex):
            var damage_after_move := _enemy_campaign_damage(enemy_id)
            hero_health = maxi(0, hero_health - damage_after_move)
            attacks += 1
            total_damage += damage_after_move
            await _enemy_attack_bump(piece)
            if hero_health <= 0:
                break

    if attacks > 0:
        last_enemy_phase_summary = "Enemy phase: %d attack%s dealt %d damage." % [attacks, "" if attacks == 1 else "s", total_damage]
    else:
        last_enemy_phase_summary = "Enemy forces repositioned across Ashenreach."
    _refresh_enemy_visibility()
    _refresh_game_hud()

func _enemy_campaign_damage(enemy_id: String) -> int:
    var encounters: Dictionary = board_data.get("encounters", {})
    var data: Dictionary = encounters.get(enemy_id, {})
    var danger := int(data.get("danger", 1))
    var base_loss := int(data.get("health_loss", 10))
    return clampi(int(round(float(base_loss) * 0.35)) + danger, 4, 14)

func _enemy_attack_bump(piece: Node3D) -> void:
    var start := piece.global_position
    var direction := hero_unit.global_position - start
    direction.y = 0.0
    if direction.length() < 0.01:
        direction = Vector3(0.0, 0.0, -1.0)
    direction = direction.normalized()
    var tween := create_tween()
    tween.tween_property(piece, "global_position", start + direction * 0.35, 0.10)
    tween.tween_property(piece, "global_position", start, 0.12)
    await tween.finished

func _resolve_world_phase() -> void:
    var threat: Dictionary = board_data.get("legendary_threat", {})
    var escalation: int = int(threat.get("escalation_per_turn", 5))
    if claimed_pois.has("RitualTotems"):
        escalation = maxi(1, escalation - 2)
    vulgrim_heat = mini(int(threat.get("max_heat", 100)), vulgrim_heat + escalation)
    if vulgrim_heat >= 100:
        vulgrim_available = true
        last_enemy_phase_summary += " Vulgrim has awakened."
    elif vulgrim_heat >= 75:
        last_enemy_phase_summary += " Vulgrim's eruption pressure is critical."
    elif vulgrim_heat >= 50:
        last_enemy_phase_summary += " The wastes become increasingly unstable."

func _load_generated_nav_grid() -> void:
    nav_grid_data.clear()
    nav_grid_tiles.clear()

    var path := "res://data/generated/ashenreach_nav_grid.json"
    if not FileAccess.file_exists(path):
        push_error("Ashenreach nav grid data is missing: %s" % path)
        return

    var file := FileAccess.open(path, FileAccess.READ)
    if not file:
        push_error("Unable to open Ashenreach nav grid data.")
        return

    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        push_error("Ashenreach nav grid data is invalid JSON.")
        return

    nav_grid_data = (parsed as Dictionary).duplicate(true)
    var tiles_variant: Variant = nav_grid_data.get("tiles", {})
    if tiles_variant is Dictionary:
        nav_grid_tiles = (tiles_variant as Dictionary).duplicate(true)

    if nav_grid_tiles.is_empty():
        push_error("Ashenreach nav grid contains no tiles.")

func _load_nav_mask_data() -> void:
    nav_mask_data = {
        "blocked_hexes": [],
        "forced_open_hexes": [],
        "blocked_regions": [],
        "forced_open_regions": [],
        "blocked_edges": []
    }
    if not FileAccess.file_exists("res://data/ashenreach_nav_mask.json"):
        return
    var file := FileAccess.open("res://data/ashenreach_nav_mask.json", FileAccess.READ)
    var parsed = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        nav_mask_data = parsed
    _rebuild_nav_edge_cache()

func _rebuild_nav_edge_cache() -> void:
    nav_blocked_edges.clear()
    for raw_edge in nav_mask_data.get("blocked_edges", []):
        if raw_edge is Array and raw_edge.size() >= 2:
            var a := str(raw_edge[0])
            var b := str(raw_edge[1])
            nav_blocked_edges[_canonical_edge_key(a, b)] = true
        elif raw_edge is String:
            var edge_text := str(raw_edge)
            var parts := edge_text.split("|", false, 1)
            if parts.size() == 2:
                nav_blocked_edges[_canonical_edge_key(parts[0], parts[1])] = true

func _load_nav_debug_overrides() -> void:
    nav_debug_forced_open.clear()
    nav_debug_forced_blocked.clear()

    var cfg := ConfigFile.new()
    if cfg.load("user://ashenreach_nav_debug.cfg") != OK:
        return

    var saved_grid_version: int = int(cfg.get_value("nav", "hex_grid_version", -1))
    if saved_grid_version != HEX_GRID_VERSION:
        return

    for key_variant in cfg.get_value("nav", "forced_open", []):
        nav_debug_forced_open[str(key_variant)] = true
    for key_variant in cfg.get_value("nav", "forced_blocked", []):
        nav_debug_forced_blocked[str(key_variant)] = true

func _save_nav_debug_overrides() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("nav", "hex_grid_version", HEX_GRID_VERSION)
    cfg.set_value("nav", "forced_open", nav_debug_forced_open.keys())
    cfg.set_value("nav", "forced_blocked", nav_debug_forced_blocked.keys())
    cfg.save("user://ashenreach_nav_debug.cfg")

func _apply_nav_mask_overrides() -> void:
    for key_variant in hex_cells.keys():
        var key := str(key_variant)
        var cell: Dictionary = hex_cells[key]

        var generated_has_surface: bool = bool(cell.get("generated_has_surface", cell.get("has_surface", false)))
        var generated_position: Vector3 = cell.get("generated_position", cell["position"]) as Vector3
        var generated_height: float = float(cell.get("generated_height", generated_position.y))

        cell["has_surface"] = generated_has_surface
        cell["position"] = generated_position
        cell["height"] = generated_height
        cell["bridge_override"] = false
        cell["walkable"] = bool(cell.get("auto_walkable", false))
        cell["nav_source"] = "auto"

        var area := cell["area"] as Area3D
        if area:
            area.position = generated_position

        hex_cells[key] = cell

    for key_variant in nav_mask_data.get("blocked_hexes", []):
        _set_hex_mask_state(str(key_variant), false, "mask_blocked")
    for key_variant in nav_mask_data.get("forced_open_hexes", []):
        _set_hex_mask_state(str(key_variant), true, "mask_open")

    for raw_region in nav_mask_data.get("blocked_regions", []):
        if raw_region is Dictionary:
            _apply_nav_circle_region(raw_region, false, "mask_blocked")
    for raw_region in nav_mask_data.get("forced_open_regions", []):
        if raw_region is Dictionary:
            _apply_nav_circle_region(raw_region, true, "mask_open")

    for key_variant in nav_debug_forced_blocked.keys():
        _set_hex_mask_state(str(key_variant), false, "debug_blocked")
    for key_variant in nav_debug_forced_open.keys():
        _set_hex_mask_state(str(key_variant), true, "debug_open")

func _set_hex_mask_state(key: String, walkable: bool, source: String) -> void:
    if not hex_cells.has(key):
        return

    if walkable:
        var open_cell: Dictionary = hex_cells[key]
        if not bool(open_cell.get("has_surface", false)):
            if not _prepare_bridge_override(key):
                return

    var cell: Dictionary = hex_cells[key]
    cell["walkable"] = walkable
    cell["nav_source"] = source
    cell["blocked_reason"] = "" if walkable else source
    hex_cells[key] = cell

func _apply_nav_circle_region(region: Dictionary, walkable: bool, source: String) -> void:
    var center_raw = region.get("center", [])
    if not (center_raw is Array) or center_raw.size() < 2:
        return
    var center := Vector2(float(center_raw[0]), float(center_raw[1]))
    var radius: float = float(region.get("radius", 0.0))
    if radius <= 0.0:
        return

    for key_variant in hex_cells.keys():
        var key := str(key_variant)
        var cell: Dictionary = hex_cells[key]
        var pos: Vector3 = cell["position"]
        if Vector2(pos.x, pos.z).distance_to(center) <= radius:
            _set_hex_mask_state(key, walkable, source)

func _build_nav_edit_panel() -> void:
    nav_edit_panel = PanelContainer.new()
    nav_edit_panel.name = "NavEditPanel"
    nav_edit_panel.anchor_left = 0.5
    nav_edit_panel.anchor_top = 1.0
    nav_edit_panel.anchor_right = 0.5
    nav_edit_panel.anchor_bottom = 1.0
    nav_edit_panel.offset_left = -220.0
    nav_edit_panel.offset_top = -190.0
    nav_edit_panel.offset_right = 220.0
    nav_edit_panel.offset_bottom = -34.0
    nav_edit_panel.visible = false
    ui_root.add_child(nav_edit_panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 12)
    margin.add_theme_constant_override("margin_top", 10)
    margin.add_theme_constant_override("margin_right", 12)
    margin.add_theme_constant_override("margin_bottom", 10)
    nav_edit_panel.add_child(margin)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 7)
    margin.add_child(box)

    var title := Label.new()
    title.text = "NAVIGATION TILE EDITOR"
    title.add_theme_font_size_override("font_size", 15)
    box.add_child(title)

    nav_edit_info = Label.new()
    nav_edit_info.text = "Tap a hex on the board."
    nav_edit_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    box.add_child(nav_edit_info)

    var actions := HBoxContainer.new()
    actions.add_theme_constant_override("separation", 6)
    box.add_child(actions)

    var auto_button := Button.new()
    auto_button.text = "AUTO"
    auto_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    auto_button.pressed.connect(func(): _nav_set_selected_state("auto"))
    actions.add_child(auto_button)

    var open_button := Button.new()
    open_button.text = "OPEN"
    open_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    open_button.pressed.connect(func(): _nav_set_selected_state("open"))
    actions.add_child(open_button)

    var block_button := Button.new()
    block_button.text = "BLOCK"
    block_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    block_button.pressed.connect(func(): _nav_set_selected_state("blocked"))
    actions.add_child(block_button)

    var bridge_button := Button.new()
    bridge_button.text = "BRIDGE"
    bridge_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bridge_button.pressed.connect(_nav_repair_selected_bridge)
    actions.add_child(bridge_button)

func _try_select_nav_hex(screen_position: Vector2) -> void:
    var origin: Vector3 = camera.project_ray_origin(screen_position)
    var ray_end: Vector3 = origin + camera.project_ray_normal(screen_position) * 200.0
    var query := PhysicsRayQueryParameters3D.create(origin, ray_end)
    query.collide_with_areas = true
    query.collide_with_bodies = false
    query.collision_mask = 2

    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        status_label.text = "NAV EDIT: no hex under tap."
        return

    var collider = hit.get("collider")
    if not collider or not collider.is_in_group("hex_cell"):
        status_label.text = "NAV EDIT: no editable hex under tap."
        return

    _nav_select_hex(collider)

func _nav_select_hex(area: Area3D) -> void:
    var key := str(area.get_meta("hex_key", ""))
    if key == "" or not hex_cells.has(key):
        return
    nav_selected_hex = key
    _apply_hex_classification_visuals()
    _refresh_nav_edit_panel()

func _is_bridge_repair_candidate(key: String) -> bool:
    if not hex_cells.has(key):
        return false
    var cell: Dictionary = hex_cells[key]
    if bool(cell.get("has_surface", false)):
        return false

    var q: int = int(cell["q"])
    var r: int = int(cell["r"])
    var opposite_pairs := [
        [Vector2i(1, 0), Vector2i(-1, 0)],
        [Vector2i(1, -1), Vector2i(-1, 1)],
        [Vector2i(0, -1), Vector2i(0, 1)]
    ]

    for pair_variant in opposite_pairs:
        var pair: Array = pair_variant
        var a: Vector2i = pair[0]
        var b: Vector2i = pair[1]
        var a_key := _hex_key(q + a.x, r + a.y)
        var b_key := _hex_key(q + b.x, r + b.y)
        if not hex_cells.has(a_key) or not hex_cells.has(b_key):
            continue

        var a_cell: Dictionary = hex_cells[a_key]
        var b_cell: Dictionary = hex_cells[b_key]
        if not bool(a_cell.get("has_surface", false)) or not bool(b_cell.get("has_surface", false)):
            continue

        var height_delta: float = absf(float(a_cell["height"]) - float(b_cell["height"]))
        if height_delta <= 1.10:
            return true

    return false

func _estimate_bridge_repair_height(key: String) -> float:
    if not hex_cells.has(key):
        return -INF

    var cell: Dictionary = hex_cells[key]
    var q: int = int(cell["q"])
    var r: int = int(cell["r"])
    var opposite_pairs := [
        [Vector2i(1, 0), Vector2i(-1, 0)],
        [Vector2i(1, -1), Vector2i(-1, 1)],
        [Vector2i(0, -1), Vector2i(0, 1)]
    ]

    var best_height := -INF
    var best_delta := INF

    for pair_variant in opposite_pairs:
        var pair: Array = pair_variant
        var a: Vector2i = pair[0]
        var b: Vector2i = pair[1]
        var a_key := _hex_key(q + a.x, r + a.y)
        var b_key := _hex_key(q + b.x, r + b.y)
        if not hex_cells.has(a_key) or not hex_cells.has(b_key):
            continue

        var a_cell: Dictionary = hex_cells[a_key]
        var b_cell: Dictionary = hex_cells[b_key]
        if not bool(a_cell.get("has_surface", false)) or not bool(b_cell.get("has_surface", false)):
            continue

        var a_height: float = float(a_cell["height"])
        var b_height: float = float(b_cell["height"])
        var delta: float = absf(a_height - b_height)
        if delta <= 1.10 and delta < best_delta:
            best_delta = delta
            best_height = (a_height + b_height) * 0.5

    return best_height

func _prepare_bridge_override(key: String) -> bool:
    if not _is_bridge_repair_candidate(key):
        return false

    var bridge_height: float = _estimate_bridge_repair_height(key)
    if bridge_height <= -INF:
        return false

    var cell: Dictionary = hex_cells[key]
    var pos: Vector3 = cell["position"]
    pos.y = bridge_height

    cell["has_surface"] = true
    cell["walkable"] = true
    cell["position"] = pos
    cell["height"] = bridge_height
    cell["bridge_override"] = true
    cell["inferred_bridge"] = true
    cell["blocked_reason"] = ""
    hex_cells[key] = cell

    var area := cell["area"] as Area3D
    if area:
        area.position = pos

    return true

func _nav_repair_selected_bridge() -> void:
    if nav_selected_hex == "" or not hex_cells.has(nav_selected_hex):
        return

    if not _prepare_bridge_override(nav_selected_hex):
        status_label.text = "BRIDGE: selected gap does not have matching supported tiles on opposite sides."
        return

    nav_debug_forced_blocked.erase(nav_selected_hex)
    nav_debug_forced_open[nav_selected_hex] = true

    _apply_nav_mask_overrides()
    _apply_hex_classification_visuals()
    _save_nav_debug_overrides()
    _refresh_nav_edit_panel()

func _nav_set_selected_state(state: String) -> void:
    if nav_selected_hex == "" or not hex_cells.has(nav_selected_hex):
        return

    nav_debug_forced_open.erase(nav_selected_hex)
    nav_debug_forced_blocked.erase(nav_selected_hex)

    if state == "open":
        nav_debug_forced_open[nav_selected_hex] = true
    elif state == "blocked":
        nav_debug_forced_blocked[nav_selected_hex] = true

    _apply_nav_mask_overrides()
    _apply_hex_classification_visuals()
    _save_nav_debug_overrides()
    _refresh_nav_edit_panel()

func _refresh_nav_edit_panel() -> void:
    if not nav_edit_panel or not nav_edit_info:
        return

    nav_edit_panel.visible = nav_debug_mode
    if nav_selected_hex == "" or not hex_cells.has(nav_selected_hex):
        nav_edit_info.text = "Tap a tile. Purple gaps are bridge-repair candidates. Use AUTO, OPEN, BLOCK, or BRIDGE."
        return

    var cell: Dictionary = hex_cells[nav_selected_hex]
    var state := "AUTO"
    if nav_debug_forced_open.has(nav_selected_hex):
        state = "FORCED OPEN"
    elif nav_debug_forced_blocked.has(nav_selected_hex):
        state = "BLOCKED"
    elif str(cell.get("nav_source", "auto")) == "mask_open":
        state = "MASK OPEN"
    elif str(cell.get("nav_source", "auto")) == "mask_blocked":
        state = "MASK BLOCKED"
    elif bool(cell.get("auto_blocked", false)):
        state = "AUTO HAZARD"

    var repair_candidate: bool = _is_bridge_repair_candidate(nav_selected_hex)
    nav_edit_info.text = "Hex %s  •  %s  •  Y %.2f\nBridge: %s  •  Surface: %s" % [
        nav_selected_hex,
        state,
        float(cell.get("height", 0.0)),
        "REPAIRABLE" if repair_candidate else ("yes" if bool(cell.get("inferred_bridge", false)) else "no"),
        "yes" if bool(cell.get("has_surface", false)) else "missing"
    ]
    status_label.text = "NAV %s • %s" % [nav_selected_hex, state]

func _toggle_nav_debug() -> void:
    nav_debug_mode = not nav_debug_mode
    _cancel_unit_move()

    hero_unit.visible = not nav_debug_mode
    movement_panel.visible = false
    hero_label.visible = false

    if hex_grid_overlay:
        hex_grid_overlay.visible = nav_debug_mode
    if nav_debug_button:
        nav_debug_button.text = "NAV EDIT: ON" if nav_debug_mode else "NAV EDIT: OFF"

    if not nav_debug_mode:
        nav_selected_hex = ""
        status_label.text = "Navigation edit closed."
    else:
        status_label.text = "NAV EDIT: cyan=normal, red=blocked, green=open, purple=bridge gap. Tap a tile to edit."

    _apply_hex_classification_visuals()
    _refresh_nav_edit_panel()

func _nav_debug_cycle_hex(area: Area3D) -> void:
    var key := str(area.get_meta("hex_key", ""))
    if key == "" or not hex_cells.has(key):
        return

    var state := ""
    if nav_debug_forced_blocked.has(key):
        nav_debug_forced_blocked.erase(key)
        nav_debug_forced_open[key] = true
        state = "FORCED OPEN"
    elif nav_debug_forced_open.has(key):
        nav_debug_forced_open.erase(key)
        state = "AUTO"
    else:
        nav_debug_forced_blocked[key] = true
        state = "BLOCKED"

    _apply_nav_mask_overrides()
    _apply_hex_classification_visuals()
    _save_nav_debug_overrides()

    var cell: Dictionary = hex_cells[key]
    status_label.text = "NAV %s • %s • height %.2f" % [key, state, float(cell["height"])]

func _save_game_state() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("board", "turn", turn_number)
    cfg.set_value("board", "moves_remaining", moves_remaining)
    cfg.set_value("board", "hex_grid_version", HEX_GRID_VERSION)
    cfg.set_value("board", "current_hex_key", current_hex_key)
    cfg.set_value("board", "campaign_phase", campaign_phase)
    cfg.set_value("board", "enemy_hex_positions", enemy_hex_positions)
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

    var saved_grid_version: int = int(cfg.get_value("board", "hex_grid_version", 0))
    if saved_grid_version == HEX_GRID_VERSION:
        current_hex_key = str(cfg.get_value("board", "current_hex_key", ""))
        var saved_enemy_positions = cfg.get_value("board", "enemy_hex_positions", {})
        if saved_enemy_positions is Dictionary:
            enemy_hex_positions = saved_enemy_positions.duplicate(true)
    else:
        # Grid coordinates changed. Preserve campaign progress but migrate all
        # board pieces onto the current terrain grid instead of reusing stale q/r.
        current_hex_key = ""
        enemy_hex_positions.clear()

    campaign_phase = str(cfg.get_value("board", "campaign_phase", PHASE_PLAYER))
    if campaign_phase != PHASE_PLAYER:
        campaign_phase = PHASE_PLAYER
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
        if campaign_phase != PHASE_PLAYER:
            poi_body.text += "\n\nWait for your player phase."
            return
        if moves_remaining <= 0:
            poi_body.text += "\n\nYou need 1 action point to secure this location."
            return
        var poi_node := $POIs.get_node_or_null(selected_poi) as Node3D
        if not poi_node or not _hero_near_poi(poi_node):
            poi_body.text += "\n\nMove the hero onto this location before claiming it."
            return
        claimed_pois[selected_poi] = true
        moves_remaining = maxi(0, moves_remaining - 1)
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
        if not _hero_near_named_poi("SunderedVault", 2.8):
            poi_body.text = "The Sundered Vault has been discovered. Move your hero onto the vault entrance before entering."
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
