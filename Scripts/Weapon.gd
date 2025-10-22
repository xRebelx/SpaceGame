## Weapon.gd — spawns projectiles; ONLY deals with shooting
## Chain: Player.gd -> Weapon.shoot() -> bullet.gd
extends Node2D

@export var bullet_scene: PackedScene
@onready var muzzle: Node2D = $Muzzle if has_node("Muzzle") else null

func shoot(direction: Vector2) -> void:
	# Do nothing if the scene is not set
	if bullet_scene == null:
		push_warning("Weapon.shoot() called without bullet_scene set.")
		return

	var bullet := bullet_scene.instantiate()
	bullet.top_level = true                  # ignore our transform (avoid double-rotation)
	bullet.global_position = muzzle.global_position if muzzle else global_position

	# Prefer initialize() if present. Our Bullet implements it.
	if bullet.has_method("initialize"):
		bullet.initialize(direction)
	else:
		bullet.direction = direction.normalized()
		bullet.rotation = direction.angle()

	# Spawn under a dedicated 'projectiles' group root if present; otherwise scene root.
	var parent := get_tree().get_first_node_in_group("projectiles")
	if parent == null:
		parent = get_tree().current_scene
	parent.add_child(bullet)
