extends Node3D
## Room dressing for painted city scenes. Props are real meshes placed on the
## projected floor plane, so depth testing naturally lets actors pass behind them.

var _prop_root: Node3D
var _screen_size := Vector2(1280.0, 720.0)
var _project_to_floor: Callable
var _palette: Dictionary


func configure_for_room(region_id: String, screen_id: String, screen_size: Vector2, project_to_floor: Callable) -> void:
	if is_instance_valid(_prop_root):
		_prop_root.queue_free()
	_prop_root = Node3D.new()
	_prop_root.name = "RoomDepthProps"
	add_child(_prop_root)
	_screen_size = Vector2(maxf(screen_size.x, 1.0), maxf(screen_size.y, 1.0))
	_project_to_floor = project_to_floor
	_palette = _palette_for(region_id)
	for prop in _layout_for(screen_id, region_id):
		_spawn_prop(prop)


func _palette_for(region_id: String) -> Dictionary:
	if region_id == "stormcrown_mountains" or region_id == "stormcrown":
		return {
			"stone": Color("#65727b"), "stone_light": Color("#a3adb0"),
			"stone_dark": Color("#394750"), "timber": Color("#684f3d"),
			"timber_light": Color("#94785a"), "metal": Color("#a8b7bc"),
			"metal_dark": Color("#53646b"), "cloth": Color("#6e3034"),
			"glow": Color("#f4b85b"), "snow": Color("#dce7e8")
		}
	if region_id == "ashen_wastes":
		return {
			"stone": Color("#65564d"), "stone_light": Color("#9b8170"),
			"stone_dark": Color("#3c3532"), "timber": Color("#594038"),
			"timber_light": Color("#8c6448"), "metal": Color("#a17a54"),
			"metal_dark": Color("#493d37"), "cloth": Color("#743c31"),
			"glow": Color("#ffad4c"), "snow": Color("#927e70")
		}
	return {
		"stone": Color("#66716e"), "stone_light": Color("#9ba69b"),
		"stone_dark": Color("#3d4845"), "timber": Color("#624e3b"),
		"timber_light": Color("#9a7b56"), "metal": Color("#9eaa9f"),
		"metal_dark": Color("#46524d"), "cloth": Color("#725044"),
		"glow": Color("#f0bb67"), "snow": Color("#c4d1cb")
	}


func _layout_for(screen_id: String, region_id: String) -> Array[Dictionary]:
	var storm := region_id == "stormcrown_mountains" or region_id == "stormcrown"
	var cold_edge := "snowbank" if storm else "boulder"
	match screen_id:
		"plaza":
			return [
				{"kind": "lantern", "point": Vector2(0.24, 0.57), "scale": 0.85},
				{"kind": "banner", "point": Vector2(0.76, 0.52), "scale": 0.85},
				{"kind": "rail", "point": Vector2(0.12, 0.80), "scale": 1.1},
				{"kind": "rail", "point": Vector2(0.88, 0.80), "scale": 1.1},
				{"kind": cold_edge, "point": Vector2(0.06, 0.87), "scale": 0.9},
				{"kind": cold_edge, "point": Vector2(0.94, 0.87), "scale": 0.9}
			]
		"market":
			return [
				{"kind": "awning", "point": Vector2(0.16, 0.48), "scale": 1.0},
				{"kind": "crate", "point": Vector2(0.29, 0.68), "scale": 0.9},
				{"kind": "barrel", "point": Vector2(0.82, 0.74), "scale": 0.9},
				{"kind": "sign", "point": Vector2(0.66, 0.50), "scale": 0.9},
				{"kind": cold_edge, "point": Vector2(0.08, 0.85), "scale": 1.0}
			]
		"living":
			return [
				{"kind": "woodpile", "point": Vector2(0.16, 0.73), "scale": 1.0},
				{"kind": "lantern", "point": Vector2(0.82, 0.55), "scale": 0.78},
				{"kind": "bench", "point": Vector2(0.72, 0.80), "scale": 0.95},
				{"kind": cold_edge, "point": Vector2(0.08, 0.86), "scale": 1.0}
			]
		"forge":
			return [
				{"kind": "forge", "point": Vector2(0.20, 0.58), "scale": 1.05},
				{"kind": "anvil", "point": Vector2(0.72, 0.68), "scale": 0.8},
				{"kind": "barrel", "point": Vector2(0.86, 0.77), "scale": 0.8},
				{"kind": "tool_rack", "point": Vector2(0.80, 0.49), "scale": 0.8}
			]
		"inn":
			return [
				{"kind": "hearth", "point": Vector2(0.18, 0.50), "scale": 0.95},
				{"kind": "bench", "point": Vector2(0.36, 0.72), "scale": 1.0},
				{"kind": "table", "point": Vector2(0.67, 0.69), "scale": 0.92},
				{"kind": "barrel", "point": Vector2(0.86, 0.75), "scale": 0.86}
			]
		"weapons":
			return [
				{"kind": "tool_rack", "point": Vector2(0.18, 0.52), "scale": 1.0},
				{"kind": "anvil", "point": Vector2(0.78, 0.68), "scale": 0.9},
				{"kind": "banner", "point": Vector2(0.84, 0.44), "scale": 0.72},
				{"kind": "lantern", "point": Vector2(0.12, 0.72), "scale": 0.75}
			]
		"armor":
			return [
				{"kind": "tool_rack", "point": Vector2(0.18, 0.50), "scale": 0.94},
				{"kind": "shield_rack", "point": Vector2(0.82, 0.53), "scale": 0.94},
				{"kind": "bench", "point": Vector2(0.70, 0.74), "scale": 0.85},
				{"kind": "banner", "point": Vector2(0.14, 0.40), "scale": 0.72}
			]
		"relics":
			return [
				{"kind": "pillar", "point": Vector2(0.15, 0.58), "scale": 0.82},
				{"kind": "pillar", "point": Vector2(0.85, 0.58), "scale": 0.82},
				{"kind": "lantern", "point": Vector2(0.24, 0.40), "scale": 0.72},
				{"kind": "sign", "point": Vector2(0.78, 0.43), "scale": 0.8}
			]
		"apothecary":
			return [
				{"kind": "table", "point": Vector2(0.22, 0.68), "scale": 0.88},
				{"kind": "barrel", "point": Vector2(0.80, 0.69), "scale": 0.82},
				{"kind": "shelf", "point": Vector2(0.16, 0.48), "scale": 0.9},
				{"kind": "lantern", "point": Vector2(0.85, 0.40), "scale": 0.72}
			]
		"barracks":
			return [
				{"kind": "table", "point": Vector2(0.51, 0.56), "scale": 0.78},
				{"kind": "tool_rack", "point": Vector2(0.15, 0.52), "scale": 0.82},
				{"kind": "shield_rack", "point": Vector2(0.85, 0.52), "scale": 0.86},
				{"kind": "banner", "point": Vector2(0.78, 0.37), "scale": 0.76}
			]
		"beacon":
			return [
				{"kind": "pillar", "point": Vector2(0.16, 0.57), "scale": 1.0},
				{"kind": "pillar", "point": Vector2(0.84, 0.57), "scale": 1.0},
				{"kind": "banner", "point": Vector2(0.30, 0.43), "scale": 0.78},
				{"kind": "banner", "point": Vector2(0.70, 0.43), "scale": 0.78},
				{"kind": "snowbank", "point": Vector2(0.08, 0.82), "scale": 0.9}
			]
		"keep":
			return [
				{"kind": "pillar", "point": Vector2(0.19, 0.55), "scale": 1.0},
				{"kind": "pillar", "point": Vector2(0.81, 0.55), "scale": 1.0},
				{"kind": "banner", "point": Vector2(0.34, 0.49), "scale": 0.8},
				{"kind": "banner", "point": Vector2(0.66, 0.49), "scale": 0.8}
			]
		"gate":
			return [
				{"kind": "pillar", "point": Vector2(0.22, 0.56), "scale": 1.25},
				{"kind": "pillar", "point": Vector2(0.78, 0.56), "scale": 1.25},
				{"kind": "lantern", "point": Vector2(0.10, 0.72), "scale": 0.9},
				{"kind": "lantern", "point": Vector2(0.90, 0.72), "scale": 0.9},
				{"kind": cold_edge, "point": Vector2(0.06, 0.87), "scale": 1.1},
				{"kind": cold_edge, "point": Vector2(0.94, 0.87), "scale": 1.1}
			]
	return []


func _spawn_prop(prop: Dictionary) -> void:
	if _project_to_floor.is_null():
		return
	var point: Vector2 = prop.get("point", Vector2(0.5, 0.7))
	var floor_point: Vector3 = _project_to_floor.call(Vector2(point.x * _screen_size.x, point.y * _screen_size.y))
	if not is_finite(floor_point.x) or not is_finite(floor_point.y) or not is_finite(floor_point.z):
		return
	var root := Node3D.new()
	root.position = floor_point
	root.scale = Vector3.ONE * float(prop.get("scale", 1.0))
	_prop_root.add_child(root)
	match str(prop.get("kind", "")):
		"lantern": _lantern(root)
		"banner": _banner(root)
		"rail": _rail(root)
		"boulder": _boulder(root, false)
		"snowbank": _boulder(root, true)
		"awning": _awning(root)
		"crate": _crate(root)
		"barrel": _barrel(root)
		"sign": _sign(root)
		"bench": _bench(root)
		"woodpile": _woodpile(root)
		"forge": _forge(root)
		"anvil": _anvil(root)
		"tool_rack": _tool_rack(root)
		"shield_rack": _shield_rack(root)
		"shelf": _shelf(root)
		"hearth": _hearth(root)
		"table": _table(root)
		"pillar": _pillar(root)


func _color(name: String) -> Color:
	return _palette.get(name, Color.WHITE)


func _box(parent: Node3D, at: Vector3, dimensions: Vector3, color_name: String, rotation_y: float = 0.0) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh_instance.mesh = mesh
	mesh_instance.position = at
	mesh_instance.rotation.y = rotation_y
	mesh_instance.material_override = _material(color_name)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh_instance)


func _cylinder(parent: Node3D, at: Vector3, dimensions: Vector3, color_name: String, radial_segments: int = 8) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = dimensions.x * 0.5
	mesh.bottom_radius = dimensions.x * 0.58
	mesh.height = dimensions.y
	mesh.radial_segments = radial_segments
	mesh_instance.mesh = mesh
	mesh_instance.position = at
	mesh_instance.material_override = _material(color_name)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh_instance)


func _sphere(parent: Node3D, at: Vector3, dimensions: Vector3, color_name: String, segments: int = 8) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = segments
	mesh.rings = 4
	mesh_instance.mesh = mesh
	mesh_instance.position = at
	mesh_instance.scale = dimensions
	mesh_instance.material_override = _material(color_name)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh_instance)


func _material(color_name: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = _color(color_name)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.roughness = 1.0
	return material


func _lantern(root: Node3D) -> void:
	_box(root, Vector3(0, 0.52, 0), Vector3(0.12, 1.05, 0.12), "metal_dark")
	_box(root, Vector3(0, 1.08, 0), Vector3(0.30, 0.30, 0.30), "metal")
	_sphere(root, Vector3(0, 1.10, 0), Vector3(0.19, 0.23, 0.19), "glow")


func _banner(root: Node3D) -> void:
	_box(root, Vector3(0, 0.90, 0), Vector3(0.07, 1.8, 0.07), "metal")
	_box(root, Vector3(0.25, 1.37, 0), Vector3(0.52, 0.78, 0.05), "cloth")


func _rail(root: Node3D) -> void:
	for x in [-0.70, 0.70]:
		_box(root, Vector3(x, 0.32, 0), Vector3(0.20, 0.65, 0.24), "stone_light")
	_box(root, Vector3(0, 0.56, 0), Vector3(1.52, 0.18, 0.30), "stone")
	_box(root, Vector3(0, 0.24, 0), Vector3(1.42, 0.14, 0.22), "stone_dark")


func _boulder(root: Node3D, snow: bool) -> void:
	var main_color := "snow" if snow else "stone"
	var accent := "stone_light" if snow else "stone_dark"
	_sphere(root, Vector3(-0.20, 0.24, 0), Vector3(0.76, 0.50, 0.63), main_color, 7)
	_sphere(root, Vector3(0.22, 0.30, -0.08), Vector3(0.68, 0.62, 0.66), accent, 7)
	_sphere(root, Vector3(0.05, 0.08, 0.16), Vector3(1.08, 0.22, 0.72), main_color, 7)


func _awning(root: Node3D) -> void:
	_box(root, Vector3(0, 1.28, 0), Vector3(1.50, 0.10, 0.80), "cloth")
	for x in [-0.62, 0.62]:
		_box(root, Vector3(x, 0.63, 0), Vector3(0.08, 1.25, 0.08), "timber")


func _crate(root: Node3D) -> void:
	_box(root, Vector3(0, 0.34, 0), Vector3(0.68, 0.68, 0.58), "timber")
	_box(root, Vector3(0, 0.35, 0.30), Vector3(0.72, 0.08, 0.04), "timber_light")
	_box(root, Vector3(0, 0.35, -0.30), Vector3(0.72, 0.08, 0.04), "timber_light")


func _barrel(root: Node3D) -> void:
	_cylinder(root, Vector3(0, 0.43, 0), Vector3(0.68, 0.84, 0.64), "timber", 10)
	for y in [0.20, 0.65]:
		_cylinder(root, Vector3(0, y, 0), Vector3(0.73, 0.07, 0.68), "metal_dark", 10)


func _sign(root: Node3D) -> void:
	_box(root, Vector3(0, 0.63, 0), Vector3(0.08, 1.25, 0.08), "timber")
	_box(root, Vector3(0.19, 1.04, 0), Vector3(0.60, 0.38, 0.08), "timber_light")


func _bench(root: Node3D) -> void:
	_box(root, Vector3(0, 0.43, 0), Vector3(1.00, 0.13, 0.34), "timber_light")
	for x in [-0.38, 0.38]:
		_box(root, Vector3(x, 0.21, 0), Vector3(0.10, 0.45, 0.30), "timber")


func _woodpile(root: Node3D) -> void:
	for row in range(3):
		_box(root, Vector3(0, 0.13 + row * 0.19, 0), Vector3(0.86, 0.16, 0.20), "timber_light" if row % 2 == 0 else "timber", 0.0 if row % 2 == 0 else 0.08)


func _forge(root: Node3D) -> void:
	_box(root, Vector3(0, 0.42, 0), Vector3(0.95, 0.80, 0.76), "stone_dark")
	_box(root, Vector3(0, 0.82, -0.02), Vector3(0.66, 0.35, 0.60), "metal_dark")
	_box(root, Vector3(0, 0.48, 0.40), Vector3(0.48, 0.24, 0.06), "glow")


func _anvil(root: Node3D) -> void:
	_box(root, Vector3(0, 0.38, 0), Vector3(0.35, 0.72, 0.34), "metal_dark")
	_box(root, Vector3(0, 0.79, 0), Vector3(0.88, 0.22, 0.42), "metal")
	_box(root, Vector3(0.45, 0.79, 0), Vector3(0.24, 0.14, 0.30), "metal")


func _tool_rack(root: Node3D) -> void:
	_box(root, Vector3(0, 0.65, 0), Vector3(0.08, 1.30, 0.08), "timber")
	_box(root, Vector3(0, 1.20, 0), Vector3(0.90, 0.10, 0.10), "timber_light")
	for x in [-0.30, 0.0, 0.30]:
		_box(root, Vector3(x, 0.79, 0.06), Vector3(0.06, 0.70, 0.06), "metal")


func _shield_rack(root: Node3D) -> void:
	_box(root, Vector3(0, 0.65, -0.10), Vector3(1.0, 1.25, 0.12), "timber")
	for x in [-0.30, 0.0, 0.30]:
		_box(root, Vector3(x, 0.95, 0.02), Vector3(0.24, 0.38, 0.08), "metal_dark")
		_box(root, Vector3(x, 0.96, 0.07), Vector3(0.06, 0.28, 0.03), "metal")
		_box(root, Vector3(x, 1.28, 0.02), Vector3(0.27, 0.06, 0.08), "metal")


func _shelf(root: Node3D) -> void:
	for x in [-0.40, 0.40]:
		_box(root, Vector3(x, 0.85, 0), Vector3(0.08, 1.65, 0.12), "timber")
	for y in [0.35, 0.86, 1.37]:
		_box(root, Vector3(0, y, 0), Vector3(0.92, 0.10, 0.30), "timber_light")
		for x in [-0.28, 0.0, 0.28]:
			_cylinder(root, Vector3(x, y + 0.18, 0.02), Vector3(0.12, 0.32, 0.12), "glow", 8)


func _hearth(root: Node3D) -> void:
	_box(root, Vector3(0, 0.43, 0), Vector3(0.90, 0.82, 0.66), "stone")
	_box(root, Vector3(0, 0.48, 0.36), Vector3(0.52, 0.30, 0.04), "glow")
	_box(root, Vector3(0, 1.16, -0.12), Vector3(0.22, 0.95, 0.22), "stone_dark")


func _table(root: Node3D) -> void:
	_box(root, Vector3(0, 0.66, 0), Vector3(0.90, 0.16, 0.70), "timber_light")
	for x in [-0.30, 0.30]:
		_box(root, Vector3(x, 0.32, 0), Vector3(0.12, 0.62, 0.58), "timber")


func _pillar(root: Node3D) -> void:
	_box(root, Vector3(0, 0.16, 0), Vector3(0.70, 0.28, 0.70), "stone_dark")
	_box(root, Vector3(0, 0.89, 0), Vector3(0.52, 1.20, 0.52), "stone")
	_box(root, Vector3(0, 1.55, 0), Vector3(0.72, 0.20, 0.72), "stone_light")
