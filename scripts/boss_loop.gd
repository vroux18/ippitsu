extends RefCounted
## Outils partagés des boss des mondes 6 à 8 (pas de class_name : preload) :
##  - suivi du tracé d'une ruée (points au sol, ruées enchaînées comprises) ;
##  - plus grande boucle fermée du tracé autour d'un point (même règle que Tsuchigumo) ;
##  - coupe d'un segment (fil, chaîne) par un segment de ruée.

const UiKit = preload("res://scripts/ui_kit.gd")
const Toon = preload("res://scripts/toon.gd")
const LOOP_PTS := 120  # points mémorisés (find_loop est quadratique)


## Ajoute la ruée a..b au tracé `pts` (Vector2, espacés d'au moins 0.3 m).
static func record(pts: Array, a: Vector3, b: Vector3) -> void:
	if pts.is_empty():
		pts.append(Vector2(a.x, a.z))
	var last: Vector2 = pts[pts.size() - 1]
	var bb := Vector2(b.x, b.z)
	if last.distance_to(bb) >= 0.3 and pts.size() < LOOP_PTS:
		pts.append(bb)


## Plus grande boucle fermée du tracé qui contient c : auto-croisement, ou fin du trait revenue
## à 1.4 m au plus d'un point antérieur. Vide si aucune.
static func find_loop(pts: Array, c: Vector2) -> PackedVector2Array:
	var best := PackedVector2Array()
	var best_area := 0.0
	var n := pts.size()
	if n < 3:
		return best
	for j in range(2, n - 1):
		var a2: Vector2 = pts[j]
		var b2: Vector2 = pts[j + 1]
		for i in range(0, j - 1):
			var p1: Vector2 = pts[i]
			var p2: Vector2 = pts[i + 1]
			var hit = Geometry2D.segment_intersects_segment(p1, p2, a2, b2)
			if hit == null:
				continue
			var poly := PackedVector2Array()
			poly.append(hit)
			for k in range(i + 1, j + 1):
				var pk: Vector2 = pts[k]
				poly.append(pk)
			var ar := UiKit.poly_area(poly)
			if poly.size() >= 3 and ar > best_area and Geometry2D.is_point_in_polygon(c, poly):
				best = poly
				best_area = ar
	var last: Vector2 = pts[n - 1]
	for i in range(0, n - 8):
		var q: Vector2 = pts[i]
		if q.distance_to(last) > 1.4:
			continue
		var poly2 := PackedVector2Array()
		for k in range(i, n):
			var pk2: Vector2 = pts[k]
			poly2.append(pk2)
		var ar2 := UiKit.poly_area(poly2)
		if ar2 > best_area and Geometry2D.is_point_in_polygon(c, poly2):
			best = poly2
			best_area = ar2
	return best


## Vrai si la ruée a..b coupe le segment p..q (projetés au sol).
static func cuts(a: Vector3, b: Vector3, p: Vector3, q: Vector3) -> bool:
	var hit = Geometry2D.segment_intersects_segment(Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(p.x, p.z), Vector2(q.x, q.z))
	return hit != null


## Cercle-guide or posé au sol (rayon r) : « trace ta boucle ici ».
static func hint_ring(parent: Node3D, r: float, col: Color) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	var ring := TorusMesh.new()
	ring.inner_radius = r - 0.06
	ring.outer_radius = r + 0.06
	ring.rings = 48
	ring.ring_segments = 4
	var rm := Toon.part(n, ring, Toon.flat(Color(col, 0.5)), Vector3(0, 0.03, 0), Vector3(1, 0.05, 1))
	rm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n
