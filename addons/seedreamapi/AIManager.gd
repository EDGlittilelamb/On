extends Node
class_name AIManager

@export var api_key: String

# ✅ 绝对正确、官方可用配置
const API_URL = "https://ark.cn-beijing.volces.com/api/v3/images/generations"
const MODEL_NAME = "doubao-seedream-5-0-260128"

@onready var http_request: HTTPRequest = $HTTPRequest

var pending_requests: Dictionary = {}
var request_counter: int = 0

func _ready():
	http_request.request_completed.connect(_on_http_request_request_completed)

# 工具：Texture2D → Base64
func texture_to_base64(tex: Texture2D) -> String:
	if not tex:
		return ""
	var img = tex.get_image()
	var buffer = img.save_png_to_buffer()
	return Marshalls.raw_to_base64(buffer)

# 【修复版】Seedream 5.0 正确 多图融合 / 图片混合写法
func generate_fusion_multiple_images(
	input_textures: Array[Texture2D],
	prompt: String,
	negative_prompt: String = "",
	strength: float = 0.7,
	size: String = "1024x1024",
	callback: Callable = Callable()
) -> void:
	if input_textures.size() < 2:
		print("至少需要2张图片")
		return

	# 关键：Seedream 5.0 融合用 image_urls 数组!!!
	var base64_array: Array[String] = []
	print("begin")
	for tex in input_textures:
		var b64 = texture_to_base64(tex)
		if b64:
			base64_array.append(b64)

	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key
	]

	var payload = {
		"model": MODEL_NAME,
		"prompt": prompt,
		"negative_prompt": negative_prompt,
		"image_urls": base64_array,  # 不是 image！！是 image_urls！！
		"mode": "fusion",
		"strength": strength,
		"response_format": "b64_json"
	}

	request_counter += 1
	var request_id = "req_" + str(request_counter)
	pending_requests[request_id] = callback

	if http_request:
		var err = http_request.request(
			API_URL,
			headers,
			HTTPClient.METHOD_POST,
			JSON.stringify(payload)
	)
	pass
func _on_http_request_request_completed(
	result, response_code, headers, body: PackedByteArray
) -> void:
	print("http begin")
	var callback: Callable = Callable()
	
	if pending_requests.size() > 0:
		var key = pending_requests.keys()[0]
		callback = pending_requests[key]
		pending_requests.erase(key)

	if result != HTTPRequest.RESULT_SUCCESS || response_code != 200:
		print("API 请求错误: ", response_code)
		print(body.get_string_from_utf8())
		return

	var json = JSON.parse_string(body.get_string_from_utf8())
	if not json or not json.has("data"):
		print("返回格式错误")
		return
	var base64_image = json.data[0].b64_json
	var bytes = Marshalls.base64_to_raw(base64_image)
	
	var img = Image.new()
	if img.load_jpg_from_buffer(bytes) == OK:
	
		var final_texture = ImageTexture.create_from_image(img)
		print()
		callback.call(final_texture)
	else:
		print("图片加载失败")
