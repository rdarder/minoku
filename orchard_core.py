import random
from typing import List, Tuple, Dict, Optional

class OrchardSolver:
    def __init__(self, size: int, patches: List[List[int]]):
        self.size = size
        self.patches = patches
        self.candidates = [[True for _ in range(size)] for _ in range(size)]
        self.placed = [[False for _ in range(size)] for _ in range(size)]
        
        self.rows_cells = [[(r, c) for c in range(size)] for r in range(size)]
        self.cols_cells = [[(r, c) for r in range(size)] for c in range(size)]
        self.patch_cells: Dict[int, List[Tuple[int, int]]] = {p: [] for p in range(size)}
        for r in range(size):
            for c in range(size):
                self.patch_cells[self.patches[r][c]].append((r, c))

    def get_neighbors(self, r: int, c: int) -> List[Tuple[int, int]]:
        res = []
        for dr in (-1, 0, 1):
            for dc in (-1, 0, 1):
                if dr == 0 and dc == 0:
                    continue
                nr, nc = r + dr, c + dc
                if 0 <= nr < self.size and 0 <= nc < self.size:
                    res.append((nr, nc))
        return res

    def eliminate(self, r: int, c: int) -> bool:
        if self.candidates[r][c]:
            self.candidates[r][c] = False
            return True
        return False

    def place_flower(self, r: int, c: int) -> bool:
        if self.placed[r][c]:
            return False
        self.placed[r][c] = True
        
        for c2 in range(self.size):
            if c2 != c: self.eliminate(r, c2)
        for r2 in range(self.size):
            if r2 != r: self.eliminate(r2, c)
        p = self.patches[r][c]
        for pr, pc in self.patch_cells[p]:
            if (pr, pc) != (r, c): self.eliminate(pr, pc)
        for nr, nc in self.get_neighbors(r, c):
            self.eliminate(nr, nc)
        return True

    def count_solutions(self, limit: int = 2) -> int:
        solutions = 0
        cols_used = [False] * self.size
        patches_used = [False] * self.size
        placed_cols = [-10] * self.size

        def backtrack(row: int):
            nonlocal solutions
            if row == self.size:
                solutions += 1
                return
            
            for col in range(self.size):
                p = self.patches[row][col]
                if cols_used[col] or patches_used[p]:
                    continue
                if row > 0 and abs(placed_cols[row - 1] - col) <= 1:
                    continue
                
                cols_used[col] = True
                patches_used[p] = True
                placed_cols[row] = col

                backtrack(row + 1)
                
                placed_cols[row] = -10
                cols_used[col] = False
                patches_used[p] = False

                if solutions >= limit:
                    return

        backtrack(0)
        return solutions

    def solve_deductive(self) -> Tuple[bool, int, Dict[str, int]]:
        technique_counts = {
            "naked_single": 0,
            "confinement": 0,
            "neighbor_overlap": 0
        }
        score = 0
        
        while True:
            progress = False
            all_units = (
                [("row", self.rows_cells[r]) for r in range(self.size)] +
                [("col", self.cols_cells[c]) for c in range(self.size)] +
                [("patch", self.patch_cells[p]) for p in range(self.size)]
            )
            
            # 1. Naked single
            for unit_type, cells in all_units:
                if any(self.placed[r][c] for r, c in cells):
                    continue
                avail = [(r, c) for r, c in cells if self.candidates[r][c]]
                if len(avail) == 1:
                    r, c = avail[0]
                    self.place_flower(r, c)
                    technique_counts["naked_single"] += 1
                    score += 1
                    progress = True
                    break
                elif len(avail) == 0:
                    return False, score, technique_counts
            
            if progress:
                continue

            # 2. Confinement (Patch candidates all in one row or col)
            for p in range(self.size):
                if any(self.placed[r][c] for r, c in self.patch_cells[p]):
                    continue
                avail = [(r, c) for r, c in self.patch_cells[p] if self.candidates[r][c]]
                if not avail:
                    continue
                rows = {r for r, c in avail}
                if len(rows) == 1:
                    row = list(rows)[0]
                    for c in range(self.size):
                        if (row, c) not in avail and self.candidates[row][c]:
                            if self.eliminate(row, c):
                                progress = True
                                technique_counts["confinement"] += 1
                                score += 3
                cols = {c for r, c in avail}
                if len(cols) == 1:
                    col = list(cols)[0]
                    for r in range(self.size):
                        if (r, col) not in avail and self.candidates[r][col]:
                            if self.eliminate(r, col):
                                progress = True
                                technique_counts["confinement"] += 1
                                score += 3

            # 3. Confinement (Row/Col candidates all in one patch)
            for r in range(self.size):
                if any(self.placed[r][c] for c in range(self.size)): continue
                avail = [(r, c) for r, c in range(self.size) if self.candidates[r][c]]
                patches = {self.patches[r][c] for r, c in avail}
                if len(patches) == 1:
                    p = list(patches)[0]
                    for pr, pc in self.patch_cells[p]:
                        if pr != r and self.candidates[pr][pc]:
                            if self.eliminate(pr, pc):
                                progress = True
                                technique_counts["confinement"] += 1
                                score += 3

            for c in range(self.size):
                if any(self.placed[r][c] for r in range(self.size)): continue
                avail = [(r, c) for r in range(self.size) if self.candidates[r][c]]
                patches = {self.patches[r][c] for r, c in avail}
                if len(patches) == 1:
                    p = list(patches)[0]
                    for pr, pc in self.patch_cells[p]:
                        if pc != c and self.candidates[pr][pc]:
                            if self.eliminate(pr, pc):
                                progress = True
                                technique_counts["confinement"] += 1
                                score += 3

            # 4. Common Neighbor Overlap
            if not progress:
                for unit_type, cells in all_units:
                    if any(self.placed[r][c] for r, c in cells):
                        continue
                    avail = [(r, c) for r, c in cells if self.candidates[r][c]]
                    if len(avail) <= 1 or len(avail) > 4:
                        continue
                    common_nbrs = set(self.get_neighbors(avail[0][0], avail[0][1]))
                    for r, c in avail[1:]:
                        common_nbrs &= set(self.get_neighbors(r, c))
                    for nr, nc in common_nbrs:
                        if self.candidates[nr][nc]:
                            if self.eliminate(nr, nc):
                                progress = True
                                technique_counts["neighbor_overlap"] += 1
                                score += 5
            
            if not progress:
                break

        flowers_placed = sum(sum(1 for c in range(self.size) if self.placed[r][c]) for r in range(self.size))
        return (flowers_placed == self.size), score, technique_counts


class OrchardGenerator:
    def __init__(self, size: int):
        self.size = size

    def _generate_valid_flower_positions(self) -> Optional[List[Tuple[int, int]]]:
        flowers: List[Tuple[int, int]] = []
        cols_available = list(range(self.size))
        
        def backtrack(row: int):
            if row == self.size:
                return True
            cols = list(cols_available)
            random.shuffle(cols)
            for col in cols:
                conflict = False
                for pr, pc in flowers:
                    if abs(pr - row) <= 1 and abs(pc - col) <= 1:
                        conflict = True
                        break
                if conflict:
                    continue
                flowers.append((row, col))
                cols_available.remove(col)
                if backtrack(row + 1):
                    return True
                flowers.pop()
                cols_available.append(col)
            return False

        if backtrack(0):
            return flowers
        return None

    def _generate_partition(self, flowers: List[Tuple[int, int]]) -> List[List[int]]:
        """
        Grow patches with controlled shape variance.
        Smaller sizes (or some singletons) create clean clues for deduction!
        """
        grid = [[-1 for _ in range(self.size)] for _ in range(self.size)]
        for i, (r, c) in enumerate(flowers):
            grid[r][c] = i

        # Assign weights / max sizes to patches so not all are identical
        # Giving 1 or 2 patches small targets creates natural anchor clues!
        targets = [random.randint(2, self.size + 2) for _ in range(self.size)]
        counts = [1] * self.size
        
        cells_assigned = self.size
        total_cells = self.size * self.size
        
        while cells_assigned < total_cells:
            # Pick an unassigned cell that has an assigned neighbor
            candidates = []
            for r in range(self.size):
                for c in range(self.size):
                    if grid[r][c] == -1:
                        for dr, dc in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                            nr, nc = r + dr, c + dc
                            if 0 <= nr < self.size and 0 <= nc < self.size and grid[nr][nc] != -1:
                                p = grid[nr][nc]
                                weight = max(1, targets[p] - counts[p])
                                candidates.append(((r, c), p, weight))
            if not candidates:
                break
            
            # Weighted random selection
            weights = [c[2] for c in candidates]
            chosen = random.choices(candidates, weights=weights, k=1)[0]
            (r, c), p, _ = chosen
            if grid[r][c] == -1:
                grid[r][c] = p
                counts[p] += 1
                cells_assigned += 1

        # Fill any stubborn voids
        for r in range(self.size):
            for c in range(self.size):
                if grid[r][c] == -1:
                    for dr, dc in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                        nr, nc = r + dr, c + dc
                        if 0 <= nr < self.size and 0 <= nc < self.size and grid[nr][nc] != -1:
                            grid[r][c] = grid[nr][nc]
                            break
        return grid

    def generate_puzzle(self, max_attempts: int = 500) -> Optional[Dict]:
        for attempt in range(max_attempts):
            flowers = self._generate_valid_flower_positions()
            if not flowers:
                continue
            
            patches = self._generate_partition(flowers)
            
            solver = OrchardSolver(self.size, patches)
            if solver.count_solutions(limit=2) != 1:
                continue
                
            deductive_solver = OrchardSolver(self.size, patches)
            is_deductive, score, techniques = deductive_solver.solve_deductive()
            
            if is_deductive:
                return {
                    "size": self.size,
                    "patches": patches,
                    "flowers": flowers,
                    "difficulty_score": score,
                    "techniques": techniques
                }
        return None

if __name__ == "__main__":
    import time
    for sz in [6, 8, 10]:
        t0 = time.time()
        gen = OrchardGenerator(sz)
        p = gen.generate_puzzle(max_attempts=1000)
        dt = time.time() - t0
        if p:
            print(f"Generated {sz}x{sz} in {dt:.3f}s! Score: {p['difficulty_score']} Tech: {p['techniques']}")
        else:
            print(f"Could not generate {sz}x{sz} within attempts ({dt:.3f}s)")
