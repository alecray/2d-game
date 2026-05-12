extends PanelContainer

signal purchased(gun_id: String)
signal equipped(gun_id: String)

var _gun: Dictionary
var _stats: Node

@onready var _gun_sprite: TextureRect = $HBox/GunSprite
@onready var _name_label: Label = $HBox/InfoBox/NameLabel
@onready var _desc_label: Label = $HBox/InfoBox/DescLabel
@onready var _price_label: Label = $HBox/BuyBox/PriceLabel
@onready var _btn_buy: Button = $HBox/BuyBox/BtnBuy
@onready var _btn_equip: Button = $HBox/BuyBox/BtnEquip

func setup(gun: Dictionary, stats: Node) -> void:
	_gun = gun
	_stats = stats
	if gun.sprite != "":
		_gun_sprite.texture = load(gun.sprite)
	_name_label.text = gun.name
	_desc_label.text = gun.desc
	_price_label.text = "FREE" if gun.cost == 0 else str(gun.cost) + " coins"
	_btn_buy.pressed.connect(_on_buy)
	_btn_equip.pressed.connect(_on_equip)
	_refresh()

func _refresh() -> void:
	var owned: bool = _stats.owns_gun(_gun.id)
	var is_equipped: bool = _stats.equipped_gun == _gun.id
	if owned:
		_price_label.text = "OWNED!"
		_price_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4, 1))
	else:
		_price_label.text = "FREE" if _gun.cost == 0 else str(_gun.cost) + " coins"
		_price_label.add_theme_color_override("font_color", Color(1, 0.78, 0.1, 1))
	_btn_buy.visible = not owned
	_btn_buy.disabled = _stats.coins < _gun.cost
	_btn_equip.visible = owned
	_btn_equip.disabled = is_equipped
	_btn_equip.text = "EQUIPPED" if is_equipped else "EQUIP"

func _on_buy() -> void:
	if _stats.buy_gun(_gun.id, _gun.cost):
		purchased.emit(_gun.id)
		_refresh()

func _on_equip() -> void:
	_stats.equip_gun(_gun.id)
	equipped.emit(_gun.id)
	_refresh()
