extends Node3D

const BOARD_SCRIPT := preload("res://scripts/board_definition.gd")
const TERRAIN_SHADER := preload("res://shaders/hex_terrain.gdshader")
const BOARD_DIR := "user://boards/"
const ACTIVE_PATH := "user://boards/active_board.board.json"
const HEX_RADIUS := 1.0
const ROOT_3 := 1.7320508
const ELEVATION_STEP := 0.22
const TILE_DEPTH := 0.28
const GHOST_RADIUS := 10
const HEX_EDGE_NEIGHBORS := [Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0)]
const TERRAIN_IDS := {"grass": 0, "woodland": 1, "dirt": 2, "stone": 3, "sand": 4, "marsh": 5}
const TERRAIN_LABELS := {
    "grass": "GRASS",
    "woodland": "WOODLAND",
    "dirt": "DIRT / TRAIL",
    "stone": "STONE",
    "sand": "SAND",
    "marsh": "MARSH"
}

var board: Dictionary = {}
var cells: Dictionary = {}
var cell_layer: Node3D
var prop_layer: Node3D
var grid_layer: Node3D
var installed_grid: MeshInstance3D
var ghost_grid: MeshInstance3D
var selection_outline: MeshInstance3D
var cell_nodes: Dictionary = {}
var prop_nodes: Dictionary = {}
var terrain_materials: Dictionary = {}
var shared_hex_mesh: ArrayMesh
var board_foundation_y := -TILE_DEPTH
var prop_materials: Dictionary = {}
var selection_marker_material: StandardMaterial3D
var board_name: LineEdit
var status_label: Label
var brush_radius_option: OptionButton
var paint_brush_option: OptionButton
var undo_button: Button
var redo_button: Button
var palette_panel: PanelContainer
var grid_button: Button
var play_button: Button
var camera_distance_slider: HSlider
var camera_pitch_slider: HSlider
var grid_visible := true
var active_tool := "add_hex"
var brush_radius := 3
var paint_brush_radius := 0
var prop_rotation := 0.0
var selected_key := ""
var selected_object_key := ""
var selected_object_index := -1
var is_playtesting := false
var player_piece: Node3D
var camera_target := Vector3(0.0, 0.0, 0.0)
var orbit_angle := 0.0
var camera_distance := 19.0
var camera_pitch_degrees := 55.0
var mouse_down := false
var mouse_dragged := false
var mouse_start := Vector2.ZERO
var pan_dragging := false
var touches: Dictionary = {}
var touch_start := Vector2.ZERO
var touch_moved := false
var last_pinch := 0.0
var last_center := Vector2.ZERO
var last_stroke_key := ""
var undo_history: Array[Dictionary] = []
var redo_history: Array[Dictionary] = []
var history_action_active := false
var history_action_before: Dictionary = {}
const HISTORY_LIMIT := 60

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
    board = _load_active_board()
    cells = board.get("cells", {})
    cell_layer = Node3D.new()
    cell_layer.name = "BoardTiles"
    add_child(cell_layer)
    prop_layer = Node3D.new()
    prop_layer.name = "BoardProps"
    add_child(prop_layer)
    grid_layer = Node3D.new()
    grid_layer.name = "BoardGrid"
    add_child(grid_layer)
    selection_outline = MeshInstance3D.new()
    selection_outline.name = "SelectedHex"
    add_child(selection_outline)
    _create_materials()
    shared_hex_mesh = _make_hex_mesh()
    _build_ui()
    _build_placement_grid()
    _rebuild_board()
    _update_camera()
    _set_status("Blank board ready. Add hexes, paint terrain, then place objects.")
    print("[hex-board-builder] ready: %d hexes, HUD=true" % cells.size())

func _load_active_board() -> Dictionary:
    if FileAccess.file_exists(ACTIVE_PATH):
        var file := FileAccess.open(ACTIVE_PATH, FileAccess.READ)
        if file:
            var parsed: Variant = JSON.parse_string(file.get_as_text())
            if parsed is Dictionary and BOARD_SCRIPT.validate(parsed):
                return parsed
    return BOARD_SCRIPT.create_empty("new_board", "New Board")

func _create_materials() -> void:
    for terrain in TERRAIN_IDS.keys():
        var material := ShaderMaterial.new()
        material.shader = TERRAIN_SHADER
        material.set_shader_parameter("terrain_id", int(TERRAIN_IDS[terrain]))
        terrain_materials[terrain] = material
    prop_materials["bark"] = _standard_material(Color("60412b"), 0.92)
    prop_materials["bark_light"] = _standard_material(Color("8a623b"), 0.9)
    prop_materials["leaf_dark"] = _standard_material(Color("24452a"), 0.92)
    prop_materials["leaf_mid"] = _standard_material(Color("38683a"), 0.9)
    prop_materials["leaf_light"] = _standard_material(Color("567e3b"), 0.88)
    prop_materials["roof"] = _standard_material(Color("49332c"), 0.91)
    prop_materials["wall"] = _standard_material(Color("a18a60"), 0.9)
    prop_materials["wood"] = _standard_material(Color("765335"), 0.92)
    prop_materials["stone"] = _standard_material(Color("77796e"), 0.96)
    prop_materials["window"] = _standard_material(Color("253b3d"), 0.44)
    prop_materials["water"] = _standard_material(Color("406c75"), 0.25)
    prop_materials["metal"] = _standard_material(Color("525b58"), 0.48)
    prop_materials["flame"] = _standard_material(Color("e87929"), 0.38)
    prop_materials["flame_light"] = _standard_material(Color("ffd064"), 0.32)
    prop_materials["flower"] = _standard_material(Color("d87d9c"), 0.55)
    prop_materials["flame"].emission_enabled = true
    prop_materials["flame"].emission = Color("e87929")
    prop_materials["flame"].emission_energy_multiplier = 1.1
    prop_materials["flame_light"].emission_enabled = true
    prop_materials["flame_light"].emission = Color("ffd064")
    prop_materials["flame_light"].emission_energy_multiplier = 1.5
    prop_materials["flower_gold"] = _standard_material(Color("f2c951"), 0.55)
    prop_materials["mushroom"] = _standard_material(Color("bd5546"), 0.56)
    prop_materials["mushroom_light"] = _standard_material(Color("e7d9b5"), 0.65)
    selection_marker_material = _standard_material(Color("ffd16b"), 0.35)
    selection_marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    selection_marker_material.emission_enabled = true
    selection_marker_material.emission = Color("e6a53c")
    selection_marker_material.emission_energy_multiplier = 1.3

func _standard_material(color: Color, roughness_value: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = roughness_value
    return material

func _build_ui() -> void:
    var ui := CanvasLayer.new()
    ui.layer = 5
    add_child(ui)
    var top := PanelContainer.new()
    top.anchor_left = 0.012
    top.anchor_right = 0.988
    top.anchor_top = 0.018
    top.anchor_bottom = 0.018
    top.offset_bottom = 62.0
    ui.add_child(top)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    top.add_child(row)
    var title := Label.new()
    title.text = "NEW REALM  •  HEX MAP BUILDER"
    title.add_theme_font_size_override("font_size", 19)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(title)
    _add_button(row, "SAVE BOARD", _save_board)
    play_button = _add_button(row, "PLAY TEST", _toggle_playtest)
    _add_button(row, "WORLD MAP", _back_to_world)
    grid_button = _add_button(row, "GRID: ON", _toggle_grid)

    palette_panel = PanelContainer.new()
    palette_panel.anchor_left = 0.014
    palette_panel.anchor_right = 0.205
    palette_panel.anchor_top = 0.115
    palette_panel.anchor_bottom = 0.115
    palette_panel.offset_bottom = 590.0
    ui.add_child(palette_panel)
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    palette_panel.add_child(scroll)
    var palette_scrollbar: VScrollBar = scroll.get_v_scroll_bar()
    palette_scrollbar.custom_minimum_size.x = 28.0
    var scrollbar_track := StyleBoxFlat.new()
    scrollbar_track.bg_color = Color("242821")
    scrollbar_track.border_width_left = 2
    scrollbar_track.border_width_right = 2
    scrollbar_track.border_color = Color("514735")
    palette_scrollbar.add_theme_stylebox_override("scroll", scrollbar_track)
    var scrollbar_thumb := StyleBoxFlat.new()
    scrollbar_thumb.bg_color = Color("c5a56c")
    scrollbar_thumb.border_width_left = 2
    scrollbar_thumb.border_width_right = 2
    scrollbar_thumb.border_color = Color("e5ca91")
    palette_scrollbar.add_theme_stylebox_override("grabber", scrollbar_thumb)
    var scrollbar_thumb_hover := StyleBoxFlat.new()
    scrollbar_thumb_hover.bg_color = Color("e0c184")
    scrollbar_thumb_hover.border_width_left = 2
    scrollbar_thumb_hover.border_width_right = 2
    scrollbar_thumb_hover.border_color = Color("fff0c9")
    palette_scrollbar.add_theme_stylebox_override("grabber_highlight", scrollbar_thumb_hover)
    palette_scrollbar.add_theme_stylebox_override("grabber_pressed", scrollbar_thumb_hover)
    var column := VBoxContainer.new()
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_theme_constant_override("separation", 5)
    scroll.add_child(column)

    board_name = LineEdit.new()
    board_name.text = str(board.get("title", "New Board"))
    board_name.placeholder_text = "Board name"
    board_name.custom_minimum_size.y = 42
    column.add_child(board_name)
    _add_button(column, "CLEAR SELECTED TILE", _clear_selection)
    _add_section(column, "EDIT HISTORY")
    var history_row := HBoxContainer.new()
    column.add_child(history_row)
    undo_button = _add_button(history_row, "UNDO", _undo)
    redo_button = _add_button(history_row, "REDO", _redo)
    undo_button.disabled = true
    redo_button.disabled = true

    _add_section(column, "1  •  LAY HEXES")
    _add_button(column, "ADD HEX", func(): _set_tool("add_hex"))
    _add_button(column, "REMOVE HEX", func(): _set_tool("remove_hex"))
    var brush_row := HBoxContainer.new()
    column.add_child(brush_row)
    var radius_label := Label.new()
    radius_label.text = "DISK RADIUS"
    radius_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    brush_row.add_child(radius_label)
    brush_radius_option = OptionButton.new()
    for radius in range(0, 9):
        brush_radius_option.add_item(str(radius))
    brush_radius_option.select(3)
    brush_radius_option.item_selected.connect(_on_brush_radius_changed)
    brush_row.add_child(brush_radius_option)
    _add_button(column, "LAY HEX DISK", _lay_hex_disk)

    _add_section(column, "2  •  PAINT TERRAIN")
    for terrain in ["grass", "woodland", "dirt", "stone", "sand", "marsh"]:
        _add_button(column, TERRAIN_LABELS[terrain], func(): _set_tool("terrain:" + terrain))
    var paint_row := HBoxContainer.new()
    column.add_child(paint_row)
    var paint_label := Label.new()
    paint_label.text = "PAINT RADIUS"
    paint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    paint_row.add_child(paint_label)
    paint_brush_option = OptionButton.new()
    for radius in range(0, 5):
        paint_brush_option.add_item(str(radius))
    paint_brush_option.select(0)
    paint_brush_option.item_selected.connect(_on_paint_brush_changed)
    paint_row.add_child(paint_brush_option)

    _add_section(column, "3  •  SHAPE THE GROUND")
    _add_button(column, "RAISE HEX", func(): _set_tool("raise"))
    _add_button(column, "LOWER HEX", func(): _set_tool("lower"))

    _add_section(column, "4  •  PLACE OBJECTS")
    for prop in [
        ["tree", "TREE"], ["pine", "PINE"], ["ancient_tree", "ANCIENT OAK"], ["dead_tree", "DEAD TREE"],
        ["house", "HOUSE"], ["fence", "FENCE"], ["rock", "ROCK"], ["bush", "BUSH"],
        ["stump", "STUMP"], ["log", "FALLEN LOG"], ["campfire", "CAMPFIRE"], ["lantern", "LANTERN"],
        ["signpost", "SIGNPOST"], ["well", "WELL"], ["ruins", "RUINS"], ["flowers", "FLOWERS"], ["mushrooms", "MUSHROOMS"]
    ]:
        var prop_id: String = prop[0]
        _add_button(column, str(prop[1]), func(): _set_tool("prop:" + prop_id))
    _add_button(column, "SELECT / MOVE OBJECT", func(): _set_tool("select_object"))
    _add_button(column, "NEXT OBJECT ON HEX", _cycle_selected_object)
    _add_button(column, "ERASE SELECTED / LAST", func(): _set_tool("erase_prop"))
    var rotate_row := HBoxContainer.new()
    column.add_child(rotate_row)
    _add_button(rotate_row, "ROTATE −", func(): _rotate_prop(-PI / 6.0))
    _add_button(rotate_row, "ROTATE +", func(): _rotate_prop(PI / 6.0))
    var nudge_row_x := HBoxContainer.new()
    column.add_child(nudge_row_x)
    _add_button(nudge_row_x, "X −", func(): _nudge_selected_object(Vector2(-0.12, 0.0)))
    _add_button(nudge_row_x, "X +", func(): _nudge_selected_object(Vector2(0.12, 0.0)))
    var nudge_row_z := HBoxContainer.new()
    column.add_child(nudge_row_z)
    _add_button(nudge_row_z, "Z −", func(): _nudge_selected_object(Vector2(0.0, -0.12)))
    _add_button(nudge_row_z, "Z +", func(): _nudge_selected_object(Vector2(0.0, 0.12)))

    _add_section(column, "VIEW")
    _add_button(column, "CAMERA ORBIT", func(): _set_tool("camera"))
    _build_camera_controls(ui)

    var footer := PanelContainer.new()
    footer.anchor_left = 0.012
    footer.anchor_right = 0.988
    footer.anchor_top = 1.0
    footer.anchor_bottom = 1.0
    footer.offset_top = -48.0
    footer.offset_bottom = -8.0
    footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(footer)
    status_label = Label.new()
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    status_label.add_theme_font_size_override("font_size", 13)
    footer.add_child(status_label)

func _build_camera_controls(ui: CanvasLayer) -> void:
    var panel := PanelContainer.new()
    panel.name = "CameraControls"
    panel.anchor_left = 1.0
    panel.anchor_right = 1.0
    panel.anchor_top = 0.12
    panel.anchor_bottom = 0.12
    panel.offset_left = -374.0
    panel.offset_right = -12.0
    panel.offset_bottom = 238.0
    ui.add_child(panel)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 4)
    panel.add_child(column)
    var title := Label.new()
    title.text = "CAMERA CONTROLS"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_color_override("font_color", Color("e0c184"))
    column.add_child(title)

    var zoom_row := HBoxContainer.new()
    column.add_child(zoom_row)
    _add_button(zoom_row, "−", func(): _zoom_camera(2.0))
    var zoom_label := Label.new()
    zoom_label.text = "ZOOM"
    zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    zoom_row.add_child(zoom_label)
    camera_distance_slider = HSlider.new()
    camera_distance_slider.min_value = 8.0
    camera_distance_slider.max_value = 70.0
    camera_distance_slider.step = 1.0
    camera_distance_slider.value = camera_distance
    camera_distance_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    camera_distance_slider.custom_minimum_size.x = 150.0
    camera_distance_slider.value_changed.connect(_on_camera_distance_changed)
    zoom_row.add_child(camera_distance_slider)
    _add_button(zoom_row, "+", func(): _zoom_camera(-2.0))

    var tilt_row := HBoxContainer.new()
    column.add_child(tilt_row)
    var tilt_label := Label.new()
    tilt_label.text = "TILT"
    tilt_label.custom_minimum_size.x = 42.0
    tilt_row.add_child(tilt_label)
    camera_pitch_slider = HSlider.new()
    camera_pitch_slider.min_value = 30.0
    camera_pitch_slider.max_value = 82.0
    camera_pitch_slider.step = 1.0
    camera_pitch_slider.value = camera_pitch_degrees
    camera_pitch_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    camera_pitch_slider.value_changed.connect(_on_camera_pitch_changed)
    tilt_row.add_child(camera_pitch_slider)

    var action_row := HBoxContainer.new()
    column.add_child(action_row)
    _add_button(action_row, "TURN LEFT", func(): _rotate_camera(PI / 12.0))
    _add_button(action_row, "TURN RIGHT", func(): _rotate_camera(-PI / 12.0))

    var frame_row := HBoxContainer.new()
    column.add_child(frame_row)
    _add_button(frame_row, "FRAME BOARD", _frame_board)
    _add_button(frame_row, "RESET VIEW", _reset_camera)

func _add_section(parent: Control, text_value: String) -> void:
    var label := Label.new()
    label.text = text_value
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_color_override("font_color", Color("d7b779"))
    label.add_theme_font_size_override("font_size", 13)
    parent.add_child(label)

func _add_button(parent: Control, text_value: String, action: Callable) -> Button:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size = Vector2(0.0, 42.0)
    button.pressed.connect(action)
    parent.add_child(button)
    return button

func _on_brush_radius_changed(index: int) -> void:
    brush_radius = index
    _set_status("Hex disk radius: %d" % brush_radius)

func _on_paint_brush_changed(index: int) -> void:
    paint_brush_radius = index
    _set_status("Terrain paint radius: %d hexes." % paint_brush_radius)

func _set_tool(tool_id: String) -> void:
    active_tool = tool_id
    _set_status("Tool: %s • tap or drag over the board" % tool_id.replace(":", " ").replace("_", " ").to_upper())

func _set_status(message: String) -> void:
    if status_label:
        status_label.text = message

func _toggle_grid() -> void:
    grid_visible = not grid_visible
    if installed_grid:
        installed_grid.visible = grid_visible
    if ghost_grid:
        ghost_grid.visible = grid_visible
    grid_button.text = "GRID: ON" if grid_visible else "GRID: OFF"

func _build_placement_grid() -> void:
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.albedo_color = Color(0.52, 0.64, 0.58, 0.18)
    var mesh := ImmediateMesh.new()
    mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
    for q in range(-GHOST_RADIUS, GHOST_RADIUS + 1):
        for r in range(-GHOST_RADIUS, GHOST_RADIUS + 1):
            if maxi(absi(q), maxi(absi(r), absi(q + r))) > GHOST_RADIUS:
                continue
            var center := _axial_to_world(q, r)
            for corner in range(6):
                var a := center + Vector3(cos(deg_to_rad(30.0 + 60.0 * corner)) * HEX_RADIUS, -0.14, sin(deg_to_rad(30.0 + 60.0 * corner)) * HEX_RADIUS)
                var b := center + Vector3(cos(deg_to_rad(30.0 + 60.0 * (corner + 1))) * HEX_RADIUS, -0.14, sin(deg_to_rad(30.0 + 60.0 * (corner + 1))) * HEX_RADIUS)
                mesh.surface_add_vertex(a)
                mesh.surface_add_vertex(b)
    mesh.surface_end()
    ghost_grid = MeshInstance3D.new()
    ghost_grid.name = "PlacementGrid"
    ghost_grid.mesh = mesh
    ghost_grid.material_override = material
    ghost_grid.visible = grid_visible
    grid_layer.add_child(ghost_grid)

func _rebuild_installed_grid() -> void:
    if installed_grid and is_instance_valid(installed_grid):
        installed_grid.free()
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.albedo_color = Color(0.90, 0.78, 0.52, 0.42)
    var mesh := ImmediateMesh.new()
    mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
    for key_value in cells.keys():
        var cell: Dictionary = cells[key_value]
        var center := _axial_to_world(int(cell.get("q", 0)), int(cell.get("r", 0)))
        center.y = float(cell.get("elevation", 0)) * ELEVATION_STEP + 0.03
        for corner in range(6):
            var point_a := center + Vector3(cos(deg_to_rad(30.0 + 60.0 * corner)) * HEX_RADIUS, 0.0, sin(deg_to_rad(30.0 + 60.0 * corner)) * HEX_RADIUS)
            var point_b := center + Vector3(cos(deg_to_rad(30.0 + 60.0 * (corner + 1))) * HEX_RADIUS, 0.0, sin(deg_to_rad(30.0 + 60.0 * (corner + 1))) * HEX_RADIUS)
            mesh.surface_add_vertex(point_a)
            mesh.surface_add_vertex(point_b)
    mesh.surface_end()
    installed_grid = MeshInstance3D.new()
    installed_grid.name = "InstalledHexGrid"
    installed_grid.mesh = mesh
    installed_grid.material_override = material
    installed_grid.visible = grid_visible
    grid_layer.add_child(installed_grid)

func _rebuild_board() -> void:
    var lowest_elevation := 0
    var has_cells := false
    for cell_value in cells.values():
        var cell_data: Dictionary = cell_value
        var elevation := int(cell_data.get("elevation", 0))
        if not has_cells or elevation < lowest_elevation:
            lowest_elevation = elevation
            has_cells = true
    board_foundation_y = float(lowest_elevation) * ELEVATION_STEP - TILE_DEPTH
    for key_value in cell_nodes.keys():
        var node: Node = cell_nodes[key_value]
        if is_instance_valid(node):
            node.free()
    for key_value in prop_nodes.keys():
        var node: Node = prop_nodes[key_value]
        if is_instance_valid(node):
            node.free()
    cell_nodes.clear()
    prop_nodes.clear()
    for key_value in cells.keys():
        _refresh_cell_visual(str(key_value))
    _rebuild_installed_grid()
    _refresh_selection()

func _refresh_cell_visual(key: String) -> void:
    if cell_nodes.has(key) and is_instance_valid(cell_nodes[key]):
        cell_nodes[key].free()
    if prop_nodes.has(key) and is_instance_valid(prop_nodes[key]):
        prop_nodes[key].free()
    cell_nodes.erase(key)
    prop_nodes.erase(key)
    if not cells.has(key):
        return
    var cell: Dictionary = cells[key]
    var terrain := str(cell.get("terrain", "grass"))
    if not terrain_materials.has(terrain):
        terrain = "grass"
    var tile := MeshInstance3D.new()
    tile.name = "Hex_" + key.replace(",", "_")
    tile.mesh = shared_hex_mesh
    tile.material_override = terrain_materials[terrain]
    tile.position = _axial_to_world(int(cell.get("q", 0)), int(cell.get("r", 0)))
    tile.position.y = float(cell.get("elevation", 0)) * ELEVATION_STEP
    cell_layer.add_child(tile)
    cell_nodes[key] = tile
    var wall_mesh := _make_hex_wall_mesh(cell)
    if wall_mesh:
        var walls := MeshInstance3D.new()
        walls.name = "ExposedHexWalls"
        walls.mesh = wall_mesh
        walls.material_override = terrain_materials[terrain]
        tile.add_child(walls)
    var object_root := Node3D.new()
    object_root.name = "Objects_" + key.replace(",", "_")
    object_root.position = tile.position + Vector3.UP * 0.01
    prop_layer.add_child(object_root)
    prop_nodes[key] = object_root
    var objects: Array = cell.get("objects", [])
    for object_index in range(objects.size()):
        if objects[object_index] is Dictionary:
            var object_data: Dictionary = objects[object_index]
            var prop := _make_prop(str(object_data.get("type", "tree")))
            prop.rotation.y = float(object_data.get("rotation", 0.0))
            var type_scale := 1.28 if str(object_data.get("type", "")) == "ancient_tree" else 1.0
            prop.scale = Vector3.ONE * clampf(float(object_data.get("scale", 1.0)), 0.45, 1.8) * type_scale
            prop.position = Vector3(float(object_data.get("offset_x", 0.0)), 0.0, float(object_data.get("offset_z", 0.0)))
            object_root.add_child(prop)
            prop.name = "PlacedObject_%d" % object_index
            if key == selected_object_key and object_index == selected_object_index:
                var marker := MeshInstance3D.new()
                marker.name = "SelectedObjectMarker"
                var marker_mesh := TorusMesh.new()
                marker_mesh.inner_radius = 0.27
                marker_mesh.outer_radius = 0.32
                marker_mesh.rings = 8
                marker_mesh.ring_segments = 18
                marker.mesh = marker_mesh
                marker.material_override = selection_marker_material
                marker.position = Vector3(prop.position.x, 0.025, prop.position.z)
                object_root.add_child(marker)

func _make_hex_mesh() -> ArrayMesh:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var top: Array[Vector3] = []
    for corner in range(6):
        var angle := deg_to_rad(30.0 + 60.0 * corner)
        top.append(Vector3(cos(angle) * HEX_RADIUS, 0.0, sin(angle) * HEX_RADIUS))
    var center := Vector3.ZERO
    for corner in range(6):
        var next := (corner + 1) % 6
        surface.add_vertex(center)
        surface.add_vertex(top[corner])
        surface.add_vertex(top[next])
    surface.generate_normals()
    return surface.commit()

func _make_hex_wall_mesh(cell: Dictionary) -> ArrayMesh:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var q := int(cell.get("q", 0))
    var r := int(cell.get("r", 0))
    var elevation := int(cell.get("elevation", 0))
    var cell_y := float(elevation) * ELEVATION_STEP
    var wall_base_y := board_foundation_y - cell_y
    var added_wall := false
    for edge in range(6):
        var offset: Vector2i = HEX_EDGE_NEIGHBORS[edge]
        var neighbor_key := _cell_key(q + offset.x, r + offset.y)
        var wall_bottom_y := wall_base_y
        if cells.has(neighbor_key):
            var neighbor: Dictionary = cells[neighbor_key]
            var neighbor_elevation := int(neighbor.get("elevation", 0))
            if neighbor_elevation >= elevation:
                continue
            wall_bottom_y = float(neighbor_elevation - elevation) * ELEVATION_STEP
        if wall_bottom_y >= -0.001:
            continue
        var angle_a := deg_to_rad(30.0 + 60.0 * edge)
        var angle_b := deg_to_rad(30.0 + 60.0 * ((edge + 1) % 6))
        var upper_a := Vector3(cos(angle_a) * HEX_RADIUS, 0.0, sin(angle_a) * HEX_RADIUS)
        var upper_b := Vector3(cos(angle_b) * HEX_RADIUS, 0.0, sin(angle_b) * HEX_RADIUS)
        var lower_a := Vector3(upper_a.x * 0.98, wall_bottom_y, upper_a.z * 0.98)
        var lower_b := Vector3(upper_b.x * 0.98, wall_bottom_y, upper_b.z * 0.98)
        surface.add_vertex(upper_a)
        surface.add_vertex(lower_a)
        surface.add_vertex(upper_b)
        surface.add_vertex(upper_b)
        surface.add_vertex(lower_a)
        surface.add_vertex(lower_b)
        added_wall = true
    if not added_wall:
        return null
    surface.generate_normals()
    return surface.commit()

func _make_prop(kind: String) -> Node3D:
    var root := Node3D.new()
    root.name = kind.capitalize()
    match kind:
        "tree":
            _build_tree(root, false)
        "pine":
            _build_tree(root, true)
        "house":
            _build_house(root)
        "fence":
            _build_fence(root)
        "rock":
            _build_rock(root)
        "bush":
            _build_bush(root)
        "ancient_tree":
            _build_tree(root, false)
        "dead_tree":
            _build_dead_tree(root)
        "stump":
            _build_stump(root)
        "log":
            _build_log(root)
        "campfire":
            _build_campfire(root)
        "lantern":
            _build_lantern(root)
        "signpost":
            _build_signpost(root)
        "well":
            _build_well(root)
        "ruins":
            _build_ruins(root)
        "flowers":
            _build_flowers(root)
        "mushrooms":
            _build_mushrooms(root)
        _:
            _build_tree(root, false)
    return root

func _add_mesh(parent: Node3D, mesh: Mesh, material: Material, position: Vector3, scale_value: Vector3 = Vector3.ONE) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.mesh = mesh
    instance.material_override = material
    instance.position = position
    instance.scale = scale_value
    parent.add_child(instance)
    return instance

func _build_tree(root: Node3D, pine: bool) -> void:
    var trunk := CylinderMesh.new()
    trunk.top_radius = 0.09 if not pine else 0.06
    trunk.bottom_radius = 0.16 if not pine else 0.11
    trunk.height = 1.45 if not pine else 1.9
    trunk.radial_segments = 12
    _add_mesh(root, trunk, prop_materials["bark"], Vector3(0.0, trunk.height * 0.5, 0.0))
    if pine:
        for index in range(4):
            var cone := CylinderMesh.new()
            cone.top_radius = 0.0
            cone.bottom_radius = 0.62 - float(index) * 0.1
            cone.height = 0.68
            cone.radial_segments = 14
            _add_mesh(root, cone, prop_materials["leaf_dark"] if index % 2 == 0 else prop_materials["leaf_mid"], Vector3(0.0, 0.75 + float(index) * 0.34, 0.0))
        return
    for branch_index in range(5):
        var angle := float(branch_index) * TAU / 5.0
        var start := Vector3(0.0, 0.65 + float(branch_index % 3) * 0.22, 0.0)
        var finish := Vector3(cos(angle) * 0.48, start.y + 0.43, sin(angle) * 0.48)
        _add_beam(root, start, finish, 0.055, prop_materials["bark_light"])
    var foliage := SphereMesh.new()
    foliage.radial_segments = 18
    foliage.rings = 12
    for index in range(9):
        var angle := float(index) * TAU / 8.0
        var layer := float(index % 3)
        var center := Vector3(cos(angle) * 0.42, 1.55 + layer * 0.18, sin(angle) * 0.42)
        var size := 0.43 if index % 3 == 0 else 0.34
        var foliage_material: Material = prop_materials["leaf_mid"] if index % 3 == 0 else (prop_materials["leaf_light"] if index % 2 == 0 else prop_materials["leaf_dark"])
        _add_mesh(root, foliage, foliage_material, center, Vector3(size, size * 0.88, size))
    _add_mesh(root, foliage, prop_materials["leaf_mid"], Vector3(0.0, 1.85, 0.0), Vector3(0.43, 0.42, 0.43))

func _build_house(root: Node3D) -> void:
    var foundation := BoxMesh.new()
    foundation.size = Vector3(0.98, 0.17, 0.90)
    _add_mesh(root, foundation, prop_materials["stone"], Vector3(0.0, 0.09, 0.0))
    var walls := BoxMesh.new()
    walls.size = Vector3(0.82, 0.72, 0.72)
    _add_mesh(root, walls, prop_materials["wall"], Vector3(0.0, 0.52, 0.0))
    var timber := BoxMesh.new()
    timber.size = Vector3(0.06, 0.78, 0.79)
    _add_mesh(root, timber, prop_materials["wood"], Vector3(-0.38, 0.53, 0.0))
    _add_mesh(root, timber, prop_materials["wood"], Vector3(0.38, 0.53, 0.0))
    var front_door := BoxMesh.new()
    front_door.size = Vector3(0.22, 0.48, 0.035)
    _add_mesh(root, front_door, prop_materials["roof"], Vector3(0.0, 0.34, 0.38))
    var window := BoxMesh.new()
    window.size = Vector3(0.17, 0.18, 0.035)
    _add_mesh(root, window, prop_materials["window"], Vector3(-0.24, 0.62, 0.38))
    _add_mesh(root, window, prop_materials["window"], Vector3(0.24, 0.62, 0.38))
    var roof_panel := BoxMesh.new()
    roof_panel.size = Vector3(0.61, 0.09, 0.98)
    var left := _add_mesh(root, roof_panel, prop_materials["roof"], Vector3(-0.22, 0.98, 0.0))
    left.rotation.z = -0.58
    var right := _add_mesh(root, roof_panel, prop_materials["roof"], Vector3(0.22, 0.98, 0.0))
    right.rotation.z = 0.58
    var chimney := BoxMesh.new()
    chimney.size = Vector3(0.16, 0.52, 0.18)
    _add_mesh(root, chimney, prop_materials["stone"], Vector3(0.24, 1.08, -0.24))

func _build_fence(root: Node3D) -> void:
    for x in [-0.72, 0.0, 0.72]:
        var post := CylinderMesh.new()
        post.top_radius = 0.055
        post.bottom_radius = 0.075
        post.height = 0.88
        post.radial_segments = 8
        _add_mesh(root, post, prop_materials["wood"], Vector3(x, 0.44, 0.0))
    for y in [0.28, 0.62]:
        var rail := BoxMesh.new()
        rail.size = Vector3(1.5, 0.11, 0.12)
        _add_mesh(root, rail, prop_materials["bark_light"], Vector3(0.0, y, 0.0))

func _build_rock(root: Node3D) -> void:
    var boulder := SphereMesh.new()
    boulder.radial_segments = 18
    boulder.rings = 10
    _add_mesh(root, boulder, prop_materials["stone"], Vector3(0.0, 0.3, 0.0), Vector3(0.58, 0.43, 0.5))
    var smaller := SphereMesh.new()
    smaller.radial_segments = 14
    smaller.rings = 8
    _add_mesh(root, smaller, prop_materials["stone"], Vector3(0.32, 0.22, 0.12), Vector3(0.29, 0.25, 0.3))
    _add_mesh(root, smaller, prop_materials["stone"], Vector3(-0.28, 0.18, -0.1), Vector3(0.24, 0.2, 0.28))

func _build_dead_tree(root: Node3D) -> void:
    var trunk := CylinderMesh.new()
    trunk.top_radius = 0.11
    trunk.bottom_radius = 0.22
    trunk.height = 1.65
    trunk.radial_segments = 10
    _add_mesh(root, trunk, prop_materials["bark"], Vector3(0.0, 0.82, 0.0))
    for branch in range(6):
        var angle := float(branch) * TAU / 6.0
        var base := Vector3(0.0, 0.55 + float(branch % 3) * 0.27, 0.0)
        var end := Vector3(cos(angle) * (0.52 if branch % 2 == 0 else 0.36), base.y + 0.45, sin(angle) * (0.52 if branch % 2 == 0 else 0.36))
        _add_beam(root, base, end, 0.055, prop_materials["bark_light"])
        if branch % 2 == 0:
            var fork := end + Vector3(cos(angle + 0.5) * 0.22, 0.28, sin(angle + 0.5) * 0.22)
            _add_beam(root, end, fork, 0.032, prop_materials["bark"])

func _build_stump(root: Node3D) -> void:
    var stump := CylinderMesh.new()
    stump.top_radius = 0.22
    stump.bottom_radius = 0.29
    stump.height = 0.48
    stump.radial_segments = 10
    _add_mesh(root, stump, prop_materials["bark"], Vector3(0.0, 0.24, 0.0))
    var cut := CylinderMesh.new()
    cut.top_radius = 0.20
    cut.bottom_radius = 0.20
    cut.height = 0.035
    cut.radial_segments = 10
    _add_mesh(root, cut, prop_materials["bark_light"], Vector3(0.0, 0.49, 0.0))

func _build_log(root: Node3D) -> void:
    var log := CylinderMesh.new()
    log.top_radius = 0.18
    log.bottom_radius = 0.20
    log.height = 1.15
    log.radial_segments = 12
    var body := _add_mesh(root, log, prop_materials["bark"], Vector3(0.0, 0.2, 0.0))
    body.rotation.z = PI * 0.5
    var cut := CylinderMesh.new()
    cut.top_radius = 0.16
    cut.bottom_radius = 0.16
    cut.height = 0.025
    cut.radial_segments = 12
    var end_a := _add_mesh(root, cut, prop_materials["bark_light"], Vector3(-0.57, 0.2, 0.0))
    var end_b := _add_mesh(root, cut, prop_materials["bark_light"], Vector3(0.57, 0.2, 0.0))
    end_a.rotation.z = PI * 0.5
    end_b.rotation.z = PI * 0.5

func _build_campfire(root: Node3D) -> void:
    var stones := SphereMesh.new()
    stones.radial_segments = 10
    stones.rings = 6
    for index in range(7):
        var angle := float(index) * TAU / 7.0
        var pos := Vector3(cos(angle) * 0.34, 0.10, sin(angle) * 0.34)
        _add_mesh(root, stones, prop_materials["stone"], pos, Vector3(0.14, 0.11, 0.14))
    var log_mesh := BoxMesh.new()
    log_mesh.size = Vector3(0.72, 0.11, 0.12)
    var log_a := _add_mesh(root, log_mesh, prop_materials["bark"], Vector3(0.0, 0.17, 0.0))
    log_a.rotation.y = 0.65
    var log_b := _add_mesh(root, log_mesh, prop_materials["bark_light"], Vector3(0.0, 0.22, 0.0))
    log_b.rotation.y = -0.65
    var flame := CylinderMesh.new()
    flame.top_radius = 0.015
    flame.bottom_radius = 0.19
    flame.height = 0.46
    flame.radial_segments = 6
    _add_mesh(root, flame, prop_materials["flame"], Vector3(0.0, 0.44, 0.0))
    var inner_flame := CylinderMesh.new()
    inner_flame.top_radius = 0.0
    inner_flame.bottom_radius = 0.10
    inner_flame.height = 0.30
    inner_flame.radial_segments = 6
    _add_mesh(root, inner_flame, prop_materials["flame_light"], Vector3(0.0, 0.47, 0.0))

func _build_lantern(root: Node3D) -> void:
    var post := CylinderMesh.new()
    post.top_radius = 0.045
    post.bottom_radius = 0.07
    post.height = 1.65
    post.radial_segments = 8
    _add_mesh(root, post, prop_materials["wood"], Vector3(0.0, 0.82, 0.0))
    var arm := BoxMesh.new()
    arm.size = Vector3(0.48, 0.06, 0.06)
    _add_mesh(root, arm, prop_materials["metal"], Vector3(0.20, 1.55, 0.0))
    var lamp := BoxMesh.new()
    lamp.size = Vector3(0.22, 0.30, 0.22)
    _add_mesh(root, lamp, prop_materials["flame_light"], Vector3(0.40, 1.35, 0.0))
    var cap := CylinderMesh.new()
    cap.top_radius = 0.0
    cap.bottom_radius = 0.19
    cap.height = 0.18
    cap.radial_segments = 4
    _add_mesh(root, cap, prop_materials["metal"], Vector3(0.40, 1.59, 0.0))

func _build_signpost(root: Node3D) -> void:
    var post := CylinderMesh.new()
    post.top_radius = 0.055
    post.bottom_radius = 0.085
    post.height = 1.45
    post.radial_segments = 8
    _add_mesh(root, post, prop_materials["wood"], Vector3(0.0, 0.72, 0.0))
    var board := BoxMesh.new()
    board.size = Vector3(0.82, 0.20, 0.12)
    _add_mesh(root, board, prop_materials["bark_light"], Vector3(0.25, 1.12, 0.0))
    var lower_board := BoxMesh.new()
    lower_board.size = Vector3(0.62, 0.17, 0.11)
    _add_mesh(root, lower_board, prop_materials["wood"], Vector3(-0.16, 0.82, 0.0))

func _build_well(root: Node3D) -> void:
    var ring := TorusMesh.new()
    ring.inner_radius = 0.38
    ring.outer_radius = 0.50
    ring.rings = 10
    ring.ring_segments = 16
    _add_mesh(root, ring, prop_materials["stone"], Vector3(0.0, 0.40, 0.0))
    var water := CylinderMesh.new()
    water.top_radius = 0.36
    water.bottom_radius = 0.36
    water.height = 0.04
    _add_mesh(root, water, prop_materials["water"], Vector3(0.0, 0.31, 0.0))
    for x in [-0.42, 0.42]:
        var post := CylinderMesh.new()
        post.top_radius = 0.045
        post.bottom_radius = 0.06
        post.height = 0.82
        post.radial_segments = 8
        _add_mesh(root, post, prop_materials["wood"], Vector3(x, 0.78, 0.0))
    var roof := BoxMesh.new()
    roof.size = Vector3(1.10, 0.08, 0.65)
    var roof_left := _add_mesh(root, roof, prop_materials["roof"], Vector3(-0.26, 1.22, 0.0))
    var roof_right := _add_mesh(root, roof, prop_materials["roof"], Vector3(0.26, 1.22, 0.0))
    roof_left.rotation.z = -0.48
    roof_right.rotation.z = 0.48

func _build_ruins(root: Node3D) -> void:
    for index in range(3):
        var pillar := BoxMesh.new()
        pillar.size = Vector3(0.25, 0.72 + float(index % 2) * 0.35, 0.25)
        _add_mesh(root, pillar, prop_materials["stone"], Vector3(-0.46 + float(index) * 0.46, pillar.size.y * 0.5, -0.16))
    var fallen := BoxMesh.new()
    fallen.size = Vector3(0.92, 0.20, 0.26)
    var lintel := _add_mesh(root, fallen, prop_materials["stone"], Vector3(0.0, 1.0, -0.16))
    lintel.rotation.z = -0.12
    var rubble := SphereMesh.new()
    rubble.radial_segments = 10
    rubble.rings = 6
    for index in range(4):
        _add_mesh(root, rubble, prop_materials["stone"], Vector3(-0.40 + float(index) * 0.25, 0.12, 0.30), Vector3(0.18, 0.14, 0.17))

func _build_flowers(root: Node3D) -> void:
    var stem := CylinderMesh.new()
    stem.top_radius = 0.012
    stem.bottom_radius = 0.02
    stem.height = 0.30
    stem.radial_segments = 5
    var bloom := SphereMesh.new()
    bloom.radial_segments = 8
    bloom.rings = 5
    for index in range(7):
        var angle := float(index) * TAU / 7.0
        var x := cos(angle) * 0.38
        var z := sin(angle) * 0.38
        var y := 0.24 + float(index % 3) * 0.05
        _add_mesh(root, stem, prop_materials["leaf_mid"], Vector3(x, y * 0.5, z))
        _add_mesh(root, bloom, prop_materials["flower"] if index % 2 == 0 else prop_materials["flower_gold"], Vector3(x, y, z), Vector3(0.10, 0.10, 0.10))

func _build_mushrooms(root: Node3D) -> void:
    var stem := CylinderMesh.new()
    stem.top_radius = 0.045
    stem.bottom_radius = 0.06
    stem.height = 0.20
    stem.radial_segments = 8
    var cap := SphereMesh.new()
    cap.radial_segments = 10
    cap.rings = 6
    for index in range(5):
        var angle := float(index) * TAU / 5.0
        var x := cos(angle) * 0.30
        var z := sin(angle) * 0.30
        var size := 0.12 + float(index % 2) * 0.05
        _add_mesh(root, stem, prop_materials["mushroom_light"], Vector3(x, 0.10, z))
        _add_mesh(root, cap, prop_materials["mushroom"], Vector3(x, 0.23, z), Vector3(size, size * 0.55, size))
        var spot := SphereMesh.new()
        spot.radial_segments = 6
        spot.rings = 4
        _add_mesh(root, spot, prop_materials["mushroom_light"], Vector3(x, 0.29, z), Vector3(0.035, 0.02, 0.035))

func _build_bush(root: Node3D) -> void:
    var leaf := SphereMesh.new()
    leaf.radial_segments = 16
    leaf.rings = 10
    for index in range(5):
        var angle := float(index) * TAU / 5.0
        var pos := Vector3(cos(angle) * 0.23, 0.2 + float(index % 2) * 0.08, sin(angle) * 0.23)
        _add_mesh(root, leaf, prop_materials["leaf_light"] if index % 2 == 0 else prop_materials["leaf_dark"], pos, Vector3(0.28, 0.23, 0.28))

func _add_beam(root: Node3D, from: Vector3, to: Vector3, radius: float, material: Material) -> void:
    var direction := to - from
    var beam := CylinderMesh.new()
    beam.top_radius = radius * 0.72
    beam.bottom_radius = radius
    beam.height = direction.length()
    beam.radial_segments = 8
    var instance := _add_mesh(root, beam, material, (from + to) * 0.5)
    instance.quaternion = Quaternion(Vector3.UP, direction.normalized())

func _axial_to_world(q: int, r: int) -> Vector3:
    return Vector3(ROOT_3 * (float(q) + float(r) * 0.5) * HEX_RADIUS, 0.0, 1.5 * float(r) * HEX_RADIUS)

func _world_to_axial(point: Vector2) -> Vector2i:
    var qf := (ROOT_3 / 3.0 * point.x - point.y / 3.0) / HEX_RADIUS
    var rf := (2.0 / 3.0 * point.y) / HEX_RADIUS
    var sf := -qf - rf
    var q := roundi(qf)
    var r := roundi(rf)
    var cube_s := roundi(sf)
    var q_error := absf(float(q) - qf)
    var r_error := absf(float(r) - rf)
    var s_error := absf(float(cube_s) - sf)
    if q_error > r_error and q_error > s_error:
        q = -r - cube_s
    elif r_error > s_error:
        r = -q - cube_s
    return Vector2i(q, r)

func _cell_key(q: int, r: int) -> String:
    return "%d,%d" % [q, r]

func _lay_hex_disk() -> void:
    var before := _capture_editor_state()
    var center := Vector2i(0, 0)
    if selected_key != "" and cells.has(selected_key):
        var selected: Dictionary = cells[selected_key]
        center = Vector2i(int(selected.get("q", 0)), int(selected.get("r", 0)))
    var count := 0
    for q in range(center.x - brush_radius, center.x + brush_radius + 1):
        for r in range(center.y - brush_radius, center.y + brush_radius + 1):
            if maxi(absi(q - center.x), maxi(absi(r - center.y), absi((q - center.x) + (r - center.y)))) > brush_radius:
                continue
            var key := _cell_key(q, r)
            if cells.has(key):
                continue
            cells[key] = _new_cell(q, r)
            count += 1
    board["cells"] = cells
    if count > 0:
        _rebuild_board()
    _set_status("Laid %d new hexes around %s." % [count, _cell_key(center.x, center.y)])
    _record_history(before)

func _new_cell(q: int, r: int) -> Dictionary:
    return {
        "q": q, "r": r, "elevation": 0,
        "terrain": "grass", "movement_cost": 1, "blocked": false,
        "blocked_edges": [], "objects": []
    }

func _apply_tool_at(q: int, r: int) -> void:
    var before := _capture_editor_state()
    _apply_tool_at_without_history(q, r)
    if not history_action_active:
        _record_history(before)

func _apply_tool_at_without_history(q: int, r: int) -> void:
    var key := _cell_key(q, r)
    if active_tool == "camera":
        return
    if active_tool == "select_object":
        _select_object_at(q, r)
        return
    if active_tool == "add_hex":
        if not cells.has(key):
            cells[key] = _new_cell(q, r)
            board["cells"] = cells
            _rebuild_board()
        _clear_object_selection()
        selected_key = key
        _refresh_selection()
        _set_status("Hex %s installed. Paint, shape, or place objects." % key)
        return
    if active_tool == "remove_hex":
        _remove_hex_disk(q, r, 0)
        return
    if not cells.has(key):
        selected_key = ""
        _clear_object_selection()
        _refresh_selection()
        _set_status("Selection cleared. Lay a hex here first.")
        return
    if not active_tool.begins_with("prop:") and active_tool != "erase_prop":
        _clear_object_selection()
    selected_key = key
    var cell: Dictionary = cells[key]
    if active_tool.begins_with("terrain:"):
        var terrain := active_tool.trim_prefix("terrain:")
        var painted_count := 0
        for dq in range(-paint_brush_radius, paint_brush_radius + 1):
            for dr in range(-paint_brush_radius, paint_brush_radius + 1):
                if maxi(absi(dq), maxi(absi(dr), absi(dq + dr))) > paint_brush_radius:
                    continue
                var paint_key := _cell_key(q + dq, r + dr)
                if not cells.has(paint_key):
                    continue
                var paint_cell: Dictionary = cells[paint_key]
                paint_cell["terrain"] = terrain
                paint_cell["blocked"] = terrain == "water"
                paint_cell["movement_cost"] = 99 if bool(paint_cell["blocked"]) else (2 if terrain in ["woodland", "dirt", "stone", "sand", "marsh"] else 1)
                cells[paint_key] = paint_cell
                _refresh_cell_visual(paint_key)
                painted_count += 1
        board["cells"] = cells
        _set_status("%s painted on %d hexes." % [TERRAIN_LABELS[terrain], painted_count])
    elif active_tool == "raise" or active_tool == "lower":
        var delta := 1 if active_tool == "raise" else -1
        cell["elevation"] = clampi(int(cell.get("elevation", 0)) + delta, -4, 8)
        cells[key] = cell
        board["cells"] = cells
        _rebuild_board()
        _set_status("Hex %s elevation: %d" % [key, int(cell["elevation"])])
    elif active_tool.begins_with("prop:"):
        var kind := active_tool.trim_prefix("prop:")
        var objects: Array = cell.get("objects", []).duplicate(true)
        objects.append({"type": kind, "rotation": prop_rotation, "scale": 1.0, "offset_x": 0.0, "offset_z": 0.0})
        cell["objects"] = objects
        cells[key] = cell
        board["cells"] = cells
        selected_object_key = key
        selected_object_index = objects.size() - 1
        _refresh_cell_visual(key)
        _set_status("%s placed on hex %s. %d object(s) on this hex." % [kind.capitalize(), key, objects.size()])
    elif active_tool == "erase_prop":
        var objects: Array = cell.get("objects", []).duplicate(true)
        if not objects.is_empty():
            var remove_index := objects.size() - 1
            if selected_object_key == key and selected_object_index >= 0 and selected_object_index < objects.size():
                remove_index = selected_object_index
            objects.remove_at(remove_index)
        cell["objects"] = objects
        cells[key] = cell
        board["cells"] = cells
        _clear_object_selection()
        _refresh_cell_visual(key)
        _set_status("Object removed from hex %s." % key)
    _refresh_selection()

func _remove_hex_disk(q: int, r: int, radius: int) -> void:
    var removed := 0
    for key_value in cells.keys().duplicate():
        var cell: Dictionary = cells[key_value]
        var dq := int(cell.get("q", 0)) - q
        var dr := int(cell.get("r", 0)) - r
        if maxi(absi(dq), maxi(absi(dr), absi(dq + dr))) > radius:
            continue
        cells.erase(key_value)
        if cell_nodes.has(key_value):
            cell_nodes[key_value].free()
            cell_nodes.erase(key_value)
        if prop_nodes.has(key_value):
            prop_nodes[key_value].free()
            prop_nodes.erase(key_value)
        removed += 1
    board["cells"] = cells
    if not cells.has(selected_key):
        selected_key = ""
    if not cells.has(selected_object_key):
        _clear_object_selection()
    _rebuild_board()
    _set_status("Removed %d hexes." % removed)

func _capture_editor_state() -> Dictionary:
    return {
        "cells": cells.duplicate(true),
        "title": str(board.get("title", "New Board")),
        "id": str(board.get("id", "new_board"))
    }

func _record_history(before: Dictionary) -> void:
    if before.is_empty() or before.get("cells", {}) == cells:
        return
    undo_history.append(before)
    if undo_history.size() > HISTORY_LIMIT:
        undo_history.pop_front()
    redo_history.clear()
    _refresh_history_controls()

func _begin_history_action() -> void:
    if history_action_active:
        return
    history_action_active = true
    history_action_before = _capture_editor_state()

func _finish_history_action() -> void:
    if not history_action_active:
        return
    _record_history(history_action_before)
    history_action_before = {}
    history_action_active = false

func _restore_editor_state(state: Dictionary) -> void:
    cells = state.get("cells", {}).duplicate(true)
    board["cells"] = cells
    board["title"] = str(state.get("title", board.get("title", "New Board")))
    board["id"] = str(state.get("id", board.get("id", "new_board")))
    selected_key = ""
    _clear_object_selection()
    if board_name:
        board_name.text = str(board["title"])
    _rebuild_board()
    _refresh_history_controls()

func _undo() -> void:
    if undo_history.is_empty():
        return
    redo_history.append(_capture_editor_state())
    var previous: Dictionary = undo_history.pop_back()
    _restore_editor_state(previous)
    _set_status("Undid last board edit.")

func _redo() -> void:
    if redo_history.is_empty():
        return
    undo_history.append(_capture_editor_state())
    var next: Dictionary = redo_history.pop_back()
    _restore_editor_state(next)
    _set_status("Redid board edit.")

func _refresh_history_controls() -> void:
    if undo_button:
        undo_button.disabled = undo_history.is_empty()
    if redo_button:
        redo_button.disabled = redo_history.is_empty()

func _clear_selection() -> void:
    selected_key = ""
    _clear_object_selection()
    _refresh_selection()
    _set_status("Tile selection cleared.")

func _refresh_selection() -> void:
    var mesh := ImmediateMesh.new()
    if selected_key != "" and cells.has(selected_key):
        var cell: Dictionary = cells[selected_key]
        var center := _axial_to_world(int(cell.get("q", 0)), int(cell.get("r", 0)))
        center.y = float(cell.get("elevation", 0)) * ELEVATION_STEP + 0.045
        var material := StandardMaterial3D.new()
        material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        material.albedo_color = Color(1.0, 0.76, 0.28, 1.0)
        material.emission_enabled = true
        material.emission = Color(0.92, 0.46, 0.08)
        material.emission_energy_multiplier = 1.1
        mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
        for corner in range(6):
            var a := center + Vector3(cos(deg_to_rad(30.0 + 60.0 * corner)) * HEX_RADIUS, 0.0, sin(deg_to_rad(30.0 + 60.0 * corner)) * HEX_RADIUS)
            var b := center + Vector3(cos(deg_to_rad(30.0 + 60.0 * (corner + 1))) * HEX_RADIUS, 0.0, sin(deg_to_rad(30.0 + 60.0 * (corner + 1))) * HEX_RADIUS)
            mesh.surface_add_vertex(a)
            mesh.surface_add_vertex(b)
        mesh.surface_end()
    selection_outline.mesh = mesh

func _save_board() -> void:
    var title := board_name.text.strip_edges()
    if title == "":
        title = "New Board"
        board_name.text = title
    board["title"] = title
    board["cells"] = cells
    board["id"] = _slug(title)
    var named_board: Dictionary = board.duplicate(true)
    if not BOARD_SCRIPT.save_board(named_board):
        _set_status("Save failed. Check board data.")
        return
    var active_copy: Dictionary = board.duplicate(true)
    active_copy["id"] = "active_board"
    BOARD_SCRIPT.save_board(active_copy)
    _set_status("Saved '%s' with %d hexes." % [title, cells.size()])

func _slug(value: String) -> String:
    var output := ""
    var last_was_separator := false
    for character in value.to_lower():
        if character.is_valid_identifier() and character.length() == 1:
            output += character
            last_was_separator = false
        elif character == " " or character == "-" or character == "_":
            if not last_was_separator and not output.is_empty():
                output += "_"
                last_was_separator = true
    if output == "":
        return "new_board"
    return output.trim_suffix("_")

func _toggle_playtest() -> void:
    if is_playtesting:
        is_playtesting = false
        if player_piece and is_instance_valid(player_piece):
            player_piece.queue_free()
        player_piece = null
        palette_panel.visible = true
        play_button.text = "PLAY TEST"
        _set_status("Back in the board editor.")
        return
    if cells.is_empty():
        _set_status("Lay some hexes before play testing.")
        return
    _save_board()
    var start_key := _find_open_start()
    if start_key == "":
        _set_status("This board has no passable starting hex.")
        return
    is_playtesting = true
    palette_panel.visible = false
    play_button.text = "RETURN TO EDITOR"
    player_piece = _make_player_piece()
    add_child(player_piece)
    player_piece.position = _cell_world(start_key) + Vector3.UP * 0.18
    _set_status("Play test: move one adjacent hex per tap. Click RETURN TO EDITOR to edit.")

func _find_open_start() -> String:
    var candidates: Array[String] = []
    for key_value in cells.keys():
        var cell: Dictionary = cells[key_value]
        if not bool(cell.get("blocked", false)):
            candidates.append(str(key_value))
    if candidates.is_empty():
        return ""
    candidates.sort_custom(func(a: String, b: String) -> bool:
        return _cell_world(a).length_squared() < _cell_world(b).length_squared()
    )
    return candidates[0]

func _make_player_piece() -> Node3D:
    var root := Node3D.new()
    root.name = "PlaytestHero"
    var body := CapsuleMesh.new()
    body.radius = 0.22
    body.height = 0.85
    var gold := _standard_material(Color("e3bc67"), 0.42)
    _add_mesh(root, body, gold, Vector3.UP * 0.55)
    var base := CylinderMesh.new()
    base.top_radius = 0.37
    base.bottom_radius = 0.37
    base.height = 0.035
    base.radial_segments = 24
    _add_mesh(root, base, _standard_material(Color("523d23"), 0.58), Vector3.UP * 0.04)
    return root

func _find_open_start_key() -> String:
    return _find_open_start()

func _cell_world(key: String) -> Vector3:
    if not cells.has(key):
        return Vector3.ZERO
    var cell: Dictionary = cells[key]
    var pos := _axial_to_world(int(cell.get("q", 0)), int(cell.get("r", 0)))
    pos.y = float(cell.get("elevation", 0)) * ELEVATION_STEP
    return pos

func _move_playtest_to(key: String) -> void:
    if not cells.has(key):
        return
    var dest: Dictionary = cells[key]
    if bool(dest.get("blocked", false)):
        _set_status("That hex is impassable.")
        return
    var from_axial := _world_to_axial(Vector2(player_piece.position.x, player_piece.position.z))
    var to_axial := Vector2i(int(dest.get("q", 0)), int(dest.get("r", 0)))
    var distance := maxi(absi(to_axial.x - from_axial.x), maxi(absi(to_axial.y - from_axial.y), absi((to_axial.x - from_axial.x) + (to_axial.y - from_axial.y))))
    if distance != 1:
        _set_status("Choose an adjacent hex to keep the route connected.")
        return
    var goal := _cell_world(key) + Vector3.UP * 0.18
    var tween := create_tween()
    tween.tween_property(player_piece, "position", goal, 0.22)
    _set_status("Moved to %s." % key)

func _axial_at_screen(screen_position: Vector2) -> Vector2i:
    var origin := camera.project_ray_origin(screen_position)
    var direction := camera.project_ray_normal(screen_position)
    var closest_key := ""
    var best_distance := INF
    for key_value in cells.keys():
        var key := str(key_value)
        var center := _cell_world(key)
        var along_ray := (center - origin).dot(direction)
        if along_ray <= 0.0:
            continue
        var nearest := origin + direction * along_ray
        var distance_to_center := nearest.distance_to(center)
        if distance_to_center < best_distance:
            best_distance = distance_to_center
            closest_key = key
    if closest_key != "" and best_distance <= HEX_RADIUS * 0.82:
        var cell: Dictionary = cells[closest_key]
        return Vector2i(int(cell.get("q", 0)), int(cell.get("r", 0)))
    if absf(direction.y) < 0.0001:
        return Vector2i.ZERO
    var distance_to_ground := -origin.y / direction.y
    if distance_to_ground <= 0.0:
        return Vector2i.ZERO
    var point := origin + direction * distance_to_ground
    return _world_to_axial(Vector2(point.x, point.z))

func _select_from_screen(position: Vector2) -> void:
    var axial := _axial_at_screen(position)
    var key := _cell_key(axial.x, axial.y)
    if is_playtesting:
        _move_playtest_to(key)
    else:
        _apply_tool_at(axial.x, axial.y)

func _on_camera_distance_changed(value: float) -> void:
    camera_distance = value
    _update_camera()

func _on_camera_pitch_changed(value: float) -> void:
    camera_pitch_degrees = value
    _update_camera()

func _zoom_camera(distance_change: float) -> void:
    camera_distance = clampf(camera_distance + distance_change, 8.0, 70.0)
    if camera_distance_slider:
        camera_distance_slider.value = camera_distance
    _update_camera()

func _rotate_camera(amount: float) -> void:
    orbit_angle = wrapf(orbit_angle + amount, -PI, PI)
    _update_camera()

func _reset_camera() -> void:
    camera_target = Vector3.ZERO
    orbit_angle = 0.0
    camera_distance = 19.0
    camera_pitch_degrees = 55.0
    if camera_distance_slider:
        camera_distance_slider.value = camera_distance
    if camera_pitch_slider:
        camera_pitch_slider.value = camera_pitch_degrees
    _update_camera()
    _set_status("Camera reset to the board origin.")

func _frame_board() -> void:
    if cells.is_empty():
        _reset_camera()
        return
    var min_point := Vector3(INF, INF, INF)
    var max_point := Vector3(-INF, -INF, -INF)
    for key_value in cells.keys():
        var point := _cell_world(str(key_value))
        min_point = min_point.min(point)
        max_point = max_point.max(point)
    camera_target = (min_point + max_point) * 0.5
    var board_span := maxf(max_point.x - min_point.x, max_point.z - min_point.z)
    camera_distance = clampf(maxf(10.0, board_span * 1.65), 8.0, 70.0)
    if camera_distance_slider:
        camera_distance_slider.value = camera_distance
    _update_camera()
    _set_status("Camera framed to %d hexes." % cells.size())

func _update_camera() -> void:
    var pitch := deg_to_rad(camera_pitch_degrees)
    var horizontal_distance := cos(pitch) * camera_distance
    var vertical_distance := sin(pitch) * camera_distance
    camera.position = camera_target + Vector3(
        sin(orbit_angle) * horizontal_distance,
        vertical_distance,
        cos(orbit_angle) * horizontal_distance
    )
    camera.look_at(camera_target, Vector3.UP)

func _pan_camera(delta: Vector2) -> void:
    var basis := camera.global_transform.basis
    var right := Vector3(basis.x.x, 0.0, basis.x.z).normalized()
    var up := Vector3(basis.y.x, 0.0, basis.y.z).normalized()
    camera_target += -right * delta.x * camera_distance * 0.0015 + up * delta.y * camera_distance * 0.0015
    _update_camera()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                mouse_down = true
                mouse_dragged = false
                mouse_start = event.position
                if not is_playtesting:
                    _begin_history_action()
            elif mouse_down:
                mouse_down = false
                if not mouse_dragged:
                    _select_from_screen(event.position)
                last_stroke_key = ""
                _finish_history_action()
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            pan_dragging = event.pressed
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            camera_distance = clampf(camera_distance - 1.5, 8.0, 70.0)
            _update_camera()
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            camera_distance = clampf(camera_distance + 1.5, 8.0, 70.0)
            _update_camera()
    elif event is InputEventMouseMotion and pan_dragging:
        _pan_camera(event.relative)
    elif event is InputEventMouseMotion and mouse_down:
        if mouse_start.distance_to(event.position) > 7.0:
            mouse_dragged = true
        if mouse_dragged and active_tool == "camera":
            orbit_angle -= event.relative.x * 0.006
            _update_camera()
        elif mouse_dragged and not is_playtesting:
            var axial := _axial_at_screen(event.position)
            var key := _cell_key(axial.x, axial.y)
            if key != last_stroke_key:
                _apply_tool_at(axial.x, axial.y)
                last_stroke_key = key
    elif event is InputEventScreenTouch:
        if event.pressed:
            touches[event.index] = event.position
            if touches.size() == 1:
                touch_start = event.position
                touch_moved = false
                if not is_playtesting:
                    _begin_history_action()
            elif touches.size() == 2:
                var points: Array = touches.values()
                last_center = ((points[0] as Vector2) + (points[1] as Vector2)) * 0.5
                touch_moved = true
        else:
            var tapped := touches.size() == 1 and not touch_moved
            touches.erase(event.index)
            if tapped:
                _select_from_screen(event.position)
            if touches.is_empty():
                touch_moved = false
                last_stroke_key = ""
                _finish_history_action()
            last_pinch = 0.0
    elif event is InputEventScreenDrag:
        touches[event.index] = event.position
        if touches.size() == 1:
            if touch_start.distance_to(event.position) > 7.0:
                touch_moved = true
            if touch_moved and active_tool == "camera":
                orbit_angle -= event.relative.x * 0.006
                _update_camera()
            elif touch_moved and not is_playtesting:
                var axial := _axial_at_screen(event.position)
                var key := _cell_key(axial.x, axial.y)
                if key != last_stroke_key:
                    _apply_tool_at(axial.x, axial.y)
                    last_stroke_key = key
        elif touches.size() == 2:
            touch_moved = true
            var points: Array = touches.values()
            var pinch := (points[0] as Vector2).distance_to(points[1] as Vector2)
            var center := ((points[0] as Vector2) + (points[1] as Vector2)) * 0.5
            if last_pinch > 0.0:
                camera_distance = clampf(camera_distance - (pinch - last_pinch) * 0.04, 8.0, 70.0)
                _pan_camera(center - last_center)
            last_center = center
            last_pinch = pinch

func _update_object_visual(key: String, object_index: int) -> void:
    if not prop_nodes.has(key) or not is_instance_valid(prop_nodes[key]) or not cells.has(key):
        return
    var objects: Array = cells[key].get("objects", [])
    if object_index < 0 or object_index >= objects.size():
        return
    var object_data: Dictionary = objects[object_index]
    var root: Node3D = prop_nodes[key]
    var visual := root.get_node_or_null("PlacedObject_%d" % object_index) as Node3D
    if visual:
        visual.position = Vector3(float(object_data.get("offset_x", 0.0)), 0.0, float(object_data.get("offset_z", 0.0)))
        visual.rotation.y = float(object_data.get("rotation", 0.0))
        var type_scale := 1.28 if str(object_data.get("type", "")) == "ancient_tree" else 1.0
        visual.scale = Vector3.ONE * clampf(float(object_data.get("scale", 1.0)), 0.45, 1.8) * type_scale
    var marker := root.get_node_or_null("SelectedObjectMarker") as MeshInstance3D
    if marker and selected_object_key == key and selected_object_index == object_index:
        marker.position = Vector3(float(object_data.get("offset_x", 0.0)), 0.025, float(object_data.get("offset_z", 0.0)))

func _clear_object_selection() -> void:
    var previous_key := selected_object_key
    selected_object_key = ""
    selected_object_index = -1
    if previous_key != "" and cells.has(previous_key):
        _refresh_cell_visual(previous_key)

func _select_object_at(q: int, r: int) -> void:
    var key := _cell_key(q, r)
    if not cells.has(key):
        _clear_object_selection()
        selected_key = ""
        _refresh_selection()
        _set_status("No hex or object at this location.")
        return
    selected_key = key
    var objects: Array = cells[key].get("objects", [])
    if objects.is_empty():
        _clear_object_selection()
        _refresh_cell_visual(key)
        _refresh_selection()
        _set_status("This hex has no objects. Place one first.")
        return
    if selected_object_key == key and selected_object_index >= 0 and selected_object_index < objects.size():
        selected_object_index = (selected_object_index + 1) % objects.size()
    else:
        selected_object_key = key
        selected_object_index = objects.size() - 1
    _refresh_cell_visual(key)
    _refresh_selection()
    _set_status("Selected object %d of %d on hex %s." % [selected_object_index + 1, objects.size(), key])

func _cycle_selected_object() -> void:
    if selected_object_key == "" or not cells.has(selected_object_key):
        _set_status("Select an object on a hex first.")
        return
    var objects: Array = cells[selected_object_key].get("objects", [])
    if objects.is_empty():
        _clear_object_selection()
        _set_status("No objects remain on this hex.")
        return
    selected_object_index = (selected_object_index + 1) % objects.size()
    _refresh_cell_visual(selected_object_key)
    _set_status("Selected object %d of %d." % [selected_object_index + 1, objects.size()])

func _nudge_selected_object(offset: Vector2) -> void:
    if selected_object_key == "" or not cells.has(selected_object_key):
        _set_status("Select an object before moving it.")
        return
    var objects: Array = cells[selected_object_key].get("objects", []).duplicate(true)
    if selected_object_index < 0 or selected_object_index >= objects.size():
        _clear_object_selection()
        _set_status("Selected object is no longer available.")
        return
    var before := _capture_editor_state()
    var object_data: Dictionary = objects[selected_object_index]
    var next_x := clampf(float(object_data.get("offset_x", 0.0)) + offset.x, -0.62, 0.62)
    var next_z := clampf(float(object_data.get("offset_z", 0.0)) + offset.y, -0.62, 0.62)
    object_data["offset_x"] = next_x
    object_data["offset_z"] = next_z
    objects[selected_object_index] = object_data
    var cell: Dictionary = cells[selected_object_key]
    cell["objects"] = objects
    cells[selected_object_key] = cell
    board["cells"] = cells
    _update_object_visual(selected_object_key, selected_object_index)
    _record_history(before)
    _set_status("Object position: X %.2f, Z %.2f." % [next_x, next_z])

func _rotate_prop(amount: float) -> void:
    if selected_object_key != "" and cells.has(selected_object_key):
        var objects: Array = cells[selected_object_key].get("objects", []).duplicate(true)
        if selected_object_index >= 0 and selected_object_index < objects.size():
            var before := _capture_editor_state()
            var object_data: Dictionary = objects[selected_object_index]
            var rotation := wrapf(float(object_data.get("rotation", 0.0)) + amount, -PI, PI)
            object_data["rotation"] = rotation
            objects[selected_object_index] = object_data
            var cell: Dictionary = cells[selected_object_key]
            cell["objects"] = objects
            cells[selected_object_key] = cell
            board["cells"] = cells
            _update_object_visual(selected_object_key, selected_object_index)
            _record_history(before)
            _set_status("Selected object rotated to %d°." % int(rad_to_deg(rotation)))
            return
    prop_rotation = wrapf(prop_rotation + amount, -PI, PI)
    _set_status("New prop rotation: %d°." % int(rad_to_deg(prop_rotation)))
    
func _back_to_world() -> void:
    get_tree().change_scene_to_file("res://scenes/FrontEnd.tscn")
