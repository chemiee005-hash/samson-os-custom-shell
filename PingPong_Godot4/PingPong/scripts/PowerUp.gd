extends Area2D
class_name PowerUp
## PowerUp.gd  (attach to: PowerUp (Area2D) in PowerUp.tscn)
##
## A pickup that sits on the table. A Ball touching it "collects" it.
## TASK 6: the pickup frees itself with queue_free() when collected OR when it expires.
## TASK 4: body_entered is connected from code (.connect) and we declare a custom signal.

## Custom signal (interrupt-style): fired the instant the pickup is consumed.
signal collected(type: int, player_id: int, pos: Vector2)

enum Type { GROW_PADDLE, MULTIBALL, SHRINK_OPPONENT }

@export var lifetime: float = 10.0
@export var radius: float = 14.0

# Set by BallSpawner before add_child().
var type: int = Type.GROW_PADDLE

var _age := 0.0
var _consumed := false


func _ready() -> void:
	add_to_group("powerups")
	# Programmatic signal connection: the physics engine "interrupts" us when a body overlaps.
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _draw() -> void:
	var c := Color(0.3, 1.0, 0.4)
	match type:
		Type.MULTIBALL: c = Color(1.0, 0.9, 0.2)
		Type.SHRINK_OPPONENT: c = Color(1.0, 0.35, 0.35)
	draw_circle(Vector2.ZERO, radius, c)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color.WHITE, 2.0)


func _process(delta: float) -> void:
	# Non-physics logic: expiry timer + fade-out effect.
	_age += delta
	var remaining := lifetime - _age
	if remaining <= 0.0:
		despawn("expired")
		return
	modulate.a = 0.35 + 0.65 * absf(sin(_age * 12.0)) if remaining < 2.0 else 1.0


func _on_body_entered(body: Node2D) -> void:
	if _consumed or not (body is Ball):
		return
	var ball := body as Ball
	if ball.last_hitter_id == 0:
		return   # nobody owns this ball yet -> nobody gets the reward
	_consumed = true                                   # guard: two balls in the same frame
	collected.emit(type, ball.last_hitter_id, global_position)
	despawn("collected")                               # TASK 6: consumed -> free it


func despawn(reason: String) -> void:
	if is_queued_for_deletion():
		return
	print("[PowerUp] queue_free (%s) | nodes before free: %d" % [reason, get_tree().get_node_count()])
	queue_free()
