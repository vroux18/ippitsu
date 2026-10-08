extends RefCounted
## Pièces de yōkai low-poly (masques, cornes, chapeaux, carapaces, queues, armes) : chaque genre d'ennemi
## garde le squelette KayKit animé mais prend sa propre silhouette. Un maillage fusionné par os (couleurs
## de sommets) et un seul matériau toon à contour d'encre pour tous : 1 à 4 instances par ennemi,
## maillages partagés par genre, aucun matériau par ennemi.
## Repères des os (unités du modèle KayKit, mises à l'échelle `u` = Character.scale_factor) :
##  head  — crâne centré en (0, 0.5, 0), rayon ≈ 0.44, face vers +Z, sommet y ≈ 0.93
##  chest — épaules y ≈ 0.15, demi-largeur ≈ 0.37, taille y ≈ -0.45 ; dos vers -Z
##  hips  — bassin ; sol à y ≈ -0.41
## Armes (handslot.*) et corps modelés (body, face vers -Z) : unités du monde.

const Toon = preload("res://scripts/toon.gd")

const HORN := Color("#EDE1C4")
const HAIR := Color("#1E1B22")
const IRON := Color("#3A3C42")
const WOOD_D := Color("#4A3A2C")
const LACQUER := Color("#2F2A36")
const LACE := Color("#B8352B")
const TIGER := Color("#E39B32")
const STRAW := Color("#C9A55A")
const STEEL := Color("#B4BAC2")
const TENGU_RED := Color("#C8423A")
const BEAK := Color("#E0A030")
const FOX_W := Color("#F6EFE2")
const FIRE := Color("#FF7A2A")

static var _sets := {}  # "genre|léger" -> {os: ArrayMesh}
static var _mat: StandardMaterial3D = null


## Matériau unique des pièces : toon, couleur des sommets, contour d'encre.
static func mat() -> StandardMaterial3D:
	if _mat == null:
		_mat = Toon.mat(Color.WHITE, true, 0.026)
		_mat.vertex_color_use_as_albedo = true
		_mat.vertex_color_is_srgb = true
	return _mat


## Sous-maillages KayKit à cacher (motifs de nom) : remplacés par les pièces.
static func hidden(kind: String) -> Array:
	match kind:
		"oni", "gaki", "moryo":
			return ["Cloak"]
		"brute", "tate", "teppo", "kanabo", "gokusotsu":
			return ["Helmet", "Cloak"]
		"kasha", "tanuki", "tanuki_d":
			return ["Helmet"]
		"kappa":
			return ["Hat"]
		"funa", "ika", "onryo", "yukionna", "ningyo":
			return ["Leg"]
		"umibozu":
			return ["Jaw", "Cloak"]
		"tengu", "kappa_yumi", "konoha":
			return ["Cape"]
	return []


## Pièces d'un genre : {nom d'os (ou "body", "wing_l", "wing_r") : maillage}. Bâties une fois par genre.
static func parts(kind: String, u: float) -> Dictionary:
	var lite := Toon.lite
	var key := "%s|%d" % [kind, 1 if lite else 0]
	if _sets.has(key):
		var cached: Dictionary = _sets[key]
		return cached
	var d := {}
	match kind:
		"oni":
			_oni(d, u, lite)
		"brute":
			_brute(d, u, lite)
		"kappa":
			_kappa(d, u, lite)
		"tate":
			_tate(d, u, lite)
		"funa":
			_funa(d, u, lite)
		"umibozu":
			_umibozu(d, u, lite)
		"kitsunebi", "kitsunebi_s":
			_kitsunebi(d, u, lite, kind == "kitsunebi_s")
		"yukionna":
			_yukionna(d, u, lite)
		"kasha":
			_kasha(d, u, lite)
		"kappa_yumi":
			_kappa_yumi(d, u, lite)
		"teppo":
			_teppo(d, u, lite)
		"ika":
			_ika(d, u, lite)
		"umi_nyobo":
			_umi_nyobo(d, u, lite)
		"moryo":
			_moryo(d, u, lite)
		"kamaitachi":
			_kamaitachi(d, u, lite)
		"tanuki", "tanuki_d":
			_tanuki(d, u, lite, kind == "tanuki_d")
		"kitsune_tsukai":
			_tsukai(d, u, lite)
		"yuki_warashi":
			_warashi(d, u, lite)
		"kanabo":
			_kanabo(d, u, lite)
		"tengu":
			_tengu(d, u, lite)
		"onryo":
			_onryo(d, u, lite)
		"yamabushi":
			_yamabushi(d, u, lite)
		"konoha":
			_konoha(d, u, lite)
		"ningyo":
			_ningyo(d, u, lite)
		"gaki":
			_gaki(d, u, lite)
		"gokusotsu":
			_gokusotsu(d, u, lite)
		"tsurara":
			_tsurara(d, lite)
		"sumidama", "sumidama_s":
			_sumidama(d, lite, 0.6 if kind == "sumidama_s" else 1.0)
		"kasa":
			_kasa(d, lite)
		"karasu":
			_karasu(d, lite)
		"kani":
			_kani(d, lite)
		"fugu":
			_fugu(d, lite)
	# un os sans pièce (mode léger) n'a pas d'entrée
	for k in d.keys():
		if d[k] == null:
			d.erase(k)
	_sets[key] = d
	return d


# ------------------------------------------------------------------ briques communes

## Paire de cornes courbes (deux segments) ; `x` : écart au centre, `tilt` : penchées vers l'extérieur.
static func _horns(m: Mesher, x: float, y: float, r: float, ln: float, col: Color, tilt: float) -> void:
	for s in [-1.0, 1.0]:
		var sx := float(s)
		var tip := m.spike(Vector3(sx * x, y, 0.06), r, ln * 0.6, col, Vector3(-0.15, 0, -sx * tilt), 0.6)
		m.spike(tip, r * 0.6, ln * 0.5, col, Vector3(-0.35, 0, -sx * tilt * 0.3))


## Sourcils froncés (oni, tengu).
static func _brows(m: Mesher, col: Color) -> void:
	for s in [-1.0, 1.0]:
		var sx := float(s)
		m.box(Vector3(sx * 0.15, 0.57, 0.42), Vector3(0.22, 0.07, 0.08), col, Vector3(0, 0, sx * 0.35))


## Crocs qui sortent de la mâchoire.
static func _tusks(m: Mesher, r: float) -> void:
	for s in [-1.0, 1.0]:
		var sx := float(s)
		m.spike(Vector3(sx * 0.13, 0.16, 0.3), r, r * 4.2, HORN, Vector3(0.25, 0, sx * 0.15))


## Calotte de cheveux (ou de fourrure) sur le haut du crâne, la face reste visible.
static func _cap(m: Mesher, col: Color, back := 0.06) -> void:
	m.ball(Vector3(0, 0.72, -back), Vector3(0.47, 0.32, 0.48), col)


## Longue chevelure : calotte, nappe dans le dos, mèches de côté ; `veil` : rideau devant la face.
static func _long_hair(m: Mesher, col: Color, ln: float, veil: bool) -> void:
	_cap(m, col, 0.08)
	m.box(Vector3(0, 0.62 - ln * 0.5, -0.38), Vector3(0.72, ln, 0.1), col, Vector3(0.12, 0, 0))
	for s in [-1.0, 1.0]:
		var sx := float(s)
		m.box(Vector3(sx * 0.41, 0.38, 0.12), Vector3(0.09, 0.5, 0.2), col, Vector3(0, 0, sx * 0.08))
	if veil:
		m.box(Vector3(0, 0.36, 0.47), Vector3(0.6, 0.66, 0.07), col, Vector3(-0.08, 0, 0))


## Triangle blanc des morts (tenkan) sur le front.
static func _tenkan(m: Mesher, y: float, z: float, tilt: float) -> void:
	m.box(Vector3(0, y, z), Vector3(0.14, 0.14, 0.02), Toon.WASHI, Vector3(-tilt, 0, PI / 4.0))


## Kimono croisé sur le torse (col en V), ceinture `obi` si couleur non transparente.
static func _kimono(m: Mesher, col: Color, collar: Color, obi: Color) -> void:
	m.cyl(Vector3(0, -0.16, 0), Vector3(0.41, 0.66, 0.38), col, Vector3.ZERO, 0.86, 8)
	for s in [-1.0, 1.0]:
		var sx := float(s)
		m.box(Vector3(sx * 0.08, 0.02, 0.37), Vector3(0.07, 0.42, 0.03), collar, Vector3(-0.12, 0, sx * 0.4))
	if obi.a > 0.0:
		m.cyl(Vector3(0, -0.36, 0), Vector3(0.42, 0.13, 0.39), obi, Vector3.ZERO, 1.0, 8)


## Bas de fantôme : pas de jambes, une volute qui s'effile vers l'arrière.
static func _wisp(m: Mesher, col: Color, lite: bool) -> void:
	m.cyl(Vector3(0, -0.14, 0), Vector3(0.36, 0.36, 0.34), col, Vector3(PI, 0, 0), 0.45, 8)
	var tip := m.spike(Vector3(0, -0.26, -0.04), 0.17, 0.26, col, Vector3(-2.0, 0, 0), 0.0, 6)
	if not lite:
		m.spike(tip, 0.06, 0.16, col, Vector3(-1.2, 0, 0), 0.0, 5)


## Pagne en peau de tigre (oni).
static func _tiger(m: Mesher, lite: bool) -> void:
	m.cyl(Vector3(0, 0.0, 0), Vector3(0.38, 0.22, 0.36), TIGER, Vector3.ZERO, 0.92, 8)
	m.box(Vector3(0, -0.2, 0.31), Vector3(0.28, 0.26, 0.05), TIGER, Vector3(-0.12, 0, 0))
	if lite:
		return
	for i in 5:
		var a := TAU * (float(i) + 0.5) / 5.0
		m.box(Vector3(sin(a) * 0.4, 0.0, cos(a) * 0.38), Vector3(0.05, 0.2, 0.03), Toon.SUMI, Vector3(0, a, 0.35))
	m.box(Vector3(0, -0.17, 0.34), Vector3(0.22, 0.035, 0.02), Toon.SUMI, Vector3(-0.12, 0, 0.2))


## Carapace de kappa dans le dos et plastron jaune devant.
static func _shell(m: Mesher, lite: bool) -> void:
	m.ball(Vector3(0, -0.05, -0.36), Vector3(0.45, 0.52, 0.12), Color("#C9B86A"))
	m.ball(Vector3(0, -0.04, -0.38), Vector3(0.41, 0.48, 0.22), Color("#4E6B3A"))
	m.ball(Vector3(0, -0.16, 0.27), Vector3(0.3, 0.38, 0.1), Color("#D8C878"))
	if lite:
		return
	for p in [Vector3(0, 0.08, -0.6), Vector3(-0.19, -0.16, -0.56), Vector3(0.19, -0.16, -0.56), Vector3(0, -0.36, -0.52)]:
		m.cyl(p, Vector3(0.11, 0.04, 0.11), Color("#3A5230"), Vector3(-PI / 2.0, 0, 0), 1.0, 6)


## Coupelle d'eau du kappa, cerclée de cheveux.
static func _dish(m: Mesher, y: float, lite: bool) -> void:
	m.cyl(Vector3(0, y - 0.07, 0), Vector3(0.38, 0.13, 0.38), Color("#2F4A2A"), Vector3.ZERO, 0.75, 10)
	m.cyl(Vector3(0, y, 0), Vector3(0.27, 0.05, 0.27), Color("#DDE8D0"), Vector3.ZERO, 1.0, 10)
	m.cyl(Vector3(0, y + 0.027, 0), Vector3(0.21, 0.01, 0.21), Color("#7FC4D8"), Vector3.ZERO, 1.0, 10)
	if lite:
		return
	for i in 5:
		var a := (float(i) - 2.0) * 0.42
		m.spike(Vector3(sin(a) * 0.34, y - 0.1, cos(a) * 0.34), 0.07, 0.2, Color("#2F4A2A"), Vector3(PI - 0.5, a, 0), 0.0, 4)


## Cornet de paille (kasa, jingasa) : large cône plat.
static func _hat(m: Mesher, y: float, r: float, h: float, col: Color, sides := 10) -> void:
	m.cyl(Vector3(0, y, 0), Vector3(r, h, r), col, Vector3.ZERO, 0.14, sides)


## Ailes de plumes dans le dos (tengu) : `n` pennes par côté, en éventail.
static func _wings(m: Mesher, col: Color, n: int, ln: float) -> void:
	for s in [-1.0, 1.0]:
		var sx := float(s)
		for i in n:
			var k := float(i) / maxf(float(n - 1), 1.0)
			var rot := Vector3(-0.35, 0, -sx * (0.5 + 0.8 * k))
			m.stick(Vector3(sx * 0.16, 0.12 - 0.08 * k, -0.33), Vector3(0.15, ln * (1.0 - 0.35 * k), 0.03), col, rot)


## Queue touffue (renard, tanuki, belette) : fuseau + bout clair.
static func _tail(m: Mesher, base: Vector3, rot: Vector3, ln: float, r: float, col: Color, tip: Color) -> void:
	var dir := Basis.from_euler(rot) * Vector3.UP
	m.ball(base + dir * ln * 0.5, Vector3(r, ln * 0.55, r), col, rot)
	m.ball(base + dir * ln * 0.95, Vector3(r * 0.75, ln * 0.22, r * 0.75), tip, rot)


# ------------------------------------------------------------------ genres

## Oni : peau rouge, cornes, tignasse hérissée, crocs ; pagne de tigre, massue de bois.
static func _oni(d: Dictionary, u: float, lite: bool) -> void:
	var h := Mesher.new(u)
	_horns(h, 0.2, 0.8, 0.085, 0.36, HORN, 0.35)
	h.ball(Vector3(0, 0.76, -0.12), Vector3(0.38, 0.22, 0.33), HAIR)
	if not lite:
		for i in 3:
			var a := (float(i) - 1.0) * 0.55
			h.spike(Vector3(a * 0.35, 0.8, -0.26), 0.1, 0.3, HAIR, Vector3(-1.2, 0, -a), 0.0, 5)
	_brows(h, HAIR)
	_tusks(h, 0.035)
	d["head"] = h.mesh()
	var p := Mesher.new(u)
	_tiger(p, lite)
	d["hips"] = p.mesh()
	d["handslot.r"] = _w_club_wood()


## Musha : spectre de général en ō-yoroi — kabuto à cornes d'or (kuwagata), menpō, grandes épaulières.
static func _brute(d: Dictionary, u: float, lite: bool) -> void:
	var h := Mesher.new(u)
	h.ball(Vector3(0, 0.74, -0.02), Vector3(0.47, 0.3, 0.48), IRON)
	h.box(Vector3(0, 0.42, -0.42), Vector3(0.82, 0.26, 0.06), LACQUER, Vector3(0.35, 0, 0))
	for s in [-1.0, 1.0]:
		var sx := float(s)
		h.box(Vector3(sx * 0.45, 0.42, -0.08), Vector3(0.06, 0.26, 0.6), LACQUER, Vector3(0, 0, sx * 0.35))
		h.box(Vector3(sx * 0.42, 0.62, 0.3), Vector3(0.05, 0.2, 0.2), Toon.GOLD, Vector3(0, -sx * 0.5, 0))
		h.stick(Vector3(sx * 0.07, 0.8, 0.4), Vector3(0.07, 0.62, 0.025), Toon.GOLD, Vector3(-0.15, 0, -sx * 0.42))
	h.cyl(Vector3(0, 0.8, 0.45), Vector3(0.09, 0.03, 0.09), Toon.GOLD, Vector3(PI / 2.0, 0, 0), 1.0, 8)
	# menpō : masque de fer rouge, moustache blanche
	h.box(Vector3(0, 0.18, 0.36), Vector3(0.46, 0.2, 0.14), Color("#7E2A22"))
	if not lite:
		for s in [-1.0, 1.0]:
			h.box(Vector3(float(s) * 0.08, 0.25, 0.44), Vector3(0.14, 0.035, 0.03), Toon.WASHI, Vector3(0, 0, float(s) * -0.3))
	d["head"] = h.mesh()
	var c := Mesher.new(u)
	c.box(Vector3(0, -0.12, 0.34), Vector3(0.62, 0.5, 0.08), LACQUER)
	for i in 3:
		c.box(Vector3(0, -0.28 + 0.15 * float(i), 0.385), Vector3(0.6, 0.03, 0.012), LACE)
	for s in [-1.0, 1.0]:
		var sx := float(s)
		var rot := Vector3(0, 0, sx * 0.3)
		var b := Basis.from_euler(rot)
		var at := Vector3(sx * 0.52, 0.04, 0)
		c.box(at, Vector3(0.08, 0.48, 0.44), LACQUER, rot)
		if not lite:
			for j in 2:
				c.box(at + b * Vector3(sx * 0.045, -0.1 + 0.18 * float(j), 0), Vector3(0.012, 0.035, 0.42), LACE, rot)
	d["chest"] = c.mesh()
	d["handslot.r"] = _w_nodachi()


## Kappa : coupelle d'eau, bec, carapace et plastron ; bâton.
static func _kappa(d: Dictionary, u: float, lite: bool) -> void:
	var h := Mesher.new(u)
	_dish(h, 0.92, lite)
	h.spike(Vector3(0, 0.27, 0.36), 0.17, 0.24, BEAK, Vector3(PI / 2.0 + 0.15, 0, 0), 0.25, 4, 0.6)
	d["head"] = h.mesh()
	var c := Mesher.new(u)
	_shell(c, lite)
	d["chest"] = c.mesh()
	d["handslot.r"] = _w_staff()


## Kappa archer (capuche du rōdeur) : coupelle sur la capuche, bec, carapace.
static func _kappa_yumi(d: Dictionary, u: float, lite: bool) -> void:
	var h := Mesher.new(u)
	_dish(h, 1.0, lite)
	h.spike(Vector3(0, 0.3, 0.42), 0.16, 0.22, BEAK, Vector3(PI / 2.0 + 0.15, 0, 0), 0.25, 4, 0.6)
	d["head"] = h.mesh()
	var c := Mesher.new(u)
	_shell(c, lite)
	d["chest"] = c.mesh()


## Ashigaru au grand bouclier : haut casque penché (eboshi-kabuto), cuirasse lamellaire lacée.
static func _tate(d: Dictionary, u: float, lite: bool) -> void:
	var h := Mesher.new(u)
	h.ball(Vector3(0, 0.74, -0.02), Vector3(0.46, 0.28, 0.47), IRON)
	h.spike(Vector3(0, 0.88, -0.08), 0.3, 0.5, Color("#2A2D33"), Vector3(-0.45, 0, 0), 0.3, 8)
	h.cyl(Vector3(0, 0.56, -0.12), Vector3(0.54, 0.14, 0.5), Color("#6E2A22"), Vector3(0.1, 0, 0), 0.85, 8)
	d["head"] = h.mesh()
	var c := Mesher.new(u)
	c.cyl(Vector3(0, -0.15, 0), Vector3(0.41, 0.6, 0.38), Color("#4A3A2E"), Vector3.ZERO, 0.9, 8)
	for i in (2 if lite else 4):
		c.cyl(Vector3(0, -0.4 + 0.15 * float(i), 0), Vector3(0.42, 0.03, 0.39), LACE, Vector3.ZERO, 0.95, 8)
	for s in [-1.0, 1.0]:
		c.box(Vector3(float(s) * 0.46, 0.06, 0), Vector3(0.07, 0.34, 0.36), Color("#4A3A2E"), Vector3(0, 0, float(s) * 0.35))
	d["chest"] = c.mesh()
	d["handslot.l"] = _w_shield()
	d["handslot.r"] = _w_blade(0.8, Color("#8A8F96"))


## Arquebusier : jingasa de laque noire au mon doré, cuirasse et cartouchière ; arquebuse.
static func _teppo(d: Dictionary, u: float, lite: bool) -> void:
	var h := Mesher.new(u)
	_hat(h, 0.9, 0.7, 0.15, Color("#24232A"), 12)
	h.cyl(Vector3(0, 0.975, 0), Vector3(0.12, 0.02, 0.12), Toon.GOLD, Vector3.ZERO, 1.0, 8)
	if not lite:
		h.cyl(Vector3(0, 0.83, 0), Vector3(0.69, 0.025, 0.69), LACE, Vector3.ZERO, 1.0, 12)
	d["head"] = h.mesh()
	var c := Mesher.new(u)
	c.box(Vector3(0, -0.1, 0.33), Vector3(0.62, 0.52, 0.09), Color("#5A2A22"))
	c.box(Vector3(0, -0.05, 0.385), Vector3(0.1, 0.8, 0.03), Toon.WOOD, Vector3(0, 0, 0.75))
	if not lite:
		for i in 4:
			var t := (float(i) - 1.5) * 0.14
			c.box(Vector3(-t * 0.68, -0.05 + t * 0.73, 0.405), Vector3(0.06, 0.09, 0.04), IRON, Vector3(0, 0, 0.75))
	d["chest"] = c.mesh()
	d["handslot.r"] = _w_rifle()


## Oni à massue : ao-oni (peau bleue), grandes cornes, crinière blanche, plastron de fer ; kanabō.
static func _kanabo(d: Dictionary, u: float, lite: bool) -> void:
	var h := Mesher.new(u)
	h.ball(Vector3(0, 0.62, -0.22), Vector3(0.52, 0.44, 0.34), Color("#EDE6D8"))
	if not lite:
		for i in 5:
			var a := (float(i) - 2.0) * 0.5
			h.spike(Vector3(sin(a) * 0.38, 0.6, -0.3 + cos(a) * 0.05), 0.12, 0.34, Color("#EDE6D8"), Vector3(-1.4, 0, -a), 0.0, 5)
	_horns(h, 0.2, 0.8, 0.11, 0.5, Toon.GOLD, 0.25)
	_brows(h, Color("#EDE6D8"))
	_tusks(h, 0.045)
	d["head"] = h.mesh()
	var c := Mesher.new(u)
	c.box(Vector3(0, -0.06, 0.36), Vector3(0.7, 0.58, 0.1), Color("#4A4E58"))
	c.box(Vector3(0, 0.24, 0.35), Vector3(0.74, 0.08, 0.12), Color("#2E3038"))
	for s in [-1.0, 1.0]:
		var sx := float(s)
		c.ball(Vector3(sx * 0.24, 0.1, 0.42), Vector3(0.04, 0.04, 0.03), Toon.GOLD)
		c.ball(Vector3(sx * 0.24, -0.25, 0.42), Vector3(0.04, 0.04, 0.03), Toon.GOLD)
		c.spike(Vector3(sx * 0.4, 0.2, 0), 0.1, 0.24, Color("#4A4E58"), Vector3(0, 0, -sx * 0.9), 0.0, 5)
	d["chest"] = c.mesh()
	if not lite:
		var p := Mesher.new(u)
		_tiger(p, lite)
		d["hips"] = p.mesh()
	d["handslot.r"] = _w_kanabo()


## Gozu (geôlier des enfers à tête de bœuf) : mufle, cornes à l'horizontale, anneau d'or ; collier de fer.
static func _gokusotsu(d: Dictionary, u: float, lite: bool) -> void:
	var h := Mesher.new(u)
	var pelt := Color("#5A4232")
	h.ball(Vector3(0, 0.6, 0.0), Vector3(0.48, 0.44, 0.5), pelt)
	h.ball(Vector3(0, 0.32, 0.4), Vector3(0.3, 0.22, 0.24), Color("#B89270"))
	h.cyl(Vector3(0, 0.22, 0.63), Vector3(0.09, 0.025, 0.09), Toon.GOLD, Vector3(PI / 2.0, 0, 0), 0.8, 8)
	for s in [-1.0, 1.0]:
		var sx := float(s)
		h.ball(Vector3(sx * 0.18, 0.57, 0.46), Vector3(0.07, 0.05, 0.04), Color("#FFC83A"))
		h.ball(Vector3(sx * 0.09, 0.35, 0.62), Vector3(0.04, 0.04, 0.03), Toon.SUMI)
		var tip := h.spike(Vector3(sx * 0.36, 0.78, 0.02), 0.1, 0.42, HORN, Vector3(0, 0, -sx * 1.25), 0.65)
		h.spike(tip, 0.065, 0.32, HORN, Vector3(-0.2, 0, -sx * 0.2))
		h.box(Vector3(sx * 0.5, 0.58, -0.04), Vector3(0.2, 0.06, 0.12), pelt, Vector3(0, 0, -sx * 0.4))
	d["head"] = h.mesh()
	var c := Mesher.new(u)
	c.cyl(Vector3(0, 0.3, 0), Vector3(0.44, 0.13, 0.42), IRON, Vector3.ZERO, 0.78, 8)
	if not lite:
		for i in 4:
			var a := TAU * (float(i) + 0.5) / 4.0
			c.spike(Vector3(sin(a) * 0.4, 0.3, cos(a) * 0.38), 0.05, 0.14, IRON, Vector3(PI / 2.0 - 0.6, a, 0), 0.0, 4)
		for i in 6:
			c.ball(Vector3(-0.3 + 0.12 * float(i), 0.12 - 0.11 * float(i), 0.38), Vector3(0.045, 0.045, 0.03), IRON)
	d["chest"] = c.mesh()
	if not lite:
		var p := Mesher.new(u)
		p.cyl(Vector3(0, 0.0, 0), Vector3(0.38, 0.2, 0.36), Color("#5A2228"), Vector3.ZERO, 0.92, 8)
		p.box(Vector3(0, -0.2, 0.31), Vector3(0.3, 0.28, 0.05), Color("#5A2228"), Vector3(-0.12, 0, 0))
		d["hips"] = p.mesh()
	d["handslot.r"] = _w_chain()


## Kasha : chat de feu — capuche de fourrure, oreilles, moustaches, mèches de flamme ; deux queues (nekomata).
static func _kasha(d: Dictionary, u: float, lite: bool) -> void:
	var fur := Color("#2A2228")
	var h := Mesher.new(u)
	_cap(h, fur)
	h.ball(Vector3(0, 0.25, 0.38), Vector3(0.2, 0.12, 0.12), Toon.WASHI)
	h.ball(Vector3(0, 0.31, 0.49), Vector3(0.045, 0.035, 0.03), Color("#E07A8A"))
	for s in [-1.0, 1.0]:
		var sx := float(s)
		h.spike(Vector3(sx * 0.26, 0.84, 0.0), 0.16, 0.32, fur, Vector3(-0.1, 0, -sx * 0.35), 0.0, 4, 0.5)
		h.spike(Vector3(sx * 0.255, 0.86, 0.05), 0.09, 0.22, Toon.VERMILION, Vector3(-0.1, 0, -sx * 0.35), 0.0, 4, 0.4)
		for j in 2:
			h.box(Vector3(sx * 0.32, 0.23 + 0.05 * float(j), 0.42), Vector3(0.32, 0.014, 0.014), Toon.SUMI, Vector3(0, 0, sx * (0.15 - 0.3 * float(j))))
	if not lite:
		for i in 3:
			var a := (float(i) - 1.0) * 0.5
			var tip := h.spike(Vector3(a * 0.3, 0.78, -0.3), 0.1, 0.32, FIRE, Vector3(-1.0, 0, -a), 0.3, 5)
			h.spike(tip, 0.03, 0.14, Color("#FFD36A"), Vector3(-1.2, 0, -a), 0.0, 4)
	d["head"] = h.mesh()
	var p := Mesher.new(u)
	for s in [-1.0, 1.0]:
		_tail(p, Vector3(float(s) * 0.06, 0.04, -0.3), Vector3(-0.75, 0, -float(s) * 0.35), 0.62, 0.07, fur, FIRE)
	d["hips"] = p.mesh()


## Umibōzu : grand crâne lisse d'encre bleue, deux gros yeux d'or ; chapelet et kesa de moine.
static func _umibozu(d: Dictionary, u: float, lite: bool) -> void:
	var h := Mesher.new(u)
	h.ball(Vector3(0, 0.6, 0.02), Vector3(0.52, 0.52, 0.5), Color("#22314A"), Vector3.ZERO, 12)
	for s in [-1.0, 1.0]:
		var sx := float(s)
		h.ball(Vector3(sx * 0.18, 0.6, 0.47), Vector3(0.12, 0.13, 0.06), Color("#F2C14E"))
		h.ball(Vector3(sx * 0.18, 0.58, 0.525), Vector3(0.05, 0.07, 0.03), Toon.SUMI)
	d["head"] = h.mesh()
	var c := Mesher.new(u)
	c.box(Vector3(0, -0.12, 0.36), Vector3(0.13, 0.8, 0.05), Toon.GOLD, Vector3(0, 0, 0.6))
	c.box(Vector3(0, -0.12, -0.36), Vector3(0.13, 0.8, 0.05), Toon.GOLD, Vector3(0, 0, -0.6))
	var n := 6 if lite else 10
	for i in n:
		var a := TAU * float(i) / float(n)
		c.ball(Vector3(sin(a) * 0.34, 0.3, cos(a) * 0.32), Vector3(0.06, 0.06, 0.06), Color("#6E3A2A"))
	d["chest"] = c.mesh()


## Funa-yūrei : noyé aux cheveux trempés, triangle des morts, kimono blanc, pas de jambes ; louche.
static func _funa(d: Dictionary, u: float, lite: bool) -> void:
	var h := Mesher.new(u)
	_long_hair(h, HAIR, 0.7, false)
	for i in 3:
		h.box(Vector3((float(i) - 1.0) * 0.15, 0.4, 0.45), Vector3(0.09, 0.4, 0.04), HAIR, Vector3(-0.1, 0, 0))
	_tenkan(h, 0.79, 0.4, 0.6)
	d["head"] = h.mesh()
	var c := Mesher.new(u)
	_kimono(c, Color("#D8E6EA"), Toon.PRUSSIAN, Color(0, 0, 0, 0))
	d["chest"] = c.mesh()
	var p := Mesher.new(u)
	_wisp(p, Color("#CFE3EA"), lite)
	d["hips"] = p.mesh()
	d["handslot.r"] = _w_ladle()


## Onryō : cheveux noirs qui voilent la face, triangle des morts, kimono blanc, volute sans jambes.
static func _onryo(d: Dictionary, u: float, lite: bool) -> void:
	var h := Mesher.new(u)
	_long_hair(h, HAIR, 1.2, true)
	_tenkan(h, 0.86, 0.36, 0.9)
	d["head"] = h.mesh()
	var c := Mesher.new(u)
	_kimono(c, Color("#F2F0F6"), Color("#B9A8E8"), Color(0, 0, 0, 0))
	d["chest"] = c.mesh()
	var p := Mesher.new(u)
	_wisp(p, Color("#D8D2EA"), lite)
	d["hips"] = p.mesh()


## Yuki-onna : longue chevelure noire, peigne de glace, kimono blanc bleuté à obi glacier, traîne au sol.
static func _yukionna(d: Dictionary, u: float, lite: bool) -> void:
	var h := Mesher.new(u)
	_long_hair(h, HAIR, 1.3, false)
	for i in (2 if lite else 3):
		var a := (float(i) - 1.0) * 0.45
		h.spike(Vector3(a * 0.3, 0.9, -0.22), 0.045, 0.3, Color("#BFE8FF"), Vector3(-0.55, 0, -a), 0.0, 4)
	d["head"] = h.mesh()
	var c := Mesher.new(u)
	_kimono(c, Color("#E8F4FF"), Color("#7FB8E0"), Color("#7FB8E0"))
	d["chest"] = c.mesh()
	var p := Mesher.new(u)
	p.cyl(Vector3(0, -0.2, 0), Vector3(0.4, 0.42, 0.37), Color("#E8F4FF"), Vector3.ZERO, 0.85, 8)
	p.cyl(Vector3(0, -0.39, 0), Vector3(0.41, 0.04, 0.38), Color("#7FB8E0"), Vector3.ZERO, 1.0, 8)
	if not lite:
		p.spike(Vector3(0, -0.27, -0.25), 0.18, 0.34, Color("#E8F4FF"), Vector3(-2.0, 0, 0), 0.0, 6)
	d["hips"] = p.mesh()


## Umi-nyōbō : cheveux d'algue, coquillage piqué, châle d'algues sur les épaules.
static func _umi_nyobo(d: Dictionary, u: float, lite: bool) -> void:
	var weed := Color("#3F7A4E")
	var h := Mesher.new(u)
	_long_hair(h, Color("#1E2E2A"), 1.0, false)
	h.ball(Vector3(0.27, 0.86, -0.04), Vector3(0.13, 0.05, 0.11), Color("#F2C6C0"), Vector3(0, 0, -0.55))
	h.ball(Vector3(-0.2, 0.9, 0.0), Vector3(0.05, 0.05, 0.05), Toon.WASHI)
	d["head"] = h.mesh()
	var c := Mesher.new(u)
	c.cyl(Vector3(0, 0.22, 0), Vector3(0.47, 0.14, 0.44), weed, Vector3.ZERO, 0.65, 10)
	var n := 3 if lite else 6
	for i in n:
		var a := TAU * (float(i) + 0.5) / float(n)
		c.stick(Vector3(sin(a) * 0.42, 0.18, cos(a) * 0.4), Vector3(0.07, 0.42 + 0.1 * float(i % 2), 0.02), weed, Vector3(PI, a, -0.15))
	d["chest"] = c.mesh()


## Ningyo : chevelure d'algue, nageoires aux oreilles, collier de perles ; longue queue de poisson au sol.
static func _ningyo(d: Dictionary, u: float, lite: bool) -> void:
	var fin := Color("#3E8C86")
	var h := Mesher.new(u)
	_long_hair(h, Color("#1E3A3E"), 0.9, false)
	for s in [-1.0, 1.0]:
		var sx := float(s)
		h.spike(Vector3(sx * 0.4, 0.5, -0.04), 0.15, 0.28, Color("#5FB8B0"), Vector3(0, 0, -sx * 1.25), 0.0, 3, 0.25)
	d["head"] = h.mesh()
	var c := Mesher.new(u)
	c.cyl(Vector3(0, -0.2, 0), Vector3(0.4, 0.55, 0.37), fin, Vector3.ZERO, 0.85, 8)
	if not lite:
		for i in 7:
			var a := (float(i) - 3.0) * 0.32
			c.ball(Vector3(sin(a) * 0.3, 0.28 - 0.05 * cos(a * 2.0), cos(a) * 0.3), Vector3(0.04, 0.04, 0.04), Toon.WASHI)
	d["chest"] = c.mesh()
	var p := Mesher.new(u)
	p.cyl(Vector3(0, -0.12, 0), Vector3(0.32, 0.32, 0.3), fin, Vector3(PI, 0, 0), 0.72, 8)
	var tip := p.spike(Vector3(0, -0.25, -0.02), 0.22, 0.5, fin, Vector3(-1.85, 0, 0), 0.45, 8)
	for s in [-1.0, 1.0]:
		var sx := float(s)
		p.box(tip + Vector3(sx * 0.14, 0.0, -0.08), Vector3(0.3, 0.04, 0.16), Color("#5FB8B0"), Vector3(0, sx * 0.6, 0))
	d["hips"] = p.mesh()


## Kitsunebi : masque de renard blanc (museau, fentes, traits rouges), grandes oreilles, collerette, queues.
static func _kitsunebi(d: Dictionary, u: float, lite: bool, mini: bool) -> void:
	var h := Mesher.new(u)
	_fox_mask(h, true)
	d["head"] = h.mesh()
	if not mini:
		var c := Mesher.new(u)
		c.cyl(Vector3(0, 0.3, 0), Vector3(0.45, 0.15, 0.43), FOX_W, Vector3.ZERO, 0.68, 10)
		d["chest"] = c.mesh()
	var p := Mesher.new(u)
	var n := 1 if mini else (2 if lite else 3)
	for i in n:
		var k := 0.0 if n == 1 else (float(i) / float(n - 1) - 0.5) * 2.0
		_tail(p, Vector3(k * 0.08, 0.02, -0.28), Vector3(-0.85 + 0.2 * absf(k), 0, -k * 0.55), 0.7, 0.13, FOX_W, Color("#BFEFFF"))
	d["hips"] = p.mesh()


## Masque de renard : plaque blanche, museau, fentes noires, traits vermillon ; `ears` : grandes oreilles.
static func _fox_mask(h: Mesher, ears: bool) -> void:
	h.ball(Vector3(0, 0.45, 0.32), Vector3(0.4, 0.36, 0.2), FOX_W)
	var tip := h.spike(Vector3(0, 0.33, 0.42), 0.16, 0.26, FOX_W, Vector3(PI / 2.0, 0, 0), 0.25, 4, 0.7)
	h.ball(tip, Vector3(0.04, 0.035, 0.035), Toon.SUMI)
	for s in [-1.0, 1.0]:
		var sx := float(s)
		h.box(Vector3(sx * 0.15, 0.47, 0.505), Vector3(0.13, 0.03, 0.02), Toon.SUMI, Vector3(0, sx * 0.3, sx * 0.3))
		h.box(Vector3(sx * 0.13, 0.6, 0.48), Vector3(0.16, 0.035, 0.02), Toon.VERMILION, Vector3(-0.4, sx * 0.3, sx * 0.5))
		if ears:
			h.spike(Vector3(sx * 0.22, 0.84, 0.0), 0.14, 0.38, FOX_W, Vector3(0, 0, -sx * 0.3), 0.0, 4, 0.45)
			h.spike(Vector3(sx * 0.215, 0.86, 0.045), 0.08, 0.26, Toon.VERMILION, Vector3(0, 0, -sx * 0.3), 0.0, 4, 0.35)


## Montreur de renards (onmyōji) : haut eboshi noir, demi-masque de renard, ofuda à la ceinture ; lanterne.
static func _tsukai(d: Dictionary, u: float, lite: bool) -> void:
	var h := Mesher.new(u)
	h.cyl(Vector3(0, 0.86, -0.02), Vector3(0.34, 0.1, 0.34), Color("#1E1C22"), Vector3.ZERO, 0.95, 10)
	h.ball(Vector3(0, 1.08, -0.1), Vector3(0.28, 0.36, 0.3), Color("#1E1C22"), Vector3(-0.3, 0, 0))
	h.box(Vector3(0, 0.47, 0.43), Vector3(0.52, 0.15, 0.08), FOX_W)
	for s in [-1.0, 1.0]:
		var sx := float(s)
		h.box(Vector3(sx * 0.14, 0.47, 0.475), Vector3(0.11, 0.03, 0.01), Toon.SUMI, Vector3(0, 0, sx * 0.3))
		h.box(Vector3(sx * 0.14, 0.55, 0.46), Vector3(0.14, 0.03, 0.02), Toon.VERMILION, Vector3(0, 0, sx * 0.4))
	d["head"] = h.mesh()
	var c := Mesher.new(u)
	c.cyl(Vector3(0, 0.3, 0), Vector3(0.44, 0.12, 0.42), Toon.WASHI, Vector3.ZERO, 0.75, 10)
	c.cyl(Vector3(0, -0.36, 0), Vector3(0.44, 0.08, 0.41), Toon.SUMI, Vector3.ZERO, 1.0, 8)
	for i in 3:
		var x := (float(i) - 1.0) * 0.14
		c.box(Vector3(x, -0.5, 0.41), Vector3(0.08, 0.22, 0.012), Toon.WASHI, Vector3(0, 0, x))
		if not lite:
			c.box(Vector3(x, -0.5, 0.418), Vector3(0.025, 0.15, 0.008), Toon.VERMILION, Vector3(0, 0, x))
	d["chest"] = c.mesh()
	d["handslot.r"] = _w_lantern()


## Yamabushi-tengu : masque rouge au long nez, crinière blanche, tokin noir ; pompons du yuigesa ; éventail.
static func _yamabushi(d: Dictionary, u: float, lite: bool) -> void:
	var white := Color("#EFEAE0")
	var h := Mesher.new(u)
	h.ball(Vector3(0, 0.55, -0.2), Vector3(0.5, 0.5, 0.34), white)
	h.ball(Vector3(0, 0.45, 0.28), Vector3(0.4, 0.38, 0.2), TENGU_RED)
	h.spike(Vector3(0, 0.44, 0.42), 0.075, 0.5, TENGU_RED, Vector3(PI / 2.0 - 0.12, 0, 0), 0.5, 6)
	_brows(h, white)
	h.cyl(Vector3(0, 0.97, 0.12), Vector3(0.15, 0.15, 0.15), Toon.SUMI, Vector3(0.3, 0, 0), 0.6, 6)
	d["head"] = h.mesh()
	var c := Mesher.new(u)
	for s in [-1.0, 1.0]:
		var sx := float(s)
		c.box(Vector3(sx * 0.17, -0.05, 0.36), Vector3(0.07, 0.55, 0.03), white)
		for i in (2 if lite else 3):
			c.ball(Vector3(sx * 0.17, 0.12 - 0.17 * float(i), 0.4), Vector3(0.07, 0.07, 0.06), white)
	d["chest"] = c.mesh()
	d["handslot.r"] = _w_fan()


## Karasu-tengu : bec de corbeau doré, tokin rouge, crête de plumes ; grandes ailes dans le dos.
static func _tengu(d: Dictionary, u: float, lite: bool) -> void:
	var wing := Color("#24222A")
	var h := Mesher.new(u)
	var tip := h.spike(Vector3(0, 0.36, 0.44), 0.15, 0.32, BEAK, Vector3(PI / 2.0 + 0.1, 0, 0), 0.15, 4, 0.8)
	h.spike(tip + Vector3(0, 0.02, -0.03), 0.03, 0.1, BEAK, Vector3(PI - 0.3, 0, 0), 0.0, 4)
	h.cyl(Vector3(0, 1.02, 0.12), Vector3(0.13, 0.14, 0.13), Toon.VERMILION, Vector3(0.3, 0, 0), 0.6, 6)
	if not lite:
		for i in 3:
			h.spike(Vector3((float(i) - 1.0) * 0.12, 0.92, -0.3), 0.06, 0.3, wing, Vector3(-1.3, 0, (1.0 - float(i)) * 0.3), 0.0, 4, 0.4)
	d["head"] = h.mesh()
	var c := Mesher.new(u)
	_wings(c, wing, 2 if lite else 3, 0.85)
	d["chest"] = c.mesh()


## Konoha-tengu : petit bec jaune, grande feuille en chapeau, ailes de feuilles vertes et rousses.
static func _konoha(d: Dictionary, u: float, lite: bool) -> void:
	var leaf := Color("#6E9E3A")
	var h := Mesher.new(u)
	h.spike(Vector3(0, 0.34, 0.44), 0.11, 0.22, BEAK, Vector3(PI / 2.0 + 0.1, 0, 0), 0.1, 4, 0.8)
	h.ball(Vector3(0, 1.03, 0.05), Vector3(0.34, 0.035, 0.52), leaf, Vector3(-0.15, 0, 0))
	h.box(Vector3(0, 1.065, 0.05), Vector3(0.025, 0.02, 0.92), Color("#4E7A3A"), Vector3(-0.15, 0, 0))
	d["head"] = h.mesh()
	var c := Mesher.new(u)
	for s in [-1.0, 1.0]:
		var sx := float(s)
		for i in (1 if lite else 2):
			var rot := Vector3(-0.3, 0, -sx * (0.6 + 0.55 * float(i)))
			var dir := Basis.from_euler(rot) * Vector3.UP
			var col := Color("#4E7A3A") if i == 0 else Color("#D98A2B")
			c.ball(Vector3(sx * 0.15, 0.1, -0.33) + dir * 0.36, Vector3(0.15, 0.4, 0.03), col, rot)
	d["chest"] = c.mesh()


## Kamaitachi : belette — oreilles rondes, museau crème ; queue en faucille terminée d'une lame.
static func _kamaitachi(d: Dictionary, u: float, lite: bool) -> void:
	var fur := Color("#8A5F35")
	var h := Mesher.new(u)
	h.ball(Vector3(0, 0.32, 0.5), Vector3(0.16, 0.12, 0.16), Color("#E8D2A8"))
	h.ball(Vector3(0, 0.36, 0.65), Vector3(0.04, 0.035, 0.03), Toon.SUMI)
	for s in [-1.0, 1.0]:
		var sx := float(s)
		h.ball(Vector3(sx * 0.36, 0.95, 0.0), Vector3(0.13, 0.13, 0.05), fur, Vector3(0, 0, -sx * 0.35))
	d["head"] = h.mesh()
	var p := Mesher.new(u)
	var rot := Vector3(-1.0, 0, 0)
	var dir := Basis.from_euler(rot) * Vector3.UP
	var base := Vector3(0, 0.05, -0.3)
	p.ball(base + dir * 0.32, Vector3(0.09, 0.36, 0.09), fur, rot)
	var mid := base + dir * 0.62
	p.ball(mid + Vector3(0, 0.18, -0.04), Vector3(0.07, 0.24, 0.07), fur, Vector3(-0.2, 0, 0))
	if not lite:
		p.stick(mid + Vector3(0, 0.36, -0.06), Vector3(0.025, 0.4, 0.1), STEEL, Vector3(0.5, 0, 0))
	d["hips"] = p.mesh()


## Tanuki : chapeau de paille, masque sombre autour des yeux, museau ; grosse queue annelée (pas le leurre).
static func _tanuki(d: Dictionary, u: float, lite: bool, decoy: bool) -> void:
	var dark := Color("#3A2A20")
	var h := Mesher.new(u)
	_hat(h, 0.92, 0.64, 0.2, STRAW)
	h.cyl(Vector3(0, 1.025, 0), Vector3(0.1, 0.03, 0.1), Toon.VERMILION, Vector3.ZERO, 0.6, 8)
	for s in [-1.0, 1.0]:
		h.box(Vector3(float(s) * 0.17, 0.32, 0.4), Vector3(0.22, 0.1, 0.06), dark, Vector3(0, 0, float(s) * 0.3))
	h.ball(Vector3(0, 0.24, 0.42), Vector3(0.16, 0.1, 0.11), Color("#E8D2A8"))
	h.ball(Vector3(0, 0.28, 0.52), Vector3(0.045, 0.035, 0.03), Toon.SUMI)
	d["head"] = h.mesh()
	if not decoy:
		var p := Mesher.new(u)
		var rot := Vector3(-0.75, 0, 0)
		_tail(p, Vector3(0, 0.05, -0.3), rot, 0.7, 0.18, Color("#7A5838"), dark)
		if not lite:
			var dir := Basis.from_euler(rot) * Vector3.UP
			p.ball(Vector3(0, 0.05, -0.3) + dir * 0.55, Vector3(0.19, 0.06, 0.19), dark, rot)
		d["hips"] = p.mesh()


## Yuki-warashi : grand chapeau de paille rond, cape de paille (mino), écharpe rouge.
static func _warashi(d: Dictionary, u: float, lite: bool) -> void:
	var h := Mesher.new(u)
	_hat(h, 0.92, 0.62, 0.22, Color("#D9C9A0"))
	d["head"] = h.mesh()
	var c := Mesher.new(u)
	c.cyl(Vector3(0, -0.08, 0), Vector3(0.52, 0.62, 0.5), Color("#B8A47A"), Vector3.ZERO, 0.62, 12)
	c.cyl(Vector3(0, 0.3, 0), Vector3(0.37, 0.12, 0.35), Toon.VERMILION, Vector3.ZERO, 0.85, 10)
	c.box(Vector3(0.12, 0.12, -0.36), Vector3(0.1, 0.32, 0.04), Toon.VERMILION, Vector3(0.2, 0, -0.15))
	if not lite:
		for i in 6:
			var a := TAU * (float(i) + 0.5) / 6.0
			c.box(Vector3(sin(a) * 0.43, -0.2, cos(a) * 0.41), Vector3(0.03, 0.32, 0.02), Color("#8C7A52"), Vector3(-0.35, a, 0))
	d["chest"] = c.mesh()


## Mōryō : longues oreilles pointues, ofuda collé sur la face, petite corne ; corde sacrée et papiers.
static func _moryo(d: Dictionary, u: float, lite: bool) -> void:
	var skin := Color("#3A3340")
	var h := Mesher.new(u)
	h.box(Vector3(0, 0.45, 0.47), Vector3(0.17, 0.42, 0.02), Toon.WASHI, Vector3(-0.1, 0, 0))
	h.box(Vector3(0, 0.45, 0.483), Vector3(0.05, 0.3, 0.012), Toon.VERMILION, Vector3(-0.1, 0, 0))
	h.spike(Vector3(0, 0.88, 0.15), 0.05, 0.2, HORN, Vector3(0.3, 0, 0), 0.0, 5)
	for s in [-1.0, 1.0]:
		var sx := float(s)
		h.spike(Vector3(sx * 0.36, 0.56, 0.0), 0.08, 0.44, skin, Vector3(0, 0, -sx * 1.3), 0.0, 5, 0.6)
	if not lite:
		for i in 4:
			var a := (float(i) - 1.5) * 0.45
			h.spike(Vector3(a * 0.3, 0.78, -0.25), 0.07, 0.26, HAIR, Vector3(-1.1, 0, -a), 0.0, 4)
	d["head"] = h.mesh()
	var c := Mesher.new(u)
	c.cyl(Vector3(0, -0.34, 0), Vector3(0.42, 0.08, 0.39), STRAW, Vector3.ZERO, 1.0, 8)
	for s in [-1.0, 1.0]:
		var sx := float(s)
		c.box(Vector3(sx * 0.14, -0.45, 0.39), Vector3(0.07, 0.1, 0.012), Toon.WASHI, Vector3(0, 0, sx * 0.4))
		c.box(Vector3(sx * 0.16, -0.54, 0.39), Vector3(0.07, 0.1, 0.012), Toon.WASHI, Vector3(0, 0, -sx * 0.4))
	d["chest"] = c.mesh()


## Ika : manteau de calmar en pointe sur la tête, nageoires ; tentacules à la place des jambes.
static func _ika(d: Dictionary, u: float, lite: bool) -> void:
	var pink := Color("#C46FA8")
	var h := Mesher.new(u)
	h.spike(Vector3(0, 0.76, -0.05), 0.4, 0.78, pink, Vector3(-0.2, 0, 0), 0.0, 8)
	for s in [-1.0, 1.0]:
		h.spike(Vector3(float(s) * 0.1, 1.2, -0.14), 0.2, 0.36, Color("#B05A94"), Vector3(-0.2, 0, -float(s) * 1.35), 0.0, 3, 0.2)
	if not lite:
		for p in [Vector3(0.15, 0.95, 0.2), Vector3(-0.18, 1.05, 0.12), Vector3(0.0, 1.22, 0.06)]:
			h.ball(p, Vector3(0.05, 0.05, 0.04), Color("#8E3F78"))
	d["head"] = h.mesh()
	var t := Mesher.new(u)
	var n := 4 if lite else 6
	for i in n:
		var a := TAU * (float(i) + 0.5) / float(n)
		t.ray(Vector3(sin(a) * 0.2, -0.02, cos(a) * 0.2), Vector3(sin(a) * 0.45, -1.0, cos(a) * 0.45), 0.075, 0.44, Color("#D59AC8"), 0.3, 5)
	d["hips"] = t.mesh()


## Gaki : mèches éparses, gros ventre gonflé, côtes saillantes ; pagne en lambeaux.
static func _gaki(d: Dictionary, u: float, lite: bool) -> void:
	var skin := Color("#A89E8A")
	var h := Mesher.new(u)
	for i in 5:
		var a := (float(i) - 2.0) * 0.5
		h.spike(Vector3(sin(a) * 0.25, 0.85, -0.05 - absf(a) * 0.05), 0.03, 0.3, Color("#5A5650"), Vector3(-0.4, 0, -a * 0.9), 0.0, 4)
	d["head"] = h.mesh()
	var c := Mesher.new(u)
	c.ball(Vector3(0, -0.42, 0.2), Vector3(0.34, 0.3, 0.32), skin)
	c.ball(Vector3(0, -0.4, 0.515), Vector3(0.03, 0.03, 0.01), Color("#6E6250"))
	if not lite:
		for i in 3:
			c.box(Vector3(0, 0.12 - 0.09 * float(i), 0.36), Vector3(0.42 - 0.05 * float(i), 0.03, 0.02), Color("#6E6250"))
	d["chest"] = c.mesh()
	if not lite:
		var p := Mesher.new(u)
		p.cyl(Vector3(0, -0.02, 0), Vector3(0.36, 0.16, 0.34), Color("#6E6250"), Vector3.ZERO, 1.05, 6)
		p.box(Vector3(0.05, -0.18, 0.3), Vector3(0.22, 0.24, 0.04), Color("#6E6250"), Vector3(-0.1, 0, 0.15))
		d["hips"] = p.mesh()


# ------------------------------------------------------------------ corps modelés (repère du corps, face -Z)

## Tsurara : tertre de neige, stalagmites et petits glaçons fusionnés.
static func _tsurara(d: Dictionary, lite: bool) -> void:
	var m := Mesher.new(1.0)
	m.ball(Vector3(0, 0.05, 0), Vector3(0.55, 0.22, 0.55), Color("#EAF4FF"), Vector3.ZERO, 10)
	var ice := Color("#A9DDF5")
	for a in [[0.0, 0.0, 0.26, 1.5], [0.24, 0.1, 0.17, 1.0], [-0.22, 0.14, 0.16, 0.9], [0.06, -0.26, 0.15, 0.8], [-0.12, -0.2, 0.12, 0.6]]:
		var sp: Array = a
		m.cyl(Vector3(float(sp[0]), float(sp[3]) * 0.5, float(sp[1])), Vector3(float(sp[2]), float(sp[3]), float(sp[2])), ice, Vector3.ZERO, 0.0, 6)
	if not lite:
		for i in 5:
			var b := TAU * float(i) / 5.0 + 0.3
			m.spike(Vector3(cos(b) * 0.46, 0.06, sin(b) * 0.46), 0.06, 0.26, Color("#CFEFFF"), Vector3(0.5 * sin(b), 0, -0.5 * cos(b)), 0.0, 5)
	d["body"] = m.mesh()


## Sumidama : goutte d'encre à deux yeux, gouttelettes sur le dessus, flaque au sol.
static func _sumidama(d: Dictionary, lite: bool, s: float) -> void:
	var ink := Color("#26222C")
	var m := Mesher.new(1.0)
	m.ball(Vector3(0, 0.42 * s, 0), Vector3(0.5, 0.425, 0.5) * s, ink, Vector3.ZERO, 12)
	m.cyl(Vector3(0, 0.02 * s, 0), Vector3(0.62, 0.03, 0.62) * s, ink, Vector3.ZERO, 0.9, 12)
	m.spike(Vector3(0, 0.8 * s, 0.05 * s), 0.12 * s, 0.24 * s, ink, Vector3(0.3, 0, 0), 0.0, 6)
	for e in [-1.0, 1.0]:
		var ex := float(e)
		m.ball(Vector3(ex * 0.17, 0.56, -0.38) * s, Vector3.ONE * 0.09 * s, Toon.WASHI)
		m.ball(Vector3(ex * 0.17, 0.56, -0.46) * s, Vector3.ONE * 0.045 * s, Toon.SUMI)
		if not lite:
			m.ball(Vector3(ex * 0.4, 0.2, -0.2) * s, Vector3(0.07, 0.1, 0.07) * s, ink)
	d["body"] = m.mesh()


## Kasa-obake : ombrelle de papier à baleines, un œil, une langue, une jambe sur un geta.
static func _kasa(d: Dictionary, lite: bool) -> void:
	var m := Mesher.new(1.0)
	m.cyl(Vector3(0, 1.25, 0), Vector3(0.62, 0.45, 0.62), Color("#C8423A"), Vector3.ZERO, 0.1, 8)
	m.cyl(Vector3(0, 1.03, 0), Vector3(0.63, 0.04, 0.63), Toon.WASHI, Vector3.ZERO, 1.0, 8)
	m.ball(Vector3(0, 1.5, 0), Vector3(0.06, 0.06, 0.06), Toon.SUMI)
	if not lite:
		for i in 8:
			var a := TAU * (float(i) + 0.5) / 8.0
			var slope := -atan2(0.62, 0.45)
			m.box(Vector3(sin(a) * 0.33, 1.25, cos(a) * 0.33), Vector3(0.025, 0.77, 0.025), Color("#7A231E"), Vector3(slope, a, 0))
	m.cyl(Vector3(0, 0.62, 0), Vector3(0.03, 0.75, 0.03), Toon.WOOD, Vector3.ZERO, 1.0, 6)
	m.ball(Vector3(0, 0.25, 0), Vector3(0.07, 0.25, 0.07), Toon.SKIN)
	m.box(Vector3(0, 0.03, -0.02), Vector3(0.16, 0.05, 0.32), Toon.WOOD)
	m.ball(Vector3(0, 1.17, -0.44), Vector3.ONE * 0.15, Toon.WASHI)
	m.ball(Vector3(0, 1.17, -0.57), Vector3.ONE * 0.075, Toon.SUMI)
	m.box(Vector3(0, 0.98, -0.55), Vector3(0.12, 0.025, 0.34), Toon.VERMILION, Vector3(0.6, 0, 0))
	d["body"] = m.mesh()


## Karasu : corps, tête, bec, tokin, yeux, queue fusionnés ; ailes (gauche, droite) pour le battement.
static func _karasu(d: Dictionary, lite: bool) -> void:
	var black := Color("#1E1C22")
	var m := Mesher.new(1.0)
	m.ball(Vector3(0, 0.5, 0), Vector3(0.3, 0.3, 0.4), black)
	m.ball(Vector3(0, 0.78, -0.22), Vector3.ONE * 0.18, black)
	m.spike(Vector3(0, 0.76, -0.36), 0.07, 0.26, Toon.GOLD, Vector3(-PI / 2.0, 0, 0), 0.0, 6)
	m.cyl(Vector3(0, 0.98, -0.2), Vector3(0.08, 0.1, 0.08), Toon.VERMILION, Vector3.ZERO, 0.6, 6)
	for s in [-1.0, 1.0]:
		m.ball(Vector3(float(s) * 0.09, 0.82, -0.36), Vector3.ONE * 0.035, Toon.GOLD)
	for i in (1 if lite else 3):
		var a := (float(i) - (0.0 if lite else 1.0)) * 0.35
		m.box(Vector3(sin(a) * 0.1, 0.45, 0.42), Vector3(0.1, 0.04, 0.38), black, Vector3(0.3, a, 0))
	d["body"] = m.mesh()
	for s in [-1.0, 1.0]:
		var sx := float(s)
		var w := Mesher.new(1.0)
		for i in (1 if lite else 3):
			var k := float(i)
			w.box(Vector3(sx * (0.3 + 0.04 * k), 0, 0.05 + 0.1 * k), Vector3(0.66 - 0.12 * k, 0.05, 0.16), Color("#24222A"), Vector3(0, sx * (0.2 + 0.25 * k), 0))
		d["wing_l" if sx < 0.0 else "wing_r"] = w.mesh()


## Heikegani : carapace-masque de samouraï (arcade, moustache), yeux pédonculés, pinces, pattes.
static func _kani(d: Dictionary, lite: bool) -> void:
	var shell := Color("#B8452E")
	var claw := Color("#6E2A1E")
	var m := Mesher.new(1.0)
	m.ball(Vector3(0, 0.45, 0), Vector3(0.62, 0.28, 0.5), shell, Vector3.ZERO, 10)
	m.box(Vector3(0, 0.55, -0.5), Vector3(0.5, 0.06, 0.04), Toon.SUMI)
	for s in [-1.0, 1.0]:
		var sx := float(s)
		m.box(Vector3(sx * 0.15, 0.66, -0.4), Vector3(0.24, 0.05, 0.05), Toon.SUMI, Vector3(0, 0, -sx * 0.35))
		m.cyl(Vector3(sx * 0.15, 0.72, -0.4), Vector3(0.02, 0.14, 0.02), claw, Vector3.ZERO, 1.0, 5)
		m.ball(Vector3(sx * 0.15, 0.8, -0.4), Vector3.ONE * 0.05, Toon.SUMI)
		m.cyl(Vector3(sx * 0.48, 0.5, -0.38), Vector3(0.06, 0.35, 0.06), claw, Vector3.ZERO, 1.0, 6)
		m.ball(Vector3(sx * 0.5, 0.72, -0.5), Vector3(0.16, 0.2, 0.24), shell)
		m.spike(Vector3(sx * 0.5, 0.78, -0.66), 0.06, 0.18, shell, Vector3(-PI / 2.0 + 0.4, 0, 0), 0.0, 5)
		for i in 3:
			m.cyl(Vector3(sx * 0.62, 0.3, -0.15 + 0.2 * float(i)), Vector3(0.045, 0.6, 0.045), claw, Vector3(0, 0, sx * 1.0), 0.67, 5)
	if not lite:
		for p in [Vector3(0.0, 0.7, 0.1), Vector3(-0.25, 0.66, 0.15), Vector3(0.25, 0.66, 0.15)]:
			m.spike(p, 0.05, 0.12, Color("#8E3324"), Vector3.ZERO, 0.0, 5)
	d["body"] = m.mesh()


## Fugu : globe, ventre pâle, yeux, nageoires, queue, épines ; tout en un (le corps gonfle d'un bloc).
static func _fugu(d: Dictionary, lite: bool) -> void:
	var fin := Color("#B8952E")
	var m := Mesher.new(1.0)
	m.ball(Vector3(0, 0.6, 0), Vector3(0.42, 0.378, 0.483), Color("#D9B870"), Vector3.ZERO, 12)
	m.ball(Vector3(0, 0.48, -0.1), Vector3(0.33, 0.21, 0.36), Color("#F1E8D6"))
	for e in [-1.0, 1.0]:
		var fe := float(e)
		m.ball(Vector3(fe * 0.2, 0.74, -0.32), Vector3.ONE * 0.08, Toon.WASHI)
		m.ball(Vector3(fe * 0.2, 0.74, -0.39), Vector3.ONE * 0.045, Toon.SUMI)
		m.cyl(Vector3(fe * 0.42, 0.6, 0.05), Vector3(0.12, 0.2, 0.12), fin, Vector3(0, 0, -fe * 1.3), 0.0, 4)
	m.cyl(Vector3(0, 0.6, 0.5), Vector3(0.18, 0.26, 0.18), fin, Vector3(-1.4, 0, 0), 0.0, 4)
	var n := 6 if lite else 10
	for i in n:
		var a := TAU * float(i) / float(n)
		m.cyl(Vector3(cos(a) * 0.4, 0.6 + sin(a) * 0.34, 0.0), Vector3(0.035, 0.14, 0.035), Color("#6E5A2E"), Vector3(0, 0, a - PI / 2.0), 0.0, 4)
	d["body"] = m.mesh()


# ------------------------------------------------------------------ armes (repère handslot, unités du monde)

static func _w_blade(ln: float, steel: Color) -> ArrayMesh:
	var m := Mesher.new(1.0)
	m.box(Vector3.ZERO, Vector3(0.05, 0.2, 0.05), WOOD_D)
	m.box(Vector3(0, 0.1 + ln / 2.0, 0), Vector3(0.035, ln, 0.08), steel)
	return m.mesh()


## Nodachi du général : longue lame claire, garde d'or.
static func _w_nodachi() -> ArrayMesh:
	var m := Mesher.new(1.0)
	m.box(Vector3(0, -0.02, 0), Vector3(0.05, 0.34, 0.05), Color("#2A2228"))
	m.cyl(Vector3(0, 0.16, 0), Vector3(0.09, 0.025, 0.09), Toon.GOLD, Vector3.ZERO, 1.0, 8)
	m.box(Vector3(0, 0.82, 0.0), Vector3(0.035, 1.3, 0.085), STEEL)
	m.box(Vector3(0, 1.5, -0.01), Vector3(0.034, 0.1, 0.06), STEEL, Vector3(-0.3, 0, 0))
	return m.mesh()


## Massue de bois de l'oni, cloutée de fer.
static func _w_club_wood() -> ArrayMesh:
	var m := Mesher.new(1.0)
	m.cyl(Vector3(0, 0.08, 0), Vector3(0.035, 0.36, 0.035), WOOD_D, Vector3.ZERO, 1.0, 6)
	m.cyl(Vector3(0, 0.52, 0), Vector3(0.07, 0.55, 0.07), Color("#8A6440"), Vector3.ZERO, 1.8, 7)
	for i in 4:
		var a := TAU * float(i) / 4.0
		m.spike(Vector3(cos(a) * 0.1, 0.55 + 0.1 * float(i % 2), sin(a) * 0.1), 0.03, 0.08, IRON, Vector3(0, -a, -PI / 2.0), 0.0, 4)
	return m.mesh()


static func _w_staff() -> ArrayMesh:
	var m := Mesher.new(1.0)
	m.cyl(Vector3(0, 0.35, 0), Vector3(0.03, 1.3, 0.03), WOOD_D, Vector3.ZERO, 1.0, 6)
	m.ball(Vector3(0, 1.05, 0), Vector3.ONE * 0.12, Toon.VERMILION)
	return m.mesh()


## Kanabō : manche de bois, grosse tête de fer cloutée d'or.
static func _w_kanabo() -> ArrayMesh:
	var m := Mesher.new(1.0)
	m.cyl(Vector3(0, 0.1, 0), Vector3(0.04, 0.5, 0.04), WOOD_D, Vector3.ZERO, 1.0, 8)
	m.cyl(Vector3(0, 0.85, 0), Vector3(0.1, 1.0, 0.1), IRON, Vector3.ZERO, 1.6, 8)
	for i in 6:
		var a := TAU * float(i) / 6.0
		m.ball(Vector3(cos(a) * 0.15, 0.6 + 0.12 * float(i % 3), sin(a) * 0.15), Vector3.ONE * 0.045, Toon.GOLD)
	return m.mesh()


## Arquebuse : canon de fer, crosse de bois, bague d'or, mèche rouge.
static func _w_rifle() -> ArrayMesh:
	var m := Mesher.new(1.0)
	m.box(Vector3(0, -0.05, 0), Vector3(0.07, 0.32, 0.12), WOOD_D)
	m.cyl(Vector3(0, 0.6, 0), Vector3(0.035, 1.1, 0.035), IRON, Vector3.ZERO, 1.0, 8)
	m.cyl(Vector3(0, 0.3, 0), Vector3(0.05, 0.06, 0.05), Toon.GOLD, Vector3.ZERO, 1.0, 8)
	m.ball(Vector3(0, 0.2, 0.08), Vector3.ONE * 0.03, Toon.VERMILION)
	return m.mesh()


## Éventail de plumes (hauchiwa) du yamabushi-tengu.
static func _w_fan() -> ArrayMesh:
	var m := Mesher.new(1.0)
	m.cyl(Vector3(0, 0.1, 0), Vector3(0.02, 0.35, 0.02), Color("#3B2E25"), Vector3.ZERO, 1.0, 6)
	for i in 7:
		var a := deg_to_rad(-54.0 + 18.0 * float(i))
		m.box(Vector3(sin(a) * 0.19, 0.42 + cos(a) * 0.19, 0), Vector3(0.07, 0.38, 0.015), Color("#2E2A30"), Vector3(0, 0, -a))
	return m.mesh()


## Chaîne de fer et boulet du geôlier.
static func _w_chain() -> ArrayMesh:
	var m := Mesher.new(1.0)
	for i in 5:
		m.ball(Vector3(0, 0.1 + 0.08 * float(i), 0), Vector3.ONE * 0.04, IRON)
	m.ball(Vector3(0, 0.6, 0), Vector3.ONE * 0.16, IRON)
	return m.mesh()


## Grand bouclier rond : bordure sumi, disque de bois, bosse dorée des deux côtés.
static func _w_shield() -> ArrayMesh:
	var m := Mesher.new(1.0)
	var r := Vector3(PI / 2.0, 0, 0)
	m.cyl(Vector3(0, 0.05, 0.08), Vector3(0.46, 0.05, 0.46), Toon.SUMI, r, 1.0, 16)
	m.cyl(Vector3(0, 0.05, 0.08), Vector3(0.4, 0.07, 0.4), Toon.WOOD, r, 1.0, 16)
	m.ball(Vector3(0, 0.05, 0.12), Vector3(0.11, 0.06, 0.11), Toon.GOLD, r)
	m.ball(Vector3(0, 0.05, 0.04), Vector3(0.11, 0.06, 0.11), Toon.GOLD, r)
	return m.mesh()


## Louche (hishaku) du noyé.
static func _w_ladle() -> ArrayMesh:
	var m := Mesher.new(1.0)
	m.cyl(Vector3(0, 0.3, 0), Vector3(0.02, 0.8, 0.02), WOOD_D, Vector3.ZERO, 1.0, 6)
	m.cyl(Vector3(0, 0.72, 0.08), Vector3(0.1, 0.12, 0.1), Toon.WOOD, Vector3.ZERO, 1.3, 10)
	return m.mesh()


## Lanterne de papier au bout d'une perche (la panse lumineuse est ajoutée à part).
static func _w_lantern() -> ArrayMesh:
	var m := Mesher.new(1.0)
	m.cyl(Vector3(0, 0.42, 0), Vector3(0.022, 1.15, 0.022), WOOD_D, Vector3.ZERO, 1.0, 6)
	m.cyl(Vector3(0, 1.0, 0), Vector3(0.1, 0.04, 0.1), Toon.SUMI, Vector3.ZERO, 1.0, 8)
	m.cyl(Vector3(0, 1.33, 0), Vector3(0.1, 0.04, 0.1), Toon.SUMI, Vector3.ZERO, 1.0, 8)
	return m.mesh()


# ------------------------------------------------------------------ assembleur

## Accumule des primitives transformées et colorées, puis rend un seul ArrayMesh (couleurs de sommets).
## Les échelles doivent rester positives (sinon l'ordre des triangles s'inverse).
class Mesher:
	extends RefCounted

	static var _prims := {}  # clé -> tableaux d'une primitive unité

	var u := 1.0
	var _v := PackedVector3Array()
	var _n := PackedVector3Array()
	var _c := PackedColorArray()
	var _ix := PackedInt32Array()

	func _init(scale_u: float) -> void:
		u = scale_u

	## Pavé centré sur `pos`, de dimensions `size`.
	func box(pos: Vector3, size: Vector3, col: Color, rot := Vector3.ZERO) -> void:
		_put("box", pos, size, Basis.from_euler(rot), col)

	## Ellipsoïde centré sur `pos`, de rayons `radii`.
	func ball(pos: Vector3, radii: Vector3, col: Color, rot := Vector3.ZERO, seg := 8) -> void:
		_put("ball:%d" % seg, pos, radii, Basis.from_euler(rot), col)

	## Tronc de cône centré : `size` = (rayon bas x, hauteur, rayon bas z) ; rayon haut = bas × `top`.
	func cyl(pos: Vector3, size: Vector3, col: Color, rot := Vector3.ZERO, top := 1.0, sides := 8) -> void:
		_put("cyl:%.2f:%d" % [top, sides], pos, size, Basis.from_euler(rot), col)

	## Pavé posé par le milieu de sa base (plume, lame) ; s'étire le long de son axe Y tourné.
	func stick(base: Vector3, size: Vector3, col: Color, rot := Vector3.ZERO) -> void:
		var b := Basis.from_euler(rot)
		_put("box", base + b * Vector3(0, size.y * 0.5, 0), size, b, col)

	## Cône posé par sa base (corne, bec, oreille), vers l'axe Y tourné ; `flat` aplatit en z. Rend la pointe.
	func spike(base: Vector3, r: float, h: float, col: Color, rot := Vector3.ZERO, top := 0.0, sides := 6, flat := 1.0) -> Vector3:
		var b := Basis.from_euler(rot)
		var tip := base + b * Vector3(0, h, 0)
		_put("cyl:%.2f:%d" % [top, sides], (base + tip) * 0.5, Vector3(r, h, r * flat), b, col)
		return tip

	## Cône posé par sa base, orienté vers `dir` (tentacules).
	func ray(base: Vector3, dir: Vector3, r: float, h: float, col: Color, top := 0.0, sides := 6) -> Vector3:
		var d := dir.normalized()
		var b: Basis = Basis(Quaternion(Vector3.UP, d)) if d.dot(Vector3.UP) > -0.999 else Basis(Vector3.RIGHT, PI)
		var tip := base + d * h
		_put("cyl:%.2f:%d" % [top, sides], (base + tip) * 0.5, Vector3(r, h, r), b, col)
		return tip

	func _put(key: String, pos: Vector3, scl: Vector3, rot: Basis, col: Color) -> void:
		var a := _arrays(key)
		var b := rot * Basis.from_scale(scl)
		var nb := b.inverse().transposed()
		var xf := Transform3D(b.scaled(Vector3.ONE * u), pos * u)
		var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var base := _v.size()
		for k in vs.size():
			_v.append(xf * vs[k])
			_n.append((nb * ns[k]).normalized())
			_c.append(col)
		var raw = a[Mesh.ARRAY_INDEX]
		if raw is PackedInt32Array:
			var idx: PackedInt32Array = raw
			for k in idx.size():
				_ix.append(base + idx[k])
		else:
			for k in vs.size():
				_ix.append(base + k)

	## Maillage final (null si vide).
	func mesh() -> ArrayMesh:
		if _v.is_empty():
			return null
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = _v
		arr[Mesh.ARRAY_NORMAL] = _n
		arr[Mesh.ARRAY_COLOR] = _c
		arr[Mesh.ARRAY_INDEX] = _ix
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m

	## Tableaux d'une primitive unité (pavé 1×1×1, sphère de rayon 1, cylindre de hauteur 1 et rayon bas 1).
	static func _arrays(key: String) -> Array:
		if _prims.has(key):
			var got: Array = _prims[key]
			return got
		var p := key.split(":")
		var pm: PrimitiveMesh
		if p[0] == "box":
			pm = BoxMesh.new()
		elif p[0] == "ball":
			var s := SphereMesh.new()
			s.radius = 1.0
			s.height = 2.0
			s.radial_segments = p[1].to_int()
			s.rings = maxi(int(p[1].to_float() * 0.5), 3)
			pm = s
		else:
			var c := CylinderMesh.new()
			c.bottom_radius = 1.0
			c.top_radius = p[1].to_float()
			c.height = 1.0
			c.radial_segments = p[2].to_int()
			c.rings = 0
			pm = c
		var arrays := pm.get_mesh_arrays()
		_prims[key] = arrays
		return arrays
