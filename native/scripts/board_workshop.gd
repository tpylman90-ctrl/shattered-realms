extends Node3D

const BOARD_SCRIPT := preload("res://scripts/board_definition.gd")
const GRID_PATH := "res://data/generated/ravenwood_nav_grid.json"
const NAV_COLLISION_LAYER := 2
const HEX_RADIUS := 0.35
const TERRAIN_COLORS := {
    "forest": Color(0.14, 0.39, 0.24, 0.34),
    "clearing": Color(0.76, 0.68, 0.43, 0.34),
    "trail": Color(0.70, 0.43, 0.18, 0.45),
    "river": Color(0.12, 0.48, 0.78, 0.43),
    "bridge": Color(0.82, 0.59, 0.27, 0.52),
    "cliff": Color(0.50, 0.22, 0.22, 0.48)
}

@onready var camera: Camera3D = $Camera3D
@onready var terrain_root: Node3D = $TerrainRoot
@onready var movement_root: Node3D = $MovementRoot

var board: Dictionary = {}
var cells: Dictionary = {}
var overlay_root: Node3D
var landmark_root: Node3D
var active_tool := "forest"
var edge_anchor_key := ""
var last_stroke_key := ""
var camera_target := Vector3(0.0, 4.5, 0.0)
var orbit_angle := 0.0
var distance := 44.0
var mouse_down := false
var mouse_dragged := false
var pan_dragging := false
var mouse_start := Vector2.ZERO
var touches: Dictionary = {}
var touch_start := Vector2.ZERO
var touch_moved := false
var last_pinch := 0.0
var last_center := Vector2.ZERO
var status_label: Label
var landmark_name: LineEdit

func _ready() -> void:
    board = BOARD_SCRIPT.load_board("ravenwood", GRID_PATH)
    cells = board.get("cells", {})
    _apply_terrain_material()
    _prepare_navigation_collision()
    overlay_root = Node3D.new()
    overlay_root.name = "TerrainAnnotations"
    add_child(overlay_root)
    landmark_root = Node3D.new()
    landmark_root.name = "Landmarks"
    add_child(landmark_root)
    _build_hud()
    _draw_annotations()
    _update_camera()
    _set_status("Tap to edit hexes. Select CAMERA ORBIT to rotate; use two fingers to pan and zoom.")
    print("[board-workshop] ready: %d hexes, HUD=%s" % [cells.size(), str(status_label != null)])

func _apply_terrain_material() -> void:
    var material := StandardMaterial3D.new()
    material.albedo_texture = preload("res://assets/3d/game-ready/ravenwood-board/ravenwood_albedo.jpg")
    material.normal_enabled = true
    material.normal_texture = preload("res://assets/3d/game-ready/ravenwood-board/ravenwood_normal.jpg")
    var metal_rough := preload("res://assets/3d/game-ready/ravenwood-board/ravenwood_metal_rough.jpg")
    material.metallic = 0.18
    material.metallic_texture = metal_rough
    material.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
    material.roughness = 1.0
    material.roughness_texture = metal_rough
    material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
    for item in terrain_root.find_children("*", "MeshInstance3D", true, false):
        (item as MeshInstance3D).material_override = material

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
        body.name = "BoardNavigationCollision"
        body.collision_layer = NAV_COLLISION_LAYER
        body.collision_mask = 0
        var collision := CollisionShape3D.new()
        collision.shape = shape
        body.add_child(collision)
        add_child(body)
        body.global_transform = mesh_node.global_transform

func _build_hud() -> void:
    var ui := CanvasLayer.new()
    add_child(ui)
    var top := PanelContainer.new()
    top.anchor_left = 0.015
    top.anchor_right = 0.985
    top.anchor_top = 0.018
    top.anchor_bottom = 0.018
    top.offset_bottom = 64.0
    ui.add_child(top)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    top.add_child(row)
    var title := Label.new()
    title.text = "RAVENWOOD  •  HEX WORKSHOP"
    title.add_theme_font_size_override("font_size", 20)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(title)
    _add_button(row, "SAVE", _save_board)
    _add_button(row, "PLAY TEST", _play_test)
    _add_button(row, "WORLD MAP", _back_to_world)

    var palette := PanelContainer.new()
    palette.anchor_left = 0.02
    palette.anchor_right = 0.19
    palette.anchor_top = 0.13
    palette.anchor_bottom = 0.13
    palette.offset_bottom = 570.0
    ui.add_child(palette)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    palette.add_child(scroll)
    var column := VBoxContainer.new()
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_theme_constant_override("separation", 5)
    scroll.add_child(column)
    var palette_title := Label.new()
    palette_title.text = "PAINT HEXES"
    palette_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(palette_title)
    for item in [["forest", "FOREST"], ["clearing", "CLEARING"], ["trail", "TRAIL"], ["river", "RIVER"], ["bridge", "BRIDGE"], ["cliff", "CLIFF"], ["passability", "TOGGLE PASSABLE"], ["edge_barrier", "TOGGLE EDGE"], ["landmark", "PLACE LANDMARK"], ["erase_landmark", "ERASE LANDMARK"], ["camera", "CAMERA ORBIT"]]:
        var tool_id: String = item[0]
        _add_button(column, str(item[1]), func(): _set_tool(tool_id))
    landmark_name = LineEdit.new()
    landmark_name.placeholder_text = "Landmark name"
    landmark_name.text = "Hollow Oak"
    landmark_name.custom_minimum_size.y = 42
    column.add_child(landmark_name)

    var footer := PanelContainer.new()
    footer.anchor_left = 0.02
    footer.anchor_right = 0.98
    footer.anchor_top = 1.0
    footer.anchor_bottom = 1.0
    footer.offset_top = -54.0
    footer.offset_bottom = -10.0
    footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(footer)
    status_label = Label.new()
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    footer.add_child(status_label)

func _add_button(parent: Control, text_value: String, action: Callable) -> void:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size = Vector2(0, 44)
    button.pressed.connect(action)
    parent.add_child(button)

func _set_tool(tool_id: String) -> void:
    active_tool = tool_id
    _set_status("Tool: " + tool_id.replace("_", " ").to_upper() + " • tap hexes to edit")

func _set_status(message: String) -> void:
    if status_label:
        status_label.text = message

func _save_board() -> void:
    var ok: bool = BOARD_SCRIPT.save_board(board)
    _set_status("Saved Ravenwood board to this device." if ok else "Could not save Ravenwood board.")

func _play_test() -> void:
    if not BOARD_SCRIPT.save_board(board):
        _set_status("Save failed; play test cancelled.")
        return
    get_tree().change_scene_to_file("res://scenes/RavenwoodPreview.tscn")

func _back_to_world() -> void:
    get_tree().change_scene_to_file("res://scenes/FrontEnd.tscn")

func _draw_annotations() -> void:
    for child in overlay_root.get_children():
        child.queue_free()
    for child in landmark_root.get_children():
        child.queue_free()
    var mesh := ImmediateMesh.new()
    var materials: Dictionary = {}
    for terrain in TERRAIN_COLORS.keys():
        var material := StandardMaterial3D.new()
        material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        material.albedo_color = TERRAIN_COLORS[terrain]
        material.cull_mode = BaseMaterial3D.CULL_DISABLED
        materials[terrain] = material
    for terrain in TERRAIN_COLORS.keys():
        var terrain_keys: Array[String] = []
        for key_value in cells.keys():
            var cell: Dictionary = cells[key_value]
            if str(cell.get("terrain", "natural")) == terrain:
                terrain_keys.append(str(key_value))
        if terrain_keys.is_empty():
            continue
        mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, materials[terrain])
        for key in terrain_keys:
            var cell: Dictionary = cells[key]
            var center := Vector3(float(cell.get("x", 0.0)), float(cell.get("y", 0.0)) + 0.12, float(cell.get("z", 0.0)))
            for corner in range(6):
                var angle_a := deg_to_rad(30.0 + 60.0 * corner)
                var angle_b := deg_to_rad(30.0 + 60.0 * (corner + 1))
                mesh.surface_add_vertex(center)
                mesh.surface_add_vertex(center + Vector3(cos(angle_a) * HEX_RADIUS, 0.0, sin(angle_a) * HEX_RADIUS))
                mesh.surface_add_vertex(center + Vector3(cos(angle_b) * HEX_RADIUS, 0.0, sin(angle_b) * HEX_RADIUS))
        mesh.surface_end()
    var overlay := MeshInstance3D.new()
    overlay.mesh = mesh
    overlay.name = "PaintedHexes"
    overlay_root.add_child(overlay)
    for key_value in cells.keys():
        var cell: Dictionary = cells[key_value]
        var name := str(cell.get("poi_name", ""))
        if name == "":
            continue
        var label := Label3D.new()
        label.text = name
        label.position = Vector3(float(cell.get("x", 0.0)), float(cell.get("y", 0.0)) + 0.55, float(cell.get("z", 0.0)))
        label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        label.font_size = 48
        label.outline_size = 8
        label.modulate = Color(1.0, 0.88, 0.57)
        landmark_root.add_child(label)

func _find_cell_at(screen_position: Vector2) -> String:
    var origin := camera.project_ray_origin(screen_position)
    var direction := camera.project_ray_normal(screen_position)
    var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 120.0)
    query.collision_mask = NAV_COLLISION_LAYER
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return ""
    var point: Vector3 = hit["position"]
    var nearest_key := ""
    var nearest_distance := INF
    for key_value in cells.keys():
        var cell: Dictionary = cells[key_value]
        var delta := Vector2(float(cell.get("x", 0.0)) - point.x, float(cell.get("z", 0.0)) - point.z)
        var candidate := delta.length_squared()
        if candidate < nearest_distance:
            nearest_distance = candidate
            nearest_key = str(key_value)
    return nearest_key if nearest_distance <= 0.30 else ""

func _edit_cell(key: String) -> void:
    if active_tool == "camera":
        return
    if active_tool == "edge_barrier":
        _edit_edge(key)
        return
    var cell: Dictionary = cells[key]
    if active_tool == "passability":
        cell["blocked"] = not bool(cell.get("blocked", false))
        cell["movement_cost"] = 99 if bool(cell["blocked"]) else 1
    elif active_tool == "landmark":
        cell["poi_name"] = landmark_name.text.strip_edges() if landmark_name.text.strip_edges() != "" else "Landmark"
        cell["poi_id"] = cell["poi_name"].to_lower().replace(" ", "_")
    elif active_tool == "erase_landmark":
        cell["poi_name"] = ""
        cell["poi_id"] = ""
    else:
        cell["terrain"] = active_tool
        cell["blocked"] = active_tool == "river" or active_tool == "cliff"
        cell["movement_cost"] = 2 if active_tool == "forest" else (99 if bool(cell["blocked"]) else 1)
    cells[key] = cell
    board["cells"] = cells
    _draw_annotations()
    _set_status("%s  •  %s  •  move cost %s" % [key, str(cell.get("terrain", "natural")).to_upper(), "blocked" if bool(cell.get("blocked", false)) else str(cell.get("movement_cost", 1))])

func _edit_edge(key: String) -> void:
    if edge_anchor_key == "":
        edge_anchor_key = key
        _set_status("Edge tool: choose a neighboring hex to connect or block.")
        return
    if key == edge_anchor_key:
        edge_anchor_key = ""
        _set_status("Edge selection cleared.")
        return
    var first: Dictionary = cells[edge_anchor_key]
    var second: Dictionary = cells[key]
    var dq := int(second.get("q", 0)) - int(first.get("q", 0))
    var dr := int(second.get("r", 0)) - int(first.get("r", 0))
    var hex_distance := maxi(absi(dq), maxi(absi(dr), absi(dq + dr)))
    if hex_distance != 1:
        _set_status("Choose one of the six neighboring hexes.")
        return
    var first_edges: Array = first.get("blocked_edges", []).duplicate()
    var second_edges: Array = second.get("blocked_edges", []).duplicate()
    var first_has := first_edges.has(key)
    var second_has := second_edges.has(edge_anchor_key)
    var should_block := not (first_has or second_has)
    if should_block:
        if not first_edges.has(key):
            first_edges.append(key)
        if not second_edges.has(edge_anchor_key):
            second_edges.append(edge_anchor_key)
    else:
        first_edges.erase(key)
        second_edges.erase(edge_anchor_key)
    first["blocked_edges"] = first_edges
    second["blocked_edges"] = second_edges
    cells[edge_anchor_key] = first
    cells[key] = second
    board["cells"] = cells
    var edited_edge := edge_anchor_key + " ↔ " + key
    edge_anchor_key = ""
    _set_status("%s  •  %s" % [edited_edge, "blocked" if should_block else "opened"])

func _update_camera() -> void:
    camera.position = camera_target + Vector3(sin(orbit_angle) * distance * 0.52, distance * 0.90, cos(orbit_angle) * distance * 0.52)
    camera.look_at(camera_target, Vector3.UP)

func _pan_camera(delta: Vector2) -> void:
    var basis := camera.global_transform.basis
    var right := Vector3(basis.x.x, 0.0, basis.x.z).normalized()
    var up := Vector3(basis.y.x, 0.0, basis.y.z).normalized()
    var factor := distance * 0.0015
    camera_target += -right * delta.x * factor + up * delta.y * factor
    _update_camera()

func _pan_camera(delta: Vector2) -> void:
    var basis := camera.global_transform.basis
    var right := Vector3(basis.x.x, 0.0, basis.x.z).normalized()
    var up := Vector3(basis.y.x, 0.0, basis.y.z).normalized()
    var factor := distance * 0.0015
    camera_target += -right * delta.x * factor + up * delta.y * factor
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
                    var key := _find_cell_at(event.position)
                    if key != "":
                        _edit_cell(key)
                last_stroke_key = ""
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
        if mouse_dragged and active_tool == "camera":
            orbit_angle -= event.relative.x * 0.006
            _update_camera()
        elif mouse_dragged and active_tool in ["forest", "clearing", "trail", "river", "bridge", "cliff", "passability"]:
            var paint_key := _find_cell_at(event.position)
            if paint_key != "" and paint_key != last_stroke_key:
                _edit_cell(paint_key)
                last_stroke_key = paint_key
    elif event is InputEventScreenTouch:
        if event.pressed:
            touches[event.index] = event.position
            if touches.size() == 1:
                touch_start = event.position
                touch_moved = false
            elif touches.size() == 2:
                var points: Array = touches.values()
                last_center = ((points[0] as Vector2) + (points[1] as Vector2)) * 0.5
                touch_moved = true
        else:
            var tapped := touches.size() == 1 and not touch_moved
            touches.erase(event.index)
            if tapped:
                var key := _find_cell_at(event.position)
                if key != "":
                    _edit_cell(key)
            if touches.is_empty():
                touch_moved = false
                last_stroke_key = ""
            last_pinch = 0.0
    elif event is InputEventScreenDrag:
        touches[event.index] = event.position
        if touches.size() == 1:
            if touch_start.distance_to(event.position) > 8.0:
                touch_moved = true
            if touch_moved and active_tool == "camera":
                orbit_angle -= event.relative.x * 0.006
                _update_camera()
            elif touch_moved and active_tool in ["forest", "clearing", "trail", "river", "bridge", "cliff", "passability"]:
                var paint_key := _find_cell_at(event.position)
                if paint_key != "" and paint_key != last_stroke_key:
                    _edit_cell(paint_key)
                    last_stroke_key = paint_key
        elif touches.size() == 2:
            touch_moved = true
            var points: Array = touches.values()
            var pinch := (points[0] as Vector2).distance_to(points[1] as Vector2)
            var center := ((points[0] as Vector2) + (points[1] as Vector2)) * 0.5
            if last_pinch > 0.0:
                distance = clampf(distance - (pinch - last_pinch) * 0.065, 17.0, 65.0)
                _pan_camera(center - last_center)
            last_center = center
            last_pinch = pinch
