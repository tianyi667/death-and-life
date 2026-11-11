class_name EnemyAI
extends RefCounted

# ==========================================
# 敌人 AI：随机从自己的手牌里抽一张打出
# ==========================================

# 基础版：纯随机出牌
func choose_card(hand: Array) -> String:
	if hand.is_empty():
		return ""
	return hand.pick_random()

# 预留接口：以后要做"确定性倾向表"时，只改这里，
# 把 hand / pool / 死牌倒计时 / 比分 都传进来即可
func choose_with_state(hand: Array, pool: Array, death_timer: int, score: Dictionary) -> String:
	# TODO: 未来按敌人类型写倾向规则（保守/激进/诈唬）
	return choose_card(hand)
