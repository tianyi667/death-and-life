extends Control

signal end_turn_pressed
signal insight_pressed
signal restart_pressed
signal next_level_pressed
signal menu_pressed

# ---------- 场景节点引用（在 battle_scene.tscn 里可编辑） ----------
@onready var hp_label: Label = $HpLabel
@onready var death_label: Label = $DeathLabel
@onready var info_label: Label = $InfoLabel
@onready var insight_btn: Button = $InsightButton
@onready var end_btn: Button = $EndTurnButton
@onready var enemy_pool_btn: Button = $EnemyPoolButton
@onready var player_pool_btn: Button = $PlayerPoolButton
@onready var info_panel: Panel = $InfoPanel
@onready var info_detail: Label = $InfoPanel/InfoDetailLabel
@onready var close_btn: Button = $InfoPanel/ClosePanelButton
@onready var result_panel: Panel = $ResultPanel
@onready var result_title: Label = $ResultPanel/ResultTitle
@onready var restart_btn: Button = $ResultPanel/RestartButton
@onready var menu_btn: Button = $ResultPanel/MenuButton
@onready var next_btn: Button = $ResultPanel/NextButton

var pool_enemy: Array = []
var pool_player: Array = []

func _ready():
	insight_btn.pressed.connect(func(): insight_pressed.emit())
	end_btn.pressed.connect(func(): end_turn_pressed.emit())
	enemy_pool_btn.pressed.connect(func(): _open_pool(true))
	player_pool_btn.pressed.connect(func(): _open_pool(false))
	close_btn.pressed.connect(func(): info_panel.visible = false)
	info_panel.gui_input.connect(_on_panel_click)
	restart_btn.pressed.connect(func(): restart_pressed.emit())
	menu_btn.pressed.connect(func(): menu_pressed.emit())
	next_btn.pressed.connect(func(): next_level_pressed.emit())

func _on_panel_click(e):
	if e is InputEventMouseButton and e.pressed:
		info_panel.visible = false

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if info_panel.visible:
			info_panel.visible = false
			get_viewport().set_input_as_handled()

func _open_pool(is_enemy: bool):
	var pool = pool_enemy if is_enemy else pool_player
	var t = ("【敌方未抽牌库】\n" if is_enemy else "【我方未抽牌库】\n")
	var counts = {}
	for c in pool: counts[c] = counts.get(c, 0) + 1
	var names = {"rope": "绳", "stone": "石", "knife": "刀", "gun": "枪", "life": "生", "death": "死"}
	for k in counts: t += names.get(k, k) + " : " + str(counts[k]) + " 张\n"
	if is_enemy:
		t += "\n（敌方手牌不可见，只能靠剩余牌库推算）"
	info_detail.text = t
	info_panel.visible = true

func refresh(hp_p: int, hp_e: int, death_t: int, insight: int, end_on: bool):
	hp_label.text = "我方生命 %d    ｜    敌方生命 %d" % [hp_p, hp_e]
	death_label.text = ("死牌倒计时：%d" % death_t) if death_t > 0 else ""
	insight_btn.text = "窥见 %d" % insight
	insight_btn.disabled = insight <= 0
	end_btn.disabled = not end_on

func set_end_enabled(on: bool):
	end_btn.disabled = not on

func set_info(t: String):
	info_label.text = t

func append_info(t: String):
	info_label.text += "\n" + t

func show_result(won: bool, can_next: bool):
	result_title.text = "你赢了！" if won else "你输了。"
	next_btn.visible = won and can_next
	result_panel.visible = true
	end_btn.disabled = true
	insight_btn.disabled = true
