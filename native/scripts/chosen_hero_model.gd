extends Node3D

var appearance: Dictionary = {}

func _ready() -> void:
    if appearance.is_empty():
        _load_saved_appearance()
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
    _sphere("Nose", Vector3(0.035, 0.055, 0.04), Vector3(0, 2.09, -0.195), skin)

    _capsule("Left Arm", 0.105, 0.76, Vector3(-0.39, 1.34, 0), skin).rotation.z = -0.12
    _capsule("Right Arm", 0.105, 0.76, Vector3(0.39, 1.34, 0), skin).rotation.z = 0.12
    _capsule("Left Leg", 0.135 if not female else 0.125, 0.88, Vector3(-0.16, 0.50, 0), leather)
    _capsule("Right Leg", 0.135 if not female else 0.125, 0.88, Vector3(0.16, 0.50, 0), leather)
    _box("Left Boot", Vector3(0.30, 0.16, 0.42), Vector3(-0.16, 0.08, 0.08), metal)
    _box("Right Boot", Vector3(0.30, 0.16, 0.42), Vector3(0.16, 0.08, 0.08), metal)
    _box("Belt", Vector3(0.59, 0.10, 0.36), Vector3(0, 0.98, 0), leather)
    _box("Buckle", Vector3(0.11, 0.12, 0.05), Vector3(0, 0.98, -0.20), trim)

    var hair_style := str(appearance.get("hair_style", "Short"))
    var hair_cap := _sphere("Hair", Vector3(0.225, 0.15, 0.205), Vector3(0, 2.30, 0), hair)
    if hair_style == "Long" or hair_style == "Braided":
        _box("Long Hair", Vector3(0.12, 0.38, 0.12), Vector3(0, 2.12, 0.16), hair)
    if hair_style == "Cropped":
        hair_cap.scale = Vector3(1.0, 0.68, 1.0)
    if class_id == "thief":
        _hood(hair_color)
    elif class_id == "ranger":
        _cape(dark_outfit)
    elif class_id == "warrior":
        _shoulder_pads(metal)
    elif class_id == "black_mage" or class_id == "white_mage":
        _robe_trim(trim)

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
    return _mesh(node_name, mesh, point, material)

func _sphere(node_name: String, dimensions: Vector3, point: Vector3, material: Material) -> MeshInstance3D:
    var mesh := SphereMesh.new()
    mesh.radius = 0.5
    mesh.height = 1.0
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

func _cape(color: Color) -> void:
    _box("Ranger Cloak", Vector3(0.48, 0.92, 0.11), Vector3(0, 1.30, 0.26), _material(color))

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
