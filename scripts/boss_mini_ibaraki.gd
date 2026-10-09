extends "res://scripts/boss_mini_base.gd"
## Mini-boss du monde 4 (Fuji Rouge) — Ibaraki-dōji, l'oni au bras tranché (26 PV × monde).
##  L'anneau de forge qui le lie est son bouclier (10) : un coup ne fait qu'effleurer. Trois sceaux
##  de braise (quatre sous 50 %) flottent dans l'arène, numérotés par des encoches sumi (1 à 4).
##  Mécanique de trait : un seul trait (ruées enchaînées comprises) qui les touche TOUS DANS L'ORDRE
##  brise tout l'anneau : à genoux 5.5 s, vulnérable (dégâts ×2). Dans le désordre (2 sceaux ou plus) :
##  l'anneau n'est qu'ébréché et les sceaux se réarrangent. Prépare les noyaux de Daidarabotchi.
##  Attaques : charge en ligne (bande annoncée 1.0 s, 10 m/s) ; cercle de feu autour de lui
##  (r2.6, annoncé 1.2 s).

const WARRIOR = preload("res://assets/kaykit/Skeleton_Warrior.glb")
const EMBER := Color("#E0602A")
const BRAISE := Color("#8E2A1E")
const IRON := Color("#3B3633")
const SEAL_HIT := 0.8  # distance trait-sceau pour le toucher
const SHIELD := 10.0
const SEAL_CHIP := 0.8  # anneau ébréché par sceau pris dans le désordre
const RESEAL_TIME := 1.2
const CHARGE_TELE := 1.0
const CHARGE_SPEED := 10.0
const CHARGE_W := 0.9  # demi-largeur de la bande de charge
const RING_R := 2.6
const RING_TELE := 1.2

var _bind: Node3D
var _seals: Array = []  # {node, orb, pos, lit}, dans l'ordre 1, 2, 3…
var _order: Array = []
var _seen := {}
var _seal_t := 0.3
var _cycle := 0
var _charge_end := Vector3.ZERO
var _charge_dir := Vector3(0, 0, 1)
var _anim_lock := 0.0  # laisse finir une animation jouée une fois
var _death_played := false


func _ready() -> void:
	title = "Ibaraki-dōji"
	hp = 26.0 * max_hp_mult
	max_hp = hp
	radius = 1.0
	_build()
	_shield_init(SHIELD, Vector3(1.4, 1.9, 1.4), 1.5)
	_state = "spawn"
	_timer = 1.4


# ------------------------------------------------------------------ construction

func _build() -> void:
	Toon.disc(self, 1.0, Color(0, 0, 0, 0.16))
	body = Node3D.new()
	add_child(body)
	ch = Character.new()
	body.add_child(ch)
	var red: Texture2D = load("res://assets/kaykit/tex/skeleton_red.png")
	var gold: Texture2D = load("res://assets/kaykit/tex/skeleton_gold.png")
	# le bras droit manque (tranché par Watanabe no Tsuna) : le kanabō est dans la main gauche
	ch.setup(WARRIOR, 3.0, [["Cloak", red], ["Helmet", gold]], ["Skeleton_Warrior_ArmRight"], EMBER)
	ch.idle = "Idle_Combat"
	ch.attach("handslot.l", _kanabo())
	ch.play_once("Spawn_Ground_Skeletons", ch.length("Spawn_Ground_Skeletons") / 1.4, 0.0)
	# cornes d'oni
	for sx in [-1.0, 1.0]:
		var horn := Toon.part(body, Toon.cyl(0.0, 0.1, 0.5, 6), Toon.mat(Toon.GOLD), Vector3(float(sx) * 0.3, 3.05, -0.05))
		horn.rotation.z = -float(sx) * 0.4
	# anneau de forge qui le lie (son armure)
	_bind = Node3D.new()
	body.add_child(_bind)
	_bind.position = Vector3(0, 1.45, 0)
	var tm := TorusMesh.new()
	tm.inner_radius = 0.85
	tm.outer_radius = 0.97
	tm.rings = 32
	tm.ring_segments = 6
	Toon.part(_bind, tm, Toon.mat(Toon.GOLD), Vector3.ZERO, Vector3(1, 0.6, 1))
	for k in 4:
		var a := TAU * float(k) / 4.0
		Toon.part(_bind, Toon.sphere(0.13), Toon.flat(EMBER), Vector3(cos(a) * 0.91, 0, sin(a) * 0.91))
	_make_stars(body, 3.4)


## Massue d'oni : fût de fer, pointes or.
func _kanabo() -> Node3D:
	var k := Node3D.new()
	Toon.part(k, Toon.cyl(0.04, 0.04, 0.4, 8), Toon.mat(Color("#4A3A2C")), Vector3(0, 0.0, 0))
	Toon.part(k, Toon.cyl(0.14, 0.09, 1.2, 8), Toon.mat(IRON), Vector3(0, 0.75, 0))
	for i in 4:
		for j in 4:
			var a := TAU * float(j) / 4.0 + float(i) * 0.4
			Toon.part(k, Toon.sphere(0.045), Toon.mat(Toon.GOLD, false), Vector3(cos(a) * 0.13, 0.35 + 0.22 * float(i), sin(a) * 0.13))
	return k


## Sceau de braise numéroté par `idx + 1` encoches sumi.
func _make_seal(idx: int, p: Vector3) -> Dictionary:
	var n := Node3D.new()
	n.top_level = true
	add_child(n)
	n.global_position = p
	Toon.disc(n, 0.62, Color(Toon.GOLD, 0.25), 0.02)
	var orb := Node3D.new()
	n.add_child(orb)
	orb.position.y = 0.9
	Toon.part(orb, Toon.sphere(0.34), Toon.flat(Toon.GOLD), Vector3.ZERO)
	Toon.part(orb, Toon.sphere(0.5), Toon.flat(Color(EMBER, 0.35)), Vector3.ZERO)
	var ink := Toon.mat(Toon.SUMI, false)
	for k in idx + 1:
		var x := (float(k) - float(idx) * 0.5) * 0.2
		Toon.part(n, Toon.box(Vector3(0.08, 0.05, 0.4)), ink, Vector3(x, 1.6, 0))
	main.splash(p + Vector3(0, 0.9, 0), EMBER, 6)
	return {"node": n, "orb": orb, "pos": Vector3(p.x, 0, p.z), "lit": false}


func _spawn_seals() -> void:
	_free_seals(false)
	var n := 3 if hp > max_hp * 0.5 else 4
	var pts := _layout(n)
	for i in n:
		var p: Vector3 = pts[i]
		_seals.append(_make_seal(i, p))


func _free_seals(burst: bool) -> void:
	for s: Dictionary in _seals:
		var n: Node3D = s["node"]
		if is_instance_valid(n):
			if burst:
				var p: Vector3 = s["pos"]
				main.splash(p + Vector3(0, 0.9, 0), EMBER, 10)
			n.queue_free()
	_seals.clear()
	_order = []
	_seen = {}


## Places des sceaux : éparpillés (pas en ligne), loin de lui, espacés de 2.4 à 4 m dans l'ordre,
## et aucun sceau sur le chemin direct entre deux sceaux qui se suivent.
func _layout(n: int) -> Array:
	var me := Vector3(position.x, 0, position.z)
	var max_leg := 4.6 if n == 3 else 4.0
	for _attempt in 80:
		var pts: Array = []
		for i in n:
			for _k in 30:
				var q := Vector3(randf_range(-3.3, 3.3), 0, randf_range(-6.2, 5.2))
				if q.distance_to(me) < 2.4:
					continue
				var good := true
				for o in pts:
					var op: Vector3 = o
					if op.distance_to(q) < 2.3:
						good = false
						break
				if good and i > 0:
					var prev: Vector3 = pts[i - 1]
					var dd := prev.distance_to(q)
					good = dd >= 2.4 and dd <= max_leg
				if good:
					pts.append(q)
					break
			if pts.size() != i + 1:
				break
		if pts.size() == n and _layout_clear(pts):
			return pts
	# repli : zigzag fixe
	var fb: Array = [Vector3(-2.6, 0, -2.4), Vector3(2.4, 0, -0.6), Vector3(-2.3, 0, 1.4), Vector3(2.5, 0, 3.4)]
	return fb.slice(0, n)


func _layout_clear(pts: Array) -> bool:
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		for j in pts.size():
			if j == i or j == i + 1:
				continue
			var q: Vector3 = pts[j]
			if _seg_dist(q, a, b) < 1.3:
				return false
	return true


# ------------------------------------------------------------------ interface avec main

func check_dash(a: Vector3, b: Vector3, stroke_id: int) -> bool:
	if dead:
		return false
	if hero.dashing and not _seals.is_empty():
		_seal_touch(a, b)
	if _state == "spawn" or _state == "dying":
		return false
	# à genoux : coup plein (×2) ; lié par l'anneau : il effleure et use l'anneau
	if _last_stroke != stroke_id and _seg_dist(position, a, b) < radius + 0.55:
		_last_stroke = stroke_id
		return true
	return false


## Fin du trait : tous les sceaux dans l'ordre brisent l'anneau.
func end_stroke(_stroke_id: int) -> void:
	if not dead and not _seals.is_empty():
		# la dernière image de la ruée n'est pas forcément passée par check_dash
		var pa: Vector3 = main._prev_hero
		_seal_touch(pa, hero.position)
	var order: Array = _order
	_order = []
	_seen = {}
	for s: Dictionary in _seals:
		s["lit"] = false
	if dead or _seals.is_empty() or order.size() < 2:
		# un seul sceau effleuré : rien ne se passe
		return
	var ok := order.size() == _seals.size()
	for i in order.size():
		if int(order[i]) != i:
			ok = false
	if ok and _state != "broken":
		_break_bind()
		return
	# dans le désordre : les sceaux crachent des étincelles et se réarrangent, l'anneau s'ébrèche
	var last: Dictionary = _seals[int(order[order.size() - 1])]
	var lp: Vector3 = last["pos"]
	main.clang(lp + Vector3(0, 0.9, 0))
	_free_seals(true)
	_seal_t = 0.6
	_shield_dmg(SEAL_CHIP * float(order.size()))


func touching_hero(p: Vector3) -> bool:
	if dead or _state != "rush":
		return false
	return Vector2(p.x - position.x, p.z - position.z).length() < radius + 0.35


func _extra_danger(p: Vector3, _eta: float) -> bool:
	if _state != "rush":
		return false
	return _seg_dist(p, position, _charge_end) < CHARGE_W + DANGER_MARGIN


func _aoe_target(center: Vector3, reach: float) -> Vector3:
	if _state == "spawn" or _state == "dying":
		return Vector3.INF
	if Vector2(position.x - center.x, position.z - center.z).length() >= reach + radius:
		return Vector3.INF
	return position + Vector3(0, 1.4, 0)


func _zone_fire(z: Dictionary) -> void:
	var tag := String(z["tag"])
	if tag == "charge":
		_state = "rush"
		ch.play("Walking_D_Skeletons", 2.6)
	elif tag == "ring":
		var c: Vector3 = z["c"]
		main.enemy_strike(c, RING_R)
		main.fire_ring(c, RING_R)
		ch.play_once("2H_Melee_Attack_Spinning", 1.6)
		_anim_lock = 0.7
		_state = "idle"
		_timer = 1.6 if hp > max_hp * 0.5 else 1.2


func _on_die() -> void:
	_free_seals(true)
	_bind.visible = false
	ch.set_glow(0.0)


## Anneau brisé : à genoux, plus d'attaque jusqu'à la fin de la fenêtre.
func _on_shield_break() -> void:
	_clear_zones()
	_free_seals(true)
	_state = "broken"
	_bind.visible = false
	ch.play("Blocking", 0.6)


func _on_shield_back() -> void:
	if _state != "broken":
		return
	_state = "rebind"
	_timer = 0.6
	_bind.visible = true
	_bind.scale = Vector3.ONE * 0.05
	ch.play("Idle_Combat")


# ------------------------------------------------------------------ boucle

func _step(delta: float) -> void:
	var to := hero.position - position
	to.y = 0
	var dist := to.length()
	var dir := _dir_to_hero()
	if _anim_lock > 0.0:
		_anim_lock -= delta
	# les sceaux reviennent (sauf à genoux)
	if _seals.is_empty() and not dead and _state != "spawn" and _state != "broken" and _state != "rebind":
		_seal_t -= delta
		if _seal_t <= 0.0:
			_spawn_seals()
	match _state:
		"spawn":
			_timer -= delta
			if _timer <= 0.0:
				_state = "idle"
				_timer = 1.0
				_seal_t = 0.0
		"idle":
			_face(dir, delta)
			if dist > 3.5:
				position += dir * 1.4 * delta
				main.clamp_to_arena(self, radius)
				if _anim_lock <= 0.0:
					ch.play("Walking_A", 0.8)
			elif _anim_lock <= 0.0:
				ch.play("Idle_Combat")
			_timer -= delta
			if _timer <= 0.0:
				_cycle += 1
				if dist > 5.0 or (dist >= 3.0 and _cycle % 2 == 1):
					_start_charge(dir)
				else:
					_zone_disc(position, RING_R, RING_TELE, "ring")
					_state = "ring"
					_timer = RING_TELE
					ch.play("Idle_Combat")
		"charge":
			# l'élan est pris : la charge part quand la bande annoncée est pleine (_zone_fire)
			_face(_charge_dir, delta, 8.0)
			_timer -= delta
		"ring":
			_timer -= delta
		"rush":
			var left := Vector2(_charge_end.x - position.x, _charge_end.z - position.z).length()
			var mv := CHARGE_SPEED * delta
			if left <= mv:
				position = Vector3(_charge_end.x, 0, _charge_end.z)
				main.clamp_to_arena(self, radius)
				_state = "idle"
				_timer = 1.4 if hp > max_hp * 0.5 else 1.0
				ch.play("Idle_Combat")
				main.splash(position + Vector3(0, 0.3, 0), BRAISE, 10)
			else:
				position += _charge_dir * mv
		"broken":
			# à genoux : la fin de la fenêtre (vulnerable_t) le relève (_on_shield_back)
			pass
		"rebind":
			_timer -= delta
			_bind.scale = Vector3.ONE * clampf(1.0 - _timer / 0.6, 0.05, 1.0)
			if _timer <= 0.0:
				_bind.scale = Vector3.ONE
				_state = "idle"
				_timer = 1.0
				_seal_t = RESEAL_TIME
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
	_animate(delta)


func _start_charge(dir: Vector3) -> void:
	_charge_dir = dir
	var me := Vector3(position.x, 0, position.z)
	# s'arrête avant le bord (rayon compris)
	var room := _bot_room(me, dir) - 0.8
	var l := clampf(room, 2.0, 9.0)
	_charge_end = me + dir * l
	_zone_rect(me + dir * (l * 0.5), dir, CHARGE_W, l * 0.5, CHARGE_TELE, "charge", Vector2(0, -1))
	_state = "charge"
	_timer = CHARGE_TELE
	ch.play_once("2H_Melee_Attack_Chop", ch.length("2H_Melee_Attack_Chop") * 0.4 / CHARGE_TELE)


## Tous les sceaux dans l'ordre : l'anneau de forge cède d'un coup.
func _break_bind() -> void:
	main.float_text(position + Vector3(0, 1.8, 0), "鬼", Toon.GOLD)
	main.big_hit(position + Vector3(0, 1.2, 0))
	main.splash(position + Vector3(0, 1.6, 0), EMBER, 30)
	main.shake = maxf(float(main.shake), 0.86)
	_shield_dmg(shield_max)


func _seal_touch(a: Vector3, b: Vector3) -> void:
	var seg := b - a
	var found: Array = []
	for i in _seals.size():
		if _seen.has(i):
			continue
		var s: Dictionary = _seals[i]
		var p: Vector3 = s["pos"]
		if _seg_dist(p, a, b) < SEAL_HIT:
			var tt := 0.0
			if seg.length_squared() > 0.0001:
				tt = (p - a).dot(seg) / seg.length_squared()
			found.append([tt, i])
	# plusieurs sceaux dans un même segment : dans le sens de la ruée
	found.sort_custom(func(x, y): return x[0] < y[0])
	for f in found:
		var idx := int(f[1])
		_seen[idx] = true
		_order.append(idx)
		var s2: Dictionary = _seals[idx]
		s2["lit"] = true
		var p2: Vector3 = s2["pos"]
		main.small_hit(p2 + Vector3(0, 0.9, 0))


## Chaleur de forge, anneau qui tourne, sceaux qui flottent (blancs une fois touchés).
func _animate(_delta: float) -> void:
	if _flash <= 0.0 and not dead:
		var windup := _state == "charge" or _state == "ring"
		var heat := 0.12
		if windup:
			heat = 0.12 + 0.6 * clampf(1.0 - _timer / (CHARGE_TELE if _state == "charge" else RING_TELE), 0.0, 1.0)
		ch.set_glow(heat, Toon.VERMILION if windup else BRAISE)
	_bind.rotation.y = _t * 1.2
	body.rotation.z = sin(_t * 12.0) * 0.04 if _state == "broken" else 0.0
	for i in _seals.size():
		var s: Dictionary = _seals[i]
		var orb: Node3D = s["orb"]
		orb.position.y = 0.9 + sin(_t * 2.4 + float(i)) * 0.1
		orb.scale = Vector3.ONE * (1.35 if bool(s["lit"]) else 1.0)


# ------------------------------------------------------------------ robot testeur

## Sceaux : un trait qui les relie dans l'ordre (en contournant les suivants : l'anneau tombe) ;
## à genoux (vulnérable) : iaï à travers, encore et encore.
func bot_stroke(hero_pos: Vector3) -> PackedVector3Array:
	var none := PackedVector3Array()
	if dead:
		return none
	var h := Vector3(hero_pos.x, 0, hero_pos.z)
	var me := Vector3(position.x, 0, position.z)
	if _state == "broken":
		if vulnerable_t < 0.3:
			return none
		return _bot_line(h, me, 7.3)
	if _seals.is_empty() or _state == "spawn" or _state == "rebind":
		return none
	var pts: Array = [h]
	for i in _seals.size():
		var s: Dictionary = _seals[i]
		var tgt: Vector3 = s["pos"]
		var avoid: Array = []
		for j in range(i + 1, _seals.size()):
			var o: Dictionary = _seals[j]
			avoid.append(o["pos"])
		var from: Vector3 = pts[pts.size() - 1]
		_bot_leg(pts, from, _bot_clamp(tgt), avoid, 1.1, 3)
	var last: Vector3 = pts[pts.size() - 1]
	var prev: Vector3 = pts[pts.size() - 2]
	var ext := last - prev
	ext.y = 0
	if ext.length_squared() > 0.01:
		pts.append(last + ext.normalized() * 0.8)
	return _bot_dense(pts)
