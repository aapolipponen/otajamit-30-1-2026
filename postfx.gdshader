shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;

uniform sampler2D screen_texture : source_color, hint_screen_texture;
uniform sampler2D depth_texture  : source_color, hint_depth_texture;

uniform int effect_mode = 0;   // 0 fog, 1 noise
uniform float seed = 0.0;

uniform int debug_mode = 0;    // 0 off, 1 show dist, 2 show raw depth, 3 show FINAL noise strength
uniform float debug_dist_scale = 120.0;

// Treat "far plane / no geometry" depth as background.
// In reverse-Z, far is ~0. <!--citation:1-->
uniform float depth_far_epsilon = 0.000001;

// -------------------- Fog --------------------
uniform float fog_start = 0.5;
uniform float fog_end   = 15.0;

uniform float fog_density      = 2.5;
uniform float fog_strength_mul = 2.0;
uniform float fog_power        = 1.5;
uniform float fog_max          = 1.0;

uniform vec3 fog_color_near : source_color = vec3(0.65, 0.75, 0.90);
uniform vec3 fog_color_far  : source_color = vec3(0.92, 0.96, 1.00);

uniform float fog_mix_amount = 1.0;
uniform float fog_add_amount = 0.6;

uniform float fog_up_start_y  = 2.0;
uniform float fog_up_end_y    = 25.0;
uniform float fog_up_strength = 8.0;
uniform float fog_up_power    = 1.5;

uniform float fog_dither_amount = 0.04;

// -------------------- Noise --------------------
uniform float noise_dist_start = 0.0;
uniform float noise_dist_end   = 60.0;

uniform float noise_strength_near = 15.0;
uniform float noise_strength_far  = 0.12;

uniform float noise_falloff_power = 2.5;
uniform float noise_strength_mul  = 25.0;

uniform float noise_inv_distance_boost = 25.0;
uniform float noise_min_distance = 0.05;

uniform float noise_blackout_start  = 0.0;
uniform float noise_blackout_end    = 0.1;
uniform float noise_blackout_amount = 0.1;

uniform float grain_size_px      = 1.0;
uniform float noise_speed        = 1.0;
uniform float noise_pixel_jitter = 2.0;

uniform int   noise_apply_linear = 1;
uniform float noise_dark_only    = 1.0;
uniform float noise_speckle_power = 0.45;

uniform float noise_luma_boost = 4.0;
uniform float noise_luma_power = 2.0;

uniform float signal_sample_radius_px = 1.0;
uniform float signal_flat_boost = 8.0;
uniform float signal_flat_low   = 0.01;
uniform float signal_flat_high  = 0.08;

uniform float signal_edge_suppress = 0.35;
uniform float signal_edge_low      = 0.05;
uniform float signal_edge_high     = 0.20;

uniform float signal_boost_fades_with_distance = 1.0;

// -------------------- Fireflies --------------------
uniform float firefly_amount = 0.20;
uniform vec3  firefly_color  : source_color = vec3(1.0, 0.95, 0.80);

uniform float firefly_cell_size_px = 64.0;
uniform float firefly_rate         = 0.003;
uniform float firefly_hold_frames  = 18.0;

uniform float firefly_intensity = 12.0;
uniform float firefly_radius_px = 2.5;

uniform float firefly_luma_threshold = 0.35;


// -------------------- helpers --------------------
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	return vec2(hash12(p), hash12(p + 17.17));
}

float luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// 1 near, 0 far
float inv_dist_ramp(float dist) {
	float u = 0.0;
	if (noise_dist_end > noise_dist_start) {
		u = clamp((dist - noise_dist_start) / (noise_dist_end - noise_dist_start), 0.0, 1.0);
	}
	return pow(1.0 - u, noise_falloff_power);
}

void vertex() {
	// Godot advanced post-processing fullscreen quad pattern. <!--citation:2-->
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col = texture(screen_texture, uv).rgb;

	// Depth is reverse-z and nonlinear; linearize using INV_PROJECTION_MATRIX. <!--citation:1-->
	float depth = texture(depth_texture, uv).x;

	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		vec3 ndc = vec3(uv, depth) * 2.0 - 1.0;
	#else
		vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
	#endif

	vec4 upos = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vec3 view_pos = upos.xyz / upos.w;

	float dist = -view_pos.z;

	// Background/far-plane guard: if depth is ~0 in reverse-Z, treat as very far. <!--citation:1-->
	if (depth <= depth_far_epsilon) {
		dist = 1e9;
		view_pos = vec3(0.0, 0.0, -1e9);
	}

	// World position for fog (INV_VIEW_MATRIX is a spatial built-in). <!--citation:3-->
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(view_pos, 1.0)).xyz;

	// ----- DEBUG -----
	if (debug_mode == 2) {
		col = vec3(depth);
	} else if (debug_mode == 1) {
		col = vec3(clamp(dist / max(debug_dist_scale, 0.0001), 0.0, 1.0));
	} else if (debug_mode == 3) {
		// We'll compute the FINAL strength exactly like the noise pass does and visualize it.
		float near_w_dbg = inv_dist_ramp(dist);

		// base
		float strength_dbg = mix(noise_strength_far, noise_strength_near, near_w_dbg);

		// gate 1/dist boost to near only
		float dist_safe_dbg = max(dist, noise_min_distance);
		strength_dbg *= (1.0 + (noise_inv_distance_boost * near_w_dbg) / dist_safe_dbg);

		// approximate signal mul = 1 at debug time (keep it simple), then apply global mul
		strength_dbg *= noise_strength_mul;

		col = vec3(clamp(strength_dbg / 10.0, 0.0, 1.0));
	} else {
		// ----- NORMAL RENDER -----
		if (effect_mode == 0) {
			// ---------------- FOG ----------------
			float d = max(dist - fog_start, 0.0);
			float denom = max(fog_end - fog_start, 0.0001);
			float lin = clamp(d / denom, 0.0, 1.0);

			float fog = 1.0 - exp(-lin * fog_density * fog_strength_mul);
			fog = pow(clamp(fog, 0.0, 1.0), fog_power);

			float up = 0.0;
			if (fog_up_end_y > fog_up_start_y) {
				up = clamp((world_pos.y - fog_up_start_y) / (fog_up_end_y - fog_up_start_y), 0.0, 1.0);
			}
			up = pow(up, fog_up_power);
			fog *= (1.0 + fog_up_strength * up);

			fog = min(fog, fog_max);

			if (fog_dither_amount != 0.0) {
				vec2 pixel_xy = uv * VIEWPORT_SIZE;
				float dn = hash12(floor(pixel_xy) + vec2(seed, seed * 0.37)) - 0.5;
				fog = clamp(fog + dn * fog_dither_amount, 0.0, 1.0);
			}

			float ramp = 0.0;
			if (fog_end > fog_start) {
				ramp = clamp((dist - fog_start) / (fog_end - fog_start), 0.0, 1.0);
			}
			vec3 fog_col = mix(fog_color_near, fog_color_far, ramp);

			col = mix(col, fog_col, fog * fog_mix_amount);
			col += fog_col * (fog * fog_add_amount);

		} else {
			// ---------------- NOISE + FIREFLIES ----------------

			// Signal-based contrast
			vec2 px_uv = vec2(signal_sample_radius_px) / VIEWPORT_SIZE;

			float lum0 = luma(col);
			float lumR = luma(texture(screen_texture, uv + vec2(+px_uv.x, 0.0)).rgb);
			float lumL = luma(texture(screen_texture, uv + vec2(-px_uv.x, 0.0)).rgb);
			float lumU = luma(texture(screen_texture, uv + vec2(0.0, +px_uv.y)).rgb);
			float lumD = luma(texture(screen_texture, uv + vec2(0.0, -px_uv.y)).rgb);

			float contrast = (abs(lumR - lum0) + abs(lumL - lum0) + abs(lumU - lum0) + abs(lumD - lum0)) * 0.25;

			float flatness = 1.0 - smoothstep(signal_flat_low, signal_flat_high, contrast);
			float edge_amt = smoothstep(signal_edge_low, signal_edge_high, contrast);

			float signal_mul = 1.0 + signal_flat_boost * flatness;
			signal_mul *= mix(1.0, 1.0 - signal_edge_suppress, edge_amt);

			// Distance ramp
			float near_w = inv_dist_ramp(dist); // 1 near, 0 far

			// Base strength (monotonic vs distance)
			float strength = mix(noise_strength_far, noise_strength_near, near_w);

			// Gate the 1/dist explosion by near_w
			float dist_safe = max(dist, noise_min_distance);
			strength *= (1.0 + (noise_inv_distance_boost * near_w) / dist_safe);

			// Dark boost (but fade it out at distance to avoid "comes back far")
			float dark = pow(clamp(1.0 - lum0, 0.0, 1.0), noise_luma_power);
			float dark_mul = 1.0 + noise_luma_boost * dark;

			// Fade multipliers with distance if enabled
			float boost_w = mix(1.0, near_w, signal_boost_fades_with_distance);
			dark_mul   = mix(1.0, dark_mul, boost_w);
			signal_mul = mix(1.0, signal_mul, boost_w);

			strength *= dark_mul;
			strength *= signal_mul;

			// Global multiplier
			strength *= noise_strength_mul;

			// Guaranteed near blackout
			float near_mask = 1.0 - smoothstep(noise_blackout_start, noise_blackout_end, dist);
			float blackout_mul = clamp(1.0 - near_mask * noise_blackout_amount, 0.0, 1.0);

			// Grain sampling
			vec2 pixel_xy = uv * VIEWPORT_SIZE;
			float s = seed * noise_speed;

			vec2 jitter = (hash22(vec2(s, s * 0.17)) - 0.5) * noise_pixel_jitter;
			vec2 cell = floor((pixel_xy + jitter) / max(grain_size_px, 0.0001));

			float r = hash12(cell + vec2(s, s * 0.37)); // 0..1

			// Speckle shaping
			float speckle = abs(r - 0.5) * 2.0; // 0..1
			speckle = pow(max(speckle, 0.0), noise_speckle_power);

			float centered = (r - 0.5) * 2.0; // [-1..1]
			float dark_only = -speckle;       // [-1..0]
			float noise_val = mix(centered, dark_only, noise_dark_only);

			float mult = max(1.0 + noise_val * strength, 0.0);

			if (noise_apply_linear != 0) {
				vec3 lin_col = pow(max(col, vec3(0.0)), vec3(2.2));
				lin_col *= mult;
				lin_col *= blackout_mul;
				col = pow(max(lin_col, vec3(0.0)), vec3(1.0 / 2.2));
			} else {
				col *= mult;
				col *= blackout_mul;
			}

			// Fireflies
			if (firefly_amount != 0.0 && firefly_rate != 0.0 && firefly_intensity != 0.0 && lum0 >= firefly_luma_threshold) {
				float hold = max(firefly_hold_frames, 1.0);
				float tslot = floor(seed / hold);

				vec2 fcell = floor(pixel_xy / max(firefly_cell_size_px, 0.0001));
				float r_spawn = hash12(fcell + vec2(tslot, tslot * 0.37));
				float spawn = step(r_spawn, firefly_rate);

				if (spawn > 0.0) {
					vec2 center01 = hash22(fcell + vec2(tslot * 1.23, tslot * 0.91));
					vec2 cell_min = fcell * firefly_cell_size_px;
					vec2 center_px = cell_min + center01 * firefly_cell_size_px;

					float dpx = length(pixel_xy - center_px);
					float sigma = max(firefly_radius_px, 0.001);
					float blob = exp(-(dpx * dpx) / (2.0 * sigma * sigma));

					col += firefly_color * (firefly_intensity * blob) * firefly_amount;
				}
			}
		}
	}

	ALBEDO = col;
	ALPHA = 1.0;
}