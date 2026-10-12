extends SceneTree

const OrchardCore = preload("res://scripts/OrchardCore.gd")

func _init():
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345
	var fl = OrchardCore._generate_valid_flowers(10, rng)
	var grid = OrchardCore._generate_initial_partition(10, fl, rng)
	var t0 = Time.get_ticks_msec()
	var res = OrchardCore._refine_and_solve(10, grid, fl, rng)
	print("Refine and solve took: ", Time.get_ticks_msec() - t0, "ms, empty: ", res.is_empty())
	quit()
