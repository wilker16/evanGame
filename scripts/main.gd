extends Node2D
## Entry point: input map, title screen, player-count / character-select menus,
## then spawns Game with the chosen config.  Add more characters by appending
## to CHARACTERS — the menus adapt automatically.

const GameScript := preload("res://scripts/game.gd")

# ---------------------------------------------------------------------------
# Character roster – add a new dict here when Evan draws another monster.
# ---------------------------------------------------------------------------
const CHARACTERS: Array = [
	{
		"name": "SPIKY",
		"art":  "res://art/monster_spiky.png",
		"height": 255.0,
		"color": Color("#e74c3c"),
	},
	{
		"name": "PENGUIN",
		"art":  "res://art/monster_penguin.png",
		"height": 240.0,
		"color": Color("#2465c8"),
	},
]

enum Screen { TITLE, COUNT, CHAR_SELECT, GAME }
var screen := Screen.TITLE

var title: CanvasLayer
var game: Node2D

# Title animation (process-driven; no looping Tweens to avoid web-build issues)
var _title_t       := 0.0
var _spiky_sprite:   Sprite2D
var _penguin_sprite: Sprite2D
var _press_label:    Label
var _spiky_base_y   := 0.0
var _penguin_base_y := 0.0

# Count-select menu
var _player_count := 1
var _count_sel    := 0   # 0 = 1P, 1 = 2P
var _count_layer: CanvasLayer
var _count_opts: Array = []

# Character-select menu
var _char_layer:  CanvasLayer
var _char_picking := 1   # which player is currently choosing
var _p1_char      := 0
var _p2_char      := 1
var _char_frames: Array = []
var _p1_cursor: Label
var _p2_cursor: Label
var _char_prompt:  Label

# ---------------------------------------------------------------------------
func _ready() -> void:
	_setup_inputs()
	_show_title()

func _process(delta: float) -> void:
	match screen:
		Screen.TITLE:       _proc_title(delta)
		Screen.COUNT:       _proc_count()
		Screen.CHAR_SELECT: _proc_char()

# ---- per-screen logic ------------------------------------------------------

func _proc_title(delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		_go_count()
	_title_t += delta
	if is_instance_valid(_spiky_sprite):
		_spiky_sprite.position.y  = _spiky_base_y  + sin(_title_t * 2.86) * 7.0
	if is_instance_valid(_penguin_sprite):
		_penguin_sprite.position.y = _penguin_base_y + sin(_title_t * 2.86 + PI) * 7.0
	if is_instance_valid(_press_label):
		_press_label.modulate.a = 0.575 + 0.425 * sin(_title_t * 5.71)

func _proc_count() -> void:
	if Input.is_action_just_pressed("p1_left") or Input.is_action_just_pressed("p2_left"):
		_count_sel = 0; _refresh_count()
	elif Input.is_action_just_pressed("p1_right") or Input.is_action_just_pressed("p2_right"):
		_count_sel = 1; _refresh_count()
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("p1_punch"):
		_player_count = _count_sel + 1
		_go_char_select()

func _proc_char() -> void:
	var prefix := "p1" if _char_picking == 1 else "p2"
	var cur    := _p1_char if _char_picking == 1 else _p2_char
	var other  := _p2_char if _char_picking == 1 else _p1_char

	if Input.is_action_just_pressed(prefix + "_left"):
		cur = _prev_char(cur, other)
	elif Input.is_action_just_pressed(prefix + "_right"):
		cur = _next_char(cur, other)

	if _char_picking == 1: _p1_char = cur
	else:                  _p2_char = cur
	_refresh_char()

	if Input.is_action_just_pressed(prefix + "_punch") or Input.is_action_just_pressed("ui_accept"):
		if _player_count == 2 and _char_picking == 1:
			_char_picking = 2
			_p2_char = _next_char(_p1_char, _p1_char)
			_refresh_char()
		else:
			_launch_game()

func _prev_char(cur: int, blocked: int) -> int:
	var n := CHARACTERS.size()
	var next := (cur - 1 + n) % n
	if next == blocked and n > 1:
		next = (next - 1 + n) % n
	return next

func _next_char(cur: int, blocked: int) -> int:
	var n := CHARACTERS.size()
	var next := (cur + 1) % n
	if next == blocked and n > 1:
		next = (next + 1) % n
	return next

# ---- screen builders -------------------------------------------------------

func _show_title() -> void:
	screen = Screen.TITLE
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

	_title_label("EVAN'S MONSTER RAMPAGE", 62, Color.WHITE, Vector2(0, 40),  Color("#2b3a55"))
	_title_label("SMASH THE WHOLE CITY!",  30, Color("#ffe27a"), Vector2(0, 128), Color("#2b3a55"))

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

	_title_label("PLAYER 1: SPIKY",              24, Color("#e74c3c"), Vector2(-320, 540), Color.WHITE)
	_title_label("A / D move   W jump   F punch   S duck", 18, Color("#2b3a55"), Vector2(-320, 574))
	_title_label("PLAYER 2: PENGUIN",             24, Color("#2465c8"), Vector2(320, 540), Color.WHITE)
	_title_label("ARROWS move+jump   L punch   ↓ duck",   18, Color("#2b3a55"), Vector2(320, 574))

	_press_label = _title_label("PRESS ENTER TO START", 32, Color.WHITE, Vector2(0, 630), Color("#2b3a55"))
	_title_label("All monsters drawn by Evan", 18, Color("#4a5a75"), Vector2(0, 688))

func _go_count() -> void:
	screen = Screen.COUNT
	if is_instance_valid(title):
		title.visible = false

	_count_layer = CanvasLayer.new()
	_count_layer.layer = 3
	add_child(_count_layer)

	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.15, 0.25, 0.92)
	bg.size = Vector2(1280, 720)
	_count_layer.add_child(bg)

	_menu_label("HOW MANY PLAYERS?", 52, Color.WHITE, Vector2(0, 180), _count_layer, Color("#2b3a55"))

	_count_opts = []
	for i in 2:
		var l := Label.new()
		l.text = "  %d PLAYER%s  " % [i + 1, "S" if i == 1 else ""]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.position = Vector2(160 + i * 560, 320)
		l.size = Vector2(400, 80)
		l.add_theme_font_size_override("font_size", 44)
		l.add_theme_color_override("font_color", Color.WHITE)
		l.add_theme_color_override("font_outline_color", Color("#2b3a55"))
		l.add_theme_constant_override("outline_size", 8)
		_count_layer.add_child(l)
		_count_opts.append(l)

	_count_sel = 0
	_refresh_count()
	_menu_label("A / D or ←/→ to choose   F or ENTER to confirm",
		22, Color(0.7, 0.8, 1.0), Vector2(0, 450), _count_layer)

func _refresh_count() -> void:
	for i in _count_opts.size():
		_count_opts[i].modulate = Color.WHITE if i == _count_sel else Color(0.4, 0.4, 0.4)

func _go_char_select() -> void:
	screen = Screen.CHAR_SELECT
	if is_instance_valid(_count_layer):
		_count_layer.queue_free()

	_char_layer = CanvasLayer.new()
	_char_layer.layer = 3
	add_child(_char_layer)

	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.15, 0.25, 0.95)
	bg.size = Vector2(1280, 720)
	_char_layer.add_child(bg)

	_menu_label("CHOOSE YOUR MONSTER", 48, Color.WHITE, Vector2(0, 50), _char_layer, Color("#2b3a55"))

	var n       := CHARACTERS.size()
	var card_w  := 220.0
	var spacing := 80.0
	var total   := n * card_w + (n - 1) * spacing
	var start_x := (1280.0 - total) * 0.5

	_char_frames = []
	for i in n:
		var cfg: Dictionary = CHARACTERS[i]
		var cx := start_x + i * (card_w + spacing)
		var c: Color = cfg["color"]

		var frame := ColorRect.new()
		frame.size = Vector2(card_w, 300)
		frame.position = Vector2(cx, 160)
		frame.color = Color(0.2, 0.25, 0.35, 0.8)
		_char_layer.add_child(frame)
		_char_frames.append(frame)

		var spr := Sprite2D.new()
		spr.texture = load(cfg["art"])
		spr.scale = Vector2.ONE * (180.0 / spr.texture.get_height())
		spr.position = Vector2(cx + card_w * 0.5, 285)
		_char_layer.add_child(spr)

		var nl := Label.new()
		nl.text = cfg["name"]
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.position = Vector2(cx, 472)
		nl.size = Vector2(card_w, 40)
		nl.add_theme_font_size_override("font_size", 26)
		nl.add_theme_color_override("font_color", c)
		nl.add_theme_color_override("font_outline_color", Color("#2b3a55"))
		nl.add_theme_constant_override("outline_size", 6)
		_char_layer.add_child(nl)

	_p1_cursor = Label.new()
	_p1_cursor.text = "▲ P1"
	_p1_cursor.add_theme_font_size_override("font_size", 24)
	_p1_cursor.add_theme_color_override("font_color", Color("#e74c3c"))
	_p1_cursor.add_theme_color_override("font_outline_color", Color.WHITE)
	_p1_cursor.add_theme_constant_override("outline_size", 5)
	_char_layer.add_child(_p1_cursor)

	_p2_cursor = Label.new()
	_p2_cursor.text = "▲ P2"
	_p2_cursor.visible = _player_count == 2
	_p2_cursor.add_theme_font_size_override("font_size", 24)
	_p2_cursor.add_theme_color_override("font_color", Color("#2465c8"))
	_p2_cursor.add_theme_color_override("font_outline_color", Color.WHITE)
	_p2_cursor.add_theme_constant_override("outline_size", 5)
	_char_layer.add_child(_p2_cursor)

	_char_prompt = _menu_label("P1: A / D to scroll   F or ENTER to confirm",
		22, Color(0.7, 0.8, 1.0), Vector2(0, 540), _char_layer)

	_char_picking = 1
	_p1_char = 0
	_p2_char = mini(1, CHARACTERS.size() - 1)
	_refresh_char()

func _refresh_char() -> void:
	var n       := CHARACTERS.size()
	var card_w  := 220.0
	var spacing := 80.0
	var total   := n * card_w + (n - 1) * spacing
	var start_x := (1280.0 - total) * 0.5

	for i in n:
		var frame: ColorRect = _char_frames[i]
		var c: Color = CHARACTERS[i]["color"]
		if (i == _p1_char and _char_picking == 1) or (i == _p2_char and _player_count == 2 and _char_picking == 2):
			frame.color = Color(c.r, c.g, c.b, 0.35)
		elif (i == _p1_char and _player_count == 2 and _char_picking == 2):
			frame.color = Color(c.r * 0.6, c.g * 0.6, c.b * 0.6, 0.25)  # P1 picked, dimmed
		else:
			frame.color = Color(0.2, 0.25, 0.35, 0.8)

	var cx1 := start_x + _p1_char * (card_w + spacing)
	_p1_cursor.size = Vector2(80, 30)
	_p1_cursor.position = Vector2(cx1 + card_w * 0.5 - 28, 518)

	if _player_count == 2 and is_instance_valid(_p2_cursor):
		var cx2 := start_x + _p2_char * (card_w + spacing)
		_p2_cursor.size = Vector2(80, 30)
		_p2_cursor.position = Vector2(cx2 + card_w * 0.5 - 28, 548)

	if is_instance_valid(_char_prompt):
		var keys := "A / D   F or ENTER" if _char_picking == 1 else "←/→   L to pick"
		_char_prompt.text = "P%d: %s to confirm" % [_char_picking, keys]

# Called by the CI smoke test and also used when restarting with same config.
func start_game() -> void:
	_player_count = 1
	_p1_char = 0
	_launch_game()

func _launch_game() -> void:
	screen = Screen.GAME
	if is_instance_valid(_char_layer):
		_char_layer.queue_free()
	if is_instance_valid(title):
		title.visible = false

	var chosen: Array = [CHARACTERS[_p1_char]]
	if _player_count == 2:
		chosen.append(CHARACTERS[_p2_char])

	game = GameScript.new(_player_count, chosen)
	game.restart_requested.connect(_on_restart)
	add_child(game)

func _on_restart() -> void:
	if is_instance_valid(game):
		game.queue_free()
	var chosen: Array = [CHARACTERS[_p1_char]]
	if _player_count == 2:
		chosen.append(CHARACTERS[_p2_char])
	game = GameScript.new(_player_count, chosen)
	game.restart_requested.connect(_on_restart)
	add_child(game)
	screen = Screen.GAME

# ---- helpers ---------------------------------------------------------------

func _setup_inputs() -> void:
	var keys := {
		"p1_left": KEY_A, "p1_right": KEY_D, "p1_jump": KEY_W,
		"p1_punch": KEY_F, "p1_duck": KEY_S,
		"p2_left": KEY_LEFT, "p2_right": KEY_RIGHT, "p2_jump": KEY_UP,
		"p2_punch": KEY_L, "p2_duck": KEY_DOWN,
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = keys[action]
		InputMap.action_add_event(action, ev)

func _menu_label(text: String, size: int, color: Color, pos: Vector2,
		layer: CanvasLayer, outline := Color.TRANSPARENT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = pos
	l.size = Vector2(1280, 60)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline.a > 0.0:
		l.add_theme_color_override("font_outline_color", outline)
		l.add_theme_constant_override("outline_size", 8)
	layer.add_child(l)
	return l

func _title_label(text: String, size: int, color: Color, offset: Vector2,
		outline := Color.TRANSPARENT) -> Label:
	return _menu_label(text, size, color, offset, title, outline)

func _circle_points(radius: float, n: int = 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts
