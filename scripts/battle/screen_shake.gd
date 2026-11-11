extends Camera2D

# 屏幕震动：只抖摄像机（Node2D 战斗层），CanvasLayer 里的 HUD 不受影响
var _amp := 0.0
var _time_left := 0.0
var _dur := 0.1

func _ready():
	set_process(false)

# 轻震：出牌 / 翻面 / 普通拼点
func shake_light():
	_start(2.0, 0.18)

# 中震：扣血（死牌爆发 / 误出死牌）
func shake_hit():
	_start(4.5, 0.28)

# 重震：Boss 大招（阶段 C 用）
func shake_heavy():
	_start(7.0, 0.45)

func _start(amplitude: float, duration: float):
	_amp = maxf(_amp, amplitude)
	_dur = maxf(duration, 0.05)
	_time_left = _dur
	set_process(true)

func _process(delta: float):
	_time_left -= delta
	if _time_left <= 0.0:
		offset = Vector2.ZERO
		_amp = 0.0
		set_process(false)
		return
	var t = _time_left / _dur          # 线性衰减
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _amp * t
