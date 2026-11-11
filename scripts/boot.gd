extends Node

# 启动时把窗口设成"按屏幕整数倍放大"，并支持 F11 / Alt+Enter 全屏切换。
# 说明：project.godot 里的 window_width_override 只对编辑器里 F5 生效，
# 导出后游戏会以 640x360 的原始尺寸打开 —— 所以这里运行时自动放大。

const BASE := Vector2i(640, 360)

func _ready():
	apply_window()

func apply_window():
	if DisplayServer.get_name() == "headless":
		return
	var screen: Vector2i = DisplayServer.screen_get_size()
	var s := mini(screen.x / BASE.x, screen.y / BASE.y)
	if s < 1:
		s = 1
	var win := BASE * s
	DisplayServer.window_set_size(win)
	var pos := (Vector2(screen) - Vector2(win)) * 0.5
	DisplayServer.window_set_position(Vector2i(pos))

func toggle_fullscreen():
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		apply_window()
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
			toggle_fullscreen()
			get_viewport().set_input_as_handled()
