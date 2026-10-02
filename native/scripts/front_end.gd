extends Control

const WORLD_DATA := "res://data/world_catalog.json"
const ASHENREACH_SCENE := "res://scenes/AshenreachDemo.tscn"
const RAVENWOOD_PREVIEW_SCENE := "res://scenes/RavenwoodPreview.tscn"
const IRON_PLAINS_PREVIEW_SCENE := "res://scenes/IronPlainsPreview.tscn"
const TERRITORY_PREVIEW_SCENE := "res://scenes/TerritoryBoardPreview.tscn"
const MAP_SCRIPT := preload("res://scripts/world_map_canvas.gd")
const HeroEquipmentService = preload("res://scripts/hero_equipment.gd")

var territories: Dictionary = {}
var current_region := "ashen_wastes"
var title_page: Control
var map_page: Control
var load_page: Control
var map_canvas: Control
var atlas_info: PanelContainer
var detail_name: Label
var detail_type: Label
var detail_body: Label
var enter_button: Button
var armory_popup: PopupPanel
var armory_text: RichTextLabel
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

func _process(delta: float) -> void:
    if loading_path == "":
        return
    load_time += delta
    var progress: Array = []
    var state := ResourceLoader.load_threaded_get_status(loading_path, progress)
    var fraction := float(progress[0]) if not progress.is_empty() else 0.0
    load_bar.value = fraction * 100.0
    var destination := "Ashenreach"
    if loading_path == RAVENWOOD_PREVIEW_SCENE:
        destination = "Ravenwood preview"
    elif loading_path == IRON_PLAINS_PREVIEW_SCENE:
        destination = "Iron Plains preview"
    elif loading_path == TERRITORY_PREVIEW_SCENE:
        destination = str(territories.get(current_region, {}).get("name", current_region)) + " concept"
    load_caption.text = "Opening %s  •  %d%%" % [destination, int(fraction * 100.0)]
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
    backdrop.texture = load("res://assets/ui/front_end/title_heroes.jpg")
    backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    title_page.add_child(backdrop)
    var bottom := PanelContainer.new()
    title_page.add_child(bottom)
    bottom.anchor_left = 0.32
    bottom.anchor_right = 0.68
    bottom.anchor_top = 1.0
    bottom.anchor_bottom = 1.0
    bottom.offset_top = -94
    bottom.offset_bottom = -16
    bottom.add_theme_stylebox_override("panel", _style(Color(0.025, 0.04, 0.05, 0.91), Color("c69a61")))
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 14)
    margin.add_theme_constant_override("margin_right", 14)
    margin.add_theme_constant_override("margin_top", 10)
    margin.add_theme_constant_override("margin_bottom", 10)
    bottom.add_child(margin)
    var button := _button("CONTINUE CAMPAIGN" if FileAccess.file_exists("user://ashenreach_save.cfg") else "ENTER THE REALMS", _open_map)
    button.add_theme_font_size_override("font_size", 21)
    margin.add_child(button)

func _build_map() -> void:
    map_page = _fill_panel()
    map_canvas = Control.new()
    map_canvas.set_script(MAP_SCRIPT)
    map_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    map_page.add_child(map_canvas)
    map_canvas.connect("region_pressed", _select_region)
    var title_button := _button("◀ TITLE", func(): _show_page(title_page))
    map_page.add_child(title_button)
    title_button.anchor_top = 1.0
    title_button.anchor_bottom = 1.0
    title_button.offset_left = 16
    title_button.offset_right = 158
    title_button.offset_top = -67
    title_button.offset_bottom = -14

    var info := PanelContainer.new()
    atlas_info = info
    map_page.add_child(info)
    info.anchor_left = 0.24
    info.anchor_right = 0.76
    info.anchor_top = 1.0
    info.anchor_bottom = 1.0
    info.offset_top = -120
    info.offset_bottom = -12
    info.add_theme_stylebox_override("panel", _style(Color(0.035, 0.065, 0.08, 0.95), Color("c39b67")))
    info.gui_input.connect(_atlas_panel_input.bind(info))
    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 16)
    margin.add_theme_constant_override("margin_right", 16)
    margin.add_theme_constant_override("margin_top", 9)
    margin.add_theme_constant_override("margin_bottom", 9)
    margin.mouse_filter = Control.MOUSE_FILTER_PASS
    info.add_child(margin)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 14)
    row.mouse_filter = Control.MOUSE_FILTER_PASS
    margin.add_child(row)
    var details := VBoxContainer.new()
    details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    details.add_theme_constant_override("separation", 2)
    details.mouse_filter = Control.MOUSE_FILTER_PASS
    row.add_child(details)
    detail_name = _label("", 23)
    detail_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    detail_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
    details.add_child(detail_name)
    detail_type = _label("", 13, Color("d0a365"))
    detail_type.mouse_filter = Control.MOUSE_FILTER_IGNORE
    details.add_child(detail_type)
    detail_body = _label("", 13, Color("c4d0ce"))
    detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    detail_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
    details.add_child(detail_body)
    enter_button = _button("ENTER ASHENREACH", _enter_region)
    enter_button.custom_minimum_size.x = 170
    enter_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    row.add_child(enter_button)
    var armory_button := _button("REGIONAL GEAR", _show_region_armory)
    armory_button.custom_minimum_size.x = 160
    armory_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    row.add_child(armory_button)
    armory_popup = PopupPanel.new()
    armory_popup.title = "REGIONAL ARMORY"
    add_child(armory_popup)
    armory_text = RichTextLabel.new()
    armory_text.custom_minimum_size = Vector2(440, 460)
    armory_text.bbcode_enabled = true
    armory_popup.add_child(armory_text)
    var dismiss := Button.new()
    dismiss.text = "×"
    dismiss.tooltip_text = "Hide territory details"
    dismiss.custom_minimum_size.x = 35
    dismiss.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    dismiss.pressed.connect(info.hide)
    row.add_child(dismiss)
    _select_region(current_region)

func _atlas_panel_input(event: InputEvent, panel: Control) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        var map_point: Vector2 = map_canvas.get_global_transform_with_canvas().affine_inverse() * (panel.get_global_transform_with_canvas() * event.position)
        map_canvas.call("select_at", map_point)
    elif event is InputEventScreenTouch and event.pressed:
        var map_point: Vector2 = map_canvas.get_global_transform_with_canvas().affine_inverse() * (panel.get_global_transform_with_canvas() * event.position)
        map_canvas.call("select_at", map_point)

func _select_region(region_id: String) -> void:
    if str(territories.get(region_id, {}).get("status", "")) == "future_ocean_expansion":
        return
    current_region = region_id
    atlas_info.show()
    if map_canvas:
        map_canvas.set("selected_region", region_id)
    var region: Dictionary = territories.get(region_id, {})
    detail_name.text = str(region.get("name", region_id))
    var playable: bool = region_id == "ashen_wastes" and (region.get("boards", []) as Array).has("ashenreach")
    var has_preview := region_id in ["ravenwood", "iron_plains"]
    var concept_ready := ResourceLoader.exists("res://assets/boards/concept/" + region_id + ".webp")
    detail_type.text = "PLAYABLE STRONGHOLD" if playable else "3D BOARD PREVIEW" if has_preview else "TERRITORY BOARD CONCEPT" if concept_ready else "FUTURE CAMPAIGN"
    var guardian := str(region.get("legendary_monster", "")).replace("_", " ").capitalize()
    var stronghold := str(region.get("stronghold", "Uncharted stronghold"))
    detail_body.text = "%s%s" % [stronghold, "  •  %s" % guardian if guardian != "" else ""]
    enter_button.visible = playable or has_preview or concept_ready
    if region_id == "ravenwood":
        enter_button.text = "PREVIEW RAVENWOOD"
    elif region_id == "iron_plains":
        enter_button.text = "PREVIEW IRON PLAINS"
    elif concept_ready:
        enter_button.text = "PREVIEW BOARD"
    else:
        enter_button.text = "ENTER ASHENREACH"

func _show_region_armory() -> void:
    var pool := HeroEquipmentService.region_pool(current_region)
    if pool.is_empty():
        return
    var region_name := str(territories.get(current_region, {}).get("name", current_region))
    var common: Array = pool.get("common", [])
    var lines: PackedStringArray = ["[b]%s • REGIONAL ARMORY[/b]" % region_name, ""]
    lines.append("The armory records %d common gear designs and a sealed signature piece." % common.size())
    lines.append("Explore, win encounters, secure strategic sites, and raid vaults to discover equipment.")
    lines.append("Each found copy rolls its own rarity, quality, and possible affix.")
    if current_region != "ashen_wastes":
        lines.append("\nThis region's campaign board is in development; its drops are not available yet.")
    armory_text.text = "\n".join(lines)
    armory_popup.popup_centered(Vector2i(470, 490))

func _open_map() -> void:
    _show_page(map_page)

func _enter_region() -> void:
    if loading_path != "" or not enter_button.visible:
        return
    var scene_path := ASHENREACH_SCENE
    if current_region == "ravenwood":
        scene_path = RAVENWOOD_PREVIEW_SCENE
    elif current_region == "iron_plains":
        scene_path = IRON_PLAINS_PREVIEW_SCENE
    else:
        scene_path = TERRITORY_PREVIEW_SCENE
    get_tree().set_meta("preview_territory", current_region)
    _show_page(load_page)
    load_time = 0.0
    load_bar.value = 0
    if current_region == "ravenwood":
        load_caption.text = "Preparing Ravenwood preview..."
    elif current_region == "iron_plains":
        load_caption.text = "Preparing Iron Plains preview..."
    elif scene_path == TERRITORY_PREVIEW_SCENE:
        load_caption.text = "Preparing %s board concept..." % str(territories.get(current_region, {}).get("name", current_region))
    else:
        load_caption.text = "Preparing Ashenreach..."
    var error := ResourceLoader.load_threaded_request(scene_path)
    if error == OK:
        loading_path = scene_path
    else:
        _loading_failed()

func _build_loading() -> void:
    load_page = _fill_panel()
    var artwork := TextureRect.new()
    artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    artwork.texture = load("res://assets/ui/front_end/title_heroes.jpg")
    artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    load_page.add_child(artwork)
    var bg := ColorRect.new()
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.color = Color(0.03, 0.05, 0.07, 0.78)
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
