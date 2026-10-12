from orchard_core import OrchardGenerator, OrchardSolver

gen = OrchardGenerator(8)
fl = gen._generate_valid_flower_positions()
print("8x8 valid flowers found:", fl is not None)
if fl:
    grid = gen._generate_partition(fl)
    s = OrchardSolver(8, grid)
    print("Solutions count:", s.count_solutions(limit=5))
    is_d, sc, te = s.solve_deductive()
    print("Deductive:", is_d, sc, te)
