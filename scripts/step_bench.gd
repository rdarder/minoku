extends SceneTree

const OrchardCore = preload("res://scripts/OrchardCore.gd")

func _init():
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345
	var t0 = Time.get_ticks_msec()
	var fl = OrchardCore._generate_valid_flowers(10, rng)
	print("Valid flowers found in: ", Time.get_ticks_msec() - t0, "ms: ", fl)
	var t1 = Time.get_ticks_msec()
	var grid = OrchardCore._generate_initial_partition(10, fl, rng)
	print("Partition generated in: ", Time.get_ticks_msec() - t1, "ms")
	var t2 = Time.get_ticks_msec()
	var alt = OrchardCore._find_alternative_solution(10, grid, fl)
	print("Find alt took: ", Time.get_ticks_msec() - t2, "ms: ", alt.size())
	quit()
