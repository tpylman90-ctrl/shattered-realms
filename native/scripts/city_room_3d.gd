extends Node3D
## A fixed-camera 3D walk space composited over the painted city illustration.
## Screen-space walk boundaries are projected onto a real 3D floor and baked
## into NavigationMesh, while actors render as perspective-correct billboards.

const FRAME_SIZE := Vector2i(24, 32)
const FLOOR_Y := 0.0
const ACTOR_PIXEL_SIZE := 0.045

var camera: Camera3D
var walk_region: NavigationRegion3D
var _view_size := Vector2(1280.0, 720.0)
var _walkable_polygons: Array[PackedVector2Array] = []
var _actors: Dictionary = {}


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "FixedPerspectiveCamera"
	camera.fov = 44.0
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.position = Vector3(0.0, 4.0, 8.0)
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
	camera.current = true

	walk_region = NavigationRegion3D.new()
	walk_region.name = "CityWalkmesh"
	walk_region.navigation_layers = 1
	add_child(walk_region)


func set_view_size(control_size: Vector2) -> void:
	_view_size = Vector2(maxf(1.0, control_size.x), maxf(1.0, control_size.y))
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_rebuild_walkmesh()


func configure_walkmesh(polygons: Array[PackedVector2Array]) -> void:
	_walkable_polygons = polygons.duplicate()
	_rebuild_walkmesh()


func sync_actor(proxy: Object, texture: Texture2D, frame: int, screen_point: Vector2) -> void:
	if not is_instance_valid(proxy) or not texture:
		return
	var sprite: Sprite3D = _actors.get(proxy)
	if not is_instance_valid(sprite):
		sprite = Sprite3D.new()
		sprite.name = "Billboard_%d" % proxy.get_instance_id()
		sprite.centered = true
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.pixel_size = ACTOR_PIXEL_SIZE
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.region_enabled = true
		add_child(sprite)
		_actors[proxy] = sprite
	sprite.texture = texture
	sprite.region_rect = Rect2(
		float(frame % 4) * FRAME_SIZE.x,
		float(floori(float(frame) / 4.0)) * FRAME_SIZE.y,
		FRAME_SIZE.x,
		FRAME_SIZE.y
	)
	var floor_point := _screen_to_floor(screen_point)
	if not _is_valid_point(floor_point):
		return
	sprite.position = floor_point + Vector3.UP * (float(FRAME_SIZE.y) * ACTOR_PIXEL_SIZE * 0.5)


func remove_actor(proxy: Object) -> void:
	var sprite: Sprite3D = _actors.get(proxy)
	if is_instance_valid(sprite):
		sprite.queue_free()
	_actors.erase(proxy)


func find_path(start_screen: Vector2, end_screen: Vector2) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if not walk_region or not walk_region.navigation_mesh:
		return result
	var map := walk_region.get_navigation_map()
	if not map.is_valid():
		return result
	NavigationServer3D.map_force_update(map)
	var start := _screen_to_floor(start_screen)
	var finish := _screen_to_floor(end_screen)
	if not _is_valid_point(start) or not _is_valid_point(finish):
		return result
	start = NavigationServer3D.map_get_closest_point(map, start)
	finish = NavigationServer3D.map_get_closest_point(map, finish)
	var path := NavigationServer3D.map_get_path(map, start, finish, true)
	for point in path:
		result.append(_floor_to_screen(point))
	return result


func _screen_to_floor(screen_point: Vector2) -> Vector3:
	var vp := get_viewport() as SubViewport
	if not camera or not vp:
		return Vector3(INF, INF, INF)
	var viewport_point := screen_point * Vector2(vp.size) / _view_size
	var ray_origin := camera.project_ray_origin(viewport_point)
	var ray_direction := camera.project_ray_normal(viewport_point)
	if absf(ray_direction.y) < 0.00001:
		return Vector3(INF, INF, INF)
	var distance := (FLOOR_Y - ray_origin.y) / ray_direction.y
	if distance < 0.0 or not is_finite(distance):
		return Vector3(INF, INF, INF)
	return ray_origin + ray_direction * distance


func _floor_to_screen(floor_point: Vector3) -> Vector2:
	var vp := get_viewport() as SubViewport
	if not camera or not vp:
		return Vector2.ZERO
	var viewport_point := camera.unproject_position(floor_point)
	return viewport_point * _view_size / Vector2(vp.size)


func _is_valid_point(point: Vector3) -> bool:
	return is_finite(point.x) and is_finite(point.y) and is_finite(point.z)


func _rebuild_walkmesh() -> void:
	if not walk_region or not is_inside_tree():
		return
	var mesh := NavigationMesh.new()
	mesh.agent_radius = 0.0
	mesh.agent_height = 1.7
	var vertices := PackedVector3Array()
	var navigation_polygons: Array[PackedInt32Array] = []
	for normalized_polygon in _walkable_polygons:
		if normalized_polygon.size() < 3:
			continue
		var screen_polygon := PackedVector2Array()
		for point in normalized_polygon:
			screen_polygon.append(Vector2(point.x * _view_size.x, point.y * _view_size.y))
		var triangle_indices := Geometry2D.triangulate_polygon(screen_polygon)
		if triangle_indices.size() < 3:
			continue
		var base_index := vertices.size()
		for point in screen_polygon:
			var floor_point := _screen_to_floor(point)
			if not _is_valid_point(floor_point):
				floor_point = Vector3(point.x / _view_size.x * 12.0 - 6.0, FLOOR_Y, point.y / _view_size.y * 12.0)
			vertices.append(floor_point)
		for index in range(0, triangle_indices.size(), 3):
			# Screen Y maps to world +Z, so reverse winding to face +Y.
			navigation_polygons.append(PackedInt32Array([
				base_index + triangle_indices[index],
				base_index + triangle_indices[index + 2],
				base_index + triangle_indices[index + 1]
			]))
	mesh.vertices = vertices
	for polygon in navigation_polygons:
		mesh.add_polygon(polygon)
	walk_region.navigation_mesh = mesh
	var map := walk_region.get_navigation_map()
	if map.is_valid():
		NavigationServer3D.map_force_update(map)
