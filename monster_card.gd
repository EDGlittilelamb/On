class_name MonsterCard
extends Control

signal pressed(card: MonsterCard)

@export var monster_texture: Texture2D
@onready var img: Sprite2D = $Sprite2D
@onready var area: Area2D = $Area2D

func _ready() -> void:
	img.texture = monster_texture
	area.input_event.connect(_on_area_input)

func _on_area_input(viewport: Viewport, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(self)
