extends Node

const SAVE_PATH = "user://player_stats.cfg"

## Each stat entry: label shown in UI, per-level effect description, XP cost for level 0→1,
## and the maximum level the player can reach.
const STAT_DEFS = {
	"max_health": {"label": "Max Health",    "desc": "+25 HP",      "base_cost": 50,  "max_level": 100},
	"speed":      {"label": "Move Speed",    "desc": "+15 speed",   "base_cost": 50,  "max_level": 100},
	"damage":     {"label": "Bullet Damage", "desc": "+2 damage",   "base_cost": 60,  "max_level": 100},
	"fire_rate":  {"label": "Fire Rate",     "desc": "-0.008s cd",  "base_cost": 70,  "max_level": 100},
	"max_ammo":   {"label": "Max Ammo",      "desc": "+50 ammo",    "base_cost": 40,  "max_level": 100},
}

var xp: int = 0
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

# --- stat bonuses applied to player ---

func health_bonus() -> int:
	return get_level("max_health") * 25

func speed_bonus() -> float:
	return get_level("speed") * 15.0

func damage_bonus() -> int:
	return get_level("damage") * 2

func fire_rate_reduction() -> float:
	return get_level("fire_rate") * 0.008

func ammo_bonus() -> int:
	return get_level("max_ammo") * 50

# --- persistence ---

func _save() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("stats", "xp", xp)
	for key in levels:
		cfg.set_value("levels", key, levels[key])
	cfg.save(SAVE_PATH)

func _load() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	xp = cfg.get_value("stats", "xp", 0)
	for key in levels:
		levels[key] = cfg.get_value("levels", key, 0)
