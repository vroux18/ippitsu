extends Node3D
## Boss du monde 1 (design/UNIVERS.md) :
##  okappa  — Ō-Kappa, mini-boss (18 PV) : salves en éventail, plongeon sous le héros.
##            Tranché dans le dos, sa coupelle se renverse : dégâts ×3 et étourdi 3 s.
##  uwabami — Uwabami, serpent de mer (60 PV) : ne prend des dégâts que si on le tranche
##            dans sa longueur (au moins 4 segments d'un même trait).
## main appelle : check_dash(), take_hit(), end_stroke(), danger_at(), touching_hero().

const Toon = preload("res://scripts/toon.gd")
const Character = preload("res://scripts/character.gd")
const MAGE = preload("res://assets/kaykit/Skeleton_Mage.glb")

const SEGMENTS := 12
const SPACING := 0.9
const SEG_R := 0.55
const HALF := Vector2(4.6, 8.6)  # demi-dimensions de l'arène (comme main.gd)
const BOWL_WATER := Color("#7FB2C8")
const DANGER_MARGIN := 0.35  # marge de danger_at (comme is_danger de main)

var kind := "okappa"
var main: Node
var hero: Node3D
var title := ""
var hp := 18.0
var max_hp := 18.0
var dead := false
var radius := 1.0
var max_hp_mult := 1.0  # difficulté du monde

var _state := "spawn"
var _timer := 1.2
var _t := 0.0
var _flash := 0.0
var _stun := 0.0
var _last_stroke := -1
var _zone: Node3D
var _zone_fill: Node3D  # visuel partagé de l'annonce (vfx.tele_disc)
var _zone_center := Vector3.ZERO
var _zone_r := 1.6
var _cycle := 0
var _summoned := false

# Ō-Kappa
var body: Node3D
var ch: Node3D
var _anim_lock := 0.0  # laisse finir une animation jouée une fois
var _death_played := false

# Uwabami
var _segs: Array = []  # Node3D, la tête en premier
var _trail: Array = []  # positions passées de la tête (la plus récente en premier)
var _path: Array = []  # chemin prévu de la traversée
var _path_i := 0
var _hits := {}  # segments tranchés depuis le dernier end_stroke : {index: true}
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
	hp *= max_hp_mult
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
	Toon.part(body, Toon.cyl(0.34, 0.34, 0.02, 20), Toon.mat(BOWL_WATER, false), Vector3(0, 2.69, 0.05))
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

## Vrai si la ruée a..b touche le boss pour la première fois de ce trait (dégâts gérés par main).
## Pour Uwabami, les segments touchés sont notés : les dégâts tombent à la fin du trait
## (ruées enchaînées comprises : tout ce qui suit le dernier end_stroke forme un seul tracé).
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
	# hors ruée (image qui suit la fin du trait, bond d'ensō) : rien ne compte
	if not hero.dashing:
		return false
	_mark_segs(a, b)
	return false


## Note les segments d'Uwabami touchés par la ruée a..b.
func _mark_segs(a: Vector3, b: Vector3) -> void:
	if _depth < -0.4:
		return
	for i in SEGMENTS:
		if _hits.has(i):
			continue
		var s: Node3D = _segs[i]
		if _seg_dist(s.position, a, b) < SEG_R + 0.5:
			_hits[i] = true
			main.small_hit(s.position)


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
			main.splash(position + Vector3(0, 2.2, 0), BOWL_WATER, 20)
	_damage(out)


## Fin du trait : Uwabami encaisse selon la plus longue suite de segments tranchés.
func end_stroke(_stroke_id: int) -> void:
	if kind == "uwabami" and not dead:
		# la dernière image de la ruée n'est pas encore passée par check_dash
		var pa: Vector3 = main._prev_hero
		_mark_segs(pa, hero.position)
	var hit_set: Dictionary = _hits
	_hits = {}
	if kind != "uwabami" or dead or hit_set.is_empty():
		return
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
		if _state == "rest":
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


## Vrai si le point p est dans une attaque annoncée qui frappe d'ici eta secondes (ou en cours).
func danger_at(p: Vector3, eta: float) -> bool:
	if dead:
		return false
	var lim := eta + DANGER_MARGIN
	if _zone != null and _timer < lim:
		if Vector2(p.x - _zone_center.x, p.z - _zone_center.z).length() < _zone_r + DANGER_MARGIN:
			return true
	if kind != "uwabami" or (_state != "telegraph" and _state != "undulate"):
		return false
	# traversée d'Uwabami : la tête suit _path, le corps passe ensuite pendant body_t
	var reach := SEG_R + 0.35 + DANGER_MARGIN
	var speed := 6.5 if hp > max_hp * 0.5 else 8.0
	var body_t := float(SEGMENTS) * SPACING / speed
	var acc := 0.0
	var i0 := 0
	var prev := Vector3.ZERO
	if _state == "telegraph":
		if _path.is_empty():
			return false
		acc = maxf(_timer, 0.0)
		prev = _path[0]
	else:
		if eta < body_t + DANGER_MARGIN:
			for s in _segs:
				var sp: Vector3 = s.position
				if Vector2(p.x - sp.x, p.z - sp.z).length() < reach:
					return true
		i0 = _path_i
		prev = _trail[0]
	for i in range(i0, _path.size()):
		var q: Vector3 = _path[i]
		acc += prev.distance_to(q) / speed
		prev = q
		if acc > lim:
			break
		if acc + body_t > eta - DANGER_MARGIN and Vector2(p.x - q.x, p.z - q.z).length() < reach:
			return true
	return false


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


## Dégâts de zone (techniques, pouvoirs) : touche la partie vulnérable la plus proche de `center` dans `reach`.
## Renvoie le point touché, ou Vector3.INF si rien n'est touché (boss invulnérable à cet instant, hors de portée, mort).
## (`reach` plutôt que `radius`, déjà pris par le rayon du boss)
func aoe_hit(center: Vector3, reach: float, dmg: float, fx := true) -> Vector3:
	if dead:
		return Vector3.INF
	var found := false
	var at := Vector3.ZERO
	if kind == "okappa":
		# enfoui ou en train de surgir : intouchable (comme check_dash)
		if _state in ["spawn", "sink", "hidden"]:
			return Vector3.INF
		if Vector2(position.x - center.x, position.z - center.z).length() < reach + radius:
			found = true
			at = position + Vector3(0, 1.2, 0)
	else:
		# Uwabami : seulement quand le corps affleure ; dégâts simples, sans bonus de longueur
		if _depth < -0.4:
			return Vector3.INF
		var best := INF
		for s in _segs:
			var sp: Vector3 = s.position
			var d := Vector2(sp.x - center.x, sp.z - center.z).length()
			if d < reach + SEG_R and d < best:
				best = d
				found = true
				at = Vector3(sp.x, maxf(sp.y, 0.0) + 0.45, sp.z)
	if not found:
		return Vector3.INF
	var fl := _flash
	_damage(dmg)
	if not fx:
		_flash = fl
	return at


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
		hp = 0.0
		dead = true
		_cancel()
		if kind == "uwabami":
			_clear_marks()
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
	_zone_fill = main.vfx.tele_disc(_zone, r)


func _cancel() -> void:
	if _zone:
		_zone.queue_free()
		_zone = null


func _zone_step(total: float) -> bool:
	var k := 1.0 - _timer / total
	main.vfx.tele_update(_zone_fill, k, _timer)
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
	if _anim_lock > 0.0:
		_anim_lock -= delta
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
			if _anim_lock <= 0.0:
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
			if _flash <= 0.0:
				ch.set_glow(0.55 * (1.0 - _timer / 0.8))
			_timer -= delta
			if _timer <= 0.0:
				if _flash <= 0.0:
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
				_anim_lock = 0.5
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
			if not _death_played:
				_death_played = true
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
				main.vfx.tele_dot_flash(m as MeshInstance3D, _timer < 0.15)
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
		var m: MeshInstance3D = main.vfx.tele_dot(_marks, 0.22)
		m.position = Vector3(p.x, m.position.y, p.z)
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


# ------------------------------------------------------------------ robot testeur

## Trait qu'un bon joueur tracerait maintenant (points au sol depuis le héros), ou vide = attendre.
func bot_stroke(hero_pos: Vector3) -> PackedVector3Array:
	var none := PackedVector3Array()
	var h := Vector3(hero_pos.x, 0, hero_pos.z)
	if dead:
		return none
	if kind == "okappa":
		if _state in ["spawn", "sink", "hidden", "dying"]:
			return none
		# trait droit (iaï) à travers lui
		return _bot_line(h, Vector3(position.x, 0, position.z), 7.3)
	# Uwabami : corps posé (repos, crachats), tranché d'un bout à l'autre
	if _depth < -0.3 or not (_state == "rest" or _state == "spit"):
		return none
	var pts: Array = []
	for s in _segs:
		var sn: Node3D = s
		pts.append(Vector3(sn.position.x, 0, sn.position.z))
	var head: Vector3 = pts[0]
	var tail: Vector3 = pts[SEGMENTS - 1]
	if h.distance_to(tail) < h.distance_to(head):
		pts.reverse()
	var first: Vector3 = pts[0]
	var second: Vector3 = pts[1]
	if h.distance_to(first) > 3.0:
		# placement dans le prolongement du bout le plus proche
		var lead := first + (first - second).normalized() * 1.0
		return _bot_route([h, lead], pts, SEG_R + 0.75)
	var last: Vector3 = pts[SEGMENTS - 1]
	var prev: Vector3 = pts[SEGMENTS - 2]
	var way: Array = [h]
	way.append_array(pts)
	way.append(last + (last - prev).normalized() * 1.2)
	return _bot_dense(way)


const BOT_HALF := Vector2(4.3, 8.3)  # bornes des points du robot (comme main._clamp_point)


func _bot_clamp(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, -BOT_HALF.x, BOT_HALF.x), 0, clampf(p.z, -BOT_HALF.y, BOT_HALF.y))


## Polyligne finale : au sol, bornée à l'arène, points espacés de 0.4 m au plus.
func _bot_dense(way: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in way.size():
		var p: Vector3 = way[i]
		if i == 0:
			out.append(Vector3(p.x, 0, p.z))
			continue
		p = _bot_clamp(p)
		var last: Vector3 = out[out.size() - 1]
		var n := int(ceil(last.distance_to(p) / 0.4))
		for k in range(1, n + 1):
			out.append(last.lerp(p, float(k) / float(n)))
	return out


## Relie les points de passage en contournant les points `avoid` (à `clear` m près).
func _bot_route(way: Array, avoid: Array, clear: float) -> PackedVector3Array:
	var first: Vector3 = way[0]
	var pts: Array = [Vector3(first.x, 0, first.z)]
	for i in range(1, way.size()):
		var a: Vector3 = pts[pts.size() - 1]
		var b: Vector3 = way[i]
		_bot_leg(pts, a, _bot_clamp(b), avoid, clear, 3)
	return _bot_dense(pts)


func _bot_leg(out: Array, a: Vector3, b: Vector3, avoid: Array, clear: float, depth: int) -> void:
	var seg := b - a
	seg.y = 0
	var l2 := seg.length_squared()
	var best_t := 2.0
	var hit := Vector3.ZERO
	if depth > 0 and l2 > 0.0001:
		for o in avoid:
			var p: Vector3 = o
			p.y = 0
			if p.distance_to(a) < clear or p.distance_to(b) < clear:
				continue
			var t := clampf((p - a).dot(seg) / l2, 0.0, 1.0)
			if (a + seg * t).distance_to(p) < clear and t < best_t:
				best_t = t
				hit = p
	if best_t > 1.0:
		out.append(b)
		return
	# détour : on passe à côté de l'obstacle le plus proche du départ
	var q := a + seg * best_t
	var n := q - hit
	n.y = 0
	if n.length() < 0.05:
		n = Vector3(-seg.z, 0, seg.x)
		if n.dot(-q) < 0.0:
			n = -n
	var w := _bot_clamp(hit + n.normalized() * (clear + 0.35))
	_bot_leg(out, a, w, avoid, clear, depth - 1)
	_bot_leg(out, w, b, avoid, clear, depth - 1)


## Place libre devant p dans la direction dir avant le bord de l'arène.
func _bot_room(p: Vector3, dir: Vector3) -> float:
	var t := 99.0
	if dir.x > 0.001:
		t = minf(t, (BOT_HALF.x - p.x) / dir.x)
	elif dir.x < -0.001:
		t = minf(t, (-BOT_HALF.x - p.x) / dir.x)
	if dir.z > 0.001:
		t = minf(t, (BOT_HALF.y - p.z) / dir.z)
	elif dir.z < -0.001:
		t = minf(t, (-BOT_HALF.y - p.z) / dir.z)
	return maxf(t, 0.0)


## Trait droit qui traverse tgt, long d'au moins min_len si l'arène le permet (iaï dès 7 m).
func _bot_line(h: Vector3, tgt: Vector3, min_len: float) -> PackedVector3Array:
	var d := tgt - h
	d.y = 0
	var dist := d.length()
	var dir := Vector3(-h.x, 0, -h.z)
	if dist > 0.3:
		dir = d / dist
	if dir.length_squared() < 0.01:
		dir = Vector3(0, 0, 1)
	dir = dir.normalized()
	var l := minf(maxf(min_len, dist + 1.2), _bot_room(h, dir))
	if l < dist + 0.5:
		# cible collée au bord : on la traverse puis on revient vers le centre
		var back := Vector3(-tgt.x, 0, -tgt.z)
		if back.length_squared() < 0.01:
			back = Vector3(0, 0, 1)
		return _bot_dense([h, tgt, tgt + back.normalized() * 2.0])
	return _bot_dense([h, h + dir * l])
