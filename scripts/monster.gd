class_name Monster
extends CharacterBody2D
## A playable giant monster (one of Evan's drawings). Walks, jumps, punches,
## gets dizzy when the army wears it down, then shakes it off and comes back.

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
		var tw := create_tween().set_loops()
		tw.tween_property(wake_label, "position:y", wake_label.position.y - 10.0, 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(wake_label, "position:y", wake_label.position.y, 0.5) \
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

	var dir := Input.get_axis(actions["left"], actions["right"])
	if absf(dir) > 0.2:
		velocity.x = dir * SPEED
		var new_facing := 1 if dir > 0.0 else -1
		if new_facing != facing:
			facing = new_facing
			sprite.flip_h = facing < 0
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED * 0.25)

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
			# Ground-pound: landing hard smashes whatever is underfoot.
			var size := Vector2(sprite_w + 60.0, 90.0)
			game.try_smash(self, Rect2(global_position - Vector2(size.x * 0.5, size.y - 20.0), size))
		fall_speed = 0.0

func _punch() -> void:
	punch_cd = PUNCH_COOLDOWN
	var base := Vector2(0, -sprite_h * 0.5)
	var tw := create_tween()
	tw.tween_property(sprite, "position", base + Vector2(facing * 26.0, 0), 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "position", base, 0.12)
	var center := global_position + Vector2(facing * (sprite_w * 0.5 + 50.0), -sprite_h * 0.55)
	var size := Vector2(170.0, 210.0)
	game.try_smash(self, Rect2(center - size * 0.5, size))

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
	if is_instance_valid(wake_label):
		wake_label.queue_free()
	Sfx.play("roar")
	if is_on_floor():
		velocity.y = -350.0
	game.popup_score(global_position + Vector2(0, -sprite_h - 30.0), "RAAAR!", Color.WHITE)
	game.update_hud()

func _go_dizzy() -> void:
	dizzy = true
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
	sprite.scale = base_sprite_scale * factor
	var tw := create_tween()
	tw.tween_property(sprite, "scale", base_sprite_scale, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
