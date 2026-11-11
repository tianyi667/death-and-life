extends TextureButton

signal committed(card)

const CARD_DISPLAY = {
	"rope": "绳", "stone": "石", "knife": "刀",
	"gun": "枪", "life": "生", "death": "死"
}

# 手牌尺寸 与 上场后的小尺寸（拖进中间平面时也会缩小到这个尺寸）
const PLAY_SIZE := Vector2(56, 75)

var image_dict = {
	"death": preload("res://art/pixel/card_death.png"),
	"gun": preload("res://art/pixel/card_gun.png"),
	"knife": preload("res://art/pixel/card_knife.png"),
	"life": preload("res://art/pixel/card_life.png"),
	"rope": preload("res://art/pixel/card_rope.png"),
	"stone": preload("res://art/pixel/card_stone.png"),
}
var back_tex = preload("res://art/pixel/card_back.png")

var card_name := ""
var is_face_down := false
var is_dragging := false
var in_slot := false
var base_pos := Vector2.ZERO
var base_rot := 0.0
var home_size := Vector2(72, 96)

var drag_root: Control = null
var release_rect := Rect2()
var drag_threshold := 24.0
var hand_parent: Node = null
var _press_start := Vector2.ZERO
var _pressed_here := false

@onready var text_label = $TextLabel

func _ready():
	home_size = size
	pivot_offset = Vector2(size.x * 0.5, size.y)   # 扇形：底部中心支点

func setup(n: String):
	card_name = n
	show_front()

func configure(root: Control, rect: Rect2, threshold: float):
	drag_root = root
	release_rect = rect
	drag_threshold = threshold
	hand_parent = get_parent()

func set_layout(pos: Vector2, rot: float):
	base_pos = pos
	base_rot = rot
	position = pos
	rotation = rot

# 改变卡牌显示尺寸（上场缩小时用）
func resize_card(s: Vector2):
	custom_minimum_size = s
	size = s

func set_slot_mode(on: bool):
	in_slot = on
	disabled = true
	is_dragging = false
	pivot_offset = Vector2(size.x * 0.5, size.y * 0.5)   # 槽里翻面用中心支点
	rotation = 0.0
	scale = Vector2.ONE

func show_front():
	is_face_down = false
	texture_normal = image_dict.get(card_name)
	if text_label != null:
		text_label.text = CARD_DISPLAY.get(card_name, card_name)
		text_label.visible = true

func show_back():
	is_face_down = true
	texture_normal = back_tex
	if text_label != null:
		text_label.visible = false

# 翻面动画：scale.x 1→0→1，中间换面
func flip_to_front():
	var t = create_tween()
	t.tween_property(self, "scale", Vector2(0.0, 1.0), 0.1)
	await t.finished
	show_front()
	var t2 = create_tween()
	t2.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	await t2.finished

# ---------- 拖拽 ----------
func _gui_input(event):
	if disabled or in_slot:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_start = get_global_mouse_position()
			_pressed_here = true
		else:
			_pressed_here = false

func _process(_delta):
	if is_dragging:
		var center = get_global_mouse_position()
		# 拖进中间平面 → 缩小到上场尺寸；拖出 → 恢复手牌尺寸
		if release_rect.has_point(center):
			if size != PLAY_SIZE:
				resize_card(PLAY_SIZE)
		else:
			if size != home_size:
				resize_card(home_size)
		global_position = center - size * 0.5
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_end_drag(center)
	elif _pressed_here and not disabled and not in_slot \
			and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if (get_global_mouse_position() - _press_start).length() > drag_threshold:
			_begin_drag()

func _begin_drag():
	is_dragging = true
	hand_parent = get_parent()
	reparent(drag_root, true)
	z_index = 100
	var t = create_tween()
	t.tween_property(self, "scale", Vector2(1.08, 1.08), 0.1)

func _end_drag(mouse: Vector2):
	if not is_dragging:
		return
	is_dragging = false
	z_index = 0
	_pressed_here = false
	if release_rect.has_point(mouse):
		committed.emit(self)   # 松手在中间平面 → 交给 battle_flow
	else:
		# 取消：恢复尺寸，飞回手牌原位
		resize_card(home_size)
		reparent(hand_parent, true)
		pivot_offset = Vector2(size.x * 0.5, size.y)
		var t = create_tween()
		t.set_parallel(true)
		t.tween_property(self, "position", base_pos, 0.15)
		t.tween_property(self, "rotation", base_rot, 0.15)
		t.tween_property(self, "scale", Vector2.ONE, 0.15)

func _on_mouse_entered():
	if not is_dragging and not in_slot and not disabled:
		var t = create_tween()
		t.tween_property(self, "scale", Vector2(1.08, 1.08), 0.1)

func _on_mouse_exited():
	if not is_dragging and not in_slot and not disabled:
		var t = create_tween()
		t.tween_property(self, "scale", Vector2.ONE, 0.1)
