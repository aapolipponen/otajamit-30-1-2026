# PlayerController.gd
extends CharacterBody3D

#===============================================================================
# Movement inspired by Half Life games ( VALVE )
#===============================================================================

# Walk / Sprint variables
@export var BASE_SPEED := 5.0
@export var SPRINT_SPEED := 10.0
var SPEED := BASE_SPEED
var DIRECTION := Vector3.ZERO
const LERP_SPEED := 10.0

# Jump variables
var JUMPS_REMAINING := 1
@export var JUMP_VELOCITY := 4.5

# Camera look and mouse variables
var mouse_input : bool = false
var rotation_input : float
var tilt_input : float

# Rotation variables
var mouse_rotation := Vector3.ZERO
var player_rotation := Vector3.ZERO
var camera_rotation := Vector3.ZERO

# Exported camera settings
@export var MOUSE_SENSITIVITY := 0.5
@export var TILT_UPPER_LIMIT := deg_to_rad(90.0)
@export var TILT_LOWER_LIMIT := deg_to_rad(-90.0)
@export var CAMERA_CONTROLLER : Camera3D

# Head bob variables
@export var BOB_FREQUENCY := 8.0
@export var BOB_AMPLITUDE := 0.05
var bob_time := 0.0
var camera_start_pos : Vector3

# Gravity
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

#===============================================================================

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	camera_start_pos = CAMERA_CONTROLLER.position

#===============================================================================

func _unhandled_input(event):
	mouse_input = event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED

	if mouse_input:
		rotation_input = -event.relative.x * MOUSE_SENSITIVITY
		tilt_input = -event.relative.y * MOUSE_SENSITIVITY

func _input(event):
	if event.is_action_pressed("exit"):
		get_tree().quit()

#===============================================================================

func _update_camera(delta):
	mouse_rotation.x += tilt_input * delta
	mouse_rotation.x = clamp(mouse_rotation.x, TILT_LOWER_LIMIT, TILT_UPPER_LIMIT)
	mouse_rotation.y += rotation_input * delta

	# Player yaw
	global_transform.basis = Basis.from_euler(Vector3(0.0, mouse_rotation.y, 0.0))

	# Camera pitch
	CAMERA_CONTROLLER.rotation.x = mouse_rotation.x
	CAMERA_CONTROLLER.rotation.z = 0.0

	rotation_input = 0.0
	tilt_input = 0.0

#===============================================================================

func _sprint():
	if Input.is_action_pressed("sprint") and is_on_floor():
		SPEED = SPRINT_SPEED
	else:
		SPEED = BASE_SPEED

func _jump():
	if Input.is_action_just_pressed("jump") and (is_on_floor() or JUMPS_REMAINING > 0):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
		else:
			velocity.y = JUMP_VELOCITY * 0.8
			JUMPS_REMAINING -= 1

	if is_on_floor():
		JUMPS_REMAINING = 0

#===============================================================================

func _head_bob(delta):
	if is_on_floor() and Vector2(velocity.x, velocity.z).length() > 0.1:
		bob_time += delta * BOB_FREQUENCY * (SPEED / BASE_SPEED)
		var bob_offset = sin(bob_time) * BOB_AMPLITUDE
		CAMERA_CONTROLLER.position.y = camera_start_pos.y + bob_offset
	else:
		bob_time = 0.0
		CAMERA_CONTROLLER.position.y = lerp(
			CAMERA_CONTROLLER.position.y,
			camera_start_pos.y,
			delta * LERP_SPEED
		)

#===============================================================================

func _physics_process(delta):
	_update_camera(delta)

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	_sprint()
	_jump()

	# Direction input
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	DIRECTION = lerp(
		DIRECTION,
		(transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(),
		delta * LERP_SPEED
	)

	# Movement
	if DIRECTION:
		velocity.x = DIRECTION.x * SPEED
		velocity.z = DIRECTION.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	_head_bob(delta)

#===============================================================================
# Developed by Gordon-DevJ.
# Updated & refined with Source-style movement and camera feel.
# Version 1.1.0
#===============================================================================
