extends Node3D

const BOARD_SCRIPT := preload("res://scripts/board_definition.gd")
const TERRAIN_SHADER := preload("res://shaders/hex_terrain.gdshader")
const GRASS_ALBEDO := preload("res://assets/terrain/ravenwood/grass_albedo.jpg")
const WOODLAND_ALBEDO := preload("res://assets/terrain/ravenwood/woodland_albedo.jpg")
const DIRT_ALBEDO := preload("res://assets/terrain/ravenwood/dirt_albedo.jpg")
const STONE_ALBEDO := preload("res://assets/terrain/ravenwood/stone_albedo.jpg")
const SAND_ALBEDO := preload("res://assets/terrain/ravenwood/sand_albedo.jpg")
const MARSH_ALBEDO := preload("res://assets/terrain/ravenwood/marsh_albedo.jpg")
const PROP_WOOD_ALBEDO := preload("res://assets/props/materials/weathered_wood.jpg")
const PROP_BARK_ALBEDO := preload("res://assets/props/materials/bark.jpg")
const PROP_STONE_ALBEDO := preload("res://assets/props/materials/masonry.jpg")
const PROP_PLASTER_ALBEDO := preload("res://assets/props/materials/aged_plaster.jpg")
const PROP_ROOF_ALBEDO := preload("res://assets/props/materials/clay_roof.jpg")
const PROP_THATCH_ALBEDO := preload("res://assets/props/materials/thatch.jpg")
const PROP_WEATHERED_WOOD_NORMAL := preload("res://assets/props/materials/weathered_wood_normal.jpg")
const PROP_WEATHERED_WOOD_ROUGHNESS := preload("res://assets/props/materials/weathered_wood_roughness.jpg")
const PROP_BARK_NORMAL := preload("res://assets/props/materials/bark_normal.jpg")
const PROP_BARK_ROUGHNESS := preload("res://assets/props/materials/bark_roughness.jpg")
const PROP_MASONRY_NORMAL := preload("res://assets/props/materials/masonry_normal.jpg")
const PROP_MASONRY_ROUGHNESS := preload("res://assets/props/materials/masonry_roughness.jpg")
const PROP_AGED_PLASTER_NORMAL := preload("res://assets/props/materials/aged_plaster_normal.jpg")
const PROP_AGED_PLASTER_ROUGHNESS := preload("res://assets/props/materials/aged_plaster_roughness.jpg")
const PROP_CLAY_ROOF_NORMAL := preload("res://assets/props/materials/clay_roof_normal.jpg")
const PROP_CLAY_ROOF_ROUGHNESS := preload("res://assets/props/materials/clay_roof_roughness.jpg")
const PROP_THATCH_NORMAL := preload("res://assets/props/materials/thatch_normal.jpg")
const PROP_THATCH_ROUGHNESS := preload("res://assets/props/materials/thatch_roughness.jpg")
const BOARD_DIR := "user://boards/"
const ACTIVE_PATH := "user://boards/active_board.board.json"
const HEX_RADIUS := 1.0
const ROOT_3 := 1.7320508
const ELEVATION_STEP := 0.22
const TILE_DEPTH := 0.28
const CLIFF_SOURCE_PROFILE_B64 := "co3HzYl5iGMoGnSFco/KzYp/gWMqK3OJaJfR0oh+jV0pDoKJc4jQ0359kGAoG3mNZ5rZ1HiCj2wPF36NWpzZ1neEjm0QHXqNbKDY4GKFjnsBMnqXcqDd4mOFinYBOXuWZq/o4nGAkn8SSYSaZrDo5W+AkIASSHuaZ6bxzXV5mEkSP4uHZ6fxw3d6k0YTP4yGX5H1x3JwmEkTIY+NY5H0nXRymSgUII6MW5D5u3J6lTsOJYWOXJPyrHN7lDsQJoWN"
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
var mountain_sources: Array[Dictionary] = []
var shared_hex_mesh: ArrayMesh
var board_foundation_y := -TILE_DEPTH
var prop_materials: Dictionary = {}
var _cliff_noise: FastNoiseLite
var _cliff_source_profile := PackedByteArray()
var selection_marker_material: StandardMaterial3D
var terrain_grass_mesh: ArrayMesh
var terrain_grass_material: StandardMaterial3D
var terrain_flower_mesh: SphereMesh
var terrain_flower_material: StandardMaterial3D
var board_name: LineEdit
var status_label: Label
var brush_radius_option: OptionButton
var paint_brush_option: OptionButton
var scatter_radius_option: OptionButton
var scatter_density_option: OptionButton
var scatter_brush_radius := 1
var scatter_density := 2
var scatter_nonce := 0
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
var wall_run_last_cell := Vector2i.ZERO
var wall_run_has_anchor := false
var selected_key := ""
var selected_object_key := ""
var selected_object_index := -1
var editor_layer := "terrain"
var last_world_tap_time_msec := -1000
var last_world_tap_position := Vector2(-10000.0, -10000.0)
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
        material.set_shader_parameter("grass_albedo", GRASS_ALBEDO)
        material.set_shader_parameter("woodland_albedo", WOODLAND_ALBEDO)
        material.set_shader_parameter("dirt_albedo", DIRT_ALBEDO)
        material.set_shader_parameter("stone_albedo", STONE_ALBEDO)
        material.set_shader_parameter("sand_albedo", SAND_ALBEDO)
        material.set_shader_parameter("marsh_albedo", MARSH_ALBEDO)
        terrain_materials[terrain] = material
    prop_materials["bark"] = _standard_material(Color("60412b"), 0.92)
    prop_materials["bark_light"] = _standard_material(Color("8a623b"), 0.9)
    prop_materials["leaf_dark"] = _standard_material(Color("28502d"), 0.92)
    prop_materials["leaf_mid"] = _standard_material(Color("477f3c"), 0.9)
    prop_materials["leaf_light"] = _standard_material(Color("76a94c"), 0.88)
    prop_materials["roof"] = _standard_material(Color("49332c"), 0.91)
    prop_materials["wall"] = _standard_material(Color("a18a60"), 0.9)
    prop_materials["wood"] = _standard_material(Color("765335"), 0.92)
    prop_materials["stone"] = _standard_material(Color("77796e"), 0.96)
    prop_materials["stone_light"] = _standard_material(Color("a19d8c"), 0.94)
    prop_materials["stone_dark"] = _standard_material(Color("535750"), 0.98)
    var cliff_material := StandardMaterial3D.new()
    cliff_material.albedo_color = Color(0.86, 0.81, 0.71)
    cliff_material.roughness = 0.98
    cliff_material.vertex_color_use_as_albedo = true
    cliff_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    prop_materials["cliff"] = cliff_material
    prop_materials["plaster"] = _standard_material(Color("c8b994"), 0.94)
    prop_materials["plaster_light"] = _standard_material(Color("ddd0ae"), 0.93)
    prop_materials["roof_red"] = _standard_material(Color("783d32"), 0.91)
    prop_materials["thatch"] = _standard_material(Color("9a7843"), 0.95)
    prop_materials["roof_moss"] = _standard_material(Color("48573d"), 0.94)
    prop_materials["brick"] = _standard_material(Color("895340"), 0.95)
    prop_materials["wood_dark"] = _standard_material(Color("49331f"), 0.96)
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
    _apply_prop_texture(["wood", "wood_dark", "bark_light"], PROP_WOOD_ALBEDO, Color("e8d8bd"), Vector3(1.7, 1.7, 1.7), PROP_WEATHERED_WOOD_NORMAL, PROP_WEATHERED_WOOD_ROUGHNESS, 0.32)
    _apply_prop_texture(["bark"], PROP_BARK_ALBEDO, Color("d9c7a8"), Vector3(2.2, 2.2, 2.2), PROP_BARK_NORMAL, PROP_BARK_ROUGHNESS, 0.40)
    _apply_prop_texture(["stone", "stone_light", "stone_dark", "brick"], PROP_STONE_ALBEDO, Color("ded9ca"), Vector3(1.9, 1.9, 1.9), PROP_MASONRY_NORMAL, PROP_MASONRY_ROUGHNESS, 0.30)
    _apply_prop_texture(["wall", "plaster", "plaster_light"], PROP_PLASTER_ALBEDO, Color("eee2c8"), Vector3(1.6, 1.6, 1.6), PROP_AGED_PLASTER_NORMAL, PROP_AGED_PLASTER_ROUGHNESS, 0.24)
    _apply_prop_texture(["roof", "roof_red", "roof_moss"], PROP_ROOF_ALBEDO, Color("e1d0ba"), Vector3(1.8, 1.8, 1.8), PROP_CLAY_ROOF_NORMAL, PROP_CLAY_ROOF_ROUGHNESS, 0.30)
    _apply_prop_texture(["thatch"], PROP_THATCH_ALBEDO, Color("e8d4a7"), Vector3(2.0, 2.0, 2.0), PROP_THATCH_NORMAL, PROP_THATCH_ROUGHNESS, 0.34)
    prop_materials["stone"].vertex_color_use_as_albedo = true
    terrain_grass_mesh = _make_grass_clump_mesh()
    terrain_grass_material = StandardMaterial3D.new()
    terrain_grass_material.vertex_color_use_as_albedo = true
    terrain_grass_material.roughness = 1.0
    terrain_grass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    terrain_flower_mesh = SphereMesh.new()
    terrain_flower_mesh.radial_segments = 8
    terrain_flower_mesh.rings = 5
    terrain_flower_material = StandardMaterial3D.new()
    terrain_flower_material.vertex_color_use_as_albedo = true
    terrain_flower_material.roughness = 0.82
    selection_marker_material = _standard_material(Color("ffd16b"), 0.35)
    selection_marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    selection_marker_material.emission_enabled = true
    selection_marker_material.emission = Color("e6a53c")
    selection_marker_material.emission_energy_multiplier = 1.3

func _apply_prop_texture(material_keys: Array, texture: Texture2D, tint: Color, texture_scale: Vector3, normal_map: Texture2D, roughness_map: Texture2D, normal_strength: float) -> void:
    for material_key in material_keys:
        var material: StandardMaterial3D = prop_materials[material_key]
        material.albedo_texture = texture
        material.albedo_color = tint
        material.normal_texture = normal_map
        material.normal_enabled = true
        material.normal_scale = normal_strength
        material.roughness_texture = roughness_map
        material.uv1_triplanar = true
        material.uv1_triplanar_sharpness = 8.0
        material.uv1_scale = texture_scale

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

    var layer_tabs := TabContainer.new()
    layer_tabs.name = "EditorLayers"
    layer_tabs.custom_minimum_size.y = 420.0
    layer_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_child(layer_tabs)
    layer_tabs.tab_changed.connect(_on_editor_layer_changed)

    var terrain_page := VBoxContainer.new()
    terrain_page.name = "TERRAIN"
    terrain_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    layer_tabs.add_child(terrain_page)
    _add_section(terrain_page, "1  •  LAY HEXES")
    _add_button(terrain_page, "ADD HEX", func(): _set_tool("add_hex"))
    _add_button(terrain_page, "REMOVE HEX", func(): _set_tool("remove_hex"))
    var brush_row := HBoxContainer.new()
    terrain_page.add_child(brush_row)
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
    _add_button(terrain_page, "LAY HEX DISK", _lay_hex_disk)

    _add_section(terrain_page, "2  •  PAINT TERRAIN")
    for terrain in ["grass", "woodland", "dirt", "stone", "sand", "marsh"]:
        _add_button(terrain_page, TERRAIN_LABELS[terrain], func(): _set_tool("terrain:" + terrain))
    var paint_row := HBoxContainer.new()
    terrain_page.add_child(paint_row)
    var paint_label := Label.new()
    paint_label.text = "TERRAIN BRUSH RADIUS"
    paint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    paint_row.add_child(paint_label)
    paint_brush_option = OptionButton.new()
    for radius in range(0, 5):
        paint_brush_option.add_item(str(radius))
    paint_brush_option.select(0)
    paint_brush_option.item_selected.connect(_on_paint_brush_changed)
    paint_row.add_child(paint_brush_option)

    _add_section(terrain_page, "3  •  SHAPE TERRAIN")
    _add_button(terrain_page, "RAISE HEX", func(): _set_tool("raise"))
    _add_button(terrain_page, "LOWER HEX", func(): _set_tool("lower"))
    _add_button(terrain_page, "PEAK CLUSTER", func(): _set_tool("mountain_peak"))
    _add_section(terrain_page, "RIDGE DIRECTION")
    var ridge_row := HBoxContainer.new()
    terrain_page.add_child(ridge_row)
    _add_button(ridge_row, "↗", func(): _set_tool("mountain_ridge:1"))
    _add_button(ridge_row, "→", func(): _set_tool("mountain_ridge:0"))
    _add_button(ridge_row, "↘", func(): _set_tool("mountain_ridge:2"))
    _add_button(terrain_page, "FOOTHILLS", func(): _set_tool("mountain_foothill"))
    _add_button(terrain_page, "CLEAR MOUNTAIN FORM", func(): _set_tool("clear_mountain"))
    _add_button(terrain_page, "TOGGLE PASSABILITY", func(): _set_tool("toggle_passable"))

    var object_page := VBoxContainer.new()
    object_page.name = "OBJECTS"
    object_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    layer_tabs.add_child(object_page)
    _add_section(object_page, "4  •  NATURE & DETAILS")
    for prop in [
        ["tree", "TREE"], ["pine", "PINE"], ["ancient_tree", "ANCIENT OAK"], ["dead_tree", "DEAD TREE"],
        ["rock", "ROCK"], ["bush", "BUSH"], ["stump", "STUMP"], ["log", "FALLEN LOG"],
        ["campfire", "CAMPFIRE"], ["lantern", "LANTERN"], ["signpost", "SIGNPOST"], ["well", "WELL"],
        ["ruins", "RUINS"], ["flowers", "FLOWERS"], ["mushrooms", "MUSHROOMS"]
    ]:
        var prop_id: String = prop[0]
        _add_button(object_page, str(prop[1]), func(): _set_tool("prop:" + prop_id))
    _add_section(object_page, "BUILDINGS")
    for building in [
        ["house", "HOUSE"], ["cottage", "COTTAGE"], ["longhouse", "LONGHOUSE"], ["barn", "BARN"],
        ["inn", "INN / TAVERN"], ["smithy", "BLACKSMITH"], ["chapel", "CHAPEL"],
        ["watchtower", "WATCHTOWER"], ["ruined_house", "RUINED HOUSE"]
    ]:
        var building_id: String = building[0]
        _add_button(object_page, str(building[1]), func(): _set_tool("prop:" + building_id))
    _add_section(object_page, "SNAPPED WALL RUNS")
    _add_button(object_page, "STONE WALL RUN", func(): _set_tool("wall_run:stone_wall"))
    _add_button(object_page, "PALISADE RUN", func(): _set_tool("wall_run:palisade_wall"))
    _add_button(object_page, "FENCE RUN", func(): _set_tool("wall_run:fence"))
    _add_button(object_page, "START NEW RUN", _start_new_wall_run)
    _add_section(object_page, "WALLS & GATES")
    for fortification in [
        ["stone_wall", "STONE WALL"], ["palisade_wall", "PALISADE WALL"],
        ["wooden_gate", "WOODEN GATE"], ["stone_gate", "STONE GATE"], ["fence", "SINGLE FENCE"]
    ]:
        var fortification_id: String = fortification[0]
        _add_button(object_page, str(fortification[1]), func(): _set_tool("prop:" + fortification_id))
    _add_button(object_page, "SELECT / MOVE OBJECT", func(): _set_tool("select_object"))
    _add_button(object_page, "NEXT OBJECT ON HEX", _cycle_selected_object)
    _add_button(object_page, "ERASE SELECTED / LAST", func(): _set_tool("erase_prop"))
    _add_section(object_page, "5  •  PAINT ENVIRONMENT")
    var scatter_controls := HBoxContainer.new()
    object_page.add_child(scatter_controls)
    var scatter_radius_label := Label.new()
    scatter_radius_label.text = "RADIUS"
    scatter_radius_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scatter_controls.add_child(scatter_radius_label)
    scatter_radius_option = OptionButton.new()
    for radius in range(0, 5):
        scatter_radius_option.add_item(str(radius))
    scatter_radius_option.select(1)
    scatter_radius_option.item_selected.connect(_on_scatter_radius_changed)
    scatter_controls.add_child(scatter_radius_option)
    var density_controls := HBoxContainer.new()
    object_page.add_child(density_controls)
    var density_label := Label.new()
    density_label.text = "OBJECTS / HEX"
    density_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    density_controls.add_child(density_label)
    scatter_density_option = OptionButton.new()
    for density in range(1, 5):
        scatter_density_option.add_item(str(density))
    scatter_density_option.select(1)
    scatter_density_option.item_selected.connect(_on_scatter_density_changed)
    density_controls.add_child(scatter_density_option)
    _add_button(object_page, "WOODLAND CLUSTER", func(): _set_tool("scatter:forest"))
    _add_button(object_page, "ROCKY DEBRIS", func(): _set_tool("scatter:rocky"))
    _add_button(object_page, "MARSH UNDERGROWTH", func(): _set_tool("scatter:marsh"))
    _add_button(object_page, "DEADFALL", func(): _set_tool("scatter:deadfall"))
    var rotate_row := HBoxContainer.new()
    object_page.add_child(rotate_row)
    _add_button(rotate_row, "ROTATE −", func(): _rotate_prop(-PI / 6.0))
    _add_button(rotate_row, "ROTATE +", func(): _rotate_prop(PI / 6.0))
    var nudge_row_x := HBoxContainer.new()
    object_page.add_child(nudge_row_x)
    _add_button(nudge_row_x, "X −", func(): _nudge_selected_object(Vector2(-0.12, 0.0)))
    _add_button(nudge_row_x, "X +", func(): _nudge_selected_object(Vector2(0.12, 0.0)))
    var nudge_row_z := HBoxContainer.new()
    object_page.add_child(nudge_row_z)
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

func _on_scatter_radius_changed(index: int) -> void:
    scatter_brush_radius = index
    _set_status("Environment brush radius: %d hexes." % scatter_brush_radius)

func _on_scatter_density_changed(index: int) -> void:
    scatter_density = index + 1
    _set_status("Environment density: %d objects per hex." % scatter_density)

func _on_editor_layer_changed(tab_index: int) -> void:
    if tab_index == 1:
        editor_layer = "objects"
        if not active_tool.begins_with("prop:") and not active_tool.begins_with("wall_run:") and not active_tool.begins_with("scatter:") and active_tool != "select_object" and active_tool != "erase_prop":
            _set_tool("select_object")
        _set_status("OBJECT LAYER • place, select, move, rotate, and erase props.")
    else:
        editor_layer = "terrain"
        if active_tool.begins_with("prop:") or active_tool.begins_with("wall_run:") or active_tool.begins_with("scatter:") or active_tool == "select_object" or active_tool == "erase_prop":
            _set_tool("add_hex")
        _set_status("TERRAIN LAYER • install hexes, paint surfaces, shape elevation, and sculpt mountains.")

func _set_tool(tool_id: String) -> void:
    if tool_id != active_tool or not tool_id.begins_with("wall_run:"):
        _reset_wall_run()
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
    material.albedo_color = Color(0.80, 0.70, 0.52, 0.24)
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
    _rebuild_mountain_sources()
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
    var landform := str(cell.get("landform", ""))
    var has_mountain := landform in ["mountain", "peak", "ridge", "foothill"]
    tile.mesh = _make_mountain_mesh(cell) if has_mountain else shared_hex_mesh
    tile.material_override = terrain_materials["stone"] if has_mountain else terrain_materials[terrain]
    tile.position = _axial_to_world(int(cell.get("q", 0)), int(cell.get("r", 0)))
    tile.position.y = float(cell.get("elevation", 0)) * ELEVATION_STEP
    cell_layer.add_child(tile)
    cell_nodes[key] = tile
    var wall_mesh := _make_hex_wall_mesh(cell)
    if wall_mesh:
        var walls := MeshInstance3D.new()
        walls.name = "ExposedHexWalls"
        walls.mesh = wall_mesh
        walls.material_override = prop_materials["cliff"]
        tile.add_child(walls)
    if not has_mountain:
        _build_terrain_dressing(tile, terrain, int(cell.get("q", 0)), int(cell.get("r", 0)))
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
            prop.position = Vector3(float(object_data.get("offset_x", 0.0)), float(object_data.get("offset_y", 0.0)), float(object_data.get("offset_z", 0.0)))
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

func _add_mountain_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
    # Reverse the ring order so generated normals face outward/upward.
    surface.add_vertex(a)
    surface.add_vertex(c)
    surface.add_vertex(b)

func _rebuild_mountain_sources() -> void:
    mountain_sources.clear()
    for cell_value in cells.values():
        var cell: Dictionary = cell_value
        var form := str(cell.get("landform", ""))
        if form not in ["mountain", "peak", "ridge", "foothill"]:
            continue
        var center := _axial_to_world(int(cell.get("q", 0)), int(cell.get("r", 0)))
        var axis_angle := deg_to_rad(float(posmod(int(cell.get("landform_axis", 0)), 3)) * 60.0)
        mountain_sources.append({
            "center": Vector2(center.x, center.z),
            "form": "peak" if form == "mountain" else form,
            "axis": Vector2(cos(axis_angle), sin(axis_angle))
        })

func _mountain_height_at(world_point: Vector2) -> float:
    var height := 0.0
    for source in mountain_sources:
        var delta: Vector2 = world_point - source["center"]
        if delta.length_squared() > 64.0:
            continue
        var form := str(source["form"])
        var contribution := 0.0
        if form == "ridge":
            var axis: Vector2 = source["axis"]
            var along := delta.dot(axis)
            var across := delta.dot(Vector2(-axis.y, axis.x))
            contribution = 1.48 * exp(-across * across * 2.4) * exp(-along * along * 0.13)
        elif form == "foothill":
            contribution = 0.46 * exp(-delta.length_squared() * 0.78)
        else:
            contribution = 1.72 * exp(-delta.length_squared() * 2.35)
        height = maxf(height, contribution)
    if height <= 0.001:
        return 0.0
    var rock_noise := sin(world_point.x * 8.7 + world_point.y * 5.9) * cos(world_point.y * 9.8 - world_point.x * 3.1)
    return maxf(0.0, height + rock_noise * 0.045 * minf(height, 1.0))

func _make_mountain_mesh(cell: Dictionary) -> ArrayMesh:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var center_world := _axial_to_world(int(cell.get("q", 0)), int(cell.get("r", 0)))
    var segment_count := 24
    var radial_steps := 6
    var rings: Array[Array] = []
    for radial_step in range(1, radial_steps + 1):
        var radial := float(radial_step) / float(radial_steps)
        var ring: Array[Vector3] = []
        for segment in range(segment_count):
            var angle := deg_to_rad(30.0) + TAU * float(segment) / float(segment_count)
            var nearest_face_normal := roundf(angle / (PI / 3.0)) * (PI / 3.0)
            var boundary_radius := (ROOT_3 * 0.5) / cos(angle - nearest_face_normal)
            var x := cos(angle) * boundary_radius * radial
            var z := sin(angle) * boundary_radius * radial
            var world_point := Vector2(center_world.x + x, center_world.z + z)
            ring.append(Vector3(x, _mountain_height_at(world_point), z))
        rings.append(ring)

    var center := Vector3(0.0, _mountain_height_at(Vector2(center_world.x, center_world.z)), 0.0)
    var first_ring: Array[Vector3] = rings[0]
    for segment in range(segment_count):
        var next := (segment + 1) % segment_count
        _add_mountain_triangle(surface, center, first_ring[segment], first_ring[next])
    for ring_index in range(rings.size() - 1):
        var inner_ring: Array[Vector3] = rings[ring_index]
        var outer_ring: Array[Vector3] = rings[ring_index + 1]
        for segment in range(segment_count):
            var next := (segment + 1) % segment_count
            _add_mountain_triangle(surface, inner_ring[segment], outer_ring[segment], inner_ring[next])
            _add_mountain_triangle(surface, outer_ring[segment], outer_ring[next], inner_ring[next])
    surface.generate_normals()
    return surface.commit()

func _init_cliff_noise() -> void:
    if _cliff_noise == null:
        _cliff_noise = FastNoiseLite.new()
        _cliff_noise.seed = 1337
        _cliff_noise.frequency = 0.18
        _cliff_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
        _cliff_noise.fractal_octaves = 2
    if _cliff_source_profile.is_empty():
        # 24 x 8 outer-rock relief sampled from the uploaded floating-island mesh.
        _cliff_source_profile = Marshalls.base64_to_raw(CLIFF_SOURCE_PROFILE_B64)


func _cliff_noise_at(local_pos: Vector3, center_world: Vector3, tile_height: float) -> float:
    var world_pos := Vector3(center_world.x + local_pos.x, tile_height + local_pos.y, center_world.z + local_pos.z)
    return _cliff_noise.get_noise_3d(world_pos.x * 1.5, world_pos.y, world_pos.z * 1.5)


func _sample_source_cliff_relief(across: float, height_ratio: float, phase: int) -> float:
    var angular_offset := roundi((across - 0.5) * 4.0)
    var angle_index := posmod(phase + angular_offset, 24)
    var height_index := clampi(roundi(height_ratio * 7.0), 0, 7)
    var packed_value := int(_cliff_source_profile[height_index * 24 + angle_index])
    return float(packed_value - 128) / 127.0 * 0.15


func _displace_cliff_angular(local_pos: Vector3, face_normal: Vector3, across: float, height_ratio: float, source_relief: float, center_world: Vector3, tile_height: float) -> Vector3:
    var noise_value := _cliff_noise_at(local_pos, center_world, tile_height)
    var stepped_noise := floorf(noise_value * 4.0) / 4.0
    # Anchor the cap/base and shared hex corners; transfer the island mesh's broad rock bulges between those seams.
    var side_fade := clampf(minf(across, 1.0 - across) / 0.17, 0.0, 1.0)
    var height_fade := sin(height_ratio * PI)
    var fade := side_fade * height_fade
    var radial_offset := (source_relief + stepped_noise * 0.34) * fade
    var vertical_offset := (source_relief * 0.24 + signf(stepped_noise) * stepped_noise * stepped_noise * 0.16) * fade
    return local_pos + face_normal * radial_offset + Vector3.UP * vertical_offset


func _get_facet_color(pos: Vector3, normal: Vector3, center_world: Vector3, tile_height: float) -> Color:
    var light_dir := Vector3(-0.38, 0.78, 0.50).normalized()
    var light_factor := clampf(0.44 + maxf(normal.dot(light_dir), 0.0) * 0.64, 0.25, 1.0)
    var world_pos := Vector3(center_world.x + pos.x, tile_height + pos.y, center_world.z + pos.z)
    var color_noise := _cliff_noise.get_noise_3d(world_pos.x * 0.42, world_pos.y * 0.32, world_pos.z * 0.42) * 0.13
    var base_rock := Color(0.43, 0.39, 0.34, 1.0)
    var shadow_rock := Color(0.09, 0.085, 0.078, 1.0)
    return shadow_rock.lerp(base_rock, clampf(light_factor + color_noise, 0.20, 1.0))


func _add_angular_cliff_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, face_normal: Vector3, center_world: Vector3, tile_height: float) -> void:
    var normal := (b - a).cross(c - a).normalized()
    if normal.dot(face_normal) < 0.0:
        normal = -normal
    var color := _get_facet_color((a + b + c) / 3.0, normal, center_world, tile_height)
    surface.set_normal(normal)
    surface.set_color(color)
    surface.add_vertex(a)
    surface.set_normal(normal)
    surface.set_color(color)
    surface.add_vertex(b)
    surface.set_normal(normal)
    surface.set_color(color)
    surface.add_vertex(c)


func _add_angular_cliff_face(surface: SurfaceTool, top_a: Vector3, top_b: Vector3, bottom_y: float, face_normal: Vector3, center_world: Vector3, tile_height: float, phase: int) -> void:
    var total_height := maxf(0.02, ((top_a.y - bottom_y) + (top_b.y - bottom_y)) * 0.5)
    # Sample the imported 24 x 8 rock relief into a modest triangulated face grid.
    var rows := clampi(ceili(total_height / 0.24), 3, 5)
    var columns := 4
    var points: Array[Array] = []

    for row in range(rows + 1):
        var row_points: Array[Vector3] = []
        for column in range(columns + 1):
            var across := float(column) / float(columns)
            var height_ratio := float(row) / float(rows)
            if column > 0 and column < columns:
                var jitter_sample := _cliff_noise_at(top_a.lerp(top_b, across), center_world, tile_height)
                across += jitter_sample * 0.035
            if row > 0 and row < rows:
                var height_sample := _cliff_noise_at(top_a.lerp(top_b, across), center_world, tile_height)
                height_ratio += height_sample * 0.07
            across = clampf(across, 0.03, 0.97)
            height_ratio = clampf(height_ratio, 0.03, 0.97)
            if column == 0:
                across = 0.0
            elif column == columns:
                across = 1.0
            if row == 0:
                height_ratio = 0.0
            elif row == rows:
                height_ratio = 1.0

            var top_point := top_a.lerp(top_b, across)
            var point := Vector3(top_point.x, lerpf(bottom_y, top_point.y, height_ratio), top_point.z)
            var source_relief := _sample_source_cliff_relief(across, height_ratio, phase)
            point = _displace_cliff_angular(point, face_normal, across, height_ratio, source_relief, center_world, tile_height)
            row_points.append(point)
        points.append(row_points)

    for row in range(rows):
        for column in range(columns):
            var a: Vector3 = points[row][column]
            var b: Vector3 = points[row][column + 1]
            var c: Vector3 = points[row + 1][column]
            var d: Vector3 = points[row + 1][column + 1]
            if (row + column) % 2 == 0:
                _add_angular_cliff_triangle(surface, a, c, d, face_normal, center_world, tile_height)
                _add_angular_cliff_triangle(surface, a, d, b, face_normal, center_world, tile_height)
            else:
                _add_angular_cliff_triangle(surface, a, c, b, face_normal, center_world, tile_height)
                _add_angular_cliff_triangle(surface, b, c, d, face_normal, center_world, tile_height)


func _make_hex_wall_mesh(cell: Dictionary) -> ArrayMesh:
    _init_cliff_noise()
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var q := int(cell.get("q", 0))
    var r := int(cell.get("r", 0))
    var elevation := int(cell.get("elevation", 0))
    var cell_y := float(elevation) * ELEVATION_STEP
    var wall_base_y := board_foundation_y - cell_y
    var is_mountain := str(cell.get("landform", "")) in ["mountain", "peak", "ridge", "foothill"]
    var center_world := _axial_to_world(q, r)
    var added_wall := false

    for edge in range(6):
        var offset: Vector2i = HEX_EDGE_NEIGHBORS[edge]
        var neighbor_key := _cell_key(q + offset.x, r + offset.y)
        var wall_bottom_y := wall_base_y
        if cells.has(neighbor_key):
            var neighbor: Dictionary = cells[neighbor_key]
            var neighbor_elevation := int(neighbor.get("elevation", 0))
            var neighbor_is_mountain := str(neighbor.get("landform", "")) in ["mountain", "peak", "ridge", "foothill"]
            if neighbor_elevation > elevation:
                continue
            if neighbor_elevation == elevation:
                if not is_mountain or neighbor_is_mountain:
                    continue
                wall_bottom_y = 0.0
            else:
                wall_bottom_y = float(neighbor_elevation - elevation) * ELEVATION_STEP
        if wall_bottom_y >= -0.001 and not is_mountain:
            continue

        var angle_a := deg_to_rad(30.0 + 60.0 * float(edge))
        var angle_b := deg_to_rad(30.0 + 60.0 * float(edge + 1))
        var upper_a := Vector3(cos(angle_a) * HEX_RADIUS, 0.0, sin(angle_a) * HEX_RADIUS)
        var upper_b := Vector3(cos(angle_b) * HEX_RADIUS, 0.0, sin(angle_b) * HEX_RADIUS)
        if is_mountain:
            upper_a.y = _mountain_height_at(Vector2(center_world.x + upper_a.x, center_world.z + upper_a.z))
            upper_b.y = _mountain_height_at(Vector2(center_world.x + upper_b.x, center_world.z + upper_b.z))
        if upper_a.y <= wall_bottom_y + 0.001 and upper_b.y <= wall_bottom_y + 0.001:
            continue

        var face_normal := Vector3(upper_a.x + upper_b.x, 0.0, upper_a.z + upper_b.z).normalized()
        var phase := posmod(q * 5 + r * 7 + edge * 3, 24)
        _add_angular_cliff_face(surface, upper_a, upper_b, wall_bottom_y, face_normal, center_world, cell_y, phase)
        added_wall = true

    if not added_wall:
        return null
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
        "cottage":
            _build_cottage(root)
        "longhouse":
            _build_longhouse(root)
        "barn":
            _build_barn(root)
        "inn":
            _build_inn(root)
        "smithy":
            _build_smithy(root)
        "chapel":
            _build_chapel(root)
        "watchtower":
            _build_watchtower(root)
        "ruined_house":
            _build_ruined_house(root)
        "stone_wall":
            _build_stone_wall(root)
        "palisade_wall":
            _build_palisade_wall(root)
        "wooden_gate":
            _build_wooden_gate(root)
        "stone_gate":
            _build_stone_gate(root)
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

func _make_grass_clump_mesh() -> ArrayMesh:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var blade_colors := [
        Color("a4bd55"), Color("88ad45"), Color("d0c45f"),
        Color("739b3d"), Color("b6bd58"), Color("739e54")
    ]
    for blade in range(6):
        var angle := TAU * float(blade) / 6.0 + float(blade % 2) * 0.31
        var direction := Vector3(cos(angle), 0.0, sin(angle))
        var side := Vector3(-direction.z, 0.0, direction.x) * (0.025 + float(blade % 3) * 0.006)
        var base := direction * (0.025 + float(blade % 2) * 0.025)
        var height := 0.13 + float((blade * 17) % 5) * 0.035
        var tip := base + direction * (0.035 + float(blade % 3) * 0.018) + Vector3(0.0, height, 0.0)
        var left := base - side
        var right := base + side
        var color: Color = blade_colors[blade]
        surface.set_color(color.darkened(0.08))
        surface.add_vertex(left)
        surface.set_color(color.lightened(0.05))
        surface.add_vertex(right)
        surface.set_color(color.lightened(0.16))
        surface.add_vertex(tip)
        surface.set_color(color.darkened(0.10))
        surface.add_vertex(right)
        surface.set_color(color.lightened(0.05))
        surface.add_vertex(base + direction * 0.02 - side * 0.45)
        surface.set_color(color.lightened(0.16))
        surface.add_vertex(tip + side * 0.12)
    surface.generate_normals()
    return surface.commit()

func _build_terrain_dressing(tile: Node3D, terrain: String, q: int, r: int) -> void:
    if terrain not in ["grass", "woodland", "marsh"]:
        return
    var rng := RandomNumberGenerator.new()
    rng.seed = posmod(q * 73856093 + r * 19349663 + int(TERRAIN_IDS[terrain]) * 83492791, 2147483647)
    var grass_count := 13 if terrain == "woodland" else (5 if terrain == "marsh" else 9)
    var grass_batch := MultiMesh.new()
    grass_batch.transform_format = MultiMesh.TRANSFORM_3D
    grass_batch.use_colors = true
    grass_batch.mesh = terrain_grass_mesh
    grass_batch.instance_count = grass_count
    for index in range(grass_count):
        var angle := rng.randf_range(0.0, TAU)
        var radius := sqrt(rng.randf()) * 0.76
        var position := Vector3(cos(angle) * radius, 0.012, sin(angle) * radius)
        var height := rng.randf_range(0.72, 1.35) * (0.82 if terrain == "marsh" else 1.0)
        var width := rng.randf_range(0.72, 1.22)
        var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(width, height, width))
        grass_batch.set_instance_transform(index, Transform3D(basis, position))
        var blade_tint: Color
        if terrain == "woodland":
            blade_tint = Color.from_hsv(
                rng.randf_range(0.28, 0.34),
                rng.randf_range(0.36, 0.48),
                rng.randf_range(0.78, 0.92)
            )
        elif terrain == "marsh":
            blade_tint = Color.from_hsv(
                rng.randf_range(0.19, 0.24),
                rng.randf_range(0.26, 0.40),
                rng.randf_range(0.82, 0.95)
            )
        else:
            blade_tint = Color.from_hsv(
                rng.randf_range(0.20, 0.28),
                rng.randf_range(0.20, 0.30),
                rng.randf_range(0.88, 1.0)
            )
        grass_batch.set_instance_color(index, blade_tint)
    var grass_instance := MultiMeshInstance3D.new()
    grass_instance.name = "MeadowGrass"
    grass_instance.multimesh = grass_batch
    grass_instance.material_override = terrain_grass_material
    tile.add_child(grass_instance)
    var flower_chance := 0.42 if terrain == "grass" else (0.09 if terrain == "woodland" else 0.04)
    if rng.randf() > flower_chance:
        return
    var flower_count := rng.randi_range(4, 8)
    var flower_batch := MultiMesh.new()
    flower_batch.transform_format = MultiMesh.TRANSFORM_3D
    flower_batch.use_colors = true
    flower_batch.mesh = terrain_flower_mesh
    flower_batch.instance_count = flower_count
    var flower_palette := [
        Color("e8c84f"), Color("a884ce"), Color("d87989"),
        Color("f0e6c8"), Color("e7a446")
    ]
    for index in range(flower_count):
        var angle := rng.randf_range(0.0, TAU)
        var radius := rng.randf_range(0.12, 0.38)
        var position := Vector3(cos(angle) * radius, rng.randf_range(0.11, 0.19), sin(angle) * radius)
        var scale := Vector3(rng.randf_range(0.035, 0.055), rng.randf_range(0.05, 0.09), rng.randf_range(0.035, 0.055))
        var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(scale)
        flower_batch.set_instance_transform(index, Transform3D(basis, position))
        flower_batch.set_instance_color(index, flower_palette[rng.randi_range(0, flower_palette.size() - 1)])
    var flower_instance := MultiMeshInstance3D.new()
    flower_instance.name = "WildflowerPatch"
    flower_instance.multimesh = flower_batch
    flower_instance.material_override = terrain_flower_material
    tile.add_child(flower_instance)

func _build_tree(root: Node3D, pine: bool) -> void:
    var trunk := CylinderMesh.new()
    trunk.top_radius = 0.085 if not pine else 0.055
    trunk.bottom_radius = 0.17 if not pine else 0.105
    trunk.height = 1.52 if not pine else 1.92
    trunk.radial_segments = 16
    _add_mesh(root, trunk, prop_materials["bark"], Vector3(0.0, trunk.height * 0.5, 0.0))
    for root_index in range(5 if not pine else 3):
        var root_angle := TAU * float(root_index) / float(5 if not pine else 3) + 0.18
        var root_tip := Vector3(cos(root_angle) * 0.35, 0.045, sin(root_angle) * 0.35)
        _add_beam(root, Vector3(0.0, 0.16, 0.0), root_tip, 0.065 if not pine else 0.038, prop_materials["bark"])
    if pine:
        for index in range(5):
            var cone := CylinderMesh.new()
            cone.top_radius = 0.025
            cone.bottom_radius = 0.66 - float(index) * 0.10
            cone.height = 0.72
            cone.radial_segments = 18
            var cone_y := 0.72 + float(index) * 0.31
            var cone_offset := Vector3(sin(float(index) * 1.7) * 0.025, 0.0, cos(float(index) * 1.3) * 0.025)
            var needles: Material = prop_materials["leaf_dark"] if index % 2 == 0 else prop_materials["leaf_mid"]
            _add_mesh(root, cone, needles, Vector3(0.0, cone_y, 0.0) + cone_offset)
        return
    for branch_index in range(7):
        var angle := float(branch_index) * TAU / 7.0 + 0.23
        var branch_y := 0.62 + float(branch_index % 3) * 0.20
        var start := Vector3(0.0, branch_y, 0.0)
        var finish := Vector3(cos(angle) * (0.48 + float(branch_index % 2) * 0.06), branch_y + 0.42, sin(angle) * (0.48 + float(branch_index % 2) * 0.06))
        _add_beam(root, start, finish, 0.052, prop_materials["bark_light"])
    var foliage := SphereMesh.new()
    foliage.radial_segments = 24
    foliage.rings = 16
    for index in range(13):
        var angle := float(index) * 2.399963 + 0.31
        var layer := float(index % 4)
        var radius := 0.30 + float((index * 37) % 6) * 0.045
        var center := Vector3(cos(angle) * radius, 1.53 + layer * 0.15 + sin(float(index) * 1.7) * 0.07, sin(angle) * radius)
        var size := 0.32 + float(index % 4) * 0.035
        var foliage_material: Material = prop_materials["leaf_mid"] if index % 4 == 0 else (prop_materials["leaf_light"] if index % 3 == 0 else prop_materials["leaf_dark"])
        _add_mesh(root, foliage, foliage_material, center, Vector3(size, size * (0.76 + float(index % 3) * 0.05), size * (0.88 + float((index + 1) % 3) * 0.05)))
    _add_mesh(root, foliage, prop_materials["leaf_mid"], Vector3(0.0, 1.82, 0.0), Vector3(0.48, 0.40, 0.46))

func _build_gable_end(root: Node3D, width: float, depth: float, eaves_y: float, ridge_y: float, material: Material) -> void:
    var half_span := width * 0.5
    var face_z := depth * 0.5 + 0.012
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    surface.add_vertex(Vector3(-half_span, eaves_y, face_z))
    surface.add_vertex(Vector3(half_span, eaves_y, face_z))
    surface.add_vertex(Vector3(0.0, ridge_y, face_z))
    surface.add_vertex(Vector3(half_span, eaves_y, -face_z))
    surface.add_vertex(Vector3(-half_span, eaves_y, -face_z))
    surface.add_vertex(Vector3(0.0, ridge_y, -face_z))
    surface.generate_normals()
    var gable_mesh := surface.commit()
    _add_mesh(root, gable_mesh, material, Vector3.ZERO)

func _add_window_frame(root: Node3D, center: Vector3, width: float, height: float, face_z: float) -> void:
    var wood: Material = prop_materials["wood_dark"]
    var jamb := BoxMesh.new()
    jamb.size = Vector3(0.055, height + 0.10, 0.06)
    for side in [-1.0, 1.0]:
        _add_mesh(root, jamb, wood, Vector3(center.x + side * (width * 0.5 + 0.025), center.y, face_z))
    var lintel := BoxMesh.new()
    lintel.size = Vector3(width + 0.12, 0.055, 0.065)
    _add_mesh(root, lintel, wood, Vector3(center.x, center.y + height * 0.5 + 0.035, face_z))
    var sill := BoxMesh.new()
    sill.size = Vector3(width + 0.16, 0.07, 0.11)
    _add_mesh(root, sill, wood, Vector3(center.x, center.y - height * 0.5 - 0.04, face_z + 0.015))
    var mullion := BoxMesh.new()
    mullion.size = Vector3(0.028, height - 0.025, 0.03)
    _add_mesh(root, mullion, wood, Vector3(center.x, center.y, face_z + 0.035))
    var crossbar := BoxMesh.new()
    crossbar.size = Vector3(width - 0.025, 0.028, 0.03)
    _add_mesh(root, crossbar, wood, Vector3(center.x, center.y, face_z + 0.035))
    var shutter := BoxMesh.new()
    shutter.size = Vector3(0.055, height + 0.01, 0.045)
    for side in [-1.0, 1.0]:
        _add_mesh(root, shutter, prop_materials["wood"], Vector3(center.x + side * (width * 0.5 + 0.085), center.y, face_z - 0.008))

func _build_gable_roof(root: Node3D, width: float, depth: float, eaves_y: float, ridge_y: float, material: Material) -> void:
    var half_span := width * 0.5
    var rise := maxf(ridge_y - eaves_y, 0.05)
    var slope := atan2(rise, half_span)
    var panel_length := Vector2(half_span, rise).length() + 0.08
    var panel := BoxMesh.new()
    panel.size = Vector3(panel_length, 0.12, depth + 0.12)
    var panel_center_y := (ridge_y + eaves_y) * 0.5
    var left := _add_mesh(root, panel, material, Vector3(-half_span * 0.5, panel_center_y, 0.0))
    left.rotation.z = slope
    var right := _add_mesh(root, panel, material, Vector3(half_span * 0.5, panel_center_y, 0.0))
    right.rotation.z = -slope
    var ridge_cap := BoxMesh.new()
    ridge_cap.size = Vector3(0.15, 0.12, depth + 0.20)
    _add_mesh(root, ridge_cap, material, Vector3(0.0, ridge_y, 0.0))
    var fascia := BoxMesh.new()
    fascia.size = Vector3(0.075, 0.12, depth + 0.15)
    for side in [-1.0, 1.0]:
        _add_mesh(root, fascia, prop_materials["wood_dark"], Vector3(side * (half_span + 0.01), eaves_y - 0.015, 0.0))
        for end_sign in [-1.0, 1.0]:
            var end_z: float = end_sign * (depth * 0.5 + 0.055)
            var eave_point := Vector3(side * half_span, eaves_y, end_z)
            var ridge_point := Vector3(0.0, ridge_y, end_z)
            _add_beam(root, eave_point, ridge_point, 0.032, prop_materials["wood_dark"])

func _build_cottage(root: Node3D) -> void:
    var base := BoxMesh.new()
    base.size = Vector3(1.12, 0.17, 1.02)
    _add_mesh(root, base, prop_materials["stone_light"], Vector3(0.0, 0.085, 0.0))
    var body := BoxMesh.new()
    body.size = Vector3(0.98, 0.78, 0.86)
    _add_mesh(root, body, prop_materials["plaster_light"], Vector3(0.0, 0.54, 0.0))
    var timber := BoxMesh.new()
    timber.size = Vector3(0.075, 0.84, 0.09)
    for x in [-0.45, 0.45]:
        for z in [-0.39, 0.39]:
            _add_mesh(root, timber, prop_materials["wood_dark"], Vector3(x, 0.54, z))
    var door := BoxMesh.new()
    door.size = Vector3(0.24, 0.50, 0.045)
    _add_mesh(root, door, prop_materials["wood"], Vector3(-0.22, 0.34, 0.45))
    var door_frame := BoxMesh.new()
    door_frame.size = Vector3(0.055, 0.56, 0.065)
    _add_mesh(root, door_frame, prop_materials["wood_dark"], Vector3(-0.385, 0.35, 0.485))
    _add_mesh(root, door_frame, prop_materials["wood_dark"], Vector3(-0.055, 0.35, 0.485))
    var door_lintel := BoxMesh.new()
    door_lintel.size = Vector3(0.38, 0.06, 0.07)
    _add_mesh(root, door_lintel, prop_materials["wood_dark"], Vector3(-0.22, 0.65, 0.485))
    var step := BoxMesh.new()
    step.size = Vector3(0.42, 0.08, 0.20)
    _add_mesh(root, step, prop_materials["stone"], Vector3(-0.22, 0.15, 0.54))
    var window := BoxMesh.new()
    window.size = Vector3(0.18, 0.20, 0.045)
    _add_mesh(root, window, prop_materials["window"], Vector3(0.20, 0.63, 0.45))
    _add_window_frame(root, Vector3(0.20, 0.63, 0.45), 0.18, 0.20, 0.49)
    _build_gable_end(root, 0.98, 0.86, 0.93, 1.42, prop_materials["plaster_light"])
    _build_gable_roof(root, 1.18, 1.10, 0.96, 1.42, prop_materials["thatch"])
    var chimney := BoxMesh.new()
    chimney.size = Vector3(0.18, 0.48, 0.19)
    _add_mesh(root, chimney, prop_materials["stone_dark"], Vector3(0.30, 1.29, -0.27))
    var chimney_cap := BoxMesh.new()
    chimney_cap.size = Vector3(0.24, 0.07, 0.25)
    _add_mesh(root, chimney_cap, prop_materials["stone_light"], Vector3(0.30, 1.55, -0.27))

func _build_longhouse(root: Node3D) -> void:
    var foundation := BoxMesh.new()
    foundation.size = Vector3(1.58, 0.18, 1.05)
    _add_mesh(root, foundation, prop_materials["stone"], Vector3(0.0, 0.09, 0.0))
    var hall := BoxMesh.new()
    hall.size = Vector3(1.43, 0.88, 0.90)
    _add_mesh(root, hall, prop_materials["wood"], Vector3(0.0, 0.60, 0.0))
    for z in [-0.36, 0.0, 0.36]:
        var post := BoxMesh.new()
        post.size = Vector3(0.10, 1.0, 0.11)
        _add_mesh(root, post, prop_materials["wood_dark"], Vector3(-0.66, 0.60, z))
        _add_mesh(root, post, prop_materials["wood_dark"], Vector3(0.66, 0.60, z))
    for x in [-0.42, 0.42]:
        var window := BoxMesh.new()
        window.size = Vector3(0.035, 0.20, 0.17)
        _add_mesh(root, window, prop_materials["window"], Vector3(x, 0.70, 0.47))
    _build_gable_end(root, 1.43, 0.88, 0.90, 1.62, prop_materials["wood"])
    _build_gable_roof(root, 1.70, 1.22, 1.05, 1.62, prop_materials["roof_moss"])
    var vent := CylinderMesh.new()
    vent.top_radius = 0.16
    vent.bottom_radius = 0.21
    vent.height = 0.22
    vent.radial_segments = 8
    _add_mesh(root, vent, prop_materials["wood_dark"], Vector3(0.0, 1.73, -0.27))

func _build_barn(root: Node3D) -> void:
    var base := BoxMesh.new()
    base.size = Vector3(1.48, 0.18, 1.16)
    _add_mesh(root, base, prop_materials["stone_dark"], Vector3(0.0, 0.09, 0.0))
    var body := BoxMesh.new()
    body.size = Vector3(1.32, 1.02, 1.02)
    _add_mesh(root, body, prop_materials["wood"], Vector3(0.0, 0.68, 0.0))
    for x in [-0.59, -0.42, 0.42, 0.59]:
        var brace := BoxMesh.new()
        brace.size = Vector3(0.07, 1.0, 0.07)
        _add_mesh(root, brace, prop_materials["wood_dark"], Vector3(x, 0.65, 0.52))
    var door_left := BoxMesh.new()
    door_left.size = Vector3(0.36, 0.75, 0.06)
    _add_mesh(root, door_left, prop_materials["wood_dark"], Vector3(-0.20, 0.45, 0.56))
    _add_mesh(root, door_left, prop_materials["wood_dark"], Vector3(0.20, 0.45, 0.56))
    var door_plank := BoxMesh.new()
    door_plank.size = Vector3(0.055, 0.70, 0.025)
    for x in [-0.40, -0.20, 0.0, 0.20, 0.40]:
        _add_mesh(root, door_plank, prop_materials["wood"], Vector3(x, 0.45, 0.595))
    _add_beam(root, Vector3(-0.36, 0.12, 0.62), Vector3(0.36, 0.78, 0.62), 0.035, prop_materials["wood_dark"])
    _add_beam(root, Vector3(0.0, 0.45, 0.635), Vector3(0.0, 0.45, 0.70), 0.022, prop_materials["metal"])
    var loft_opening := BoxMesh.new()
    loft_opening.size = Vector3(0.30, 0.15, 0.04)
    _add_mesh(root, loft_opening, prop_materials["window"], Vector3(0.0, 1.04, 0.54))
    _add_window_frame(root, Vector3(0.0, 1.04, 0.54), 0.30, 0.15, 0.565)
    _build_gable_end(root, 1.32, 1.02, 1.19, 1.76, prop_materials["wood"])
    _build_gable_roof(root, 1.68, 1.32, 1.18, 1.76, prop_materials["roof_red"])

func _build_inn(root: Node3D) -> void:
    var foundation := BoxMesh.new()
    foundation.size = Vector3(1.38, 0.17, 1.15)
    _add_mesh(root, foundation, prop_materials["stone"], Vector3(0.0, 0.085, 0.0))
    var lower := BoxMesh.new()
    lower.size = Vector3(1.18, 0.70, 0.96)
    _add_mesh(root, lower, prop_materials["plaster"], Vector3(0.0, 0.52, 0.0))
    var upper := BoxMesh.new()
    upper.size = Vector3(1.03, 0.53, 0.86)
    _add_mesh(root, upper, prop_materials["wood"], Vector3(0.0, 1.12, -0.03))
    var balcony := BoxMesh.new()
    balcony.size = Vector3(1.28, 0.09, 0.24)
    _add_mesh(root, balcony, prop_materials["wood_dark"], Vector3(0.0, 0.89, 0.53))
    for x in [-0.56, -0.28, 0.0, 0.28, 0.56]:
        var rail_post := CylinderMesh.new()
        rail_post.top_radius = 0.025
        rail_post.bottom_radius = 0.035
        rail_post.height = 0.34
        rail_post.radial_segments = 6
        _add_mesh(root, rail_post, prop_materials["wood_dark"], Vector3(x, 1.08, 0.62))
    var rail := BoxMesh.new()
    rail.size = Vector3(1.30, 0.07, 0.07)
    _add_mesh(root, rail, prop_materials["wood_dark"], Vector3(0.0, 1.24, 0.62))
    var door := BoxMesh.new()
    door.size = Vector3(0.23, 0.52, 0.05)
    _add_mesh(root, door, prop_materials["roof"], Vector3(-0.32, 0.34, 0.50))
    _build_gable_end(root, 1.03, 0.70, 0.96, 1.88, prop_materials["plaster"])
    _build_gable_roof(root, 1.35, 1.12, 1.42, 1.88, prop_materials["roof_red"])
    var sign := BoxMesh.new()
    sign.size = Vector3(0.42, 0.25, 0.07)
    _add_mesh(root, sign, prop_materials["wood_dark"], Vector3(0.45, 1.03, 0.62))
    var lantern := SphereMesh.new()
    lantern.radius = 0.10
    lantern.height = 0.20
    _add_mesh(root, lantern, prop_materials["flame_light"], Vector3(0.50, 0.72, 0.61))

func _build_smithy(root: Node3D) -> void:
    var base := BoxMesh.new()
    base.size = Vector3(1.30, 0.19, 1.12)
    _add_mesh(root, base, prop_materials["stone"], Vector3(0.0, 0.095, 0.0))
    var shop := BoxMesh.new()
    shop.size = Vector3(1.10, 0.82, 0.92)
    _add_mesh(root, shop, prop_materials["brick"], Vector3(-0.05, 0.56, 0.0))
    _build_gable_end(root, 1.10, 0.82, 0.92, 1.48, prop_materials["brick"])
    _build_gable_roof(root, 1.38, 1.16, 0.97, 1.48, prop_materials["roof_moss"])
    var chimney := BoxMesh.new()
    chimney.size = Vector3(0.25, 0.80, 0.25)
    _add_mesh(root, chimney, prop_materials["stone_dark"], Vector3(0.38, 1.31, -0.26))
    var furnace := BoxMesh.new()
    furnace.size = Vector3(0.40, 0.48, 0.32)
    _add_mesh(root, furnace, prop_materials["stone_dark"], Vector3(0.62, 0.30, 0.28))
    var fire := BoxMesh.new()
    fire.size = Vector3(0.20, 0.20, 0.06)
    _add_mesh(root, fire, prop_materials["flame"], Vector3(0.62, 0.34, 0.46))
    var anvil_base := BoxMesh.new()
    anvil_base.size = Vector3(0.22, 0.22, 0.18)
    _add_mesh(root, anvil_base, prop_materials["metal"], Vector3(-0.46, 0.20, 0.48))
    var anvil_top := BoxMesh.new()
    anvil_top.size = Vector3(0.38, 0.12, 0.22)
    _add_mesh(root, anvil_top, prop_materials["metal"], Vector3(-0.46, 0.36, 0.48))

func _build_chapel(root: Node3D) -> void:
    var foundation := BoxMesh.new()
    foundation.size = Vector3(1.28, 0.20, 1.38)
    _add_mesh(root, foundation, prop_materials["stone_light"], Vector3(0.0, 0.10, 0.0))
    var nave := BoxMesh.new()
    nave.size = Vector3(0.98, 1.02, 1.12)
    _add_mesh(root, nave, prop_materials["plaster"], Vector3(0.0, 0.70, -0.02))
    _build_gable_end(root, 0.98, 1.02, 1.12, 1.80, prop_materials["plaster"])
    _build_gable_roof(root, 1.24, 1.35, 1.23, 1.80, prop_materials["roof_moss"])
    var tower := BoxMesh.new()
    tower.size = Vector3(0.48, 1.18, 0.50)
    _add_mesh(root, tower, prop_materials["stone"], Vector3(0.0, 1.30, 0.52))
    var arch := BoxMesh.new()
    arch.size = Vector3(0.28, 0.42, 0.04)
    _add_mesh(root, arch, prop_materials["window"], Vector3(0.0, 1.48, 0.79))
    var spire := CylinderMesh.new()
    spire.top_radius = 0.02
    spire.bottom_radius = 0.36
    spire.height = 0.68
    spire.radial_segments = 6
    _add_mesh(root, spire, prop_materials["roof_red"], Vector3(0.0, 2.20, 0.52))
    _add_beam(root, Vector3(0.0, 2.54, 0.52), Vector3(0.0, 2.84, 0.52), 0.035, prop_materials["metal"])
    _add_beam(root, Vector3(-0.14, 2.70, 0.52), Vector3(0.14, 2.70, 0.52), 0.030, prop_materials["metal"])

func _build_watchtower(root: Node3D) -> void:
    var base := CylinderMesh.new()
    base.top_radius = 0.54
    base.bottom_radius = 0.64
    base.height = 0.72
    base.radial_segments = 8
    _add_mesh(root, base, prop_materials["stone_dark"], Vector3(0.0, 0.36, 0.0))
    var shaft := CylinderMesh.new()
    shaft.top_radius = 0.38
    shaft.bottom_radius = 0.48
    shaft.height = 1.10
    shaft.radial_segments = 8
    _add_mesh(root, shaft, prop_materials["stone"], Vector3(0.0, 1.22, 0.0))
    var platform := BoxMesh.new()
    platform.size = Vector3(1.08, 0.16, 1.08)
    _add_mesh(root, platform, prop_materials["wood_dark"], Vector3(0.0, 1.82, 0.0))
    for x in [-0.43, 0.43]:
        for z in [-0.43, 0.43]:
            var post := CylinderMesh.new()
            post.top_radius = 0.045
            post.bottom_radius = 0.06
            post.height = 0.64
            post.radial_segments = 7
            _add_mesh(root, post, prop_materials["wood"], Vector3(x, 2.18, z))
    var roof := CylinderMesh.new()
    roof.top_radius = 0.02
    roof.bottom_radius = 0.72
    roof.height = 0.70
    roof.radial_segments = 6
    _add_mesh(root, roof, prop_materials["roof_red"], Vector3(0.0, 2.78, 0.0))
    for x in [-0.43, 0.43]:
        var rail := BoxMesh.new()
        rail.size = Vector3(0.98, 0.09, 0.08)
        _add_mesh(root, rail, prop_materials["wood_dark"], Vector3(0.0, 1.98, x))
        rail.size = Vector3(0.08, 0.09, 0.98)
        _add_mesh(root, rail, prop_materials["wood_dark"], Vector3(x, 1.98, 0.0))

func _build_ruined_house(root: Node3D) -> void:
    var floor := BoxMesh.new()
    floor.size = Vector3(1.26, 0.16, 1.10)
    _add_mesh(root, floor, prop_materials["stone_dark"], Vector3(0.0, 0.08, 0.0))
    var wall_a := BoxMesh.new()
    wall_a.size = Vector3(0.10, 0.94, 0.92)
    _add_mesh(root, wall_a, prop_materials["stone"], Vector3(-0.54, 0.55, 0.0))
    var wall_b := BoxMesh.new()
    wall_b.size = Vector3(0.62, 0.62, 0.10)
    _add_mesh(root, wall_b, prop_materials["stone_light"], Vector3(0.12, 0.42, -0.48))
    var broken := BoxMesh.new()
    broken.size = Vector3(0.50, 0.28, 0.10)
    var broken_piece := _add_mesh(root, broken, prop_materials["stone"], Vector3(0.48, 0.77, 0.48))
    broken_piece.rotation.z = -0.22
    var beam := BoxMesh.new()
    beam.size = Vector3(1.08, 0.15, 0.16)
    var fallen := _add_mesh(root, beam, prop_materials["wood"], Vector3(0.10, 0.16, 0.04))
    fallen.rotation.z = -0.18
    var rubble := SphereMesh.new()
    rubble.radial_segments = 8
    rubble.rings = 5
    for i in range(7):
        _add_mesh(root, rubble, prop_materials["stone_dark"] if i % 2 == 0 else prop_materials["stone_light"], Vector3(-0.48 + float(i) * 0.16, 0.13, 0.52), Vector3(0.18, 0.13, 0.20))

func _build_stone_wall(root: Node3D) -> void:
    var footing := BoxMesh.new()
    footing.size = Vector3(1.72, 0.20, 0.32)
    _add_mesh(root, footing, prop_materials["stone_dark"], Vector3(0.0, 0.10, 0.0))
    var block := BoxMesh.new()
    block.size = Vector3(0.22, 0.46, 0.36)
    for i in range(8):
        var x := -0.77 + float(i) * 0.22
        var material: Material = prop_materials["stone"] if i % 3 != 0 else prop_materials["stone_light"]
        _add_mesh(root, block, material, Vector3(x, 0.43, 0.0), Vector3(1.0, 0.88 + float(i % 3) * 0.07, 1.0))
    var cap := BoxMesh.new()
    cap.size = Vector3(1.76, 0.15, 0.42)
    _add_mesh(root, cap, prop_materials["stone_light"], Vector3(0.0, 0.75, 0.0))

func _build_palisade_wall(root: Node3D) -> void:
    var post := CylinderMesh.new()
    post.top_radius = 0.015
    post.bottom_radius = 0.095
    post.height = 1.12
    post.radial_segments = 7
    for i in range(9):
        var x := -0.78 + float(i) * 0.195
        _add_mesh(root, post, prop_materials["wood"], Vector3(x, 0.52, 0.0), Vector3(1.0, 1.0, 0.88))
    for y in [0.28, 0.67]:
        _add_beam(root, Vector3(-0.86, y, -0.10), Vector3(0.86, y, -0.10), 0.055, prop_materials["wood_dark"])

func _build_wooden_gate(root: Node3D) -> void:
    for x in [-0.79, 0.79]:
        var post := CylinderMesh.new()
        post.top_radius = 0.08
        post.bottom_radius = 0.12
        post.height = 1.48
        post.radial_segments = 8
        _add_mesh(root, post, prop_materials["wood_dark"], Vector3(x, 0.72, 0.0))
    for z in [-0.10, 0.10]:
        var gate := BoxMesh.new()
        gate.size = Vector3(1.45, 0.90, 0.10)
        _add_mesh(root, gate, prop_materials["wood"], Vector3(0.0, 0.57, z))
    for x in [-0.62, -0.31, 0.0, 0.31, 0.62]:
        var brace := BoxMesh.new()
        brace.size = Vector3(0.07, 0.92, 0.13)
        _add_mesh(root, brace, prop_materials["wood_dark"], Vector3(x, 0.57, 0.18))
    _add_beam(root, Vector3(-0.76, 0.12, 0.22), Vector3(0.76, 1.00, 0.22), 0.045, prop_materials["wood_dark"])
    _add_beam(root, Vector3(0.76, 0.12, 0.22), Vector3(-0.76, 1.00, 0.22), 0.045, prop_materials["wood_dark"])

func _build_stone_gate(root: Node3D) -> void:
    for x in [-0.78, 0.78]:
        var pillar := BoxMesh.new()
        pillar.size = Vector3(0.36, 1.50, 0.48)
        _add_mesh(root, pillar, prop_materials["stone"], Vector3(x, 0.75, 0.0))
        var cap := BoxMesh.new()
        cap.size = Vector3(0.46, 0.16, 0.56)
        _add_mesh(root, cap, prop_materials["stone_light"], Vector3(x, 1.56, 0.0))
    var lintel := BoxMesh.new()
    lintel.size = Vector3(1.45, 0.28, 0.46)
    _add_mesh(root, lintel, prop_materials["stone_dark"], Vector3(0.0, 1.44, 0.0))
    for x in [-0.34, -0.11, 0.11, 0.34]:
        var bar := BoxMesh.new()
        bar.size = Vector3(0.08, 1.02, 0.12)
        _add_mesh(root, bar, prop_materials["wood_dark"], Vector3(x, 0.53, 0.20))
    _add_beam(root, Vector3(-0.40, 0.12, 0.28), Vector3(0.40, 0.90, 0.28), 0.04, prop_materials["wood"])

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
    var door_frame := BoxMesh.new()
    door_frame.size = Vector3(0.055, 0.56, 0.06)
    _add_mesh(root, door_frame, prop_materials["wood_dark"], Vector3(-0.145, 0.35, 0.41))
    _add_mesh(root, door_frame, prop_materials["wood_dark"], Vector3(0.145, 0.35, 0.41))
    var window := BoxMesh.new()
    window.size = Vector3(0.17, 0.18, 0.035)
    _add_mesh(root, window, prop_materials["window"], Vector3(-0.24, 0.62, 0.38))
    _add_mesh(root, window, prop_materials["window"], Vector3(0.24, 0.62, 0.38))
    _add_window_frame(root, Vector3(-0.24, 0.62, 0.38), 0.17, 0.18, 0.42)
    _add_window_frame(root, Vector3(0.24, 0.62, 0.38), 0.17, 0.18, 0.42)
    _build_gable_end(root, 0.82, 0.72, 0.88, 1.38, prop_materials["wall"])
    _build_gable_roof(root, 1.08, 1.02, 0.90, 1.38, prop_materials["roof"])
    var chimney := BoxMesh.new()
    chimney.size = Vector3(0.16, 0.52, 0.18)
    _add_mesh(root, chimney, prop_materials["stone"], Vector3(0.24, 1.08, -0.24))
    var chimney_cap := BoxMesh.new()
    chimney_cap.size = Vector3(0.23, 0.07, 0.25)
    _add_mesh(root, chimney_cap, prop_materials["stone_light"], Vector3(0.24, 1.36, -0.24))

func _build_fence(root: Node3D) -> void:
    for x in [-0.86, 0.0, 0.86]:
        var post := CylinderMesh.new()
        post.top_radius = 0.045
        post.bottom_radius = 0.085
        post.height = 0.90
        post.radial_segments = 10
        _add_mesh(root, post, prop_materials["wood_dark"], Vector3(x, 0.45, 0.0))
        var cap := SphereMesh.new()
        cap.radial_segments = 8
        cap.rings = 5
        _add_mesh(root, cap, prop_materials["bark_light"], Vector3(x, 0.91, 0.0), Vector3(0.075, 0.045, 0.075))
    for y in [0.25, 0.65]:
        var rail := BoxMesh.new()
        rail.size = Vector3(1.76, 0.10, 0.13)
        _add_mesh(root, rail, prop_materials["wood"], Vector3(0.0, y, 0.0))
    for index in range(5):
        var x := -0.62 + float(index) * 0.31
        var picket := BoxMesh.new()
        picket.size = Vector3(0.09, 0.40 + float(index % 2) * 0.08, 0.075)
        _add_mesh(root, picket, prop_materials["bark_light"], Vector3(x, 0.45, 0.0))

func _build_rock(root: Node3D) -> void:
    var main_stone := CylinderMesh.new()
    main_stone.top_radius = 0.40
    main_stone.bottom_radius = 0.56
    main_stone.height = 0.55
    main_stone.radial_segments = 7
    main_stone.rings = 1
    var main_instance := _add_mesh(root, main_stone, prop_materials["stone"], Vector3(0.0, 0.27, 0.0), Vector3(1.0, 0.82, 0.94))
    main_instance.rotation.y = 0.19
    main_instance.rotation.z = -0.08
    var shoulder := CylinderMesh.new()
    shoulder.top_radius = 0.31
    shoulder.bottom_radius = 0.42
    shoulder.height = 0.39
    shoulder.radial_segments = 6
    shoulder.rings = 1
    var shoulder_instance := _add_mesh(root, shoulder, prop_materials["stone_light"], Vector3(0.31, 0.19, 0.12), Vector3(0.76, 0.83, 0.72))
    shoulder_instance.rotation.y = -0.36
    shoulder_instance.rotation.z = 0.12
    var broken_face := CylinderMesh.new()
    broken_face.top_radius = 0.22
    broken_face.bottom_radius = 0.30
    broken_face.height = 0.31
    broken_face.radial_segments = 5
    broken_face.rings = 1
    var face_instance := _add_mesh(root, broken_face, prop_materials["stone_dark"], Vector3(-0.28, 0.15, 0.22), Vector3(0.82, 0.78, 0.76))
    face_instance.rotation.y = 0.48
    face_instance.rotation.x = -0.13
    var chip := CylinderMesh.new()
    chip.top_radius = 0.10
    chip.bottom_radius = 0.16
    chip.height = 0.15
    chip.radial_segments = 6
    chip.rings = 1
    var chip_instance := _add_mesh(root, chip, prop_materials["stone_light"], Vector3(-0.48, 0.075, -0.08), Vector3(0.9, 0.72, 0.82))
    chip_instance.rotation.y = -0.25

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
    for course in range(2):
        for index in range(12):
            var angle := TAU * (float(index) + float(course % 2) * 0.5) / 12.0
            var block := BoxMesh.new()
            block.size = Vector3(0.235, 0.18, 0.20)
            var radius := 0.395 + float((index + course) % 3) * 0.008
            var material_key := "stone_light" if (index + course) % 5 == 0 else ("stone_dark" if (index + course) % 7 == 0 else "stone")
            var stone := _add_mesh(root, block, prop_materials[material_key], Vector3(cos(angle) * radius, 0.10 + float(course) * 0.17, sin(angle) * radius))
            stone.rotation.y = angle + PI * 0.5 + float(index % 3 - 1) * 0.025
    var rim_block := BoxMesh.new()
    rim_block.size = Vector3(0.24, 0.12, 0.22)
    for index in range(12):
        var angle := TAU * (float(index) + 0.25) / 12.0
        var capstone := _add_mesh(root, rim_block, prop_materials["stone_light"], Vector3(cos(angle) * 0.40, 0.34, sin(angle) * 0.40))
        capstone.rotation.y = angle + PI * 0.5
    var water := CylinderMesh.new()
    water.top_radius = 0.30
    water.bottom_radius = 0.30
    water.height = 0.035
    _add_mesh(root, water, prop_materials["water"], Vector3(0.0, 0.22, 0.0))
    for x in [-0.42, 0.42]:
        var post := CylinderMesh.new()
        post.top_radius = 0.045
        post.bottom_radius = 0.065
        post.height = 0.82
        post.radial_segments = 10
        _add_mesh(root, post, prop_materials["wood_dark"], Vector3(x, 0.78, 0.0))
    var axle := CylinderMesh.new()
    axle.top_radius = 0.055
    axle.bottom_radius = 0.055
    axle.height = 0.76
    axle.radial_segments = 10
    var windlass := _add_mesh(root, axle, prop_materials["wood"], Vector3(0.0, 0.98, 0.0))
    windlass.rotation.z = PI * 0.5
    var rope := CylinderMesh.new()
    rope.top_radius = 0.018
    rope.bottom_radius = 0.018
    rope.height = 0.47
    rope.radial_segments = 6
    _add_mesh(root, rope, prop_materials["bark_light"], Vector3(0.0, 0.71, 0.0))
    var crank_arm := BoxMesh.new()
    crank_arm.size = Vector3(0.07, 0.27, 0.07)
    var crank := _add_mesh(root, crank_arm, prop_materials["wood_dark"], Vector3(-0.43, 0.97, 0.0))
    crank.rotation.z = -0.32
    var crank_handle := CylinderMesh.new()
    crank_handle.top_radius = 0.035
    crank_handle.bottom_radius = 0.035
    crank_handle.height = 0.20
    crank_handle.radial_segments = 8
    var handle := _add_mesh(root, crank_handle, prop_materials["wood"], Vector3(-0.50, 0.85, 0.0))
    handle.rotation.z = PI * 0.5
    _build_gable_roof(root, 1.18, 0.78, 1.20, 1.52, prop_materials["roof"])

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
    if editor_layer == "terrain" and (active_tool.begins_with("prop:") or active_tool.begins_with("wall_run:") or active_tool.begins_with("scatter:") or active_tool == "select_object" or active_tool == "erase_prop"):
        return
    if editor_layer == "objects" and active_tool != "select_object" and active_tool != "erase_prop" and not active_tool.begins_with("prop:") and not active_tool.begins_with("wall_run:") and not active_tool.begins_with("scatter:"):
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
    if not active_tool.begins_with("prop:") and not active_tool.begins_with("wall_run:") and active_tool != "erase_prop":
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
    elif active_tool == "mountain" or active_tool == "mountain_peak" or active_tool.begins_with("mountain_ridge:") or active_tool == "mountain_foothill" or active_tool == "clear_mountain":
        var form := "peak"
        var ridge_axis := 0
        if active_tool.begins_with("mountain_ridge:"):
            form = "ridge"
            ridge_axis = clampi(active_tool.get_slice(":", 1).to_int(), 0, 2)
        elif active_tool == "mountain_foothill":
            form = "foothill"
        _apply_mountain_brush(q, r, form, ridge_axis, active_tool != "clear_mountain")
        return
    elif active_tool == "toggle_passable":
        cell["blocked"] = not bool(cell.get("blocked", false))
        cell["movement_cost"] = 99 if bool(cell["blocked"]) else 1
        cells[key] = cell
        board["cells"] = cells
        _refresh_cell_visual(key)
        _set_status("Hex %s is now %s." % [key, "blocked" if bool(cell["blocked"]) else "passable"])
    elif active_tool.begins_with("wall_run:"):
        _continue_wall_run(q, r, active_tool.trim_prefix("wall_run:"))
        return
    elif active_tool.begins_with("scatter:"):
        _apply_scatter_brush(q, r, active_tool.trim_prefix("scatter:"))
        return
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

func _start_new_wall_run() -> void:
    _reset_wall_run()
    _set_status("Wall run reset. Tap a start hex, then tap neighboring hexes to extend it.")

func _reset_wall_run() -> void:
    wall_run_has_anchor = false
    wall_run_last_cell = Vector2i.ZERO

func _continue_wall_run(q: int, r: int, kind: String) -> void:
    var current := Vector2i(q, r)
    var current_key := _cell_key(q, r)
    if not cells.has(current_key):
        _reset_wall_run()
        selected_key = ""
        _refresh_selection()
        _set_status("Wall runs need installed hexes. Lay a continuous row of hexes first.")
        return
    if not wall_run_has_anchor:
        wall_run_last_cell = current
        wall_run_has_anchor = true
        _clear_object_selection()
        selected_key = current_key
        _refresh_selection()
        _set_status("%s run started at %s. Tap a neighboring hex to place the first segment." % [kind.replace("_", " ").capitalize(), current_key])
        return
    if current == wall_run_last_cell:
        return
    var previous := wall_run_last_cell
    var delta := current - previous
    var distance := maxi(absi(delta.x), maxi(absi(delta.y), absi(delta.x + delta.y)))
    if distance != 1:
        wall_run_last_cell = current
        selected_key = current_key
        _refresh_selection()
        _set_status("Run start moved to %s. Tap one of its neighboring hexes to continue." % current_key)
        return
    var previous_key := _cell_key(previous.x, previous.y)
    if not cells.has(previous_key):
        wall_run_last_cell = current
        _set_status("Previous hex is missing. Run start moved to %s." % current_key)
        return
    var placed := _place_wall_segment_between(previous, current, kind)
    wall_run_last_cell = current
    selected_key = current_key
    _refresh_selection()
    if placed:
        _set_status("%s segment snapped between %s and %s. Continue to extend the run." % [kind.replace("_", " ").capitalize(), previous_key, current_key])

func _place_wall_segment_between(from_cell: Vector2i, to_cell: Vector2i, kind: String) -> bool:
    var from_key := _cell_key(from_cell.x, from_cell.y)
    var to_key := _cell_key(to_cell.x, to_cell.y)
    var anchor_coord := from_cell
    var other_coord := to_cell
    if from_key > to_key:
        anchor_coord = to_cell
        other_coord = from_cell
    var anchor_key := _cell_key(anchor_coord.x, anchor_coord.y)
    var other_key := _cell_key(other_coord.x, other_coord.y)
    var edge_id := "%s|%s|%s" % [kind, anchor_key, other_key]
    var anchor_data: Dictionary = cells[anchor_key]
    var objects: Array = anchor_data.get("objects", []).duplicate(true)
    for object_data in objects:
        if object_data is Dictionary and str(object_data.get("wall_link", "")) == edge_id:
            return false
    var from_world := _axial_to_world(from_cell.x, from_cell.y)
    var to_world := _axial_to_world(to_cell.x, to_cell.y)
    var anchor_world := _axial_to_world(anchor_coord.x, anchor_coord.y)
    var midpoint := (from_world + to_world) * 0.5
    var from_elevation := int((cells[from_key] as Dictionary).get("elevation", 0))
    var to_elevation := int((cells[to_key] as Dictionary).get("elevation", 0))
    var anchor_elevation := int(anchor_data.get("elevation", 0))
    var direction := to_world - from_world
    var snapped_rotation := roundf(atan2(-direction.z, direction.x) / (PI / 3.0)) * (PI / 3.0)
    objects.append({
        "type": kind,
        "rotation": snapped_rotation,
        "scale": 1.0,
        "offset_x": midpoint.x - anchor_world.x,
        "offset_y": (float(from_elevation + to_elevation) * 0.5 - float(anchor_elevation)) * ELEVATION_STEP,
        "offset_z": midpoint.z - anchor_world.z,
        "wall_link": edge_id
    })
    anchor_data["objects"] = objects
    cells[anchor_key] = anchor_data
    board["cells"] = cells
    selected_object_key = anchor_key
    selected_object_index = objects.size() - 1
    _refresh_cell_visual(anchor_key)
    return true

func _apply_mountain_brush(q: int, r: int, form: String, ridge_axis: int, make_mountain: bool) -> void:
    var changed := 0
    for dq in range(-paint_brush_radius, paint_brush_radius + 1):
        for dr in range(-paint_brush_radius, paint_brush_radius + 1):
            if maxi(absi(dq), maxi(absi(dr), absi(dq + dr))) > paint_brush_radius:
                continue
            var key := _cell_key(q + dq, r + dr)
            if not cells.has(key):
                continue
            var cell: Dictionary = cells[key]
            if make_mountain:
                cell["landform"] = form
                cell["landform_axis"] = ridge_axis
                cell["terrain"] = "stone"
                var blocks_movement := form != "foothill"
                cell["blocked"] = blocks_movement
                cell["movement_cost"] = 99 if blocks_movement else 3
            elif str(cell.get("landform", "")) in ["mountain", "peak", "ridge", "foothill"]:
                cell["landform"] = ""
                cell.erase("landform_axis")
                cell["blocked"] = false
                cell["movement_cost"] = 1
            cells[key] = cell
            changed += 1
    board["cells"] = cells
    _rebuild_board()
    var form_label := "cleared" if not make_mountain else form.capitalize()
    _set_status("%s landform painted on %d hexes." % [form_label, changed])

func _random_hex_offset(rng: RandomNumberGenerator) -> Vector2:
    for attempt in range(20):
        var candidate := Vector2(rng.randf_range(-0.78, 0.78), rng.randf_range(-0.92, 0.92))
        if absf(candidate.x) * ROOT_3 / 3.0 + absf(candidate.y) <= 0.94:
            return candidate
    return Vector2.ZERO

func _apply_scatter_brush(q: int, r: int, preset: String) -> void:
    var pools := {
        "forest": ["tree", "tree", "pine", "ancient_tree", "bush", "flowers", "mushrooms", "log"],
        "rocky": ["rock", "rock", "rock", "stump", "dead_tree", "log"],
        "marsh": ["dead_tree", "bush", "mushrooms", "mushrooms", "rock", "log"],
        "deadfall": ["dead_tree", "dead_tree", "stump", "log", "log", "rock"]
    }
    if not pools.has(preset):
        return
    var changed := 0
    var placed := 0
    var pool: Array = pools[preset]
    for dq in range(-scatter_brush_radius, scatter_brush_radius + 1):
        for dr in range(-scatter_brush_radius, scatter_brush_radius + 1):
            if maxi(absi(dq), maxi(absi(dr), absi(dq + dr))) > scatter_brush_radius:
                continue
            var key := _cell_key(q + dq, r + dr)
            if not cells.has(key):
                continue
            var cell: Dictionary = cells[key]
            var objects: Array = cell.get("objects", []).duplicate(true)
            var rng := RandomNumberGenerator.new()
            rng.seed = int((q + dq) * 73856093) ^ int((r + dr) * 19349663) ^ int(scatter_nonce * 83492791)
            for object_number in range(scatter_density):
                var kind: String = str(pool[rng.randi_range(0, pool.size() - 1)])
                var offset := _random_hex_offset(rng)
                objects.append({
                    "type": kind,
                    "rotation": rng.randf_range(0.0, TAU),
                    "scale": rng.randf_range(0.72, 1.24),
                    "offset_x": offset.x,
                    "offset_z": offset.y
                })
                placed += 1
            cell["objects"] = objects
            cells[key] = cell
            _refresh_cell_visual(key)
            changed += 1
    scatter_nonce += 1
    board["cells"] = cells
    _refresh_selection()
    _set_status("%s scatter added %d details across %d hexes." % [preset.capitalize(), placed, changed])

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

func _process_world_tap(position: Vector2) -> void:
    # Android can deliver one physical tap as both touch and emulated mouse input.
    # Treat paired releases at the same screen point as one board action.
    var now := Time.get_ticks_msec()
    if now - last_world_tap_time_msec < 140 and position.distance_to(last_world_tap_position) < 10.0:
        return
    last_world_tap_time_msec = now
    last_world_tap_position = position
    _select_from_screen(position)

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
                    _process_world_tap(event.position)
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
                _process_world_tap(event.position)
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
    # Keep the current prop selected when tapping its hex again.
    # Cycling is an explicit action via NEXT OBJECT ON HEX.
    if selected_object_key != key or selected_object_index < 0 or selected_object_index >= objects.size():
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
