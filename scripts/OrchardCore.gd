class_name OrchardCore
extends RefCounted

## Procedural Generator & Solver for Orchard
## Guarantees 100% uniquely solvable and purely deductive puzzles.

static func generate_puzzle(size: int, puzzle_seed: int = -1, max_attempts: int = 50) -> Dictionary:
	var actual_seed: int = puzzle_seed
	if actual_seed < 0:
		actual_seed = randi() & 0x7FFFFFFF
	
	var rng = RandomNumberGenerator.new()
	rng.seed = actual_seed

	for attempt in range(max_attempts):
		var flowers = _generate_valid_flowers(size, rng)
		if flowers.is_empty():
			continue
		
		var grid = _generate_initial_partition(size, flowers, rng)
		var mutated = _refine_and_solve(size, grid, flowers, rng)
		if not mutated.is_empty():
			mutated["seed"] = actual_seed
			mutated["level_code"] = "%dx%d-%d" % [size, size, actual_seed]
			return mutated
	return {}

static func _generate_valid_flowers(size: int, rng: RandomNumberGenerator) -> Array:
	var flowers: Array = []
	var cols = []
	for i in range(size):
		cols.append(i)
	
	if _backtrack_flowers(0, size, cols, flowers, rng):
		return flowers
	return []

static func _backtrack_flowers(row: int, size: int, cols: Array, flowers: Array, rng: RandomNumberGenerator) -> bool:
	if row == size:
		return true
	var avail = cols.duplicate()
	_rng_shuffle(avail, rng)
	for c in avail:
		var conflict = false
		for f in flowers:
			if abs(f.x - row) <= 1 and abs(f.y - c) <= 1:
				conflict = true
				break
		if conflict:
			continue
		flowers.append(Vector2i(row, c))
		cols.erase(c)
		if _backtrack_flowers(row + 1, size, cols, flowers, rng):
			return true
		flowers.pop_back()
		cols.append(c)
	return false

static func _rng_shuffle(arr: Array, rng: RandomNumberGenerator):
	for i in range(arr.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

static func _generate_initial_partition(size: int, flowers: Array, rng: RandomNumberGenerator) -> Array:
	var grid: Array = []
	for r in range(size):
		var row: Array = []
		for c in range(size):
			row.append(-1)
		grid.append(row)
		
	for i in range(flowers.size()):
		var f = flowers[i]
		grid[f.x][f.y] = i
		
	var unassigned = size * size - size
	while unassigned > 0:
		for r in range(size):
			for c in range(size):
				if grid[r][c] == -1:
					var adj: Array = []
					for d in [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]:
						var nr = r + d.x
						var nc = c + d.y
						if nr >= 0 and nr < size and nc >= 0 and nc < size and grid[nr][nc] != -1:
							adj.append(grid[nr][nc])
					if not adj.is_empty():
						grid[r][c] = adj[rng.randi_range(0, adj.size() - 1)]
						unassigned -= 1
	return grid

static func _refine_and_solve(size: int, grid: Array, flowers: Array, rng: RandomNumberGenerator) -> Dictionary:
	var flower_set: Dictionary = {}
	for f in flowers:
		flower_set[f] = true
		
	# Targeted counter-solution elimination:
	# Find any competing alternative solution and mutate a cell belonging to it
	for step in range(40):
		var alt = _find_alternative_solution(size, grid, flowers)
		if alt.is_empty():
			# Solution is strictly unique! Verify purely deductive solvability
			var ded = solve_deductive(size, grid)
			if ded["solved"]:
				return {
					"size": size,
					"patches": grid,
					"flowers": flowers,
					"difficulty_score": ded["score"],
					"techniques": ded["techniques"]
				}
			else:
				# Unique but requires non-trivial guessing beyond our techniques; break to try next attempt
				break
				
		# Filter cells in alternative solution that do NOT match target flowers
		var diff_cells: Array = []
		for cell in alt:
			if not flower_set.has(cell):
				diff_cells.append(cell)
				
		if diff_cells.is_empty():
			break
		_rng_shuffle(diff_cells, rng)
		
		var swapped = false
		for cell in diff_cells:
			var r = cell.x
			var c = cell.y
			var cur_p = grid[r][c]
			
			var adj_patches: Array = []
			for d in [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]:
				var nr = r + d.x
				var nc = c + d.y
				if nr >= 0 and nr < size and nc >= 0 and nc < size and grid[nr][nc] != cur_p:
					if not adj_patches.has(grid[nr][nc]):
						adj_patches.append(grid[nr][nc])
						
			if adj_patches.is_empty():
				continue
			_rng_shuffle(adj_patches, rng)
			
			for target_p in adj_patches:
				grid[r][c] = target_p
				if _is_connected(size, cur_p, grid) and _is_connected(size, target_p, grid):
					swapped = true
					break
				else:
					grid[r][c] = cur_p
			if swapped:
				break
	return {}

static func _find_alternative_solution(size: int, patches: Array, target_flowers: Array) -> Array:
	var cols_used = []
	var patches_used = []
	for i in range(size):
		cols_used.append(false)
		patches_used.append(false)
		
	var target_set: Dictionary = {}
	for f in target_flowers:
		target_set[f] = true
		
	var alt_sol: Array = []
	var current: Array = []
	_backtrack_find_alt(0, -10, size, patches, target_set, cols_used, patches_used, current, alt_sol)
	return alt_sol

static func _backtrack_find_alt(row: int, pcol: int, size: int, patches: Array, target_set: Dictionary, cols_used: Array, patches_used: Array, current: Array, alt_sol: Array) -> bool:
	if row == size:
		var matches_target = true
		for cell in current:
			if not target_set.has(cell):
				matches_target = false
				break
		if not matches_target:
			alt_sol.append_array(current)
			return true
		return false
		
	for col in range(size):
		if cols_used[col]: continue
		if abs(pcol - col) <= 1: continue
		var p = patches[row][col]
		if patches_used[p]: continue
		
		cols_used[col] = true
		patches_used[p] = true
		current.append(Vector2i(row, col))
		
		if _backtrack_find_alt(row + 1, col, size, patches, target_set, cols_used, patches_used, current, alt_sol):
			return true
			
		current.pop_back()
		cols_used[col] = false
		patches_used[p] = false
	return false

static func _is_connected(size: int, p: int, grid: Array) -> bool:
	var cells: Array = []
	for r in range(size):
		for c in range(size):
			if grid[r][c] == p:
				cells.append(Vector2i(r, c))
	if cells.is_empty():
		return false
	var visited: Dictionary = {}
	var queue: Array = [cells[0]]
	visited[cells[0]] = true
	var count = 0
	while not queue.is_empty():
		var curr = queue.pop_front()
		count += 1
		for d in [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]:
			var n = curr + d
			if n.x >= 0 and n.x < size and n.y >= 0 and n.y < size and grid[n.x][n.y] == p:
				if not visited.has(n):
					visited[n] = true
					queue.append(n)
	return count == cells.size()

static func count_solutions(size: int, patches: Array, limit: int = 2) -> int:
	var solutions = [0]
	var cols_used = []
	var patches_used = []
	for i in range(size):
		cols_used.append(false)
		patches_used.append(false)
		
	_backtrack_count(0, -10, size, patches, cols_used, patches_used, limit, solutions)
	return solutions[0]

static func _backtrack_count(row: int, pcol: int, size: int, patches: Array, cols_used: Array, patches_used: Array, limit: int, solutions: Array):
	if row == size:
		solutions[0] += 1
		return
	for col in range(size):
		if cols_used[col]: continue
		if abs(pcol - col) <= 1: continue
		var p = patches[row][col]
		if patches_used[p]: continue
		
		cols_used[col] = true
		patches_used[p] = true
		_backtrack_count(row + 1, col, size, patches, cols_used, patches_used, limit, solutions)
		cols_used[col] = false
		patches_used[p] = false
		if solutions[0] >= limit:
			return

static func solve_deductive(size: int, patches: Array) -> Dictionary:
	var candidates: Array = []
	var placed: Array = []
	var patch_cells: Dictionary = {}
	for i in range(size):
		patch_cells[i] = []
		
	for r in range(size):
		var cand_row: Array = []
		var placed_row: Array = []
		for c in range(size):
			cand_row.append(true)
			placed_row.append(false)
			patch_cells[patches[r][c]].append(Vector2i(r, c))
		candidates.append(cand_row)
		placed.append(placed_row)
		
	var techniques = {"naked_single": 0, "confinement": 0, "neighbor_overlap": 0}
	var score = 0
	
	while true:
		var progress = false
		
		# 1. Units check (rows, cols, patches)
		var units: Array = []
		for r in range(size):
			var row_cells: Array = []
			for c in range(size): row_cells.append(Vector2i(r, c))
			units.append(row_cells)
		for c in range(size):
			var col_cells: Array = []
			for r in range(size): col_cells.append(Vector2i(r, c))
			units.append(col_cells)
		for p in range(size):
			units.append(patch_cells[p])
			
		for cells in units:
			var already_has_flower = false
			for cell in cells:
				if placed[cell.x][cell.y]:
					already_has_flower = true
					break
			if already_has_flower:
				continue
				
			var avail: Array = []
			for cell in cells:
				if candidates[cell.x][cell.y]:
					avail.append(cell)
			if avail.size() == 1:
				var f = avail[0]
				placed[f.x][f.y] = true
				techniques["naked_single"] += 1
				score += 1
				progress = true
				# Eliminate conflicts
				for c2 in range(size): if c2 != f.y: candidates[f.x][c2] = false
				for r2 in range(size): if r2 != f.x: candidates[r2][f.y] = false
				for pcell in patch_cells[patches[f.x][f.y]]:
					if pcell != f: candidates[pcell.x][pcell.y] = false
				for dr in [-1, 0, 1]:
					for dc in [-1, 0, 1]:
						if dr == 0 and dc == 0: continue
						var nr = f.x + dr
						var nc = f.y + dc
						if nr >= 0 and nr < size and nc >= 0 and nc < size:
							candidates[nr][nc] = false
				break
			elif avail.is_empty():
				return {"solved": false, "score": score, "techniques": techniques}
		
		if progress:
			continue
			
		# 2. Confinement check
		for p in range(size):
			var already_placed = false
			for cell in patch_cells[p]:
				if placed[cell.x][cell.y]:
					already_placed = true
					break
			if already_placed: continue
			
			var avail: Array = []
			for cell in patch_cells[p]:
				if candidates[cell.x][cell.y]: avail.append(cell)
			if avail.is_empty(): continue
			
			var first_r = avail[0].x
			var same_row = true
			for cell in avail:
				if cell.x != first_r: same_row = false; break
			if same_row:
				for c in range(size):
					if not avail.has(Vector2i(first_r, c)) and candidates[first_r][c]:
						candidates[first_r][c] = false
						progress = true
						techniques["confinement"] += 1
						score += 3
						
			var first_c = avail[0].y
			var same_col = true
			for cell in avail:
				if cell.y != first_c: same_col = false; break
			if same_col:
				for r in range(size):
					if not avail.has(Vector2i(r, first_c)) and candidates[r][first_c]:
						candidates[r][first_c] = false
						progress = true
						techniques["confinement"] += 1
						score += 3
		if progress:
			continue
			
		if not progress:
			break
			
	var count = 0
	for r in range(size):
		for c in range(size):
			if placed[r][c]: count += 1
	return {"solved": count == size, "score": score, "techniques": techniques}
