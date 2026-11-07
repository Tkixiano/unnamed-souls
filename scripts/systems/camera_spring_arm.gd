extends SpringArm3D
## SpringArm performs its native shape sweep before this node's physics script.
## Contract immediately for safety; smooth only the collision-free recovery.

var minimum_distance: float = 0.55
var recovery_speed: float = 8.0
var current_distance: float = 0.0

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	current_distance = spring_length


func _physics_process(delta: float) -> void:
	var safe_distance := clampf(get_hit_length(), 0.0, spring_length)
	var wanted := maxf(minimum_distance, spring_length)
	var weight := 1.0 if recovery_speed <= 0.0 else 1.0 - exp(-recovery_speed * delta)
	# Never force a minimum through an obstruction closer than that minimum.
	current_distance = minf(safe_distance, lerpf(current_distance, wanted, weight))
	camera.position = Vector3(0, 0, current_distance)
