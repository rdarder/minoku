extends SceneTree

const OrchardCore = preload("res://scripts/OrchardCore.gd")

func _init():
	var p = OrchardCore.generate_puzzle(6, 59762294)
	print("Patches matrix:")
	var counts = {}
	for r in range(6):
		var row_str = ""
		for c in range(6):
			var pid = p["patches"][r][c]
			row_str += "%2d " % pid
			counts[pid] = counts.get(pid, 0) + 1
		print(row_str)
	print("Patch counts:", counts)
	quit()
