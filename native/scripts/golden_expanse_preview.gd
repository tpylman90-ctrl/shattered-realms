extends Node3D

const NAV_DATA := "res://data/generated/golden_expanse_nav_grid.json"
const START := Vector2(-17.0, -11.0)

@onready var camera: Camera3D = $Camera3D
@onready var movement_root: Node3D = $MovementRoot
@onready var title_label: Label = $UI/TopBar/Row/Title
@onready var movement_button: Button = $UI/TopBar/Row/MovementButton
@onready var status_label: Label = $UI/BottomBar/Status
@onready var art_preview: TextureRect = $UI/ArtPreview
@onready var art_button: Button = $UI/TopBar/Row/ArtButton

var cells: Array = []
var routes := AStar3D.new()
var hero: Node3D
var current_hex := -1
var queued_path: PackedInt64Array = PackedInt64Array()
var orbit := -0.75
var elevation := 0.80
var distance := 44.0
var target := Vector3(0, 0, 0)
var mouse_down := Vector2.ZERO
var left_dragging := false
var right_dragging := false
var touches: Dictionary = {}
var pinch_distance := 0.0
var touch_start := Vector2.ZERO
var touch_moved := false


func _ready() -> void:
    var file := FileAccess.open(NAV_DATA, FileAccess.READ)
    if file == null:
        status_label.text = "Movement data unavailable"
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        status_label.text = "Movement data is invalid"
        return
    cells = parsed.get("cells", [])
    for i in range(cells.size()):
        var cell: Dictionary = cells[i]
        var weight := 0.85 if cell.get("terrain") == "road" else 0.90 if cell.get("terrain") == "bridge" else 1.0
        routes.add_point(i, _cell_position(i), weight)
    for i in range(cells.size()):
        for neighbor in cells[i].get("neighbors", []):
            var j := int(neighbor)
            if j > i:
                routes.connect_points(i, j)
    title_label.text = "THE GOLDEN EXPANSE  •  %s MOVEMENT HEXES" % _comma(cells.size())
    movement_button.pressed.connect(_toggle_movement)
    art_button.pressed.connect(_toggle_art)
    $UI/TopBar/Row/ResetButton.pressed.connect(_reset_camera)
    $UI/TopBar/Row/WorldButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/FrontEnd.tscn"))
    current_hex = _closest_cell(START)
    _make_hero()
    _update_camera()


func _comma(value: int) -> String:
    var result := str(value)
    var at := result.length() - 3
    while at > 0:
        result = result.insert(at, ",")
        at -= 3
    return result


func _cell_position(i: int) -> Vector3:
    var c: Dictionary = cells[i]
    return Vector3(float(c["x"]), float(c["y"]), float(c["z"]))


func _closest_cell(point: Vector2) -> int:
    var best := -1
    var best_distance := INF
    for i in range(cells.size()):
        var c: Dictionary = cells[i]
        var d := point.distance_squared_to(Vector2(float(c["x"]), float(c["z"])))
        if d < best_distance:
            best_distance = d
            best = i
    return best


func _make_hero() -> void:
    hero = Node3D.new()
    hero.name = "CaravanScout"
    add_child(hero)
    var base := MeshInstance3D.new()
    var base_mesh := CylinderMesh.new()
    base_mesh.top_radius = 0.31
    base_mesh.bottom_radius = 0.37
    base_mesh.height = 0.18
    base.mesh = base_mesh
    base.position.y = 0.12
    var bronze := StandardMaterial3D.new()
    bronze.albedo_color = Color("70532c")
    bronze.metallic = 0.45
    base.material_override = bronze
    hero.add_child(base)
    var figure := MeshInstance3D.new()
    var figure_mesh := CapsuleMesh.new()
    figure_mesh.radius = 0.20
    figure_mesh.height = 0.84
    figure.mesh = figure_mesh
    figure.position.y = 0.62
    var cloth := StandardMaterial3D.new()
    cloth.albedo_color = Color("e5c582")
    figure.material_override = cloth
    hero.add_child(figure)
    var facing := MeshInstance3D.new()
    var pointer := PrismMesh.new()
    pointer.size = Vector3(0.34, 0.10, 0.35)
    facing.mesh = pointer
    facing.position = Vector3(0, 0.95, -0.22)
    facing.material_override = bronze
    hero.add_child(facing)
    hero.position = _cell_position(current_hex)


func _process(delta: float) -> void:
    if queued_path.is_empty() or hero == null:
        return
    var next_hex := int(queued_path[0])
    var goal := _cell_position(next_hex)
    var delta_pos := goal - hero.position
    if delta_pos.length() <= 0.06:
        hero.position = goal
        current_hex = next_hex
        queued_path.remove_at(0)
        if queued_path.is_empty():
            status_label.text = "Arrived • %s" % str(cells[current_hex]["terrain"]).capitalize()
        return
    hero.position = hero.position.move_toward(goal, delta * 3.6)
    var horizontal := Vector2(delta_pos.x, delta_pos.z)
    if horizontal.length_squared() > 0.001:
        hero.rotation.y = atan2(-horizontal.x, -horizontal.y)


func _toggle_movement() -> void:
    movement_root.visible = not movement_root.visible
    movement_button.text = "HIDE HEXES" if movement_root.visible else "SHOW HEXES"


func _toggle_art() -> void:
    art_preview.visible = not art_preview.visible
    art_button.text = "3D BOARD" if art_preview.visible else "ART PREVIEW"
    movement_button.disabled = art_preview.visible
    status_label.text = "Golden Expanse concept art • Tap 3D BOARD to explore" if art_preview.visible else "Tap a hex to move • Drag to orbit • Pinch to zoom"


func _update_camera() -> void:
    camera.position = target + Vector3(sin(orbit) * cos(elevation), sin(elevation), cos(orbit) * cos(elevation)) * distance
    camera.look_at(target, Vector3.UP)


func _reset_camera() -> void:
    target = Vector3.ZERO
    orbit = -0.75
    elevation = 0.80
    distance = 44.0
    _update_camera()


func _select_at(screen: Vector2) -> void:
    if cells.is_empty() or art_preview.visible:
        return
    var ray_origin := camera.project_ray_origin(screen)
    var ray_direction := camera.project_ray_normal(screen)
    if absf(ray_direction.y) < 0.05:
        return
    var t := (0.55 - ray_origin.y) / ray_direction.y
    if t < 0:
        return
    var hit := ray_origin + ray_direction * t
    if absf(hit.x) > 21 or absf(hit.z) > 21:
        return
    var selected := _closest_cell(Vector2(hit.x, hit.z))
    var c: Dictionary = cells[selected]
    if Vector2(float(c["x"]), float(c["z"])).distance_to(Vector2(hit.x, hit.z)) > 1.4:
        return
    var path := routes.get_id_path(current_hex, selected)
    if path.size() <= 1:
        status_label.text = "No route to that hex" if path.is_empty() else "Already there"
        return
    queued_path = path
    queued_path.remove_at(0)
    status_label.text = "Moving %d hexes • %s" % [queued_path.size(), str(c["terrain"]).capitalize()]


func _unhandled_input(event: InputEvent) -> void:
    if art_preview.visible:
        return
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                left_dragging = true
                mouse_down = event.position
            elif left_dragging:
                left_dragging = false
                if event.position.distance_to(mouse_down) < 8:
                    _select_at(event.position)
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            right_dragging = event.pressed
        elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
            distance = clampf(distance + (-2.5 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 2.5), 20, 75)
            _update_camera()
    elif event is InputEventMouseMotion:
        if left_dragging:
            orbit -= event.relative.x * 0.006
            elevation = clampf(elevation + event.relative.y * 0.004, 0.42, 1.43)
            _update_camera()
        elif right_dragging:
            target += Vector3(-event.relative.x, 0, -event.relative.y) * (distance * 0.0007)
            target.x = clampf(target.x, -12, 12)
            target.z = clampf(target.z, -12, 12)
            _update_camera()
    elif event is InputEventScreenTouch:
        if event.pressed:
            touches[event.index] = event.position
            if touches.size() == 1:
                touch_start = event.position
                touch_moved = false
        else:
            if touches.size() == 1 and not touch_moved:
                _select_at(event.position)
            touches.erase(event.index)
            pinch_distance = 0.0
    elif event is InputEventScreenDrag:
        touches[event.index] = event.position
        if touches.size() == 1:
            touch_moved = touch_moved or event.position.distance_to(touch_start) > 9
            orbit -= event.relative.x * 0.006
            elevation = clampf(elevation + event.relative.y * 0.004, 0.42, 1.43)
            _update_camera()
        elif touches.size() == 2:
            touch_moved = true
            var points := touches.values()
            var pinch := (points[0] as Vector2).distance_to(points[1] as Vector2)
            if pinch_distance > 0:
                distance = clampf(distance - (pinch - pinch_distance) * 0.06, 20, 75)
                _update_camera()
            pinch_distance = pinch
