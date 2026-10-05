extends Node3D
## Boss du monde 1 (design/UNIVERS.md) :
##  okappa  — Ō-Kappa, mini-boss (18 PV) : salves en éventail, plongeon sous le héros.
##            Tranché dans le dos, sa coupelle se renverse : dégâts ×3 et étourdi 3 s.
##  uwabami — Uwabami, serpent de mer (60 PV) : ne prend des dégâts que si on le tranche
##            dans sa longueur (au moins 4 segments d'un même trait).
## main appelle : check_dash(), take_hit(), end_stroke(), danger_zone(), touching_hero().

const Toon = preload("res://scripts/toon.gd")
const Character = preload("res://scripts/character.gd")
const MAGE = preload("res://assets/kaykit/Skeleton_Mage.glb")

const SEGMENTS := 12
const SPACING := 0.9
const SEG_R := 0.55
const HALF := Vector2(4.6, 8.6)  # demi-dimensions de l'arène (comme main.gd)

var kind := "okappa"
var main: Node
var hero: Node3D
var title := ""
var hp := 18.0
var max_hp := 18.0
var dead := false
var radius := 1.0

var _state := "spawn"
var _timer := 1.2
var _t := 0.0
var _flash := 0.0
var _stun := 0.0
var _last_stroke := -1
var _zone: Node3D
var _zone_fill: MeshInstance3D
var _zone_center := Vector3.ZERO
var _zone_r := 1.6
var _cycle := 0
var _summoned := false

# Ō-Kappa
var body: Node3D
var ch: Node3D

# Uwabami
var _segs: Array = []  # Node3D, la tête en premier
var _trail: Array = []  # positions passées de la tête (la plus récente en premier)
var _path: Array = []  # chemin prévu de la traversée
var _path_i := 0
var _hits := {}  # stroke_id -> {index: true}
var _marks: Node3D
var _depth := -1.6  # profondeur du corps (0 = en surface)
var _burst := 0
var _fired := 0


func setup(k: String, m: Node) -> void:
	kind = k
	main = m
	hero = m.hero


func _ready() -> void:
	if kind == "okappa":
		title = "Ō-Kappa"
		hp = 18.0
		radius = 1.0
		_build_okappa()
	else:
		title = "Uwabami"
		hp = 60.0
		radius = SEG_R
		_build_uwabami()
	max_hp = hp


# ------------------------------------------------------------------ construction

func _build_okappa() -> void:
	body = Node3D.new()
	add_child(body)
	ch = Character.new()
	body.add_child(ch)
	var tex: Texture2D = load("res://assets/kaykit/tex/skeleton_prussian.png")
	ch.setup(MAGE, 2.8, [["Hat", tex], ["Body", tex]], ["Skeleton_Mage_Hat"], Toon.GOLD)
	ch.idle = "Idle_Combat"
	# la coupelle d'eau sur le crâne : son point faible, visible de dos
	var bowl := Toon.part(body, Toon.cyl(0.42, 0.3, 0.12, 20), Toon.mat(Toon.GOLD), Vector3(0, 2.62, 0.05))
	bowl.name = "bowl"
	Toon.part(body, Toon.cyl(0.34, 0.34, 0.02, 20), Toon.mat(Color("#7FB2C8"), false), Vector3(0, 2.69, 0.05))
	Toon.disc(self, 1.0, Color(0, 0, 0, 0.14))
	body.scale = Vector3.ONE * 0.01
	ch.play_once("Spawn_Ground_Skeletons", ch.length("Spawn_Ground_Skeletons") / 1.2, 0.0)


func _build_uwabami() -> void:
	var skin := Toon.mat(Toon.PRUSSIAN)
	var belly := Toon.mat(Color("#C9D6DC"))
	var fin := Toon.mat(Toon.GOLD)
	var horn := Toon.mat(Toon.FOAM)
	for i in SEGMENTS:
		var s := Node3D.new()
		add_child(s)
		var k := 1.0 - 0.5 * float(i) / float(SEGMENTS - 1)
		if i == 0:
			# tête de dragon d'eau
			Toon.part(s, Toon.sphere(0.72), skin, Vector3(0, 0.55, 0), Vector3(1.0, 0.85, 1.15))
			Toon.part(s, Toon.box(Vector3(0.7, 0.4, 0.8)), skin, Vector3(0, 0.45, -0.75))
			Toon.part(s, Toon.box(Vector3(0.6, 0.12, 0.7)), belly, Vector3(0, 0.22, -0.7))
			for sx in [-1.0, 1.0]:
				var h := Toon.part(s, Toon.cyl(0.0, 0.1, 0.7, 8), horn, Vector3(sx * 0.35, 1.15, 0.15))
				h.rotation = Vector3(0.6, 0, sx * 0.35)
				Toon.part(s, Toon.sphere(0.12), Toon.mat(Toon.GOLD, false), Vector3(sx * 0.32, 0.78, -0.45))
				Toon.part(s, Toon.sphere(0.06), Toon.mat(Toon.SUMI, false), Vector3(sx * 0.34, 0.8, -0.55))
			var mane := Toon.part(s, Toon.cyl(0.0, 0.35, 0.8, 6), Toon.mat(Toon.VERMILION), Vector3(0, 1.0, 0.45))
			mane.rotation.x = -1.0
		else:
			Toon.part(s, Toon.sphere(SEG_R * k), skin, Vector3(0, 0.45 * k, 0), Vector3(1.0, 0.85, 1.25))
			Toon.part(s, Toon.sphere(SEG_R * k * 0.8), belly, Vector3(0, 0.25 * k, 0), Vector3(1.0, 0.5, 1.2))
			if i % 2 == 1:
				var f := Toon.part(s, Toon.cyl(0.0, 0.18 * k, 0.5 * k, 4), fin, Vector3(0, 0.95 * k, 0))
				f.rotation.x = -0.5
		s.position = Vector3(0, _depth, -HALF.y - 4.0 - i * SPACING)
		_segs.append(s)
	for i in SEGMENTS * 12:
		_trail.append(Vector3(0, 0, -HALF.y - 4.0 - i * SPACING / 12.0))
	_marks = Node3D.new()
	_marks.top_level = true
	add_child(_marks)
	_state = "dive"
	_timer = 0.5


# ------------------------------------------------------------------ interface avec main

func alive() -> bool:
	return not dead


## Vrai si la ruée a..b touche le boss pour la première fois de ce trait (dégâts gérés par main).
## Pour Uwabami, les segments touchés sont notés : les dégâts tombent à la fin du trait.
func check_dash(a: Vector3, b: Vector3, stroke_id: int) -> bool:
	if dead:
		return false
	if kind == "okappa":
		if _state in ["spawn", "sink", "hidden"] or _last_stroke == stroke_id:
			return false
		if _seg_dist(position, a, b) < radius + 0.55:
			_last_stroke = stroke_id
			return true
		return false
	if _depth < -0.4:
		return false
	var hit_set: Dictionary = _hits.get(stroke_id, {})
	for i in SEGMENTS:
		if hit_set.has(i):
			continue
		var s: Node3D = _segs[i]
		if _seg_dist(s.position, a, b) < SEG_R + 0.5:
			hit_set[i] = true
			main.small_hit(s.position)
	_hits[stroke_id] = hit_set
	return false


func take_hit(dmg: float, dir: Vector3) -> void:
	if dead:
		return
	var out := dmg
	if kind == "okappa":
		var ry := body.rotation.y
		var fwd := Vector3(-sin(ry), 0, -cos(ry))
		if dir.normalized().dot(fwd) > 0.4:
			# par-derrière : la coupelle se renverse
			out *= 3.0
			_stun = 3.0
			_cancel()
			_state = "stun"
			main.float_text(position + Vector3(0, 1.2, 0), "×3", Toon.GOLD)
			main.splash(position + Vector3(0, 2.2, 0), Color("#7FB2C8"), 20)
	_damage(out)


## Fin du trait : Uwabami encaisse selon la plus longue suite de segments tranchés.
func end_stroke(stroke_id: int) -> void:
	if kind != "uwabami" or dead or not _hits.has(stroke_id):
		_hits.erase(stroke_id)
		return
	var hit_set: Dictionary = _hits[stroke_id]
	_hits.erase(stroke_id)
	var best := 0
	var run := 0
	for i in SEGMENTS:
		if hit_set.has(i):
			run += 1
			best = maxi(best, run)
		else:
			run = 0
	if best == 0:
		return
	var dmg := 0.0
	if best >= SEGMENTS:
		dmg = 20.0
		_stun = 2.0
	elif best >= 8:
		dmg = 10.0
	elif best >= 4:
		dmg = float(best)
	var where: Node3D = _segs[0]
	if dmg <= 0.0:
		# coupé en travers : la lame ricoche sur les écailles
		main.float_text(where.position, "×0", Toon.FOAM)
		main.clang(where.position)
		return
	main.float_text(where.position + Vector3(0, 0.6, 0), str(int(dmg)), Toon.VERMILION)
	main.big_hit(where.position)
	_damage(dmg)


## Zone d'attaque en préparation : [centre, rayon, temps restant], ou [].
func danger_zone() -> Array:
	if _zone != null:
		return [_zone_center, _zone_r, _timer]
	return []


func touching_hero(p: Vector3) -> bool:
	if dead:
		return false
	if kind == "okappa":
		return false
	if _state != "undulate" or _depth < -0.3:
		return false
	for s in _segs:
		var q: Vector3 = s.position
		if Vector2(p.x - q.x, p.z - q.z).length() < SEG_R + 0.35:
			return true
	return false


# ------------------------------------------------------------------ outils

func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var seg := b - a
	var t := 0.0
	if seg.length_squared() > 0.0001:
		t = clampf((p - a).dot(seg) / seg.length_squared(), 0.0, 1.0)
	var q := a + seg * t
	return Vector2(p.x - q.x, p.z - q.z).length()


func _damage(d: float) -> void:
	hp -= d
	_flash = 0.15
	if hp <= 0.0:
		dead = true
		_cancel()
		_timer = 0.0
		_state = "dying"
		main.boss_killed(self)
	elif kind == "okappa" and not _summoned and hp <= max_hp * 0.5:
		_summoned = true
		main.spawn_minions(["oni", "oni"])


func _make_zone(center: Vector3, r: float, t: float) -> void:
	_cancel()
	_zone = Node3D.new()
	_zone.top_level = true
	add_child(_zone)
	_zone.global_position = Vector3(center.x, 0, center.z)
	_zone_center = Vector3(center.x, 0, center.z)
	_zone_r = r
	_timer = t
	Toon.disc(_zone, r, Color(Toon.VERMILION, 0.18), 0.03)
	_zone_fill = Toon.disc(_zone, r, Color(Toon.VERMILION, 0.45), 0.035)


func _cancel() -> void:
	if _zone:
		_zone.queue_free()
		_zone = null


func _zone_step(total: float) -> bool:
	var k := 1.0 - _timer / total
	_zone_fill.scale = Vector3(k, 1, k)
	var m := _zone_fill.material_override as StandardMaterial3D
	m.albedo_color = Color(Toon.FOAM, 0.85) if _timer < 0.15 else Color(Toon.VERMILION, 0.45)
	return _timer <= 0.0


# ------------------------------------------------------------------ boucle

func _process(delta: float) -> void:
	_t += delta
	if _flash > 0.0:
		_flash -= delta
		if ch:
			ch.set_flash(1.0 if _flash > 0.0 else 0.0)
	if kind == "okappa":
		_okappa(delta)
	else:
		_uwabami(delta)


func _okappa(delta: float) -> void:
	var to := hero.position - position
	to.y = 0
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	if _state != "dying" and _state != "stun":
		body.rotation.y = lerp_angle(body.rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * 5.0))
	match _state:
		"spawn":
			_timer -= delta
			body.scale = Vector3.ONE * clampf(1.0 - _timer / 1.2, 0.01, 1.0)
			if _timer <= 0.0:
				body.scale = Vector3.ONE
				_state = "idle"
				_timer = 1.0
		"idle":
			# garde ses distances en glissant sur le côté
			var side := Vector3(-dir.z, 0, dir.x) * sin(_t * 0.6)
			var want := -1.0 if dist < 4.0 else (1.0 if dist > 6.5 else 0.0)
			position += (dir * want + side * 0.7) * 1.3 * delta
			main.clamp_to_arena(self, radius)
			ch.play("Walking_B", 0.7)
			_timer -= delta
			if _timer <= 0.0:
				_cycle += 1
				if _cycle % 3 == 0:
					_state = "sink"
					_timer = 0.6
					ch.play_once("Death_C_Skeletons", 2.0)
				else:
					_state = "fan"
					_timer = 0.8
					ch.play_once("Spellcast_Shoot", ch.length("Spellcast_Shoot") * 0.55 / 0.8)
		"fan":
			ch.set_glow(0.55 * (1.0 - _timer / 0.8))
			_timer -= delta
			if _timer <= 0.0:
				ch.set_glow(0.0)
				for i in 5:
					var a := deg_to_rad(-30.0 + 15.0 * i)
					var d := dir.rotated(Vector3.UP, a)
					main.spawn_bullet(position + Vector3(0, 1.4, 0) + d * 0.8, d)
				_state = "idle"
				_timer = 1.5
		"sink":
			_timer -= delta
			body.position.y = lerpf(0.0, -2.6, clampf(1.0 - _timer / 0.6, 0.0, 1.0))
			if _timer <= 0.0:
				_state = "hidden"
				_make_zone(hero.position, 1.6, 1.2)
		"hidden":
			_timer -= delta
			if _zone_step(1.2):
				var c := _zone_center
				_cancel()
				position = Vector3(c.x, 0, c.z)
				main.clamp_to_arena(self, radius)
				main.enemy_strike(c, 1.6)
				body.position.y = 0.0
				ch.idle = "Idle_Combat"
				ch.play_once("Spawn_Ground_Skeletons", ch.length("Spawn_Ground_Skeletons") / 0.5, 0.0)
				_state = "idle"
				_timer = 1.4
		"stun":
			_stun -= delta
			body.rotation.z = sin(_t * 12.0) * 0.08
			if _stun <= 0.0:
				body.rotation.z = 0.0
				_state = "idle"
				_timer = 0.8
		"dying":
			_timer += delta
			if _timer < 0.05:
				ch.hold()
				ch.play_once("Death_C_Skeletons", 1.2, 0.05)
			if _timer > 1.4:
				body.position.y -= delta * 1.5
			if _timer > 2.2:
				queue_free()


func _uwabami(delta: float) -> void:
	match _state:
		"dive":
			# sous l'eau : on prépare la prochaine traversée
			_depth = move_toward(_depth, -1.6, delta * 2.5)
			_timer -= delta
			if _timer <= 0.0 and _depth <= -1.55:
				_plan_crossing()
				_state = "telegraph"
				_timer = 1.3
		"telegraph":
			# sillage d'écume : le chemin qu'il va prendre
			_timer -= delta
			var k := 1.0 - _timer / 1.3
			for i in _marks.get_child_count():
				var m: Node3D = _marks.get_child(i)
				m.visible = float(i) / float(_marks.get_child_count()) <= k * 1.4
			if _timer <= 0.0:
				_state = "undulate"
				_path_i = 0
				_segs_at_path_start()
		"undulate":
			_depth = move_toward(_depth, 0.0, delta * 3.0)
			var speed := 6.5 if hp > max_hp * 0.5 else 8.0
			_advance_head(speed * delta)
			if _path_i >= _path.size():
				_clear_marks()
				_state = "rest"
				_timer = 3.2
		"rest":
			# corps posé dans l'arène : la fenêtre pour le trancher dans sa longueur
			_timer -= delta
			if _stun > 0.0:
				_stun -= delta
				_timer = maxf(_timer, 0.1)
			if _timer <= 0.0:
				_state = "spit"
				_burst = 0
				_fired = 0
				_timer = 0.6
		"spit":
			var head: Node3D = _segs[0]
			var to := hero.position - head.position
			to.y = 0
			head.rotation.y = lerp_angle(head.rotation.y, atan2(-to.x, -to.z), minf(1.0, delta * 6.0))
			_timer -= delta
			if _timer <= 0.0:
				var d := to.normalized()
				main.spawn_bullet(head.position + Vector3(0, 0.9, 0) + d * 0.9, d)
				_fired += 1
				_timer = 0.14
				if _fired >= 6:
					_fired = 0
					_burst += 1
					_timer = 0.9
					if _burst >= 3:
						_state = "dive"
						_timer = 1.0
		"dying":
			_timer += delta
			_depth = move_toward(_depth, -2.0, delta * 0.9)
			for s in _segs:
				s.rotation.z = sin(_t * 10.0 + s.position.x) * 0.2
			if _timer > 2.6:
				queue_free()
	_update_body()


func _plan_crossing() -> void:
	# traversée en S de haut en bas (ou l'inverse), qui finit posée dans l'arène
	_path.clear()
	var down := randf() < 0.5
	var amp := randf_range(1.8, HALF.x - 1.2)
	var phase := randf() * TAU
	var z0 := -HALF.y - 3.0
	var z1 := HALF.y - 2.5
	var steps := 60
	for i in steps + 1:
		var u := float(i) / steps
		var z := lerpf(z0, z1, u) if down else lerpf(-z0, -z1, u)
		var x := amp * sin(phase + u * TAU * 1.1)
		_path.append(Vector3(x, 0, z))
	_clear_marks()
	for i in range(0, _path.size(), 2):
		var p: Vector3 = _path[i]
		if absf(p.z) > HALF.y + 0.5:
			continue
		var m := Toon.disc(_marks, 0.22, Color(Toon.FOAM, 0.85), 0.04)
		m.position = Vector3(p.x, 0.04, p.z)
		m.visible = false


func _clear_marks() -> void:
	for m in _marks.get_children():
		m.queue_free()


func _segs_at_path_start() -> void:
	# le corps démarre caché derrière le point de départ
	var start: Vector3 = _path[0]
	var second: Vector3 = _path[1]
	var back := (start - second).normalized()
	_trail.clear()
	for i in SEGMENTS * 12:
		_trail.append(start + back * (i * SPACING / 12.0))


func _advance_head(dist: float) -> void:
	var head_pos: Vector3 = _trail[0]
	while dist > 0.0 and _path_i < _path.size():
		var target: Vector3 = _path[_path_i]
		var to := target - head_pos
		var d := to.length()
		if d <= dist:
			head_pos = target
			dist -= d
			_path_i += 1
		else:
			head_pos += to / d * dist
			dist = 0.0
		_push_trail(head_pos)


func _push_trail(p: Vector3) -> void:
	var last: Vector3 = _trail[0]
	var step := SPACING / 12.0
	var d := p.distance_to(last)
	if d < step:
		_trail[0] = p
		return
	var n := int(d / step)
	for i in range(1, n + 1):
		_trail.push_front(last.lerp(p, float(i) / n))
	while _trail.size() > SEGMENTS * 12 + 2:
		_trail.pop_back()


func _update_body() -> void:
	for i in SEGMENTS:
		var s: Node3D = _segs[i]
		var idx := mini(i * 12, _trail.size() - 1)
		var p: Vector3 = _trail[idx]
		var nxt: Vector3 = _trail[mini(idx + 6, _trail.size() - 1)]
		var wave := sin(_t * 4.0 - i * 0.6) * 0.08
		s.position = Vector3(p.x, _depth + wave + (0.0 if i > 0 or _state != "spit" else 0.3), p.z)
		var dir := p - nxt
		if dir.length_squared() > 0.0001 and (i > 0 or _state != "spit"):
			s.rotation.y = atan2(-dir.x, -dir.z)
		s.visible = _depth > -1.5
		var flash := _flash > 0.0
		s.scale = Vector3.ONE * (1.08 if flash else 1.0)
