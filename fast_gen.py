"""
High performance Orchard level generator:
Uses boundary-swapping and simulated annealing / local search to sculpt patches
around the target solution until exactly ONE unique solution remains.
"""
import random
from typing import List, Tuple, Set, Dict, Optional
from collections import deque

class FastOrchard:
    def __init__(self, size: int):
        self.size = size

    def valid_flowers(self) -> Optional[List[Tuple[int, int]]]:
        flowers = []
        cols = list(range(self.size))
        
        def backtrack(row: int):
            if row == self.size:
                return True
            avail = list(cols)
            random.shuffle(avail)
            for c in avail:
                if row > 0 and abs(flowers[-1][1] - c) <= 1:
                    continue
                # 8-neighbor with all previous
                conflict = False
                for pr, pc in flowers:
                    if abs(pr - row) <= 1 and abs(pc - c) <= 1:
                        conflict = True
                        break
                if conflict: continue
                
                flowers.append((row, c))
                cols.remove(c)
                if backtrack(row + 1):
                    return True
                flowers.pop()
                cols.append(c)
            return False

        if backtrack(0):
            return flowers
        return None

    def count_solutions(self, patches: List[List[int]], limit: int = 2) -> int:
        size = self.size
        solutions = 0
        cols_used = [False] * size
        patches_used = [False] * size
        prev_col = -10

        def backtrack(row: int, pcol: int):
            nonlocal solutions
            if row == size:
                solutions += 1
                return
            
            for col in range(size):
                if cols_used[col]: continue
                if abs(pcol - col) <= 1: continue
                p = patches[row][col]
                if patches_used[p]: continue
                
                cols_used[col] = True
                patches_used[p] = True
                
                backtrack(row + 1, col)
                
                cols_used[col] = False
                patches_used[p] = False
                
                if solutions >= limit:
                    return

        backtrack(0, -10)
        return solutions

    def solve_deductive(self, patches: List[List[int]]):
        size = self.size
        candidates = [[True for _ in range(size)] for _ in range(size)]
        placed = [[False for _ in range(size)] for _ in range(size)]
        
        patch_cells: Dict[int, List[Tuple[int, int]]] = {p: [] for p in range(size)}
        for r in range(size):
            for c in range(size):
                patch_cells[patches[r][c]].append((r, c))
                
        def eliminate(r, c):
            if candidates[r][c]:
                candidates[r][c] = False
                return True
            return False
            
        def place(r, c):
            placed[r][c] = True
            for c2 in range(size):
                if c2 != c: eliminate(r, c2)
            for r2 in range(size):
                if r2 != r: eliminate(r2, c)
            for pr, pc in patch_cells[patches[r][c]]:
                if (pr, pc) != (r, c): eliminate(pr, pc)
            for dr in (-1, 0, 1):
                for dc in (-1, 0, 1):
                    if dr == 0 and dc == 0: continue
                    nr, nc = r + dr, c + dc
                    if 0 <= nr < size and 0 <= nc < size:
                        eliminate(nr, nc)

        technique_counts = {"naked_single": 0, "confinement": 0, "neighbor_overlap": 0}
        score = 0
        
        while True:
            progress = False
            
            # 1. Naked singles
            all_units = (
                [[(r, c) for c in range(size)] for r in range(size)] +
                [[(r, c) for r in range(size)] for c in range(size)] +
                [patch_cells[p] for p in range(size)]
            )
            for cells in all_units:
                if any(placed[r][c] for r, c in cells): continue
                avail = [(r, c) for r, c in cells if candidates[r][c]]
                if len(avail) == 1:
                    place(avail[0][0], avail[0][1])
                    technique_counts["naked_single"] += 1
                    score += 1
                    progress = True
                    break
                elif len(avail) == 0:
                    return False, score, technique_counts
            if progress: continue
            
            # 2. Confinement
            for p in range(size):
                if any(placed[r][c] for r, c in patch_cells[p]): continue
                avail = [(r, c) for r, c in patch_cells[p] if candidates[r][c]]
                if not avail: continue
                rows = {r for r, c in avail}
                if len(rows) == 1:
                    row = list(rows)[0]
                    for c in range(size):
                        if (row, c) not in avail and candidates[row][c]:
                            if eliminate(row, c):
                                progress = True
                                technique_counts["confinement"] += 1
                                score += 3
                cols = {c for r, c in avail}
                if len(cols) == 1:
                    col = list(cols)[0]
                    for r in range(size):
                        if (r, col) not in avail and candidates[r][col]:
                            if eliminate(r, col):
                                progress = True
                                technique_counts["confinement"] += 1
                                score += 3
            if progress: continue

            # 3. Common neighbors
            for cells in all_units:
                if any(placed[r][c] for r, c in cells): continue
                avail = [(r, c) for r, c in cells if candidates[r][c]]
                if len(avail) <= 1 or len(avail) > 4: continue
                def nbrs(r, c):
                    return {(r+dr, c+dc) for dr in (-1,0,1) for dc in (-1,0,1) 
                            if (dr!=0 or dc!=0) and 0<=r+dr<size and 0<=c+dc<size}
                common = nbrs(avail[0][0], avail[0][1])
                for r, c in avail[1:]:
                    common &= nbrs(r, c)
                for nr, nc in common:
                    if candidates[nr][nc]:
                        if eliminate(nr, nc):
                            progress = True
                            technique_counts["neighbor_overlap"] += 1
                            score += 5
                            
            if not progress:
                break
                
        tot = sum(sum(1 for c in range(size) if placed[r][c]) for r in range(size))
        return (tot == size), score, technique_counts

    def generate_puzzle(self):
        size = self.size
        flowers = self.valid_flowers()
        if not flowers: return None
        
        # Start with Voronoi patches around flowers
        grid = [[-1 for _ in range(size)] for _ in range(size)]
        for i, (r, c) in enumerate(flowers):
            grid[r][c] = i
            
        # Grow patches with some variance
        unassigned = size * size - size
        while unassigned > 0:
            for r in range(size):
                for c in range(size):
                    if grid[r][c] == -1:
                        # Find adjacent patch
                        adj = []
                        for dr, dc in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                            nr, nc = r + dr, c + dc
                            if 0 <= nr < size and 0 <= nc < size and grid[nr][nc] != -1:
                                adj.append(grid[nr][nc])
                        if adj:
                            grid[r][c] = random.choice(adj)
                            unassigned -= 1

        # Check connectivity helper
        def is_connected(p, temp_grid):
            cells = [(r, c) for r in range(size) for c in range(size) if temp_grid[r][c] == p]
            if not cells: return False
            visited = set([cells[0]])
            queue = deque([cells[0]])
            while queue:
                cr, cc = queue.popleft()
                for dr, dc in [(-1,0),(1,0),(0,-1),(0,1)]:
                    nr, nc = cr + dr, cc + dc
                    if (nr, nc) in cells and (nr, nc) not in visited:
                        visited.add((nr, nc))
                        queue.append((nr, nc))
            return len(visited) == len(cells)

        # Mutate grid borders to break extra solutions
        flower_set = set(flowers)
        for step in range(250):
            sols = self.count_solutions(grid, limit=2)
            if sols == 1:
                is_ded, score, tech = self.solve_deductive(grid)
                if is_ded:
                    return {
                        "size": size,
                        "patches": grid,
                        "flowers": flowers,
                        "difficulty_score": score,
                        "techniques": tech
                    }
            
            # Find a non-flower cell on a boundary between two patches
            boundary_candidates = []
            for r in range(size):
                for c in range(size):
                    if (r, c) in flower_set: continue
                    cur_p = grid[r][c]
                    for dr, dc in [(-1,0),(1,0),(0,-1),(0,1)]:
                        nr, nc = r + dr, c + dc
                        if 0 <= nr < size and 0 <= nc < size and grid[nr][nc] != cur_p:
                            boundary_candidates.append((r, c, grid[nr][nc]))
            
            if not boundary_candidates: break
            random.shuffle(boundary_candidates)
            for r, c, target_p in boundary_candidates[:15]:
                old_p = grid[r][c]
                grid[r][c] = target_p
                # Verify both patches remain fully connected
                if is_connected(old_p, grid) and is_connected(target_p, grid):
                    break
                else:
                    grid[r][c] = old_p
                    
        return None

if __name__ == "__main__":
    import time
    for sz in [6, 8]:
        for attempt in range(20):
            t0 = time.time()
            gen = FastOrchard(sz)
            p = gen.generate_puzzle()
            if p:
                print(f"Generated {sz}x{sz} in {time.time()-t0:.3f}s! Score={p['difficulty_score']} Tech={p['techniques']}")
                break
