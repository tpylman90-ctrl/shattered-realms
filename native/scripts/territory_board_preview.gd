extends Control

const CATALOG := "res://data/world_catalog.json"
const ART_ROOT := "res://assets/boards/concept/"

var board_id := "cursed_mire"
var artwork: TextureRect
var title_label: Label
var zoom := 1.0

func _ready() -> void:
    if get_tree().has_meta("preview_territory"):
        board_id = str(get_tree().get_meta("preview_territory"))
    var file := FileAccess.open(CATALOG, FileAccess.READ)
    var catalog: Dictionary = JSON.parse_string(file.get_as_text()) if file else {}
    var territory: Dictionary = catalog.get("territories", {}).get(board_id, {})
    if territory.is_empty():
        territory = catalog.get("locations", {}).get(board_id, {})
    if territory.get("status", "") == "future_ocean_expansion":
        get_tree().change_scene_to_file("res://scenes/FrontEnd.tscn")
        return
    var background := ColorRect.new()
    background.color = Color("101619")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(background)
    artwork = TextureRect.new()
    artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
    artwork.texture = load(ART_ROOT + board_id + ".webp")
    add_child(artwork)
    var bar := PanelContainer.new()
    bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    bar.offset_bottom = 64
    add_child(bar)
    var row := HBoxContainer.new()
    bar.add_child(row)
    title_label = Label.new()
    title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title_label.text = "%s  •  BOARD CONCEPT" % str(territory.get("name", board_id))
    row.add_child(title_label)
    var back := Button.new()
    back.text = "WORLD MAP"
    back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/FrontEnd.tscn"))
    row.add_child(back)
    var caption := Label.new()
    caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    caption.offset_top = -42
    caption.text = "TERRAIN ART PREVIEW  •  3D MODEL AND MOVEMENT LAYER IN DEVELOPMENT"
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(caption)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            zoom = minf(zoom * 1.1, 2.5)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            zoom = maxf(zoom / 1.1, 1.0)
        artwork.scale = Vector2.ONE * zoom
        artwork.pivot_offset = size * 0.5
