extends CanvasLayer

var bus_map := {
	"Master": "MasterSlider",
	"Music": "MusicSlider",
	"SFX": "SfxSlider",
	"Voice": "VoiceSlider",
	"Ambience": "AmbienceSlider",
	"UI": "UiSlider",
}

var _sliders: Dictionary = {}

func _ready() -> void:
	visible = false
	$Panel/VBox/ButtonRow/CloseBtn.pressed.connect(_on_close)

	for bus_name in bus_map.keys():
		var node_path = "Panel/VBox/%s" % bus_map[bus_name]
		var slider: HSlider = get_node(node_path)
		_sliders[bus_name] = slider
		var val_label = get_node(node_path.trim_suffix("Slider") + "Value")
		var bus_idx = AudioServer.get_bus_index(bus_name)
		if bus_idx >= 0:
			var db = AudioServer.get_bus_volume_db(bus_idx)
			var pct = db_to_linear(db) * 100
			slider.value = pct
			val_label.text = "%d%%" % pct
		slider.drag_ended.connect(_on_slider_changed.bind(bus_name, slider, val_label))

func show_panel() -> void:
	visible = true

func _on_slider_changed(_value_changed: bool, bus_name: String, slider: HSlider, val_label: Label) -> void:
	var pct = slider.value
	val_label.text = "%d%%" % pct
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(pct / 100.0))

func _on_close() -> void:
	visible = false
