extends SceneTree

const OrchardCore = preload("res://scripts/OrchardCore.gd")

func _init():
	print("--- Profiling 10x10 Generation ---")
	for i in range(5):
		var t0 = Time.get_ticks_msec()
		var p = OrchardCore.generate_puzzle(10, -1, 30)
		var dt = Time.get_ticks_msec() - t0
		if not p.is_empty():
			print("Attempt %d: SUCCESS in %d ms (code: %s, score: %d)" % [i, dt, p["level_code"], p["difficulty_score"]])
		else:
			print("Attempt %d: FAILED after %d ms" % [i, dt])
	quit()
