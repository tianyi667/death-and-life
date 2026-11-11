extends Control

# ==========================================
# 📦 模块 1：节点引用（大管家需要控制的 UI 零件）
# ==========================================
@onready var enemy_hand_button = $TopArea/EnemyHandButton
@onready var enemy_played_label = $TopArea/EnemyPlayedLabel
@onready var result_label = $CenterArea
@onready var played_area = $PlayedArea        # 中央出牌区：敌我双方打出的牌

@onready var player_pool_button = $BottomArea/PlayerPoolButton 
@onready var hand_container = $BottomArea/HandContainer
@onready var confirm_button = $BottomArea/ConfirmButton
@onready var insight_button = $BottomArea/InsightButton

@onready var info_panel = $InfoPanel
@onready var info_detail_label = $InfoPanel/InfoDetailLabel
@onready var close_panel_button = $InfoPanel/ClosePanelButton
@onready var background_node =$Background
@export var card_scene: PackedScene 


# ==========================================
# 📊 模块 2：数据与状态变量
# ==========================================
var deck = []             # 玩家的当前牌库
var hand = []             # 玩家的当前手牌
var enemy_pool = []       # 敌人的当前牌库
var enemy_hand = []       # 敌人的当前手牌（完全不可见）

#  核心机制：记录双方这局游戏的“初始全量牌库”，用来做无限洗牌重置
var player_initial_deck = [] 
var enemy_initial_deck = []  

var resolver = BattleResolver.new() # 实例化裁判员
const EnemyAIScript = preload("res://scripts/date/EnemyAI.gd")
var enemy_ai = EnemyAIScript.new()  # 敌人 AI（随机从自己手牌出牌）

var selected_card_node = null # 玩家当前选中的卡牌节点
var selected_card_name = ""   # 玩家当前选中的卡牌名字
var enemy_current_card = ""   # 敌人本回合暗中选定的牌
var enemy_last_play = ""      # 敌人上一回合打出的牌（用于中央出牌区）
var player_last_play = ""     # 玩家上一回合打出的牌（用于中央出牌区）
var enemy_revealed_card = ""  # 本回合用窥见具象化出来的敌人那张牌

# 生命值：敌我各 3 点，扣血只能由【死】牌造成
var player_hp = 3
var enemy_hp = 3

var insight_count = 1         # 玩家剩余的窥见次数（上限 3）
const INSIGHT_MAX = 3
var death_timer = -1          # 玩家头顶的死牌倒计时（明牌）
var enemy_death_timer = -1    # 敌人头顶的死牌倒计时（暗牌，不可见）

# 代码生成的 UI
var result_panel: Panel       # 结算面板
var result_title: Label
var hp_label: Label           # 生命值显示
var enemy_reveal_area: HBoxContainer # 敌人手牌区（平时空白，窥见才具象化）

# 英文 key → 中文显示名（UI 文案用）
const CARD_DISPLAY = {
	"rope": "绳",
	"stone": "石",
	"knife": "刀",
	"gun": "枪",
	"life": "生",
	"death": "死"
}

func card_display(name_str: String) -> String:
	return CARD_DISPLAY.get(name_str, name_str)

# ==========================================
# 🚀 模块 3：初始化与开局发牌
# ==========================================
func _ready():
	# 绑定所有 UI 按钮的点击信号
	confirm_button.pressed.connect(_on_confirm_pressed)
	insight_button.pressed.connect(_on_insight_pressed)
	enemy_hand_button.pressed.connect(_on_enemy_hand_btn_pressed)
	player_pool_button.pressed.connect(_on_player_pool_btn_pressed)
	close_panel_button.pressed.connect(_on_close_panel_btn_pressed)
	info_panel.gui_input.connect(_on_info_panel_gui_input) # 点面板任意处也能关
	
	# 1. 向管家索要玩家牌库，并备份初始状态（用于以后洗牌）
	deck = GameManager.get_character_deck()
	player_initial_deck = deck.duplicate() 
	
	# 2. 加载关卡配置，并备份敌人初始牌库
	load_level_data(GameManager.current_level)
	enemy_initial_deck = enemy_pool.duplicate() 
	
	# 3. 洗乱双方的牌库
	deck.shuffle() 
	enemy_pool.shuffle()
	
	# 4. 游戏开局，双方各抽 3 张牌
	for i in range(3): 
		draw_card()
	
	# 5. 生成代码版 UI（生命条 / 敌人手牌区 / 结算面板）
	_build_hp_label()
	_build_reveal_area()
	_build_result_panel()
	
	# 6. 按钮文案
	enemy_hand_button.text = "查看敌方牌库"
	insight_button.text = "窥见 (" + str(insight_count) + ")"
	
	# 7. 渲染界面
	update_ui()

# 读取关卡数据（决定敌人的初始卡池）
func load_level_data(level_num: int):
	if level_num == 1: 
		background_node.texture=load("res://资源/shengsiju_dungeon_connected_clean_aigc_label (2).png")
		enemy_pool = ["stone", "stone", "rope", "rope", "knife", "knife", "stone"] 
	elif level_num == 2: 
		enemy_pool = ["gun", "life", "death", "death", "knife", "rope", "stone"]
	else: 
		enemy_pool = ["knife", "knife", "stone", "rope", "gun", "stone", "rope"]
		
		
# ==========================================
# ♻️ 模块 4：无限洗牌机制（核心逻辑）
# ==========================================
# 玩家洗牌：把没在手里的牌重新洗回牌库
func refresh_deck():
	var hand_counts = {}
	for card in hand: hand_counts[card] = hand_counts.get(card, 0) + 1
	
	var new_deck = []
	for card in player_initial_deck:
		if hand_counts.get(card, 0) > 0:
			hand_counts[card] -= 1 
		else:
			new_deck.append(card)
			
	deck = new_deck
	deck.shuffle()
	result_label.text = "你的牌库耗尽，重新洗牌！"

# 敌人洗牌：逻辑同上，为了公平，敌人也可以无限洗牌
func refresh_enemy_deck():
	var e_hand_counts = {}
	for card in enemy_hand: e_hand_counts[card] = e_hand_counts.get(card, 0) + 1
	
	var new_enemy_deck = []
	for card in enemy_initial_deck:
		if e_hand_counts.get(card, 0) > 0:
			e_hand_counts[card] -= 1 
		else:
			new_enemy_deck.append(card)
			
	enemy_pool = new_enemy_deck
	enemy_pool.shuffle()

# ==========================================
# 🃏 模块 5：抽牌逻辑
# ==========================================
func draw_card():
	# --- 玩家抽牌 ---
	if deck.size() == 0: refresh_deck()
	if deck.size() > 0:
		var new_card = deck.pop_back() 
		hand.append(new_card)
		# 抽到死牌 → 立刻激活 3 回合倒计时
		if new_card == "death" and death_timer == -1: death_timer = 3 
		
	# --- 敌人抽牌 ---
	if enemy_pool.size() == 0: refresh_enemy_deck()
	if enemy_pool.size() > 0:
		var e_card = enemy_pool.pop_back()
		enemy_hand.append(e_card)
		if e_card == "death" and enemy_death_timer == -1: enemy_death_timer = 3 

# ==========================================
# 🎨 模块 6：界面刷新（渲染 UI）
# ==========================================
func update_ui():
	# 1. 生命值
	_update_hp_label()
	
	# 2. 我方牌库按钮文字
	player_pool_button.text = "查看我方牌库 (" + str(deck.size()) + "张)"
	
	# 3. 顶部状态条：我方死牌倒计时 + 敌人上一手
	var lines := []
	if death_timer > 0:
		lines.append("我方死牌倒计时：" + str(death_timer) + " 回合")
	if enemy_last_play != "":
		lines.append("敌人打出：【" + card_display(enemy_last_play) + "】")
	
	if lines.is_empty():
		enemy_played_label.text = "无死牌威胁"
		enemy_played_label.modulate = Color(1, 1, 1)
	else:
		enemy_played_label.text = "\n".join(lines)
		enemy_played_label.modulate = Color(1, 0.4, 0.4) if death_timer > 0 else Color(1, 1, 1)
	
	# 4. 清空旧的手牌容器
	for child in hand_container.get_children():
		hand_container.remove_child(child)
		child.queue_free()
	
	# 5. 生成玩家的手牌实体
	var restored_node = null
	var hand_cards = []
	for card_name in hand:
		var new_card = card_scene.instantiate()
		hand_container.add_child(new_card)   # 必须先入树，@onready 才会生效
		new_card.setup(card_name)            # setup 里会挂上对应纹理
		new_card.card_selected.connect(on_card_clicked)
		hand_cards.append(new_card)
		if restored_node == null and selected_card_name != "" and card_name == selected_card_name:
			restored_node = new_card
	
	# 5.5 扇形排布（类似杀戮尖塔的手牌）
	_layout_hand(hand_cards)
	
	# 6. 恢复/清理选中状态（放到布局之后，才能基于基准位置抬高）
	selected_card_node = restored_node
	if restored_node != null:
		restored_node.select()
	else:
		selected_card_name = ""
		selected_card_node = null
	
	# 7. 敌人手牌区：平时完全空白；只有用过窥见，才具象化出那一张
	for child in enemy_reveal_area.get_children():
		enemy_reveal_area.remove_child(child)
		child.queue_free()
	if enemy_revealed_card != "":
		var hint = Label.new()
		hint.text = "窥见 · 敌人将出："
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hint.add_theme_font_size_override("font_size", 20)
		enemy_reveal_area.add_child(hint)
		var r_card = card_scene.instantiate()
		enemy_reveal_area.add_child(r_card)
		r_card.disabled = true
		r_card.setup(enemy_revealed_card)
	
	# 8. 中央出牌区：敌我双方上一回合打出的牌
	for child in played_area.get_children():
		played_area.remove_child(child)
		child.queue_free()
	if player_last_play != "":
		var p_card = card_scene.instantiate()
		played_area.add_child(p_card)
		p_card.disabled = true
		p_card.setup(player_last_play)
	if enemy_last_play != "":
		if player_last_play != "":
			var vs_label = Label.new()
			vs_label.text = "VS"
			vs_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			played_area.add_child(vs_label)
		var e_card = card_scene.instantiate()
		played_area.add_child(e_card)
		e_card.disabled = true
		e_card.setup(enemy_last_play)

# 扇形手牌布局：中间高、两边低、向外旋转
const CARD_W = 120.0
const CARD_H = 160.0
const HAND_BOTTOM_MARGIN = 46.0 # 手牌距离底部的留白（留给扇形下坠）
const HAND_ARC = 10.0           # 两边下坠的弧度
const MAX_FAN_DEG = 16.0        # 最外侧牌的最大旋转角

func _layout_hand(cards: Array):
	var n = cards.size()
	if n == 0:
		return
	
	var area_w = hand_container.size.x
	var area_h = hand_container.size.y
	if area_w <= 1.0:
		area_w = 760.0                       # 容器还没算好尺寸时的兜底
	if area_h <= 1.0:
		area_h = 280.0
	var center_x = area_w * 0.5
	var center_i = (n - 1) * 0.5
	# 手牌贴着容器底部摆放，扇形向上展开
	var base_y = maxf(area_h - CARD_H - HAND_BOTTOM_MARGIN, 16.0)
	# 牌越多越挤：允许重叠，但保证不会跑出容器太多
	var spacing = clampf(area_w / (n + 1.0), 60.0, 112.0)
	var step_rot = 6.0
	if center_i > 0.0:
		step_rot = min(MAX_FAN_DEG / center_i, 6.0)
	
	for i in range(n):
		var card = cards[i]
		var d = i - center_i
		var x = center_x + d * spacing - CARD_W * 0.5
		var y = base_y + absf(d) * HAND_ARC + d * d * 1.2
		var rot = deg_to_rad(d * step_rot)
		card.set_layout(Vector2(x, y), rot)

# ==========================================
# 🖱️ 模块 7：玩家操作响应
# ==========================================
# 点击卡牌（选中/取消选中）
func on_card_clicked(card_node):
	if selected_card_node == card_node:
		selected_card_name = ""
		selected_card_node = null
		result_label.text = "已取消选中"
		return 
		
	if selected_card_node != null and selected_card_node != card_node:
		selected_card_node.deselect()
		
	selected_card_node = card_node
	selected_card_name = card_node.card_name
	result_label.text = "选中了：【" + card_display(selected_card_name) + "】"

# 使用“窥见”技能：把敌人本回合要出的那一张，具象化到敌方手牌区
func _on_insight_pressed():
	if insight_count <= 0: return
	
	# 敌人暗中选定一张手牌（如果还没选的话）
	if enemy_current_card == "": enemy_current_card = enemy_ai.choose_card(enemy_hand)
	
	insight_count -= 1
	enemy_revealed_card = enemy_current_card   # 具象化的就是这一张
	insight_button.text = "窥见 (" + str(insight_count) + ")"
	result_label.text = "【窥见】敌人将打出：【" + card_display(enemy_current_card) + "】"
	update_ui()

# ==========================================
# ⚔️ 模块 8：回合结算（核心博弈点）
# ==========================================
func _on_confirm_pressed():
	if selected_card_name == "": return
	
	# 新回合开始：清掉上一回合的中央出牌区记录
	player_last_play = ""
	enemy_last_play = ""
	
	# 防呆：如果敌人手牌空了，强制给他洗牌抽牌，跳过这回合
	if enemy_hand.is_empty():
		refresh_enemy_deck()
		draw_card()
		return
	
	# 敌人 AI 从自己手牌里随机出牌
	if enemy_current_card == "": enemy_current_card = enemy_ai.choose_card(enemy_hand)
	enemy_last_play = enemy_current_card
	player_last_play = selected_card_name
	update_ui() 
	
	# 呼叫裁判员进行胜负判定
	var result = resolver.resolve(selected_card_name, enemy_current_card)
	result_label.text = result.text
	
	# --- 🌟 拼点失败惩罚：不扣血，改为「+1 窥见 + 被塞 1 张死牌」 ---
	if result.winner == "player":
		enemy_pool.append("death")
		result_label.text += "\n敌方牌库被塞入 1 张死牌！"
	elif result.winner == "enemy":
		deck.append("death")
		insight_count = mini(insight_count + 1, INSIGHT_MAX)
		insight_button.text = "窥见 (" + str(insight_count) + ")"
		result_label.text += "\n你输了拼点：+1 窥见，牌库被塞入 1 张死牌！"
	
	# --- 玩家死牌结算 ---
	if selected_card_name == "death":
		if result.winner == "player" or result.winner == "draw":
			# 撞敌人单枪 / 双方同出死牌 → 拆弹成功
			death_timer = -1
			result_label.text += "\n死牌安全落地，未扣血。"
		else:
			# 死牌被克制 → 扣 1 点生命，死牌销毁
			player_hp -= 1
			death_timer = -1
			result_label.text += "\n你误出了【死】牌，反噬扣 1 点生命！"
			if player_hp <= 0:
				result_label.text += "\n你的生命归零，被执念吞噬……"
				show_result(false)
				return
	elif death_timer > 0:
		# 手里捏着死牌没打 → 倒计时减 1
		death_timer -= 1
		if death_timer == 0:
			# 爆炸：扣 1 点生命，死牌销毁
			player_hp -= 1
			hand.erase("death")
			death_timer = -1
			result_label.text += "\n死牌爆发！扣 1 点生命，死牌销毁。"
			if hand.has("death"):
				death_timer = 3  # 手里还有死牌，重新开始倒计时
			if player_hp <= 0:
				result_label.text += "\n你的生命归零，被执念吞噬……"
				show_result(false)
				return
			
	# --- 🌟 敌人死牌结算（暗中进行） ---
	if enemy_current_card == "death":
		if result.winner == "enemy" or result.winner == "draw":
			enemy_death_timer = -1   # 敌人拆弹成功
		else:
			# 敌人误出死牌 → 扣 1 点生命
			enemy_hp -= 1
			enemy_death_timer = -1
			result_label.text += "\n敌人误出了【死】牌，反噬扣 1 点生命！"
			if enemy_hp <= 0:
				result_label.text += "\n敌人生命归零，亡魂消散！你赢了！"
				GameManager.finish_battle()
				show_result(true)
				return
	elif enemy_death_timer > 0:
		enemy_death_timer -= 1
		if enemy_death_timer == 0:
			# 敌人死牌暗中爆炸 → 扣 1 点生命
			enemy_hp -= 1
			enemy_hand.erase("death")
			enemy_death_timer = -1
			result_label.text += "\n敌人死牌爆发，扣除 1 点生命！"
			if enemy_hand.has("death"):
				enemy_death_timer = 3
			if enemy_hp <= 0:
				result_label.text += "\n敌人生命归零，亡魂消散！你赢了！"
				GameManager.finish_battle()	
				show_result(true)
				
				return
			
	# 消耗双方打出的牌
	hand.erase(selected_card_name)
	enemy_hand.erase(enemy_current_card)
	selected_card_name = ""
	enemy_current_card = ""
	selected_card_node = null
	enemy_revealed_card = ""   # 本回合窥见具象化结束
	
	draw_card() 
	update_ui()

# ==========================================
# 🏆 模块 8.5：胜负结算 + 代码生成的 UI
# ==========================================
func _build_hp_label():
	hp_label = Label.new()
	hp_label.anchor_left = 0.0
	hp_label.anchor_top = 0.0
	hp_label.anchor_right = 1.0
	hp_label.anchor_bottom = 0.0
	hp_label.offset_top = 6
	hp_label.offset_bottom = 46
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.add_theme_font_size_override("font_size", 26)
	add_child(hp_label)

func _update_hp_label():
	if hp_label != null:
		hp_label.text = "我方生命 %d    ｜    敌方生命 %d" % [player_hp, enemy_hp]

func _build_reveal_area():
	enemy_reveal_area = HBoxContainer.new()
	enemy_reveal_area.anchor_left = 0.0
	enemy_reveal_area.anchor_top = 0.0
	enemy_reveal_area.anchor_right = 0.55
	enemy_reveal_area.anchor_bottom = 1.0
	enemy_reveal_area.offset_left = 24
	enemy_reveal_area.offset_top = 52
	enemy_reveal_area.offset_right = 0
	enemy_reveal_area.offset_bottom = 0
	enemy_reveal_area.alignment = 1
	enemy_reveal_area.add_theme_constant_override("separation", 12)
	$TopArea.add_child(enemy_reveal_area)

func _build_result_panel():
	result_panel = Panel.new()
	result_panel.anchor_left = 0.3
	result_panel.anchor_top = 0.34
	result_panel.anchor_right = 0.7
	result_panel.anchor_bottom = 0.62
	result_panel.visible = false
	add_child(result_panel) # 最后添加 = 绘制在最上层

	var box = VBoxContainer.new()
	box.anchor_left = 0.0
	box.anchor_top = 0.0
	box.anchor_right = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = 24
	box.offset_top = 24
	box.offset_right = -24
	box.offset_bottom = -24
	box.add_theme_constant_override("separation", 16)
	result_panel.add_child(box)

	result_title = Label.new()
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_title.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(result_title)

	var restart_button = Button.new()
	restart_button.text = "再来一局"
	restart_button.pressed.connect(_on_restart_pressed)
	box.add_child(restart_button)

	var menu_button = Button.new()
	menu_button.text = "返回主界面"
	menu_button.pressed.connect(_on_menu_pressed)
	box.add_child(menu_button)

func _on_menu_pressed():
	get_tree().change_scene_to_file("res://ui/ui.tscn")

func show_result(won: bool):
	result_title.text = "你赢了！" if won else "你输了。"
	result_panel.visible = true
	confirm_button.disabled = true
	insight_button.disabled = true

func _on_restart_pressed():
	get_tree().reload_current_scene()

# ==========================================
# 📖 模块 9：牌库查看面板（记牌器）
# 只能看“剩余牌库构成”，看不到敌方手牌
# ==========================================
func _on_enemy_hand_btn_pressed():
	info_detail_label.text = "【敌方未抽牌库】\n"
	var pool_counts = {}
	for card in enemy_pool: pool_counts[card] = pool_counts.get(card, 0) + 1
	for key in pool_counts: info_detail_label.text += card_display(key) + " : " + str(pool_counts[key]) + " 张\n"
	info_detail_label.text += "\n（敌方手牌不可见，只能靠剩余牌库推算）"
	info_panel.visible = true

func _on_player_pool_btn_pressed():
	info_detail_label.text = "【我方未抽牌库】\n"
	var pool_counts = {}
	for card in deck: pool_counts[card] = pool_counts.get(card, 0) + 1
	for key in pool_counts: info_detail_label.text += card_display(key) + " : " + str(pool_counts[key]) + " 张\n"
	info_panel.visible = true

func _on_close_panel_btn_pressed():
	info_panel.visible = false

# 点面板任意位置也能关闭（兜底，防止 close 按钮失效时关不掉）
func _on_info_panel_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		info_panel.visible = false

# 按 ESC 关闭弹窗
func _unhandled_input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if info_panel.visible:
			info_panel.visible = false
			get_viewport().set_input_as_handled()
