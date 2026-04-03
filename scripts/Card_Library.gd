# res://autoload/CardLibrary.gd
extends Node
const CardDataScript = preload("res://scripts/Card_Data.gd")
var by_id: Dictionary = {} # StringName -> CardData
var cards: Array[CardData] = []

func add_card(id: StringName, icon: Texture2D, source_type: StringName) -> void:
	if id == StringName() or icon == null:
		return
	if by_id.has(id):
		return # 去重
	var d = CardDataScript.new()	
	d.id = id
	d.icon = icon
	d.source_type = source_type
	by_id[id] = d
	cards.append(d)

# 从 stats 推导一个稳定 id（优先 stats.id；否则用资源文件名）
func infer_id_from_stats(stats: Resource, prefix: StringName) -> StringName:
	if stats == null:
		return prefix
	var v = stats.get("id") # 如果没有这个字段会返回 null
	if v != null and String(v) != "":
		return StringName(String(v))
	if stats.resource_path != "":
		return StringName("%s_%s" % [String(prefix), stats.resource_path.get_file().get_basename()])
	return prefix
