extends "res://scripts/boss_mini_base.gd"
## Mini-boss du monde 6 (Kurama) — le chef des karasu-tengu (22 PV × monde).
##  Son manteau de plumes est son bouclier (10) : un coup ne fait qu'effleurer. Posé au sol, une BOUCLE
##  fermée tracée autour de lui (cercle or au sol) arrache tout le manteau : à terre 5.5 s, vulnérable
##  (dégâts ×2). En vol, il est hors d'atteinte. Prépare Sōjōbō (tornade tranchée, puis boucle).
##  Attaques : salve de plumes en éventail (lueur 0.8 s) ; envol puis piqué en ligne (bande annoncée
##  1.0 s, 12 m/s) qui le repose près du héros.
## Apparence (direction « Masque d'encre », règles en tête de yokai_ink_w1.gd) : le karasu commun du monde 6
## (yokai_ink_w6.gd) en GARDIEN de 2,8 m, sur le rig des yōkai d'encre (ink_rig.gd) — corps d'encre bleu-noir,
## obi de cèdre à écume du ravin et liserés d'or, collier d'or ; MASQUE DE PLUMES CERNÉ D'OR aux yeux d'or ronds
## cernés de washi, sourcils de washi, GRAND BEC D'OR, tokin braise à cordon d'or, crête de plumes à penne d'or ;
## les bras sont des AILES D'ENCRE IMMENSES (bord d'attaque d'or, rémiges à pointes d'or) qui battent ; plumes
## de la queue en gouttes. Le manteau (bouclier) : collerette de longues plumes d'encre à pointes d'or sous un
## anneau d'or. Seule l'apparence a changé : PV, manteau, boucle, zones, rythme, interface et robot sont ceux d'avant.

const Yokai = preload("res://scripts/yokai_parts.gd")
const W6 = preload("res://scripts/yokai_ink_w6.gd")  # palette du monde 6 (encre du corbeau, cèdre, braise)
const Loop = preload("res://scripts/boss_loop.gd")
const FEATHER := Color("#1E1C22")  # plumes (éclaboussures, manteau)
const HEIGHT := 2.8  # le karasu commun fait 1 m
const HINT_R := 2.1  # rayon conseillé de la boucle
const SHIELD := 10.0
const VOLLEY_TELE := 0.8
const DIVE_TELE := 1.0
const DIVE_SPEED := 12.0
const DIVE_W := 0.9  # demi-largeur de la bande du piqué
const SOAR_T := 0.7
const FLY_Y := 3.2

var _cloak: Node3D  # le manteau de plumes (bouclier)
var _hint: Node3D
var _pts: Array = []  # Vector2 de la ruée depuis le dernier end_stroke
var _cycle := 0
var _dive_from := Vector3.ZERO
var _dive_to := Vector3.ZERO
var _dive_dir := Vector3(0, 0, 1)
var _fly := 0.0  # hauteur de vol (0 = posé)
var _death_played := false


func _ready() -> void:
	title = "Karasu-tengu"
	hp = 22.0 * max_hp_mult
	max_hp = hp
	radius = 1.0
	_build()
	_shield_init(SHIELD, Vector3(1.4, 1.8, 1.4), 1.4)
	_state = "spawn"
	_timer = 1.2


# ------------------------------------------------------------------ construction

## Marionnette du gardien : le rig des yōkai d'encre (ink_rig.gd) habillé des pièces bâties ici (le genre
## « karasu_o » n'existe dans aucun yokai_ink_wN.gd : _dress est remplacé, le reste du rig sert tel quel).
## Les bras sont les ailes, ouvertes à l'horizontale comme celles du karasu commun ; `flap` les fait battre
## (ajouté à l'écartement des bras). Les noms d'animations KayKit du combat deviennent ses clips.
class Rig extends "res://scripts/ink_rig.gd":
	static var _cache := {}  # léger -> pièces
	var flap := 0.0  # battement des ailes (rad, positif = ailes levées)

	func setup(k: String, height := H_REF) -> void:
		super.setup(k, height)
		_rest_r = Vector3(0.2, 0, 1.45)
		_rest_l = Vector3(0.2, 0, -1.45)
		_eval(0.0)
		for j in SLOTS:
			_out[j] = _tgt[j]
		_apply()

	## Le masque regarde un peu plus la caméra (le bec doit se lire du dessus) ; les ailes battent.
	func _apply() -> void:
		super._apply()
		_head.rotation.x += 0.15
		_arms[0].rotation.z -= flap
		_arms[1].rotation.z += flap

	func _dress() -> void:
		var key := 1 if Toon.lite else 0
		if not _cache.has(key):
			_cache[key] = _build_parts(Toon.lite)
		var d: Dictionary = _cache[key]
		_parts.clear()
		_part_id = PackedStringArray()
		_part_on(_body, "body", d)
		_part_on(_head, "head", d)
		_part_on(_arms[0], "arm", d)
		_part_on(_arms[1], "arm", d)
		for n in _drips:
			n.queue_free()
		_drips.clear()
		_drip_spread = float(d.get("spread", 0.0))
		var pts: PackedVector3Array = d.get("drips", PackedVector3Array())
		for p in pts:
			var piv := Node3D.new()
			piv.position = p
			_body.add_child(piv)
			_drips.append(piv)
			_part_on(piv, "drip", d)

	## Pièces (unités du modèle, H_REF = 1,75 m, face vers -Z), deux surfaces : toon à contour, aplat lumineux.
	static func _build_parts(lite: bool) -> Dictionary:
		var d := {}
		var b := Yokai.Mesher.new(1.0)
		Yokai.ink_body(b, 1.0, W6.INK_CROW, W6.CLOTH, W6.WAVE, W6.LINE, lite, true)
		# jabot : plumes du poitrail en pointe sous le masque ; collier d'or au cou, pendentif d'or
		b.spike(Vector3(0, 0.98, -0.3), 0.18, 0.34, W6.FEATHER, Vector3(PI + 0.35, 0, 0), 0.0, 5, 0.4)
		b.cyl(Vector3(0, 1.0, 0), Vector3(0.44, 0.04, 0.42), Toon.GOLD, Vector3.ZERO, 1.0, 12)
		b.cyl(Vector3(0, 0.84, -0.4), Vector3(0.07, 0.02, 0.07), Toon.GOLD, Vector3(PI / 2.0, 0, 0), 1.0, 8)
		if not lite:
			# plumes des épaules : deux touffes d'encre qui dépassent derrière les bosses
			for s in [-1.0, 1.0]:
				var x := float(s)
				b.stick(Vector3(x * 0.4, 1.06, 0.1), Vector3(0.1, 0.3, 0.04), W6.FEATHER, Vector3(-1.1, 0, -x * 0.6))
		d["body"] = b.mesh()
		var a := Yokai.Mesher.new(1.0)
		var f := Yokai.Mesher.new(1.0)
		# masque de plumes cerné d'or, plus large que celui des communs ; sourcils de washi froncés
		Yokai.mask_plate(a, W6.FEATHER, 1.15, 1.1, true)
		Yokai.mask_brows(a, Toon.WASHI, true, 1.15)
		# yeux d'or ronds et fixes, cernés de washi (regard d'oiseau)
		for s in [-1.0, 1.0]:
			var x := float(s) * 0.14
			a.ball(Vector3(x, 0.06, Yokai.FACE_Z + 0.01), Vector3(0.09, 0.09, 0.02), Toon.WASHI, Vector3.ZERO, 8)
			f.ball(Vector3(x, 0.06, Yokai.FACE_Z - 0.005), Vector3(0.066, 0.066, 0.015), Yokai.EYE_GOLD, Vector3.ZERO, 8)
			f.ball(Vector3(x, 0.06, Yokai.FACE_Z - 0.017), Vector3(0.026, 0.026, 0.01), Toon.SUMI, Vector3.ZERO, 6)
		# grand bec d'or, un peu baissé : mandibule haute à arête sumi, mandibule basse plus courte
		a.spike(Vector3(0, -0.05, Yokai.FACE_Z + 0.02), 0.13, 0.58, Toon.GOLD, Vector3(-PI / 2.0 - 0.3, 0, 0), 0.0, 5, 0.7)
		a.box(Vector3(0, -0.06, Yokai.FACE_Z - 0.2), Vector3(0.2, 0.014, 0.34), Toon.SUMI, Vector3(0.3, 0, 0))
		a.spike(Vector3(0, -0.14, Yokai.FACE_Z + 0.02), 0.09, 0.4, Yokai.BEAK, Vector3(-PI / 2.0 - 0.5, 0, 0), 0.0, 4, 0.6)
		# tokin : bonnet braise à cordon et bouton d'or, posé sur le front ; crête de plumes, penne d'or au milieu
		a.cyl(Vector3(0, 0.36, Yokai.MASK_Z + 0.1), Vector3(0.125, 0.17, 0.125), W6.LINE, Vector3(0.2, 0, 0), 0.55, 6)
		a.cyl(Vector3(0, 0.285, Yokai.MASK_Z + 0.1), Vector3(0.14, 0.03, 0.14), Toon.GOLD, Vector3(0.2, 0, 0), 1.0, 8)
		a.ball(Vector3(0, 0.45, Yokai.MASK_Z + 0.08), Vector3(0.035, 0.035, 0.035), Toon.GOLD, Vector3.ZERO, 6)
		var n := 3 if lite else 5
		for i in n:
			var k := float(i) - float(n - 1) * 0.5
			a.stick(Vector3(k * 0.1, 0.22, Yokai.MASK_Z + 0.3), Vector3(0.06, 0.42 - 0.04 * absf(k), 0.035), W6.FEATHER, Vector3(0.9, 0, -k * 0.3))
		a.stick(Vector3(0, 0.32, Yokai.MASK_Z + 0.26), Vector3(0.045, 0.44, 0.03), Toon.GOLD, Vector3(0.7, 0, 0))
		d["head"] = Yokai.two(a, f)
		# aile (bras) : vole le long de -Y depuis l'épaule, large dans le plan YZ (horizontale une fois ouverte) ;
		# os d'encre, membrane de plumes en deux couches, bord d'attaque d'or, rémiges à pointes d'or
		var w := Yokai.Mesher.new(1.0)
		w.cyl(Vector3(0, -0.4, 0), Vector3(0.1, 0.8, 0.11), W6.INK_CROW, Vector3(PI, 0, 0), 0.7, 7)
		w.box(Vector3(0, -0.55, 0.03), Vector3(0.055, 0.86, 0.5), W6.FEATHER, Vector3(0.1, 0, 0))
		w.box(Vector3(0, -0.32, 0.1), Vector3(0.07, 0.46, 0.3), W6.INK_CROW, Vector3(0.15, 0, 0))
		w.box(Vector3(0, -0.5, -0.21), Vector3(0.065, 0.9, 0.035), Toon.GOLD, Vector3(0.1, 0, 0))
		var pens := 4 if lite else 7
		for i in pens:
			var k := float(i) / float(pens - 1) - 0.5  # -0.5..0.5
			var ln := 0.6 - 0.18 * absf(k)
			var rot := Vector3(PI - k * 0.9, 0, 0)
			var base := Vector3(0, -0.95, 0.03 + k * 0.46)
			w.stick(base, Vector3(0.05, ln, 0.1), W6.FEATHER, rot)
			if not lite:
				w.ball(base + Basis.from_euler(rot) * Vector3(0, ln, 0), Vector3(0.035, 0.05, 0.035), Toon.GOLD, Vector3.ZERO, 6)
		d["arm"] = w.mesh()
		# queue : plumes à la place des gouttes, penchées vers l'arrière (spread), pointe d'or
		var t := Yokai.Mesher.new(1.0)
		t.ball(Vector3.ZERO, Vector3(0.07, 0.06, 0.07), W6.INK_CROW, Vector3.ZERO, 6)
		t.stick(Vector3.ZERO, Vector3(0.09, 0.46, 0.04), W6.FEATHER, Vector3(PI, 0, 0))
		t.ball(Vector3(0, -0.46, 0), Vector3(0.04, 0.05, 0.03), Toon.GOLD, Vector3.ZERO, 6)
		d["drip"] = t.mesh()
		d["drips"] = PackedVector3Array([Vector3(0, 0.42, 0.3), Vector3(-0.13, 0.44, 0.26), Vector3(0.13, 0.44, 0.26)])
		d["spread"] = 0.7
		return d


func _build() -> void:
	Toon.disc(self, 1.0, Color(0, 0, 0, 0.16))
	body = Node3D.new()
	add_child(body)
	body.rotation.y = PI  # il entre face au héros (le corps regarde vers -Z ; _face le tourne ensuite)
	ch = Rig.new()
	body.add_child(ch)
	ch.setup("karasu_o", HEIGHT)
	ch.idle = "Idle_Combat"
	ch.play("Idle_Combat")
	# manteau de plumes (le bouclier) : anneau d'or aux épaules, collerette de longues plumes d'encre à pointes
	# d'or, évasées vers le bas (une seule pièce ; `scale` le fait repousser)
	_cloak = Node3D.new()
	body.add_child(_cloak)
	_cloak.position = Vector3(0, 1.75, 0)
	var m := Yokai.Mesher.new(1.0)
	m.cyl(Vector3(0, 0.03, 0), Vector3(0.78, 0.06, 0.78), Toon.GOLD, Vector3.ZERO, 1.0, 14)
	var n := 8 if Toon.lite else 12
	for k in n:
		var a := TAU * (float(k) + 0.5) / float(n)
		var rot := Vector3(PI - 0.25, PI * 0.5 - a, 0)
		var base := Vector3(cos(a) * 0.74, 0, sin(a) * 0.74)
		var tip := m.spike(base, 0.15, 1.1, FEATHER, rot, 0.2, 4, 0.3)
		if not Toon.lite:
			m.ball(tip, Vector3(0.05, 0.07, 0.04), Toon.GOLD, Vector3(0, PI * 0.5 - a, 0), 6)
	var mi := MeshInstance3D.new()
	mi.mesh = m.mesh()
	mi.set_surface_override_material(0, _ink_mat())
	_cloak.add_child(mi)
	_hint = Loop.hint_ring(self, HINT_R, Toon.GOLD)
	_make_stars(body, 3.2)
	body.scale = Vector3.ONE * 0.01


## Matériau toon à couleurs de sommets, contour d'encre (le manteau).
static func _ink_mat() -> StandardMaterial3D:
	var m := Toon.mat(Color.WHITE, true, 0.03)
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.rim = 0.35
	m.rim_tint = 0.5
	return m


# ------------------------------------------------------------------ interface avec main

func check_dash(a: Vector3, b: Vector3, stroke_id: int) -> bool:
	if dead:
		return false
	if hero.dashing and _grounded():
		Loop.record(_pts, a, b)
	if not _hittable():
		return false
	# à terre : coup plein (×2) ; dans son manteau : il effleure et use les plumes
	if _last_stroke != stroke_id and _seg_dist(position, a, b) < radius + 0.55:
		_last_stroke = stroke_id
		return true
	return false


## Fin du trait : une boucle fermée autour de lui, posé, arrache le manteau.
func end_stroke(_stroke_id: int) -> void:
	if not dead and not _pts.is_empty():
		# la dernière image de la ruée n'est pas forcément passée par check_dash
		var pa: Vector3 = main._prev_hero
		Loop.record(_pts, pa, hero.position)
	var pts: Array = _pts
	_pts = []
	if dead or pts.size() < 6 or vulnerable_t > 0.0 or not _grounded():
		return
	var loop := Loop.find_loop(pts, Vector2(position.x, position.z))
	if loop.size() < 3:
		return
	_tear()


func touching_hero(p: Vector3) -> bool:
	if dead or _state != "rush" or _fly > 1.2:
		return false
	return Vector2(p.x - position.x, p.z - position.z).length() < radius + 0.35


func _extra_danger(p: Vector3, _eta: float) -> bool:
	if _state != "rush":
		return false
	return _seg_dist(p, position, _dive_to) < DIVE_W + DANGER_MARGIN


func _aoe_target(center: Vector3, reach: float) -> Vector3:
	if not _hittable():
		return Vector3.INF
	if Vector2(position.x - center.x, position.z - center.z).length() >= reach + radius:
		return Vector3.INF
	return position + Vector3(0, 1.4, 0)


func _zone_fire(z: Dictionary) -> void:
	if String(z["tag"]) == "dive":
		_state = "rush"
		ch.play("Walking_D_Skeletons", 2.6)


func _on_die() -> void:
	_cloak.visible = false
	_hint.visible = false
	ch.set_glow(0.0)


## Manteau arraché : à terre, plus d'attaque jusqu'à la fin de la fenêtre.
func _on_shield_break() -> void:
	_clear_zones()
	ch.set_glow(0.0)
	_state = "torn"
	_cloak.visible = false
	ch.play_once("Hit_A", 1.2)


func _on_shield_back() -> void:
	if _state != "torn":
		return
	_state = "regrow"
	_timer = 0.6
	_cloak.visible = true
	_cloak.scale = Vector3.ONE * 0.05


func _sh_hidden() -> bool:
	return _fly > 1.0


# ------------------------------------------------------------------ boucle

func _step(delta: float) -> void:
	var dir := _dir_to_hero()
	match _state:
		"spawn":
			_timer -= delta
			body.scale = Vector3.ONE * clampf(1.0 - _timer / 1.2, 0.01, 1.0)
			if _timer <= 0.0:
				body.scale = Vector3.ONE
				_state = "perch"
				_timer = 1.6
		"perch":
			_face(dir, delta, 4.0)
			_fly = move_toward(_fly, 0.0, delta * 6.0)
			_timer -= delta
			if _timer <= 0.0:
				_cycle += 1
				if _cycle % 2 == 1:
					_state = "volley"
					_timer = VOLLEY_TELE
					ch.play_once("Spellcast_Shoot", 1.3)  # les deux ailes se rabattent devant : la salve
				else:
					_state = "soar"
					_timer = SOAR_T
					main.splash(position + Vector3(0, 0.5, 0), FEATHER, 10)
		"volley":
			_face(dir, delta, 4.0)
			_timer -= delta
			if _flash <= 0.0:
				ch.set_glow(0.55 * clampf(1.0 - _timer / VOLLEY_TELE, 0.0, 1.0), Toon.VERMILION)
			if _timer <= 0.0:
				ch.set_glow(0.0)
				# plumes en éventail (plus nombreuses quand il faiblit)
				var n := 5 if hp > max_hp * 0.5 else 7
				var spread := deg_to_rad(60.0 if n == 5 else 84.0)
				for i in n:
					var ang := -spread * 0.5 + spread * float(i) / float(n - 1)
					var d := dir.rotated(Vector3.UP, ang)
					main.spawn_bullet(position + Vector3(0, 1.4, 0) + d * 1.2, d)
				_state = "perch"
				_timer = 2.6 if hp > max_hp * 0.5 else 2.2
		"soar":
			_timer -= delta
			_fly = lerpf(FLY_Y, 0.0, clampf(_timer / SOAR_T, 0.0, 1.0))
			if _timer <= 0.0:
				_start_dive()
		"dive":
			# en l'air au-dessus du départ : la bande se remplit (_zone_fire lance le piqué)
			_face(_dive_dir, delta, 8.0)
			_fly = FLY_Y
		"rush":
			var left := Vector2(_dive_to.x - position.x, _dive_to.z - position.z).length()
			var mv := DIVE_SPEED * delta
			var total := maxf(Vector2(_dive_to.x - _dive_from.x, _dive_to.z - _dive_from.z).length(), 0.01)
			if left <= mv:
				_land()
			else:
				position += _dive_dir * mv
				_fly = FLY_Y * clampf(left / total, 0.0, 1.0)
		"torn":
			_fly = move_toward(_fly, 0.0, delta * 6.0)
		"regrow":
			_timer -= delta
			_cloak.scale = Vector3.ONE * clampf(1.0 - _timer / 0.6, 0.05, 1.0)
			if _timer <= 0.0:
				_cloak.scale = Vector3.ONE
				_state = "perch"
				_timer = 1.4
		"dying":
			_timer += delta
			if not _death_played:
				_death_played = true
				ch.hold()
				ch.play_once("Death_C_Skeletons", 1.2, 0.05)
			_fly = move_toward(_fly, 0.0, delta * 4.0)
			body.position.y = _fly - maxf(_timer - 1.4, 0.0) * 1.5
			if _timer > 2.2:
				queue_free()
	_animate()


## Piqué : du point d'envol vers le héros (un peu au-delà), bande annoncée au sol.
func _start_dive() -> void:
	_dive_from = Vector3(position.x, 0, position.z)
	var d := Vector3(hero.position.x, 0, hero.position.z) - _dive_from
	var l := d.length()
	_dive_dir = d / l if l > 0.3 else _dir_to_hero()
	var e := _dive_from + _dive_dir * clampf(l + 1.5, 3.0, 9.0)
	_dive_to = Vector3(clampf(e.x, -HALF.x + 1.0, HALF.x - 1.0), 0, clampf(e.z, -HALF.y + 1.0, HALF.y - 1.0))
	var v := _dive_to - _dive_from
	var vl := v.length()
	if vl < 1.0:
		_land()
		return
	_dive_dir = v / vl
	_zone_rect(_dive_from + v * 0.5, _dive_dir, DIVE_W, vl * 0.5, DIVE_TELE, "dive", Vector2(0, -1))
	_state = "dive"


## Il se pose au bout du piqué : la fenêtre pour la boucle.
func _land() -> void:
	position = Vector3(_dive_to.x, 0, _dive_to.z)
	main.clamp_to_arena(self, radius)
	_fly = 0.0
	_state = "perch"
	_timer = 2.8 if hp > max_hp * 0.5 else 2.3
	main.splash(position + Vector3(0, 0.4, 0), FEATHER, 12)
	main.vfx.ring(Vector3(position.x, 0.08, position.z), Toon.SUMI, 1.4)
	ch.play("Idle_Combat")


func _grounded() -> bool:
	return _state == "perch" or _state == "volley" or _state == "regrow"


func _hittable() -> bool:
	return not (_state in ["spawn", "soar", "dive", "rush", "dying"])


## La boucle arrache tout le manteau : le bouclier tombe d'un coup.
func _tear() -> void:
	main.float_text(position + Vector3(0, 1.6, 0), "円", Toon.GOLD)
	main.big_hit(position + Vector3(0, 1.0, 0))
	main.splash(position + Vector3(0, 1.4, 0), FEATHER, 26)
	main.shake = maxf(float(main.shake), 0.55)
	_shield_dmg(shield_max)


## Vol, ailes qui battent (grandes et vite en vol, tombantes à terre), cercle-guide quand il est posé.
func _animate() -> void:
	if _state != "dying":
		body.position.y = _fly
	var flying := _state == "soar" or _state == "dive" or _state == "rush"
	var amp := 0.6 if flying else 0.12
	var rate := 12.0 if flying else 2.5
	var flap := 0.25 + sin(_t * rate) * amp
	if _state == "torn" or _state == "dying":
		flap = -0.55 + sin(_t * 1.5) * 0.05
	ch.flap = flap
	_hint.visible = _state == "perch" or _state == "volley"
	_hint.rotation.y = _t * 0.4
	if _state == "torn":
		body.rotation.z = sin(_t * 12.0) * 0.06
	elif _state != "dying":
		body.rotation.z = 0.0
	if _state != "spawn" and _state != "dying":
		body.scale = Vector3.ONE * (1.08 if _flash > 0.0 else 1.0)


# ------------------------------------------------------------------ robot testeur

## Posé : placement sur le cercle-guide, puis boucle de 400° autour de lui (le manteau tombe) ;
## à terre (vulnérable) : iaï à travers, encore et encore.
func bot_stroke(hero_pos: Vector3) -> PackedVector3Array:
	var none := PackedVector3Array()
	if dead:
		return none
	var h := Vector3(hero_pos.x, 0, hero_pos.z)
	var c := Vector3(position.x, 0, position.z)
	if _state == "torn":
		if vulnerable_t < 0.3:
			return none
		return _bot_line(h, c, 7.3)
	if _state != "perch" and _state != "volley":
		return none
	return _bot_loop(h, c, HINT_R)


## Boucle autour de c (rayon r) : d'abord se placer sur le cercle, puis 400° d'un seul trait.
func _bot_loop(h: Vector3, c: Vector3, r: float) -> PackedVector3Array:
	var off := h - c
	var d := off.length()
	var phi := atan2(off.z, off.x) if d > 0.05 else PI * 0.5
	if d < r - 0.6 or d > r + 0.6:
		for k in [0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6]:
			var th := phi + deg_to_rad(30.0) * float(k)
			var q := c + Vector3(cos(th), 0, sin(th)) * r
			if _bot_inside(q, 0.25):
				return _bot_dense([h, q])
		return PackedVector3Array()
	var way: Array = [h]
	for i in range(0, 41):
		var th2 := phi + deg_to_rad(400.0) * float(i) / 40.0
		way.append(c + Vector3(cos(th2), 0, sin(th2)) * r)
	return _bot_dense(way)
