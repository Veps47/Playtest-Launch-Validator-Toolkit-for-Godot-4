extends Control

@onready var btn_accept: Button = $Panel/VBoxContainer/HBoxContainer/BtnAccept
@onready var btn_decline: Button = $Panel/VBoxContainer/HBoxContainer/BtnDecline

func _ready() -> void:
	if not TelemetryCore.needs_consent_dialog():
		queue_free()
		return
		
	show()
	btn_accept.pressed.connect(_on_accept_pressed)
	btn_decline.pressed.connect(_on_decline_pressed)

func _on_accept_pressed() -> void:
	TelemetryCore.set_analytics_consent(true)
	queue_free()

func _on_decline_pressed() -> void:
	TelemetryCore.set_analytics_consent(false)
	queue_free()
