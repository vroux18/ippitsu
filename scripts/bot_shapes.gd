extends RefCounted
## Figures du robot testeur : points de passage des six formes (boucle, zigzag, trait droit, aller-retour,
## ensō, crochet), vérifiées avec StrokeShapes.detect sur un tracé simulé (même pas que ink_stroke.gd)
## avant d'être lancées. Fonctions statiques pures, plan XZ.

const StrokeShapes = preload("res://scripts/stroke_shapes.gd")
const STEP := 0.18  # = ink_stroke.gd STEP
const SHAPES := ["loop", "zigzag", "straight", "return", "enso", "hook"]


## Points de passage de la figure, depuis `o`, orientée selon `f` (unitaire, XZ), côté `side` (±1).
static func waypoints(shape: String, o: Vector3, f: Vector3, side: float) -> PackedVector3Array:
	var s := Vector3(-f.z, 0.0, f.x) * side
	var out := PackedVector3Array()
	match shape:
		"straight":
			out.append(o + f * 8.0)
		"zigzag":
			for c: Vector2 in [Vector2(1, 2), Vector2(2, 0), Vector2(3, 2), Vector2(4, 0)]:
				out.append(o + f * c.x + s * c.y)
		"return":
			for c: Vector2 in [Vector2(5, 0), Vector2(5, 0.4), Vector2(0.3, 0.5)]:
				out.append(o + f * c.x + s * c.y)
		"hook":
			var hk := deg_to_rad(30.0)
			for c: Vector2 in [Vector2(5, 0), Vector2(5.0 - 1.8 * cos(hk), 1.8 * sin(hk))]:
				out.append(o + f * c.x + s * c.y)
		"loop":
			# trochoïde (comme l'auto-test) : entrée droite, boucle de rayon 1,4, sortie droite
			var r := 1.4
			var sp := 0.5
			var base := Vector2(-sp * PI - 1.5, 2.0 * r)
			for k in range(81):
				var t := -PI + TAU * float(k) / 80.0
				var c := Vector2(sp * t - r * sin(t), r - r * cos(t)) - base
				out.append(o + f * c.x + s * c.y)
			var e := Vector2(sp * PI + 1.5, 2.0 * r) - base
			out.append(o + f * e.x + s * e.y)
		"enso":
			# cercle de rayon 2,4 qui part du héros et laisse une ouverture d'un mètre
			var rr := 2.4
			var c0 := o + f * rr
			var gap := 2.0 * asin(0.5 / rr)
			for k in range(1, 49):
				var t := (TAU - gap) * float(k) / 48.0
				out.append(c0 - f * (rr * cos(t)) + s * (rr * sin(t)))
	return out


## Tracé simulé : mêmes pas que InkStroke.extend_to (budget illimité), points ramenés par `clamp_fn`.
static func simulate(o: Vector3, wps: PackedVector3Array, clamp_fn: Callable) -> PackedVector3Array:
	var pts := PackedVector3Array([Vector3(o.x, 0.0, o.z)])
	for w: Vector3 in wps:
		var target: Vector3 = clamp_fn.call(w)
		target.y = 0.0
		var guard := 0
		while guard < 200:
			guard += 1
			var from := pts[pts.size() - 1]
			var d := from.distance_to(target)
			if d < STEP:
				break
			pts.append(from + (target - from) / d * STEP)
	return pts


## Cherche une orientation où la figure tient dans l'arène et reste reconnue (d'abord vers `toward`).
## Renvoie les points de passage, ou un tableau vide.
static func plan(shape: String, o: Vector3, toward: Vector3, clamp_fn: Callable) -> PackedVector3Array:
	var base := 0.0
	var tw := Vector3(toward.x - o.x, 0.0, toward.z - o.z)
	if tw.length_squared() > 0.0001:
		base = atan2(tw.z, tw.x)
	for k: int in [0, 1, -1, 2, -2, 3, -3, 4]:
		var ang := base + float(k) * PI / 4.0
		var f := Vector3(cos(ang), 0.0, sin(ang))
		for side: float in [1.0, -1.0]:
			var wps := waypoints(shape, o, f, side)
			var r := StrokeShapes.detect(simulate(o, wps, clamp_fn))
			if String(r.get("shape", "")) == shape:
				return wps
	return PackedVector3Array()


## Auto-contrôle : depuis quelques positions de l'arène, part de figures reconnues (forme -> [ok, essais]).
static func self_check(clamp_fn: Callable) -> Dictionary:
	var out := {}
	for shape: String in SHAPES:
		var ok := 0
		var n := 0
		for o: Vector3 in [Vector3(0, 0, 6.1), Vector3(0, 0, 0), Vector3(-3, 0, -5), Vector3(3.5, 0, 2), Vector3(-2, 0, 7.5)]:
			n += 1
			if not plan(shape, o, Vector3(0, 0, -8), clamp_fn).is_empty():
				ok += 1
		out[shape] = [ok, n]
	return out
