class_name EndingScreen
extends Control

# ==================================================
# CONFIG (Set via Inspector or Externally)
# ==================================================
@export_group("Audio")
@export var text_sound: AudioStream
@export var win_sound: AudioStream
@export var lose_sound: AudioStream

# ==================================================
# CONSTANTS
# ==================================================
const WIN_COLOR = Color(0.2, 1.0, 0.2) # Bright Green
const LOSE_COLOR = Color(1.0, 0.0, 0.0) # Bright Red

# ==================================================
# STATE
# ==================================================
var screens: Array[String] = []
var final_color: Color = Color.WHITE # Legacy support
var screen_index := 0
var is_typing := false
var input_locked := true

# Tweens
var typing_tween: Tween
var bg_tween: Tween
var shake_tween: Tween

# ==================================================
# UI NODES
# ==================================================
var bg: ColorRect
var title_label: Label
var audio_player: AudioStreamPlayer

# ==================================================
# LIFECYCLE
# ==================================================
func _ready():
	build_ui()
	play_screen()

func build_ui():
	# Determine initial contrast based on player type
	var is_black_player := GameGlobal.player_type == "Musta"
	var initial_bg = Color.BLACK if is_black_player else Color.WHITE
	var initial_text = Color.WHITE if is_black_player else Color.BLACK

	bg = ColorRect.new()
	bg.color = initial_bg
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	title_label = Label.new()
	title_label.text = ""
	title_label.add_theme_font_size_override("font_size", 72)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_label.modulate = initial_text
	add_child(title_label)

	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)

# ==================================================
# CORE LOGIC
# ==================================================
func play_screen():
	input_locked = true
	is_typing = true
	title_label.text = ""
	
	if screen_index >= screens.size():
		return 

	# Check if this is the very last screen
	if screen_index == screens.size() - 1:
		play_final_sequence()
		return

	# Standard typing
	var text := screens[screen_index]
	
	if typing_tween: typing_tween.kill()
	typing_tween = create_tween()
	
	for i in range(text.length()):
		typing_tween.tween_callback(func():
			title_label.text += text[i]
			play_text_sound()
		)
		typing_tween.tween_interval(0.05)

	typing_tween.tween_callback(func():
		finish_screen_logic()
	)

func next_screen():
	screen_index += 1
	play_screen()

# ==================================================
# FINAL SEQUENCE
# ==================================================
func play_final_sequence():
	var text = screens[screen_index]
	
	if typing_tween: typing_tween.kill()
	
	# Show final text instantly
	title_label.text = text
	is_typing = false
	input_locked = true 
	
	# 1. Determine Win/Loss
	var lower_text = text.to_lower()
	var is_win = false
	
	# Simple keyword detection for Finnish
	if "voit" in lower_text or "onnittelut" in lower_text or "selvis" in lower_text or "loppu" in lower_text:
		if not ("hävis" in lower_text or "kuol" in lower_text):
			is_win = true

	# 2. Apply Effects based on result
	if is_win:
		title_label.modulate = WIN_COLOR
		play_sound_override(win_sound)
		# No shake for winning
	else:
		title_label.modulate = LOSE_COLOR
		play_sound_override(lose_sound)
		screen_shake(15.0, 1.0) # Shake only on loss, reduced intensity

	# 3. Quit after delay
	await get_tree().create_timer(4.0).timeout
	get_tree().quit()

# ==================================================
# INPUT
# ==================================================
func _unhandled_input(event):
	if not (event is InputEventKey and event.pressed):
		return

	if is_typing:
		finish_screen_logic()
		return

	if not input_locked:
		next_screen()

func finish_screen_logic():
	if typing_tween: typing_tween.kill()
	
	var text = screens[screen_index]
	title_label.text = text
	is_typing = false
	
	apply_text_effects(text)
	
	if screen_index == screens.size() - 1:
		play_final_sequence()
	else:
		input_locked = false 

# ==================================================
# TEXT EFFECTS
# ==================================================
func apply_text_effects(text: String):
	match text:
		"MAAILMA HALKEAA":
			screen_shake(12, 0.8) # Reduced from 28

		"AIKA PYSÄHTYY":
			slow_motion(0.1, 2.0)

		"KAIKKI MUUTTUU VALKOISEKSI":
			fade_background(Color.WHITE, Color.BLACK)

		"KAIKKI PIMENEE":
			fade_background(Color.BLACK, Color.WHITE)

# ==================================================
# VISUAL FX
# ==================================================
func fade_background(bg_color: Color, text_color: Color):
	if bg_tween: bg_tween.kill()
	bg_tween = create_tween()
	bg_tween.set_parallel(true)
	bg_tween.tween_property(bg, "color", bg_color, 1.5)
	bg_tween.tween_property(title_label, "modulate", text_color, 1.5)

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

func slow_motion(scale := 0.3, duration := 1.5):
	Engine.time_scale = scale
	await get_tree().create_timer(duration * scale).timeout 
	Engine.time_scale = 1.0

# ==================================================
# AUDIO
# ==================================================
func play_text_sound():
	if not text_sound: return
	audio_player.stream = text_sound
	audio_player.pitch_scale = randf_range(0.9, 1.1)
	audio_player.play()

func play_sound_override(stream: AudioStream):
	if not stream: return
	audio_player.stop() # Stop any typing sounds
	audio_player.stream = stream
	audio_player.pitch_scale = 1.0
	audio_player.play()
