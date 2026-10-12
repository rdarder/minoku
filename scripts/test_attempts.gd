extends SceneTree

const OrchardCore = preload("res://scripts/OrchardCore.gd")

func _init():
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345
	var attempts = 0
	var t0 = Time.get_ticks_msec()
	while attempts < 30:
		attempts += 1
		var fl = OrchardCore._generate_valid_flowers(10, rng)
		var grid = OrchardCore._generate_initial_partition(10, fl, rng)
		var res = OrchardCore._refine_and_solve(10, grid, fl, rng)
		if not res.is_empty():
			print("Attempt %d SUCCESS in %d ms! Score: %d" % [attempts, Time.get_ticks_msec() - t0, res["difficulty_score"]])
			break
		else:
			print("Attempt %d failed in %d ms" % [attempts, Time.get_ticks_msec() - t0])
	quit()
