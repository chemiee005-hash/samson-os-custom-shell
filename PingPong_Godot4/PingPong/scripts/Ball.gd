extends CharacterBody2D
class_name Ball
## Ball.gd  (attach to: Ball (CharacterBody2D) in Ball.tscn)
##
## TASK 2 - Game loop separation
##   _physics_process(delta): velocity, speed-up, wall/paddle collision + bounce, out-of-bounds checks
##   _process(delta)       : lifetime timer, colour/blink effects (non-physics)
##
## TASK 6 - Cleanup
##   Extra balls call queue_free() (via despawn()) when they: leave the arena, expire, score, or on
##   round reset. queue_free() schedules deletion at the end of the frame (safe inside callbacks).

@export var start_speed: float = 420.0
@export var max_speed: float = 950.0
@export var speed_gain_per_paddle_hit: float = 1.05
@export var max_bounce_y: float = 0.75
@export var extra_ball_lifetime: float = 20.0
@export var radius: float = 8.0

# Set by BallSpawner BEFORE add_child() so _ready() sees the right values.
var is_extra: bool = false

var in_play: bool = false
var current_speed: float = 0.0
var last_hitter_id: int = 0   # 0 = no paddle touched yet; used by PowerUp to know who collected it

var _lifetime: float = 0.0
var _base_color: Color = Color.WHITE

const OUT_MARGIN := 150.0


func _ready() -> void:
	add_to_group("balls")
	_base_color = Color(1.0, 0.85, 0.3) if is_extra else Color.WHITE
	modulate = _base_color
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color.WHITE)


func launch(direction: Vector2) -> void:
	current_speed = start_speed
	velocity = direction.normalized() * current_speed
	in_play = true


func stop() -> void:
	in_play = false
	velocity = Vector2.ZERO


# ---------------------------------------------------------------------------
# PHYSICS LOOP: movement, speed calculations, collisions
# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if not in_play:
		return

	# move_and_collide() moves along velocity and reports the first hit.
	var collision := move_and_collide(velocity * delta)
	if collision:
		var collider := collision.get_collider()
		var normal := collision.get_normal()
		if collider is Paddle:
			_bounce_off_paddle(collider, normal)          # paddle bounce
		else:
			velocity = velocity.bounce(normal).normalized() * current_speed   # wall bounce

	_check_out_of_bounds()


func _bounce_off_paddle(paddle: Paddle, normal: Vector2) -> void:
	# Where on the paddle did we hit? -1 (top) .. +1 (bottom) -> controls the return angle.
	var offset := clampf((global_position.y - paddle.global_position.y) / paddle.get_half_height(), -1.0, 1.0)
	var dir_x := signf(normal.x)
	if absf(normal.x) < 0.1:          # grazed top/bottom edge: keep flying away from that side
		dir_x = -signf(velocity.x)
	current_speed = minf(current_speed * speed_gain_per_paddle_hit, max_speed)   # speed calc
	velocity = Vector2(dir_x, offset * max_bounce_y).normalized() * current_speed
	last_hitter_id = paddle.player_id


func _check_out_of_bounds() -> void:
	var size := get_viewport_rect().size
	var p := global_position
	if p.x < -OUT_MARGIN or p.x > size.x + OUT_MARGIN or p.y < -OUT_MARGIN or p.y > size.y + OUT_MARGIN:
		if is_extra:
			despawn("left the arena")          # TASK 6: extra ball left play -> free it
		else:
			# Safety net for the main ball: put it back in the middle.
			global_position = size * 0.5
			launch(Vector2(1.0 if randf() < 0.5 else -1.0, randf_range(-0.3, 0.3)))


# ---------------------------------------------------------------------------
# GAME LOOP (per-frame): lifetime timer + visuals (NOT physics)
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	_lifetime += delta

	var tint := _base_color
	if is_extra:
		var remaining := extra_ball_lifetime - _lifetime
		if remaining <= 0.0:
			despawn("lifetime expired")        # TASK 6: timed cleanup
			return
		if remaining < 3.0:
			tint.a = 0.4 + 0.6 * absf(sin(_lifetime * 14.0))   # blink before disappearing
	else:
		# Main ball turns redder as it speeds up.
		tint = tint.lerp(Color(1.0, 0.4, 0.4), clampf(current_speed / max_speed, 0.0, 1.0))
	modulate = tint


# ---------------------------------------------------------------------------
# TASK 6: Memory cleanup
# ---------------------------------------------------------------------------
func despawn(reason: String) -> void:
	if is_queued_for_deletion():
		return
	# DEBUG SNIPPET: node count before this ball is removed. Compare with the next
	# "[Debug]" line printed by GameManager - the count must go DOWN, not keep growing.
	print("[Ball] queue_free (%s) | nodes before free: %d" % [reason, get_tree().get_node_count()])
	queue_free()
