# Test rotation values with manual control
extends Node3D

@export var skeleton_path: NodePath
@export var test_bone_name: String = "elbow"  # Bone to test rotations on
@export var test_rotation_degrees: Vector3 = Vector3(0.0, 0.0, 0.0)  # Euler angles in degrees
@export var apply_test_rotation: bool = true  # Toggle this to apply the test rotation
@export var print_rotation_values: bool = true  # Toggle this to print current values

var skeleton: Skeleton3D

# Add this to your test script
@export var animation_player_path: NodePath = NodePath("../../AnimationPlayer")
var animation_player: AnimationPlayer
func _ready():
	skeleton_path = get_path()
	skeleton = get_node(skeleton_path) as Skeleton3D
	
	if animation_player_path:
		animation_player = get_node(animation_player_path) as AnimationPlayer

func _process(_delta):
	if apply_test_rotation or print_rotation_values:
		test_rotation_values()
		# Reset flags to prevent continuous application
		apply_test_rotation = false
		print_rotation_values = false

func test_rotation_values():
	if not skeleton:
		print("Skeleton not found!")
		return
		
	var bone_idx = skeleton.find_bone(test_bone_name)
	if bone_idx == -1:
		print("Test bone not found: ", test_bone_name)
		return
	
	# Apply test rotation if requested
	if apply_test_rotation:
		# Pause animation temporarily
		if animation_player:
			animation_player.pause()
		var euler_radians = Vector3(
			deg_to_rad(test_rotation_degrees.x),
			deg_to_rad(test_rotation_degrees.y),
			deg_to_rad(test_rotation_degrees.z)
		)
		var test_rotation = Basis.from_euler(euler_radians)
		var current_pose = skeleton.get_bone_pose(bone_idx)
		current_pose.basis = current_pose.basis * test_rotation
		skeleton.set_bone_pose(bone_idx, current_pose)
		print("Applied test rotation: ", test_rotation_degrees, " degrees")
	
	# Print current rotation values if requested
	if print_rotation_values:
		var pose = skeleton.get_bone_pose(bone_idx)
		var quat = pose.basis.get_rotation_quaternion()
		var euler_degrees = pose.basis.get_euler() * 180.0 / PI
		
		# Get rotation in elbow's local space
		var humerus_idx = skeleton.find_bone("humerus")  # Replace with your elbow bone name
		var humerus_to_elbow_quat = Quaternion.IDENTITY
		
		if humerus_idx != -1:
			# Calculate relative rotation from elbow to hand (same as your main script)
			var humerus_global = skeleton.get_bone_global_pose(humerus_idx)
			var elbow_global = skeleton.get_bone_global_pose(bone_idx)
			var current_relative = humerus_global.basis.get_rotation_quaternion().inverse() * elbow_global.basis.get_rotation_quaternion()
			
			var elbow_rest_global = skeleton.get_bone_global_rest(humerus_idx)
			var hand_rest_global = skeleton.get_bone_global_rest(bone_idx)
			var rest_relative = elbow_rest_global.basis.get_rotation_quaternion().inverse() * hand_rest_global.basis.get_rotation_quaternion()
			
			humerus_to_elbow_quat = rest_relative.inverse() * current_relative
		
		print("=== Rotation Analysis for bone: ", test_bone_name, " ===")
		print("Global quaternion (w,x,y,z): ", quat.w, ", ", quat.x, ", ", quat.y, ", ", quat.z)
		print("Global Y coefficient: ", quat.y)
		print("Elbow-space quaternion (w,x,y,z): ", humerus_to_elbow_quat.w, ", ", humerus_to_elbow_quat.x, ", ", humerus_to_elbow_quat.y, ", ", humerus_to_elbow_quat.z)
		print("Elbow-space Y coefficient: ", humerus_to_elbow_quat.y)
		print("Expected Y coeff for ", test_rotation_degrees.y, "° Y rotation: ", sin(deg_to_rad(test_rotation_degrees.y) / 2.0))
		print("==============================================")
