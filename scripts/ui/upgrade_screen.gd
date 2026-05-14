extends CanvasLayer

const UPGRADE_CARD_SCENE = preload("res://prefabs/ui/upgrade_card.tscn")

@onready var _card_row: HBoxContainer = $Center/VBox/CardRow

const UPGRADES := [
	{"id": "haste",       "name": "HASTE",       "desc": "+40 move speed"},
	{"id": "rapid_fire",  "name": "RAPID FIRE",  "desc": "Shoot 25% faster"},
	{"id": "marksman",    "name": "MARKSMAN",    "desc": "+8 bullet damage"},
	{"id": "toughness",   "name": "TOUGHNESS",   "desc": "+30 max HP\n& restore 30"},
	{"id": "ammo_cache",  "name": "AMMO CACHE",  "desc": "+150 max ammo\n& refill"},
	{"id": "vital_surge", "name": "VITAL SURGE", "desc": "Fully restore HP"},
	{"id": "volatile",    "name": "VOLATILE",    "desc": "Bullets explode\non impact"},
	{"id": "seeker",      "name": "SEEKER",      "desc": "Bullets home\ntoward enemies"},
	{"id": "penetrator",  "name": "PENETRATOR",  "desc": "Bullets pierce\nthrough enemies"},
	{"id": "payload",     "name": "PAYLOAD",     "desc": "Fire 3 bullets\nin a spread"},
	{"id": "velocity",    "name": "VELOCITY",    "desc": "+60% bullet\nspeed"},
	{"id": "ricochet",    "name": "RICOCHET",    "desc": "Bullets bounce\noff walls"},
	{"id": "split",       "name": "SPLIT",       "desc": "Each bullet\nforks into two"},
]

func _ready() -> void:
	add_to_group("upgrade_screen")
	get_tree().paused = true
	var pool := UPGRADES.duplicate()
	pool.shuffle()
	for upgrade in pool.slice(0, 3):
		_card_row.add_child(_make_card(upgrade))

func _make_card(upgrade: Dictionary) -> Button:
	var btn: Button = UPGRADE_CARD_SCENE.instantiate()
	btn.get_node("NameLabel").text = upgrade.name
	btn.get_node("DescLabel").text = upgrade.desc
	btn.pressed.connect(func(): _on_chosen(upgrade))
	return btn

func _on_chosen(upgrade: Dictionary) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		_apply(player, upgrade)
	get_tree().paused = false
	queue_free()

func _apply(player: Node, upgrade: Dictionary) -> void:
	match upgrade.id:
		"haste":
			player.SPEED += 40.0
		"rapid_fire":
			player.FIRE_RATE = maxf(0.05, player.FIRE_RATE * 0.75)
		"marksman":
			player.bullet_damage += 8
		"toughness":
			player.MAX_HEALTH += 30
			player.health = min(player.health + 30, player.MAX_HEALTH)
		"ammo_cache":
			player.MAX_AMMO += 150
			player.ammo = min(player.ammo + 150, player.MAX_AMMO)
		"vital_surge":
			player.health = player.MAX_HEALTH
		"volatile":
			player.bullet_explosive = true
		"seeker":
			player.bullet_homing = true
		"penetrator":
			player.bullet_piercing = true
		"payload":
			player.bullet_count = 3
		"velocity":
			player.bullet_speed_multiplier = minf(player.bullet_speed_multiplier * 1.6, 3.0)
		"ricochet":
			player.bullet_extra_bounces += 3
		"split":
			player.bullet_split = true
