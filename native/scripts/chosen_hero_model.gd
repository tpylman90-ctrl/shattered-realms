extends Node3D

var appearance: Dictionary = {}

func _ready() -> void:
    if appearance.is_empty():
        _load_saved_appearance()
    if get_child_count() == 0:
        _rebuild_figure()

func set_profile(profile: Dictionary) -> void:
    appearance = profile.duplicate(true)
    _rebuild_figure()

func _load_saved_appearance() -> void:
    var cfg := ConfigFile.new()
    if cfg.load("user://chosen_hero.cfg") != OK:
        return
    for key in cfg.get_section_keys("chosen_hero"):
        appearance[key] = cfg.get_value("chosen_hero", key)

func _rebuild_figure() -> void:
    for child in get_children():
        remove_child(child)
        child.queue_free()

    var class_id := str(appearance.get("starting_class_id", "warrior"))
    var female := str(appearance.get("gender", "Male")) == "Female"
    var skin_color := _skin_color(str(appearance.get("skin_tone", "Olive")))
    var hair_color := _hair_color(str(appearance.get("hair_color", "Brown")))
    var outfit_color := _class_color(class_id)
    var dark_outfit := outfit_color.darkened(0.42)
    var skin := _material(skin_color)
    var hair := _material(hair_color)
    var cloth := _material(outfit_color)
    var trim := _material(outfit_color.lightened(0.32), 0.35)
    var leather := _material(dark_outfit, 0.15)
    var metal := _material(Color("b9a77e"), 0.78)

    var torso := _capsule("Torso", 0.30 if not female else 0.27, 1.08 if not female else 1.0, Vector3(0, 1.32, 0), cloth)
    torso.scale.x = 1.0 if not female else 0.88
    _capsule("Neck", 0.09, 0.20, Vector3(0, 1.90, 0), skin)
    var head := _sphere("Head", Vector3(0.21 if not female else 0.205, 0.25, 0.19), Vector3(0, 2.12, 0), skin)
    var face_detail := _material(Color("33231e"))
    _sphere("Left Eye", Vector3(0.026, 0.026, 0.014), Vector3(-0.072, 2.15, -0.184), face_detail)
    _sphere("Right Eye", Vector3(0.026, 0.026, 0.014), Vector3(0.072, 2.15, -0.184), face_detail)
    _capsule("Left Brow", 0.018, 0.095, Vector3(-0.072, 2.205, -0.18), face_detail).rotation.z = 0.10
    _capsule("Right Brow", 0.018, 0.095, Vector3(0.072, 2.205, -0.18), face_detail).rotation.z = -0.10
    _sphere("Nose", Vector3(0.035, 0.055, 0.04), Vector3(0, 2.09, -0.195), skin)
    _box("Mouth", Vector3(0.075, 0.018, 0.018), Vector3(0, 2.015, -0.19), face_detail)
    _ellipsoid("Left Ear", Vector3(0.075, 0.13, 0.07), Vector3(-0.21, 2.12, 0), skin)
    _ellipsoid("Right Ear", Vector3(0.075, 0.13, 0.07), Vector3(0.21, 2.12, 0), skin)

    _capsule("Left Arm", 0.105, 0.76, Vector3(-0.39, 1.34, 0), skin).rotation.z = -0.12
    _capsule("Right Arm", 0.105, 0.76, Vector3(0.39, 1.34, 0), skin).rotation.z = 0.12
    _ellipsoid("Tailored Tunic", Vector3(0.58 if not female else 0.53, 0.88, 0.42), Vector3(0, 1.33, 0), cloth)
    _capsule("Left Sleeve", 0.14, 0.62, Vector3(-0.36, 1.42, 0), cloth)
    _capsule("Right Sleeve", 0.14, 0.62, Vector3(0.36, 1.42, 0), cloth)
    _capsule("Left Bracer", 0.115, 0.38, Vector3(-0.43, 1.02, -0.015), leather)
    _capsule("Right Bracer", 0.115, 0.38, Vector3(0.43, 1.02, -0.015), leather)
    _ellipsoid("Left Glove", Vector3(0.17, 0.19, 0.16), Vector3(-0.44, 0.76, -0.025), leather)
    _ellipsoid("Right Glove", Vector3(0.17, 0.19, 0.16), Vector3(0.44, 0.76, -0.025), leather)
    _capsule("Left Leg", 0.135 if not female else 0.125, 0.88, Vector3(-0.16, 0.50, 0), leather)
    _capsule("Right Leg", 0.135 if not female else 0.125, 0.88, Vector3(0.16, 0.50, 0), leather)
    _ellipsoid("Left Knee Guard", Vector3(0.21, 0.17, 0.13), Vector3(-0.16, 0.72, -0.09), metal)
    _ellipsoid("Right Knee Guard", Vector3(0.21, 0.17, 0.13), Vector3(0.16, 0.72, -0.09), metal)
    _ellipsoid("Left Boot", Vector3(0.30, 0.19, 0.43), Vector3(-0.16, 0.09, -0.06), metal)
    _ellipsoid("Right Boot", Vector3(0.30, 0.19, 0.43), Vector3(0.16, 0.09, -0.06), metal)
    _box("Left Hip Flap", Vector3(0.24, 0.32, 0.10), Vector3(-0.20, 0.80, -0.18), cloth)
    _box("Right Hip Flap", Vector3(0.24, 0.32, 0.10), Vector3(0.20, 0.80, -0.18), cloth)
    _box("Belt", Vector3(0.61, 0.12, 0.35), Vector3(0, 0.98, 0), leather)
    _box("Buckle", Vector3(0.12, 0.14, 0.05), Vector3(0, 0.98, -0.20), trim)
    _box("Left Belt Pouch", Vector3(0.18, 0.18, 0.13), Vector3(-0.32, 0.96, -0.12), leather)
    _box("Right Belt Pouch", Vector3(0.18, 0.18, 0.13), Vector3(0.32, 0.96, -0.12), leather)
    _rod("Chest Strap", Vector3(-0.24, 1.76, -0.18), Vector3(0.22, 1.08, -0.23), 0.035, leather)
    _rod("Shoulder Seam", Vector3(-0.29, 1.69, -0.12), Vector3(0.29, 1.69, -0.12), 0.022, trim)
    var armor := _material(outfit_color.darkened(0.18), 0.36)
    if class_id != "black_mage" and class_id != "white_mage":
        _ellipsoid("Fitted Chest Armor", Vector3(0.52 if not female else 0.46, 0.62, 0.15), Vector3(0, 1.43, -0.235), armor)
        _ellipsoid("Raised Breastplate", Vector3(0.33, 0.38, 0.045), Vector3(0, 1.49, -0.328), metal)
        _ellipsoid("Breastplate Crest", Vector3(0.09, 0.17, 0.035), Vector3(0, 1.50, -0.362), trim)

    var hair_style := str(appearance.get("hair_style", "Short"))
    var hair_cap := _sphere("Hair", Vector3(0.225, 0.15, 0.205), Vector3(0, 2.30, 0), hair)
    if hair_style == "Long":
        _capsule("Left Hair Lock", 0.055, 0.52, Vector3(-0.17, 2.08, -0.01), hair)
        _capsule("Right Hair Lock", 0.055, 0.52, Vector3(0.17, 2.08, -0.01), hair)
    elif hair_style == "Braided":
        _capsule("Braided Hair", 0.065, 0.62, Vector3(-0.18, 2.04, 0.08), hair)
        for braid_index in range(4):
            _ellipsoid("Braid Tie %d" % braid_index, Vector3(0.075, 0.045, 0.075), Vector3(-0.18, 2.25 - 0.12 * braid_index, 0.08), trim)
    if hair_style == "Cropped":
        hair_cap.scale = Vector3(1.0, 0.68, 1.0)
    if class_id == "thief":
        _hood(hair_color)
        _ellipsoid("Thief Face Wrap", Vector3(0.31, 0.12, 0.06), Vector3(0, 2.00, -0.18), leather)
        _add_dagger(Vector3(0.56, 1.00, -0.12), metal, leather)
        _add_dagger(Vector3(-0.56, 1.00, -0.12), metal, leather)
    elif class_id == "ranger":
        _cape(dark_outfit)
        _add_quiver(leather, metal)
        _add_bow(leather, trim)
    elif class_id == "warrior":
        _shoulder_pads(metal)
        _ellipsoid("Warrior Shoulder Left", Vector3(0.37, 0.23, 0.32), Vector3(-0.37, 1.69, -0.01), armor)
        _ellipsoid("Warrior Shoulder Right", Vector3(0.37, 0.23, 0.32), Vector3(0.37, 1.69, -0.01), armor)
        _add_sword(metal, trim, leather)
        _add_shield(armor, trim)
    elif class_id == "black_mage":
        _robe_trim(trim)
        _high_collar(cloth, trim)
        _cape(dark_outfit)
        _add_staff(trim, Color("8c72d6"))
    elif class_id == "white_mage":
        _robe_trim(trim)
        _high_collar(cloth, trim)
        _cape(dark_outfit.lightened(0.12))
        _add_staff(trim, Color("e9d5a0"))

func _material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = metallic
    material.roughness = 0.72
    return material

func _capsule(node_name: String, radius: float, height: float, point: Vector3, material: Material) -> MeshInstance3D:
    var mesh := CapsuleMesh.new()
    mesh.radius = radius
    mesh.height = height
    mesh.radial_segments = 24
    mesh.rings = 12
    return _mesh(node_name, mesh, point, material)

func _sphere(node_name: String, dimensions: Vector3, point: Vector3, material: Material) -> MeshInstance3D:
    var mesh := SphereMesh.new()
    mesh.radius = 0.5
    mesh.height = 1.0
    mesh.radial_segments = 32
    mesh.rings = 20
    var instance := _mesh(node_name, mesh, point, material)
    instance.scale = dimensions * 2.0
    return instance

func _box(node_name: String, dimensions: Vector3, point: Vector3, material: Material) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = dimensions
    return _mesh(node_name, mesh, point, material)

func _mesh(node_name: String, mesh: Mesh, point: Vector3, material: Material) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = node_name
    instance.mesh = mesh
    instance.material_override = material
    instance.position = point
    add_child(instance)
    return instance

func _ellipsoid(node_name: String, dimensions: Vector3, point: Vector3, material: Material) -> MeshInstance3D:
    var mesh := SphereMesh.new()
    mesh.radius = 0.5
    mesh.height = 1.0
    mesh.radial_segments = 24
    mesh.rings = 16
    var instance := _mesh(node_name, mesh, point, material)
    instance.scale = dimensions
    return instance

func _rod(node_name: String, start_point: Vector3, end_point: Vector3, radius: float, material: Material) -> MeshInstance3D:
    var direction := end_point - start_point
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius * 0.82
    mesh.bottom_radius = radius
    mesh.height = maxf(0.01, direction.length())
    mesh.radial_segments = 12
    var instance := _mesh(node_name, mesh, (start_point + end_point) * 0.5, material)
    if direction.length_squared() > 0.0001:
        instance.quaternion = Quaternion(Vector3.UP, direction.normalized())
    return instance

func _add_sword(metal: Material, trim: Material, leather: Material) -> void:
    _box("Sword Blade", Vector3(0.095, 0.70, 0.045), Vector3(0.57, 1.35, -0.14), metal)
    _box("Sword Fuller", Vector3(0.018, 0.54, 0.012), Vector3(0.57, 1.36, -0.168), trim)
    _box("Sword Guard", Vector3(0.33, 0.065, 0.09), Vector3(0.57, 0.98, -0.14), trim)
    _capsule("Sword Grip", 0.035, 0.24, Vector3(0.57, 0.82, -0.14), leather)
    _ellipsoid("Pommel", Vector3(0.10, 0.10, 0.10), Vector3(0.57, 0.68, -0.14), trim)

func _add_shield(armor: Material, trim: Material) -> void:
    _ellipsoid("Warrior Shield", Vector3(0.48, 0.58, 0.12), Vector3(-0.60, 1.17, -0.12), armor)
    _ellipsoid("Shield Boss", Vector3(0.15, 0.15, 0.07), Vector3(-0.60, 1.18, -0.205), trim)
    _rod("Shield Rim Left", Vector3(-0.81, 1.42, -0.19), Vector3(-0.81, 0.92, -0.19), 0.018, trim)
    _rod("Shield Rim Right", Vector3(-0.39, 1.42, -0.19), Vector3(-0.39, 0.92, -0.19), 0.018, trim)

func _add_dagger(point: Vector3, metal: Material, leather: Material) -> void:
    _box("Dagger Blade", Vector3(0.055, 0.31, 0.035), point + Vector3(0, 0.17, 0), metal)
    _box("Dagger Guard", Vector3(0.17, 0.045, 0.06), point, metal)
    _capsule("Dagger Grip", 0.028, 0.18, point + Vector3(0, -0.12, 0), leather)

func _add_quiver(leather: Material, metal: Material) -> void:
    _capsule("Ranger Quiver", 0.105, 0.62, Vector3(-0.28, 1.32, 0.24), leather)
    for arrow_index in range(3):
        var arrow_x := -0.35 + 0.07 * arrow_index
        _rod("Arrow Shaft %d" % arrow_index, Vector3(arrow_x, 1.50, 0.20), Vector3(arrow_x + 0.12, 1.92, 0.20), 0.012, metal)

func _add_bow(leather: Material, trim: Material) -> void:
    var bow_points := [
        Vector3(0.62, 0.72, -0.12),
        Vector3(0.79, 1.02, -0.12),
        Vector3(0.84, 1.35, -0.12),
        Vector3(0.78, 1.68, -0.12),
        Vector3(0.62, 1.96, -0.12)
    ]
    for point_index in range(bow_points.size() - 1):
        _rod("Longbow Limb %d" % point_index, bow_points[point_index], bow_points[point_index + 1], 0.026, leather)
    _rod("Bowstring", bow_points[0], bow_points[4], 0.007, trim)
    _ellipsoid("Bow Grip", Vector3(0.07, 0.15, 0.07), Vector3(0.84, 1.35, -0.12), trim)

func _add_staff(trim: Material, gem_color: Color) -> void:
    var staff_wood := _material(Color("463629"), 0.12)
    _rod("Mage Staff", Vector3(0.60, 0.13, -0.06), Vector3(0.60, 2.12, -0.06), 0.045, staff_wood)
    _ellipsoid("Staff Crown", Vector3(0.22, 0.25, 0.18), Vector3(0.60, 2.08, -0.06), trim)
    var gem := _material(gem_color, 0.15)
    _ellipsoid("Focus Crystal", Vector3(0.13, 0.16, 0.12), Vector3(0.60, 2.10, -0.17), gem)

func _high_collar(cloth: Material, trim: Material) -> void:
    _ellipsoid("High Collar", Vector3(0.50, 0.34, 0.30), Vector3(0, 1.82, 0.02), cloth)
    _box("Collar Edge", Vector3(0.43, 0.045, 0.035), Vector3(0, 1.67, -0.15), trim)

func _triangle_sheet(node_name: String, vertices: PackedVector3Array, material: Material) -> MeshInstance3D:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for vertex in vertices:
        surface.add_vertex(vertex)
    surface.generate_normals()
    var mesh := surface.commit()
    var instance := _mesh(node_name, mesh, Vector3.ZERO, material)
    return instance

func _cape(color: Color) -> void:
    var cloth := _material(color)
    var vertices := PackedVector3Array([
        Vector3(-0.20, 1.74, 0.16), Vector3(0.20, 1.74, 0.16), Vector3(-0.32, 1.08, 0.22),
        Vector3(0.20, 1.74, 0.16), Vector3(0.32, 1.08, 0.22), Vector3(-0.32, 1.08, 0.22),
        Vector3(-0.32, 1.08, 0.22), Vector3(0.32, 1.08, 0.22), Vector3(-0.48, 0.32, 0.28),
        Vector3(0.32, 1.08, 0.22), Vector3(0.48, 0.32, 0.28), Vector3(-0.48, 0.32, 0.28)
    ])
    _triangle_sheet("Tailored Cloak", vertices, cloth)
    _rod("Cloak Clasp", Vector3(-0.14, 1.70, 0.12), Vector3(0.14, 1.70, 0.12), 0.035, _material(Color("d4b56e"), 0.55))

func _hood(color: Color) -> void:
    _sphere("Thief Hood", Vector3(0.29, 0.29, 0.26), Vector3(0, 2.12, 0.06), _material(color.darkened(0.18)))

func _shoulder_pads(material: Material) -> void:
    _sphere("Left Pauldron", Vector3(0.20, 0.14, 0.17), Vector3(-0.37, 1.68, 0), material)
    _sphere("Right Pauldron", Vector3(0.20, 0.14, 0.17), Vector3(0.37, 1.68, 0), material)

func _robe_trim(material: Material) -> void:
    _box("Robe Trim", Vector3(0.08, 1.05, 0.04), Vector3(0, 1.28, -0.20), material)

func _skin_color(tone: String) -> Color:
    match tone:
        "Light":
            return Color("f0c7a0")
        "Brown":
            return Color("9c674b")
        "Deep":
            return Color("614130")
        _:
            return Color("c58f6a")

func _hair_color(color_name: String) -> Color:
    match color_name:
        "Black":
            return Color("201b19")
        "Auburn":
            return Color("87472f")
        "Silver":
            return Color("bfc5c8")
        _:
            return Color("59402d")

func _class_color(class_id: String) -> Color:
    match class_id:
        "ranger":
            return Color("536a42")
        "black_mage":
            return Color("554178")
        "white_mage":
            return Color("9b8d62")
        "thief":
            return Color("64513e")
        _:
            return Color("80573a")
