extends "res://scripts/boss_mini_base.gd"
## Mini-boss du monde 2 (Tanabata) — Tsuchigumo, l'araignée des terriers (24 PV × monde).
##  Enfermée dans un cocon de soie : la lame ricoche (×0). Une BOUCLE fermée tracée autour d'elle
##  (Uzu, Ensō, ou fin de trait revenue près d'un point du trait) déchire le cocon : 5 dmg,
##  renversée 3 s (vulnérable aux coupes). Un cercle or au sol montre où tourner.
##  Prépare l'Ensō de Kyūbi (boucle autour des queues).
##  Attaques : salve de soie en éventail (lueur 0.8 s) ; bond sur le héros (zone r1.8, 1.1 s).

const MINION = preload("res://assets/kaykit/Skeleton_Minion.glb")
const SILK := Color("#F1EEE6")
const SHELL := Color("#3A2F28")
const LEG := Color("#2A221D")
const BODY_SCALE := 1.1
const HINT_R := 2.1  # cercle-guide au sol (rayon conseillé de la boucle)
const LOOP_PTS := 120  # points mémorisés pour la boucle (_find_loop est quadratique)
const TEAR_DMG := 5.0
const TORN_TIME := 3.0
const LEAP_R := 1.8
const LEAP_TELE := 1.1
const VOLLEY_TELE := 0.8

var _legs: Array = []  # [pivot, phase]
var _cocoon: Node3D
var _hint: Node3D
var _pts: Array = []  # Vector2 de la ruée depuis le dernier end_stroke
var _cycle := 0
var _leap_from := Vector3.ZERO
var _leap_to := Vector3.ZERO
var _death_played := false


func _ready() -> void:
	title = "Tsuchigumo"
	hp = 24.0 * max_hp_mult
	max_hp = hp
	radius = 1.1
	_build()
	_state = "spawn"
	_timer = 1.2


# ------------------------------------------------------------------ construction

func _build() -> void:
	Toon.disc(self, 1.4, Color(0, 0, 0, 0.16))
	body = Node3D.new()
	add_child(body)
	var shell := Toon.mat(SHELL)
	var gold := Toon.mat(Toon.GOLD)
	var leg_mat := Toon.mat(LEG)
	# abdomen rayé or (le « tigre » des terriers)
	var ab := Node3D.new()
	body.add_child(ab)
	ab.position = Vector3(0, 1.0, 0.85)
	ab.scale = Vector3(1.0, 0.85, 1.2)
	Toon.part(ab, Toon.sphere(0.85), shell, Vector3.ZERO)
	for dz in [-0.35, 0.05, 0.45]:
		var rr := sqrt(0.85 * 0.85 - float(dz) * float(dz)) + 0.015
		var band := Toon.part(ab, Toon.cyl(rr, rr, 0.09, 16), gold, Vector3(0, 0, float(dz)))
		band.rotation.x = PI * 0.5
	# céphalothorax
	Toon.part(body, Toon.sphere(0.55), shell, Vector3(0, 0.85, -0.3), Vector3(1.0, 0.8, 1.1))
	# huit pattes coudées, articulations or
	for side in [-1.0, 1.0]:
		for i in 4:
			var a := 0.75 - 0.5 * float(i)
			var pv := Node3D.new()
			body.add_child(pv)
			pv.position = Vector3(float(side) * 0.35, 0.85, -0.45 + 0.28 * float(i))
			pv.rotation.y = a if float(side) > 0.0 else PI - a
			_limb(pv, Vector3.ZERO, Vector3(0.85, 0.6, 0), 0.08, leg_mat)
			_limb(pv, Vector3(0.85, 0.6, 0), Vector3(1.45, -0.85, 0), 0.065, leg_mat)
			Toon.part(pv, Toon.sphere(0.1), gold, Vector3(0.85, 0.6, 0))
			_legs.append([pv, float(i) * 1.3 + (0.0 if float(side) > 0.0 else 0.65)])
	# le buste d'os-soldat qui sort de la tête (Tsuchigumo à visage d'oni)
	ch = Character.new()
	body.add_child(ch)
	ch.position = Vector3(0, 1.05, -0.45)
	var tex: Texture2D = load("res://assets/kaykit/tex/skeleton_ink.png")
	ch.setup(MINION, 1.35, [["Cloak", tex]], ["Skeleton_Minion_LegLeft", "Skeleton_Minion_LegRight"], Toon.GOLD)
	ch.idle = "Idle_Combat"
	ch.play("Idle_Combat")
	# cocon de soie : coque translucide et fils enroulés
	_cocoon = Node3D.new()
	body.add_child(_cocoon)
	_cocoon.position = Vector3(0, 1.0, 0.2)
	var shape := Vector3(1.15, 0.95, 1.4)
	Toon.part(_cocoon, Toon.sphere(1.0), Toon.flat(Color(SILK, 0.38)), Vector3.ZERO, shape)
	for k in 4:
		var tm := TorusMesh.new()
		tm.inner_radius = 1.0
		tm.outer_radius = 1.06
		tm.rings = 24
		tm.ring_segments = 6
		var th := Toon.part(_cocoon, tm, Toon.flat(Color(SILK, 0.85)), Vector3.ZERO, shape)
		th.rotation = Vector3(0.45 * float(k) + 0.2, 0.8 * float(k), 0.35)
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


# ------------------------------------------------------------------ interface avec main

func check_dash(a: Vector3, b: Vector3, stroke_id: int) -> bool:
	if dead:
		return false
	if hero.dashing and _wrapped():
		_record(a, b)
	if _state == "torn":
		if _last_stroke != stroke_id and _seg_dist(position, a, b) < radius + 0.55:
			_last_stroke = stroke_id
			return true
		return false
	if _state == "spawn" or _state == "leap":
		return false
	# cocon : la lame ricoche (une fois par trait)
	if _clanged != stroke_id and _seg_dist(position, a, b) < radius + 0.5:
		_clanged = stroke_id
		main.clang(position + Vector3(0, 1.0, 0))
		main.float_text(position, "×0", Toon.FOAM)
	return false


## Fin du trait : une boucle fermée qui entoure l'araignée déchire le cocon.
func end_stroke(_stroke_id: int) -> void:
	if not dead and not _pts.is_empty():
		# la dernière image de la ruée n'est pas forcément passée par check_dash
		var pa: Vector3 = main._prev_hero
		_record(pa, hero.position)
	var pts: Array = _pts
	_pts = []
	if dead or pts.size() < 6 or not (_state == "idle" or _state == "volley"):
		return
	var loop := _find_loop(pts, Vector2(position.x, position.z))
	if loop.size() < 3:
		return
	_tear()


func _aoe_target(center: Vector3, reach: float) -> Vector3:
	if _state != "torn":
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
	ch.set_glow(0.0)


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
					ch.play_once("Throw", ch.length("Throw") * 0.5 / VOLLEY_TELE)
		"volley":
			_face(dir, delta, 3.0)
			_timer -= delta
			if _flash <= 0.0:
				ch.set_glow(0.55 * clampf(1.0 - _timer / VOLLEY_TELE, 0.0, 1.0), Toon.VERMILION)
			if _timer <= 0.0:
				ch.set_glow(0.0)
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
			_stun -= delta
			if _stun <= 0.0:
				_stun = 0.0
				_state = "rewrap"
				_timer = 0.6
				_cocoon.visible = true
				_cocoon.scale = Vector3.ONE * 0.05
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
				ch.hold()
				ch.play_once("Death_C_Skeletons", 1.2, 0.05)
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
	ch.play_once("Jump_Full_Short", ch.length("Jump_Full_Short") / LEAP_TELE)


func _wrapped() -> bool:
	return _state == "idle" or _state == "volley" or _state == "rewrap"


func _tear() -> void:
	var d := TEAR_DMG * max_hp_mult
	ch.set_glow(0.0)
	_state = "torn"
	_stun = TORN_TIME
	_cocoon.visible = false
	main.float_text(position + Vector3(0, 0.6, 0), "円 " + str(roundi(d)), Toon.GOLD)
	main.big_hit(position + Vector3(0, 0.8, 0))
	main.splash(position + Vector3(0, 1.2, 0), SILK, 26)
	main.shake = maxf(float(main.shake), 0.4)
	ch.play_once("Hit_A", 1.2)
	_damage(d)


## Pattes qui pianotent, corps qui respire ; cocon et cercle-guide selon l'état.
func _animate(_delta: float) -> void:
	var fast := _state == "torn" or _state == "leap"
	for l in _legs:
		var pv: Node3D = l[0]
		var ph := float(l[1])
		if _state == "dying":
			pv.rotation.z = lerpf(pv.rotation.z, 0.9, 0.05)
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
			var ar := _area(poly)
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
		var ar2 := _area(poly2)
		if ar2 > best_area and Geometry2D.is_point_in_polygon(c, poly2):
			best = poly2
			best_area = ar2
	return best


func _area(poly: PackedVector2Array) -> float:
	var s := 0.0
	var m := poly.size()
	for i in m:
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % m]
		s += p.x * q.y - q.x * p.y
	return absf(s) * 0.5


# ------------------------------------------------------------------ robot testeur

## Cocon : placement sur le cercle-guide, puis boucle de 400° autour d'elle ; renversée : iaï à travers.
func bot_stroke(hero_pos: Vector3) -> PackedVector3Array:
	var none := PackedVector3Array()
	if dead:
		return none
	var h := Vector3(hero_pos.x, 0, hero_pos.z)
	var c := Vector3(position.x, 0, position.z)
	if _state == "torn":
		if _stun < 0.3:
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
