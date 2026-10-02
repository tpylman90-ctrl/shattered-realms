extends Control

const BOARD_TEXTURE := preload("res://assets/territory_boards/iron_plains.webp")

var viewport_panel: Control
var board_image: TextureRect
var zoom_level := 1.0
var pan_offset := Vector2.ZERO
var dragging := false
var touches: Dictionary = {}
var last_pinch_distance := 0.0

func _ready() -> void:
    _build_preview()

func _build_preview() -> void:
    var backdrop := ColorRect.new()
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.color = Color("11191a")
    add_child(backdrop)

    viewport_panel = Control.new()
    viewport_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    viewport_panel.clip_contents = true
    viewport_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(viewport_panel)

    board_image = TextureRect.new()
    board_image.texture = BOARD_TEXTURE
    board_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    board_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    board_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    board_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
    viewport_panel.add_child(board_image)
    viewport_panel.gui_input.connect(_on_viewport_input)
    viewport_panel.resized.connect(_apply_view)

    var top_bar := PanelContainer.new()
    top_bar.anchor_left = 0.025
    top_bar.anchor_top = 0.025
    top_bar.anchor_right = 0.975
    top_bar.anchor_bottom = 0.115
    top_bar.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.055, 0.06, 0.94), Color("b28b50")))
    add_child(top_bar)
    var top_row := HBoxContainer.new()
    top_row.add_theme_constant_override("separation", 12)
    top_bar.add_child(top_row)

    var title_column := VBoxContainer.new()
    title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top_row.add_child(title_column)
    var title := _label("THE IRON PLAINS  •  HARROWSTEAD", 20, Color("ead4a5"))
    title_column.add_child(title)
    title_column.add_child(_label("TERRITORY BOARD PREVIEW", 12, Color("adbbb4")))
    top_row.add_child(_button("RETURN TO WORLD MAP", _return_to_map))

    var bottom_bar := PanelContainer.new()
    bottom_bar.anchor_left = 0.025
    bottom_bar.anchor_top = 0.89
    bottom_bar.anchor_right = 0.975
    bottom_bar.anchor_bottom = 0.975
    bottom_bar.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.055, 0.06, 0.94), Color("756344")))
    add_child(bottom_bar)
    var bottom_row := HBoxContainer.new()
    bottom_row.add_theme_constant_override("separation", 10)
    bottom_bar.add_child(bottom_row)
    bottom_row.add_child(_label("Drag to inspect  •  Pinch or scroll to zoom", 14, Color("c2c9be")))
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bottom_row.add_child(spacer)
    bottom_row.add_child(_button("−", func(): _set_zoom(zoom_level - 0.15)))
    bottom_row.add_child(_button("+", func(): _set_zoom(zoom_level + 0.15)))
    bottom_row.add_child(_button("RESET VIEW", _reset_view))
    _apply_view()

func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(8)
    style.content_margin_left = 12
    style.content_margin_right = 12
    style.content_margin_top = 7
    style.content_margin_bottom = 7
    return style

func _label(value: String, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    return label

func _button(value: String, action: Callable) -> Button:
    var button := Button.new()
    button.text = value
    button.custom_minimum_size = Vector2(48, 38)
    button.add_theme_stylebox_override("normal", _panel_style(Color("202b2b"), Color("766341")))
    button.add_theme_stylebox_override("hover", _panel_style(Color("34413e"), Color("d1ad6e")))
    button.pressed.connect(action)
    return button

func _on_viewport_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            dragging = event.pressed
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            _set_zoom(zoom_level + 0.12)
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _set_zoom(zoom_level - 0.12)
        viewport_panel.accept_event()
    elif event is InputEventMouseMotion and dragging:
        pan_offset += event.relative
        _apply_view()
        viewport_panel.accept_event()
    elif event is InputEventScreenTouch:
        if event.pressed:
            touches[event.index] = event.position
        else:
            touches.erase(event.index)
        last_pinch_distance = 0.0
        viewport_panel.accept_event()
    elif event is InputEventScreenDrag:
        touches[event.index] = event.position
        if touches.size() == 1:
            pan_offset += event.relative
            _apply_view()
        elif touches.size() == 2:
            var points: Array = touches.values()
            var distance: float = (points[0] as Vector2).distance_to(points[1] as Vector2)
            if last_pinch_distance > 0.0:
                var scale_delta := distance / last_pinch_distance
                _set_zoom(zoom_level * scale_delta)
            last_pinch_distance = distance
        viewport_panel.accept_event()

func _set_zoom(value: float) -> void:
    zoom_level = clampf(value, 1.0, 2.6)
    _apply_view()

func _apply_view() -> void:
    if not is_instance_valid(board_image) or not is_instance_valid(viewport_panel):
        return
    var limit := viewport_panel.size * (zoom_level - 1.0) * 0.5
    pan_offset.x = clampf(pan_offset.x, -limit.x, limit.x)
    pan_offset.y = clampf(pan_offset.y, -limit.y, limit.y)
    board_image.pivot_offset = viewport_panel.size * 0.5
    board_image.position = pan_offset
    board_image.scale = Vector2.ONE * zoom_level

func _reset_view() -> void:
    zoom_level = 1.0
    pan_offset = Vector2.ZERO
    _apply_view()

func _return_to_map() -> void:
    get_tree().change_scene_to_file("res://scenes/FrontEnd.tscn")
