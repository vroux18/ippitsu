extends "res://scripts/boss_mini_base.gd"
## Mini-boss du monde 8 (Yomi) — Gaki-ō, le roi des affamés (22 PV × monde).
##  Trois chaînes le lient à des pieux de fer : tant qu'elles tiennent, l'enfer le protège (bouclier 10)
##  et un coup ne fait qu'effleurer. Mécanique de trait : TRANCHER LES CHAÎNES EN TRAVERS (un trait qui
##  croise une chaîne la rompt). Les trois rompues en moins de 8 s : il s'effondre 5.5 s, vulnérable
##  (dégâts ×2). Sinon les chaînes se ressoudent. Prépare les fils d'Izanami.
##  Attaques : ruée vorace en ligne (bande annoncée 1.0 s, 9 m/s) ; hurlement de faim (disque r2.4,
##  1.2 s) ; os crachés en éventail (lueur 0.8 s).

const MINION = preload("res://assets/kaykit/Skeleton_Minion.glb")
const Loop = preload("res://scripts/boss_loop.gd")
const BONE := Color("#D8D2C4")
const IRON := Color("#3A3C42")
const HUNGER := Color("#9AE070")
const SHIELD := 10.0
const CHAIN_CHIP := 1.2  # éclat de bouclier par chaîne rompue
const RESOLDER := 8.0  # délai pour rompre les trois chaînes
const LUNGE_TELE := 1.0
const LUNGE_SPEED := 9.0
const LUNGE_W := 0.9
const HOWL_R := 2.4
const HOWL_TELE := 1.2
const SPIT_TELE := 0.8
const STAKES := [Vector3(-3.4, 0, -6.6), Vector3(3.4, 0, -6.6), Vector3(0.0, 0, 1.4)]
const HOME := Vector3(0, 0, -3.6)

var _belly: MeshInstance3D
var _collar: Node3D
var _chains: Array = []  # {stake (Vector3), node (Node3D, maillons), mesh, cut}
var _cut_t := 0.0  # temps restant avant que les chaînes rompues se ressoudent
var _cycle := 0
var _lunge_end := Vector3.ZERO
var _lunge_dir := Vector3(0, 0, 1)
var _anim_lock := 0.0
var _death_played := false


func _ready() -> void:
	title = "Gaki-ō"
	hp = 22.0 * max_hp_mult
	max_hp = hp
	radius = 1.0
	_build()
	_shield_init(SHIELD, Vector3(1.5, 1.9, 1.5), 1.4)
	_state = "spawn"
	_timer = 1.3


# ------------------------------------------------------------------ construction

func _build() -> void:
	Toon.disc(self, 1.1, Color(0, 0, 0, 0.18))
	body = Node3D.new()
	add_child(body)
	ch = Character.new()
	body.add_child(ch)
	var ink: Texture2D = load("res://assets/kaykit/tex/skeleton_ink.png")
	ch.setup(MINION, 2.8, [["", ink]], [], HUNGER)
	ch.idle = "Idle_Combat"
	ch.play("Idle_Combat")
	# ventre gonflé de l'affamé, cornes, collier de fer
	_belly = Toon.part(body, Toon.sphere(0.62), Toon.mat(Color("#A89E8A")), Vector3(0, 1.05, -0.25), Vector3(1.0, 0.95, 0.85))
	for sx: float in [-1.0, 1.0]:
		var horn := Toon.part(body, Toon.cyl(0.0, 0.09, 0.45, 6), Toon.mat(BONE), Vector3(sx * 0.22, 2.75, -0.05))
		horn.rotation.z = -sx * 0.5
	_collar = Node3D.new()
	body.add_child(_collar)
	_collar.position = Vector3(0, 2.0, 0)
	var tm := TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.56
	tm.rings = 24
	tm.ring_segments = 6
	Toon.part(_collar, tm, Toon.mat(IRON), Vector3.ZERO, Vector3(1, 0.7, 1))
	# pieux de fer et leurs chaînes
	var iron := Toon.mat(IRON, true, 0.03)
	for k in STAKES.size():
		var sp: Vector3 = STAKES[k]
		var stake := Node3D.new()
		stake.top_level = true
		add_child(stake)
		stake.global_position = sp
		Toon.part(stake, Toon.cyl(0.12, 0.16, 1.6, 6), iron, Vector3(0, 0.8, 0))
		Toon.part(stake, Toon.cyl(0.2, 0.2, 0.1, 6), iron, Vector3(0, 1.6, 0))
		Toon.disc(stake, 0.45, Color(Toon.SUMI, 0.25), 0.02)
		var link := Toon.part(self, Toon.cyl(0.05, 0.05, 1.0, 5), Toon.mat(IRON, true, 0.02), Vector3.ZERO)
		link.top_level = true
		link.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_chains.append({"stake": Vector3(sp.x, 0, sp.z), "stake_node": stake, "mesh": link, "cut": false})
	_make_stars(body, 3.2)
	body.scale = Vector3.ONE * 0.01


# ------------------------------------------------------------------ interface avec main

func check_dash(a: Vector3, b: Vector3, stroke_id: int) -> bool:
	if dead:
		return false
	if hero.dashing and _bound():
		_cut_chains(a, b)
	if _state == "spawn" or _state == "dying":
		return false
	if _last_stroke != stroke_id and _seg_dist(position, a, b) < radius + 0.55:
		_last_stroke = stroke_id
		return true
	return false


func end_stroke(_stroke_id: int) -> void:
	if dead or not _bound():
		return
	# la dernière image de la ruée n'est pas forcément passée par check_dash
	var pa: Vector3 = main._prev_hero
	_cut_chains(pa, hero.position)


func touching_hero(p: Vector3) -> bool:
	if dead or _state != "lunge":
		return false
	return Vector2(p.x - position.x, p.z - position.z).length() < radius + 0.35


func _extra_danger(p: Vector3, _eta: float) -> bool:
	if _state != "lunge":
		return false
	return _seg_dist(p, position, _lunge_end) < LUNGE_W + DANGER_MARGIN


func _aoe_target(center: Vector3, reach: float) -> Vector3:
	if _state == "spawn" or _state == "dying":
		return Vector3.INF
	if Vector2(position.x - center.x, position.z - center.z).length() >= reach + radius:
		return Vector3.INF
	return position + Vector3(0, 1.4, 0)


func _zone_fire(z: Dictionary) -> void:
	var tag := String(z["tag"])
	if tag == "lunge":
		_state = "lunge"
		ch.play("Walking_D_Skeletons", 2.8)
	elif tag == "howl":
		var c: Vector3 = z["c"]
		main.enemy_strike(c, HOWL_R)
		main.vfx.ring(Vector3(c.x, 0.08, c.z), HUNGER, HOWL_R)
		main.shake = maxf(float(main.shake), 0.42)
		_state = "idle"
		_timer = 1.6 if hp > max_hp * 0.5 else 1.2


func _on_die() -> void:
	for c in _chains:
		var cd: Dictionary = c
		var m = cd["mesh"]
		m.visible = false
	ch.set_glow(0.0)


## Chaînes rompues : il s'effondre, plus d'attaque jusqu'à la fin de la fenêtre.
func _on_shield_break() -> void:
	_clear_zones()
	_state = "fallen"
	_cut_t = 0.0
	ch.play_once("Hit_A", 1.0)


## Fin de la fenêtre : les chaînes se ressoudent, il se relève.
func _on_shield_back() -> void:
	if _state != "fallen":
		return
	_resolder()
	_state = "idle"
	_timer = 1.2


# ------------------------------------------------------------------ boucle

func _step(delta: float) -> void:
	var dir := _dir_to_hero()
	if _anim_lock > 0.0:
		_anim_lock -= delta
	if _cut_t > 0.0 and _state != "fallen":
		_cut_t -= delta
		if _cut_t <= 0.0:
			_resolder()
			main.float_text(position + Vector3(0, 2.6, 0), "鎖", SHIELD_C)
	match _state:
		"spawn":
			_timer -= delta
			body.scale = Vector3.ONE * clampf(1.0 - _timer / 1.3, 0.01, 1.0)
			if _timer <= 0.0:
				body.scale = Vector3.ONE
				_state = "idle"
				_timer = 1.4
		"idle":
			_face(dir, delta, 4.0)
			# il rôde autour de sa place, tenu par ses chaînes
			var want := HOME + Vector3(sin(_t * 0.5) * 1.2, 0, cos(_t * 0.4) * 0.8)
			var mv := Vector3(want.x - position.x, 0, want.z - position.z)
			if mv.length() > 0.1:
				position += mv.normalized() * minf(1.0 * delta, mv.length())
				if _anim_lock <= 0.0:
					ch.play("Walking_A", 0.7)
			elif _anim_lock <= 0.0:
				ch.play("Idle_Combat")
			_timer -= delta
			if _timer <= 0.0:
				_cycle += 1
				match _cycle % 3:
					1:
						_start_lunge(dir)
					2:
						_zone_disc(position, HOWL_R, HOWL_TELE, "howl")
						_state = "howl"
						ch.play("Idle_Combat")
					_:
						_state = "spit"
						_timer = SPIT_TELE
						ch.play_once("Throw", ch.length("Throw") * 0.5 / SPIT_TELE)
		"charge":
			_face(_lunge_dir, delta, 8.0)
		"howl":
			# le ventre gonfle avant le hurlement
			pass
		"spit":
			_face(dir, delta, 5.0)
			_timer -= delta
			if _flash <= 0.0:
				ch.set_glow(0.6 * clampf(1.0 - _timer / SPIT_TELE, 0.0, 1.0), HUNGER)
			if _timer <= 0.0:
				ch.set_glow(0.0)
				var n := 5 if hp > max_hp * 0.5 else 7
				var spread := deg_to_rad(56.0 if n == 5 else 80.0)
				for i in n:
					var ang := -spread * 0.5 + spread * float(i) / float(n - 1)
					var d := dir.rotated(Vector3.UP, ang)
					main.spawn_bullet(position + Vector3(0, 1.6, 0) + d * 1.0, d)
				_state = "idle"
				_timer = 2.0 if hp > max_hp * 0.5 else 1.6
		"lunge":
			var left := Vector2(_lunge_end.x - position.x, _lunge_end.z - position.z).length()
			var step := LUNGE_SPEED * delta
			if left <= step:
				position = Vector3(_lunge_end.x, 0, _lunge_end.z)
				main.clamp_to_arena(self, radius)
				_state = "idle"
				_timer = 1.6 if hp > max_hp * 0.5 else 1.2
				ch.play("Idle_Combat")
				main.splash(position + Vector3(0, 0.3, 0), BONE, 10)
			else:
				position += _lunge_dir * step
		"fallen":
			# effondré : la fin de la fenêtre (vulnerable_t) le relève (_on_shield_back)
			pass
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
	_animate()


func _start_lunge(dir: Vector3) -> void:
	_lunge_dir = dir
	var me := Vector3(position.x, 0, position.z)
	var room := _bot_room(me, dir) - 0.8
	var l := clampf(room, 2.0, 7.0)
	_lunge_end = me + dir * l
	_zone_rect(me + dir * (l * 0.5), dir, LUNGE_W, l * 0.5, LUNGE_TELE, "lunge", Vector2(0, -1))
	_state = "charge"
	ch.play_once("1H_Melee_Attack_Chop", ch.length("1H_Melee_Attack_Chop") * 0.4 / LUNGE_TELE)


func _bound() -> bool:
	return _state != "spawn" and _state != "fallen" and _state != "dying"


## Point d'attache des chaînes (son collier), au sol.
func _collar_ground() -> Vector3:
	return Vector3(position.x, 0, position.z)


## Ruée a..b : chaque chaîne croisée se rompt ; les trois rompues brisent le bouclier.
func _cut_chains(a: Vector3, b: Vector3) -> void:
	var me := _collar_ground()
	var n_cut := 0
	for c in _chains:
		var cd: Dictionary = c
		if bool(cd["cut"]):
			n_cut += 1
			continue
		var sp: Vector3 = cd["stake"]
		# la chaîne va du pieu à 0.9 m de lui (on ne la tranche pas dans son corps)
		var tip := me + (sp - me).normalized() * 0.9
		if Loop.cuts(a, b, sp, tip):
			cd["cut"] = true
			n_cut += 1
			var mid := sp.lerp(tip, 0.5)
			main.small_hit(mid + Vector3(0, 1.0, 0))
			main.vfx.sparks(mid + Vector3(0, 1.0, 0), Vector3.UP, 8, Toon.GOLD)
			main.sfx.play("strike", 1.4, -5.0)
			if _cut_t <= 0.0:
				_cut_t = RESOLDER
			if n_cut < _chains.size():
				_shield_dmg(CHAIN_CHIP)
	if n_cut >= _chains.size() and vulnerable_t <= 0.0 and not dead:
		main.float_text(position + Vector3(0, 2.4, 0), "断", Toon.GOLD)
		main.big_hit(position + Vector3(0, 1.4, 0))
		main.shake = maxf(float(main.shake), 0.69)
		_shield_dmg(shield_max)


func _resolder() -> void:
	_cut_t = 0.0
	for c in _chains:
		var cd: Dictionary = c
		if bool(cd["cut"]):
			cd["cut"] = false
			var sp: Vector3 = cd["stake"]
			main.vfx.sparks(sp + Vector3(0, 1.4, 0), Vector3.UP, 5, SHIELD_C)


## Chaînes tendues (pieu -> collier), ventre qui gonfle, corps effondré.
func _animate() -> void:
	var neck := position + Vector3(0, 2.0 + body.position.y, 0)
	for c in _chains:
		var cd: Dictionary = c
		var m = cd["mesh"]
		var sp: Vector3 = cd["stake"]
		var on := not bool(cd["cut"]) and not dead
		m.visible = on
		if on:
			var a := sp + Vector3(0, 1.5, 0)
			var d := neck - a
			var l := maxf(d.length(), 0.01)
			var q := Quaternion.IDENTITY
			if absf(d.normalized().dot(Vector3.UP)) < 0.999:
				q = Quaternion(Vector3.UP, d.normalized())
			m.global_transform = Transform3D(Basis(q) * Basis.from_scale(Vector3(1, l, 1)), (a + neck) * 0.5)
	var swell := 1.0
	if _state == "howl":
		for z in _zones:
			var zd: Dictionary = z
			swell = 1.0 + 0.35 * clampf(1.0 - float(zd["t"]) / float(zd["total"]), 0.0, 1.0)
	_belly.scale = Vector3(1.0, 0.95, 0.85) * swell
	if _state == "fallen":
		body.rotation.x = lerpf(body.rotation.x, 0.5, 0.1)
		body.position.y = -0.3
	elif _state != "dying":
		body.rotation.x = lerpf(body.rotation.x, 0.0, 0.2)
		body.position.y = 0.0
	if _state != "spawn" and _state != "dying":
		body.scale = Vector3.ONE * (1.06 if _flash > 0.0 else 1.0)


# ------------------------------------------------------------------ robot testeur

## Chaînes : un trait droit en travers de la première chaîne intacte (et des autres au passage) ;
## effondré (vulnérable) : iaï à travers, encore et encore.
func bot_stroke(hero_pos: Vector3) -> PackedVector3Array:
	var none := PackedVector3Array()
	if dead:
		return none
	var h := Vector3(hero_pos.x, 0, hero_pos.z)
	var me := _collar_ground()
	if _state == "fallen":
		if vulnerable_t < 0.3:
			return none
		return _bot_line(h, me, 7.3)
	if not _bound() or _state == "spawn":
		return none
	for c in _chains:
		var cd: Dictionary = c
		if bool(cd["cut"]):
			continue
		var sp: Vector3 = cd["stake"]
		var tip := me + (sp - me).normalized() * 0.9
		var mid := sp.lerp(tip, 0.5)
		var along := (tip - sp)
		along.y = 0
		if along.length_squared() < 0.01:
			continue
		var n := Vector3(-along.z, 0, along.x).normalized()
		var p0 := mid - n * 1.4
		var p1 := mid + n * 1.4
		if h.distance_to(p1) < h.distance_to(p0):
			var tmp := p0
			p0 = p1
			p1 = tmp
		return _bot_dense([h, p0, p1])
	return none
