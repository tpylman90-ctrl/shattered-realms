class_name CampaignDirector
extends RefCounted

const FLOW_PATH := "res://data/campaign_flow.json"
const SAVE_PATH := "user://campaign_progress.cfg"
const FALLBACK_MAX_LEVEL := 30
const HeroProgressionService = preload("res://scripts/hero_progression.gd")

static var _flow_cache: Dictionary = {}


static func flow() -> Dictionary:
	if not _flow_cache.is_empty():
		return _flow_cache
	if not FileAccess.file_exists(FLOW_PATH):
		push_error("Campaign flow data missing: %s" % FLOW_PATH)
		return {}
	var file := FileAccess.open(FLOW_PATH, FileAccess.READ)
	if not file:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_flow_cache = (parsed as Dictionary).duplicate(true)
	return _flow_cache


static func campaign_text() -> Dictionary:
	return flow().get("campaign", {})


static func territory(territory_id: String) -> Dictionary:
	var territories: Dictionary = flow().get("territories", {})
	if territories.has(territory_id):
		return (territories[territory_id] as Dictionary).duplicate(true)
	var finale: Dictionary = campaign_text().get("finale", {})
	if territory_id == str(finale.get("territory", "")):
		return finale.duplicate(true)
	return {}


static func state() -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	var secured: Array[String] = []
	for value in cfg.get_value("campaign", "secured_territories", []):
		var territory_id := str(value)
		if territory(territory_id).is_empty() or secured.has(territory_id):
			continue
		secured.append(territory_id)
	var recruited: Array[String] = []
	var default_recruits: Array = campaign_text().get("starting_heroes", [])
	for value in cfg.get_value("campaign", "recruited_heroes", default_recruits):
		var hero_id := str(value)
		if hero_id != "" and not recruited.has(hero_id):
			recruited.append(hero_id)
	return {"secured_territories": secured, "recruited_heroes": recruited}


static func _save_state(progress: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("campaign", "secured_territories", progress.get("secured_territories", []))
	cfg.set_value("campaign", "recruited_heroes", progress.get("recruited_heroes", []))
	cfg.save(SAVE_PATH)


static func secure_territory(territory_id: String) -> void:
	if territory(territory_id).is_empty():
		return
	var progress := state()
	var secured: Array = progress.get("secured_territories", [])
	if not secured.has(territory_id):
		secured.append(territory_id)
	progress["secured_territories"] = secured
	_save_state(progress)


static func unsecure_territory(territory_id: String) -> void:
	var progress := state()
	var secured: Array = progress.get("secured_territories", [])
	secured.erase(territory_id)
	progress["secured_territories"] = secured
	_save_state(progress)


static func recruit_hero(hero_id: String) -> void:
	if hero_id == "":
		return
	var progress := state()
	var recruited: Array = progress.get("recruited_heroes", [])
	if not recruited.has(hero_id):
		recruited.append(hero_id)
	progress["recruited_heroes"] = recruited
	_save_state(progress)


static func reset_territories() -> void:
	var progress := state()
	progress["secured_territories"] = []
	_save_state(progress)


static func is_route_open(territory_id: String) -> bool:
	if territory_id == str(campaign_text().get("starting_territory", "ashen_wastes")):
		return true
	var progress := state()
	var secured: Array = progress.get("secured_territories", [])
	var target := territory(territory_id)
	if target.is_empty():
		return false
	for neighbor_variant in target.get("connected_to", []):
		if secured.has(str(neighbor_variant)):
			return true
	return false


static func route_status(territory_id: String) -> String:
	var progress := state()
	if (progress.get("secured_territories", []) as Array).has(territory_id):
		return "RECONNECTED"
	if territory_id == str(campaign_text().get("starting_territory", "ashen_wastes")):
		return "STARTING TERRITORY"
	if is_route_open(territory_id):
		return "OPEN ROUTE"
	return "SEALED ROUTE"


static func open_routes() -> Array[String]:
	var progress := state()
	var secured: Array = progress.get("secured_territories", [])
	var start_id := str(campaign_text().get("starting_territory", "ashen_wastes"))
	var territories: Dictionary = flow().get("territories", {})
	var result: Array[String] = []
	for territory_id_variant in territories.keys():
		var territory_id := str(territory_id_variant)
		if secured.has(territory_id) or territory_id == start_id:
			continue
		if is_route_open(territory_id):
			result.append(territory_id)
	return result


static func finale_status(recruited_count: int) -> Dictionary:
	var finale: Dictionary = campaign_text().get("finale", {})
	var required := int(finale.get("requires_recruited_heroes", 9))
	return {
		"required": required,
		"recruited": recruited_count,
		"ready": recruited_count >= required,
		"remaining": maxi(0, required - recruited_count)
	}


static func can_begin_finale() -> bool:
	var progress := state()
	return bool(finale_status((progress.get("recruited_heroes", []) as Array).size()).get("ready", false))


static func scaled_enemy(encounter: Dictionary, player_level: int, territory_id: String) -> Dictionary:
	var region := territory(territory_id)
	var danger := maxi(1, int(encounter.get("danger", 1)))
	var recommended_level := maxi(1, int(region.get("recommended_level", 1)))
	var level_offset := int(encounter.get("level_offset", danger - 1))
	var max_level := int(HeroProgressionService.data().get("rules", {}).get("max_level", FALLBACK_MAX_LEVEL))
	var enemy_level := clampi(maxi(recommended_level, maxi(1, player_level) + level_offset), 1, max_level)
	var base_level := maxi(1, int(encounter.get("base_level", recommended_level)))
	var level_delta := enemy_level - base_level
	var hp_scale := clampf(pow(1.065, float(level_delta)), 0.65, 6.0)
	var attack_scale := clampf(pow(1.035, float(level_delta)), 0.72, 2.75)
	var xp_scale := clampf(1.0 + float(maxi(0, level_delta)) * 0.035, 1.0, 1.75)
	var base_hp := maxi(1, int(encounter.get("base_hp", 48 + danger * 22)))
	var base_attack := maxi(1, int(encounter.get("base_attack", 5 + danger * 4)))
	var base_xp := maxi(0, int(encounter.get("xp", 0)))
	return {
		"enemy_level": enemy_level,
		"danger": danger,
		"hp": maxi(1, int(round(float(base_hp) * hp_scale))),
		"attack": maxi(1, int(round(float(base_attack) * attack_scale))),
		"xp": int(round(float(base_xp) * xp_scale)),
		"hp_scale": hp_scale,
		"attack_scale": attack_scale,
		"recommended_level": recommended_level
	}
