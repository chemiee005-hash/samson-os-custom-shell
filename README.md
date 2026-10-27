# Ping Pong - Godot 4 (6-task rubric demo)

Open the `PingPong` folder as a project in Godot 4.2+ (or copy `scripts/` + `scenes/` into your own
project and see "Using your own project" below). Edit scripts in VS Code with the Godot Tools extension.
Press F5 (or the Play button) - main scene is `scenes/Main.tscn`.

## Controls
| Action | P1 | P2 |
|---|---|---|
| Move (polled) | W / S | Up / Down |
| Boost (event) | D | Left arrow |
| Serve / Rematch (event) | Space | |
| Pause (event) | Esc | |
| Spawn 3 more balls (event) | M | |

## Input Map (Project > Project Settings > Input Map)
Create these actions (GameManager.gd also auto-creates any that are missing, with these defaults):

| Action | Default key |
|---|---|
| p1_up | W |
| p1_down | S |
| p1_boost | D |
| p2_up | Up |
| p2_down | Down |
| p2_boost | Left |
| serve | Space |
| pause | Escape |
| multiball | M |

## Autoload (required)
Project Settings > Globals > Autoload: add `res://scripts/LevelManager.gd` with the name **LevelManager**
(already set in the supplied project.godot).

## Collision layers used
| Thing | Layer | Mask |
|---|---|---|
| Paddle, Walls | 1 | 0 |
| Ball | 2 | 1 (hits paddles + walls; balls don't hit each other) |
| PowerUp | 4 | 2 (detects balls) |
| Goal | 0 | 2 (detects balls) |

## Scene trees and script attachments

Main.tscn
```
Main (Node2D)                       - no script
|- GameManager (Node)               - GameManager.gd   (process_mode = Always)
|- BallSpawner (Node2D)             - BallSpawner.gd   (positioned at 0,0)
|- Arena (Node2D)
|  |- CenterLine (Line2D)
|  `- Walls (StaticBody2D)
|     |- TopWall (CollisionShape2D)
|     `- BottomWall (CollisionShape2D)
|- Paddle1 (instance of Paddle.tscn)  player_id = 1, position (40, 324)
|- Paddle2 (instance of Paddle.tscn)  player_id = 2, position (1112, 324)
|- GoalLeft  (instance of Goal.tscn)  position (-30, 324)
|- GoalRight (instance of Goal.tscn)  position (1182, 324)
`- UI (instance of UI.tscn)
```
Paddle.tscn
```
Paddle (CharacterBody2D)            - Paddle.gd
`- CollisionShape2D (RectangleShape2D 16x100)
```
Ball.tscn
```
Ball (CharacterBody2D)              - Ball.gd
`- CollisionShape2D (CircleShape2D r=8)
```
PowerUp.tscn
```
PowerUp (Area2D)                    - PowerUp.gd
`- CollisionShape2D (CircleShape2D r=14)
```
Goal.tscn
```
Goal (Area2D)                       - no script (GameManager connects body_entered in code)
`- CollisionShape2D (RectangleShape2D 60x900)
```
UI.tscn
```
UI (CanvasLayer, process_mode Always) - UI.gd
|- ScoreP1 (Label)
|- ScoreP2 (Label)
|- Message (Label)
|- DebugLabel (Label)
`- PauseMenu (Control, hidden)
   |- Dim (ColorRect)
   `- Buttons (VBoxContainer)
      |- ResumeButton (Button)
      `- RestartButton (Button)
```
Autoload: LevelManager (Node) - LevelManager.gd (builds its own loading overlay in code)

## Rubric map
| Task | Where |
|---|---|
| 1 Scene instancing | BallSpawner.gd (spawn_ball / spawn_multiball / spawn_powerup; 3 balls live after serve) |
| 2 Game loop split | Paddle.gd, Ball.gd (_physics_process vs _process, commented) |
| 3 Responsive main thread | LevelManager.gd (load_threaded_request, call_deferred, fade + progress bar) |
| 4 Signals | `.connect()` in GameManager._ready, PowerUp._ready, BallSpawner.spawn_powerup, UI._ready; custom signals: point_scored, match_over, paused_changed, state_changed, collected, powerup_collected, restart_requested |
| 5 Polling vs events | Paddle.gd (get_axis polled; boost via _unhandled_input), GameManager.gd (Esc/Space/M via _unhandled_input) |
| 6 Cleanup | Ball.despawn(), PowerUp.despawn() -> queue_free(); node count in Output panel + top-left label |

## Verifying cleanup (Task 6)
Watch the Output panel while playing:
```
[Debug] total nodes=34 | balls=3 | powerups=2
[Ball] queue_free (scored in goal) | nodes before free: 34
[PowerUp] queue_free (collected) | nodes before free: 33
[Debug] total nodes=31 | balls=2 | powerups=1
```
Node count rises when things spawn and falls when they are freed; across many rounds it should stay in a
stable range. The same numbers are shown live in the top-left debug label.

## Using your own project
Copy `scripts/` and `scenes/` into your project, add the LevelManager autoload, set Main.tscn as the main
scene, and set the window to 1152x648.
