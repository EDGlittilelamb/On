# res://ui/card.gd
extends Control
class_name cumstonCard

signal clicked(card_data)

@onready var area: Area2D = $Area2D
@onready var img = $img   # Sprite2D 或 TextureRect 都行

var data  # CardData

func setup(d):
	data = d
	# 按你的 img 类型设置纹理
	if img is Sprite2D:
		img.texture = d.icon
	elif img is TextureRect:
		img.texture = d.icon

func _ready():
	area.input_event.connect(_on_input)

func _on_input(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("clicked", data)
		print("card clicked")
