extends Node2D
class_name BallSpawner
## BallSpawner.gd  (attach to: BallSpawner (Node2D) in Main.tscn)
##
## TASK 1 - Scene instancing as "processes"
##
##   A .tscn file (Ball.tscn, PowerUp.tscn) is like a PROGRAM on disk: a static blueprint describing
##   which nodes exist, their properties and scripts. It does nothing by itself.
##
##   preload()/load() copies that blueprint into memory as a PackedScene (the loaded "executable image").
##
##   PackedScene.instantiate() is like LAUNCHING the program: it builds a brand-new, independent tree of
##   nodes in memory - a running PROCESS. Each instance has its own variables (own velocity, own timers).
##
##   add_child() is like handing the process to the scheduler: only nodes inside the SceneTree get
##   _ready(), _process(), _physics_process() calls and take part in physics.
##
##   queue_free() is like process EXIT: the instance is destroyed and its memory reclaimed. The .tscn on
##   disk is untouched, and you can spawn as many new instances from it as you like.
##
## With multiball enabled there are 3 live Ball instances at once (1 main + 2 extra) - all spawned from the
## SAME Ball.tscn blueprint. PowerUp pickups are spawned the same way (up to 3 at once).

## TASK 4: custom signal re-emitted so GameManager only needs to listen to the spawner.
signal powerup_collected(type: int, player_id: int, pos: Vector2)

@export var ball_scene: PackedScene = preload("res://scenes/Ball.tscn")
@export var powerup_scene: PackedScene = preload("res://scenes/PowerUp.tscn")


func arena_center() -> Vector2:
	return get_viewport_rect().size * 0.5


func random_table_position() -> Vector2:
	var s := get_viewport_rect().size
	return Vector2(randf_range(s.x * 0.25, s.x * 0.75), randf_range(80.0, s.y - 80.0))


## Create ONE ball process. It is NOT launched here; the caller decides when (serve vs. instant).
func spawn_ball(pos: Vector2, extra: bool = false) -> Ball:
	var ball := ball_scene.instantiate() as Ball      # launch a new "process" from the blueprint
	ball.is_extra = extra                              # configure BEFORE it enters the tree (_ready reads it)
	ball.position = pos                                # spawner sits at (0,0) in Main, so local == global
	# call_deferred: spawn requests can arrive inside a physics callback (e.g. a power-up
	# collision). Adding physics bodies while the physics server is flushing queries is an error,
	# so we add the node safely at the end of the frame.
	add_child.call_deferred(ball)
	return ball


## Multi-ball mode: spawn `count` extra balls at once, flying in random directions.
func spawn_multiball(count: int, origin: Vector2 = Vector2.INF) -> Array[Ball]:
	var spawned: Array[Ball] = []
	var at := arena_center() if origin == Vector2.INF else origin
	for i in count:
		var ball := spawn_ball(at, true)
		var dir := Vector2(1.0 if randf() < 0.5 else -1.0, 0.0).rotated(randf_range(-0.6, 0.6))
		ball.launch(dir)
		spawned.append(ball)
	return spawned


func spawn_powerup(pos: Vector2, type: int = -1) -> PowerUp:
	var p := powerup_scene.instantiate() as PowerUp
	p.type = type if type >= 0 else randi() % PowerUp.Type.size()
	p.position = pos
	# TASK 4: connect a signal from code with .connect()
	p.collected.connect(_on_powerup_collected)
	add_child.call_deferred(p)
	return p


## Free every ball and pickup (used on round reset). Each despawn() calls queue_free().
func clear_all() -> void:
	for b in get_tree().get_nodes_in_group("balls"):
		b.despawn("round reset")
	for p in get_tree().get_nodes_in_group("powerups"):
		p.despawn("round reset")


func _on_powerup_collected(type: int, player_id: int, pos: Vector2) -> void:
	powerup_collected.emit(type, player_id, pos)
