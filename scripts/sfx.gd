extends Node
## Autoload sound player: Sfx.play("punch"). One-shot players free themselves.

var streams: Dictionary = {}

func _ready() -> void:
	for n in ["punch", "crumble", "boom", "pew", "hurt", "roar", "fanfare", "dizzy", "jump"]:
		var path := "res://audio/%s.wav" % n
		if ResourceLoader.exists(path):
			streams[n] = load(path)

func play(sound: String, volume_db: float = 0.0, pitch_jitter: float = 0.08) -> void:
	if not streams.has(sound):
		return
	var p := AudioStreamPlayer.new()
	p.stream = streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
