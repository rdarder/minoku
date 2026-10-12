from orchard_core import OrchardSolver, OrchardGenerator

gen = OrchardGenerator(8)
fl = gen._generate_valid_flower_positions()
patches = gen._generate_partition(fl)
s = OrchardSolver(8, patches)

cols_used = [False] * 8
patches_used = [False] * 8
placed_cols = [-10] * 8
all_sols = []

def find_all(row, current):
    if row == 8:
        all_sols.append(list(current))
        return
    for col in range(8):
        p = patches[row][col]
        if cols_used[col] or patches_used[p]: continue
        if row > 0 and abs(placed_cols[row-1] - col) <= 1: continue
        cols_used[col] = True
        patches_used[p] = True
        placed_cols[row] = col
        current.append((row, col))
        find_all(row + 1, current)
        current.pop()
        placed_cols[row] = -10
        cols_used[col] = False
        patches_used[p] = False

find_all(0, [])
print("Target flowers:", fl)
print(f"Total solutions found: {len(all_sols)}")
for idx, sol in enumerate(all_sols[:5]):
    diff = set(sol) - set(fl)
    print(f"Sol {idx}: {sol} (Diff: {diff})")
