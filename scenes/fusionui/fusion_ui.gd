extends Node2D

@onready var confirm = $Confirm
@onready var confirm_area = $Confirm/Area2D

@onready var fusionup = $FusionUp
@onready var fusionup_area = $FusionUp/Area2D

@onready var pile = $Pile

@export var card_scene: PackedScene

var selected: Array = []
@onready var orbit_l: Node2D = $OrbitL
@onready var orbit_r: Node2D = $OrbitR
@onready var left_slot: Sprite2D = $OrbitL/LeftSlot
@onready var right_slot: Sprite2D = $OrbitR/RightSlot

var _is_fusing = false
var _radius := 120.0
var _angle := 0.0

func _set_orbit(angle: float, radius: float) -> void:
	_angle = angle
	_radius = radius

	# 让两张卡在同一个中心绕圈，但相位相反
	left_slot.position = Vector2(-radius, 0).rotated(angle)
	right_slot.position = Vector2(radius, 0).rotated(-angle)
func _ready():
	# 默认不显示
	hide_all()

	confirm_area.input_event.connect(_on_confirm_clicked)
	fusionup_area.input_event.connect(_on_fusion_clicked)

func hide_all():
	visible = false
	confirm.visible = false
	fusionup.visible = false
	pile.visible = false
	left_slot.visible = false
	right_slot.visible = false
	selected.clear()

func show_confirm_only():
	visible = true
	confirm.visible = true
	fusionup.visible = false
	pile.visible = false
	left_slot.visible = false
	right_slot.visible = false
	selected.clear()

func show_select_panel():
	visible = true
	confirm.visible = false
	fusionup.visible = true
	pile.visible = true
	# 左右槽位先不强制显示，等选中再显示
	spawn_cards()

func _on_confirm_clicked(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		show_select_panel()

func spawn_cards():
	for c in pile.get_children():
		c.queue_free()

	for d in CardLibrary.cards:
		var card = card_scene.instantiate()
		pile.add_child(card)
		card.setup(d)
		card.clicked.connect(_on_card_clicked)

func _on_card_clicked(d):

	var idx := selected.find(d)
	if idx != -1:
		selected.remove_at(idx)
		_refresh_slots()
		return

	# 2) 如果还没满两张：直接加入
	if selected.size() < 2:
		selected.append(d)
		_refresh_slots()
		return

	# 3) 如果已满两张：点第三张 → 挤掉最早选的那张（FIFO）
	selected.remove_at(0)
	selected.append(d)
	_refresh_slots()

func _on_fusion_clicked(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_fusing:
			return
		if selected.size() != 2:
			return

		# 这里你先算出融合结果（Texture2D）
		var result_texture: Texture2D = _get_fusion_result_texture(selected[0], selected[1])
		await play_fusion_animation(result_texture)
func _get_fusion_result_texture(a, b) -> Texture2D:
	# 临时：直接用 a 的图，之后你再接你的配方/字典
	return a.icon
func play_fusion_animation(result_texture: Texture2D) -> void:
	_is_fusing = true

	# 确保左右槽位可见
	left_slot.visible = true
	right_slot.visible = true

	# 初始化轨道（从当前半径开始）
	_set_orbit(0.0, 120.0)

	# 旋转 + 收缩（1秒）
	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE)
	t.set_ease(Tween.EASE_IN_OUT)

	# 用 tween_method 驱动我们的 _set_orbit(angle, radius)
	# angle: 0 -> 2.5圈 (2π*2.5)，radius: 120 -> 0
	var start_angle := 0.0
	var end_angle := TAU * 2.5
	var start_r := 120.0
	var end_r := 0.0

	t.tween_method(func(v):
		# v 从 0->1
		var a = lerp(start_angle, end_angle, v)
		var r = lerp(start_r, end_r, v)
		_set_orbit(a, r)
	, 0.0, 1.0, 1.0)

	await t.finished

	# 动画结束：合体到角色
	left_slot.visible = false
	right_slot.visible = false

	_apply_to_player(result_texture)

	_is_fusing = false
func _apply_to_player(tex: Texture2D) -> void:
	var player := get_parent()
	var sprite := player.get_node_or_null("Sprite2D") as Sprite2D
	if sprite and tex:
		sprite.texture = tex
func _refresh_slots():
	# 左槽
	if selected.size() >= 1 and selected[0] != null:
		left_slot.texture = selected[0].icon
		left_slot.visible = true
	else:
		left_slot.visible = false

	# 右槽
	if selected.size() >= 2 and selected[1] != null:
		right_slot.texture = selected[1].icon
		right_slot.visible = true
	else:
		right_slot.visible = false
