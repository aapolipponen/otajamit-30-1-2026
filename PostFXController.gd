# PostFXController.gd
extends Node

@export var post_fx_quad_path: NodePath

@onready var _quad := get_node(post_fx_quad_path) as MeshInstance3D
@onready var _mat := _quad.material_override as ShaderMaterial

var effect_mode := 0

func _ready() -> void:
	# READ FROM GLOBAL
	if GameGlobal.player_type == "Musta":
		effect_mode = 1
	else:
		effect_mode = 0
		
	# Apply immediately
	if _mat:
		_mat.set_shader_parameter("effect_mode", effect_mode)

func _process(_delta: float) -> void:
	if _mat:
		_mat.set_shader_parameter("seed", float(Engine.get_frames_drawn()))

func _unhandled_input(event: InputEvent) -> void:
	# Keep debug toggle if you want
	if event.is_action_pressed("toggle_post_fx"):
		effect_mode = 1 - effect_mode
		_mat.set_shader_parameter("effect_mode", effect_mode)
