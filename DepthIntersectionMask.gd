@tool
class_name VSNode_DepthIntersectionMask
extends VisualShaderNodeCustom

###################
## Base Props
###################
func _get_name() -> String:
	return "DepthIntersectionMask"

func _get_category() -> String:
	return "Utility"

func _get_description() -> String:
	return "Creates a mask based on depth intersection with scene geometry"

func _get_return_icon_type() -> PortType:
	return VisualShaderNode.PORT_TYPE_SCALAR

#################
## Input props
#################
func _get_input_port_count() -> int:
	return 1

func _get_input_port_name(port: int) -> String:
	return "Distance"

func _get_input_port_type(port: int) -> PortType:
	return VisualShaderNode.PORT_TYPE_SCALAR

func _get_input_port_default_value(port: int) -> Variant:
	return 1.0  # Default intersection distance

#################
## Output props
#################
func _get_output_port_count() -> int:
	return 1

func _get_output_port_name(port: int) -> String:
	return "Mask"

func _get_output_port_type(port: int) -> PortType:
	return VisualShaderNode.PORT_TYPE_SCALAR

#################
## Global code
#################
func _get_global_code(mode: Shader.Mode) -> String:
	return """
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
"""

#################
## Main shader code
#################
func _get_code(input_vars: Array[String], output_vars: Array[String],
		mode: Shader.Mode, type: VisualShader.Type) -> String:
	
	var code_template = """
	{{
		// Sample the depth texture
		float depth = texture(depth_texture, SCREEN_UV).x;
		
		// Convert to normalized device coordinates based on renderer
		vec3 ndc;
		#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
			ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
		#else
			ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
		#endif
		
		// Convert to view space to get linear depth
		vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		view.xyz /= view.w;
		float scene_linear_depth = -view.z;
		
		// Get current fragment depth in view space
		float fragment_depth = -VERTEX.z;
		
		// Calculate depth difference 
		float depth_diff = abs(scene_linear_depth - fragment_depth);
		
		// Create mask based on intersection distance (inverted by default)
		float intersection_distance = {distance_input};
		float mask = 1.0 - clamp(depth_diff / intersection_distance, 0.0, 1.0);
		
		{mask_output} = mask;
	}}
	"""

	return code_template.format({
		"distance_input": input_vars[0] if input_vars[0] != "" else "1.0",
		"mask_output": output_vars[0]
	})

func _is_available(mode: Shader.Mode, type: VisualShader.Type) -> bool:
	return mode == Shader.MODE_SPATIAL && type == VisualShader.TYPE_FRAGMENT
