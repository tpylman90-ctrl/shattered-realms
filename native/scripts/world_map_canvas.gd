extends Control

signal region_pressed(region_id: String)

const ATLAS := preload("res://assets/ui/front_end/world_atlas.jpg")
# Locations on the supplied 1536 x 1024 illustrated atlas.
const REGIONS := {
    "ashen_wastes": Vector2(0.705, 0.156),
    "blighted_marsh": Vector2(0.842, 0.251),
    "shadowfen_forest": Vector2(0.601, 0.348),
    "cursed_mire": Vector2(0.422, 0.665),
    "dragons_rest": Vector2(0.142, 0.707),
    "ravenwood": Vector2(0.296, 0.167),
    "frostpeaks": Vector2(0.469, 0.117),
    "stormcrown_mountains": Vector2(0.518, 0.251),
    "iron_plains": Vector2(0.421, 0.339),
    "drakeshard_range": Vector2(0.771, 0.37),
    "veiled_sea": Vector2(0.148, 0.267),
    "golden_expanse": Vector2(0.693, 0.589),
    "devouring_deep": Vector2(0.779, 0.698),
    "ember_coast": Vector2(0.330, 0.807),
    "hollow_isles": Vector2(0.744, 0.928),
    "broken_sea": Vector2(0.945, 0.414),
    "stormreach_ocean": Vector2(0.252, 0.917)
}
# Names, city icons, passes and lairs printed on the atlas all lead to their
# containing region. Coordinates use the source image, not the screen size.
const LANDMARKS := {
    "ashen_wastes": [Vector2(0.716, 0.203), Vector2(0.668, 0.105)],
    "blighted_marsh": [Vector2(0.842, 0.295)],
    "shadowfen_forest": [Vector2(0.612, 0.411)],
    "cursed_mire": [Vector2(0.419, 0.712), Vector2(0.312, 0.615)],
    "dragons_rest": [Vector2(0.126, 0.754)],
    "ravenwood": [Vector2(0.287, 0.226), Vector2(0.290, 0.369)],
    "frostpeaks": [Vector2(0.465, 0.071)],
    "stormcrown_mountains": [Vector2(0.525, 0.267)],
    "iron_plains": [Vector2(0.434, 0.364), Vector2(0.495, 0.484)],
    "drakeshard_range": [Vector2(0.697, 0.424), Vector2(0.838, 0.468)],
    "veiled_sea": [Vector2(0.186, 0.385), Vector2(0.166, 0.523)],
    "golden_expanse": [Vector2(0.687, 0.645)],
    "devouring_deep": [Vector2(0.909, 0.57)],
    "ember_coast": [Vector2(0.418, 0.817), Vector2(0.577, 0.812)]
}

var selected_region := "ashen_wastes"
var selected_point := REGIONS["ashen_wastes"]
var pulse_time := 0.0

func _process(delta: float) -> void:
    pulse_time += delta
    queue_redraw()

func atlas_rect() -> Rect2:
    var ratio: float = minf(size.x / float(ATLAS.get_width()), size.y / float(ATLAS.get_height()))
    var draw_size := Vector2(ATLAS.get_size()) * ratio
    return Rect2((size - draw_size) * 0.5, draw_size)

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("101820"))
    var picture := atlas_rect()
    draw_texture_rect(ATLAS, picture, false)
    for region_id in REGIONS:
        var pin: Vector2 = picture.position + REGIONS[region_id] * picture.size
        draw_circle(pin, 3.0, Color(0.97, 0.77, 0.48, 0.72))
    if REGIONS.has(selected_region):
        var center: Vector2 = picture.position + selected_point * picture.size
        var radius := 20.0 + sin(pulse_time * 2.4) * 3.0
        draw_circle(center, radius + 7.0, Color(1.0, 0.69, 0.31, 0.14))
        draw_arc(center, radius, 0, TAU, 48, Color("f3c377"), 3.0, true)
        draw_circle(center, 4.0, Color("f6dc9f"))

func _gui_input(event: InputEvent) -> void:
    var position_on_map := Vector2(-1000, -1000)
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        position_on_map = event.position
    elif event is InputEventScreenTouch and event.pressed:
        position_on_map = event.position
    else:
        return
    select_at(position_on_map)

func select_at(position_on_map: Vector2) -> void:
    var picture := atlas_rect()
    if not picture.has_point(position_on_map):
        return
    var nearest := ""
    var nearest_point := Vector2.ZERO
    var distance := INF
    for region_id in REGIONS:
        var positions: Array = [REGIONS[region_id]]
        positions.append_array(LANDMARKS.get(region_id, []))
        for spot in positions:
            var center: Vector2 = picture.position + (spot as Vector2) * picture.size
            var candidate: float = position_on_map.distance_to(center)
            if candidate < distance:
                nearest = region_id
                nearest_point = spot
                distance = candidate
    if nearest != "":
        selected_region = nearest
        selected_point = nearest_point
        region_pressed.emit(nearest)
        accept_event()
