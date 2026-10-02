class_name HeroProgression
extends RefCounted

const DATA_PATH := "res://data/hero_progression.json"
const SAVE_PATH := "user://hero_progression.cfg"
const CHOSEN_PROFILE_PATH := "user://chosen_hero.cfg"
const WORLD_CAMPAIGN_PATH := "user://world_campaign.cfg"
const CHOSEN_HERO_ID := "chosen_hero"

const STARTER_CLASSES := {
    "warrior": {
        "name": "Warrior", "color": "#ae7952",
        "base_stats": {"hp": 126, "mp": 36, "power": 17, "magic": 8, "defense": 14, "resistance": 9, "speed": 9, "crit": 4.0},
        "growth": {"hp": 13, "mp": 3, "power": 2.3, "magic": 0.8, "defense": 1.8, "resistance": 1.0, "speed": 0.5, "crit": 0.1},
        "description": "Direct weapon skill and durable defense."
    },
    "ranger": {
        "name": "Ranger", "color": "#668b56",
        "base_stats": {"hp": 104, "mp": 42, "power": 14, "magic": 10, "defense": 9, "resistance": 10, "speed": 15, "crit": 8.0},
        "growth": {"hp": 10, "mp": 4, "power": 1.7, "magic": 1.0, "defense": 0.9, "resistance": 1.0, "speed": 1.1, "crit": 0.22},
        "description": "Precise ranged attacks and battlefield control."
    },
    "black_mage": {
        "name": "Black Mage", "color": "#7659a7",
        "base_stats": {"hp": 86, "mp": 62, "power": 7, "magic": 19, "defense": 7, "resistance": 15, "speed": 10, "crit": 4.0},
        "growth": {"hp": 8, "mp": 7, "power": 0.7, "magic": 2.5, "defense": 0.7, "resistance": 1.6, "speed": 0.7, "crit": 0.12},
        "description": "High-impact magic, hexes, and disruption."
    },
    "white_mage": {
        "name": "White Mage", "color": "#d4c58e",
        "base_stats": {"hp": 102, "mp": 64, "power": 8, "magic": 17, "defense": 10, "resistance": 16, "speed": 10, "crit": 5.0},
        "growth": {"hp": 10, "mp": 7, "power": 0.8, "magic": 2.1, "defense": 1.0, "resistance": 1.8, "speed": 0.7, "crit": 0.14},
        "description": "Healing, recovery, and protective magic."
    },
    "thief": {
        "name": "Thief", "color": "#877256",
        "base_stats": {"hp": 96, "mp": 40, "power": 14, "magic": 9, "defense": 8, "resistance": 9, "speed": 17, "crit": 10.0},
        "growth": {"hp": 9, "mp": 4, "power": 1.6, "magic": 0.8, "defense": 0.8, "resistance": 0.9, "speed": 1.3, "crit": 0.28},
        "description": "Fast strikes, evasion, and dirty tricks."
    }
}

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
    if hero_id == CHOSEN_HERO_ID:
        return _chosen_hero_definition()
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


static func chosen_hero_exists() -> bool:
    var cfg := ConfigFile.new()
    return cfg.load(CHOSEN_PROFILE_PATH) == OK and str(cfg.get_value("chosen_hero", "name", "")).strip_edges() != ""

static func chosen_hero_class_id() -> String:
    var cfg := ConfigFile.new()
    if cfg.load(CHOSEN_PROFILE_PATH) != OK:
        return "warrior"
    var class_id := str(cfg.get_value("chosen_hero", "starting_class_id", "warrior"))
    return class_id if STARTER_CLASSES.has(class_id) else "warrior"

static func chosen_hero_name() -> String:
    var cfg := ConfigFile.new()
    if cfg.load(CHOSEN_PROFILE_PATH) != OK:
        return "Chosen Hero"
    var name := str(cfg.get_value("chosen_hero", "name", "Chosen Hero")).strip_edges()
    return name if name != "" else "Chosen Hero"

static func chosen_hero_paths() -> Array[String]:
    var cfg := ConfigFile.new()
    var result: Array[String] = []
    if cfg.load(CHOSEN_PROFILE_PATH) == OK:
        var stored: Variant = cfg.get_value("chosen_hero", "unlocked_skill_paths", [])
        if stored is Array:
            for raw_path in stored:
                var path_id := str(raw_path)
                if not result.has(path_id):
                    result.append(path_id)
    var starter := chosen_hero_class_id()
    if not result.has(starter):
        result.append(starter)
    return result

static func chosen_hero_can_access_path(path_id: String) -> bool:
    return chosen_hero_paths().has(path_id)

static func unlock_chosen_hero_champion_path(hero_id: String, land_reconnected: bool, chest_piece_owned: bool) -> bool:
    if not land_reconnected or not chest_piece_owned or not data().get("heroes", {}).has(hero_id):
        return false
    var path_id := "champion_" + hero_id
    var paths := chosen_hero_paths()
    if paths.has(path_id):
        return false
    paths.append(path_id)
    var cfg := ConfigFile.new()
    if cfg.load(CHOSEN_PROFILE_PATH) != OK:
        return false
    cfg.set_value("chosen_hero", "unlocked_skill_paths", paths)
    return cfg.save(CHOSEN_PROFILE_PATH) == OK

static func mark_territory_reconnected(territory_id: String) -> void:
    if territory_id.strip_edges() == "":
        return
    var cfg := ConfigFile.new()
    cfg.load(WORLD_CAMPAIGN_PATH)
    cfg.set_value("territories", territory_id, true)
    cfg.save(WORLD_CAMPAIGN_PATH)

static func territory_is_reconnected(territory_id: String) -> bool:
    if territory_id.strip_edges() == "":
        return false
    var cfg := ConfigFile.new()
    if cfg.load(WORLD_CAMPAIGN_PATH) == OK:
        return bool(cfg.get_value("territories", territory_id, false))
    return false

static func _chosen_hero_definition() -> Dictionary:
    var root := data()
    var class_id := chosen_hero_class_id()
    var starter: Dictionary = STARTER_CLASSES.get(class_id, STARTER_CLASSES["warrior"])
    var tree_id := class_id
    var skills: Array = _starter_class_skills(class_id)
    var trees: Array = [{"id": tree_id, "name": str(starter.get("name", "Warrior")), "theme": str(starter.get("description", ""))}]
    var hero_definitions: Dictionary = root.get("heroes", {})
    for hero_id_variant in hero_definitions.keys():
        var hero_id := str(hero_id_variant)
        var source: Dictionary = hero_definitions[hero_id]
        var path_id := "champion_" + hero_id
        trees.append({
            "id": path_id,
            "name": str(source.get("name", hero_id)),
            "theme": "Champion specialty • unlock by restoring their land and recovering their chest piece."
        })
        for raw_skill in source.get("skills", []):
            if not raw_skill is Dictionary:
                continue
            var skill: Dictionary = (raw_skill as Dictionary).duplicate(true)
            var old_id := str(skill.get("id", ""))
            skill["id"] = path_id + "::" + old_id
            skill["tree"] = path_id
            var mapped_requires: Array[String] = []
            for required in skill.get("requires", []):
                mapped_requires.append(path_id + "::" + str(required))
            skill["requires"] = mapped_requires
            skills.append(skill)

    var starter_skill := class_id + "::" + class_id + "_basic"
    return {
        "id": CHOSEN_HERO_ID,
        "name": chosen_hero_name(),
        "base_stats": starter.get("base_stats", {}),
        "growth": starter.get("growth", {}),
        "trees": trees,
        "skills": skills,
        "starting_skills": [starter_skill],
        "starting_equipped": [starter_skill]
    }

static func _starter_class_skills(class_id: String) -> Array:
    var tree := class_id
    var class_skills: Array = []
    match class_id:
        "warrior":
            class_skills = [
                _starter_skill(tree, "warrior_basic", "Heavy Swing", "A forceful strike against one foe.", "active", 1, 1, 4, 25, "power", "heavy_hit"),
                _starter_skill(tree, "warrior_guard", "Guard Stance", "Gain a lasting defense bonus.", "passive", 2, 2, 0, 0, "none", "", {"defense": 3}, ["warrior_basic"]),
                _starter_skill(tree, "warrior_sunder", "Sundering Blow", "Strike hard and weaken the target.", "active", 4, 3, 7, 21, "power", "sunder", {}, ["warrior_guard"])
            ]
        "ranger":
            class_skills = [
                _starter_skill(tree, "ranger_basic", "Quick Shot", "A fast, accurate ranged attack.", "active", 1, 1, 4, 20, "power", "heavy_hit"),
                _starter_skill(tree, "ranger_keen_eye", "Keen Eye", "Improve critical hit chance.", "passive", 2, 2, 0, 0, "none", "", {"crit": 1.0}, ["ranger_basic"]),
                _starter_skill(tree, "ranger_snare", "Crippling Shot", "Damage and slow one enemy.", "active", 4, 3, 7, 17, "power", "slow", {}, ["ranger_keen_eye"])
            ]
        "black_mage":
            class_skills = [
                _starter_skill(tree, "black_mage_basic", "Arcane Bolt", "A focused blast of destructive magic.", "active", 1, 1, 5, 28, "magic", "heavy_hit"),
                _starter_skill(tree, "black_mage_mana", "Mana Reserve", "Increase maximum MP and magic.", "passive", 2, 2, 0, 0, "none", "", {"mp": 6, "magic": 2}, ["black_mage_basic"]),
                _starter_skill(tree, "black_mage_hex", "Withering Hex", "Damage and weaken one enemy.", "active", 4, 3, 8, 20, "magic", "weaken", {}, ["black_mage_mana"])
            ]
        "white_mage":
            class_skills = [
                _starter_skill(tree, "white_mage_basic", "Mend", "Restore a large portion of the hero's health.", "active", 1, 1, 6, 0, "none", "heal"),
                _starter_skill(tree, "white_mage_ward", "Warding Light", "Increase resistance and maximum health.", "passive", 2, 2, 0, 0, "none", "", {"resistance": 2, "hp": 5}, ["white_mage_basic"]),
                _starter_skill(tree, "white_mage_sanctuary", "Sanctuary", "Regenerate health over several turns.", "active", 4, 3, 8, 0, "none", "regen", {}, ["white_mage_ward"])
            ]
        "thief":
            class_skills = [
                _starter_skill(tree, "thief_basic", "Quick Cut", "A swift strike that leaves a bleeding wound.", "active", 1, 1, 4, 18, "power", "bleed"),
                _starter_skill(tree, "thief_fleet", "Fleet Foot", "Increase movement speed and evasion.", "passive", 2, 2, 0, 0, "none", "", {"speed": 2, "crit": 0.5}, ["thief_basic"]),
                _starter_skill(tree, "thief_smoke", "Smoke Veil", "Evade incoming attacks for several turns.", "active", 4, 3, 7, 0, "none", "evade", {}, ["thief_fleet"])
            ]
    return class_skills

static func _starter_skill(tree_id: String, skill_id: String, skill_name: String, text: String, skill_type: String, required_level: int, tier: int, mp_cost: int, base_power: int, scaling: String, effect: String, bonuses: Dictionary = {}, requirements: Array = []) -> Dictionary:
    var skill := {
        "id": tree_id + "::" + skill_id,
        "name": skill_name,
        "description": text,
        "tree": tree_id,
        "type": skill_type,
        "level_req": required_level,
        "tier": tier,
        "tier_spend_required": 0 if tier == 1 else 1 if tier == 2 else 2,
        "point_cost_per_rank": 1,
        "max_rank": 3,
        "requires": [],
        "mp": mp_cost,
        "power": base_power,
        "power_per_rank": 4 if skill_type == "active" else 0,
        "scaling": scaling,
        "element": "physical",
        "target": "enemy" if effect != "heal" and effect != "regen" and effect != "evade" and not effect.begins_with("guard_") else "self",
        "effect": effect,
        "combat_effect": effect
    }
    if not requirements.is_empty():
        var mapped: Array[String] = []
        for required in requirements:
            mapped.append(tree_id + "::" + str(required))
        skill["requires"] = mapped
    if not bonuses.is_empty():
        skill["stat_bonus"] = bonuses.duplicate(true)
    return skill

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

    # Migrate older saves: every previously learned node starts at rank one.
    var ranks: Dictionary = {}
    var saved_ranks: Variant = cfg.get_value(section, "skill_ranks", {})
    if saved_ranks is Dictionary and not (saved_ranks as Dictionary).is_empty():
        for raw_id in (saved_ranks as Dictionary).keys():
            var id := str(raw_id)
            var skill := skill_by_id(hero_id, id)
            if not skill.is_empty():
                ranks[id] = clampi(int(saved_ranks[raw_id]), 0, int(skill.get("max_rank", 1)))
    else:
        for raw_id in cfg.get_value(section, "learned_skills", starting_skills):
            var id := str(raw_id)
            if not skill_by_id(hero_id, id).is_empty():
                ranks[id] = 1
    for raw_id in starting_skills:
        ranks[str(raw_id)] = maxi(1, int(ranks.get(str(raw_id), 0)))

    var learned: Array[String] = []
    for id in ranks.keys():
        if int(ranks[id]) > 0:
            learned.append(str(id))

    var equipped: Array[String] = []
    for id_variant in cfg.get_value(section, "equipped_skills", starting_equipped):
        var id := str(id_variant)
        if learned.has(id) and not equipped.has(id):
            equipped.append(id)

    var points_earned := maxi(0, current_level - 1) * int(data().get("rules", {}).get("skill_points_per_level", 1))
    var spent_points := 0
    for skill_id in learned:
        var paid_ranks := int(ranks.get(skill_id, 0)) - (1 if starting_skills.has(skill_id) else 0)
        spent_points += maxi(0, paid_ranks)
    var skill_points := maxi(0, points_earned - spent_points)

    cfg.set_value(section, "xp", xp)
    cfg.set_value(section, "level", current_level)
    cfg.set_value(section, "skill_points", skill_points)
    cfg.set_value(section, "learned_skills", learned)
    cfg.set_value(section, "skill_ranks", ranks)
    cfg.set_value(section, "equipped_skills", equipped)
    cfg.save(SAVE_PATH)

    var effective_stats := stats_for(hero_id, current_level)
    for skill_id in learned:
        var passive := skill_by_id(hero_id, skill_id)
        if str(passive.get("type", "active")) != "passive":
            continue
        for stat in passive.get("stat_bonus", {}).keys():
            effective_stats[stat] = float(effective_stats.get(stat, 0)) + float(passive["stat_bonus"][stat]) * float(ranks.get(skill_id, 0))
    for stat in effective_stats.keys():
        if stat != "crit":
            effective_stats[stat] = int(round(float(effective_stats[stat])))

    return {
        "hero_id": hero_id,
        "xp": xp,
        "level": current_level,
        "skill_points": skill_points,
        "learned_skills": learned,
        "skill_ranks": ranks,
        "equipped_skills": equipped,
        "stats": effective_stats
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

    var ranks: Dictionary = profile.get("skill_ranks", {})
    if int(ranks.get(skill_id, 0)) >= int(skill.get("max_rank", 1)):
        return false
    if int(profile.get("level", 1)) < int(skill.get("level_req", 1)):
        return false
    if int(profile.get("skill_points", 0)) < int(skill.get("point_cost_per_rank", 1)):
        return false

    var tree_spent := 0
    var definition := hero_definition(hero_id)
    for node in definition.get("skills", []):
        if str(node.get("tree", "")) == str(skill.get("tree", "")):
            var node_id := str(node.get("id", ""))
            var free_rank := 1 if definition.get("starting_skills", []).has(node_id) else 0
            tree_spent += maxi(0, int(ranks.get(node_id, 0)) - free_rank)
    if hero_id == CHOSEN_HERO_ID and not chosen_hero_can_access_path(str(skill.get("tree", ""))):
        return false
    if tree_spent < int(skill.get("tier_spend_required", 0)):
        return false

    for required_variant in skill.get("requires", []):
        if int(ranks.get(str(required_variant), 0)) < 1:
            return false
    return true


static func learn_skill(hero_id: String, skill_id: String) -> bool:
    if not can_learn(hero_id, skill_id):
        return false

    var profile := ensure_profile(hero_id)
    var ranks: Dictionary = profile.get("skill_ranks", {}).duplicate(true)
    ranks[skill_id] = int(ranks.get(skill_id, 0)) + 1

    var cfg := ConfigFile.new()
    cfg.load(SAVE_PATH)
    var section := "hero:%s" % hero_id
    cfg.set_value(section, "skill_ranks", ranks)
    cfg.save(SAVE_PATH)
    ensure_profile(hero_id)
    return true


static func respec(hero_id: String) -> bool:
    var definition := hero_definition(hero_id)
    if definition.is_empty():
        return false
    var ranks: Dictionary = {}
    var equipped: Array[String] = []
    for raw_id in definition.get("starting_skills", []):
        var id := str(raw_id)
        ranks[id] = 1
        if str(skill_by_id(hero_id, id).get("type", "active")) == "active":
            equipped.append(id)
    var cfg := ConfigFile.new()
    cfg.load(SAVE_PATH)
    var section := "hero:%s" % hero_id
    cfg.set_value(section, "skill_ranks", ranks)
    cfg.set_value(section, "learned_skills", ranks.keys())
    cfg.set_value(section, "equipped_skills", equipped)
    if cfg.save(SAVE_PATH) != OK:
        return false
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
