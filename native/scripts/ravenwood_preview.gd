extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var movement_root: Node3D = $MovementRoot
@onready var terrain_root: Node3D = $TerrainRoot
@onready var toggle_button: Button = $UI/TopBar/Row/MovementButton
var orbit_angle := 0.0
var distance := 36.0
var dragging := false
var touches: Dictionary = {}
var last_pinch := 0.0
const TARGET := Vector3(0.0, 4.5, 0.0)

func _ready() -> void:
    var terrain_material := StandardMaterial3D.new()
    terrain_material.albedo_texture = preload("res://assets/3d/game-ready/ravenwood-board/ravenwood_albedo.jpg")
    terrain_material.normal_enabled = true
    terrain_material.normal_texture = preload("res://assets/3d/game-ready/ravenwood-board/ravenwood_normal.jpg")
    var metal_rough := preload("res://assets/3d/game-ready/ravenwood-board/ravenwood_metal_rough.jpg")
    terrain_material.metallic = 1.0
    terrain_material.metallic_texture = metal_rough
    terrain_material.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
    terrain_material.roughness = 1.0
    terrain_material.roughness_texture = metal_rough
    terrain_material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
    for mesh in terrain_root.find_children("*", "MeshInstance3D", true, false):
        (mesh as MeshInstance3D).material_override = terrain_material
    var overlay := StandardMaterial3D.new()
    overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    overlay.albedo_color = Color(0.08, 0.9, 0.48, 0.54)
    overlay.emission_enabled = true
    overlay.emission = Color(0.03, 0.7, 0.37)
    overlay.emission_energy_multiplier = 0.7
    for mesh in movement_root.find_children("*", "MeshInstance3D", true, false):
        (mesh as MeshInstance3D).material_override = overlay
    toggle_button.pressed.connect(_toggle_movement)
    $UI/TopBar/Row/WorldButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/FrontEnd.tscn"))
    _update_camera()

func _toggle_movement() -> void:
    movement_root.visible = not movement_root.visible
    toggle_button.text = "HIDE MOVEMENT" if movement_root.visible else "SHOW MOVEMENT"

func _update_camera() -> void:
    camera.position = TARGET + Vector3(sin(orbit_angle)*distance*0.72, distance*0.72, cos(orbit_angle)*distance*0.72)
    camera.look_at(TARGET, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            dragging = event.pressed
        elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
            distance = clampf(distance + (-2.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 2.0),17.0,65.0)
            _update_camera()
    elif event is InputEventMouseMotion and dragging:
        orbit_angle -= event.relative.x*0.006
        _update_camera()
    elif event is InputEventScreenTouch:
        if event.pressed: touches[event.index] = event.position
        else: touches.erase(event.index)
        last_pinch = 0.0
    elif event is InputEventScreenDrag:
        touches[event.index] = event.position
        if touches.size() == 1:
            orbit_angle -= event.relative.x*0.006
            _update_camera()
        elif touches.size() == 2:
            var points := touches.values()
            var pinch := (points[0] as Vector2).distance_to(points[1] as Vector2)
            if last_pinch > 0.0:
                distance = clampf(distance-(pinch-last_pinch)*0.065,17.0,65.0)
                _update_camera()
            last_pinch = pinch
