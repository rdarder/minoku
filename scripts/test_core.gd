extends SceneTree

const OrchardCore = preload("res://scripts/OrchardCore.gd")

func _init():
	print("--- Testing GDScript Orchard Generator in Godot 4.3 ---")
	for sz in [6, 8, 10]:
		var t0 = Time.get_ticks_msec()
		var p = OrchardCore.generate_puzzle(sz, 30)
		var dt = Time.get_ticks_msec() - t0
		if not p.is_empty():
			print("Generated %dx%d in %d ms! Score: %d Techniques: %s" % [sz, sz, dt, p["difficulty_score"], str(p["techniques"])])
		else:
			print("Could not generate %dx%d in time limit" % [sz, sz])
	quit()
