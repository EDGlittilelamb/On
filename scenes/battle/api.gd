extends Node

@onready var http := HTTPRequest.new()

# ⚠️生产环境不要把 Key 写进客户端（会被反编译/抓包拿走）
const ARK_API_KEY := "sk-xxxxxxxxxxxxxxxxxxxxxxxx"

# 方舟数据面 Base URL（官方）
const BASE_URL := "https://ark.cn-beijing.volces.com/api/v3" # :contentReference[oaicite:1]{index=1}
const ENDPOINT := "/images/generations"                      # 常见图片生成路径

# 选一个你已开通的模型（这里用示例名；请替换成你控制台里的 Seedream 5.0 lite Model ID）
const MODEL_ID := "doubao-seedream-5-0-lite-xxxxx"

# 输入图片路径：res://(只读资源) 或 user://(可写目录)
var INPUT_IMAGE_PATH := "user://input.jpg"
var OUTPUT_IMAGE_PATH := "user://out.png"

func _ready() -> void:
	add_child(http)
	http.request_completed.connect(_on_request_completed)

	# 发起一次请求示例
	generate_single_to_single(
		INPUT_IMAGE_PATH,
		"把背景换成演唱会现场，保持主体不变，写实风格"
	)

func generate_single_to_single(image_path: String, prompt: String) -> void:
	var img_b64 := file_to_base64(image_path)
	if img_b64.is_empty():
		return

	# 有些接口支持带/不带 dataURL 前缀。若你那边要求前缀就打开下一行：
	# img_b64 = "data:image/jpeg;base64," + img_b64

	var body := {
		"model": MODEL_ID,
		"prompt": prompt,

		# 单图输入：直接传 Base64 字符串
		"image": img_b64,

		# 强制单图（如果你的文档里参数名不同，按文档调整）
		"force_single": true,

		# 让服务端直接回 base64，方便你在客户端落盘/显示
		"response_format": "b64_json",

		# 你也可以按需加 size/width/height/seed/watermark/scale 等参数
		# "size": "2K",
		# "seed": -1,
		# "watermark": false,
	}

	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % ARK_API_KEY, # :contentReference[oaicite:2]{index=2}
	])

	var url := BASE_URL + ENDPOINT
	var err := http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		push_error("HTTPRequest.request failed: %s" % str(err))

func file_to_base64(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Cannot open file: " + path)
		return ""
	var bytes := f.get_buffer(f.get_length())
	return Marshalls.raw_to_base64(bytes)

func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var text := body.get_string_from_utf8()

	if response_code < 200 or response_code >= 300:
		push_error("HTTP %d: %s" % [response_code, text])
		return

	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid JSON: " + text)
		return

	# 典型返回结构：{ data: [ { b64_json: "...", url: "..." } ] }
	if not parsed.has("data") or not (parsed["data"] is Array) or parsed["data"].is_empty():
		push_error("No data in response: " + text)
		return

	var item = parsed["data"][0]
	if item is Dictionary and item.has("b64_json") and typeof(item["b64_json"]) == TYPE_STRING:
		var out_bytes := Marshalls.base64_to_raw(item["b64_json"])
		save_bytes(OUTPUT_IMAGE_PATH, out_bytes)
		print("Saved output image to: ", OUTPUT_IMAGE_PATH)

		# 可选：直接加载显示（根据实际格式 png/jpg 选择加载方式）
		# var img := Image.new()
		# var ok := img.load_png_from_buffer(out_bytes)  # 如果输出是 PNG
		# if ok == OK:
		#     var tex := ImageTexture.create_from_image(img)
		#     $Sprite2D.texture = tex
	else:
		# 如果你把 response_format 设为 url，就在这里读取 item["url"]
		push_error("No b64_json in response: " + text)

func save_bytes(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Cannot write file: " + path)
		return
	f.store_buffer(bytes)
	f.flush()
	f.close()
