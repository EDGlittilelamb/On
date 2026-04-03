class_name Battle
extends Node2D

@export var battle_stats: BattleStats
@export var char_stats: CharacterStats
@export var music: AudioStream
@export var relics: RelicHandler

@onready var battle_ui: BattleUI = $BattleUI
@onready var player_handler: PlayerHandler = $PlayerHandler
@onready var enemy_handler: EnemyHandler = $EnemyHandler
@onready var player: Player = $Player


func _ready() -> void:
	enemy_handler.child_order_changed.connect(_on_enemies_child_order_changed)
	Events.enemy_turn_ended.connect(_on_enemy_turn_ended)
	
	Events.player_turn_ended.connect(player_handler.end_turn)
	Events.player_hand_discarded.connect(enemy_handler.start_turn)
	Events.player_died.connect(_on_player_died)
	Events.enemy_died.connect(_on_enemy_died) # ✅新增
	
func _on_enemy_died(enemy: Node) -> void:
	# enemy 预计就是 Enemy.gd 的实例
	if enemy == null:
		return

	# Enemy 脚本里通常有 stats 和 Sprite2D.texture
	var stats = enemy.get("stats")  # 安全读取
	if stats == null:
		return

	# icon 优先用 stats.art（与你现在的赋值一致）
	var icon: Texture2D = stats.get("art")
	if icon == null:
		# 兜底：从 Sprite2D 拿
		var sprite := enemy.get_node_or_null("Sprite2D") as Sprite2D
		if sprite and sprite.texture:
			icon = sprite.texture
	if icon == null:
		return

	# 生成一个稳定的 id（建议敌人类型级别，而不是实例级别）
	var card_id = CardLibrary.infer_id_from_stats(stats, &"enemy")
	CardLibrary.add_card(card_id, icon, &"enemy")

func start_battle() -> void:
	get_tree().paused = false
	MusicPlayer.play(music, true)
	battle_ui.char_stats = char_stats
	player.stats = char_stats
	player_handler.relics = relics
	enemy_handler.setup_enemies(battle_stats)
	enemy_handler.reset_enemy_actions()
	
	relics.relics_activated.connect(_on_relics_activated)
	relics.activate_relics_by_type(Relic.Type.START_OF_COMBAT)
	register_player_card()

	player_handler.relics = relics
	enemy_handler.setup_enemies(battle_stats)
	enemy_handler.reset_enemy_actions()

	relics.activate_relics_by_type(Relic.Type.START_OF_COMBAT)
func register_player_card():

	if player == null:
		return

	var sprite := player.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return

	var texture := sprite.texture
	if texture == null:
		return

	# 玩家卡的ID
	var id := "player_base"

	CardLibrary.add_card(id, texture, "player")
func _on_enemies_child_order_changed() -> void:
	if enemy_handler.get_child_count() == 0 and is_instance_valid(relics):
		relics.activate_relics_by_type(Relic.Type.END_OF_COMBAT)


func _on_enemy_turn_ended() -> void:
	player_handler.start_turn()
	enemy_handler.reset_enemy_actions()


func _on_player_died() -> void:
	Events.battle_over_screen_requested.emit("Game Over!", BattleOverPanel.Type.LOSE)
	SaveGame.delete_data()


func _on_relics_activated(type: Relic.Type) -> void:
	match type:
		Relic.Type.START_OF_COMBAT:
			player_handler.start_battle(char_stats)
			battle_ui.initialize_card_pile_ui()
		Relic.Type.END_OF_COMBAT:
			Events.battle_over_screen_requested.emit("Victorious!", BattleOverPanel.Type.WIN)
