import random
from orchard_core import OrchardGenerator, OrchardSolver

gen = OrchardGenerator(6)
flowers = gen._generate_valid_flower_positions()
print("Flowers:", flowers)
patches = gen._generate_patches(flowers)
solver = OrchardSolver(6, patches)
sol_count = solver.count_solutions(limit=10)
print("Solutions count:", sol_count)
is_ded, score, tech = solver.solve_deductive()
print("Deductive solved:", is_ded, "score:", score, "tech:", tech)
