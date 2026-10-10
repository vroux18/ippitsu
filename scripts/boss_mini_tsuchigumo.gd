extends "res://scripts/boss_mini_base.gd"
## Mini-boss du monde 2 (Tanabata) — Tsuchigumo, l'araignée des terriers (26 PV × monde).
##  Le cocon de soie est son bouclier (10) : un coup ne fait qu'effleurer. Une BOUCLE fermée tracée
##  autour d'elle (Uzu, Ensō, ou fin de trait revenue près d'un point du trait) déchire tout le cocon :
##  renversée 5.5 s, vulnérable (dégâts ×2). Un cercle or au sol montre où tourner.
##  Prépare l'Ensō de Kyūbi (boucle autour des queues).
##  Attaques : salve de soie en éventail (lueur 0.8 s) ; bond sur le héros (zone r1.8, 1.1 s).

const UiKit = preload("res://scripts/ui_kit.gd")
const Yokai = preload("res://scripts/yokai_parts.gd")
const SILK := Color("#F1EEE6")
# apparence « Masque d'encre » (règles en tête de yokai_ink_w1.gd ; famille du monde 2 : yokai_ink_w2.gd)
const INK := Color("#241C16")  # encre chaude des bêtes du monde 2
const CLOTH := Color("#2E3B4E")  # étoffe de la nuit de Tanabata
const WAVE := Color("#F1E3A6")  # or pâle du feu de renard (écailles)
const MASK_EARTH := Color("#C4996A")  # hannya de terre cuite
const EMBER := Color("#6E2A24")  # braise sombre (traits du masque)
const BODY_SCALE := 1.1
const HINT_R := 2.1  # cercle-guide au sol (rayon conseillé de la boucle)
const LOOP_PTS := 120  # points mémorisés pour la boucle (_find_loop est quadratique)
const SHIELD := 10.0
const LEAP_R := 1.8
const LEAP_TELE := 1.1
const VOLLEY_TELE := 0.8

var _legs: Array = []  # [pivot, phase]
var _cocoon: Node3D
var _mat: StandardMaterial3D  # toon à couleurs de sommets, propre au gardien (éclat des coups, lueur d'annonce)
var _head: Node3D  # masque hannya et cou d'encre (il se cabre pour la salve, pend quand elle est renversée)
var _glow := 0.0  # lueur vermillon d'annonce (salve)
var _hint: Node3D
var _pts: Array = []  # Vector2 de la ruée depuis le dernier end_stroke
var _cycle := 0
var _leap_from := Vector3.ZERO
var _leap_to := Vector3.ZERO
var _death_played := false


func _ready() -> void:
	title = "Tsuchigumo"
	hp = 26.0 * max_hp_mult
	max_hp = hp
	radius = 1.1
	_build()
	_shield_init(SHIELD, Vector3(1.7, 1.3, 1.9), 1.0)
	# elle apparaît déjà tournée vers le héros : l'entrée en scène montre le masque, pas l'abdomen
	if hero != null:
		_face(_dir_to_hero(), 1.0, 1.0)
	_state = "spawn"
	_timer = 1.2


# ------------------------------------------------------------------ construction

## Tsuchigumo : araignée d'encre — abdomen d'encre ceint de l'étoffe de la nuit à écailles d'or pâle et
## liserés d'or, céphalothorax à huit yeux d'or, huit pattes d'encre aux articulations d'or et griffes d'or ;
## au-dessus, sur un cou d'encre, le masque de nō « hannya » de terre cuite cerné d'or (cornes d'or, yeux
## d'or, rictus à crocs), crinière d'encre qui coule en arrière. Les pivots des pattes, le cocon (bouclier)
## et le cercle-guide gardent leurs places. Matériaux : toon propre (éclat, lueur), aplat partagé, cocon, guide.
func _build() -> void:
	var lite := Toon.lite
	Toon.disc(self, 1.4, Color(0, 0, 0, 0.16))
	body = Node3D.new()
	add_child(body)
	_mat = Toon.mat(Color.WHITE, true, 0.03)
	_mat.vertex_color_use_as_albedo = true
	_mat.vertex_color_is_srgb = true
	_mat.rim = 0.35
	_mat.rim_tint = 0.5
	_mat.emission_enabled = true
	_mat.emission = Color.WHITE
	_mat.emission_energy_multiplier = 0.0
	var b := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	# abdomen : boule d'encre (même place et même volume qu'avant), large bande d'étoffe à écailles,
	# liserés d'or, deux anneaux d'or ; gouttes qui pendent à l'arrière
	var ac := Vector3(0, 1.0, 0.85)
	var ar := Vector3(0.85, 0.72, 1.02)
	b.ball(ac, ar, INK, Vector3.ZERO, 12)
	b.cyl(ac + Vector3(0, 0, 0.05), Vector3(0.87, 0.5, 0.74), CLOTH, Vector3(PI / 2.0, 0, 0), 1.0, 14)
	for dz in [-0.2, 0.3]:
		b.cyl(ac + Vector3(0, 0, float(dz)), Vector3(0.885, 0.05, 0.755), Toon.GOLD, Vector3(PI / 2.0, 0, 0), 1.0, 14)
	b.cyl(ac + Vector3(0, 0, -0.5), Vector3(0.74, 0.1, 0.63), Toon.GOLD, Vector3(PI / 2.0, 0, 0), 1.0, 14)
	b.cyl(ac + Vector3(0, 0, 0.62), Vector3(0.68, 0.1, 0.58), Toon.GOLD, Vector3(PI / 2.0, 0, 0), 1.0, 14)
	var n := 7 if lite else 11
	for i in n:
		var ang := -2.0 + 4.0 * float(i) / float(n - 1)
		var at := ac + Vector3(sin(ang) * 0.87, cos(ang) * 0.74, 0.05)
		b.ball(at, Vector3(0.11, 0.025, 0.09), WAVE, Vector3(0, 0, -ang), 6)
		if not lite:
			var ang2 := ang + 2.0 / float(n - 1)
			var at2 := ac + Vector3(sin(ang2) * 0.87, cos(ang2) * 0.74, 0.22)
			b.ball(at2, Vector3(0.1, 0.025, 0.08), WAVE, Vector3(0, 0, -ang2), 6)
	var drops: Array = [Vector3(0.3, 0.45, 1.4), Vector3(-0.35, 0.5, 1.2)]
	if not lite:
		drops.append(Vector3(0.05, 0.4, 1.75))
	for q in drops:
		var dp: Vector3 = q
		var tip := b.spike(dp, 0.09, 0.4, INK, Vector3(PI, 0, -signf(dp.x) * 0.25), 0.3, 5)
		b.ball(tip, Vector3(0.06, 0.07, 0.06), INK, Vector3.ZERO, 6)
	# céphalothorax : encre, rangée de huit yeux d'or sur le devant (ils regardent le ciel)
	var cc := Vector3(0, 0.85, -0.3)
	b.ball(cc, Vector3(0.55, 0.44, 0.6), INK, Vector3.ZERO, 10)
	var eyes: Array = [Vector3(-0.3, 0.28, -0.42), Vector3(0.3, 0.28, -0.42), Vector3(-0.12, 0.38, -0.4), Vector3(0.12, 0.38, -0.4)]
	if not lite:
		eyes.append_array([Vector3(-0.42, 0.16, -0.38), Vector3(0.42, 0.16, -0.38), Vector3(-0.2, 0.2, -0.54), Vector3(0.2, 0.2, -0.54)])
	for q in eyes:
		var e: Vector3 = q
		f.ball(cc + e, Vector3(0.075, 0.06, 0.075), Yokai.EYE_GOLD, Vector3(-0.6, 0, 0), 6)
		f.ball(cc + e + Vector3(0, 0.03, -0.03), Vector3(0.03, 0.035, 0.03), Toon.SUMI, Vector3(-0.6, 0, 0), 6)
	_part(body, Yokai.two(b, f), Vector3.ZERO)
	# tête : cou d'encre, masque hannya relevé vers la caméra, crinière d'encre
	_head = Node3D.new()
	_head.position = Vector3(0, 1.2, -0.45)
	body.add_child(_head)
	var h := Yokai.Mesher.new(1.0)
	var hf := Yokai.Mesher.new(1.0)
	h.cyl(Vector3(0, 0.3, 0), Vector3(0.3, 0.7, 0.3), INK, Vector3.ZERO, 0.8, 8)
	h.ball(Vector3(0, 0.62, 0.1), Vector3(0.36, 0.3, 0.36), INK, Vector3.ZERO, 10)
	var mrot := Vector3(0.75, 0, 0)  # relevé vers le ciel (face -Z tournée vers le haut et l'avant) : la caméra plonge
	var mb := Basis.from_euler(mrot)
	var mc := Vector3(0, 0.8, -0.28)
	h.ball(mc, Vector3(0.5, 0.56, 0.11), MASK_EARTH, mrot, 10)
	h.ball(mc + mb * Vector3(0, 0, 0.045), Vector3(0.55, 0.61, 0.08), Toon.GOLD, mrot, 10)
	var fz := -0.095
	for sx in [-1.0, 1.0]:
		var x := float(sx)
		# sourcils de braise froncés, yeux d'or ronds, pommettes
		h.box(mc + mb * Vector3(x * 0.2, 0.27, fz), Vector3(0.25, 0.06, 0.02), EMBER, Vector3(0.75, 0, x * 0.45))
		hf.ball(mc + mb * Vector3(x * 0.19, 0.12, fz), Vector3(0.105, 0.085, 0.015), Yokai.EYE_GOLD, mrot, 8)
		hf.ball(mc + mb * Vector3(x * 0.19, 0.12, fz - 0.012), Vector3(0.04, 0.05, 0.01), Toon.SUMI, mrot, 6)
		if not lite:
			h.box(mc + mb * Vector3(x * 0.34, -0.05, fz), Vector3(0.035, 0.18, 0.015), EMBER, Vector3(0.75, 0, x * 0.2))
		# cornes d'or de la hannya : courbées vers le haut et l'arrière
		h.spike(mc + mb * Vector3(x * 0.24, 0.5, 0.02), 0.08, 0.48, Toon.GOLD, Vector3(0.35, 0, -x * 0.45), 0.0, 5)
		# crocs d'or aux coins du rictus
		h.spike(mc + mb * Vector3(x * 0.21, -0.24, fz), 0.035, 0.14, Toon.GOLD, Vector3(PI + 0.6, 0, 0), 0.0, 4)
	# rictus : trait sumi et bouche de braise (son souffle de soie part d'ici)
	h.box(mc + mb * Vector3(0, -0.27, fz), Vector3(0.5, 0.08, 0.02), EMBER, mrot)
	h.box(mc + mb * Vector3(0, -0.27, fz - 0.008), Vector3(0.5, 0.022, 0.012), Toon.SUMI, mrot)
	# crinière d'encre qui coule en arrière du masque
	var mane := 3 if lite else 5
	for i in mane:
		var x := (float(i) - 0.5 * float(mane - 1)) * 0.17
		h.spike(Vector3(x, 1.0 - absf(x) * 0.4, 0.15), 0.08, 0.5 - absf(x) * 0.5, INK, Vector3(-1.3, 0, x * 1.2), 0.0, 5)
	_part(_head, Yokai.two(h, hf), Vector3.ZERO)
	# huit pattes d'encre coudées (mêmes pivots qu'avant), articulation et griffe d'or
	var lm := Yokai.Mesher.new(1.0)
	var knee := Vector3(0.85, 0.6, 0)
	var foot := Vector3(1.45, -0.85, 0)
	lm.ray(Vector3.ZERO, knee, 0.085, knee.length(), INK, 0.8, 6)
	lm.ray(knee, foot - knee, 0.07, (foot - knee).length() - 0.12, INK, 0.75, 6)
	lm.ball(knee, Vector3.ONE * 0.1, Toon.GOLD, Vector3.ZERO, 6)
	lm.ball(Vector3.ZERO, Vector3(0.1, 0.09, 0.1), INK, Vector3.ZERO, 6)
	lm.ray(foot - (foot - knee).normalized() * 0.14, foot - knee, 0.06, 0.2, Toon.GOLD, 0.0, 5)
	var leg_mesh := lm.mesh()
	for side in [-1.0, 1.0]:
		for i in 4:
			var a := 0.75 - 0.5 * float(i)
			var pv := Node3D.new()
			body.add_child(pv)
			pv.position = Vector3(float(side) * 0.35, 0.85, -0.45 + 0.28 * float(i))
			pv.rotation.y = a if float(side) > 0.0 else PI - a
			_part(pv, leg_mesh, Vector3.ZERO)
			_legs.append([pv, float(i) * 1.3 + (0.0 if float(side) > 0.0 else 0.65)])
	# cocon de soie : coque translucide et fils enroulés (quatre boucles de brins fusionnées en un maillage :
	# le TorusMesh fin rendait par instants un cône géant d'encre en jeu)
	_cocoon = Node3D.new()
	body.add_child(_cocoon)
	_cocoon.position = Vector3(0, 1.0, 0.2)
	var shape := Vector3(1.15, 0.95, 1.4)
	Toon.part(_cocoon, Toon.sphere(1.0), Toon.flat(Color(SILK, 0.38)), Vector3.ZERO, shape)
	var silk := Yokai.Mesher.new(1.0)
	var segs := 16 if lite else 24
	for k in 4:
		var rb := Basis.from_euler(Vector3(0.45 * float(k) + 0.2, 0.8 * float(k), 0.35))
		var prev := Vector3.ZERO
		for i in segs + 1:
			var t := TAU * float(i) / float(segs)
			var q := shape * (rb * Vector3(cos(t) * 1.03, sin(t) * 1.03, 0))
			if i > 0:
				silk.ray(prev, q - prev, 0.032, (q - prev).length() + 0.02, SILK, 1.0, 4)
			prev = q
	var thread := MeshInstance3D.new()
	thread.mesh = silk.mesh()
	thread.material_override = Toon.flat(Color(SILK, 0.85))
	thread.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cocoon.add_child(thread)
	# cercle-guide or : « trace ta boucle ici »
	_hint = Node3D.new()
	add_child(_hint)
	var ring := TorusMesh.new()
	ring.inner_radius = HINT_R - 0.06
	ring.outer_radius = HINT_R + 0.06
	ring.rings = 48
	ring.ring_segments = 4
	var rm := Toon.part(_hint, ring, Toon.flat(Color(Toon.GOLD, 0.5)), Vector3(0, 0.03, 0), Vector3(1, 0.05, 1))
	rm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_make_stars(body, 2.6)
	body.scale = Vector3.ONE * 0.01


## Pièce d'encre : surface 0 = toon du gardien, surface 1 (s'il y en a une) = aplat lumineux.
func _part(parent: Node3D, m: Mesh, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.set_surface_override_material(0, _mat)
	if m.get_surface_count() > 1:
		mi.set_surface_override_material(1, Yokai.ink_flat_mat())
	if Toon.lite:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


# ------------------------------------------------------------------ interface avec main

func check_dash(a: Vector3, b: Vector3, stroke_id: int) -> bool:
	if dead:
		return false
	if hero.dashing and _wrapped():
		_record(a, b)
	if _state == "spawn" or _state == "leap" or _state == "dying":
		return false
	# renversée : coup plein (×2) ; dans le cocon : il effleure et use la soie
	if _last_stroke != stroke_id and _seg_dist(position, a, b) < radius + 0.55:
		_last_stroke = stroke_id
		return true
	return false


## Fin du trait : une boucle fermée qui entoure l'araignée déchire le cocon.
func end_stroke(_stroke_id: int) -> void:
	if not dead and not _pts.is_empty():
		# la dernière image de la ruée n'est pas forcément passée par check_dash
		var pa: Vector3 = main._prev_hero
		_record(pa, hero.position)
	var pts: Array = _pts
	_pts = []
	if dead or pts.size() < 6 or vulnerable_t > 0.0 or not (_state == "idle" or _state == "volley"):
		return
	var loop := _find_loop(pts, Vector2(position.x, position.z))
	if loop.size() < 3:
		return
	_tear()


func _aoe_target(center: Vector3, reach: float) -> Vector3:
	if _state == "spawn" or _state == "leap" or _state == "dying":
		return Vector3.INF
	if Vector2(position.x - center.x, position.z - center.z).length() >= reach + radius:
		return Vector3.INF
	return position + Vector3(0, 1.0, 0)


func _zone_fire(z: Dictionary) -> void:
	if String(z["tag"]) != "leap":
		return
	# atterrissage du bond
	var c: Vector3 = z["c"]
	position = Vector3(c.x, 0, c.z)
	main.clamp_to_arena(self, radius)
	body.position.y = 0.0
	main.enemy_strike(c, LEAP_R)
	main.splash(c + Vector3(0, 0.3, 0), SILK, 14)
	_state = "idle"
	_timer = 2.2 if hp > max_hp * 0.5 else 1.8


func _on_die() -> void:
	_cocoon.visible = false
	_hint.visible = false
	body.position.y = 0.0
	_glow = 0.0


## Cocon déchiré : renversée, plus d'attaque jusqu'à la fin de la fenêtre.
func _on_shield_break() -> void:
	_clear_zones()
	_glow = 0.0
	_state = "torn"
	_cocoon.visible = false
	body.position.y = 0.0


func _on_shield_back() -> void:
	if _state != "torn":
		return
	_state = "rewrap"
	_timer = 0.6
	_cocoon.visible = true
	_cocoon.scale = Vector3.ONE * 0.05


# ------------------------------------------------------------------ boucle

func _step(delta: float) -> void:
	var dir := _dir_to_hero()
	match _state:
		"spawn":
			_timer -= delta
			body.scale = Vector3.ONE * BODY_SCALE * clampf(1.0 - _timer / 1.2, 0.01, 1.0)
			if _timer <= 0.0:
				body.scale = Vector3.ONE * BODY_SCALE
				_state = "idle"
				_timer = 1.4
		"idle":
			_face(dir, delta, 3.0)
			_timer -= delta
			if _timer <= 0.0:
				_cycle += 1
				if _cycle % 2 == 0:
					_start_leap()
				else:
					_state = "volley"
					_timer = VOLLEY_TELE
		"volley":
			_face(dir, delta, 3.0)
			_timer -= delta
			_glow = 0.55 * clampf(1.0 - _timer / VOLLEY_TELE, 0.0, 1.0)
			if _timer <= 0.0:
				_glow = 0.0
				# boules de soie en éventail (plus nombreuses quand elle faiblit)
				var n := 5 if hp > max_hp * 0.5 else 7
				var spread := deg_to_rad(60.0 if n == 5 else 84.0)
				for i in n:
					var ang := -spread * 0.5 + spread * float(i) / float(n - 1)
					var d := dir.rotated(Vector3.UP, ang)
					main.spawn_bullet(position + Vector3(0, 1.3, 0) + d * 1.4, d)
				_state = "idle"
				_timer = 2.4 if hp > max_hp * 0.5 else 2.0
		"leap":
			# accroupie, puis vol en cloche jusqu'à la zone (l'atterrissage est dans _zone_fire)
			_timer -= delta
			var k := clampf(1.0 - _timer / LEAP_TELE, 0.0, 1.0)
			var fly := clampf((k - 0.3) / 0.7, 0.0, 1.0)
			var p := _leap_from.lerp(_leap_to, fly)
			position = Vector3(p.x, 0, p.z)
			if fly <= 0.0:
				body.position.y = -0.25 * clampf(k / 0.3, 0.0, 1.0)
			else:
				body.position.y = sin(PI * fly) * 3.0
			_face(_leap_to - _leap_from, delta, 6.0)
		"torn":
			# renversée : la fin de la fenêtre (vulnerable_t) la remet sur pattes (_on_shield_back)
			pass
		"rewrap":
			_timer -= delta
			_cocoon.scale = Vector3.ONE * clampf(1.0 - _timer / 0.6, 0.05, 1.0)
			if _timer <= 0.0:
				_cocoon.scale = Vector3.ONE
				_state = "idle"
				_timer = 1.2
		"dying":
			_timer += delta
			if not _death_played:
				_death_played = true
				_glow = 0.0
			body.rotation.z = minf(_timer * 2.0, 1.0) * 0.5
			if _timer > 1.2:
				body.position.y -= delta * 1.5
			if _timer > 2.2:
				queue_free()
	_animate(delta)


func _start_leap() -> void:
	_leap_from = Vector3(position.x, 0, position.z)
	var tgt: Vector3 = main.arena.clamp_walk(Vector3(hero.position.x, 0, hero.position.z), radius)
	_leap_to = Vector3(tgt.x, 0, tgt.z)
	_zone_disc(_leap_to, LEAP_R, LEAP_TELE, "leap")
	_state = "leap"
	_timer = LEAP_TELE


func _wrapped() -> bool:
	return _state == "idle" or _state == "volley" or _state == "rewrap"


## La boucle déchire tout le cocon : le bouclier tombe d'un coup.
func _tear() -> void:
	main.float_icon(position + Vector3(0, 1.4, 0), "figures/enso", Toon.GOLD)
	main.big_hit(position + Vector3(0, 0.8, 0))
	main.splash(position + Vector3(0, 1.2, 0), SILK, 26)
	main.shake = maxf(float(main.shake), 0.55)
	_shield_dmg(shield_max)


## Pattes qui pianotent, corps qui respire, masque qui se cabre (salve) ou pend (renversée) ; éclat des
## coups et lueur d'annonce sur l'encre ; cocon et cercle-guide selon l'état.
func _animate(delta: float) -> void:
	var fast := _state == "torn" or _state == "leap"
	if _flash > 0.0:
		_mat.emission = Color.WHITE
		_mat.emission_energy_multiplier = 1.0
	else:
		_mat.emission = Toon.VERMILION
		_mat.emission_energy_multiplier = _glow
	var head_x := 0.0
	if _state == "volley":
		head_x = -0.45 * clampf(1.0 - _timer / VOLLEY_TELE, 0.0, 1.0)
	elif _state == "torn" or _state == "dying":
		head_x = 0.7
	elif _state == "leap":
		head_x = -0.3
	_head.rotation.x = lerpf(_head.rotation.x, head_x + sin(_t * 1.8) * 0.04, minf(1.0, delta * 8.0))
	for l in _legs:
		var pv: Node3D = l[0]
		var ph := float(l[1])
		if _state == "dying":
			pv.rotation.z = lerpf(pv.rotation.z, 0.9, minf(1.0, delta * 3.0))
		elif fast:
			pv.rotation.z = sin(_t * 16.0 + ph) * 0.3
		else:
			pv.rotation.z = sin(_t * 3.0 + ph) * 0.07
	if _state == "idle" or _state == "volley" or _state == "rewrap":
		body.position.y = sin(_t * 2.2) * 0.04
	elif _state == "torn":
		body.position.y = -0.15
		body.rotation.z = sin(_t * 12.0) * 0.06
	if _state != "torn" and _state != "dying":
		body.rotation.z = 0.0
	_hint.visible = _state == "idle" or _state == "volley"
	_hint.rotation.y = _t * 0.4
	var sc := 1.08 if _flash > 0.0 else 1.0
	if _state != "spawn" and _state != "dying":
		body.scale = Vector3.ONE * BODY_SCALE * sc


# ------------------------------------------------------------------ boucle tracée

func _record(a: Vector3, b: Vector3) -> void:
	if _pts.is_empty():
		_pts.append(Vector2(a.x, a.z))
	var last: Vector2 = _pts[_pts.size() - 1]
	var bb := Vector2(b.x, b.z)
	if last.distance_to(bb) >= 0.3 and _pts.size() < LOOP_PTS:
		_pts.append(bb)


## Plus grande boucle fermée du tracé qui contient c (auto-croisement, ou extrémité revenue à ≤ 1.4 m).
func _find_loop(pts: Array, c: Vector2) -> PackedVector2Array:
	var best := PackedVector2Array()
	var best_area := 0.0
	var n := pts.size()
	# 1) boucles par auto-croisement
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
				poly.append(pts[k])
			var ar := UiKit.poly_area(poly)
			if poly.size() >= 3 and ar > best_area and Geometry2D.is_point_in_polygon(c, poly):
				best = poly
				best_area = ar
	# 2) boucle presque fermée : la fin revient près d'un point antérieur
	var last: Vector2 = pts[n - 1]
	for i in range(0, n - 8):
		var q: Vector2 = pts[i]
		if q.distance_to(last) > 1.4:
			continue
		var poly2 := PackedVector2Array()
		for k in range(i, n):
			poly2.append(pts[k])
		var ar2 := UiKit.poly_area(poly2)
		if ar2 > best_area and Geometry2D.is_point_in_polygon(c, poly2):
			best = poly2
			best_area = ar2
	return best


# ------------------------------------------------------------------ robot testeur

## Cocon : placement sur le cercle-guide, puis boucle de 400° autour d'elle (le bouclier tombe) ;
## renversée (vulnérable) : iaï à travers, encore et encore.
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
	if _state != "idle" and _state != "volley":
		return none
	var off := h - c
	var d := off.length()
	var phi := atan2(off.z, off.x) if d > 0.05 else PI * 0.5
	if d < HINT_R - 0.6 or d > HINT_R + 0.6:
		# point du cercle le plus proche du héros qui reste dans l'arène
		for k in [0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6]:
			var th := phi + deg_to_rad(30.0) * float(k)
			var q := c + Vector3(cos(th), 0, sin(th)) * HINT_R
			if _bot_inside(q, 0.25):
				return _bot_dense([h, q])
		return none
	var way: Array = [h]
	for i in range(0, 41):
		var th2 := phi + deg_to_rad(400.0) * float(i) / 40.0
		way.append(c + Vector3(cos(th2), 0, sin(th2)) * HINT_R)
	return _bot_dense(way)
