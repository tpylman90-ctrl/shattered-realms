class_name HeroEquipment
extends RefCounted

const DATA_PATH := "res://data/equipment.json"
const SAVE_PATH := "user://hero_equipment.cfg"
const SLOTS := ["head", "chest", "arms", "legs", "feet", "back", "right_hand", "left_hand", "relic_1", "relic_2"]

static var _catalog: Dictionary = {}

static func catalog() -> Dictionary:
    if _catalog.is_empty():
        var file := FileAccess.open(DATA_PATH, FileAccess.READ)
        if file:
            var parsed: Variant = JSON.parse_string(file.get_as_text())
            if parsed is Dictionary:
                _catalog = parsed
    return _catalog

static func items() -> Dictionary:
    return catalog().get("items", {})

static func loadout(hero_id: String) -> Dictionary:
    var cfg := ConfigFile.new()
    cfg.load(SAVE_PATH)
    var result: Dictionary = {}
    for slot in SLOTS:
        result[slot] = str(cfg.get_value("hero:%s" % hero_id, slot, ""))
    return result

static func owned(item_id: String, collectibles: Array[String]) -> bool:
    var item: Dictionary = items().get(item_id, {})
    return bool(item.get("starter", false)) or collectibles.has(item_id)

static func equip(hero_id: String, slot: String, item_id: String, collectibles: Array[String]) -> bool:
    if not SLOTS.has(slot):
        return false
    var item: Dictionary = items().get(item_id, {}) if item_id != "" else {}
    if item_id != "" and (item.is_empty() or str(item.get("slot", "")) != slot or not owned(item_id, collectibles)):
        return false
    var cfg := ConfigFile.new()
    cfg.load(SAVE_PATH)
    var section := "hero:%s" % hero_id
    cfg.set_value(section, slot, item_id)
    return cfg.save(SAVE_PATH) == OK

static func effective_stats(hero_id: String, base: Dictionary) -> Dictionary:
    var result := base.duplicate(true)
    var equipped := loadout(hero_id)
    var tags: Array[String] = []
    for slot in SLOTS:
        var item: Dictionary = items().get(str(equipped.get(slot, "")), {})
        if item.is_empty():
            continue
        for tag in item.get("tags", []):
            if not tags.has(str(tag)):
                tags.append(str(tag))
        for stat in item.get("stats", {}).keys():
            result[stat] = float(result.get(stat, 0)) + float(item["stats"][stat])
    # Synergies are keyed to shared archetype tags, never to a single hero ID.
    var hero_tags: Array = catalog().get("hero_tags", {}).get(hero_id, [])
    for slot in SLOTS:
        var item: Dictionary = items().get(str(equipped.get(slot, "")), {})
        for tag in item.get("synergy_tags", []):
            if hero_tags.has(tag):
                for stat in item.get("synergy_stats", {}).keys():
                    result[stat] = float(result.get(stat, 0)) + float(item["synergy_stats"][stat])
                break
    for stat in result.keys():
        if stat != "crit":
            result[stat] = int(round(float(result[stat])))
    return result
