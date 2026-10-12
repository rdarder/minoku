import time
from fast_gen import FastOrchard

for attempt in range(30):
    t0 = time.time()
    gen = FastOrchard(10)
    p = gen.generate_puzzle()
    if p:
        print(f"Generated 10x10 in {time.time()-t0:.3f}s! Score={p['difficulty_score']} Tech={p['techniques']}")
        break
