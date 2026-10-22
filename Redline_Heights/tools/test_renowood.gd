extends SceneTree

func _init():
	var Renowood = load("res://scripts/renowood.gd")
	Renowood._setup()
	print("RENOWOOD PTS: ", Renowood.pts.size())
	print("RENOWOOD PADS: ", Renowood.pads.size())
	for i in range(Renowood.pads.size()):
		var p = Renowood.pads[i]
		print("Pad ", i, ": pos=", p.c, " h=", p.h, " r=", p.r)
	print("RENOWOOD DRIVES: ", Renowood.drives.size())
	for i in range(Renowood.drives.size()):
		var d = Renowood.drives[i]
		print("Drive ", i, ": len=", d.pts.size(), " start=", d.pts[0], " end=", d.pts[-1])
	quit()
