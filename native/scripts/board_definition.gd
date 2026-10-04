extends RefCounted
class_name BoardDefinition

const FORMAT := "shattered_realms_board"
const VERSION := 1
const BOARD_DIR := "user://boards/"

static func load_board(board_id: String, fallback_nav_path: String) -> Dictionary:
    var user_path := BOARD_DIR + board_id + ".board.json"
    var source_path := "res://data/boards/" + board_id + ".board.json"
    for path in [user_path, source_path]:
        if FileAccess.file_exists(path):
            var file := FileAccess.open(path, FileAccess.READ)
            if file:
                var parsed: Variant = JSON.parse_string(file.get_as_text())
                if parsed is Dictionary and validate(parsed):
                    return parsed
    return _from_navigation(fallback_nav_path, board_id)

static func _from_navigation(path: String, board_id: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        return {}
    var cells: Dictionary = {}
    var raw_cells: Variant = parsed.get("tiles", {})
    if not (raw_cells is Dictionary):
        return {}
    for raw_key in raw_cells.keys():
        var key := str(raw_key)
        var parts := key.split(",")
        if parts.size() != 2:
            continue
        var source: Variant = raw_cells[raw_key]
        if not (source is Dictionary):
            continue
        var bridge := bool(source.get("inferred_bridge", false))
        var cliff := bool(source.get("auto_blocked", false))
        cells[key] = {
            "q": int(parts[0]), "r": int(parts[1]),
            "x": float(source.get("x", 0.0)), "y": float(source.get("y", 0.0)), "z": float(source.get("z", 0.0)),
            "terrain": "bridge" if bridge else ("cliff" if cliff else "natural"),
            "movement_cost": 99 if cliff else 1, "blocked": cliff,
            "blocked_edges": source.get("blocked_edges", []).duplicate(),
            "inferred_bridge": bridge, "auto_blocked": cliff,
            "poi_id": "", "poi_name": ""
        }
    var definition := {
        "format": FORMAT, "version": VERSION, "id": board_id,
        "title": board_id.capitalize(), "theme": "temperate forest",
        "grid": {"type": "hex", "orientation": "flat", "radius": 0.42},
        "cells": cells, "landmarks": []
    }
    return definition

static func validate(definition: Dictionary) -> bool:
    if str(definition.get("format", "")) != FORMAT or int(definition.get("version", -1)) != VERSION:
        return false
    var cells: Variant = definition.get("cells", null)
    return cells is Dictionary and not cells.is_empty()

static func save_board(definition: Dictionary) -> bool:
    if not validate(definition):
        return false
    var absolute_dir := ProjectSettings.globalize_path(BOARD_DIR)
    var err := DirAccess.make_dir_recursive_absolute(absolute_dir)
    if err != OK and err != ERR_ALREADY_EXISTS:
        return false
    var file := FileAccess.open(BOARD_DIR + str(definition.get("id", "board")) + ".board.json", FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(definition, "\t") + "\n")
    return file.get_error() == OK
