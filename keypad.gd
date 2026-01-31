# Keypad.gd
extends Control

# ==================================================
# CONFIG
# ==================================================
@export var passcode := [8, 3, 1, 6]
@export var max_hearts := 3
@export var debounce_time := 0.65
@export var input_flash_rate := 0.6 # normal seconds per pulse
@export var enable_sounds := false
@export var sound_correct: AudioStream
@export var sound_wrong: AudioStream
@export var sound_win: AudioStream
@export var sound_lose: AudioStream

# ==================================================
# STATE
# ==================================================
var buffer: Array[int] = []
var hearts: int
var input_locked := false
var input_flash_tween: Tween
var audio_player: AudioStreamPlayer

# ==================================================
# UI REFERENCES
# ==================================================
var root_container: VBoxContainer
var digits_container: HBoxContainer
var digit_labels: Array[Label] = []

var hearts_container: HBoxContainer
var heart_icons: Array[ColorRect] = []

var flash_rect: ColorRect
var chroma_rects: Array[ColorRect] = []

var win_screen: Control
var lose_screen: Control

# ==================================================
# READY
# ==================================================
func _ready():
	hearts = max_hearts
	build_ui()
	update_digits()
	update_hearts()
	start_input_flash()
	
	if enable_sounds:
		audio_player = AudioStreamPlayer.new()
		add_child(audio_player)

# ==================================================
# UI CONSTRUCTION
# ==================================================
func build_ui():
	root_container = VBoxContainer.new()
	root_container.anchor_left = 0
	root_container.anchor_right = 1
	root_container.anchor_top = 0
	root_container.anchor_bottom = 1
	root_container.alignment = BoxContainer.ALIGNMENT_CENTER
	root_container.add_theme_constant_override("separation", 30)
	add_child(root_container)

	# Digits
	digits_container = HBoxContainer.new()
	digits_container.alignment = BoxContainer.ALIGNMENT_CENTER
	digits_container.add_theme_constant_override("separation", 20)
	root_container.add_child(digits_container)

	for i in range(passcode.size()):
		var lbl := Label.new()
		lbl.text = "_"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.custom_minimum_size = Vector2(64, 80)
		lbl.add_theme_font_size_override("font_size", 48)
		digit_labels.append(lbl)
		digits_container.add_child(lbl)

	# Hearts
	hearts_container = HBoxContainer.new()
	hearts_container.alignment = BoxContainer.ALIGNMENT_CENTER
	hearts_container.add_theme_constant_override("separation", 12)
	root_container.add_child(hearts_container)

	for i in range(max_hearts):
		var heart := ColorRect.new()
		heart.color = Color.RED
		heart.custom_minimum_size = Vector2(22, 22)
		heart_icons.append(heart)
		hearts_container.add_child(heart)

	# End screens
	win_screen = make_end_screen("VOITIT PELIN", Color.GREEN)
	lose_screen = make_end_screen("HÄVISIT PELIN", Color.RED)
	add_child(win_screen)
	add_child(lose_screen)

	# Chromatic overlays
	chroma_rects = []
	var colors = [Color(1,0,0,0), Color(0,1,0,0), Color(0,0,1,0)]
	for col in colors:
		var c = ColorRect.new()
		c.color = col
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.anchor_left = 0
		c.anchor_right = 1
		c.anchor_top = 0
		c.anchor_bottom = 1
		add_child(c)
		chroma_rects.append(c)

	# Screen flash
	flash_rect = ColorRect.new()
	flash_rect.color = Color(1,1,1,0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.anchor_left = 0
	flash_rect.anchor_right = 1
	flash_rect.anchor_top = 0
	flash_rect.anchor_bottom = 1
	add_child(flash_rect)

# ==================================================
# END SCREENS
# ==================================================
func make_end_screen(text: String, color: Color) -> Control:
	var screen := ColorRect.new()
	screen.color = Color(0,0,0,0.92)
	screen.visible = false
	screen.anchor_left = 0
	screen.anchor_right = 1
	screen.anchor_top = 0
	screen.anchor_bottom = 1

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	label.modulate = color
	label.anchor_left = 0
	label.anchor_right = 1
	label.anchor_top = 0
	label.anchor_bottom = 1
	screen.add_child(label)
	return screen

# ==================================================
# INPUT
# ==================================================
func _unhandled_input(event):
	if input_locked:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode >= KEY_0 and event.keycode <= KEY_9:
			process_digit(event.keycode - KEY_0)

# ==================================================
# CORE LOGIC
# ==================================================
func process_digit(digit: int):
	input_locked = true
	var index := buffer.size()
	if index >= passcode.size():
		input_locked = false
		return

	# Show the digit
	digit_labels[index].text = str(digit)

	if digit == passcode[index]:
		buffer.append(digit)
		if enable_sounds and sound_correct:
			audio_player.stream = sound_correct
			audio_player.play()
		await play_correct_feedback(index)
		if buffer.size() == passcode.size():
			if enable_sounds and sound_win:
				audio_player.stream = sound_win
				audio_player.play()
			await wait(0.8)
			win()
		else:
			await debounce()
	else:
		# Remove wrong digit immediately
		digit_labels[index].text = "_"

		var is_last_heart = hearts == 1
		if enable_sounds and sound_wrong:
			audio_player.stream = sound_wrong
			audio_player.play()
		await play_wrong_feedback(index, is_last_heart)

		hearts -= 1
		update_hearts()
		if hearts <= 0:
			if enable_sounds and sound_lose:
				audio_player.stream = sound_lose
				audio_player.play()
			await wait(0.8)
			lose()
		else:
			await debounce()

# ==================================================
# UI UPDATES
# ==================================================
func update_digits():
	for i in range(digit_labels.size()):
		digit_labels[i].text = str(buffer[i]) if i < buffer.size() else "_"

func update_hearts():
	for i in range(heart_icons.size()):
		heart_icons[i].visible = i < hearts

# ==================================================
# FEEDBACK
# ==================================================
func play_correct_feedback(index: int):
	digit_labels[index].modulate = Color.GREEN
	screen_flash(0.5)
	await wait(0.2)
	digit_labels[index].modulate = Color.WHITE

func play_wrong_feedback(index: int, cruel := false):
	digit_labels[index].modulate = Color.RED
	if cruel:
		screen_flash(2.0)
		jitter(root_container, 36, 0.8)
	else:
		screen_flash(1.5)
		jitter(root_container, 20, 0.4)
	await chroma_aberration(cruel)
	await wait(0.25)
	digit_labels[index].modulate = Color.WHITE

# ==================================================
# FLASH, JITTER, CHROMATIC ABERRATION
# ==================================================
func screen_flash(intensity := 1.0):
	var tween = create_tween()
	flash_rect.color = Color(1,1,1,0)
	tween.tween_property(flash_rect,"color", Color(1,1,1,clamp(intensity,0,1)), 0.05).set_trans(Tween.TRANS_SINE)
	tween.tween_property(flash_rect,"color", Color(1,1,1,0), 0.15)

func jitter(node: Control, strength := 10.0, duration := 0.25):
	var tween = create_tween()
	var original_pos = node.position
	var shakes = int(duration / 0.04)
	for i in range(shakes):
		var offset = Vector2(randf_range(-strength,strength), randf_range(-strength,strength))
		tween.tween_property(node, "position", original_pos + offset, 0.02)
	tween.tween_property(node, "position", original_pos, 0.05)

func chroma_aberration(cruel := false):
	var tween = create_tween()
	var offset = 12
	if cruel:
		offset = 24
	for i in range(chroma_rects.size()):
		var c = chroma_rects[i]
		var dir = i - 1
		var target_pos = Vector2(dir * offset, 0)
		tween.tween_property(c, "position", target_pos, 0.1)
		tween.tween_property(c, "position", Vector2.ZERO, 0.15).set_delay(0.1)

# ==================================================
# INPUT FLASH (Next Empty Digit, Faster on Last Heart)
# ==================================================
func start_input_flash():
	if input_flash_tween and input_flash_tween.is_valid():
		input_flash_tween.kill()
	
	input_flash_tween = create_tween()
	input_flash_tween.set_loops() # infinite loop

	var next_index = buffer.size()
	if next_index >= digit_labels.size():
		return # nothing to flash

	var lbl = digit_labels[next_index]
	var rate = input_flash_rate
	if hearts == 1:
		rate *= 0.4 # faster pulse on last heart

	input_flash_tween.tween_property(lbl, "modulate:a", 0.3, rate/2).set_trans(Tween.TRANS_SINE)
	input_flash_tween.tween_property(lbl, "modulate:a", 1.0, rate/2).set_trans(Tween.TRANS_SINE)

# ==================================================
# FLOW CONTROL
# ==================================================
func debounce():
	await wait(debounce_time)
	input_locked = false
	start_input_flash() # restart pulse for next empty digit

func wait(time: float):
	return get_tree().create_timer(time).timeout

# ==================================================
# END STATES
# ==================================================
func win():
	input_locked = true
	win_screen.visible = true

func lose():
	input_locked = true
	lose_screen.visible = true
