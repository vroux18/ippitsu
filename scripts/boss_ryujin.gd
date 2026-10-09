extends "res://scripts/boss_mini_base.gd"
## Boss du monde 7 (Ryūgū-jō) — Ryūjin, le roi dragon de la mer (34 PV × monde).
##  Sa cuirasse d'écailles est son bouclier (12) : un coup ne fait qu'effleurer.
##  Mécanique de trait : « trancher les cinq perles dans l'ordre ». Cinq perles (tama) flottent dans
##  l'arène, numérotées par des encoches sumi : en arc (phase 1), en zigzag (phase 2), en couronne
##  (phase 3). Un seul trait (ruées enchaînées comprises) qui les tranche toutes dans l'ordre brise la
##  cuirasse : la tête retombe, vulnérable 6 s (dégâts ×2), puis phase suivante. Hors ordre : un éclat
##  par perle touchée et les perles se réarrangent ; bon début mais trait trop court : on recommence.
##  Attaques : marée (bande en travers de l'arène, 1.2 s), souffle d'eau (cône 9 m, 1.0 s),
##  bulles (gerbe de boules lentes, lueur 0.9 s). Contact : la tête et ses moustaches.

const SCALE_C := Color("#1E5A5E")
const SCALE_HI := Color("#2E7A7A")
const BELLY := Color("#E8D9A8")
const MANE := Color("#C8423A")
const PEARL := Color("#F4F1EA")
const PEARL_HIT := 0.8
const HEAD_R := 1.7  # contact (tête posée au sol devant le corps)
const SHIELD := 12.0
const PEARL_SH := 0.6  # éclat de cuirasse par perle d'un trait raté
const TIDE_HZ := 1.0
const BREATH_HALF := 0.4
const BREATH_LEN := 9.0

var _head: Node3D
var _jaw: Node3D
var _coils: Array = []
var _eye_mat: StandardMaterial3D
var _pearls: Array = []  # {node, orb, mat, p}
var _layout_id := 0
var _pearls_lock := 0.0
var _run := {}  # trait en cours : {layout, order, bad}
var _phase := 1
var _atk_cd := 1.8
var _volley_t := -1.0
var _cycle := 0


func _ready() -> void:
	title = "Ryūjin"
	if position.is_zero_approx():
		position = Vector3(0, 0, -6.6)  # au fond de l'arène, la tête vers le héros
	hp = 34.0 * max_hp_mult
	max_hp = hp
	radius = HEAD_R
	vulnerable_len = 6.0
	_build()
	_shield_init(SHIELD, Vector3(2.6, 2.2, 2.0), 1.6)
	_state = "spawn"
	_timer = 2.2


# ------------------------------------------------------------------ construction

func _build() -> void:
	var skin := Toon.mat(SCALE_C, true, 0.04)
	var hi := Toon.mat(SCALE_HI, true, 0.03)
	var belly := Toon.mat(BELLY, true, 0.03)
	var gold := Toon.mat(Toon.GOLD, true, 0.03)
	Toon.disc(self, 2.4, Color(0, 0, 0, 0.2))
	body = Node3D.new()
	add_child(body)
	# anneaux du corps qui sortent de l'eau derrière la tête
	for i in 7:
		var t := float(i) / 6.0
		var c := Node3D.new()
		body.add_child(c)
		var x := sin(t * PI * 1.6) * 2.6
		c.position = Vector3(x, 0.0, -1.0 - t * 2.4)
		var r := lerpf(0.9, 0.55, t)
		Toon.part(c, Toon.sphere(r), skin, Vector3(0, r * 0.7, 0), Vector3(1.0, 1.0, 1.3))
		Toon.part(c, Toon.sphere(r * 0.85), belly, Vector3(0, r * 0.35, 0.15), Vector3(1.0, 0.6, 1.2))
		var fin := Toon.part(c, Toon.cyl(0.0, r * 0.35, r * 0.8, 4), Toon.mat(MANE), Vector3(0, r * 1.55, 0))
		fin.rotation.x = -0.4
		_coils.append([c, t * 4.0])
	# tête de dragon : museau, mâchoire, cornes de cerf, crinière, moustaches, yeux d'or
	_head = Node3D.new()
	body.add_child(_head)
	_head.position = Vector3(0, 1.0, 0.6)
	Toon.part(_head, Toon.sphere(0.95), skin, Vector3(0, 0.3, 0), Vector3(1.0, 0.85, 1.1))
	Toon.part(_head, Toon.box(Vector3(1.0, 0.5, 1.2)), skin, Vector3(0, 0.15, 1.0))
	Toon.part(_head, Toon.box(Vector3(0.9, 0.12, 1.1)), hi, Vector3(0, 0.45, 1.0))
	_jaw = Node3D.new()
	_head.add_child(_jaw)
	_jaw.position = Vector3(0, -0.15, 0.4)
	Toon.part(_jaw, Toon.box(Vector3(0.85, 0.22, 1.1)), belly, Vector3(0, -0.05, 0.55))
	for k in 4:
		var tooth := Toon.part(_jaw, Toon.cyl(0.0, 0.05, 0.16, 4), Toon.mat(PEARL), Vector3(-0.3 + 0.2 * float(k), 0.1, 1.0))
		tooth.rotation.x = PI
	_eye_mat = main.vfx.glow_mat(Toon.GOLD, 2.0)
	for sx: float in [-1.0, 1.0]:
		Toon.part(_head, Toon.sphere(0.17), _eye_mat, Vector3(sx * 0.42, 0.55, 0.62))
		# cornes de cerf
		var h1 := Toon.part(_head, Toon.cyl(0.03, 0.08, 1.0, 5), gold, Vector3(sx * 0.35, 1.2, -0.2))
		h1.rotation = Vector3(-0.5, 0, -sx * 0.4)
		var h2 := Toon.part(_head, Toon.cyl(0.02, 0.05, 0.45, 5), gold, Vector3(sx * 0.62, 1.45, -0.35))
		h2.rotation = Vector3(-0.3, 0, -sx * 1.0)
		# moustaches (barbillons)
		var w := Toon.part(_head, Toon.cyl(0.015, 0.04, 1.4, 4), gold, Vector3(sx * 0.6, 0.1, 1.5))
		w.rotation = Vector3(1.2, 0, -sx * 0.9)
	for k in 6:
		var mane := Toon.part(_head, Toon.cyl(0.0, 0.22, 0.8, 5), Toon.mat(MANE), Vector3((float(k) - 2.5) * 0.25, 0.75, -0.6))
		mane.rotation.x = -1.0 - 0.1 * float(k % 2)
	# la perle du dragon tenue sous le menton
	Toon.part(_head, Toon.sphere(0.25), main.vfx.glow_mat(PEARL, 1.8), Vector3(0, -0.45, 1.3))
	_make_stars(_head, 1.8)
	body.position.y = -3.5


# ------------------------------------------------------------------ perles

func _clamp_pearl(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, -HALF.x + 0.8, HALF.x - 0.8), 0, clampf(p.z, position.z + 3.2, HALF.y - 1.6))


func _spread_ok(pts: Array, d: float) -> bool:
	for i in pts.size():
		for j in range(i + 1, pts.size()):
			var p: Vector3 = pts[i]
			var q: Vector3 = pts[j]
			if p.distance_to(q) < d:
				return false
	return true


## Phase 1 : arc de cinq perles en travers de l'arène.
func _layout_arc() -> Array:
	var cz := randf_range(-1.5, 1.5)
	var bend := randf_range(1.0, 2.2) * (1.0 if randf() < 0.5 else -1.0)
	var pts: Array = []
	for i in 5:
		var u := float(i) / 4.0
		pts.append(_clamp_pearl(Vector3(lerpf(-3.4, 3.4, u), 0, cz + bend * (1.0 - pow(2.0 * u - 1.0, 2.0)))))
	if randf() < 0.5:
		pts.reverse()
	return pts


## Phase 2 : zigzag qui descend vers le héros.
func _layout_zigzag() -> Array:
	var x0 := randf_range(2.4, 3.4) * (1.0 if randf() < 0.5 else -1.0)
	var pts: Array = []
	for i in 5:
		var sx := 1.0 if i % 2 == 0 else -1.0
		pts.append(_clamp_pearl(Vector3(x0 * sx, 0, position.z + 3.6 + 2.2 * float(i))))
	if randf() < 0.4:
		pts.reverse()
	return pts


## Phase 3 : couronne (pentagone) au centre, dans l'ordre du tour.
func _layout_ring() -> Array:
	var c := Vector3(randf_range(-0.6, 0.6), 0, randf_range(0.0, 1.5))
	var a0 := randf() * TAU
	var sgn := 1.0 if randf() < 0.5 else -1.0
	var pts: Array = []
	for i in 5:
		var a := a0 + sgn * TAU * float(i) / 5.0
		pts.append(_clamp_pearl(c + Vector3(cos(a) * 3.0, 0, sin(a) * 3.4)))
	return pts


func _new_layout() -> void:
	_layout_id += 1
	_clear_pearls()
	var pts: Array = []
	for attempt in 12:
		if _phase == 1:
			pts = _layout_arc()
		elif _phase == 2:
			pts = _layout_zigzag()
		else:
			pts = _layout_ring()
		if _spread_ok(pts, 1.6):
			break
	for i in pts.size():
		var p: Vector3 = pts[i]
		_pearls.append(_make_pearl(p, i, 0.08 * float(i)))
	_pearls_lock = 0.45 + 0.08 * float(pts.size())


func _make_pearl(p: Vector3, idx: int, delay: float) -> Dictionary:
	var n := Node3D.new()
	n.top_level = true
	add_child(n)
	n.global_position = p
	Toon.disc(n, 0.62, Color(PEARL, 0.25), 0.02)
	var m := Toon.mat(PEARL, true, 0.03)
	m.emission_enabled = true
	m.emission = Color("#9FF0E6")
	m.emission_energy_multiplier = 0.6
	var orb := Toon.part(n, Toon.sphere(0.3), m, Vector3(0, 0.85, 0))
	# encoches sumi sur une plaque de washi : une barre par rang
	var plate := Node3D.new()
	plate.position = Vector3(0, 0.3, 0.85)
	plate.rotation.x = 0.6
	n.add_child(plate)
	Toon.part(plate, Toon.cyl(0.53, 0.53, 0.02, 16), Toon.flat(Toon.SUMI), Vector3(0, -0.006, 0))
	Toon.part(plate, Toon.cyl(0.48, 0.48, 0.02, 16), Toon.flat(Toon.WASHI), Vector3.ZERO)
	var bar_mat := Toon.flat(Toon.SUMI)
	var cnt := idx + 1
	for j in cnt:
		var x := (float(j) - float(cnt - 1) * 0.5) * 0.12
		Toon.part(plate, Toon.box(Vector3(0.07, 0.012, 0.34)), bar_mat, Vector3(x, 0.014, 0))
	n.scale = Vector3.ONE * 0.01
	var tw := n.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(n, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return {"node": n, "orb": orb, "mat": m, "p": Vector3(p.x, 0, p.z)}


func _clear_pearls() -> void:
	for c in _pearls:
		var cd: Dictionary = c
		var n = cd["node"]
		if is_instance_valid(n):
			var tw: Tween = n.create_tween()
			tw.tween_property(n, "scale", Vector3.ONE * 0.01, 0.25)
			tw.tween_callback(n.queue_free)
	_pearls.clear()


func _pearl_color(c: Dictionary, col: Color, energy: float) -> void:
	var m: StandardMaterial3D = c["mat"]
	m.albedo_color = col
	m.emission = col
	m.emission_energy_multiplier = energy


func _reset_pearl_colors() -> void:
	for c in _pearls:
		var cd: Dictionary = c
		var m: StandardMaterial3D = cd["mat"]
		m.albedo_color = PEARL
		m.emission = Color("#9FF0E6")
		m.emission_energy_multiplier = 0.6


# ------------------------------------------------------------------ interface avec main

func _head_ground() -> Vector3:
	return Vector3(position.x, 0, position.z + 1.4)


func check_dash(a: Vector3, b: Vector3, stroke_id: int) -> bool:
	if dead or _state == "spawn" or _state == "dying" or not hero.dashing:
		return false
	if _run.is_empty() or int(_run["layout"]) != _layout_id:
		_run = {"layout": _layout_id, "order": [], "bad": false}
	_touch_pearls(a, b)
	if _last_stroke != stroke_id and _seg_dist(_head_ground(), a, b) < HEAD_R + 0.3:
		_last_stroke = stroke_id
		return true
	return false


func _touch_pearls(a: Vector3, b: Vector3) -> void:
	if _pearls_lock > 0.0 or _state != "fight":
		return
	var order: Array = _run["order"]
	var found: Array = []
	var seg := b - a
	for i in _pearls.size():
		if order.has(i):
			continue
		var c: Dictionary = _pearls[i]
		var p: Vector3 = c["p"]
		if _seg_dist(p, a, b) < PEARL_HIT:
			var tt := 0.0
			if seg.length_squared() > 0.0001:
				tt = clampf((p - a).dot(seg) / seg.length_squared(), 0.0, 1.0)
			found.append([tt, i])
	found.sort_custom(func(x, y): return x[0] < y[0])
	for f in found:
		var i: int = f[1]
		var c: Dictionary = _pearls[i]
		var p: Vector3 = c["p"]
		if i == order.size() and not bool(_run["bad"]):
			# dans l'ordre : la perle s'illumine, un peu d'élan rendu pour la suite
			_pearl_color(c, Toon.GOLD, 1.6)
			main.small_hit(p + Vector3(0, 0.8, 0))
			if i > 0:
				main.elan = minf(main.elan_max(), main.elan + 2.0)
		else:
			_run["bad"] = true
			_pearl_color(c, Toon.SUMI, 0.0)
			main.splash(p + Vector3(0, 0.8, 0), Color("#9FF0E6"), 6)
		order.append(i)


## Fin du trait : verdict sur les perles tranchées.
func end_stroke(_stroke_id: int) -> void:
	if _run.is_empty():
		return
	if not dead and int(_run["layout"]) == _layout_id:
		var pa: Vector3 = main._prev_hero
		_touch_pearls(pa, hero.position)
	var run: Dictionary = _run
	_run = {}
	if dead or int(run["layout"]) != _layout_id:
		return
	var order: Array = run["order"]
	if order.is_empty() or _state != "fight":
		return
	if not bool(run["bad"]) and order.size() == _pearls.size():
		_break_pearls()
		return
	var last: Dictionary = _pearls[int(order[order.size() - 1])]
	var lp: Vector3 = last["p"]
	_shield_dmg(PEARL_SH * float(order.size()))
	if dead or _state != "fight":
		return
	if bool(run["bad"]):
		main.clang(lp)
		_new_layout()
	else:
		_reset_pearl_colors()


## Toutes les perles dans l'ordre : la cuirasse cède d'un coup (_on_shield_break fait retomber la tête).
func _break_pearls() -> void:
	var last: Dictionary = _pearls[_pearls.size() - 1]
	var lp: Vector3 = last["p"]
	for c in _pearls:
		var cd: Dictionary = c
		var p: Vector3 = cd["p"]
		main.splash(p + Vector3(0, 0.8, 0), PEARL, 12)
	main.big_hit(lp)
	main.float_text(lp, "%d / %d" % [_pearls.size(), _pearls.size()], SHIELD_C)
	_shield_dmg(shield_max)


func touching_hero(p: Vector3) -> bool:
	if dead or _state == "spawn" or _state == "dying":
		return false
	var hg := _head_ground()
	return Vector2(p.x - hg.x, p.z - hg.z).length() < HEAD_R


func _aoe_target(center: Vector3, reach: float) -> Vector3:
	if _state == "spawn" or _state == "dying":
		return Vector3.INF
	var hg := _head_ground()
	if Vector2(hg.x - center.x, hg.z - center.z).length() >= reach + HEAD_R:
		return Vector3.INF
	return hg + Vector3(0, 1.4, 0)


func _sh_anchor() -> Vector3:
	return _head_ground()


func _zone_fire(z: Dictionary) -> void:
	var tag := String(z["tag"])
	if tag == "tide":
		var c: Vector3 = z["c"]
		if _in_zone(z, hero.position, 0.0):
			main.enemy_strike(Vector3(hero.position.x, 0, hero.position.z), 0.4)
		for k in 5:
			main.vfx.water_burst(Vector3(-3.6 + 1.8 * float(k), 0, c.z), 0.8)
		main.shake = maxf(float(main.shake), 0.42)
	elif tag == "breath":
		var o: Vector3 = z["c"]
		var d: Vector3 = z["dir"]
		if _in_zone(z, hero.position, 0.0):
			main.enemy_strike(Vector3(hero.position.x, 0, hero.position.z), 0.4)
		for k in 5:
			main.vfx.water_burst(o + d * (1.6 + 1.7 * float(k)), 0.5 + 0.12 * float(k))
		main.shake = maxf(float(main.shake), 0.31)


func _on_die() -> void:
	_clear_pearls()
	_run = {}
	_volley_t = -1.0


## Cuirasse brisée : la tête retombe, attaques annulées.
func _on_shield_break() -> void:
	_clear_zones()
	_clear_pearls()
	_run = {}
	_volley_t = -1.0
	_state = "open"
	var last := _head_ground()
	main.float_text(last + Vector3(0, 2.0, 0), "龍", Toon.GOLD)


## Fin de la fenêtre : la cuirasse se referme, phase suivante, nouvelles perles.
func _on_shield_back() -> void:
	if _state != "open":
		return
	if _phase < 3:
		_phase += 1
		main.spawn_minions(["kani", "oni"] if _phase == 2 else ["ningyo", "kani"])
	else:
		main.spawn_minions(["oni", "oni"])
	_state = "fight"
	_atk_cd = 1.6
	_new_layout()


# ------------------------------------------------------------------ boucle

func _step(delta: float) -> void:
	if _pearls_lock > 0.0:
		_pearls_lock -= delta
	match _state:
		"spawn":
			_timer -= delta
			var k := clampf(1.0 - _timer / 2.2, 0.0, 1.0)
			body.position.y = lerpf(-3.5, 0.0, 1.0 - pow(1.0 - k, 3.0))
			if fmod(_t, 0.3) < delta:
				main.vfx.water_burst(position + Vector3(randf_range(-2.5, 2.5), 0, randf_range(0.0, 2.0)), 0.8)
			if _timer <= 0.0:
				body.position.y = 0.0
				_state = "fight"
				_atk_cd = 1.6
				_new_layout()
		"fight":
			if _volley_t >= 0.0:
				_volley_t -= delta
				_eye_mat.emission_energy_multiplier = 2.0 + 3.0 * clampf(1.0 - _volley_t / 0.9, 0.0, 1.0)
				if _volley_t < 0.0:
					_volley_t = -1.0
					_fire_volley()
			elif _zones.is_empty():
				_atk_cd -= delta
				if _atk_cd <= 0.0:
					_attack()
		"open":
			# tête retombée : les coups portent ×2 (la fin de la fenêtre : _on_shield_back)
			if fmod(_t, 0.3) < delta:
				main.splash(_head_ground() + Vector3(randf_range(-1.0, 1.0), 1.2, 0), Color("#9FF0E6"), 4)
		"dying":
			_timer += delta
			body.position.y -= delta * (0.6 + _timer) * 0.9
			if fmod(_t, 0.25) < delta:
				main.vfx.water_burst(position + Vector3(randf_range(-2.0, 2.0), 0, randf_range(0.0, 2.0)), 0.8)
			if _timer > 3.2:
				queue_free()
	_animate(delta)


func _attack() -> void:
	_cycle += 1
	var opts: Array = ["tide", "breath", "volley"]
	var pick: String = opts[_cycle % opts.size()]
	match pick:
		"tide":
			var cz := clampf(hero.position.z, position.z + 3.0, HALF.y - 1.0)
			_zone_rect(Vector3(0, 0, cz), Vector3(1, 0, 0), TIDE_HZ, HALF.x, 1.2, "tide", Vector2(-1, 0))
		"breath":
			var o := _head_ground() + Vector3(0, 0, 1.4)
			var to := hero.position - o
			to.y = 0
			var ang := clampf(atan2(to.x, to.z), -1.0, 1.0)
			_zone_fan(o, Vector3(sin(ang), 0, cos(ang)), BREATH_HALF, BREATH_LEN, 1.0, "breath")
		_:
			_volley_t = 0.9
	_atk_cd = 2.9 - 0.4 * float(_phase)


func _fire_volley() -> void:
	var src := _head_ground() + Vector3(0, 1.0, 1.4)
	var to := hero.position - src
	to.y = 0
	var d := Vector3(0, 0, 1) if to.length_squared() < 0.01 else to.normalized()
	var n := 3 + 2 * _phase  # 5, 7, 9 bulles
	var step := deg_to_rad(64.0) / float(n - 1)
	for i in n:
		var dd := d.rotated(Vector3.UP, -deg_to_rad(32.0) + step * float(i))
		main.spawn_bullet(src + dd * 0.4, dd)


## Corps qui ondule, tête qui suit le héros (retombée quand la cuirasse est brisée), perles qui flottent.
func _animate(delta: float) -> void:
	for c in _coils:
		var arr: Array = c
		var cn: Node3D = arr[0]
		var ph: float = arr[1]
		cn.position.y = sin(_t * 1.8 + ph) * 0.18
	var look := hero.position - (position + _head.position)
	var yaw := clampf(atan2(look.x, look.z), -0.7, 0.7)
	_head.rotation.y = lerp_angle(_head.rotation.y, yaw, minf(1.0, delta * 3.0))
	var slump := 0.35 if _state == "open" else 0.0
	_head.rotation.x = lerpf(_head.rotation.x, slump, minf(1.0, delta * 4.0))
	var open_jaw := 0.0
	for z in _zones:
		var zd: Dictionary = z
		if String(zd["tag"]) == "breath":
			open_jaw = clampf(1.0 - float(zd["t"]) / float(zd["total"]), 0.0, 1.0)
	if _volley_t >= 0.0:
		open_jaw = maxf(open_jaw, 1.0 - _volley_t / 0.9)
	_jaw.rotation.x = 0.5 * open_jaw
	_head.position.y = 1.0 + (-0.5 if _state == "open" else sin(_t * 1.3) * 0.08)
	if _flash > 0.0:
		body.scale = Vector3.ONE * 1.04
	else:
		body.scale = Vector3.ONE
	var started := not _run.is_empty() and (_run["order"] as Array).size() > 0
	for i in _pearls.size():
		var c2: Dictionary = _pearls[i]
		var orb = c2["orb"]
		orb.position.y = 0.85 + sin(_t * 2.4 + float(i)) * 0.08
		var s := 1.0
		if i == 0 and not started:
			s = 1.0 + 0.18 * maxf(0.0, sin(_t * 6.0))  # la première perle bat : c'est le départ
		orb.scale = Vector3.ONE * s


# ------------------------------------------------------------------ robot testeur

## Perles : placement juste avant la première, puis un seul trait qui les relie dans l'ordre en
## évitant les suivantes ; tête retombée (vulnérable) : iaï en travers, juste devant la tête.
func bot_stroke(hero_pos: Vector3) -> PackedVector3Array:
	var none := PackedVector3Array()
	var h := Vector3(hero_pos.x, 0, hero_pos.z)
	if dead:
		return none
	var hg := _head_ground()
	if _state == "open":
		if vulnerable_t < 0.3:
			return none
		var sx := -1.0 if h.x > hg.x else 1.0
		var near_end := hg + Vector3(-sx * 3.6, 0, 1.2)
		var far_end := hg + Vector3(sx * 3.6, 0, 1.2)
		if h.distance_to(near_end) < 0.8:
			return _bot_dense([h, far_end])
		return _bot_dense([h, hg + Vector3(0, 0, 1.2), far_end])
	if _state != "fight" or _pearls.size() < 2 or _pearls_lock > 0.0:
		return none
	var pts: Array = []
	for c in _pearls:
		var cd: Dictionary = c
		var p: Vector3 = cd["p"]
		pts.append(Vector3(p.x, 0, p.z))
	var first: Vector3 = pts[0]
	var second: Vector3 = pts[1]
	if h.distance_to(first) > 2.6:
		var entry := _bot_off_head(_bot_clamp(first - (second - first).normalized() * 1.1))
		return _bot_route([h, entry], pts, 1.0)
	var way: Array = [h]
	for i in pts.size():
		var a: Vector3 = way[way.size() - 1]
		var b: Vector3 = pts[i]
		_bot_leg(way, a, b, pts.slice(i + 1), 1.0, 3)
	var last: Vector3 = pts[pts.size() - 1]
	var prev: Vector3 = pts[pts.size() - 2]
	way.append(_bot_off_head(_bot_clamp(last + (last - prev).normalized() * 0.9)))
	return _bot_dense(way)


## Repousse un point d'arrivée hors de la tête du dragon (contact = dégâts).
func _bot_off_head(p: Vector3) -> Vector3:
	var c := _head_ground()
	var v := p - c
	v.y = 0
	if v.length() >= HEAD_R + 0.4:
		return p
	if v.length_squared() < 0.01:
		v = Vector3(0, 0, 1)
	return _bot_clamp(c + v.normalized() * (HEAD_R + 0.5))
