extends SceneTree
## Headless smoke test for CI: loads every script, boots the title screen,
## then starts an actual game round for a couple of seconds.
## Run with: godot --headless -s res://tools/ci_check.gd

func _initialize() -> void:
	var failed := false
	var scripts := [
		"res://scripts/main.gd", "res://scripts/game.gd", "res://scripts/monster.gd",
		"res://scripts/building.gd", "res://scripts/tank.gd", "res://scripts/helicopter.gd",
		"res://scripts/bullet.gd", "res://scripts/sfx.gd",
	]
	for p in scripts:
		var s: Script = load(p)
		if s == null or not s.can_instantiate():
			push_error("Script failed to load: " + p)
			failed = true

	var scene: PackedScene = load("res://scenes/Main.tscn")
	if scene == null or not scene.can_instantiate():
		push_error("Main.tscn failed to load")
		failed = true

	if failed:
		quit(1)
		return

	# The Sfx autoload may not be registered in -s mode; provide it manually.
	if root.get_node_or_null("Sfx") == null:
		var sfx: Node = load("res://scripts/sfx.gd").new()
		sfx.name = "Sfx"
		root.add_child(sfx)

	var main = scene.instantiate()
	root.add_child(main)
	await create_timer(0.5).timeout
	main.start_game()
	await create_timer(2.5).timeout
	print("CI_SMOKE_OK")
	quit(0)
