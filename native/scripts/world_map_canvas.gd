extends Control

# Coordinates are fractions of the map panel so the atlas fits phone screens.
const REGIONS := {
    "ashen_wastes": {"point": Vector2(0.29, 0.59), "color": Color("ad5e34")},
    "blighted_marsh": {"point": Vector2(0.55, 0.73), "color": Color("627d50")},
    "shadowfen_forest": {"point": Vector2(0.67, 0.38), "color": Color("477466")},
    "cursed_mire": {"point": Vector2(0.75, 0.61), "color": Color("79647f")},
    "dragons_rest": {"point": Vector2(0.43, 0.26), "color": Color("bd7655")}
}

var selected_region := "ashen_wastes"
var drift := 0.0

func _process(delta: float) -> void:
    drift += delta
    queue_redraw()

func _draw() -> void:
    var s := size
    draw_rect(Rect2(Vector2.ZERO, s), Color("10232c"))
    for i in range(12):
        var y := (float(i) + 0.5) * s.y / 12.0
        draw_line(Vector2(0, y), Vector2(s.x, y), Color(0.45, 0.61, 0.63, 0.09), 1.0)
    for i in range(18):
        var x := float(i) * s.x / 17.0
        draw_line(Vector2(x, 0), Vector2(x, s.y), Color(0.45, 0.61, 0.63, 0.07), 1.0)
    _land(PackedVector2Array([Vector2(.09,.17),Vector2(.28,.10),Vector2(.40,.15),Vector2(.52,.10),Vector2(.67,.16),Vector2(.80,.11),Vector2(.92,.23),Vector2(.88,.38),Vector2(.96,.53),Vector2(.87,.78),Vector2(.70,.87),Vector2(.57,.82),Vector2(.45,.91),Vector2(.29,.83),Vector2(.15,.88),Vector2(.06,.70),Vector2(.12,.51),Vector2(.04,.35)]), Color("364841"))
    _land(PackedVector2Array([Vector2(.08,.53),Vector2(.28,.45),Vector2(.42,.51),Vector2(.43,.78),Vector2(.29,.84),Vector2(.14,.81),Vector2(.06,.69)]), Color("625048"))
    _land(PackedVector2Array([Vector2(.43,.57),Vector2(.53,.50),Vector2(.66,.57),Vector2(.72,.80),Vector2(.57,.84),Vector2(.45,.89)]), Color("455747"))
    _land(PackedVector2Array([Vector2(.53,.23),Vector2(.76,.16),Vector2(.90,.28),Vector2(.86,.43),Vector2(.70,.49),Vector2(.57,.42)]), Color("36584f"))
    _path(PackedVector2Array([Vector2(.22,.41),Vector2(.35,.32),Vector2(.45,.26),Vector2(.59,.30),Vector2(.71,.44),Vector2(.77,.60)]), Color("8a8780"), 3.0)
    _path(PackedVector2Array([Vector2(.30,.58),Vector2(.42,.61),Vector2(.54,.72),Vector2(.67,.69),Vector2(.76,.61)]), Color("ba8b52"), 2.0)
    _path(PackedVector2Array([Vector2(.48,.12),Vector2(.51,.29),Vector2(.60,.44),Vector2(.54,.57),Vector2(.61,.78),Vector2(.65,.93)]), Color("4d8790"), 8.0)
    for mountain in [Vector2(.24,.27),Vector2(.30,.23),Vector2(.36,.29),Vector2(.41,.35),Vector2(.78,.26),Vector2(.82,.31)]:
        var p: Vector2 = mountain * s
        draw_polyline(PackedVector2Array([p+Vector2(-12,8),p+Vector2(0,-11),p+Vector2(14,8)]), Color("899087"), 2.0, true)
    for key in REGIONS:
        var region: Dictionary = REGIONS[key]
        var p: Vector2 = region["point"] * s
        var col: Color = region["color"]
        var active: bool = key == selected_region
        var pulse := 1.0 + sin(drift * 2.4) * 0.12 if active else 1.0
        draw_circle(p, (27.0 if active else 20.0) * pulse, Color(col.r,col.g,col.b,0.16))
        draw_arc(p, (20.0 if active else 15.0) * pulse, 0, TAU, 48, col, 2.0, true)
        draw_circle(p, 5.0, col)
    draw_rect(Rect2(Vector2(8,8), s-Vector2(16,16)), Color("b4935f"), false, 2.0)

func _land(points: PackedVector2Array, color: Color) -> void:
    var scaled := PackedVector2Array()
    for p in points:
        scaled.append(p * size)
    draw_colored_polygon(scaled, color)
    scaled.append(scaled[0])
    draw_polyline(scaled, Color("9b9879"), 2.0, true)

func _path(points: PackedVector2Array, color: Color, width: float) -> void:
    var scaled := PackedVector2Array()
    for p in points:
        scaled.append(p * size)
    draw_polyline(scaled, color, width, true)
