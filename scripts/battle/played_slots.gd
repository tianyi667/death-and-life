extends Control

const CardScene = preload("res://scenes/card_view.tscn")
const PLAY_SIZE := Vector2(56, 75)

# 槽位节点在 battle_scene.tscn 里（可直接拖位置）
@onready var player_slot: Control = $PlayerSlot
@onready var enemy_slot: Control = $EnemySlot

var player_card = null
var enemy_card = null
var enemy_revealed := false

# 玩家交出的牌：缩小后飞到我方角色头顶，正面朝上
func commit_player_card(card):
	player_card = card
	card.reparent(player_slot, true)
	card.resize_card(PLAY_SIZE)
	var t = create_tween()
	t.tween_property(card, "position", Vector2.ZERO, 0.18)
	card.set_slot_mode(true)
	card.show_front()

# 敌方回合开始：头顶放一张小尺寸盖牌
func place_enemy_face_down(card_name: String):
	enemy_revealed = false
	enemy_card = CardScene.instantiate()
	enemy_slot.add_child(enemy_card)
	enemy_card.setup(card_name)
	enemy_card.resize_card(PLAY_SIZE)
	enemy_card.set_slot_mode(true)
	enemy_card.show_back()

# 窥见 / 回合结束：翻开
func reveal_enemy():
	if enemy_card != null and not enemy_revealed:
		enemy_revealed = true
		enemy_card.flip_to_front()

func clear():
	if player_card != null:
		player_card.queue_free()
		player_card = null
	if enemy_card != null:
		enemy_card.queue_free()
		enemy_card = null
	enemy_revealed = false
