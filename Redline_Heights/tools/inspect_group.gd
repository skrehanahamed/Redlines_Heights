extends SceneTree

func _init():
	var Renowood = load("res://scripts/renowood.gd")
	var g0 = Renowood._group(Renowood.VILLA)
	var g1 = Renowood._group(Renowood.VILLA_POOL)
	print("VILLA box=", g0.box, " parts=", g0.parts.size())
	print("VILLA_POOL box=", g1.box, " parts=", g1.parts.size())
	quit()
