extends RefCounted
## Reconnaissance des formes spéciales du trait (UNIVERS.md §4.8).
## Fonctions statiques pures : on travaille dans le plan XZ (y ignoré / mis à 0).
## Usage : const StrokeShapes = preload("res://scripts/stroke_shapes.gd")
##         var info: Dictionary = StrokeShapes.detect(stroke.points)

const EPS := 0.000001
const CLEAN_DIST := 0.02        # points plus proches que ça = confondus
const MIN_LENGTH := 0.5         # trait trop court : aucune forme
const SIMPLIFY_TOL := 0.3       # tolérance RDP pour zigzag / crochet

# Ensō (cercle ouvert)
const ENSO_GAP := 1.5            # écart fin-début toléré (au moins ; grandit avec le rayon)
const ENSO_MIN_R := 1.6
const ENSO_ROUND := 0.34          # un cercle à main levée, un peu ovale ou cabossé, passe
const ENSO_MIN_TURN := 245.0
# Uzu (boucle)
const LOOP_TURN := 300.0
const LOOP_R_MIN := 0.6
const LOOP_R_MAX := 3.0         # en combat on trace grand : une grosse boucle reste une boucle
const LOOP_PAD := 4             # points ajoutés de part et d'autre de la boucle pour l'angle cumulé
# Kaeshi (aller-retour)
const RET_GAP := 1.2
const RET_FAR := 3.0
const RET_DEV := 0.8
const RET_SAMPLES := 24
# Inazuma (zigzag)
const ZZ_ANGLE := 85.0           # virage net (un Z dessiné vite tourne d'environ 110-150°, un N pressé ~80°)
const ZZ_SEG_MIN := 0.6
const ZZ_SEG_MAX := 12.0         # le pad agrandit le geste : les branches peuvent être longues
const ZZ_COUNT := 2              # un Z (2 virages) suffit
# Ittō (trait droit)
const ST_LEN := 7.0
const ST_DEV := 0.4
# Kagi (crochet) : changement de direction entre l'avant-dernier et le dernier segment
const HK_LAST := 1.5
const HK_PREV := 0.8
const HK_MIN := 120.0
const HK_MAX := 170.0  # l'aller-retour est testé avant : un retour court et replié reste un crochet


## Trait de combat : il part du héros, puis suit le doigt. Le geste du joueur commence au point `lead_n`
## (premier contact du doigt) : on lit d'abord ce geste seul, l'amorce depuis le héros ne doit pas casser la figure.
static func detect_lead(points: PackedVector3Array, lead_n: int) -> Dictionary:
	if lead_n > 0 and lead_n < points.size() - 2 and length(points.slice(0, lead_n + 1)) >= 1.0:
		var r := detect(points.slice(lead_n))
		if not r.is_empty():
			return r
	return detect(points)


## Détecte la forme du trait. Renvoie {} ou {"shape": String, ...infos}.
static func detect(points: PackedVector3Array) -> Dictionary:
	var p := _clean(points)
	if p.size() < 3 or length(p) < MIN_LENGTH:
		return {}
	var r := _detect_enso(p)
	if not r.is_empty():
		return r
	r = _detect_loop(p)
	if not r.is_empty():
		return r
	r = _detect_return(p)
	if not r.is_empty():
		return r
	# boucle ouverte (le trait tourne presque un tour complet sans se recouper) : une boucle, jamais un zigzag
	r = _detect_loop_open(p)
	if not r.is_empty():
		return r
	var s := simplify(p, SIMPLIFY_TOL)
	r = _detect_zigzag(s)
	if r.is_empty():
		r = _detect_zigzag_soft(p)
	if not r.is_empty():
		return r
	r = _detect_straight(p)
	if not r.is_empty():
		return r
	return _detect_hook(s)


# ---------------------------------------------------------------- utilitaires

## Longueur totale de la polyligne.
static func length(points: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i].distance_to(points[i - 1])
	return total


## Ramer–Douglas–Peucker en 2D (XZ), version itérative.
static func simplify(points: PackedVector3Array, tolerance: float) -> PackedVector3Array:
	var n := points.size()
	if n < 3:
		return points.duplicate()
	var keep := PackedByteArray()
	keep.resize(n)
	keep.fill(0)
	keep[0] = 1
	keep[n - 1] = 1
	var stack := PackedInt32Array([0, n - 1])
	while stack.size() >= 2:
		var b := stack[stack.size() - 1]
		var a := stack[stack.size() - 2]
		stack.resize(stack.size() - 2)
		var best := -1.0
		var idx := -1
		for k in range(a + 1, b):
			var d := _seg_dist(points[k], points[a], points[b])
			if d > best:
				best = d
				idx = k
		if idx >= 0 and best > tolerance:
			keep[idx] = 1
			stack.append(a)
			stack.append(idx)
			stack.append(idx)
			stack.append(b)
	var out := PackedVector3Array()
	for i in range(n):
		if keep[i] == 1:
			out.append(points[i])
	return out


## Angle de rotation signé cumulé (degrés) le long de la polyligne, dans le plan XZ.
static func turning_deg(points: PackedVector3Array) -> float:
	var total := 0.0
	var has_prev := false
	var prev := Vector2.ZERO
	for i in range(1, points.size()):
		var d := Vector2(points[i].x - points[i - 1].x, points[i].z - points[i - 1].z)
		if d.length_squared() < EPS:
			continue
		if has_prev:
			total += atan2(prev.cross(d), prev.dot(d))
		prev = d
		has_prev = true
	return rad_to_deg(total)


# ---------------------------------------------------------------- détecteurs

static func _detect_enso(p: PackedVector3Array) -> Dictionary:
	if absf(turning_deg(p)) < ENSO_MIN_TURN:
		return {}
	var c := _centroid(p)
	var st := _radius_stats(p, c)
	# un grand cercle peut rester plus ouvert : l'écart toléré suit le rayon
	if p[0].distance_to(p[p.size() - 1]) > maxf(ENSO_GAP, st.x * 1.1):
		return {}
	if st.x < ENSO_MIN_R or st.y / st.x >= ENSO_ROUND:
		return {}
	return {"shape": "enso", "center": c, "radius": st.x}


static func _detect_loop(p: PackedVector3Array) -> Dictionary:
	var n := p.size()
	for i in range(n - 1):
		for j in range(i + 2, n - 1):
			var t := _seg_hit(p[i], p[i + 1], p[j], p[j + 1])
			if t < 0.0:
				continue
			# sous-trait fermé : point de croisement -> boucle -> point de croisement
			var x := p[i].lerp(p[i + 1], t)
			var sub := PackedVector3Array([x])
			sub.append_array(p.slice(i + 1, j + 1))
			sub.append(x)
			var c := _centroid(sub)
			var st := _radius_stats(sub, c)
			if st.x < LOOP_R_MIN or st.x > LOOP_R_MAX:
				continue
			var a := maxi(0, i - LOOP_PAD)
			var b := mini(n - 1, j + 1 + LOOP_PAD)
			if absf(turning_deg(p.slice(a, b + 1))) < LOOP_TURN:
				continue
			# un grand cercle qui se recoupe au bout (le joueur a « fermé » son ensō en dépassant) reste un ensō
			if st.x >= ENSO_MIN_R and st.y / maxf(st.x, EPS) < ENSO_ROUND:
				return {"shape": "enso", "center": c, "radius": st.x}
			return {"shape": "loop", "center": c, "radius": st.x}
	# petit cercle refermé sans se recouper (trop petit pour un ensō) : c'est une boucle
	if absf(turning_deg(p)) >= LOOP_TURN:
		var c2 := _centroid(p)
		var st2 := _radius_stats(p, c2)
		if st2.x >= LOOP_R_MIN and st2.x < ENSO_MIN_R and st2.y / st2.x < ENSO_ROUND 				and p[0].distance_to(p[n - 1]) < maxf(0.6, st2.x * 0.8):
			return {"shape": "loop", "center": c2, "radius": st2.x}
	return {}


## Boucle ouverte : une boucle tracée vite ne se recoupe pas toujours (un « ρ » ou un « e » ouvert). Si une
## portion du trait tourne dans le même sens d'au moins LOOP_OPEN_TURN, avec un rayon de boucle, c'est une boucle.
## Testé avant le zigzag : les joueurs voyaient leurs boucles prises pour des zigzags (deux demi-virages).
const LOOP_OPEN_TURN := 250.0
const LOOP_OPEN_STEP := 0.15


static func _detect_loop_open(p: PackedVector3Array) -> Dictionary:
	var q := _resample_step(p, LOOP_OPEN_STEP)
	var run := _same_sign_run(q)
	if float(run[0]) < LOOP_OPEN_TURN:
		return {}
	var sub := q.slice(int(run[1]), int(run[2]) + 1)
	if sub.size() < 4:
		return {}
	var c := _centroid(sub)
	var st := _radius_stats(sub, c)
	if st.x < LOOP_R_MIN or st.x > LOOP_R_MAX or st.y / maxf(st.x, EPS) > 0.6:
		return {}
	# grand et rond : c'est un ensō un peu ouvert, pas une boucle (la boucle est le petit tour serré)
	if st.x >= ENSO_MIN_R and st.y / maxf(st.x, EPS) < ENSO_ROUND and float(run[0]) >= ENSO_MIN_TURN:
		return {"shape": "enso", "center": c, "radius": st.x}
	if st.x >= ENSO_MIN_R:
		return {}
	return {"shape": "loop", "center": c, "radius": st.x}


## Plus grand virage cumulé dans un même sens le long de q : [degrés, indice de début, indice de fin].
static func _same_sign_run(q: PackedVector3Array) -> Array:
	var best := 0.0
	var b0 := 0
	var b1 := 0
	var acc := 0.0
	var a0 := 0
	var prev := Vector2.ZERO
	var has_prev := false
	for i in range(1, q.size()):
		var d := Vector2(q[i].x - q[i - 1].x, q[i].z - q[i - 1].z)
		if d.length_squared() < EPS:
			continue
		if has_prev:
			var t := rad_to_deg(atan2(prev.cross(d), prev.dot(d)))
			if acc == 0.0 or signf(t) == signf(acc) or absf(t) < 2.0:
				acc += t
			else:
				acc = t
				a0 = i - 1
			if absf(acc) > absf(best):
				best = acc
				b0 = a0
				b1 = i
		prev = d
		has_prev = true
	return [absf(best), b0, b1]


static func _detect_return(p: PackedVector3Array) -> Dictionary:
	var start := p[0]
	var k := 0
	var far := 0.0
	for i in range(p.size()):
		var d := p[i].distance_to(start)
		if d > far:
			far = d
			k = i
	if far < RET_FAR:
		return {}
	# un long aller-retour tracé vite revient moins précisément : tolérances proportionnelles à l'aller
	if start.distance_to(p[p.size() - 1]) > _ret_gap(far):
		return {}
	# aller (début -> point le plus loin) vs retour retourné (fin -> point le plus loin)
	var aller := _resample_n(p.slice(0, k + 1), RET_SAMPLES)
	var back_src := p.slice(k)
	back_src.reverse()
	var retour := _resample_n(back_src, RET_SAMPLES)
	var dev := 0.0
	for s in range(RET_SAMPLES):
		dev += aller[s].distance_to(retour[s])
	dev /= float(RET_SAMPLES)
	if dev >= _ret_dev(far):
		return {}
	return {"shape": "return", "far": p[k]}


static func _ret_gap(far: float) -> float:
	return maxf(RET_GAP, far * 0.25)


static func _ret_dev(far: float) -> float:
	return maxf(RET_DEV, far * 0.14)


static func _detect_zigzag(s: PackedVector3Array) -> Dictionary:
	var corners: Array = []
	for i in range(1, s.size() - 1):
		var a := s[i] - s[i - 1]
		var b := s[i + 1] - s[i]
		var la := a.length()
		var lb := b.length()
		if la < ZZ_SEG_MIN or la > ZZ_SEG_MAX or lb < ZZ_SEG_MIN or lb > ZZ_SEG_MAX:
			continue
		if _angle_change(a, b) > ZZ_ANGLE:
			corners.append(s[i])
	if corners.size() < ZZ_COUNT:
		return {}
	return {"shape": "zigzag", "corners": corners}


## Zigzag à main levée : les coins tracés vite sont arrondis, RDP les coupe en deux demi-virages trop doux.
## On mesure le virage sur une fenêtre glissante (≈ 0,6 m avant / après), on garde les pics, et il faut
## au moins deux coins de sens alterné (un Z, un N, un W) séparés de vraies branches.
const ZZ_STEP := 0.2
const ZZ_WIN := 3
const ZZ_SOFT_ANGLE := 95.0
const ZZ_BRANCH := 1.0


static func _detect_zigzag_soft(p: PackedVector3Array) -> Dictionary:
	if length(p) < 3.5:
		return {}
	var q := _resample_step(p, ZZ_STEP)
	# un virage cumulé de plus d'un demi-tour dans le même sens : c'est une courbe (boucle ratée), pas un zigzag
	if float(_same_sign_run(q)[0]) > 200.0:
		return {}
	var n := q.size()
	if n < ZZ_WIN * 2 + 3:
		return {}
	# virage signé de chaque point sur la fenêtre
	var turn := PackedFloat32Array()
	turn.resize(n)
	turn.fill(0.0)
	for i in range(ZZ_WIN, n - ZZ_WIN):
		var a := Vector2(q[i].x - q[i - ZZ_WIN].x, q[i].z - q[i - ZZ_WIN].z)
		var b := Vector2(q[i + ZZ_WIN].x - q[i].x, q[i + ZZ_WIN].z - q[i].z)
		if a.length_squared() < EPS or b.length_squared() < EPS:
			continue
		turn[i] = rad_to_deg(atan2(a.cross(b), a.dot(b)))
	# pics : un coin par série de points qui tournent fort dans le même sens
	var idx: Array = []
	var sgn: Array = []
	var i := 0
	while i < n:
		if absf(turn[i]) <= ZZ_SOFT_ANGLE:
			i += 1
			continue
		var sg := signf(turn[i])
		var best := i
		while i < n and absf(turn[i]) > ZZ_SOFT_ANGLE * 0.6 and signf(turn[i]) == sg:
			if absf(turn[i]) > absf(turn[best]):
				best = i
			i += 1
		idx.append(best)
		sgn.append(sg)
	# plus longue suite de coins alternés, branches assez longues entre eux
	var corners: Array = []
	var run: Array = []
	for k in idx.size():
		var ci: int = idx[k]
		if not run.is_empty():
			var pi: int = run[run.size() - 1]
			var psg: float = sgn[idx.find(pi)]
			var branch := q[ci].distance_to(q[pi])
			if float(sgn[k]) == psg or branch < ZZ_BRANCH or branch > ZZ_SEG_MAX:
				if run.size() > corners.size():
					corners = run.duplicate()
				run = []
		run.append(ci)
	if run.size() > corners.size():
		corners = run
	if corners.size() < ZZ_COUNT:
		return {}
	# les deux bouts aussi doivent être de vraies branches
	var c0: int = corners[0]
	var c1: int = corners[corners.size() - 1]
	if q[0].distance_to(q[c0]) < ZZ_BRANCH * 0.7 or q[n - 1].distance_to(q[c1]) < ZZ_BRANCH * 0.7:
		return {}
	var pts: Array = []
	for c in corners:
		pts.append(q[int(c)])
	return {"shape": "zigzag", "corners": pts}


static func _detect_straight(p: PackedVector3Array) -> Dictionary:
	if length(p) < ST_LEN:
		return {}
	var a := p[0]
	var b := p[p.size() - 1]
	var tol := _st_dev(length(p))
	for q: Vector3 in p:
		if _seg_dist(q, a, b) >= tol:
			return {}
	return {"shape": "straight", "dir": _flat_dir(b - a)}


## Un long trait à main levée ondule un peu : l'écart toléré suit la longueur.
static func _st_dev(l: float) -> float:
	return maxf(ST_DEV, l * 0.035)


static func _detect_hook(s: PackedVector3Array) -> Dictionary:
	var n := s.size()
	if n < 3:
		return {}
	var last := s[n - 1] - s[n - 2]
	var prev := s[n - 2] - s[n - 3]
	if last.length() < HK_LAST or prev.length() < HK_PREV:
		return {}
	var ang := _angle_change(prev, last)
	if ang < HK_MIN or ang > HK_MAX:
		return {}
	return {"shape": "hook", "tip": s[n - 1], "dir": _flat_dir(last)}


# ---------------------------------------------------------------- aides internes

## Copie à plat (y = 0) sans points confondus.
static func _clean(points: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p: Vector3 in points:
		var q := Vector3(p.x, 0.0, p.z)
		if out.is_empty() or q.distance_to(out[out.size() - 1]) >= CLEAN_DIST:
			out.append(q)
	return out


## Distance 2D (XZ) du point p au segment [a, b].
static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ap := Vector2(p.x - a.x, p.z - a.z)
	var l2 := ab.length_squared()
	if l2 < EPS:
		return ap.length()
	var t := clampf(ap.dot(ab) / l2, 0.0, 1.0)
	return (ap - ab * t).length()


## Croisement strict de [ab] et [cd] en XZ : renvoie le paramètre t sur [ab], ou -1.
static func _seg_hit(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> float:
	var r := Vector2(b.x - a.x, b.z - a.z)
	var s := Vector2(d.x - c.x, d.z - c.z)
	var den := r.cross(s)
	if absf(den) < EPS:
		return -1.0
	var q := Vector2(c.x - a.x, c.z - a.z)
	var t := q.cross(s) / den
	var u := q.cross(r) / den
	if t <= 0.0 or t >= 1.0 or u <= 0.0 or u >= 1.0:
		return -1.0
	return t


## Barycentre pondéré par la longueur des segments.
static func _centroid(p: PackedVector3Array) -> Vector3:
	var acc := Vector3.ZERO
	var tot := 0.0
	for i in range(1, p.size()):
		var l := p[i].distance_to(p[i - 1])
		acc += (p[i] + p[i - 1]) * (0.5 * l)
		tot += l
	if tot < EPS:
		acc = Vector3.ZERO
		for q: Vector3 in p:
			acc += q
		return acc / float(maxi(1, p.size()))
	return acc / tot


## Rayon moyen (x) et écart-type du rayon (y) autour de c.
static func _radius_stats(p: PackedVector3Array, c: Vector3) -> Vector2:
	if p.is_empty():
		return Vector2.ZERO
	var m := 0.0
	for q: Vector3 in p:
		m += q.distance_to(c)
	m /= float(p.size())
	var v := 0.0
	for q: Vector3 in p:
		var e := q.distance_to(c) - m
		v += e * e
	v /= float(p.size())
	return Vector2(m, sqrt(v))


## Rééchantillonne la polyligne en `count` points régulièrement espacés.
static func _resample_n(p: PackedVector3Array, count: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	if p.is_empty():
		return out
	var total := length(p)
	if total < EPS or count < 2 or p.size() < 2:
		for _k in range(maxi(count, 1)):
			out.append(p[0])
		return out
	var step_l := total / float(count - 1)
	var i := 1
	var acc := 0.0
	for k in range(count):
		var target := step_l * float(k)
		while i < p.size() - 1 and acc + p[i].distance_to(p[i - 1]) < target:
			acc += p[i].distance_to(p[i - 1])
			i += 1
		var sl := p[i].distance_to(p[i - 1])
		var t := 0.0
		if sl >= EPS:
			t = clampf((target - acc) / sl, 0.0, 1.0)
		out.append(p[i - 1].lerp(p[i], t))
	return out


## Angle (0..180°) entre deux directions, en XZ.
static func _angle_change(a: Vector3, b: Vector3) -> float:
	var va := Vector2(a.x, a.z)
	var vb := Vector2(b.x, b.z)
	var la := va.length()
	var lb := vb.length()
	if la < EPS or lb < EPS:
		return 0.0
	return rad_to_deg(acos(clampf(va.dot(vb) / (la * lb), -1.0, 1.0)))


static func _flat_dir(v: Vector3) -> Vector3:
	var f := Vector3(v.x, 0.0, v.z)
	if f.length_squared() < EPS:
		return Vector3.ZERO
	return f.normalized()


# ---------------------------------------------------------------- diagnostic (dojo)
# Trait non reconnu : la figure la plus proche et la condition qui a manqué, avec les mêmes seuils que detect().

const FIG_NAMES := {"enso": "un ensō", "loop": "une boucle", "return": "un aller-retour", "zigzag": "un zigzag", "straight": "un trait droit", "hook": "un crochet"}
const NEAR_MIN := 0.35  # sous ce score : trait simple, aucune figure en vue
const ZZ_SOFT := 50.0   # virage mou : presque un angle de zigzag


## Phrase d'un résultat de near_miss() (vide si le trait est reconnu).
static func describe(m: Dictionary) -> String:
	if m.is_empty():
		return ""
	var sh := String(m.get("shape", ""))
	var why := String(m.get("reason", ""))
	if sh == "":
		if why == "trop court":
			return "Trait trop court"
		return "Trait simple : aucune figure"
	return "Presque %s : %s" % [String(FIG_NAMES.get(sh, sh)), why]


## Figure la plus proche d'un trait non reconnu.
## Renvoie {} si le trait est reconnu, sinon {"shape": figure ("" : aucune), "reason": String, "score": 0..1}.
static func near_miss(points: PackedVector3Array) -> Dictionary:
	var p := _clean(points)
	if p.size() < 3 or length(p) < MIN_LENGTH:
		return {"shape": "", "reason": "trop court", "score": 0.0}
	if not detect(points).is_empty():
		return {}
	var s := simplify(p, SIMPLIFY_TOL)
	var best: Dictionary = {"shape": "", "reason": "aucune figure", "score": 0.0}
	for c: Dictionary in [_miss_enso(p), _miss_loop(p), _miss_return(p), _miss_zigzag(s), _miss_straight(p), _miss_hook(s)]:
		if float(c["score"]) > float(best["score"]):
			best = c
	if float(best["score"]) < NEAR_MIN:
		return {"shape": "", "reason": "aucune figure", "score": float(best["score"])}
	return best


## Score = porte × produit des conditions (rapport ≥ 1 : tenue) ; la raison est la condition la plus manquée.
static func _worst(shape: String, checks: Array, gate: float) -> Dictionary:
	var score := clampf(gate, 0.0, 1.0)
	var reason := ""
	var low := 2.0
	for ck: Array in checks:
		var r := clampf(float(ck[0]), 0.0, 1.0)
		score *= r
		if r < low:
			low = r
			reason = String(ck[1])
	return {"shape": shape, "reason": reason, "score": score}


static func _miss_enso(p: PackedVector3Array) -> Dictionary:
	var turn := absf(turning_deg(p))
	var c := _centroid(p)
	var st := _radius_stats(p, c)
	var gap := p[0].distance_to(p[p.size() - 1])
	var gap_max := maxf(ENSO_GAP, st.x * 1.1)
	var rnd := st.y / maxf(st.x, EPS)
	var checks := [
		[turn / ENSO_MIN_TURN, "fais presque tout le tour"],
		[gap_max / maxf(gap, EPS), "cercle trop ouvert"],
		[st.x / ENSO_MIN_R, "cercle trop petit"],
		[ENSO_ROUND / maxf(rnd, EPS), "pas assez rond"],
	]
	# il faut au moins une bonne moitié de tour pour parler de cercle
	return _worst("enso", checks, (turn - 120.0) / 120.0)


static func _miss_loop(p: PackedVector3Array) -> Dictionary:
	var n := p.size()
	var best: Dictionary = {"shape": "loop", "reason": "", "score": 0.0}
	var crossed := false
	for i in range(n - 1):
		for j in range(i + 2, n - 1):
			var t := _seg_hit(p[i], p[i + 1], p[j], p[j + 1])
			if t < 0.0:
				continue
			crossed = true
			var x := p[i].lerp(p[i + 1], t)
			var sub := PackedVector3Array([x])
			sub.append_array(p.slice(i + 1, j + 1))
			sub.append(x)
			var st := _radius_stats(sub, _centroid(sub))
			var a := maxi(0, i - LOOP_PAD)
			var b := mini(n - 1, j + 1 + LOOP_PAD)
			var turn := absf(turning_deg(p.slice(a, b + 1)))
			var checks := [
				[st.x / LOOP_R_MIN, "boucle trop petite"],
				[LOOP_R_MAX / maxf(st.x, EPS), "boucle trop grande"],
				[turn / LOOP_TURN, "boucle trop plate"],
			]
			var r := _worst("loop", checks, 1.0)
			if float(r["score"]) > float(best["score"]):
				best = r
	if not crossed:
		# ça tourne, mais le trait ne se recoupe pas : la boucle reste ouverte
		var tt := absf(turning_deg(p))
		best = {"shape": "loop", "reason": "recoupe ton propre trait", "score": clampf((tt - 180.0) / 180.0, 0.0, 1.0) * 0.8}
	return best


static func _miss_return(p: PackedVector3Array) -> Dictionary:
	var start := p[0]
	var k := 0
	var far := 0.0
	for i in range(p.size()):
		var d := p[i].distance_to(start)
		if d > far:
			far = d
			k = i
	# part du trait après le point le plus loin : sans retour, ce n'est pas un aller-retour
	var back := 1.0 - float(k) / float(maxi(p.size() - 1, 1))
	if back < 0.15 or far < 0.5:
		return {"shape": "return", "reason": "", "score": 0.0}
	var gap := start.distance_to(p[p.size() - 1])
	var aller := _resample_n(p.slice(0, k + 1), RET_SAMPLES)
	var back_src := p.slice(k)
	back_src.reverse()
	var retour := _resample_n(back_src, RET_SAMPLES)
	var dev := 0.0
	for s in range(RET_SAMPLES):
		dev += aller[s].distance_to(retour[s])
	dev /= float(RET_SAMPLES)
	var checks := [
		[_ret_gap(far) / maxf(gap, EPS), "reviens jusqu'au départ"],
		[far / RET_FAR, "aller trop court"],
		[_ret_dev(far) / maxf(dev, EPS), "retour trop écarté de l'aller"],
	]
	return _worst("return", checks, back / 0.3)


static func _miss_zigzag(s: PackedVector3Array) -> Dictionary:
	var sharp := 0
	var soft := 0
	var n_short := 0
	var n_long := 0
	for i in range(1, s.size() - 1):
		var a := s[i] - s[i - 1]
		var b := s[i + 1] - s[i]
		var ang := _angle_change(a, b)
		if ang < ZZ_SOFT:
			continue
		var la := a.length()
		var lb := b.length()
		if la < ZZ_SEG_MIN or lb < ZZ_SEG_MIN:
			n_short += 1
		elif la > ZZ_SEG_MAX or lb > ZZ_SEG_MAX:
			n_long += 1
		elif ang > ZZ_ANGLE:
			sharp += 1
		else:
			soft += 1
	var reason := "il faut deux virages nets"
	if soft > 0 and soft >= n_short and soft >= n_long:
		reason = "angles trop doux"
	elif n_short > 0 and n_short >= n_long:
		reason = "branches trop courtes"
	elif n_long > 0:
		reason = "branches trop longues"
	var score := (float(sharp) + 0.6 * float(soft + n_short + n_long)) / float(ZZ_COUNT)
	return {"shape": "zigzag", "reason": reason, "score": clampf(score, 0.0, 0.95)}


static func _miss_straight(p: PackedVector3Array) -> Dictionary:
	var a := p[0]
	var b := p[p.size() - 1]
	var dev := 0.0
	for q: Vector3 in p:
		dev = maxf(dev, _seg_dist(q, a, b))
	var checks := [
		[length(p) / ST_LEN, "trop court"],
		[_st_dev(length(p)) / maxf(dev, EPS), "trop sinueux pour un trait droit"],
	]
	# un trait franchement courbe ou cassé n'est pas « presque droit »
	return _worst("straight", checks, (1.6 - dev) / 1.2)


static func _miss_hook(s: PackedVector3Array) -> Dictionary:
	var n := s.size()
	if n < 3:
		return {"shape": "hook", "reason": "", "score": 0.0}
	var last := s[n - 1] - s[n - 2]
	var prev := s[n - 2] - s[n - 3]
	var ang := _angle_change(prev, last)
	if ang < 60.0:
		return {"shape": "hook", "reason": "", "score": 0.0}
	var checks := [
		[last.length() / HK_LAST, "crochet trop court"],
		[prev.length() / HK_PREV, "premier trait trop court"],
		[ang / HK_MIN, "repars plus en arrière"],
		[HK_MAX / ang, "trop replié, presque un aller-retour"],
	]
	return _worst("hook", checks, (ang - 60.0) / 50.0)


# ---------------------------------------------------------------- auto-test

static func _resample_step(p: PackedVector3Array, step: float) -> PackedVector3Array:
	var n := maxi(2, int(ceil(length(p) / step)) + 1)
	return _resample_n(p, n)


static func _poly(coords: PackedVector2Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for c: Vector2 in coords:
		out.append(Vector3(c.x, 0.0, c.y))
	return out


static func _check(fails: Array, name: String, pts: PackedVector3Array, expected: String) -> void:
	var r := detect(pts)
	var got := ""
	if r.has("shape"):
		got = str(r["shape"])
	if got != expected:
		fails.append("%s : attendu '%s', obtenu '%s'" % [name, expected, got])


## Polylignes synthétiques -> liste des échecs (vide si tout passe).
static func self_test() -> Array:
	var fails: Array = []
	var step := 0.18
	# Ensō : cercle r2.5 ouvert de 1 m, léger tremblement
	var circ := PackedVector3Array()
	var gap := 2.0 * asin(0.5 / 2.5)
	for k in range(121):
		var t := (TAU - gap) * float(k) / 120.0
		var rr := 2.5 + 0.1 * sin(5.0 * t)
		circ.append(Vector3(3.0 + rr * cos(t), 0.0, 1.0 + rr * sin(t)))
	_check(fails, "enso", _resample_step(circ, step), "enso")
	# Ensō à main levée : ovale, cabossé, ouvert d'un quart de rayon de plus
	var ov := PackedVector3Array()
	for k in range(101):
		var t2 := (TAU - 0.55) * float(k) / 100.0
		var r2 := 2.2 + 0.35 * sin(3.0 * t2 + 0.7)
		ov.append(Vector3(r2 * 1.25 * cos(t2), 0.0, r2 * 0.85 * sin(t2)))
	_check(fails, "enso main levée", _resample_step(ov, step), "enso")
	# Uzu : boucle (trochoïde) au milieu d'un trait droit
	var R := 1.4
	var sp := 0.5
	var lp := PackedVector3Array([Vector3(-sp * PI - 4.0, 0.0, 2.0 * R)])
	for k in range(81):
		var t := -PI + TAU * float(k) / 80.0
		lp.append(Vector3(sp * t - R * sin(t), 0.0, R - R * cos(t)))
	lp.append(Vector3(sp * PI + 4.0, 0.0, 2.0 * R))
	_check(fails, "loop", _resample_step(lp, step), "loop")
	# Uzu ouverte : amorce droite, 300° d'arc de rayon 1,2, sortie sans se recouper (un « ρ » tracé vite)
	var lo := PackedVector3Array([Vector3(-3.0, 0.0, 0.0), Vector3(-1.5, 0.0, 0.0)])
	for k in range(61):
		var t3 := -PI / 2.0 + deg_to_rad(300.0) * float(k) / 60.0
		lo.append(Vector3(1.2 * cos(t3), 0.0, 1.2 + 1.2 * sin(t3)))
	lo.append(Vector3(-2.4, 0.0, 3.2))
	_check(fails, "boucle ouverte", _resample_step(lo, step), "loop")
	# Ensō dépassé : grand cercle r2.2 bouclé à 400° (le doigt a continué après la fermeture) -> ensō, pas boucle
	var ov2 := PackedVector3Array()
	for k in range(111):
		var t4 := deg_to_rad(400.0) * float(k) / 110.0
		ov2.append(Vector3(2.2 * cos(t4), 0.0, 2.2 * sin(t4)))
	_check(fails, "enso dépassé", _resample_step(ov2, step), "enso")
	# Ensō ouvert d'un tiers (r2.0, 260°) -> ensō (tolérant), pas boucle
	var ov3 := PackedVector3Array()
	for k in range(81):
		var t5 := deg_to_rad(260.0) * float(k) / 80.0
		ov3.append(Vector3(2.0 * cos(t5), 0.0, 2.0 * sin(t5)))
	_check(fails, "enso ouvert", _resample_step(ov3, step), "enso")
	# Kaeshi : aller-retour légèrement décalé
	_check(fails, "return", _resample_step(_poly(PackedVector2Array([Vector2(0, 0), Vector2(5, 0), Vector2(5, 0.4), Vector2(0.3, 0.5)])), step), "return")
	# Inazuma : 3 angles vifs
	_check(fails, "zigzag", _resample_step(_poly(PackedVector2Array([Vector2(0, 0), Vector2(1, 2), Vector2(2, 0), Vector2(3, 2), Vector2(4, 0)])), step), "zigzag")
	# Ittō : droite de 8 m
	_check(fails, "straight", _resample_step(_poly(PackedVector2Array([Vector2(0, 0), Vector2(8, 0.2)])), step), "straight")
	# Kagi : 5 m puis retour à 150° sur 1.8 m
	# Z tracé au pad : 2 virages, branches longues
	_check(fails, "zigzag Z", _resample_step(_poly(PackedVector2Array([Vector2(0, 0), Vector2(6, 0), Vector2(0.5, 4), Vector2(6.5, 4)])), step), "zigzag")
	var hk := deg_to_rad(30.0)
	_check(fails, "hook", _resample_step(_poly(PackedVector2Array([Vector2(0, 0), Vector2(5, 0), Vector2(5.0 - 1.8 * cos(hk), 1.8 * sin(hk))])), step), "hook")
	# petit cercle refermé (r 1.1) sans croisement : boucle
	var sc := PackedVector3Array()
	for k in range(61):
		var t3 := (TAU - 0.3) * float(k) / 60.0
		sc.append(Vector3(1.1 * cos(t3), 0.0, 1.1 * sin(t3)))
	_check(fails, "petite boucle fermée", _resample_step(sc, step), "loop")
	# aller-retour long et approximatif (combat)
	_check(fails, "return large", _resample_step(_poly(PackedVector2Array([Vector2(0, 0), Vector2(8, 0), Vector2(8.3, 0.6), Vector2(0.6, 0.9)])), step), "return")
	# ensō tracé loin du héros : amorce droite depuis le héros, puis le cercle du doigt
	var lead := _resample_step(_poly(PackedVector2Array([Vector2(-4, -5), Vector2(5.5, 1.0)])), step)
	var nl := lead.size() - 1
	lead.append_array(_resample_step(circ.slice(0), step).slice(1))
	var rl := detect_lead(lead, nl)
	if String(rl.get("shape", "")) != "enso":
		fails.append("enso avec amorce : attendu 'enso', obtenu '%s'" % String(rl.get("shape", "")))
	# éclair tracé vite au doigt : coins arrondis (deux lissages de Chaikin), virages d'environ 120°
	var zr := _poly(PackedVector2Array([Vector2(0, 0), Vector2(3, 1.6), Vector2(0.6, 3.0), Vector2(3.6, 4.6)]))
	for _it in 2:
		var sm := PackedVector3Array([zr[0]])
		for k in range(zr.size() - 1):
			sm.append(zr[k].lerp(zr[k + 1], 0.25))
			sm.append(zr[k].lerp(zr[k + 1], 0.75))
		sm.append(zr[zr.size() - 1])
		zr = sm
	_check(fails, "zigzag arrondi", _resample_step(zr, step), "zigzag")
	# gribouillis court
	var scr := PackedVector3Array()
	for k in range(18):
		scr.append(Vector3(0.18 * float(k), 0.0, 0.25 * sin(float(k) * 1.7) + 0.1 * cos(float(k) * 3.1)))
	_check(fails, "scribble", scr, "")
	# cas dégénérés
	_check(fails, "vide", PackedVector3Array(), "")
	_check(fails, "un point", PackedVector3Array([Vector3(1, 0, 1)]), "")
	var same := PackedVector3Array()
	for _k in range(10):
		same.append(Vector3(1, 0, 1))
	_check(fails, "confondus", same, "")
	_check(fails, "courbe douce", _resample_step(_poly(PackedVector2Array([Vector2(0, 0), Vector2(2, 0.5), Vector2(4, 1.5), Vector2(5, 3)])), step), "")
	return fails
