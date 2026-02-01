# MainMenu.gd
class_name MainMenu
extends Control

# ==================================================
# CONFIG
# ==================================================
@export var testing_scene_path := "res://Testing.tscn"

var intro: IntroScreen = preload("res://IntroScreen.tscn").instantiate()

# ==================================================
# STATE
# ==================================================
var selection_index := -1
var buttons: Array[Button] = []
var backgrounds: Array[ColorRect] = []
var labels: Array[Label] = []
var input_locked := false
var anim_tween: Tween

# ==================================================
# READY
# ==================================================
func _ready():
	build_ui()
	animate_state()

# ==================================================
# UI BUILDER
# ==================================================
func build_ui():
	var root = HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# --- LEFT SIDE (Black BG, White Text) ---
	create_side(root, "MUSTA", Color.BLACK, Color.WHITE, 0)
	
	# --- RIGHT SIDE (White BG, Black Text) ---
	create_side(root, "VALKOINEN", Color.WHITE, Color.BLACK, 1)

func create_side(parent: Container, text: String, bg_col: Color, text_col: Color, index: int):
	var panel = Control.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	# Background
	var bg = ColorRect.new()
	bg.color = bg_col
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bg)
	backgrounds.append(bg)

	# Full‑size button
	var btn = Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.focus_mode = Control.FOCUS_NONE
	panel.add_child(btn)
	buttons.append(btn)



	# Centered label
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 64)
	lbl.add_theme_color_override("font_color", text_col)
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HorizontalAlignment.HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VerticalAlignment.VERTICAL_ALIGNMENT_CENTER
	panel.add_child(lbl)
	labels.append(lbl)

	# Signals
	btn.pressed.connect(_on_commit)
	btn.mouse_entered.connect(_on_hover.bind(index))
	btn.mouse_exited.connect(_on_unhover)

# ==================================================
# INPUT & LOGIC
# ==================================================
func _unhandled_input(event):
	if input_locked: return

	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT, KEY_A:
				_on_hover(0)
			KEY_RIGHT, KEY_D:
				_on_hover(1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if selection_index != -1:
					_on_commit()

func _on_hover(index: int):
	if selection_index != index:
		selection_index = index
		animate_state()

func _on_unhover():
	selection_index = -1
	animate_state()

func _on_commit():
	if selection_index == -1: return
	input_locked = true

	var choice = "Musta" if selection_index == 0 else "Valkoinen"
	GameGlobal.player_type = choice

	var tw = create_tween()
	var bg = backgrounds[selection_index]
	var lbl = labels[selection_index]

	# Flash background
	tw.parallel().tween_property(bg, "modulate", Color(1.5, 1.5, 1.5), 0.1)

	# Flash text by increasing font size temporarily
	tw.parallel().tween_callback(func() -> void:
		lbl.add_theme_font_size_override("font_size", 96) # Pop effect
	)
	tw.parallel().tween_callback(func() -> void:
		lbl.add_theme_font_size_override("font_size", 80) # Return to selected size
	)

	# Return background to normal
	tw.tween_property(bg, "modulate", Color.WHITE, 0.1)

	await tw.finished

	load_game_scene()

func load_game_scene():
	var choice_text := "VALKOISEN" if GameGlobal.player_type == "Valkoinen" else "MUSTAN"
	var world_text := "valkoiselta" if GameGlobal.player_type == "Valkoinen" else "mustalta"

	intro.screens = [
		"OLET VALINNUT " + choice_text,
		"HERÄÄT TUNTEMATTOMASSA PAIKASSA",
		"KAIKKI NÄYTTÄÄ " + world_text.to_upper(),
		"ET MUISTA MITÄÄN",
		"TIEDÄT VAIN, ETTÄ SINUN ON PÄÄSTÄVÄ POIS"
	]

	get_tree().root.add_child(intro)
	queue_free()

# ==================================================
# ANIMATION
# ==================================================
func animate_state():
	if anim_tween and anim_tween.is_valid():
		anim_tween.kill()

	anim_tween = create_tween().set_parallel(true)

	for i in range(labels.size()):
		var bg = backgrounds[i]
		var lbl = labels[i]

		var base_size = 64
		var selected_size = 80
		var dimmed_size = 56

		if selection_index == -1:
			# NEUTRAL
			anim_tween.tween_property(bg, "modulate:a", 1.0, 0.3)
			anim_tween.tween_callback(func() -> void:
				lbl.add_theme_font_size_override("font_size", base_size)
			)
			anim_tween.tween_property(lbl, "modulate:a", 0.8, 0.3)

		elif i == selection_index:
			# SELECTED
			anim_tween.tween_property(bg, "modulate:a", 1.0, 0.2)
			anim_tween.tween_callback(func() -> void:
				lbl.add_theme_font_size_override("font_size", selected_size)
			)
			anim_tween.tween_property(lbl, "modulate:a", 1.0, 0.2)

		else:
			# UNSELECTED
			anim_tween.tween_property(bg, "modulate:a", 0.3, 0.3)
			anim_tween.tween_callback(func() -> void:
				lbl.add_theme_font_size_override("font_size", dimmed_size)
			)
			anim_tween.tween_property(lbl, "modulate:a", 0.4, 0.3)
