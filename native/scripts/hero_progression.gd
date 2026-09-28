class_name HeroProgression
extends RefCounted

const DATA_PATH := "res://data/hero_progression.json"
const SAVE_PATH := "user://hero_progression.cfg"

static var _data_cache: Dictionary = {}


static func data() -> Dictionary:
    if not _data_cache.is_empty():
        return _data_cache

    if not FileAccess.file_exists(DATA_PATH):
        push_error("Hero progression data missing: %s" % DATA_PATH)
        return {}

    var file := FileAccess.open(DATA_PATH, FileAccess.READ)
    if not file:
        push_error("Unable to open hero progression data.")
        return {}

    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        _data_cache = (parsed as Dictionary).duplicate(true)
    return _data_cache


static func hero_definition(hero_id: String) -> Dictionary:
    var root := data()
    var heroes_variant: Variant = root.get("heroes", {})
    if heroes_variant is Dictionary and (heroes_variant as Dictionary).has(hero_id):
        return ((heroes_variant as Dictionary)[hero_id] as Dictionary).duplicate(true)
    return {}


static func xp_for_level(level: int) -> int:
    level = maxi(1, level)
    if level <= 1:
        return 0

    var rules: Dictionary = data().get("rules", {})
    var curve: Dictionary = rules.get("xp_curve", {})
    var base := float(curve.get("base", 70.0))
    var growth := float(curve.get("growth", 1.34))
    var total := 0.0

    for step in range(1, level):
        total += base * pow(growth, float(step - 1))
    return int(round(total))


static func level_from_xp(xp: int) -> int:
    var max_level := int(data().get("rules", {}).get("max_level", 30))
    var level := 1
    while level < max_level and xp >= xp_for_level(level + 1):
        level += 1
    return level


static func stats_for(hero_id: String, level: int) -> Dictionary:
    var definition := hero_definition(hero_id)
    var base: Dictionary = definition.get("base_stats", {})
    var growth: Dictionary = definition.get("growth", {})
    var result: Dictionary = {}

    for stat_variant in data().get("rules", {}).get("stats", []):
        var stat := str(stat_variant)
        var value := float(base.get(stat, 0.0)) + float(growth.get(stat, 0.0)) * float(maxi(0, level - 1))
        if stat == "crit":
            result[stat] = snappedf(value, 0.1)
        else:
            result[stat] = int(round(value))

    return result


static func skill_by_id(hero_id: String, skill_id: String) -> Dictionary:
    var definition := hero_definition(hero_id)
    for skill_variant in definition.get("skills", []):
        if skill_variant is Dictionary:
            var skill: Dictionary = skill_variant
            if str(skill.get("id", "")) == skill_id:
                return skill.duplicate(true)
    return {}


static func ensure_profile(hero_id: String, legacy_xp: int = 0) -> Dictionary:
    var definition := hero_definition(hero_id)
    if definition.is_empty():
        return {}

    var cfg := ConfigFile.new()
    cfg.load(SAVE_PATH)

    var section := "hero:%s" % hero_id
    var has_profile := cfg.has_section(section)
    var xp := int(cfg.get_value(section, "xp", legacy_xp if not has_profile else 0))
    xp = maxi(xp, legacy_xp)

    var current_level := level_from_xp(xp)
    var starting_skills: Array = definition.get("starting_skills", [])
    var starting_equipped: Array = definition.get("starting_equipped", [])

    var learned: Array[String] = []
    for id_variant in cfg.get_value(section, "learned_skills", starting_skills):
        var id := str(id_variant)
        if not learned.has(id):
            learned.append(id)
    for id_variant in starting_skills:
        var id := str(id_variant)
        if not learned.has(id):
            learned.append(id)

    var equipped: Array[String] = []
    for id_variant in cfg.get_value(section, "equipped_skills", starting_equipped):
        var id := str(id_variant)
        if learned.has(id) and not equipped.has(id):
            equipped.append(id)

    var points_earned := maxi(0, current_level - 1) * int(data().get("rules", {}).get("skill_points_per_level", 1))
    var spent_points := 0
    for skill_id in learned:
        var skill := skill_by_id(hero_id, skill_id)
        spent_points += int(skill.get("cost_sp", 0))
    var skill_points := maxi(0, points_earned - spent_points)

    cfg.set_value(section, "xp", xp)
    cfg.set_value(section, "level", current_level)
    cfg.set_value(section, "skill_points", skill_points)
    cfg.set_value(section, "learned_skills", learned)
    cfg.set_value(section, "equipped_skills", equipped)
    cfg.save(SAVE_PATH)

    return {
        "hero_id": hero_id,
        "xp": xp,
        "level": current_level,
        "skill_points": skill_points,
        "learned_skills": learned,
        "equipped_skills": equipped,
        "stats": stats_for(hero_id, current_level)
    }


static func add_xp(hero_id: String, amount: int, legacy_xp: int = 0) -> Dictionary:
    var before := ensure_profile(hero_id, legacy_xp)
    if before.is_empty():
        return {}

    var old_level := int(before.get("level", 1))
    var new_xp := int(before.get("xp", 0)) + maxi(0, amount)

    var cfg := ConfigFile.new()
    cfg.load(SAVE_PATH)
    var section := "hero:%s" % hero_id
    cfg.set_value(section, "xp", new_xp)
    cfg.save(SAVE_PATH)

    var after := ensure_profile(hero_id, new_xp)
    after["levels_gained"] = int(after.get("level", 1)) - old_level
    return after


static func can_learn(hero_id: String, skill_id: String) -> bool:
    var profile := ensure_profile(hero_id)
    var skill := skill_by_id(hero_id, skill_id)
    if profile.is_empty() or skill.is_empty():
        return false

    var learned: Array = profile.get("learned_skills", [])
    if learned.has(skill_id):
        return false
    if int(profile.get("level", 1)) < int(skill.get("level_req", 1)):
        return false
    if int(profile.get("skill_points", 0)) < int(skill.get("cost_sp", 0)):
        return false

    for required_variant in skill.get("requires", []):
        if not learned.has(str(required_variant)):
            return false
    return true


static func learn_skill(hero_id: String, skill_id: String) -> bool:
    if not can_learn(hero_id, skill_id):
        return false

    var profile := ensure_profile(hero_id)
    var learned: Array = profile.get("learned_skills", []).duplicate()
    learned.append(skill_id)

    var cfg := ConfigFile.new()
    cfg.load(SAVE_PATH)
    var section := "hero:%s" % hero_id
    cfg.set_value(section, "learned_skills", learned)
    cfg.save(SAVE_PATH)
    ensure_profile(hero_id)
    return true


static func set_equipped_skills(hero_id: String, skill_ids: Array[String]) -> void:
    var profile := ensure_profile(hero_id)
    if profile.is_empty():
        return

    var learned: Array = profile.get("learned_skills", [])
    var limit := int(data().get("rules", {}).get("equipped_active_limit", 6))
    var clean: Array[String] = []

    for skill_id in skill_ids:
        if clean.size() >= limit:
            break
        var skill := skill_by_id(hero_id, skill_id)
        if learned.has(skill_id) and str(skill.get("type", "active")) == "active" and not clean.has(skill_id):
            clean.append(skill_id)

    var cfg := ConfigFile.new()
    cfg.load(SAVE_PATH)
    cfg.set_value("hero:%s" % hero_id, "equipped_skills", clean)
    cfg.save(SAVE_PATH)
