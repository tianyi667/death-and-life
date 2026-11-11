extends Node2D

const EnemyAIScript = preload("res://scripts/date/EnemyAI.gd")

enum State { PLAYER_TURN, WAIT_END, RESOLVING, ENDED }

var state: State = State.PLAYER_TURN
var resolver = BattleResolver.new()
var enemy_ai = EnemyAIScript.new()

# ---------- 数据 ----------
var deck: Array = []
var hand: Array = []
var enemy_pool: Array = []
var enemy_hand: Array = []
var player_initial_deck: Array = []
var enemy_initial_deck: Array = []

var player_hp := 3
var enemy_hp := 3
var insight_count := 1
const INSIGHT_MAX := 3
var death_timer := -1
var enemy_death_timer := -1

var enemy_current_card := ""   # 回合开始就定（盖牌用）
var player_committed := ""     # 玩家拖进中间平面交出的那张

# ---------- 场景节点引用（在 battle_scene.tscn 里可编辑） ----------
@onready var cam: Camera2D = $Camera2D
@onready var bg: Sprite2D = $BattleField/Background
@onready var player_sprite: Sprite2D = $BattleField/PlayerSprite
@onready var enemy_sprite: Sprite2D = $BattleField/EnemySprite
@onready var hud_root: Control = $Hud/HudRoot
@onready var hand_ctrl: Control = $Hud/HudRoot/HandContainer
@onready var slots: Control = $Hud/HudRoot/PlayedSlots
@onready var hud_ui: Control = $Hud/HudRoot/HudUI

# 中间释放平面（杀戮尖塔式，一整个平面）
const RELEASE_RECT := Rect2(60, 70, 520, 150)

# 同一地面线：双方脚底都在 y≈298（手牌在其下方，不遮挡角色）
const GROUND_Y := 250.0
const PLAYER_POS := Vector2(240, 250)
const BOSS_POS := Vector2(400, 235)   # Boss 1.4 倍时，中心下移保证脚底落地

# 关卡配置（阶段 C 会扩展 AI 与 Boss 机制）
const LEVELS = {
	1: {
		"pool": ["stone", "stone", "rope", "rope", "knife", "knife", "stone"],
		"bg": "res://art/pixel/bg_level1.png",
		"enemy": "res://art/pixel/char_guard.png",
		"enemy_pos": Vector2(400, GROUND_Y),
		"enemy_scale": Vector2(1, 1),
	},
	2: {
		"pool": ["gun", "life", "death", "death", "knife", "rope", "stone"],
		"bg": "res://art/pixel/bg_level2.png",
		"enemy": "res://art/pixel/char_elite.png",
		"enemy_pos": Vector2(400, GROUND_Y),
		"enemy_scale": Vector2(1, 1),
	},
	3: {
		"pool": ["knife", "knife", "stone", "rope", "gun", "stone", "rope"],
		"bg": "res://art/pixel/bg_level3.png",
		"enemy": "res://art/pixel/char_boss.png",
		"enemy_pos": BOSS_POS,
		"enemy_scale": Vector2(1.4, 1.4),
	},
}

const CARD_NAMES = {"rope": "绳", "stone": "石", "knife": "刀", "gun": "枪", "life": "生", "death": "死"}

func _cn(n: String) -> String:
	return CARD_NAMES.get(n, n)

func _ready():
	# 接线：UI 信号 → 流程函数
	hud_ui.end_turn_pressed.connect(_on_end_turn)
	hud_ui.insight_pressed.connect(_on_insight)
	hud_ui.restart_pressed.connect(func(): get_tree().reload_current_scene())
	hud_ui.next_level_pressed.connect(_on_next_level)
	hud_ui.menu_pressed.connect(func(): GameManager.goto_map())
	hand_ctrl.card_committed.connect(_on_card_committed)
	hand_ctrl.setup(hud_root, RELEASE_RECT)

	_load_level(GameManager.current_level)

	deck = GameManager.get_character_deck()
	player_initial_deck = deck.duplicate()
	enemy_initial_deck = enemy_pool.duplicate()
	deck.shuffle()
	enemy_pool.shuffle()
	for i in range(3):
		draw_card()
	_start_round()

func _load_level(level: int):
	var cfg: Dictionary = LEVELS.get(level, LEVELS[1])
	enemy_pool = cfg["pool"].duplicate()
	bg.texture = load(cfg["bg"])
	enemy_sprite.texture = load(cfg["enemy"])
	enemy_sprite.position = cfg["enemy_pos"]
	enemy_sprite.scale = cfg["enemy_scale"]

# ---------- 回合流程 ----------
func _start_round():
	state = State.PLAYER_TURN
	player_committed = ""
	if enemy_hand.is_empty():
		draw_card()
	enemy_current_card = enemy_ai.choose_card(enemy_hand)   # 回合开始就定牌
	slots.place_enemy_face_down(enemy_current_card)
	hand_ctrl.refresh(hand)
	hand_ctrl.set_interactive(true)
	hud_ui.pool_enemy = enemy_pool
	hud_ui.pool_player = deck
	hud_ui.refresh(player_hp, enemy_hp, death_timer, insight_count, false)

func _on_card_committed(card):
	if state != State.PLAYER_TURN:
		return
	player_committed = card.card_name
	hand.erase(player_committed)
	state = State.WAIT_END
	hand_ctrl.set_interactive(false)
	slots.commit_player_card(card)
	hud_ui.refresh(player_hp, enemy_hp, death_timer, insight_count, true)

func _on_insight():
	# 出牌前（PLAYER_TURN）和出牌后（WAIT_END）都可以窥见
	var can := state == State.PLAYER_TURN or state == State.WAIT_END
	if not can or insight_count <= 0 or slots.enemy_revealed:
		return
	insight_count -= 1
	slots.reveal_enemy()
	hud_ui.set_info("【窥见】敌人将打出：【" + _cn(enemy_current_card) + "】")
	# 只有已经交出牌时，「回合结束」才可点
	hud_ui.refresh(player_hp, enemy_hp, death_timer, insight_count, state == State.WAIT_END)

func _on_end_turn():
	if state != State.WAIT_END:
		return
	state = State.RESOLVING
	hud_ui.set_end_enabled(false)
	if slots.enemy_card != null and slots.enemy_card.is_face_down:
		await slots.enemy_card.flip_to_front()
	cam.shake_light()                       # 回合结束：触发震动
	# 停顿：让玩家看清敌人出的这张牌
	await get_tree().create_timer(0.7).timeout
	var ended = _resolve_round()
	if ended:
		return
	# 再停顿：留时间读结算信息，然后清场进入下一回合
	await get_tree().create_timer(0.6).timeout
	slots.clear()
	draw_card()
	_start_round()

func _on_next_level():
	if GameManager.current_level < 3:
		GameManager.goto_battle(GameManager.current_level + 1)
	else:
		GameManager.goto_map()

# ---------- 抽牌 / 洗牌 ----------
func draw_card():
	if deck.size() == 0: refresh_deck()
	if deck.size() > 0:
		var c = deck.pop_back()
		hand.append(c)
		if c == "death" and death_timer == -1: death_timer = 3
	if enemy_pool.size() == 0: refresh_enemy_deck()
	if enemy_pool.size() > 0:
		var c = enemy_pool.pop_back()
		enemy_hand.append(c)
		if c == "death" and enemy_death_timer == -1: enemy_death_timer = 3

func refresh_deck():
	var hc = {}
	for c in hand: hc[c] = hc.get(c, 0) + 1
	var nd = []
	for c in player_initial_deck:
		if hc.get(c, 0) > 0: hc[c] -= 1
		else: nd.append(c)
	deck = nd
	deck.shuffle()

func refresh_enemy_deck():
	var hc = {}
	for c in enemy_hand: hc[c] = hc.get(c, 0) + 1
	var nd = []
	for c in enemy_initial_deck:
		if hc.get(c, 0) > 0: hc[c] -= 1
		else: nd.append(c)
	enemy_pool = nd
	enemy_pool.shuffle()

# ---------- 结算（HP/死牌/窥见补偿），返回 true = 战斗结束 ----------
func _resolve_round() -> bool:
	var result = resolver.resolve(player_committed, enemy_current_card)
	hud_ui.set_info(result.text)

	if result.winner == "player":
		enemy_pool.append("death")
		hud_ui.append_info("敌方牌库被塞入 1 张死牌！")
	elif result.winner == "enemy":
		deck.append("death")
		insight_count = mini(insight_count + 1, INSIGHT_MAX)
		hud_ui.append_info("你输了拼点：+1 窥见，牌库被塞入 1 张死牌！")

	# 玩家死牌结算
	if player_committed == "death":
		if result.winner == "player" or result.winner == "draw":
			death_timer = -1
			hud_ui.append_info("死牌安全落地，未扣血。")
		else:
			player_hp -= 1
			cam.shake_hit()
			death_timer = -1
			hud_ui.append_info("你误出了【死】牌，反噬扣 1 点生命！")
			if player_hp <= 0:
				_end_battle(false)
				return true
	elif death_timer > 0:
		death_timer -= 1
		if death_timer == 0:
			player_hp -= 1
			cam.shake_hit()
			hand.erase("death")
			death_timer = -1
			hud_ui.append_info("死牌爆发！扣 1 点生命，死牌销毁。")
			if hand.has("death"):
				death_timer = 3
			if player_hp <= 0:
				_end_battle(false)
				return true

	# 敌人死牌结算（暗中）
	if enemy_current_card == "death":
		if result.winner == "enemy" or result.winner == "draw":
			enemy_death_timer = -1
		else:
			enemy_hp -= 1
			cam.shake_hit()
			enemy_death_timer = -1
			hud_ui.append_info("敌人误出了【死】牌，反噬扣 1 点生命！")
			if enemy_hp <= 0:
				_end_battle(true)
				return true
	elif enemy_death_timer > 0:
		enemy_death_timer -= 1
		if enemy_death_timer == 0:
			enemy_hp -= 1
			cam.shake_hit()
			enemy_hand.erase("death")
			enemy_death_timer = -1
			hud_ui.append_info("敌人死牌爆发，扣除 1 点生命！")
			if enemy_hand.has("death"):
				enemy_death_timer = 3
			if enemy_hp <= 0:
				_end_battle(true)
				return true

	enemy_hand.erase(enemy_current_card)
	return false

func _end_battle(won: bool):
	state = State.ENDED
	slots.clear()
	hand_ctrl.set_interactive(false)
	if won:
		GameManager.finish_battle()
	hud_ui.show_result(won, GameManager.current_level < 3)
