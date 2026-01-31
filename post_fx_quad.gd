extends MeshInstance3D

@export var post_fx_shader: Shader
@export var start_effect := 1 # 0 = fog glow, 1 = tracer noise

var effect_mode := 1
var _mat: ShaderMaterial

func _ready() -> void:
	# Ensure we have a ShaderMaterial to set uniforms on.
	if material_override is ShaderMaterial:
		_mat = material_override
	else:
		_mat = ShaderMaterial.new()
		material_override = _mat

	if post_fx_shader == null:
		push_error("PostFXQuad: post_fx_shader is not assigned.")
		return

	_mat.shader = post_fx_shader

	effect_mode = start_effect
	# Safer: set as per-instance uniforms (recommended when you don't want shared-material side effects).
	set_instance_shader_parameter("effect_mode", effect_mode)

func _process(_delta: float) -> void:
	# Drive animated noise deterministically.
	set_instance_shader_parameter("seed", float(Engine.get_frames_drawn()))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_post_fx"):
		effect_mode = 1 - effect_mode
		set_instance_shader_parameter("effect_mode", effect_mode)
