extends Control

signal card_committed(card)

const CardScene = preload("res://scenes/card_view.tscn")
const CARD_W := 72.0
const CARD_H := 96.0
const MAX_FAN_DEG := 10.0
const HAND_ARC := 4.0

var cards: Array = []
var drag_root: Control = null
var release_rect := Rect2()

func setup(root: Control, rect: Rect2):
	drag_root = root
	release_rect = rect

func refresh(hand: Array):
	for c in cards:
		if is_instance_valid(c) and c.get_parent() == self:
			c.queue_free()
	cards.clear()
	for n in hand:
		var c = CardScene.instantiate()
		add_child(c)
		c.setup(n)
		c.configure(drag_root, release_rect, 24.0)
		c.committed.connect(_on_committed)
		cards.append(c)
	_layout()

func _on_committed(card):
	card_committed.emit(card)

func set_interactive(on: bool):
	for c in cards:
		if is_instance_valid(c):
			c.disabled = not on

# 扇形排布：中间高、两边低、向外旋转（杀戮尖塔式）
func _layout():
	var n = cards.size()
	if n == 0:
		return
	var aw = size.x if size.x > 1.0 else 520.0
	var center_x = aw * 0.5
	var center_i = (n - 1) * 0.5
	var spacing = clampf(aw / (n + 1.0), 44.0, 78.0)
	var base_y = maxf(size.y - CARD_H - 4.0, -40.0)
	var step = 6.0
	if center_i > 0.0:
		step = min(MAX_FAN_DEG / center_i, 6.0)
	for i in range(n):
		var d = i - center_i
		var x = center_x + d * spacing - CARD_W * 0.5
		var y = base_y + absf(d) * HAND_ARC + d * d * 1.0
		cards[i].set_layout(Vector2(x, y), deg_to_rad(d * step))
