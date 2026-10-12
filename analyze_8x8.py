from orchard_core import OrchardSolver, OrchardGenerator
import random

gen = OrchardGenerator(8)
sol_counts = []
for _ in range(50):
    fl = gen._generate_valid_flower_positions()
    if not fl: continue
    patches = gen._generate_partition(fl)
    s = OrchardSolver(8, patches)
    sol_counts.append(s.count_solutions(limit=5))

print("Distribution of solution counts in 50 random 8x8 partitions:")
from collections import Counter
print(Counter(sol_counts))
