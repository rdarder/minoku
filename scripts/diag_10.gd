extends SceneTree

const OrchardCore = preload("res://scripts/OrchardCore.gd")

func _init():
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345
	var fl = OrchardCore._generate_valid_flowers(10, rng)
	var grid = OrchardCore._generate_initial_partition(10, fl, rng)
	
	print("Checking uniqueness vs deductive solvability for 10x10:")
	for step in range(40):
		var alt = OrchardCore._find_alternative_solution(10, grid, fl)
		if alt.is_empty():
			print("At step %d, board is 100%% UNIQUE!" % step)
			var ded = OrchardCore.solve_deductive(10, grid)
			print("Is deductive? ", ded["solved"], " Techniques: ", ded["techniques"])
			break
		# Mutate one cell
		var diff = []
		var fl_set = {}
		for f in fl: fl_set[f] = true
		for c in alt:
			if not fl_set.has(c): diff.append(c)
		OrchardCore._rng_shuffle(diff, rng)
		var swapped = false
		for c in diff:
			var cur_p = grid[c.x][c.y]
			var adj = []
			for d in [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]:
				var nr = c.x + d.x
				var nc = c.y + d.y
				if nr>=0 and nr<10 and nc>=0 and nc<10 and grid[nr][nc] != cur_p and not adj.has(grid[nr][nc]):
					adj.append(grid[nr][nc])
			OrchardCore._rng_shuffle(adj, rng)
			for target_p in adj:
				grid[c.x][c.y] = target_p
				if OrchardCore._is_connected(10, cur_p, grid) and OrchardCore._is_connected(10, target_p, grid):
					swapped = true
					break
				else:
					grid[c.x][c.y] = cur_p
			if swapped: break
	quit()
