extends Node2D

@onready var confirm = $Confirm
@onready var confirm_area = $Confirm/Area2D
@onready var fusionup = $FusionUp
@onready var fusionup_area = $FusionUp/Area2D
@onready var pile = $Pile
@export var card_scene: PackedScene
@onready var animation_player: AnimationPlayer = $AnimationPlayer
var selected: Array = []
@onready var left_slot: Sprite2D = $OrbitL/LeftSlot
@onready var right_slot: Sprite2D = $OrbitR/RightSlot
var original_tex = null
var _is_fusing = false
func _ready():
	original_tex = get_parent().get_node("Sprite2D").texture
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
	print(d.icon)
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
		_get_fusion_result_texture(selected[0], selected[1],
		func(result_tex:Texture2D):
			await play_fusion_animation(result_tex)
			)
		hide_all()
		

# 你要的函数：接收 a 和 b，用它们的 icon 生成合体纹理，异步等待返回
func _get_fusion_result_texture(a, b,callback:Callable) -> Texture2D:
	# 1. 获取两张输入图片
	var tex_a: CompressedTexture2D = a.icon
	var tex_b: CompressedTexture2D = b.icon

	# 2. 创建异步等待器（原生Godot，无额外文件）
	var state = {
		done = false,
		texture = null
	}
	var ai_manager := get_tree().root.find_child("AIManager", true, false)
	# 3. 调用AI多图融合
	var images: Array[Texture2D] = [tex_a, tex_b,original_tex]
	ai_manager.generate_fusion_multiple_images(
	images,
	"pixel art character sprite, in the exact same art style as the two reference characters, front-facing, top-down view, 16x32 pixel resolution, white background, clean outline. Create a new original character that **maximally retains and naturally merges all core visual features, color palettes, line weights, and shading styles** from both reference characters. Automatically identify and preserve all key traits from each reference: including but not limited to hairstyle, facial features, clothing, accessories, body proportions, and color scheme. Ensure the new character has a cohesive, unified design that clearly inherits the identity of both source characters, with no distortion, missing features, or style deviation. Strictly maintain the original pixel art aesthetic, resolution, and visual consistency of the reference characters.",
	"",
	0.75,
	"1024x1024",
	func(res: Texture2D):
		res = make_texture_white_transparent(res)
		if callback:
			callback.call(res)
)

	# 4. 等待AI返回（关键）
	await until(state.done)

	# 5. 返回最终纹理
	return state.result_tex
	
# 通用等待工具，放脚本最下面即可
func until(condition: bool) -> void:
	while not condition:
		await get_tree().process_frame
func play_fusion_animation(result_texture: Texture2D) -> void:
	left_slot.visible = true
	right_slot.visible = true
	animation_player.play("fusion")
	await animation_player.animation_finished

	# 合体完成
	left_slot.visible = false
	right_slot.visible = false
	_apply_to_player(result_texture)

func _apply_to_player(tex: Texture2D) -> void:
	_is_fusing = true
	var player := get_parent()
	var sprite := player.get_node_or_null("Sprite2D") as Sprite2D
	sprite.scale = Vector2(16.0/2048,16.0/2048)
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

func make_texture_white_transparent(tex: Texture2D) -> Texture2D:
	if not tex:
		return null

	var img := tex.get_image()
	img.convert(Image.FORMAT_RGBA8)

	# 遍历所有像素，把白色变成透明
	for x in img.get_width():
		for y in img.get_height():
			var color = img.get_pixel(x, y)
			if color.r > 0.95 and color.g > 0.95 and color.b > 0.95:
				img.set_pixel(x, y, Color(1,1,1,0))

	return ImageTexture.create_from_image(img)
