class_name Monster
extends CharacterBody2D
## A playable giant monster (one of Evan's drawings). Walks, jumps, punches,
## ducks, gets dizzy when the army wears it down, then shakes it off and comes back.

const SPEED := 330.0
const JUMP_VELOCITY := -760.0
const GRAVITY := 1700.0
const MAX_HP := 100.0
const PUNCH_COOLDOWN := 0.35
const STOMP_MIN_FALL_SPEED := 500.0

var game
var player_index := 1
var display_name := "MONSTER"
var actions := {}
var hp := MAX_HP
var awake := false
var dizzy := false
var invulnerable := false
var facing := 1
var punch_cd := 0.0
var fall_speed := 0.0
var wobble_t := 0.0
var ducking := false
var walk_t := 0.0
var _bob_tween: Tween
var _punch_arm: Node2D

var sprite: Sprite2D
var base_sprite_scale := Vector2.ONE
var sprite_h := 240.0
var sprite_w := 100.0
var wake_label: Label

func _init(p_game, p_index: int, tex_path: String, prefix: String, p_name: String, height: float) -> void:
	game = p_game
	player_index = p_index
	display_name = p_name
	sprite_h = height
	actions = {
		"left": prefix + "_left", "right": prefix + "_right",
		"jump": prefix + "_jump", "punch": prefix + "_punch",
		"duck": prefix + "_duck",
	}
	collision_layer = 2
	collision_mask = 1
	z_index = 10

	var tex: Texture2D = load(tex_path)
	var s := sprite_h / float(tex.get_height())
	sprite_w = tex.get_width() * s
	sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.scale = Vector2(s, s)
	base_sprite_scale = sprite.scale
	sprite.position = Vector2(0, -sprite_h * 0.5)
	sprite.modulate = Color(1, 1, 1, 0.45)  # asleep until first input
	add_child(sprite)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(maxf(sprite_w * 0.45, 40.0), sprite_h)
	shape.shape = rect
	shape.position = Vector2(0, -sprite_h * 0.5)
	add_child(shape)

	wake_label = Label.new()
	wake_label.text = "PRESS %s!" % ("F" if player_index == 1 else "L")
	wake_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wake_label.position = Vector2(-100, -sprite_h - 56)
	wake_label.size = Vector2(200, 36)
	wake_label.add_theme_font_size_override("font_size", 26)
	wake_label.add_theme_color_override("font_color", Color.WHITE)
	wake_label.add_theme_color_override("font_outline_color", Color("#2b3a55"))
	wake_label.add_theme_constant_override("outline_size", 8)
	add_child(wake_label)

func _ready() -> void:
	if is_instance_valid(wake_label):
		_bob_tween = create_tween().set_loops()
		_bob_tween.tween_property(wake_label, "position:y", wake_label.position.y - 10.0, 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_bob_tween.tween_property(wake_label, "position:y", wake_label.position.y, 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _physics_process(delta: float) -> void:
	punch_cd = maxf(punch_cd - delta, 0.0)
	if not is_on_floor():
		velocity.y += GRAVITY * delta
		fall_speed = velocity.y

	if dizzy:
		velocity.x = 0.0
		move_and_slide()
		wobble_t += delta
		sprite.rotation = sin(wobble_t * 9.0) * 0.22
		return

	if not awake:
		for a in actions.values():
			if Input.is_action_just_pressed(a):
				_wake()
				break
		move_and_slide()
		return

	# Duck while on floor and duck key held.
	var want_duck := Input.is_action_pressed(actions["duck"]) and is_on_floor()
	if want_duck != ducking:
		ducking = want_duck
		sprite.rotation = 0.0
		if ducking:
			sprite.scale = base_sprite_scale * Vector2(1.25, 0.55)
			sprite.position = Vector2(0, -sprite_h * 0.275)
		else:
			sprite.scale = base_sprite_scale
			sprite.position = Vector2(0, -sprite_h * 0.5)

	if ducking:
		velocity.x = move_toward(velocity.x, 0.0, SPEED * 0.5)
		move_and_slide()
		position.x = clampf(position.x, 50.0, 1230.0)
		return

	var dir := Input.get_axis(actions["left"], actions["right"])
	if absf(dir) > 0.2:
		velocity.x = dir * SPEED
		var new_facing := 1 if dir > 0.0 else -1
		if new_facing != facing:
			facing = new_facing
			sprite.flip_h = facing < 0
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED * 0.25)

	# Walk lean — subtle body tilt while moving on the ground.
	if is_on_floor() and absf(velocity.x) > 10.0:
		walk_t += delta * 8.0
		sprite.rotation = sin(walk_t) * 0.045 * facing
	else:
		walk_t = 0.0
		sprite.rotation = move_toward(sprite.rotation, 0.0, delta * 8.0)

	if Input.is_action_just_pressed(actions["jump"]) and is_on_floor():
		velocity.y = JUMP_VELOCITY
		Sfx.play("jump", -8.0)
		_pose(Vector2(0.92, 1.1))

	if Input.is_action_just_pressed(actions["punch"]) and punch_cd <= 0.0:
		_punch()

	var was_airborne := not is_on_floor()
	move_and_slide()
	position.x = clampf(position.x, 50.0, 1230.0)

	if was_airborne and is_on_floor():
		_pose(Vector2(1.1, 0.88))
		if fall_speed > STOMP_MIN_FALL_SPEED:
			var size := Vector2(sprite_w + 60.0, 90.0)
			game.try_smash(self, Rect2(global_position - Vector2(size.x * 0.5, size.y - 20.0), size))
		fall_speed = 0.0

func _punch() -> void:
	punch_cd = PUNCH_COOLDOWN
	# Sprite body lurches forward.
	var base := Vector2(0, -sprite_h * 0.5)
	var tw := create_tween()
	tw.tween_property(sprite, "position", base + Vector2(facing * 30.0, 0), 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "position", base, 0.14)
	# Extending arm sprite and impact burst.
	_spawn_punch_arm()
	# Hitbox.
	var center := global_position + Vector2(facing * (sprite_w * 0.5 + 50.0), -sprite_h * 0.55)
	var size := Vector2(170.0, 210.0)
	game.try_smash(self, Rect2(center - size * 0.5, size))
	game.popup_score(center + Vector2(0, -20), "POW!", Color("#ffe27a"))

func _spawn_punch_arm() -> void:
	if is_instance_valid(_punch_arm):
		_punch_arm.queue_free()
	_punch_arm = Node2D.new()
	_punch_arm.position = Vector2(0, -sprite_h * 0.55)
	_punch_arm.z_index = 11
	add_child(_punch_arm)

	var arm_len := sprite_w * 0.65
	var shoulder_x := sprite_w * 0.28

	# Arm — trapezoid that widens slightly toward the fist.
	var arm := Polygon2D.new()
	arm.polygon = PackedVector2Array([
		Vector2(shoulder_x,           -11.0),
		Vector2(shoulder_x + arm_len, -15.0),
		Vector2(shoulder_x + arm_len,  15.0),
		Vector2(shoulder_x,            11.0),
	])
	arm.color = Color("#f0a030")
	_punch_arm.add_child(arm)

	# Fist — chunky hexagon at the end of the arm.
	var fx := shoulder_x + arm_len
	var fs := 34.0
	var fist := Polygon2D.new()
	fist.polygon = PackedVector2Array([
		Vector2(fx,          -fs * 0.55),
		Vector2(fx + fs,     -fs * 0.50),
		Vector2(fx + fs * 1.2, 0.0),
		Vector2(fx + fs,      fs * 0.50),
		Vector2(fx,           fs * 0.55),
		Vector2(fx - 6.0,     0.0),
	])
	fist.color = Color("#e06818")
	_punch_arm.add_child(fist)

	# Three knuckle ridges on the fist face.
	for k in 3:
		var kn := Polygon2D.new()
		var kx := fx + 8.0 + k * 9.0
		kn.polygon = PackedVector2Array([
			Vector2(kx,       -fs * 0.38),
			Vector2(kx + 4.0, -fs * 0.38),
			Vector2(kx + 4.0,  fs * 0.38),
			Vector2(kx,        fs * 0.38),
		])
		kn.color = Color("#bf5010")
		_punch_arm.add_child(kn)

	# Impact star burst at the fist tip — spawned before scale animation.
	var tip := global_position + Vector2(facing * (shoulder_x + arm_len + fs * 1.1), -sprite_h * 0.55)
	_spawn_impact_star(tip)

	# Arm extends from near-zero scale to full then retracts.
	_punch_arm.scale = Vector2(facing * 0.05, 1.0)
	var anim := _punch_arm.create_tween()
	anim.tween_property(_punch_arm, "scale", Vector2(facing * 1.0, 1.0), 0.08) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	anim.tween_interval(0.08)
	anim.tween_property(_punch_arm, "scale", Vector2(facing * 0.05, 1.0), 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	anim.tween_callback(_punch_arm.queue_free)

func _spawn_impact_star(pos: Vector2) -> void:
	var star := Polygon2D.new()
	star.polygon = _star_points(26.0, 7)
	star.position = pos
	star.color = Color("#ffe040")
	star.z_index = 20
	add_child(star)
	var tw := star.create_tween()
	tw.set_parallel(true)
	tw.tween_property(star, "scale", Vector2(3.0, 3.0), 0.22) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(star, "modulate", Color(1.0, 0.8, 0.0, 0.0), 0.25)
	tw.chain().tween_callback(star.queue_free)

func _star_points(r: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n * 2:
		var a := TAU * i / (n * 2) - PI * 0.5
		var rad := r if i % 2 == 0 else r * 0.38
		pts.append(Vector2(cos(a) * rad, sin(a) * rad))
	return pts

func take_damage(dmg: float) -> void:
	if not can_be_hit():
		return
	hp = maxf(hp - dmg, 0.0)
	Sfx.play("hurt", -6.0)
	sprite.modulate = Color(1, 0.35, 0.35)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.25)
	game.update_hud()
	if hp <= 0.0:
		_go_dizzy()

func can_be_hit() -> bool:
	return awake and not dizzy and not invulnerable

func can_be_targeted() -> bool:
	return awake and not dizzy

func _wake() -> void:
	awake = true
	sprite.modulate = Color.WHITE
	if _bob_tween:
		_bob_tween.kill()
	if is_instance_valid(wake_label):
		wake_label.queue_free()
	Sfx.play("roar")
	if is_on_floor():
		velocity.y = -350.0
	game.popup_score(global_position + Vector2(0, -sprite_h - 30.0), "RAAAR!", Color.WHITE)
	game.update_hud()

func _go_dizzy() -> void:
	dizzy = true
	ducking = false
	if is_instance_valid(_punch_arm):
		_punch_arm.queue_free()
	sprite.scale = base_sprite_scale
	sprite.position = Vector2(0, -sprite_h * 0.5)
	Sfx.play("dizzy")
	sprite.modulate = Color(0.75, 0.75, 0.9)
	game.popup_score(global_position + Vector2(0, -sprite_h - 30.0), "DIZZY!", Color("#ffe27a"))
	await get_tree().create_timer(3.0).timeout
	if not is_instance_valid(self):
		return
	dizzy = false
	sprite.rotation = 0.0
	hp = MAX_HP
	invulnerable = true
	game.update_hud()
	Sfx.play("roar", -6.0)
	var tw := create_tween()
	for i in 5:
		tw.tween_property(sprite, "modulate:a", 0.35, 0.16)
		tw.tween_property(sprite, "modulate:a", 1.0, 0.16)
	tw.tween_callback(func() -> void:
		invulnerable = false
		sprite.modulate = Color.WHITE)

## Quick squash/stretch, returning to normal.
func _pose(factor: Vector2) -> void:
	if ducking:
		return
	sprite.scale = base_sprite_scale * factor
	var tw := create_tween()
	tw.tween_property(sprite, "scale", base_sprite_scale, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
