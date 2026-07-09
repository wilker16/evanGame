extends Node2D
## One round of Monster Rampage: a fresh city, two monsters, an angry army.
## Built entirely in code so the whole game lives in readable scripts.

signal restart_requested

const MonsterScript := preload("res://scripts/monster.gd")
const BuildingScript := preload("res://scripts/building.gd")
const TankScript := preload("res://scripts/tank.gd")
const HeliScript := preload("res://scripts/helicopter.gd")
const BulletScript := preload("res://scripts/bullet.gd")

const GROUND_Y := 640.0
const VIEW_W := 1280.0
const CHUNK_POINTS := 10
const COLLAPSE_POINTS := 100
const VEHICLE_POINTS := 50
const MAX_TANKS := 2
const MAX_HELIS := 2

const PALETTE: Array = [
	Color("#c96a5a"), Color("#8ea0b8"), Color("#d8b36a"),
	Color("#7fb2a3"), Color("#b48ec9"), Color("#d88f6a"),
]
const P1_COLOR := Color("#e74c3c")
const P2_COLOR := Color("#2465c8")

var monsters: Array = []
var buildings: Array = []
var enemies: Array = []
var scores := {1: 0, 2: 0}
var won := false
var spawn_interval := 5.0

var hud: CanvasLayer
var score_labels := {}
var hp_bars := {}
var buildings_label: Label
var spawn_timer: Timer
var clouds: Array = []

func _ready() -> void:
	randomize()
	_build_backdrop()
	_build_ground()
	_build_city()
	_spawn_monsters()
	_build_hud()
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer)
	add_child(spawn_timer)
	spawn_timer.start()
	update_hud()

func _process(delta: float) -> void:
	for c in clouds:
		var node: Node2D = c["node"]
		node.position.x += c["speed"] * delta
		if node.position.x > VIEW_W + 120.0:
			node.position.x = -120.0
	if won and Input.is_action_just_pressed("ui_accept"):
		restart_requested.emit()

# --- world construction -----------------------------------------------------

func _build_backdrop() -> void:
	var sky := Polygon2D.new()
	sky.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(VIEW_W, 0), Vector2(VIEW_W, 720), Vector2(0, 720),
	])
	sky.vertex_colors = PackedColorArray([
		Color("#6fb7ef"), Color("#6fb7ef"), Color("#d9efff"), Color("#d9efff"),
	])
	add_child(sky)

	var sun := Polygon2D.new()
	sun.polygon = _circle_points(52.0)
	sun.color = Color("#ffe27a")
	sun.position = Vector2(1140, 110)
	add_child(sun)

	for i in 3:
		var cloud := Node2D.new()
		for j in 3:
			var puff := Polygon2D.new()
			puff.polygon = _circle_points(26.0 - 6.0 * absf(j - 1.0))
			puff.position = Vector2(j * 30.0 - 30.0, (j % 2) * -8.0)
			puff.color = Color(1, 1, 1, 0.9)
			cloud.add_child(puff)
		cloud.position = Vector2(160.0 + i * 420.0, 90.0 + (i % 2) * 60.0)
		add_child(cloud)
		clouds.append({"node": cloud, "speed": 12.0 + i * 6.0})

	# Distant skyline silhouettes.
	var sx := 20.0
	while sx < VIEW_W - 40.0:
		var w := randf_range(60.0, 120.0)
		var h := randf_range(120.0, 260.0)
		var far := Polygon2D.new()
		far.polygon = PackedVector2Array([
			Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h),
		])
		far.position = Vector2(sx, GROUND_Y - h)
		far.color = Color("#9db8d2")
		add_child(far)
		sx += w + randf_range(10.0, 50.0)

func _build_ground() -> void:
	var dirt := Polygon2D.new()
	dirt.polygon = PackedVector2Array([
		Vector2(0, GROUND_Y), Vector2(VIEW_W, GROUND_Y),
		Vector2(VIEW_W, 720), Vector2(0, 720),
	])
	dirt.color = Color("#79b756")
	add_child(dirt)
	var curb := Polygon2D.new()
	curb.polygon = PackedVector2Array([
		Vector2(0, GROUND_Y), Vector2(VIEW_W, GROUND_Y),
		Vector2(VIEW_W, GROUND_Y + 8), Vector2(0, GROUND_Y + 8),
	])
	curb.color = Color("#5d9440")
	add_child(curb)

	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	floor_body.position = Vector2(VIEW_W * 0.5, GROUND_Y + 40.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 80)
	shape.shape = rect
	floor_body.add_child(shape)
	add_child(floor_body)

func _build_city() -> void:
	var x := 90.0
	for i in 6:
		var cols := randi_range(2, 3)
		var rows := randi_range(3, 6)
		var b = BuildingScript.new(self, cols, rows, PALETTE[i % PALETTE.size()])
		b.position = Vector2(x, GROUND_Y)
		add_child(b)
		buildings.append(b)
		x += cols * BuildingScript.CHUNK_W + randf_range(28.0, 60.0)

func _spawn_monsters() -> void:
	var m1 = MonsterScript.new(self, 1, "res://art/monster_spiky.png", "p1", "SPIKY", 230.0)
	m1.position = Vector2(240, GROUND_Y - 2.0)
	add_child(m1)
	var m2 = MonsterScript.new(self, 2, "res://art/monster_penguin.png", "p2", "PENGUIN", 255.0)
	m2.position = Vector2(1040, GROUND_Y - 2.0)
	m2.facing = -1
	m2.sprite.flip_h = true
	add_child(m2)
	monsters = [m1, m2]

# --- HUD ---------------------------------------------------------------------

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 5
	add_child(hud)
	_build_player_panel(1, Vector2(16, 10), "SPIKY", P1_COLOR)
	_build_player_panel(2, Vector2(VIEW_W - 246.0, 10), "PENGUIN", P2_COLOR)

	buildings_label = Label.new()
	buildings_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buildings_label.position = Vector2(0, 12)
	buildings_label.size = Vector2(VIEW_W, 30)
	buildings_label.add_theme_font_size_override("font_size", 22)
	buildings_label.add_theme_color_override("font_color", Color.WHITE)
	buildings_label.add_theme_color_override("font_outline_color", Color("#2b3a55"))
	buildings_label.add_theme_constant_override("outline_size", 6)
	hud.add_child(buildings_label)

func _build_player_panel(idx: int, pos: Vector2, pname: String, color: Color) -> void:
	var name_label := Label.new()
	name_label.text = pname
	name_label.position = pos
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", color)
	name_label.add_theme_color_override("font_outline_color", Color.WHITE)
	name_label.add_theme_constant_override("outline_size", 6)
	hud.add_child(name_label)

	var score := Label.new()
	score.text = "0"
	score.position = pos + Vector2(0, 26)
	score.add_theme_font_size_override("font_size", 32)
	score.add_theme_color_override("font_color", Color.WHITE)
	score.add_theme_color_override("font_outline_color", Color("#2b3a55"))
	score.add_theme_constant_override("outline_size", 8)
	hud.add_child(score)
	score_labels[idx] = score

	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0, 0, 0, 0.4)
	bar_bg.position = pos + Vector2(0, 70)
	bar_bg.size = Vector2(230, 16)
	hud.add_child(bar_bg)
	var bar := ColorRect.new()
	bar.color = Color("#5ecb5e")
	bar.position = pos + Vector2(2, 72)
	bar.size = Vector2(226, 12)
	hud.add_child(bar)
	hp_bars[idx] = bar

func update_hud() -> void:
	for m in monsters:
		if not is_instance_valid(m):
			continue
		score_labels[m.player_index].text = str(scores[m.player_index])
		var bar: ColorRect = hp_bars[m.player_index]
		var frac: float = m.hp / m.MAX_HP
		bar.size.x = 226.0 * clampf(frac, 0.0, 1.0)
		bar.color = Color("#5ecb5e") if frac > 0.35 else Color("#e0b13c")
		if not m.awake:
			bar.color = Color(0.6, 0.6, 0.6)
	buildings_label.text = "BUILDINGS LEFT: %d" % buildings.size()

# --- smashing ---------------------------------------------------------------

## A monster punched (or stomped) the area `rect`. Damage everything inside.
func try_smash(monster, rect: Rect2) -> void:
	Sfx.play("punch", -4.0)
	var pts := 0
	for b in buildings.duplicate():
		pts += b.smash_at(rect, monster.player_index)
	for e in enemies.duplicate():
		if rect.intersects(e.hit_rect()):
			e.explode(monster.player_index)
	if pts > 0:
		add_score(monster.player_index, pts)
		popup_score(Vector2(rect.get_center().x, rect.position.y + 20.0),
			"+%d" % pts, Color.WHITE)
		Sfx.play("crumble", -4.0)

func add_score(player: int, pts: int) -> void:
	scores[player] += pts
	update_hud()

func on_building_collapsed(b, by_player: int) -> void:
	buildings.erase(b)
	add_score(by_player, COLLAPSE_POINTS)
	spawn_debris(b.global_position + Vector2(b.width() * 0.5, -30.0), b.base_color, 30)
	popup_score(b.global_position + Vector2(b.width() * 0.5, -120.0),
		"+%d!" % COLLAPSE_POINTS, Color("#ffe27a"))
	Sfx.play("boom")
	shake(10.0)
	update_hud()
	if buildings.is_empty():
		_win()

func on_vehicle_destroyed(vehicle, by_player: int) -> void:
	enemies.erase(vehicle)
	add_score(by_player, VEHICLE_POINTS)
	spawn_debris(vehicle.global_position + Vector2(0, -20.0), Color("#5d6b3f"), 20)
	popup_score(vehicle.global_position + Vector2(0, -60.0),
		"+%d" % VEHICLE_POINTS, Color("#ffd27a"))
	Sfx.play("boom", -8.0)
	shake(5.0)
	vehicle.queue_free()

# --- army --------------------------------------------------------------------

func _on_spawn_timer() -> void:
	if won or get_target(Vector2(VIEW_W * 0.5, GROUND_Y)) == null:
		return
	var tanks := 0
	var helis := 0
	for e in enemies:
		if e is Tank:
			tanks += 1
		else:
			helis += 1
	var options: Array = []
	if tanks < MAX_TANKS:
		options.append("tank")
	if helis < MAX_HELIS:
		options.append("heli")
	if options.is_empty():
		return
	var choice: String = options.pick_random()
	var from_left := randf() < 0.5
	if choice == "tank":
		var tank = TankScript.new(self)
		tank.position = Vector2(-60.0 if from_left else VIEW_W + 60.0, GROUND_Y)
		add_child(tank)
		enemies.append(tank)
	else:
		var heli = HeliScript.new(self)
		heli.position = Vector2(-60.0 if from_left else VIEW_W + 60.0, 200.0)
		add_child(heli)
		enemies.append(heli)
	spawn_interval = maxf(3.2, spawn_interval * 0.93)
	spawn_timer.wait_time = spawn_interval

## Nearest monster the army may shoot at, or null.
func get_target(from_pos: Vector2):
	var best = null
	var best_d := INF
	for m in monsters:
		if not is_instance_valid(m) or not m.can_be_targeted():
			continue
		var d := from_pos.distance_to(m.global_position)
		if d < best_d:
			best_d = d
			best = m
	return best

func spawn_bullet(from: Vector2, vel: Vector2) -> void:
	add_child(BulletScript.new(self, from, vel))

# --- effects -----------------------------------------------------------------

func spawn_debris(pos: Vector2, color: Color, amount: int = 14) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = 12
	p.one_shot = true
	p.emitting = true
	p.amount = amount
	p.lifetime = 0.9
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 75.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 300.0
	p.gravity = Vector2(0, 900)
	p.scale_amount_min = 4.0
	p.scale_amount_max = 9.0
	p.color = color
	add_child(p)
	get_tree().create_timer(1.4).timeout.connect(p.queue_free)

func spawn_spark(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = 16
	p.one_shot = true
	p.emitting = true
	p.amount = 8
	p.lifetime = 0.35
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 160.0
	p.gravity = Vector2(0, 300)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = Color("#ffd27a")
	add_child(p)
	get_tree().create_timer(0.8).timeout.connect(p.queue_free)

func popup_score(pos: Vector2, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos + Vector2(-60, -20)
	l.size = Vector2(120, 40)
	l.z_index = 20
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("#2b3a55"))
	l.add_theme_constant_override("outline_size", 8)
	add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 60.0, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)

func shake(strength: float) -> void:
	var tw := create_tween()
	for i in 5:
		var target := Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
		tw.tween_property(self, "position", target, 0.04)
	tw.tween_property(self, "position", Vector2.ZERO, 0.05)

# --- winning -----------------------------------------------------------------

func _win() -> void:
	if won:
		return
	won = true
	spawn_timer.stop()
	for e in enemies.duplicate():
		spawn_debris(e.global_position + Vector2(0, -20.0), Color("#5d6b3f"), 16)
		e.queue_free()
	enemies.clear()
	Sfx.play("fanfare")

	var overlay := CanvasLayer.new()
	overlay.layer = 8
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.1, 0.2, 0.65)
	dim.size = Vector2(VIEW_W, 720)
	overlay.add_child(dim)

	_overlay_label(overlay, "CITY SMASHED!", 72, Color("#ffe27a"), 170.0)
	var p1: int = scores[1]
	var p2: int = scores[2]
	_overlay_label(overlay, "SPIKY: %d" % p1, 40, P1_COLOR.lightened(0.3), 300.0)
	_overlay_label(overlay, "PENGUIN: %d" % p2, 40, P2_COLOR.lightened(0.4), 360.0)
	var verdict := "IT'S A TIE! YOU BOTH WIN!"
	if p1 > p2:
		verdict = "SPIKY IS THE KING OF THE CITY!"
	elif p2 > p1:
		verdict = "PENGUIN IS THE KING OF THE CITY!"
	_overlay_label(overlay, verdict, 34, Color.WHITE, 440.0)
	var again := _overlay_label(overlay, "PRESS ENTER FOR A NEW CITY", 28, Color.WHITE, 540.0)
	var blink := create_tween().set_loops()
	blink.tween_property(again, "modulate:a", 0.2, 0.5)
	blink.tween_property(again, "modulate:a", 1.0, 0.5)

func _overlay_label(layer: CanvasLayer, text: String, size: int, color: Color, y: float) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, y)
	l.size = Vector2(VIEW_W, 80)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("#2b3a55"))
	l.add_theme_constant_override("outline_size", 10)
	layer.add_child(l)
	return l

func _circle_points(radius: float, n: int = 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts
