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

static func consumables() -> Dictionary:
    return catalog().get("consumables", {})

static func region_pool(region_id: String) -> Dictionary:
    return catalog().get("region_pools", {}).get(region_id, {})

static func loadout(hero_id: String) -> Dictionary:
    var cfg := ConfigFile.new()
    cfg.load(SAVE_PATH)
    var result: Dictionary = {}
    for slot in SLOTS:
        result[slot] = str(cfg.get_value("hero:%s" % hero_id, slot, ""))
    return result

# Old template IDs remain valid so existing saves and unlocked heroes keep their gear.
static func inventory() -> Array[String]:
    var cfg := ConfigFile.new()
    cfg.load(SAVE_PATH)
    var result: Array[String] = []
    for item_id in cfg.get_value("loot", "inventory", []):
        if items().has(str(item_id)) and not result.has(str(item_id)):
            result.append(str(item_id))
    return result

static func _is_equipped_in_config(cfg: ConfigFile, reference: String) -> bool:
    for section in cfg.get_sections():
        if not str(section).begins_with("hero:"):
            continue
        for slot in SLOTS:
            if str(cfg.get_value(section, slot, "")) == reference:
                return true
    return false

static func is_equipped(reference: String) -> bool:
    var cfg := ConfigFile.new()
    cfg.load(SAVE_PATH)
    return _is_equipped_in_config(cfg, reference)

static func unassigned_inventory_references() -> Array[String]:
    var cfg := ConfigFile.new()
    cfg.load(SAVE_PATH)
    var result: Array[String] = []
    for reference in cfg.get_value("loot", "inventory", []):
        var item_id := str(reference)
        if items().has(item_id) and not _is_equipped_in_config(cfg, item_id):
            result.append(item_id)
    for instance in cfg.get_value("gear", "instances", []):
        var instance_id := str(instance.get("id", ""))
        if instance_id != "" and not _is_equipped_in_config(cfg, instance_id):
            result.append(instance_id)
    return result

static func owns_template(template_id: String) -> bool:
    if inventory().has(template_id):
        return true
    for instance in gear_instances():
        if str(instance.get("template", "")) == template_id:
            return true
    return false

# Foundry synthesis consumes only unassigned inventory, never a piece worn by
# any hero. The transaction writes inputs, output, and gold together.
static func synthesize(recipe_id: String, ingredients: Array[String], output_id: String, cost: int) -> Dictionary:
    if ingredients.size() < 2 or not items().has(output_id) or cost < 0:
        return {"ok": false, "reason": "The foundry cannot read this design."}
    var cfg := ConfigFile.new()
    cfg.load(SAVE_PATH)
    var balance := int(cfg.get_value("economy", "gold", 0))
    if balance < cost:
        return {"ok": false, "reason": "You need %d more gold to commission this item." % (cost - balance)}
    var loot: Array = cfg.get_value("loot", "inventory", [])
    var instances: Array = cfg.get_value("gear", "instances", [])
    var output_owned := loot.has(output_id)
    for instance in instances:
        if str(instance.get("template", "")) == output_id:
            output_owned = true
            break
    if output_owned:
        return {"ok": false, "reason": "Your company already owns this forged design."}
    var refs_to_consume: Array[String] = []
    for reference in ingredients:
        if reference.is_empty() or refs_to_consume.has(reference) or _is_equipped_in_config(cfg, reference):
            return {"ok": false, "reason": "The listed components must be distinct and unequipped."}
        var found := loot.has(reference)
        if reference.begins_with("gear:"):
            found = false
            for instance in instances:
                if str(instance.get("id", "")) == reference:
                    found = true
                    break
        if not found:
            return {"ok": false, "reason": "Missing an unequipped component: %s." % str(item_for(reference).get("name", reference))}
        refs_to_consume.append(reference)
    for reference in refs_to_consume:
        if reference.begins_with("gear:"):
            for index in range(instances.size() - 1, -1, -1):
                if str(instances[index].get("id", "")) == reference:
                    instances.remove_at(index)
                    break
        else:
            loot.erase(reference)
    loot.append(output_id)
    cfg.set_value("loot", "inventory", loot)
    cfg.set_value("gear", "instances", instances)
    cfg.set_value("economy", "gold", balance - cost)
    if cfg.save(SAVE_PATH) != OK:
        return {"ok": false, "reason": "The foundry ledger could not be saved."}
    return {"ok": true, "recipe": recipe_id, "item": items()[output_id].duplicate(true), "gold": balance - cost}

static func gold() -> int:
    var cfg := ConfigFile.new()
    cfg.load(SAVE_PATH)
    return maxi(0, int(cfg.get_value("economy", "gold", 0)))

static func award_gold(category: String, source_id: String, amount: int) -> int:
    if amount <= 0:
        return 0
    var cfg := ConfigFile.new()
    cfg.load(SAVE_PATH)
    var source_key := "%s:%s" % [category, source_id]
    var claimed: Array = cfg.get_value("economy", "claimed_gold_sources", [])
    if claimed.has(source_key):
        return 0
    claimed.append(source_key)
    cfg.set_value("economy", "claimed_gold_sources", claimed)
    cfg.set_value("economy", "gold", int(cfg.get_value("economy", "gold", 0)) + amount)
    return amount if cfg.save(SAVE_PATH) == OK else 0

static func spend_gold(amount: int) -> bool:
    if amount <= 0:
        return false
    var cfg := ConfigFile.new()
    cfg.load(SAVE_PATH)
    var balance := int(cfg.get_value("economy", "gold", 0))
    if balance < amount:
        return false
    cfg.set_value("economy", "gold", balance - amount)
    return cfg.save(SAVE_PATH) == OK

static func gear_instances() -> Array:
    var cfg := ConfigFile.new()
    cfg.load(SAVE_PATH)
    return cfg.get_value("gear", "instances", [])

static func item_for(reference: String) -> Dictionary:
    if items().has(reference):
        return (items()[reference] as Dictionary).duplicate(true)
    for instance in gear_instances():
        if str(instance.get("id", "")) == reference:
            var item: Dictionary = items().get(str(instance.get("template", "")), {}).duplicate(true)
            if not item.is_empty():
                item["name"] = str(instance.get("name", item.get("name", reference)))
                item["stats"] = instance.get("stats", {})
                item["rarity"] = instance.get("rarity", "")
                item["quality"] = instance.get("quality", 0)
                item["source"] = instance.get("source", "")
            return item
    return {}

static func owned(reference: String, collectibles: Array[String]) -> bool:
    var item := item_for(reference)
    if item.is_empty():
        return false
    if reference.begins_with("gear:"):
        return true
    return bool(item.get("starter", false)) or collectibles.has(reference) or inventory().has(reference)

static func reward_for(category: String, source_id: String) -> String:
    return str(catalog().get("loot_sources", {}).get(category, {}).get(source_id, ""))

# Preserved for one-time quest relics and old save compatibility.
static func claim_reward(category: String, source_id: String) -> String:
    var item_id := reward_for(category, source_id)
    if not items().has(item_id):
        return ""
    var cfg := ConfigFile.new()
    cfg.load(SAVE_PATH)
    var source_key := "%s:%s" % [category, source_id]
    var claimed: Array = cfg.get_value("loot", "claimed_sources", [])
    if claimed.has(source_key):
        return ""
    var owned_items: Array = cfg.get_value("loot", "inventory", [])
    var newly_owned := not owned_items.has(item_id)
    if newly_owned:
        owned_items.append(item_id)
    claimed.append(source_key)
    cfg.set_value("loot", "inventory", owned_items)
    cfg.set_value("loot", "claimed_sources", claimed)
    if cfg.save(SAVE_PATH) != OK:
        return ""
    return item_id if newly_owned else ""

static func _roll_rarity() -> String:
    var rarities: Dictionary = catalog().get("rarities", {})
    var total := 0
    for rarity in rarities:
        total += int(rarities[rarity].get("weight", 0))
    var roll := randi_range(1, maxi(1, total))
    for rarity in rarities:
        roll -= int(rarities[rarity].get("weight", 0))
        if roll <= 0:
            return str(rarity)
    return "tempered"

static func _create_instance(cfg: ConfigFile, template_id: String, source: String) -> Dictionary:
    var base: Dictionary = items().get(template_id, {})
    if base.is_empty():
        return {}
    var instances: Array = cfg.get_value("gear", "instances", [])
    var serial := int(cfg.get_value("gear", "next_id", 1))
    var rarity := _roll_rarity()
    var quality := randi_range(1, 100)
    var multiplier := float(catalog().get("rarities", {}).get(rarity, {}).get("multiplier", 1.0)) * (0.9 + float(quality) * 0.002)
    var stats: Dictionary = {}
    for stat in base.get("stats", {}):
        stats[stat] = maxi(1, int(round(float(base["stats"][stat]) * multiplier)))
    var affix := ""
    if rarity in ["rare", "epic", "legendary"]:
        var affixes: Dictionary = catalog().get("affixes", {})
        var names := affixes.keys()
        if not names.is_empty():
            affix = str(names.pick_random())
            for stat in affixes[affix]:
                stats[stat] = int(stats.get(stat, 0)) + int(affixes[affix][stat])
    var instance := {"id": "gear:%d" % serial, "template": template_id, "name": "%s%s" % [str(base.get("name", template_id)), " " + affix if affix != "" else ""], "rarity": rarity, "quality": quality, "stats": stats, "source": source}
    instances.append(instance)
    cfg.set_value("gear", "instances", instances)
    cfg.set_value("gear", "next_id", serial + 1)
    return instance

static func _claim_drop(source: String, template_id: String) -> Dictionary:
    if not items().has(template_id):
        return {}
    var cfg := ConfigFile.new()
    cfg.load(SAVE_PATH)
    var claimed: Array = cfg.get_value("gear", "claimed_drops", [])
    if claimed.has(source):
        return {}
    var instance := _create_instance(cfg, template_id, source)
    claimed.append(source)
    cfg.set_value("gear", "claimed_drops", claimed)
    if cfg.save(SAVE_PATH) != OK:
        return {}
    return instance

static func claim_equipment_reward(category: String, source_id: String) -> Dictionary:
    return _claim_drop("%s:%s" % [category, source_id], reward_for(category, source_id))

static func claim_region_drop(category: String, source_id: String, region_id: String, drop_chance: int = 35, signature_chance: int = 12) -> Dictionary:
    var pool := region_pool(region_id)
    var common: Array = pool.get("common", [])
    var signature := str(pool.get("signature", ""))
    if pool.is_empty() or (common.is_empty() and (signature.is_empty() or not items().has(signature))):
        return {}

    var source := "region:%s:%s:%s" % [region_id, category, source_id]
    var cfg := ConfigFile.new()
    cfg.load(SAVE_PATH)
    var claimed: Array = cfg.get_value("gear", "claimed_drops", [])
    if claimed.has(source):
        return {}
    claimed.append(source)

    if randi_range(1, 100) > clampi(drop_chance, 0, 100):
        cfg.set_value("gear", "claimed_drops", claimed)
        cfg.save(SAVE_PATH)
        return {}

    var template_id := signature if not signature.is_empty() and randi_range(1, 100) <= clampi(signature_chance, 0, 100) else ""
    if template_id.is_empty() and not common.is_empty():
        template_id = str(common.pick_random())
    if not items().has(template_id):
        return {}

    var instance := _create_instance(cfg, template_id, source)
    if instance.is_empty():
        return {}
    cfg.set_value("gear", "claimed_drops", claimed)
    if cfg.save(SAVE_PATH) != OK:
        return {}
    return instance


static func begin_vault_raid() -> int:
    var cfg := ConfigFile.new()
    cfg.load(SAVE_PATH)
    var serial := int(cfg.get_value("gear", "vault_raid_serial", 0)) + 1
    cfg.set_value("gear", "vault_raid_serial", serial)
    if cfg.save(SAVE_PATH) != OK:
        return 0
    return serial

static func claim_vault_drop(region_id: String, raid_id: int) -> Dictionary:
    var pool := region_pool(region_id)
    if pool.is_empty() or raid_id <= 0:
        return {}
    var cfg := ConfigFile.new()
    cfg.load(SAVE_PATH)
    var source := "vault:%s:%d" % [region_id, raid_id]
    if (cfg.get_value("gear", "claimed_drops", []) as Array).has(source):
        return {}
    var choices: Array = pool.get("common", [])
    if choices.is_empty():
        return {}
    var template_id := str(pool.get("signature", "")) if randi_range(1, 100) <= 12 else str(choices.pick_random())
    return _claim_drop(source, template_id)

static func supply_count(supply_id: String) -> int:
    var cfg := ConfigFile.new()
    cfg.load(SAVE_PATH)
    return int(cfg.get_value("supplies", supply_id, 0))

static func add_supply(supply_id: String, amount: int = 1) -> bool:
    if not consumables().has(supply_id) or amount <= 0:
        return false
    var cfg := ConfigFile.new()
    cfg.load(SAVE_PATH)
    cfg.set_value("supplies", supply_id, int(cfg.get_value("supplies", supply_id, 0)) + amount)
    return cfg.save(SAVE_PATH) == OK

static func use_supply(supply_id: String, context: String) -> Dictionary:
    var supply: Dictionary = consumables().get(supply_id, {})
    if supply.is_empty() or not (supply.get("use", []) as Array).has(context):
        return {}
    var cfg := ConfigFile.new()
    cfg.load(SAVE_PATH)
    var count := int(cfg.get_value("supplies", supply_id, 0))
    if count <= 0:
        return {}
    cfg.set_value("supplies", supply_id, count - 1)
    if cfg.save(SAVE_PATH) != OK:
        return {}
    return supply

static func claim_supply_drop(category: String, source_id: String, region_id: String) -> String:
    var choices: Array = catalog().get("region_supplies", {}).get(region_id, [])
    if choices.is_empty():
        return ""
    var cfg := ConfigFile.new()
    cfg.load(SAVE_PATH)
    var key := "supply:%s:%s" % [category, source_id]
    var claimed: Array = cfg.get_value("supplies", "claimed_sources", [])
    if claimed.has(key):
        return ""
    var supply_id := str(choices.pick_random())
    claimed.append(key)
    cfg.set_value("supplies", "claimed_sources", claimed)
    cfg.set_value("supplies", supply_id, int(cfg.get_value("supplies", supply_id, 0)) + 1)
    if cfg.save(SAVE_PATH) != OK:
        return ""
    return supply_id

static func _can_use_slot(hero_id: String, slot: String, item: Dictionary) -> bool:
    if str(item.get("slot", "")) == slot:
        return true
    var traits: Array = catalog().get("hero_traits", {}).get(hero_id, [])
    return slot == "left_hand" and str(item.get("slot", "")) == "right_hand" and int(item.get("hands", 1)) == 2 and traits.has("OneHandedHeavy")

static func equip(hero_id: String, slot: String, reference: String, collectibles: Array[String]) -> bool:
    if not SLOTS.has(slot):
        return false
    var item := item_for(reference) if reference != "" else {}
    if reference != "" and (item.is_empty() or not _can_use_slot(hero_id, slot, item) or not owned(reference, collectibles)):
        return false
    var cfg := ConfigFile.new()
    cfg.load(SAVE_PATH)
    var section := "hero:%s" % hero_id
    if reference.begins_with("gear:"):
        for other_section in cfg.get_sections():
            if not str(other_section).begins_with("hero:"):
                continue
            for other_slot in SLOTS:
                if str(cfg.get_value(other_section, other_slot, "")) == reference:
                    cfg.set_value(other_section, other_slot, "")
    if slot in ["right_hand", "left_hand"] and reference != "":
        var other_slot := "left_hand" if slot == "right_hand" else "right_hand"
        var other_item := item_for(str(cfg.get_value(section, other_slot, "")))
        var traits: Array = catalog().get("hero_traits", {}).get(hero_id, [])
        if not traits.has("OneHandedHeavy") and (int(item.get("hands", 1)) == 2 or int(other_item.get("hands", 1)) == 2):
            cfg.set_value(section, other_slot, "")
    cfg.set_value(section, slot, reference)
    return cfg.save(SAVE_PATH) == OK

static func effective_stats(hero_id: String, base: Dictionary) -> Dictionary:
    var result := base.duplicate(true)
    var equipped := loadout(hero_id)
    var hero_tags: Array = catalog().get("hero_tags", {}).get(hero_id, [])
    var region_counts: Dictionary = {}
    for slot in SLOTS:
        var item := item_for(str(equipped.get(slot, "")))
        if item.is_empty():
            continue
        var region := str(item.get("region", ""))
        if region != "":
            region_counts[region] = int(region_counts.get(region, 0)) + 1
        for stat in item.get("stats", {}):
            result[stat] = float(result.get(stat, 0)) + float(item["stats"][stat])
        for tag in item.get("synergy_tags", []):
            if hero_tags.has(tag):
                for stat in item.get("synergy_stats", {}):
                    result[stat] = float(result.get(stat, 0)) + float(item["synergy_stats"][stat])
                break
        if str(item.get("signature_hero", "")) == hero_id:
            for stat in item.get("signature_stats", {}):
                result[stat] = float(result.get(stat, 0)) + float(item["signature_stats"][stat])
    for region in region_counts:
        for threshold in catalog().get("set_bonuses", {}):
            if int(region_counts[region]) >= int(threshold):
                for stat in catalog()["set_bonuses"][threshold]:
                    result[stat] = float(result.get(stat, 0)) + float(catalog()["set_bonuses"][threshold][stat])
    for stat in result:
        if stat != "crit":
            result[stat] = int(round(float(result[stat])))
    return result
