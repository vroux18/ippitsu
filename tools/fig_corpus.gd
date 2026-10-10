extends SceneTree
## Corpus de gestes réalistes pour la reconnaissance des figures (scripts/stroke_shapes.gd).
## Chaque figure est générée procéduralement comme un pouce sur téléphone : tailles (petit / moyen / grand,
## en mètres au sol : 1 cm d'écran vaut 1,4 m en bas de l'arène, 1,9 m au centre, 2,4 m en haut — un geste
## de pouce fait 1 à 4 cm), tremblement, vitesse variable (points espacés de 0,05 à 0,6 m), rotation
## quelconque, légère anisotropie (perspective), amorce depuis le héros (lead), dépassement en fin de geste,
## coins arrondis ; plus des contre-exemples qui ne doivent donner aucune figure.
## Lancement : `godot --headless --path . -- --figtest` (main._figtest) ou `--script tools/fig_corpus.gd`.
## Imprime la matrice de confusion (attendu × détecté), le taux par figure, les ratés, la stabilité de la
## lecture en direct (trait sans ses 30 derniers centimètres), et la réussite des figures du robot.

const StrokeShapes = preload("res://scripts/stroke_shapes.gd")
const BotShapes = preload("res://scripts/bot_shapes.gd")

const FIGS := ["enso", "loop", "return", "zigzag", "straight", "hook"]
const COLS := ["enso", "loop", "return", "zigzag", "straight", "hook", ""]
const PER_FIG := 36       # variantes par figure (3 tailles × 12)
const SEED := 20261010
const LAID_STEP := 0.18   # pas du trait posé (ink_stroke.gd STEP)
const PROBE := 0.3        # la lecture en direct se fait tous les 30 cm (main._touch_move)


# ---------------------------------------------------------------- lancement

func _init() -> void:
	run(true)
	quit()


## Joue tout le corpus (graine `seed` : une autre graine, d'autres gestes) ;
## renvoie {"ok": int, "n": int, "rate": {fig: float}, "fails": Array, "unstable": Array, "bot_ok": bool}.
static func run(verbose: bool, seed: int = SEED) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var samples := build(rng)
	var mat := {}
	for a in COLS:
		var row := {}
		for b in COLS:
			row[b] = 0
		mat[a] = row
	var fails: Array = []
	var unstable: Array = []
	var ok := 0
	var fp := 0
	for s: Dictionary in samples:
		var pts: PackedVector3Array = s["pts"]
		var want := String(s["want"])
		var got := _shape(_detect(s, pts))
		mat[want][got] = int(mat[want][got]) + 1
		if got == want:
			ok += 1
		else:
			var why := ""
			if got == "":
				why = " — " + StrokeShapes.describe(StrokeShapes.near_miss(pts.slice(maxi(0, int(s.get("lead", -1))))))
			fails.append("%s : attendu '%s', obtenu '%s'%s" % [String(s["name"]), want, got, why])
			if want == "":
				fp += 1
		# lecture en direct : le trait sans ses 30 derniers centimètres doit donner la même figure (ou rien)
		if got != "":
			var cut := _cut_end(pts, PROBE)
			var live := _shape(_detect(s, cut))
			if live != "" and live != got:
				unstable.append("%s : en direct '%s', final '%s'" % [String(s["name"]), live, got])
	var rate := {}
	for f in FIGS:
		var tot := 0
		for b in COLS:
			tot += int(mat[f][b])
		rate[f] = float(mat[f][f]) / float(maxi(tot, 1))
	var bot := _bot_check()
	if verbose:
		print("FIGTEST corpus : %d échantillons, %d justes (%.1f %%)" % [samples.size(), ok, 100.0 * float(ok) / float(maxi(samples.size(), 1))])
		var head := "FIGTEST %-10s" % "att.\\dét."
		for b in COLS:
			head += "%9s" % (b if b != "" else "(rien)")
		print(head)
		for a in COLS:
			var line := "FIGTEST %-10s" % (a if a != "" else "(rien)")
			for b in COLS:
				line += "%9d" % int(mat[a][b])
			print(line)
		for f in FIGS:
			print("FIGTEST taux %-9s : %5.1f %%" % [f, 100.0 * float(rate[f])])
		var cnt := 0
		for b in COLS:
			cnt += int(mat[""][b])
		print("FIGTEST contre-exemples : %d figures détectées sur %d" % [fp, cnt])
		print("FIGTEST stabilité en direct : %d changements de figure sur %d reconnus" % [unstable.size(), ok])
		for u in unstable:
			print("FIGTEST   instable : ", u)
		for f in fails:
			print("FIGTEST   raté : ", f)
		for k in bot.keys():
			var r: Array = bot[k]
			print("FIGTEST robot %-9s : %d/%d orientations reconnues" % [String(k), int(r[0]), int(r[1])])
	var bot_ok := true
	for k in bot.keys():
		if int(bot[k][0]) != int(bot[k][1]):
			bot_ok = false
	return {"ok": ok, "n": samples.size(), "rate": rate, "fails": fails, "unstable": unstable, "bot_ok": bot_ok}


static func _detect(s: Dictionary, pts: PackedVector3Array) -> Dictionary:
	var lead := int(s.get("lead", -1))
	if lead >= 0:
		return StrokeShapes.detect_lead(pts, lead)
	return StrokeShapes.detect(pts)


static func _shape(r: Dictionary) -> String:
	return String(r.get("shape", ""))


## Les figures du robot (bot_shapes.gd) : 8 directions × 2 côtés, sans bords ; toutes doivent être reconnues.
static func _bot_check() -> Dictionary:
	var out := {}
	for shape: String in BotShapes.SHAPES:
		var n := 0
		var ok := 0
		for k in 8:
			var ang := float(k) * PI / 4.0
			var f := Vector3(cos(ang), 0.0, sin(ang))
			for side: float in [1.0, -1.0]:
				n += 1
				var wps: PackedVector3Array = BotShapes.waypoints(shape, Vector3.ZERO, f, side)
				var pts: PackedVector3Array = BotShapes.simulate(Vector3.ZERO, wps, Callable(FigCorpusClamp, "same"))
				if _shape(StrokeShapes.detect(pts)) == shape:
					ok += 1
		out[shape] = [ok, n]
	return out


class FigCorpusClamp:
	static func same(p: Vector3) -> Vector3:
		return p


# ---------------------------------------------------------------- corpus

## Tous les échantillons : [{name, pts, want, lead}].
static func build(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for k in PER_FIG:
		var size := k % 3  # 0 petit, 1 moyen, 2 grand
		out.append(_sample(rng, "enso", size, k))
		out.append(_sample(rng, "loop", size, k))
		out.append(_sample(rng, "return", size, k))
		out.append(_sample(rng, "zigzag", size, k))
		out.append(_sample(rng, "straight", size, k))
		out.append(_sample(rng, "hook", size, k))
	for k in 12:
		out.append(_counter(rng, "wander", k))
	for k in 9:
		out.append(_counter(rng, "C", k))
	for k in 9:
		out.append(_counter(rng, "S", k))
	for k in 6:
		out.append(_counter(rng, "V", k))
	for k in 6:
		out.append(_counter(rng, "bent", k))
	for k in 4:
		out.append(_counter(rng, "arc", k))
	return out


static func _sample(rng: RandomNumberGenerator, fig: String, size: int, k: int) -> Dictionary:
	var g := PackedVector2Array()
	var tag := ""
	match fig:
		"enso":
			var r := _pick(rng, size, [1.5, 2.0], [2.0, 3.0], [3.0, 4.5])
			# ouvert jusqu'à 35 %, ou dépassé (le doigt continue après la fermeture) jusqu'à 60° de plus
			var turn := rng.randf_range(234.0, 360.0) if k % 3 != 2 else rng.randf_range(360.0, 420.0)
			g = _circle(rng, r, turn, 0.08)
			tag = "r%.1f %d°" % [r, int(turn)]
		"loop":
			var r := _pick(rng, size, [0.6, 0.9], [0.9, 1.2], [1.2, 2.2])
			if k % 4 == 3:
				# petit cercle seul, refermé ou presque, sans se recouper : une boucle (trop petit pour un ensō)
				r = rng.randf_range(0.6, 1.0)
				g = _circle(rng, r, rng.randf_range(300.0, 400.0), 0.1)
				tag = "seule r%.1f" % r
			else:
				var turn := rng.randf_range(250.0, 400.0)
				# une grande boucle (r > 1,2) n'est une boucle, et pas un ensō, que prise entre deux longues amorces
				var tmin := 0.8 if size < 2 else 1.4 * r
				var tin := rng.randf_range(tmin, 4.0)
				var tout := rng.randf_range(tmin, 4.0)
				g = _curl(r, turn, tin, tout)
				tag = "r%.1f %d° amorces %.1f/%.1f" % [r, int(turn), tin, tout]
		"return":
			var far := _pick(rng, size, [3.2, 4.5], [4.5, 6.5], [6.5, 9.0])
			var off := rng.randf_range(0.0, 0.2) * far
			var gap := rng.randf_range(0.0, 0.22) * far
			var bow := rng.randf_range(0.0, 0.08) * far
			g = _hairpin(far, off, gap, bow)
			tag = "aller %.1f décalé %.1f écart %.1f" % [far, off, gap]
		"zigzag":
			var corners := 2 + k % 3
			var br := _pick(rng, size, [1.3, 1.8], [1.8, 2.8], [2.8, 4.5])  # (sous 1,3 m, moins d'un centimètre : illisible)
			var ang := rng.randf_range(90.0, 145.0)  # (UNIVERS : > 100° ; sous 90°, c'est une vague ; au-delà, replié)
			g = _zig(rng, corners, br, ang)
			tag = "%d virages branche %.1f angle %d°" % [corners, br, int(ang)]
		"straight":
			var l := _pick(rng, size, [7.0, 8.0], [8.0, 10.0], [10.0, 12.0])
			var bow := rng.randf_range(0.0, 0.25)
			g = _bowed(l, bow)
			tag = "%.1f m flèche %.2f" % [l, bow]
		"hook":
			var main := _pick(rng, size, [2.0, 3.0], [3.0, 4.5], [4.5, 6.0])
			# le crochet est une barbe au bout du trait : au plus 60 % du trait (plus long et replié, il revient
			# près du départ : un aller-retour) ; crochets courts (1,2-1,6 m)
			var last := minf(0.6 * main, rng.randf_range(1.3, 3.0) if k % 3 != 0 else rng.randf_range(1.3, 1.6))
			var ang := rng.randf_range(125.0, 160.0)
			g = PackedVector2Array([Vector2(0, 0), Vector2(main, 0), Vector2(main, 0) + Vector2(cos(deg_to_rad(ang)), sin(deg_to_rad(ang))) * last])
			tag = "%.1f puis %.1f à %d°" % [main, last, int(ang)]
	# coins arrondis : le pouce arrondit d'autant plus que le geste est grand (jusqu'à un cinquième de la branche)
	var round_m := 0.0
	if fig == "zigzag":
		round_m = rng.randf_range(0.0, 0.2) * _len2(g) / float(2 + k % 3 + 1)
	elif fig == "hook":
		round_m = rng.randf_range(0.0, 0.2) * g[1].distance_to(g[2])
	elif fig == "return":
		round_m = rng.randf_range(0.0, 0.06) * _len2(g)
	var over := rng.randf_range(0.2, 1.0) if k % 5 == 1 and fig in ["loop", "zigzag", "return"] else 0.0  # (le crochet finit où il finit)
	var laid := k % 2 == 0
	var pts := _finish(rng, g, round_m, over, laid)
	var name := "%s %s #%d (%s%s%s)" % [fig, ["petit", "moyen", "grand"][size], k, tag, ", posé" if laid else ", brut", ", dépassé %.1f" % over if over > 0.0 else ""]
	var s := {"name": name, "pts": pts, "want": fig, "lead": -1}
	if k % 3 == 1:
		_add_lead(rng, s)
	return s


static func _counter(rng: RandomNumberGenerator, kind: String, k: int) -> Dictionary:
	var g := PackedVector2Array()
	var tag := kind
	match kind:
		"wander":
			# trait quelconque : courbe douce qui serpente un peu, 3 à 8 m
			var l := rng.randf_range(3.0, 8.0)
			var n := 40
			var w := rng.randf_range(0.3, 1.2)
			var bend := deg_to_rad(rng.randf_range(2.0, 3.0)) * (1.0 if rng.randf() < 0.5 else -1.0)  # 80 à 120° au total
			for _try in 6:
				g = PackedVector2Array()
				var ang := 0.0
				var p := Vector2.ZERO
				for i in n:
					g.append(p)
					ang += deg_to_rad(rng.randf_range(-14.0, 14.0)) * w + bend
					p += Vector2(cos(ang), sin(ang)) * (l / float(n))
				# un hasard presque droit serait un vrai trait droit : on retire
				var sag := 0.0
				for q: Vector2 in g:
					sag = maxf(sag, _seg_dist2(q, g[0], g[g.size() - 1]))
				if sag > 0.12 * l:
					break
			tag = "trait quelconque %.1f m" % l
		"C":
			# un C : arc d'un demi-tour (jusqu'à 180° ; au-delà, jusqu'au tiers ouvert, c'est la zone ambiguë) : pas un ensō
			var r := rng.randf_range(1.2, 4.0)
			var turn := rng.randf_range(110.0, 180.0)
			g = _circle(rng, r, turn, 0.04)
			tag = "C r%.1f %d°" % [r, int(turn)]
		"S":
			# un S : deux arcs opposés : pas un zigzag
			var r := rng.randf_range(1.0, 2.5)
			var turn := rng.randf_range(140.0, 180.0)
			var a := _arc(Vector2(0, -r), r, PI / 2.0, PI / 2.0 - deg_to_rad(turn))
			var e := a[a.size() - 1]
			var dir := (e - a[a.size() - 2]).normalized()
			var c2 := e + Vector2(-dir.y, dir.x) * r
			var a0 := (e - c2).angle()
			var b := _arc(c2, r, a0, a0 + deg_to_rad(turn))
			g = a
			g.append_array(b.slice(1))
			tag = "S r%.1f %d°" % [r, int(turn)]
		"V":
			# un seul virage à 50-100° au milieu : ni zigzag, ni crochet
			var l1 := rng.randf_range(2.0, 4.0)
			var l2 := rng.randf_range(2.0, 4.0)
			var ang := rng.randf_range(50.0, 90.0)
			g = PackedVector2Array([Vector2(0, 0), Vector2(l1, 0), Vector2(l1, 0) + Vector2(cos(deg_to_rad(ang)), sin(deg_to_rad(ang))) * l2])
			tag = "V %d°" % int(ang)
		"bent":
			# long trait cassé de 25-40° au milieu : pas un trait droit
			var l := rng.randf_range(7.0, 10.0)
			var ang := deg_to_rad(rng.randf_range(25.0, 40.0))
			g = PackedVector2Array([Vector2(0, 0), Vector2(l * 0.5, 0), Vector2(l * 0.5, 0) + Vector2(cos(ang), sin(ang)) * l * 0.5])
			tag = "cassé %d°" % int(rad_to_deg(ang))
		"arc":
			# arc doux de 50-95° : une ruée courbe, aucune figure
			var r := rng.randf_range(2.5, 5.0)
			g = _circle(rng, r, rng.randf_range(50.0, 95.0), 0.03)
			tag = "arc r%.1f" % r
	var pts := _finish(rng, g, rng.randf_range(0.0, 0.3), 0.0, k % 2 == 0)
	return {"name": "contre-exemple #%d (%s)" % [k, tag], "pts": pts, "want": "", "lead": -1}


# ---------------------------------------------------------------- gabarits (plan 2D, mètres)

static func _pick(rng: RandomNumberGenerator, size: int, s: Array, m: Array, l: Array) -> float:
	var r: Array = [s, m, l][size]
	return rng.randf_range(float(r[0]), float(r[1]))


## Cercle de rayon r parcouru sur `turn` degrés, rayon ondulé (main levée), départ en angle quelconque.
static func _circle(rng: RandomNumberGenerator, r: float, turn: float, wobble: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var a0 := rng.randf_range(0.0, TAU)
	var ph := rng.randf_range(0.0, TAU)
	var sgn := 1.0 if rng.randf() < 0.5 else -1.0
	var n := maxi(24, int(turn / 4.0))
	for i in n + 1:
		var t := deg_to_rad(turn) * float(i) / float(n)
		var rr := r * (1.0 + wobble * sin(2.0 * t + ph) + wobble * 0.6 * sin(3.0 * t))
		var a := a0 + sgn * t
		out.append(Vector2(cos(a), sin(a)) * rr)
	return out


static func _arc(c: Vector2, r: float, a0: float, a1: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := maxi(12, int(absf(a1 - a0) / deg_to_rad(4.0)))
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / float(n))
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


## Boucle dans un trait : amorce droite, arc tangent de `turn` degrés et de rayon r, sortie tangente.
static func _curl(r: float, turn: float, tin: float, tout: float) -> PackedVector2Array:
	var out := PackedVector2Array([Vector2(-tin, 0.0), Vector2(0.0, 0.0)])
	# tangent en (0,0) dirigé +x, tourne à gauche : centre en (0, r)
	var arc := _arc(Vector2(0.0, r), r, -PI / 2.0, -PI / 2.0 + deg_to_rad(turn))
	out.append_array(arc.slice(1))
	var e := arc[arc.size() - 1]
	var dir := (e - arc[arc.size() - 2]).normalized()
	out.append(e + dir * tout)
	return out


## Aller-retour : aller de `far` (bombé de `bow`), demi-tour, retour décalé de `off`, fin à `gap` du départ.
static func _hairpin(far: float, off: float, gap: float, bow: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := 24
	for i in n + 1:
		var t := float(i) / float(n)
		out.append(Vector2(far * t, bow * sin(PI * t)))
	out.append(Vector2(far + off * 0.5, off * 0.5))
	# la fin est à `gap` du départ, du côté du retour
	var e := Vector2(0.4 * far, maxf(off, 0.01)).normalized() * gap
	for i in range(1, n + 1):
		var t := float(i) / float(n)
		out.append(Vector2(far, off).lerp(e, t) + Vector2(0.0, bow * 0.6 * sin(PI * t)))
	return out


## Zigzag : `corners` virages alternés d'environ `ang` degrés, branches ~`br` (± 30 %).
static func _zig(rng: RandomNumberGenerator, corners: int, br: float, ang: float) -> PackedVector2Array:
	var out := PackedVector2Array([Vector2.ZERO])
	var dir := 0.0
	var p := Vector2.ZERO
	var sgn := 1.0 if rng.randf() < 0.5 else -1.0
	for i in corners + 1:
		var l := br * rng.randf_range(0.7, 1.3)
		p += Vector2(cos(dir), sin(dir)) * l
		out.append(p)
		dir += sgn * deg_to_rad(ang * rng.randf_range(0.92, 1.08))
		sgn = -sgn
	return out


static func _bowed(l: float, bow: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 25:
		var t := float(i) / 24.0
		out.append(Vector2(l * t, bow * sin(PI * t)))
	return out


# ---------------------------------------------------------------- réalisme du geste

## Gabarit -> geste : coins arrondis (`round_m`), anisotropie légère, rotation, tremblement, dépassement en
## fin de geste (`over` m dans la dernière direction), puis échantillonnage posé (0,18 m) ou brut (irrégulier).
static func _finish(rng: RandomNumberGenerator, g: PackedVector2Array, round_m: float, over: float, laid: bool) -> PackedVector3Array:
	var dense := _resample2(g, 0.05)
	if round_m > 0.0:
		dense = _smooth(dense, int(round_m / 0.05))
	# anisotropie (perspective au sol : un cercle à l'écran est un peu ovale au sol) et rotation
	var an := rng.randf_range(1.0, 1.2)  # (en jeu, le geste brut est redressé par la caméra ; il en reste un peu)
	var an_a := rng.randf_range(0.0, PI)
	var rot := rng.randf_range(0.0, TAU)
	var off := Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(-8.0, 8.0))
	var pts := PackedVector2Array()
	for p: Vector2 in dense:
		var q := p.rotated(-an_a)
		q.x *= an
		pts.append(q.rotated(an_a + rot) + off)
	if over > 0.0 and pts.size() >= 2:
		var d := (pts[pts.size() - 1] - pts[pts.size() - 2]).normalized()
		pts.append(pts[pts.size() - 1] + d * over)
		pts = _resample2(pts, 0.05)
	# tremblement : balancement lent + frisson rapide, perpendiculaires au trait
	var sway := rng.randf_range(0.03, 0.12)
	var jit := rng.randf_range(0.01, 0.05)
	var f1 := rng.randf_range(0.6, 1.6)
	var ph := rng.randf_range(0.0, TAU)
	var s := 0.0
	var trem := PackedVector2Array()
	for i in pts.size():
		if i > 0:
			s += pts[i].distance_to(pts[i - 1])
		var a := pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]
		var nrm := Vector2(-a.y, a.x).normalized() if a.length_squared() > 0.0 else Vector2.ZERO
		trem.append(pts[i] + nrm * (sway * sin(f1 * s + ph) + jit * rng.randf_range(-1.0, 1.0)))
	# échantillonnage : trait posé (pas fixe) ou geste brut (vitesse du pouce variable)
	var out := PackedVector3Array()
	if laid:
		for p: Vector2 in _resample2(trem, LAID_STEP):
			out.append(Vector3(p.x, 0.0, p.y))
		return out
	# un grand geste est tracé plus vite : l'écart entre deux points du doigt grandit avec le geste (0,2 à 0,6 m)
	var base := rng.randf_range(0.12, 0.35)
	var cap := clampf(_len2(trem) / 15.0, 0.2, 0.6)
	var f2 := rng.randf_range(0.3, 1.0)
	var ph2 := rng.randf_range(0.0, TAU)
	var total := _len2(trem)
	var target := 0.0
	var i := 1
	var acc := 0.0
	while target <= total + 0.0001:
		while i < trem.size() - 1 and acc + trem[i].distance_to(trem[i - 1]) < target:
			acc += trem[i].distance_to(trem[i - 1])
			i += 1
		var sl := trem[i].distance_to(trem[i - 1])
		var t := clampf((target - acc) / maxf(sl, 0.0001), 0.0, 1.0)
		var p := trem[i - 1].lerp(trem[i], t)
		out.append(Vector3(p.x, 0.0, p.y))
		target += clampf(base * (1.0 + 0.7 * sin(f2 * target + ph2)) * rng.randf_range(0.6, 1.4), 0.05, cap)
	var e := trem[trem.size() - 1]
	if out.is_empty() or out[out.size() - 1].distance_to(Vector3(e.x, 0.0, e.y)) > 0.05:
		out.append(Vector3(e.x, 0.0, e.y))
	return out


## Amorce depuis le héros : trait droit de 0,5 à 4 m posé (pas 0,18) jusqu'au premier point du geste.
static func _add_lead(rng: RandomNumberGenerator, s: Dictionary) -> void:
	var pts: PackedVector3Array = s["pts"]
	var first := pts[0]
	var a := rng.randf_range(0.0, TAU)
	var hero := first + Vector3(cos(a), 0.0, sin(a)) * rng.randf_range(0.5, 4.0)
	var lead := PackedVector3Array()
	var d := hero.distance_to(first)
	var n := int(d / LAID_STEP)
	for i in n + 1:
		lead.append(hero.lerp(first, float(i) / float(maxi(n, 1))))
	var nl := lead.size() - 1
	lead.append_array(pts.slice(1))
	s["pts"] = lead
	s["lead"] = nl
	s["name"] = String(s["name"]) + " + amorce %.1f" % d


static func _smooth(p: PackedVector2Array, w: int) -> PackedVector2Array:
	if w < 1:
		return p
	var out := PackedVector2Array()
	for i in p.size():
		var acc := Vector2.ZERO
		var n := 0
		for j in range(maxi(0, i - w), mini(p.size() - 1, i + w) + 1):
			acc += p[j]
			n += 1
		out.append(acc / float(n))
	return out


static func _seg_dist2(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.000001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _len2(p: PackedVector2Array) -> float:
	var t := 0.0
	for i in range(1, p.size()):
		t += p[i].distance_to(p[i - 1])
	return t


static func _resample2(p: PackedVector2Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if p.size() < 2:
		return p.duplicate()
	var total := _len2(p)
	var n := maxi(2, int(ceil(total / step)) + 1)
	var i := 1
	var acc := 0.0
	for k in n:
		var target := total * float(k) / float(n - 1)
		while i < p.size() - 1 and acc + p[i].distance_to(p[i - 1]) < target:
			acc += p[i].distance_to(p[i - 1])
			i += 1
		var sl := p[i].distance_to(p[i - 1])
		var t := clampf((target - acc) / maxf(sl, 0.0001), 0.0, 1.0)
		out.append(p[i - 1].lerp(p[i], t))
	return out


## Trait privé de ses `d` derniers mètres (lecture en direct avant le relâchement).
static func _cut_end(p: PackedVector3Array, d: float) -> PackedVector3Array:
	var out := p.duplicate()
	var left := d
	while out.size() >= 2 and left > 0.0:
		var sl := out[out.size() - 1].distance_to(out[out.size() - 2])
		if sl <= left:
			left -= sl
			out.resize(out.size() - 1)
		else:
			out[out.size() - 1] = out[out.size() - 1].lerp(out[out.size() - 2], left / sl)
			left = 0.0
	return out
