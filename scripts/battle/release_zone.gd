extends Node2D

# 屏幕中间的释放平面（杀戮尖塔式：一整个平面，而非小圆圈）
# 只画四角标记，避免大白框遮挡画面
const ZONE_SIZE := Vector2(520, 150)
const CORNER := 16.0

func _draw():
	var col = Color(0.85, 0.85, 0.95, 0.35)
	var w = ZONE_SIZE.x
	var h = ZONE_SIZE.y
	# 左上
	draw_line(Vector2(0, 0), Vector2(CORNER, 0), col, 2.0)
	draw_line(Vector2(0, 0), Vector2(0, CORNER), col, 2.0)
	# 右上
	draw_line(Vector2(w, 0), Vector2(w - CORNER, 0), col, 2.0)
	draw_line(Vector2(w, 0), Vector2(w, CORNER), col, 2.0)
	# 左下
	draw_line(Vector2(0, h), Vector2(CORNER, h), col, 2.0)
	draw_line(Vector2(0, h), Vector2(0, h - CORNER), col, 2.0)
	# 右下
	draw_line(Vector2(w, h), Vector2(w - CORNER, h), col, 2.0)
	draw_line(Vector2(w, h), Vector2(w, h - CORNER), col, 2.0)
