extends SceneTree
## Corpus de gestes réalistes pour la reconnaissance des figures (scripts/stroke_shapes.gd).
## Chaque figure est générée procéduralement comme un pouce sur téléphone : tailles (petit / moyen / grand,
## en mètres au sol : 1 cm d'écran vaut 1,4 m en bas de l'arène, 1,9 m au centre, 2,4 m en haut — un geste
## de pouce fait 1 à 4 cm), tremblement, vitesse variable (points espacés de 0,05 à 0,6 m), rotation
## quelconque, légère anisotropie (perspective), amorce depuis le héros (lead), dépassement en fin de geste,
## coins arrondis ; plus des contre-exemples qui ne doivent donner aucune figure.
## Les figures de l'arbre (vague, pointe, triangle) ont leur propre tirage (graine SEED + 1, après les six
## premières : les gestes des six premières restent les mêmes), avec leurs quasi-confusions (S plat, V large,
## V inégal = crochet, triangle sans son 3e côté = pointe, grand Λ = pointe). Puis les traits de combat naturels (aucune
## figure ; graine SEED + 2). run() joue le corpus avec les figures `lock` verrouillées (main._figtest : aucune, puis
## toutes celles de l'arbre) : un geste qui a la forme d'une figure verrouillée ne doit être aucune figure.
## Lancement : `godot --headless --path . -- --figtest` (main._figtest) ou `--script tools/fig_corpus.gd`.
## Imprime la matrice de confusion (attendu × détecté), le taux par figure, les ratés, la stabilité de la
## lecture en direct (trait sans ses 30 derniers centimètres), et la réussite des figures du robot.

const StrokeShapes = preload("res://scripts/stroke_shapes.gd")
const BotShapes = preload("res://scripts/bot_shapes.gd")

const FIGS := ["enso", "loop", "return", "zigzag", "straight", "hook", "wave", "point", "triangle"]
const COLS := ["enso", "loop", "return", "zigzag", "straight", "hook", "wave", "point", "triangle", ""]
const BASE := ["enso", "loop", "return", "zigzag", "straight", "hook"]
const TREE := ["wave", "point", "triangle"]  # figures de l'arbre (StrokeShapes.LEARNED)
const PER_FIG := 36       # variantes par figure (3 tailles × 12)
const SEED := 20261010
const LAID_STEP := 0.18   # pas du trait posé (ink_stroke.gd STEP)
const PROBE := 0.3        # la lecture en direct se fait tous les 30 cm (main._touch_move)
const NAT_KINDS := ["comma", "ell", "split", "bowcomma", "hesitant", "reach"]  # traits de combat naturels (_natural)
const NAT_PER := 24       # variantes par sorte (aucune figure attendue)
const NAT_GRAY := 12      # variantes de la zone grise par sorte (virgule, L, deux segments)


# ---------------------------------------------------------------- lancement

func _init() -> void:
	run(true)
	quit()


## Joue tout le corpus (graine `seed` : une autre graine, d'autres gestes) ;
## renvoie {"ok": int, "n": int, "rate": {fig: float}, "fails": Array, "unstable": Array, "bot_ok": bool}.
## `lock` : figures de l'arbre verrouillées pendant la partie (StrokeShapes.locked) ; un geste qui a leur forme
## doit alors n'être AUCUNE figure (pas de repli sur une autre : un V de pointe verrouillée n'est pas un crochet).
static func run(verbose: bool, seed: int = SEED, lock: Array = []) -> Dictionary:
	var was_locked: Array = StrokeShapes.locked
	StrokeShapes.locked = lock.duplicate()
	var tagl := "" if lock.is_empty() else "[verrouillées : %s] " % ", ".join(PackedStringArray(lock))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var samples := build(rng)
	var n_scored := 0
	for s: Dictionary in samples:
		if not bool(s.get("gray", false)):
			n_scored += 1
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
	var grp := {"base": [0, 0], "tree": [0, 0], "nat": [0, 0]}  # [justes, total] : six premières figures (et leurs contre-exemples), figures de l'arbre, traits naturels
	var nat := {}  # traits de combat naturels : figure lue -> nombre
	var gray := {}  # zone grise
	for s: Dictionary in samples:
		var pts: PackedVector3Array = s["pts"]
		var want := want_of(s, lock)
		var got := _shape(_detect(s, pts))
		if bool(s.get("gray", false)):
			gray[got] = int(gray.get(got, 0)) + 1
			continue
		if bool(s.get("nat", false)):
			nat[got] = int(nat.get(got, 0)) + 1
		if got != want and got == String(s.get("alt", "-")):
			want = got
		mat[want][got] = int(mat[want][got]) + 1
		var g: Array = grp["nat" if bool(s.get("nat", false)) else ("tree" if bool(s.get("tree", false)) else "base")]
		g[1] = int(g[1]) + 1
		if got == want:
			g[0] = int(g[0]) + 1
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
	var bot := _bot_check(lock)
	if verbose:
		print("FIGTEST %scorpus : %d échantillons, %d justes (%.1f %%)" % [tagl, n_scored, ok, 100.0 * float(ok) / float(maxi(n_scored, 1))])
		print("FIGTEST groupes : six premières figures (et contre-exemples) %d/%d ; figures de l'arbre (vague, pointe, triangle, quasi-confusions) : %d/%d ; traits de combat naturels (aucune figure) : %d/%d" % [int(grp["base"][0]), int(grp["base"][1]), int(grp["tree"][0]), int(grp["tree"][1]), int(grp["nat"][0]), int(grp["nat"][1])])
		var nl := ""
		for k in nat.keys():
			nl += " %s %d" % [String(k) if String(k) != "" else "(rien)", int(nat[k])]
		print("FIGTEST traits naturels lus comme :%s" % nl)
		var gl := ""
		for k in gray.keys():
			gl += " %s %d" % [String(k) if String(k) != "" else "(rien)", int(gray[k])]
		print("FIGTEST zone grise (L, virgules, deux segments à 106-120°, non comptés) lus comme :%s" % gl)
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
			print("FIGTEST robot %-9s : %d/%d orientations %s" % [String(k), int(r[0]), int(r[1]), "sans figure (verrouillée)" if String(k) in lock else "reconnues"])
	var bot_ok := true
	for k in bot.keys():
		if int(bot[k][0]) != int(bot[k][1]):
			bot_ok = false
	StrokeShapes.locked = was_locked
	return {"ok": ok, "n": n_scored, "rate": rate, "fails": fails, "unstable": unstable, "bot_ok": bot_ok, "nat": nat}


## Figure attendue d'un échantillon quand les figures `lock` sont verrouillées : leur forme ne donne rien.
static func want_of(s: Dictionary, lock: Array) -> String:
	var w := String(s["want"])
	return "" if w in lock else w


static func _detect(s: Dictionary, pts: PackedVector3Array) -> Dictionary:
	var lead := int(s.get("lead", -1))
	if lead >= 0:
		return StrokeShapes.detect_lead(pts, lead)
	return StrokeShapes.detect(pts)


static func _shape(r: Dictionary) -> String:
	return String(r.get("shape", ""))


## Les figures du robot (bot_shapes.gd) : 8 directions × 2 côtés, sans bords ; toutes doivent être reconnues (une
## figure verrouillée, `lock`, ne doit rien donner).
static func _bot_check(lock: Array = []) -> Dictionary:
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
				if _shape(StrokeShapes.detect(pts)) == ("" if shape in lock else shape):  # verrouillée : aucune figure
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
	# figures de l'arbre : tirage à part, les gestes des six premières ne bougent pas
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = rng.seed + 1
	for k in PER_FIG:
		var size := k % 3
		for fig: String in TREE:
			out.append(_tree_sample(rng2, fig, size, k))
	for kind: String in ["flatS", "wideV", "lopV", "openT", "lambda", "lambda"]:
		for k in 6:
			out.append(_tree_counter(rng2, kind, k))
	# traits de combat naturels (aucune figure) : tirage à part (graine SEED + 2), les gestes précédents ne bougent pas
	var rng3 := RandomNumberGenerator.new()
	rng3.seed = rng.seed + 2
	for kind: String in NAT_KINDS:
		for k in NAT_PER:
			out.append(_natural(rng3, kind, k, false))
	# zone grise (virage de 106 à 120°, angle intérieur 60 à 74° : la frontière avec un crochet franc à 125°) :
	# mesurée et imprimée, pas comptée comme une erreur
	for kind: String in ["comma", "ell", "split"]:
		for k in NAT_GRAY:
			out.append(_natural(rng3, kind, k, true))
	return out


## Traits de combat naturels (aucune figure) : ce que trace un pouce qui va chercher un ou deux ennemis sans
## vouloir de figure ; le crochet, la plus facile des figures, ne doit pas les capter. Trait droit dont le doigt
## dérape en levant (virgule de 10 à 25 % du trait jusqu'à 105°, minuscule jusqu'à 150°, arrondie ou cassée), L
## large (un ennemi puis un autre, virage de 55 à 105°), deux segments 70/30 ou 60/40, trait un peu courbe terminé
## par une virgule, départ hésitant (petit crochet ou tremblé au départ), trait qui s'infléchit en arc vers un
## second ennemi. 3,5 à 12 m, toutes orientations. Un trait droit qui dérape (virgule, départ hésitant) peut rester
## lu comme le trait droit voulu (`alt`) ; aucune autre figure. `gray` : virage de 106 à 120°, entre le L et le
## crochet franc (125° et plus) : la lecture y est mesurée, pas exigée.
static func _natural(rng: RandomNumberGenerator, kind: String, k: int, gray: bool) -> Dictionary:
	var g := PackedVector2Array()
	var tag := kind
	var total := rng.randf_range(3.5, 12.0)
	var sgn := 1.0 if rng.randf() < 0.5 else -1.0
	var round_m := rng.randf_range(0.0, 0.25)
	match kind:
		"comma":
			# au-delà de 120°, la virgule reste minuscule (8 à 15 % du trait)
			var frac := rng.randf_range(0.1, 0.25)
			var ang := rng.randf_range(106.0, 120.0) if gray else rng.randf_range(45.0, 105.0)
			if k % 4 == 3 and not gray:
				frac = rng.randf_range(0.08, 0.15)
				ang = rng.randf_range(105.0, 150.0)
			g = _bowed(total * (1.0 - frac), rng.randf_range(0.0, 0.25))
			g = _tail_arc(g, total * frac, ang * sgn) if k % 2 == 0 else _tail_seg(g, total * frac, ang * sgn)
			tag = "virgule %d %% à %d°" % [int(frac * 100.0), int(ang)]
		"ell":
			var frac := rng.randf_range(0.2, 0.5)
			var ang := rng.randf_range(106.0, 120.0) if gray else rng.randf_range(55.0, 105.0)
			g = _tail_seg(_bowed(total * (1.0 - frac), rng.randf_range(0.0, 0.2)), total * frac, ang * sgn)
			round_m = rng.randf_range(0.0, 0.12) * total
			tag = "L %d/%d à %d°" % [100 - int(frac * 100.0), int(frac * 100.0), int(ang)]
		"split":
			var frac := (0.3 if k % 2 == 0 else 0.4) + rng.randf_range(-0.03, 0.03)
			var ang := rng.randf_range(106.0, 120.0) if gray else rng.randf_range(60.0, 105.0)
			g = _tail_seg(_bowed(total * (1.0 - frac), rng.randf_range(0.0, 0.2)), total * frac, ang * sgn)
			tag = "deux segments %d/%d à %d°" % [100 - int(frac * 100.0), int(frac * 100.0), int(ang)]
		"bowcomma":
			var frac := rng.randf_range(0.1, 0.22)
			var bend := rng.randf_range(15.0, 35.0)
			var r := total * (1.0 - frac) / deg_to_rad(bend)
			g = _arc(Vector2(0.0, r), r, -PI / 2.0, -PI / 2.0 + deg_to_rad(bend))
			var ang := rng.randf_range(50.0, 100.0) * (1.0 if rng.randf() < 0.5 else -1.0)
			g = _tail_arc(g, total * frac, ang) if k % 2 == 0 else _tail_seg(g, total * frac, ang)
			tag = "courbe %d° virgule %d %% à %d°" % [int(bend), int(frac * 100.0), int(absf(ang))]
		"hesitant":
			var h := rng.randf_range(0.3, 1.0)
			var a0 := deg_to_rad(rng.randf_range(100.0, 170.0)) * sgn
			g = PackedVector2Array([Vector2.from_angle(a0) * h, Vector2.ZERO])
			if k % 3 == 1:
				g = PackedVector2Array([Vector2(-0.2, h * 0.6), Vector2.from_angle(a0) * h, Vector2.ZERO])
			g.append_array(_bowed(total, rng.randf_range(0.0, 0.25)).slice(1))
			if k % 3 == 2:
				g = _tail_seg(g, total * rng.randf_range(0.1, 0.2), rng.randf_range(50.0, 110.0) * -sgn)
			tag = "départ hésitant %.1f m" % h
		"reach":
			var frac := rng.randf_range(0.25, 0.4)
			var ang := rng.randf_range(60.0, 110.0)
			g = _tail_arc(_bowed(total * (1.0 - frac), rng.randf_range(0.0, 0.2)), total * frac, ang * sgn)
			tag = "inflexion %d %% sur %d°" % [int(frac * 100.0), int(ang)]
	var laid := k % 2 == 0
	var pts := _finish(rng, g, round_m, 0.0, laid)
	var s := {"name": "trait naturel%s #%d (%s, %.1f m%s)" % [" (zone grise)" if gray else "", k, tag, total, ", posé" if laid else ", brut"], "pts": pts, "want": "", "lead": -1, "nat": true, "gray": gray}
	if kind in ["comma", "bowcomma", "hesitant"]:
		s["alt"] = "straight"  # un trait droit qui dérape un peu reste le trait droit que le joueur a voulu
	if k % 3 == 1:
		_add_lead(rng, s)
	return s


## Prolonge g d'un segment de longueur l qui part du bout en tournant de `ang` degrés (signés).
static func _tail_seg(g: PackedVector2Array, l: float, ang: float) -> PackedVector2Array:
	var out := g.duplicate()
	var e := g[g.size() - 1]
	out.append(e + (e - g[g.size() - 2]).normalized().rotated(deg_to_rad(ang)) * l)
	return out


## Prolonge g d'un arc tangent de longueur l qui tourne de `ang` degrés (signés) : une virgule arrondie.
static func _tail_arc(g: PackedVector2Array, l: float, ang: float) -> PackedVector2Array:
	var out := g.duplicate()
	var e := g[g.size() - 1]
	var d := (e - g[g.size() - 2]).normalized()
	var th := deg_to_rad(absf(ang))
	var sg := signf(ang)
	var c := e + Vector2(-d.y, d.x) * (l / maxf(th, 0.01)) * sg
	var a0 := (e - c).angle()
	out.append_array(_arc(c, l / maxf(th, 0.01), a0, a0 + th * sg).slice(1))
	return out


## Figures de l'arbre : vague (S de deux arcs opposés, rayons et tours inégaux, petites amorces), pointe (V aigu
## aux branches proches, pointe arrondie), triangle (angles quelconques entre 35 et 105°, départ sur un sommet,
## au milieu d'un côté, ou dépassé ; fermeture imprécise ; coins arrondis).
static func _tree_sample(rng: RandomNumberGenerator, fig: String, size: int, k: int) -> Dictionary:
	var g := PackedVector2Array()
	var tag := ""
	var round_m := 0.0
	match fig:
		"wave":
			var r := _pick(rng, size, [0.75, 1.1], [1.1, 1.7], [1.7, 2.6])
			var r2 := r * rng.randf_range(0.75, 1.3)
			var t1 := rng.randf_range(135.0, 200.0)
			var t2 := rng.randf_range(135.0, 200.0)
			var tin := rng.randf_range(0.0, 0.5) * r if k % 4 == 3 else 0.0
			var tout := rng.randf_range(0.0, 0.5) * r if k % 4 == 2 else 0.0
			g = _s_curve(r, r2, t1, t2, tin, tout)
			tag = "r%.1f/%.1f %d°/%d°" % [r, r2, int(t1), int(t2)]
		"point":
			var b := _pick(rng, size, [1.5, 2.2], [2.2, 3.4], [3.4, 5.0])
			var b2 := b * rng.randf_range(0.8, 1.0)
			if rng.randf() < 0.5:
				var tmp := b
				b = b2
				b2 = tmp
			var ang := rng.randf_range(22.0, 56.0)  # angle intérieur de la pointe (la perspective en ajoute jusqu'à 10°)
			var d2 := Vector2.from_angle(deg_to_rad(ang))
			g = PackedVector2Array([Vector2(b, 0), Vector2.ZERO, d2 * b2])
			round_m = rng.randf_range(0.0, 0.12) * minf(b, b2)
			tag = "%.1f/%.1f à %d°" % [b, b2, int(ang)]
		"triangle":
			var side := _pick(rng, size, [1.6, 2.4], [2.4, 3.6], [3.6, 5.5])
			var a1 := rng.randf_range(35.0, 105.0)
			var a2 := rng.randf_range(maxf(35.0, 75.0 - a1), minf(105.0, 145.0 - a1))
			var tri := _tri(side, a1, a2)
			var mode := k % 3  # 0 : départ sur un sommet ; 1 : au milieu d'un côté ; 2 : sommet, trait qui dépasse
			var pts := PackedVector2Array()
			if mode == 1:
				var m := tri[0].lerp(tri[1], rng.randf_range(0.3, 0.7))
				pts = PackedVector2Array([m, tri[1], tri[2], tri[0], m])
			else:
				pts = PackedVector2Array([tri[0], tri[1], tri[2], tri[0]])
				if mode == 2:
					pts.append(tri[0].lerp(tri[1], rng.randf_range(0.08, 0.25)))
			# fermeture imprécise : l'arrivée s'arrête court ou à côté du départ (jusqu'à 18 % d'un côté)
			var e := pts[pts.size() - 1]
			var miss := Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(0.0, 0.18) * side
			pts[pts.size() - 1] = e + miss
			g = pts
			round_m = rng.randf_range(0.0, 0.12) * side
			tag = "côté %.1f angles %d/%d/%d %s" % [side, int(a1), int(a2), int(180.0 - a1 - a2), ["sommet", "milieu", "dépassé"][mode]]
	var laid := k % 2 == 0
	var pts3 := _finish(rng, g, round_m, 0.0, laid)
	var name := "%s %s #%d (%s%s)" % [fig, ["petit", "moyen", "grand"][size], k, tag, ", posé" if laid else ", brut"]
	var s := {"name": name, "pts": pts3, "want": fig, "lead": -1, "tree": true}
	if k % 3 == 1:
		_add_lead(rng, s)
	return s


## Quasi-confusions des figures de l'arbre : S plat (deux arcs de 45 à 85°, rien), V large (82 à 100°, rien),
## V inégal (barbe courte : un crochet), triangle sans son troisième côté (deux côtés : un V, une pointe, jamais
## un triangle).
static func _tree_counter(rng: RandomNumberGenerator, kind: String, k: int) -> Dictionary:
	var g := PackedVector2Array()
	var tag := kind
	var want := ""
	match kind:
		"flatS":
			var r := rng.randf_range(1.2, 2.6)
			var t1 := rng.randf_range(45.0, 85.0)
			var t2 := rng.randf_range(45.0, 85.0)
			g = _s_curve(r, r * rng.randf_range(0.8, 1.2), t1, t2, 0.0, 0.0)
			tag = "S plat r%.1f %d°/%d°" % [r, int(t1), int(t2)]
		"wideV":
			var b := rng.randf_range(2.0, 4.0)
			var ang := rng.randf_range(82.0, 100.0)
			g = PackedVector2Array([Vector2(b, 0), Vector2.ZERO, Vector2.from_angle(deg_to_rad(ang)) * b * rng.randf_range(0.85, 1.0)])
			tag = "V large %d°" % int(ang)
		"lopV":
			var main := rng.randf_range(3.0, 5.0)
			var last := main * rng.randf_range(0.3, 0.55)
			var ang := rng.randf_range(25.0, 55.0)
			g = PackedVector2Array([Vector2(main, 0), Vector2.ZERO, Vector2.from_angle(deg_to_rad(ang)) * last])
			tag = "V inégal %.1f/%.1f à %d°" % [main, last, int(ang)]
			want = "hook"
		"lambda":
			# cas réel (monde 1) : un grand Λ tracé pour toucher deux ennemis, branches presque égales, 38 à 58° au
			# sommet, 2,5 à 7 m par branche : une pointe (rien si elle n'est pas apprise), jamais un crochet
			var b := rng.randf_range(2.5, 7.0)
			var ang := rng.randf_range(38.0, 58.0)
			g = PackedVector2Array([Vector2(b, 0), Vector2.ZERO, Vector2.from_angle(deg_to_rad(ang)) * b * rng.randf_range(0.82, 1.15)])
			tag = "Λ %.1f m à %d°" % [b, int(ang)]
			want = "point"
		"openT":
			var side := rng.randf_range(2.5, 4.5)
			var tri := _tri(side, 65.0, 50.0)
			g = PackedVector2Array([tri[0], tri[1], tri[2]])
			tag = "triangle sans 3e côté %.1f" % side
			want = "point"  # deux côtés égaux à 50° : un V
	var pts := _finish(rng, g, rng.randf_range(0.0, 0.15), 0.0, k % 2 == 0)
	var s := {"name": "quasi-confusion #%d (%s)" % [k, tag], "pts": pts, "want": want, "lead": -1, "tree": true}
	if kind == "lambda" and k % 2 == 1:
		_add_lead(rng, s)  # le doigt touche loin du héros : amorce
	return s


## S : arc de rayon r sur t1 degrés, puis arc de l'autre sens de rayon r2 sur t2 degrés, tangents ; amorces
## droites tin (avant) et tout (après).
static func _s_curve(r: float, r2: float, t1: float, t2: float, tin: float, tout: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if tin > 0.0:
		out.append(Vector2(-tin, 0.0))
	# départ en (0,0) vers +x, tourne à gauche : centre (0, r)
	var a := _arc(Vector2(0.0, r), r, -PI / 2.0, -PI / 2.0 + deg_to_rad(t1))
	out.append_array(a)
	var e := a[a.size() - 1]
	var dir := (e - a[a.size() - 2]).normalized()
	var c2 := e + Vector2(dir.y, -dir.x) * r2  # centre à droite : tourne dans l'autre sens
	var a0 := (e - c2).angle()
	var b := _arc(c2, r2, a0, a0 - deg_to_rad(t2))
	out.append_array(b.slice(1))
	if tout > 0.0:
		var e2 := b[b.size() - 1]
		out.append(e2 + (e2 - b[b.size() - 2]).normalized() * tout)
	return out


## Sommets d'un triangle de base `side` (sur l'axe x) et d'angles a1, a2 (degrés) à ses deux bouts.
static func _tri(side: float, a1: float, a2: float) -> PackedVector2Array:
	var a3 := deg_to_rad(180.0 - a1 - a2)
	var l1 := side * sin(deg_to_rad(a2)) / maxf(sin(a3), 0.01)  # côté opposé à l'angle a2, partant du premier sommet
	var p2 := Vector2.from_angle(-deg_to_rad(a1)) * l1
	return PackedVector2Array([Vector2.ZERO, Vector2(side, 0.0), p2])


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
			# un S : deux arcs opposés : pas un zigzag, une vague (figure de l'arbre)
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
	return {"name": "contre-exemple #%d (%s)" % [k, tag], "pts": pts, "want": "wave" if kind == "S" else "", "lead": -1}


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
