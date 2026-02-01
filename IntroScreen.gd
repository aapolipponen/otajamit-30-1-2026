class_name IntroScreen
extends Control

# ==================================================
# CONFIG
# ==================================================
@export_group("Audio")
@export var text_sound: AudioStream

var screens: Array[String] = []

# ==================================================
# STATE
# ==================================================
var screen_index := 0
var input_locked := true
var is_typing := false

# Tweens
var typing_tween: Tween
var prompt_tween: Tween
var shake_tween: Tween
var fade_tween: Tween

# ==================================================
# UI NODES
# ==================================================
var bg: ColorRect
var title_label: Label
var prompt_label: Label
var audio_player: AudioStreamPlayer

# ==================================================
# LIFECYCLE
# ==================================================
func _ready():
	build_ui()
	play_screen()

func build_ui():
	var is_black := GameGlobal.player_type == "Musta"
	var text_color = Color.WHITE if is_black else Color.BLACK

	# Background
	bg = ColorRect.new()
	bg.color = Color.BLACK if is_black else Color.WHITE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main Text
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 72)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_label.modulate = text_color
	add_child(title_label)

	# "Press Any Key" Prompt
	prompt_label = Label.new()
	prompt_label.text = "PAINA MITÄ TAHANSA NÄPPÄINTÄ"
	prompt_label.add_theme_font_size_override("font_size", 22)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	prompt_label.position.y += 120 # Offset slightly down
	prompt_label.modulate = text_color
	prompt_label.modulate.a = 0.0 # Start hidden
	add_child(prompt_label)
	
	# Audio
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)

# ==================================================
# CORE LOGIC
# ==================================================
func play_screen():
	# Reset State
	input_locked = true
	is_typing = true
	title_label.text = ""
	prompt_label.modulate.a = 0.0 # Hide prompt

	# Kill old tweens
	if typing_tween: typing_tween.kill()
	if prompt_tween: prompt_tween.kill()

	var text = screens[screen_index]

	# Start Typing
	typing_tween = create_tween()
	for i in range(text.length()):
		typing_tween.tween_callback(func():
			title_label.text += text[i]
			play_text_sound()
		)
		typing_tween.tween_interval(0.05)

	# On Complete
	typing_tween.tween_callback(func():
		finish_screen_logic()
	)

func next_screen():
	screen_index += 1
	if screen_index >= screens.size():
		fade_out_and_start()
	else:
		play_screen()

# ==================================================
# INPUT HANDLING
# ==================================================
func _unhandled_input(event):
	if not (event is InputEventKey and event.pressed):
		return

	# 1. Kill prompt fade-in on any key press
	if prompt_tween: prompt_tween.kill()
	prompt_label.modulate.a = 0.0

	# 2. If Typing -> Finish text instantly (Don't skip screen yet)
	if is_typing:
		finish_screen_logic()
		return

	# 3. If Done -> Go Next
	if not input_locked:
		next_screen()

func finish_screen_logic():
	if typing_tween: typing_tween.kill()
	
	var text = screens[screen_index]
	title_label.text = text
	is_typing = false
	input_locked = false
	
	# Optional: Check for dramatic keywords in intro too
	apply_text_effects(text)
	
	schedule_prompt()

func schedule_prompt():
	# Wait a bit, then fade in the prompt
	prompt_tween = create_tween()
	prompt_tween.tween_interval(1.0)
	prompt_tween.tween_property(prompt_label, "modulate:a", 0.5, 1.0)

# ==================================================
# TRANSITION
# ==================================================
func fade_out_and_start():
	input_locked = true
	if prompt_tween: prompt_tween.kill()
	prompt_label.modulate.a = 0.0

	# Fade out the background (revealing the game scene behind, or black)
	fade_tween = create_tween()
	fade_tween.tween_property(bg, "modulate:a", 0.0, 2.0)
	fade_tween.parallel().tween_property(title_label, "modulate:a", 0.0, 1.5)
	
	fade_tween.tween_callback(func():
		get_tree().change_scene_to_file("res://Testing.tscn")
		queue_free()
	)

# ==================================================
# EFFECTS & AUDIO
# ==================================================
func play_text_sound():
	if not text_sound: return
	audio_player.stream = text_sound
	audio_player.pitch_scale = randf_range(0.95, 1.05)
	audio_player.play()

func apply_text_effects(text: String):
	# If you want dramatic intros like "MAAILMA JÄRKYTTYY"
	match text:
		"TÄMÄ ON TARINA...": # Example
			pass 
		"AIKA PYSÄHTYY":
			screen_shake(10, 0.5)

func screen_shake(strength := 10.0, duration := 0.5):
	if shake_tween: shake_tween.kill()

	var original_pos := Vector2.ZERO
	shake_tween = create_tween()
	var steps := int(duration / 0.04)

	for i in range(steps):
		var offset := Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength)
		)
		shake_tween.tween_property(self, "position", original_pos + offset, 0.04)

	shake_tween.tween_property(self, "position", original_pos, 0.05)
