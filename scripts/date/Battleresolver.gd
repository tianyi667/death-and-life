class_name BattleResolver
extends RefCounted

func resolve(p_card: String, e_card: String) -> Dictionary:
	# ==========================================
	# 优先级 1：死牌判定 (最高优先级，必须最先拦截)
	# ==========================================
	if p_card == "death":
		if e_card == "gun":
			return {'winner': 'draw', 'text': '你趁单枪打出死牌，安全落地！'}
		elif e_card == 'death':
			return {'winner': 'draw', 'text': '双出死'}
		else:
			return {'winner': 'enemy', 'text': '你误出了【死】牌，遭受反噬！'}
			
	if e_card == "death":
		if p_card == "gun":
			return {'winner': 'draw', 'text': '敌人趁你单枪打出死牌，安全落地！'}
		elif p_card == 'death':
			return {'winner': 'draw', 'text': '双出死'}
		else:
			return {'winner': 'player', 'text': '敌人误出了【死】牌，遭受反噬！'}

	# ==========================================
	# 优先级 2：枪+生 王牌组合 (克制一切)
	# ==========================================
	if p_card == "gun+life" and e_card == "gun+life":
		return {'winner': 'draw', 'text': '双方同时打出王牌，同归于尽！'}
	if p_card == "gun+life":
		return {'winner': 'player', 'text': '你的【枪+生】克制一切！'}
	if e_card == "gun+life":
		return {'winner': 'enemy', 'text': '敌人的【枪+生】克制一切！'}

	# ==========================================
	# 优先级 3：绳 殊死反制 单枪
	# ==========================================
	if p_card == "rope" and e_card == "gun":
		return {'winner': 'player', 'text': '你的【绳】殊死反制了单枪！'}
	if e_card == "rope" and p_card == "gun":
		return {'winner': 'enemy', 'text': '敌人的【绳】反制了你的单枪！'}

	# ==========================================
	# 优先级 4：单枪强制平局 (遇到任何普通牌)
	# ==========================================
	if p_card == "gun" or e_card == "gun":
		return {'winner': 'draw', 'text': '单枪强制平局，无事发生。'}

	# ==========================================
	# 优先级 5：基础克制 (刀克绳石，石克绳)
	# ==========================================
	# 玩家出刀
	if p_card == "knife" and (e_card == "rope" or e_card == "stone"):
		return {'winner': 'player', 'text': '你的【刀】斩断了防御！'}
	# 敌人出刀
	if e_card == "knife" and (p_card == "rope" or p_card == "stone"):
		return {'winner': 'enemy', 'text': '敌人的【刀】斩断了你的防御！'}
	
	# 玩家出石
	if p_card == "stone" and e_card == "rope":
		return {'winner': 'player', 'text': '你的【石】砸断了【绳】！'}
	# 敌人出石
	if e_card == "stone" and p_card == "rope":
		return {'winner': 'enemy', 'text': '敌人的【石】砸断了你的【绳】！'}

	# ==========================================
	# 优先级 6：兜底 (同牌相撞或不相克)
	# ==========================================
	return {'winner': 'draw', 'text': '互相抵消，无事发生。'}
	
	
	
	
	
	
	
	
