本游戏的特色为融合系统，灵感来源为《欧布奥特曼》里面的奥特融合。

当玩家击败敌人时，会获得敌人的卡牌，在战斗中，可以利用敌人卡牌强化自己，并调用 img2img 模型更新玩家角色外观。融合后的玩家角色外观会保留敌人和玩家角色的特征。
## 融合系统拆解
### 1. 全局函数 Card_Library

生成 `cards` 数组，保留已经击败的敌人的 texture。

```
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

func infer_id_from_stats(stats: Resource, prefix: StringName) -> StringName:
    if stats == null:
        return prefix
    var v = stats.get("id")
    if v != null and String(v) != "":
        return StringName(String(v))
    if stats.resource_path != "":
        return StringName("%s_%s" % [String(prefix), stats.resource_path.get_file().get_basename()])
    return prefix
```
### 2. UI 设计
节点 Fusion_UI 挂载到 Player 节点上。交互逻辑：

点击 Player 节点 → 显示 Fusion_UI 上的 FusionUp 子节点

再次点击 FusionUp 节点 → 显示 cards 数组里已击败敌人对应的 CustomCard 资源

点击敌人的 CustomCard 资源 → 卡片显示在 Player 两侧

融合条件：必须且仅能选择两张敌人卡牌，才能触发融合

FusionUI 结构如下：

```
Fusion_UI
├─ OrbitL
│  └─ LeftSlot
├─ OrbitR
│  └─ RightSlot
├─ Confirm
│  └─ Area2D
│     └─ CollisionShape2D
├─ Pile
├─ FusionUp
│  └─ Area2D
│     └─ CollisionShape2D
└─ AnimationPlayer
```
Player 结构如下：

```
Player
├─ Sprite2D
├─ StatsUI
├─ StatusHandler
├─ ModifierHandler
│  ├─ DamageDealtModifie
│  ├─ DamageTakenModifi
│  └─ CardCostModifier
├─ Area2D
│  └─ CollisionShape2D
└─ Fusion_UI
```
###3. HTTP 请求

本次使用的 img2img 模型为 seedream5.0 lite。融合时需要传入三张图片：两张敌人原画 + 玩家角色原画。

**⚠️ 注意：该模型要求图片必须为 base64 格式。**
实现步骤：

*1. 将 Texture2D 转化为 base64 格式：*
```
var base64_array: Array[String] = []
for tex in input_textures:
    var b64 = texture_to_base64(tex)
    if b64:
        base64_array.append(b64)
设置 headers 和 payload：

gdscript
var headers = [
    "Content-Type: application/json",
    "Authorization: Bearer " + api_key
]
var payload = {
    "model": MODEL_NAME,
    "prompt": prompt,
    "negative_prompt": negative_prompt,
    "image_urls": base64_array,  # 注意：是 image_urls，不是 image
    "mode": "fusion",
    "strength": strength,
    "response_format": "b64_json"   # 必须为 b64_json
}
```
*2.将返回的 base64 转化为 jpg：*
```
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
```
*3.由于生成的图片背景是全白，最后需要调整透明度:*
```
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
```


