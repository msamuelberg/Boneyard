extends Node3D
class_name SwingTwistInterpolator

@export var skeleton_path: NodePath
@export var elbow_bone_name: String = "elbow"
@export var hand_bone_name: String = "hand" 
@export var twist_bone_names: Array[String] = ["twist1", "twist2", "twist3", "twist4"]
# twist_axis sohuld be given as a normalized vector.
@export var twist_axis: Vector3 = Vector3(0.0, 1.0 , 0.0) # Y-axis points down the length of the bone, i.e Y is the axis we want to twist around

# New control vector for twist offset
@export var twist_control_vector: Vector3 = Vector3(0.0, 1.0 , 0.0) # Reference direction for twist control
@export var twist_offset_degrees: float = 0.0  # Offset in degrees to control where twist interpolation happens
@export var enable_quaternion_flip_prevention: bool = true  # Enable smart quaternion selection

var skeleton: Skeleton3D
var elbow_bone_idx: int
var hand_bone_idx: int
var twist_bone_indices: Array[int] = []

func _ready():
	setup_bones()

func setup_bones():
	skeleton_path = get_path()
	skeleton = get_node(skeleton_path) as Skeleton3D
	if not skeleton_path:
		push_error("Skeleton not found at path: " + str(skeleton_path))
		return
	
	elbow_bone_idx = skeleton.find_bone(elbow_bone_name)
	hand_bone_idx = skeleton.find_bone(hand_bone_name)
	
	if elbow_bone_idx == -1:
		push_error("Elbow bone not found: " + elbow_bone_name)
		return
	
	if hand_bone_idx == -1:
		push_error("Hand bone not found: " + hand_bone_name)
		return

	for twist_name in twist_bone_names:
		var twist_idx = skeleton.find_bone(twist_name)
		if twist_idx != -1:
			twist_bone_indices.append(twist_idx)
		else:
			push_warning("Twist bone not found: " + twist_name)


func get_twist(q : Quaternion, axis : Vector3) -> Quaternion:
	# This assumes normalized quaternions
	var p :Vector3 = Vector3(q.x,q.y,q.z).dot(axis) * axis
	var twist :Quaternion= Quaternion(p.x, p.y, p.z,q.w).normalized()
	return twist
	
func get_swing(q : Quaternion, axis : Vector3) -> Quaternion:
	var twist := get_twist(q,axis)
	var swing := -(q.inverse() * twist)	
	return swing

# Get the relative rotation from elbow to hand
func get_elbow_to_hand_rotation() -> Quaternion:
	# Get the hand's current rotation in elbow's local space
	var elbow_global = skeleton.get_bone_global_pose(elbow_bone_idx)
	var hand_global = skeleton.get_bone_global_pose(hand_bone_idx)
	var current_relative = elbow_global.basis.get_rotation_quaternion().inverse() * hand_global.basis.get_rotation_quaternion()
	
	# Get the hand's rest rotation in elbow's local space
	var elbow_rest_global = skeleton.get_bone_global_rest(elbow_bone_idx)
	var hand_rest_global = skeleton.get_bone_global_rest(hand_bone_idx)
	var rest_relative = elbow_rest_global.basis.get_rotation_quaternion().inverse() * hand_rest_global.basis.get_rotation_quaternion()
	
	# Delta is current relative rotation minus rest relative rotation
	var delta_rotation = rest_relative.inverse() * current_relative
	
	return delta_rotation

# Apply twist interpolation
func apply_twist_interpolation(debug_enable: bool):
	var start_time = Time.get_ticks_usec() if debug_enable else 0
	
	if twist_bone_indices.is_empty():
		return
	
	# Get the rotation from elbow to hand
	var elbow_to_hand_rotation = get_elbow_to_hand_rotation()
	
	var twist_rotation = get_twist(elbow_to_hand_rotation, twist_axis)
	
	# Distribute twist across the joints
	for i in range(twist_bone_indices.size()):
		var bone_idx = twist_bone_indices[i]
		
		# Interpolation factor (could be a 2d curve instead)
		var t = float(i + 1) / float(twist_bone_indices.size() + 1)
		
		var identity = Quaternion.IDENTITY
		var partial_twist_quat = identity.slerp(twist_rotation, t)
		
		# Get current pose and apply twist (replace rotation, preserve position)
		var current_pose = skeleton.get_bone_pose(bone_idx)
		current_pose.basis = Basis(partial_twist_quat)
		skeleton.set_bone_pose(bone_idx, current_pose)

	if debug_enable:
		var end_time = Time.get_ticks_usec()
		var evaluation_time_us = end_time - start_time
		debug_swing_twist(evaluation_time_us)

# Automatic update
func _process(_delta):
	apply_twist_interpolation(true)

# Debug function to visualize the decomposition with performance timing
func debug_swing_twist(evaluation_time_us: int = 0):
	var rotation = get_elbow_to_hand_rotation()
	var twist = get_twist(rotation, twist_axis)
	var swing = get_swing(rotation, twist_axis)
	
	print("=== Swing-Twist Debug Info ===")
	print("Original rotation: ", rotation)
	print("Swing component: ", swing)
	print("Twist component: ", twist)
	print("Reconstructed: ", swing * twist)
	
	if evaluation_time_us > 0:
		print("Evaluation time this frame: ", evaluation_time_us, " microseconds")
	print("==============================")
