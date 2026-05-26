extends Button

var label = $Label

func _ready() -> void:
	pressed.connect(_on_pressed)
	label.visible = false

func _on_pressed() -> void:
	TelemetryCore.open_logs_folder()
	label.visible = true
	label.text = "The log folder is open. Please compress the JSON files into an archive and send it to the developer."
	await get_tree().create_timer(10).timeout
	label.visible = false
