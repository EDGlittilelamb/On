class_name MonsterCardsPile
extends Control

signal card_chosen(texture: Texture2D)

@export var monster_card_scene: PackedScene
@export var monster_textures: Array[Texture2D] = []
@export var min_cards: int = 3
@export var max_cards: int = 6

@onready var vbox: VBoxContainer = $ScrollContainer/VBoxContainer

func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_STOP

func init_random_cards() -> void:
	_clear_cards()

	if monster_textures.is_empty():
		push_warning("MonsterCardsPile: monster_textures 为空")
		return

	var count := randi_range(min_cards, max_cards)
	var pool := monster_textures.duplicate()
	pool.shuffle()

	for i in range(min(count, pool.size())):
		var c: MonsterCard = monster_card_scene.instantiate()
		c.monster_texture = pool[i]
		c.pressed.connect(_on_card_pressed)
		vbox.add_child(c)

func _on_card_pressed(card: MonsterCard) -> void:
	card_chosen.emit(card.monster_texture)

func _clear_cards() -> void:
	for child in vbox.get_children():
		child.queue_free()
func open() -> void:
	show()

func close() -> void:
	hide()
