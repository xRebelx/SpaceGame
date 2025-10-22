## bullet.gd — projectile logic (spawned by Weapon.shoot)
## Chain: Player.gd -> Weapon.shoot() [Weapon.gd] -> bullet.gd (this file)
extends Area2D

@export var speed: float = 1000.0                  # units/sec
@export var max_travel_distance: float = 1200.0    # despawn after this distance

var direction: Vector2 = Vector2.RIGHT             # set by Weapon.shoot()
var _travelled := 0.0

func initialize(dir: Vector2) -> void:
	# Called by Weapon to set direction in one call.
	direction = dir.normalized()
	rotation = direction.angle()

func _ready() -> void:
	# If direction was set directly (not via initialize), align rotation anyway.
	if direction != Vector2.ZERO:
		rotation = direction.angle()

func _physics_process(delta: float) -> void:
	var move := direction.normalized() * speed * delta
	global_position += move
	_travelled += move.length()
	if _travelled >= max_travel_distance:
		queue_free()

func _on_body_entered(_body: Node) -> void:
	# TODO: apply damage via a damage system if/when we add one.
	queue_free()
