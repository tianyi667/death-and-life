extends Node
var current_level = 1
var max_current_level = 1
var current_character = 'knife_user'
var character_decks ={'knife_user':['stone','stone','rope','rope','knife','gun','life','knife']
					,"rope":['rope','rope','rope','stone','knife','life','gun','death']	}		  #角色池
func get_character_deck()->Array:
	return character_decks[current_character].duplicate()
func goto_battle(level_num:int):
	current_level = level_num         #进入时给关卡赋值
	get_tree().change_scene_to_file("res://scenes/battle_scene.tscn")
func goto_map():
	get_tree().change_scene_to_file("res://ui/ui.tscn")   #回到主界面
func finish_battle():
	max_current_level +=1             #只记录通关进度，不立刻切场景（否则结算面板会被切走）
