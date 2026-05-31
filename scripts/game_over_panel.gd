extends CanvasLayer

const ENDINGS := {
	"school_efficiency": {
		"title": "效率崩溃",
		"reason": "学校效率已崩溃",
		"desc": "工单积压如山，教学质量严重下滑，校园运营陷入瘫痪。",
	},
	"parent_trust": {
		"title": "信任崩塌",
		"reason": "家长信任已丧失殆尽",
		"desc": "家长对学校的管理完全失去信心，大量学生转学。",
	},
	"compliance_safety": {
		"title": "合规审计",
		"reason": "合规安全严重违规",
		"desc": "监管部门介入调查，学校被责令停业整顿。",
	},
	"system_stability": {
		"title": "系统宕机",
		"reason": "系统稳定性已崩溃",
		"desc": "校园管理系统已宕机，无法继续运营。",
	},
}

func _ready() -> void:
	visible = false
	$CenterContainer/VBox/MainMenuBtn.pressed.connect(_on_main_menu)
	$CenterContainer/VBox/QuitBtn.pressed.connect(_on_quit)

func show_ending(metric_id: String) -> void:
	var ending = ENDINGS.get(metric_id, ENDINGS["system_stability"])
	$CenterContainer/VBox/TitleLabel.text = "游戏结束 - " + ending.title
	$CenterContainer/VBox/ReasonLabel.text = ending.reason
	$CenterContainer/VBox/DescLabel.text = ending.desc
	visible = true
	get_tree().paused = true

func _on_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_quit() -> void:
	get_tree().quit()
