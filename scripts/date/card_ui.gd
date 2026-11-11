extends TextureButton

# 卡牌被点击时用信号通知大管家，避免用 get_parent() 去猜父节点
signal card_selected(card_node)

# 抓取文字节点（解决空值报错）
@onready var text_label = $TextLabel 

var card_name: String = ""
var is_selected = false

# 扇形排布：由大管家写入的“基准位置/角度”，悬停和选中都基于它做位移
var base_position = Vector2.ZERO
var base_rotation = 0.0
const HOVER_LIFT = 46.0   # 悬停时上浮的高度
const HOVER_SCALE = 1.12

# 英文 key → 中文显示名
const CARD_DISPLAY = {
	"rope": "绳",
	"stone": "石",
	"knife": "刀",
	"gun": "枪",
	"life": "生",
	"death": "死"
}

# 卡牌路径字典（注意统一使用 death）
var image_dict = {
	"death": preload("res://art/dead.png"),
	"gun": preload("res://art/gun.png"),
	"knife": preload("res://art/knife.png"),
	"life": preload("res://art/life.png"),
	"rope": preload("res://art/rope.png"),
	"stone": preload("res://art/stone.png")
}

func display_name(name_str: String) -> String:
	return CARD_DISPLAY.get(name_str, name_str)

func _ready():
	_update_pivot()

# 旋转/缩放的支点放在“底部中心”，这样扇形展开才自然
func _update_pivot():
	var s = size
	if s.x <= 0.0:
		s = custom_minimum_size
	if s.x <= 0.0:
		s = Vector2(120, 160)
	pivot_offset = Vector2(s.x * 0.5, s.y)

# 兼容“还没加入场景树就调用 setup”的情况：
# 此时 @onready 的 text_label 还没初始化，手动取一次节点。
func _get_label() -> Label:
	if text_label == null:
		text_label = get_node_or_null("TextLabel")
	return text_label

# 由大管家调用：设置这张牌在扇形里的基准位置与角度
func set_layout(pos: Vector2, rot: float):
	base_position = pos
	base_rotation = rot
	_update_pivot()
	position = pos
	rotation = rot
	scale = Vector2(1.0, 1.0)

func setup(name_str: String):
	card_name = name_str
	var label = _get_label()
	if label != null:
		label.text = display_name(name_str)
	if image_dict.has(name_str): 
		texture_normal = image_dict[name_str] # 设置对应纹理
	if name_str == "death" and label != null: 
		label.modulate = Color(1, 0.2, 0.2) # 死牌变红

# ----- 悬停 / 选中时的上浮动画 -----
func _raise():
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(self, "position", base_position - Vector2(0, HOVER_LIFT), 0.1)
	t.tween_property(self, "scale", Vector2(HOVER_SCALE, HOVER_SCALE), 0.1)

func _drop():
	var t = create_tween()
	t.set_parallel(true)
	t.tween_property(self, "position", base_position, 0.1)
	t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

# 供大管家在重绘后恢复选中状态（不触发信号）
func select():
	is_selected = true
	modulate = Color(1, 1, 0.5)
	_raise()

func deselect():
	is_selected = false
	modulate = Color(1, 1, 1)
	_drop()

func _on_mouse_entered():
	if not is_selected:
		_raise()

func _on_mouse_exited():
	if not is_selected:
		_drop()

func _on_pressed():
	is_selected = not is_selected
	if is_selected:
		modulate = Color(1, 1, 0.5)
		_raise()
	else:
		modulate = Color(1, 1, 1)
		_drop()
	card_selected.emit(self)
