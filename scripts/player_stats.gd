extends Node

const SAVE_PATH = "user://player_stats.cfg"

## Each stat entry: label shown in UI, per-level effect description, XP cost for level 0→1,
## and the maximum level the player can reach.
const STAT_DEFS = {
	"max_health": {"label": "Max Health",    "desc": "+5 HP",       "base_cost": 50,  "max_level": 100},
	"speed":      {"label": "Move Speed",    "desc": "+15 speed",   "base_cost": 50,  "max_level": 100},
	"damage":     {"label": "Bullet Damage", "desc": "+2 damage",   "base_cost": 60,  "max_level": 100},
	"fire_rate":  {"label": "Fire Rate",     "desc": "-0.008s cd",  "base_cost": 70,  "max_level": 100},
	"max_ammo":   {"label": "Max Ammo",      "desc": "+10 ammo",    "base_cost": 40,  "max_level": 100},
}

## Gun definitions — edit stats here. Applied on top of persistent upgrades each run.
## DPS = (damage_mult * 5) * bullet_count / max(0.05, fire_rate_mult * 0.1)
const GUN_DEFS = {
	"gun1": {
		"name": "Tiny Jim",       "desc": "Lil' starter blaster",       "cost": 0,   "sprite": "res://assets/sprites/weapons/gun1.png",
		"fire_rate_mult": 1.0,  "damage_mult": 1.0,  "bullet_count": 1, "speed_mult": 1.0,  "bullet_size": 1.0,  "bounces": 0, "color": Color.WHITE,
		# DPS ≈ 50
	},
	"gun2": {
		"name": "Clanker-er",     "desc": "High fire rate,\nlow damage",  "cost": 25,  "sprite": "res://assets/sprites/weapons/gun2.png",
		"fire_rate_mult": 0.45, "damage_mult": 0.65, "bullet_count": 1, "speed_mult": 1.3,  "bullet_size": 0.7,  "bounces": 0, "color": Color(0, 0.9, 1.0),
		# fire_rate hits 0.05s cap → DPS ≈ 65
	},
	"gun3": {
		"name": "Chicken Burger", "desc": "Slow but hits\nextremely hard","cost": 75,  "sprite": "res://assets/sprites/weapons/gun3.png",
		"fire_rate_mult": 2.5,  "damage_mult": 4.5,  "bullet_count": 1, "speed_mult": 0.3,  "bullet_size": 3.0,  "bounces": 0, "color": Color(1.0, 0.75, 0),
		# DPS ≈ 90
	},
	"gun4": {
		"name": "Angler Jaw",     "desc": "3-bullet spread,\nshort range","cost": 150, "sprite": "res://assets/sprites/weapons/gun4.png",
		"fire_rate_mult": 1.2,  "damage_mult": 1.0,  "bullet_count": 3, "speed_mult": 0.8,  "bullet_size": 0.9,  "bounces": 0, "color": Color(0.1, 0.9, 0.1),
		# DPS ≈ 125
	},
	"gun5": {
		"name": "GIGA CHONGO",    "desc": "Massive laser\nbeam",          "cost": 500, "sprite": "res://assets/sprites/weapons/gun5.png",
		"fire_rate_mult": 1.0,  "damage_mult": 5.0,  "bullet_count": 1, "speed_mult": 1.0,  "bullet_size": 1.0,  "bounces": 0, "color": Color(1, 1, 0),
		# 25 DPS per enemy simultaneously in AoE
		"shoot_mode": "laser",
	},
}

var xp: int = 0
var coins: int = 0
var boss_tokens: int = 0       # collected across runs; used to spawn the boss
var unlocked_maps: Array = []  # map names unlocked by defeating bosses
var owned_guns: Array = []  # purchased gun IDs; pistol is always available without being listed
var equipped_gun: String = "gun1"
var levels: Dictionary = {}

func _ready() -> void:
	for key in STAT_DEFS:
		levels[key] = 0
	_load()

# --- query helpers ---

func get_level(stat: String) -> int:
	return levels.get(stat, 0)

## XP cost to go from current level to the next.  Scales as base_cost * 1.8^level.
func upgrade_cost(stat: String) -> int:
	return int(STAT_DEFS[stat]["base_cost"] * pow(1.8, get_level(stat)))

func can_upgrade(stat: String) -> bool:
	return xp >= upgrade_cost(stat) and get_level(stat) < STAT_DEFS[stat]["max_level"]

func owns_gun(id: String) -> bool:
	return id == "gun1" or id in owned_guns

func buy_gun(id: String, cost: int) -> bool:
	if owns_gun(id) or coins < cost:
		return false
	coins -= cost
	owned_guns.append(id)
	_save()
	return true

func equip_gun(id: String) -> void:
	if owns_gun(id):
		equipped_gun = id
		_save()

# --- mutation ---

func spend_xp(stat: String) -> void:
	if not can_upgrade(stat):
		return
	xp -= upgrade_cost(stat)
	levels[stat] += 1
	_save()

func add_xp(amount: int) -> void:
	xp += amount
	_save()

func add_coins(amount: int) -> void:
	coins += amount
	_save()

func add_boss_token() -> void:
	boss_tokens += 1
	_save()

func unlock_map(map_name: String) -> void:
	if not unlocked_maps.has(map_name):
		unlocked_maps.append(map_name)
		_save()

func reset() -> void:
	xp = 0
	coins = 0
	owned_guns = []
	equipped_gun = "gun1"
	unlocked_maps = []
	for key in levels:
		levels[key] = 0
	_save()

# --- stat bonuses applied to player ---

func health_bonus() -> int:
	return get_level("max_health") * 5

func speed_bonus() -> float:
	return get_level("speed") * 15.0

func damage_bonus() -> int:
	return get_level("damage") * 2

func fire_rate_reduction() -> float:
	return get_level("fire_rate") * 0.008

func ammo_bonus() -> int:
	return get_level("max_ammo") * 10

# --- persistence ---

func _save() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("stats", "xp", xp)
	cfg.set_value("stats", "coins", coins)
	cfg.set_value("stats", "boss_tokens", boss_tokens)
	cfg.set_value("stats", "unlocked_maps", unlocked_maps)
	cfg.set_value("stats", "owned_guns", owned_guns)
	cfg.set_value("stats", "equipped_gun", equipped_gun)
	for key in levels:
		cfg.set_value("levels", key, levels[key])
	cfg.save(SAVE_PATH)

func _load() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	xp = cfg.get_value("stats", "xp", 0)
	coins = cfg.get_value("stats", "coins", 0)
	boss_tokens = cfg.get_value("stats", "boss_tokens", 0)
	unlocked_maps = cfg.get_value("stats", "unlocked_maps", [])
	owned_guns = cfg.get_value("stats", "owned_guns", [])
	equipped_gun = cfg.get_value("stats", "equipped_gun", "gun1")
	for key in levels:
		levels[key] = cfg.get_value("levels", key, 0)
