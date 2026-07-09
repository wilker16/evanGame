extends Node2D
## Entry point: sets up the input map, shows the title screen, starts/restarts games.

const GameScript := preload("res://scripts/game.gd")

var title: CanvasLayer
var game: Node2D
var title_active := false

# Title-screen animation state (driven by _process to avoid Tween web-build issues).
var _title_t := 0.0
var _spiky_sprite: Sprite2D
var _penguin_sprite: Sprite2D
var _press_label: Label
var _spiky_base_y := 0.0
var _penguin_base_y := 0.0
var _press_base_a := 1.0

func _ready() -> void:
	_setup_inputs()
	_show_title()

func _process(delta: float) -> void:
	if title_active and Input.is_action_just_pressed("ui_accept"):
		start_game()
	# Animate title sprites and blink label without Tweens.
	if title_active:
		_title_t += delta
		if is_instance_valid(_spiky_sprite):
			_spiky_sprite.position.y = _spiky_base_y + sin(_title_t * 2.86) * 7.0
		if is_instance_valid(_penguin_sprite):
			_penguin_sprite.position.y = _penguin_base_y + sin(_title_t * 2.86 + PI) * 7.0
		if is_instance_valid(_press_label):
			_press_label.modulate.a = 0.575 + 0.425 * sin(_title_t * 5.71)

func _setup_inputs() -> void:
	var keys := {
		"p1_left": KEY_A, "p1_right": KEY_D, "p1_jump": KEY_W, "p1_punch": KEY_F,
		"p2_left": KEY_LEFT, "p2_right": KEY_RIGHT, "p2_jump": KEY_UP, "p2_punch": KEY_L,
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = keys[action]
		InputMap.action_add_event(action, ev)

func start_game() -> void:
	title_active = false
	if is_instance_valid(title):
		title.visible = false
	if is_instance_valid(game):
		game.queue_free()
	game = GameScript.new()
	game.restart_requested.connect(_on_restart)
	add_child(game)

func _on_restart() -> void:
	start_game()

func _show_title() -> void:
	title = CanvasLayer.new()
	add_child(title)

	var sky := ColorRect.new()
	sky.color = Color("#87c9f2")
	sky.size = Vector2(1280, 720)
	title.add_child(sky)

	var sun := Polygon2D.new()
	sun.polygon = _circle_points(56.0)
	sun.color = Color("#ffe27a")
	sun.position = Vector2(1130, 120)
	title.add_child(sun)

	var grass := ColorRect.new()
	grass.color = Color("#79b756")
	grass.position = Vector2(0, 656)
	grass.size = Vector2(1280, 64)
	title.add_child(grass)

	_title_label("EVAN'S MONSTER RAMPAGE", 62, Color.WHITE, Vector2(0, 40), Color("#2b3a55"))
	_title_label("SMASH THE WHOLE CITY!", 30, Color("#ffe27a"), Vector2(0, 128), Color("#2b3a55"))

	_spiky_sprite = Sprite2D.new()
	_spiky_sprite.texture = load("res://art/monster_spiky.png")
	_spiky_sprite.scale = Vector2.ONE * (300.0 / _spiky_sprite.texture.get_height())
	_spiky_sprite.position = Vector2(320, 400)
	_spiky_base_y = _spiky_sprite.position.y
	title.add_child(_spiky_sprite)

	_penguin_sprite = Sprite2D.new()
	_penguin_sprite.texture = load("res://art/monster_penguin.png")
	_penguin_sprite.scale = Vector2.ONE * (320.0 / _penguin_sprite.texture.get_height())
	_penguin_sprite.position = Vector2(960, 400)
	_penguin_base_y = _penguin_sprite.position.y
	title.add_child(_penguin_sprite)

	_title_label("PLAYER 1: SPIKY", 24, Color("#e74c3c"), Vector2(-320, 540), Color.WHITE)
	_title_label("A / D move   W jump   F punch", 20, Color("#2b3a55"), Vector2(-320, 574))
	_title_label("PLAYER 2: PENGUIN", 24, Color("#2465c8"), Vector2(320, 540), Color.WHITE)
	_title_label("ARROWS move + jump   L punch", 20, Color("#2b3a55"), Vector2(320, 574))

	_press_label = _title_label("PRESS ENTER TO START", 32, Color.WHITE, Vector2(0, 630), Color("#2b3a55"))

	_title_label("All monsters drawn by Evan", 18, Color("#4a5a75"), Vector2(0, 688))
	title_active = true

## Centered label; x_offset shifts the center. Returns the Label.
func _title_label(text: String, size: int, color: Color, offset: Vector2, outline := Color.TRANSPARENT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(offset.x, offset.y)
	l.size = Vector2(1280, 60)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline.a > 0.0:
		l.add_theme_color_override("font_outline_color", outline)
		l.add_theme_constant_override("outline_size", 8)
	title.add_child(l)
	return l

func _circle_points(radius: float, n: int = 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts
