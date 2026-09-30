extends Control

const WORLD_DATA := "res://data/world_catalog.json"
const ASHENREACH_SCENE := "res://scenes/AshenreachDemo.tscn"
const MAP_SCRIPT := preload("res://scripts/world_map_canvas.gd")
const MAP_POINTS := {
    "ashen_wastes": Vector2(0.29, 0.59),
    "blighted_marsh": Vector2(0.55, 0.73),
    "shadowfen_forest": Vector2(0.67, 0.38),
    "cursed_mire": Vector2(0.75, 0.61),
    "dragons_rest": Vector2(0.43, 0.26)
}

var territories: Dictionary = {}
var current_region := "ashen_wastes"
var title_page: Control
var map_page: Control
var load_page: Control
var map_canvas: Control
var map_markers: Dictionary = {}
var detail_name: Label
var detail_type: Label
var detail_body: Label
var enter_button: Button
var load_bar: ProgressBar
var load_caption: Label
var loading_path := ""
var load_time := 0.0

func _ready() -> void:
    var file := FileAccess.open(WORLD_DATA, FileAccess.READ)
    if file:
        var parsed: Variant = JSON.parse_string(file.get_as_text())
        if parsed is Dictionary:
            territories = parsed.get("territories", {})
    _build_title()
    _build_map()
    _build_loading()
    _show_page(title_page)
    resized.connect(_place_markers)

func _process(delta: float) -> void:
    if loading_path == "":
        return
    load_time += delta
    var progress: Array = []
    var state := ResourceLoader.load_threaded_get_status(loading_path, progress)
    var fraction := float(progress[0]) if not progress.is_empty() else 0.0
    load_bar.value = fraction * 100.0
    load_caption.text = "Opening Ashenreach  •  %d%%" % int(fraction * 100.0)
    if state == ResourceLoader.THREAD_LOAD_LOADED:
        var packed := ResourceLoader.load_threaded_get(loading_path) as PackedScene
        loading_path = ""
        if packed:
            get_tree().change_scene_to_packed(packed)
        else:
            _loading_failed()
    elif state == ResourceLoader.THREAD_LOAD_FAILED or state == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
        loading_path = ""
        _loading_failed()

func _fill_panel() -> Control:
    var panel := Control.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(panel)
    return panel

func _show_page(page: Control) -> void:
    title_page.visible = page == title_page
    map_page.visible = page == map_page
    load_page.visible = page == load_page
    if page == map_page:
        call_deferred("_place_markers")

func _style(color: Color, border: Color = Color("897451")) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = color
    box.border_color = border
    box.set_border_width_all(2)
    box.set_corner_radius_all(9)
    return box

func _label(value: String, size_px: int, color: Color = Color("e8d9b9")) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size", size_px)
    label.modulate = color
    return label

func _button(value: String, action: Callable) -> Button:
    var button := Button.new()
    button.text = value
    button.custom_minimum_size.y = 48
    button.add_theme_stylebox_override("normal", _style(Color("202e33")))
    button.add_theme_stylebox_override("hover", _style(Color("354447"), Color("d7ab60")))
    button.pressed.connect(action)
    return button

func _build_title() -> void:
    title_page = _fill_panel()
    var backdrop := TextureRect.new()
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.texture = load("res://assets/battle/ashenreach_basalt_arena.jpg")
    backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    title_page.add_child(backdrop)
    var veil := ColorRect.new()
    veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    veil.color = Color(0.015, 0.025, 0.032, 0.79)
    title_page.add_child(veil)
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    title_page.add_child(center)
    var stack := VBoxContainer.new()
    stack.custom_minimum_size.x = 440
    stack.add_theme_constant_override("separation", 10)
    center.add_child(stack)
    var crest := TextureRect.new()
    crest.texture = load("res://assets/ui/shattered_sigil.svg")
    crest.custom_minimum_size = Vector2(116, 116)
    crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    stack.add_child(crest)
    var eyebrow := _label("THE CAMPAIGN BEGINS", 17, Color("c39357"))
    eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stack.add_child(eyebrow)
    var title := _label("SHATTERED\nREALMS", 62)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stack.add_child(title)
    var subtitle := _label("Gather your heroes. Cross the broken kingdoms. Claim the strongholds.", 16, Color("aebfc0"))
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    stack.add_child(subtitle)
    var space := Control.new()
    space.custom_minimum_size.y = 22
    stack.add_child(space)
    stack.add_child(_button("CONTINUE CAMPAIGN" if FileAccess.file_exists("user://ashenreach_save.cfg") else "EXPLORE THE WORLD", _open_map))
    var small := _label("ASHENREACH  •  EARLY CAMPAIGN", 12, Color("c39357"))
    small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stack.add_child(small)

func _build_map() -> void:
    map_page = _fill_panel()
    map_page.add_theme_color_override("font_color", Color("e8d9b9"))
    var bg := ColorRect.new()
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.color = Color("101820")
    map_page.add_child(bg)
    var page := VBoxContainer.new()
    page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    page.add_theme_constant_override("separation", 8)
    map_page.add_child(page)
    var header := HBoxContainer.new()
    header.custom_minimum_size.y = 64
    page.add_child(header)
    var title := _label("  SHATTERED REALMS  /  WORLD ATLAS", 25, Color("d6a865"))
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    header.add_child(_button("TITLE", func(): _show_page(title_page)))
    var row := HBoxContainer.new()
    row.size_flags_vertical = Control.SIZE_EXPAND_FILL
    row.add_theme_constant_override("separation", 10)
    page.add_child(row)
    var atlas_panel := PanelContainer.new()
    atlas_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    atlas_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    atlas_panel.add_theme_stylebox_override("panel", _style(Color("10232c")))
    row.add_child(atlas_panel)
    map_canvas = Control.new()
    map_canvas.set_script(MAP_SCRIPT)
    map_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
    atlas_panel.add_child(map_canvas)
    map_canvas.resized.connect(_place_markers)
    for region_id in MAP_POINTS:
        var marker := Button.new()
        marker.text = str(territories.get(region_id, {}).get("name", region_id))
        marker.custom_minimum_size = Vector2(120, 38)
        marker.add_theme_stylebox_override("normal", _style(Color(0.07, 0.13, 0.16, 0.88), Color("9d825a")))
        marker.pressed.connect(_select_region.bind(region_id))
        map_canvas.add_child(marker)
        map_markers[region_id] = marker
    var info := PanelContainer.new()
    info.custom_minimum_size.x = 300
    info.size_flags_vertical = Control.SIZE_EXPAND_FILL
    info.add_theme_stylebox_override("panel", _style(Color("19252a")))
    row.add_child(info)
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 18)
    margin.add_theme_constant_override("margin_right", 18)
    margin.add_theme_constant_override("margin_top", 18)
    margin.add_theme_constant_override("margin_bottom", 18)
    info.add_child(margin)
    var details := VBoxContainer.new()
    details.add_theme_constant_override("separation", 16)
    margin.add_child(details)
    details.add_child(_label("CAMPAIGN ATLAS", 14, Color("b99865")))
    detail_name = _label("", 27)
    detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    details.add_child(detail_name)
    detail_type = _label("", 14, Color("c59557"))
    details.add_child(detail_type)
    var line := HSeparator.new()
    details.add_child(line)
    detail_body = _label("", 16, Color("c4d0ce"))
    detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    detail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    details.add_child(detail_body)
    enter_button = _button("ENTER ASHENREACH", _enter_region)
    details.add_child(enter_button)
    var foot := _label("Select a territory to inspect its campaign route. The remaining lands open as their maps are built.", 12, Color("9badae"))
    foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    page.add_child(foot)
    _select_region(current_region)

func _place_markers() -> void:
    if not map_canvas or map_canvas.size.x < 1.0:
        return
    for region_id in MAP_POINTS:
        var button: Button = map_markers[region_id]
        var point: Vector2 = MAP_POINTS[region_id] * map_canvas.size
        button.position = point + Vector2(-button.size.x * 0.5, 17)
        button.position.x = clampf(button.position.x, 8, map_canvas.size.x - button.size.x - 8)
        button.position.y = clampf(button.position.y, 8, map_canvas.size.y - button.size.y - 8)

func _select_region(region_id: String) -> void:
    current_region = region_id
    if map_canvas:
        map_canvas.set("selected_region", region_id)
    var region: Dictionary = territories.get(region_id, {})
    detail_name.text = str(region.get("name", region_id))
    var playable: bool = region_id == "ashen_wastes" and (region.get("boards", []) as Array).has("ashenreach")
    detail_type.text = "PLAYABLE STRONGHOLD" if playable else "FUTURE CAMPAIGN"
    var guardian := str(region.get("legendary_monster", "unknown")).replace("_", " ").capitalize()
    var stronghold := str(region.get("stronghold", "Uncharted stronghold"))
    detail_body.text = "%s\n\nLegendary threat: %s\n\n%s" % [stronghold, guardian, "Continue your saved expedition or enter the Ashenreach board." if playable else "This region is mapped in the atlas. Its campaign board is still in development."]
    enter_button.visible = playable

func _open_map() -> void:
    _show_page(map_page)

func _enter_region() -> void:
    if current_region != "ashen_wastes" or loading_path != "":
        return
    _show_page(load_page)
    load_time = 0.0
    load_bar.value = 0
    load_caption.text = "Preparing Ashenreach..."
    var error := ResourceLoader.load_threaded_request(ASHENREACH_SCENE)
    if error == OK:
        loading_path = ASHENREACH_SCENE
    else:
        _loading_failed()

func _build_loading() -> void:
    load_page = _fill_panel()
    var bg := ColorRect.new()
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.color = Color("101b22")
    load_page.add_child(bg)
    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    load_page.add_child(center)
    var column := VBoxContainer.new()
    column.custom_minimum_size.x = 460
    column.add_theme_constant_override("separation", 22)
    center.add_child(column)
    var title := _label("SHATTERED REALMS", 36, Color("d6a865"))
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(title)
    var lore := _label("Beyond the burning wastes, a city waits beneath the ash.", 17)
    lore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(lore)
    load_bar = ProgressBar.new()
    load_bar.show_percentage = false
    load_bar.custom_minimum_size.y = 12
    column.add_child(load_bar)
    load_caption = _label("Preparing Ashenreach...", 14, Color("a9babb"))
    load_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    column.add_child(load_caption)

func _loading_failed() -> void:
    _show_page(map_page)
    detail_body.text = "Ashenreach could not load. Please try entering again."
