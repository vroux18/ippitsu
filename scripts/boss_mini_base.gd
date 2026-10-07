extends Node3D
## Socle commun des mini-boss des mondes 2 à 5 (salle 8, voir main.MINI_BOSS).
## Interface attendue par main (identique à boss.gd) : setup(), check_dash(), take_hit(), end_stroke(),
## danger_at(), touching_hero(), aoe_hit(), bot_stroke() ; main.boss_killed(self) une seule fois.
## Les scripts enfants remplacent les fonctions « virtuelles » : _step, _zone_fire, _extra_danger,
## _aoe_target, _on_die (et les fonctions d'interface dont ils ont besoin).

const Toon = preload("res://scripts/toon.gd")
const Character = preload("res://scripts/character.gd")

const HALF := Vector2(4.6, 8.6)  # demi-dimensions de l'arène (comme main.gd)
const DANGER_MARGIN := 0.35  # marge de danger_at (comme is_danger de main)
const BOT_HALF := Vector2(4.3, 8.3)  # bornes des points du robot (comme main._clamp_point)

var kind := ""
var main: Node
var hero: Node3D
var title := ""
var hp := 20.0
var max_hp := 20.0
var dead := false
var radius := 1.0
var max_hp_mult := 1.0  # difficulté du monde

var body: Node3D
var ch: Node3D  # personnage KayKit éventuel (flash des coups)
var _stars: Node3D
var _state := "spawn"
var _timer := 1.2
var _t := 0.0
var _flash := 0.0
var _stun := 0.0
var _last_stroke := -1
var _clanged := -1
# zones annoncées : {node, fill, shape (disc | rect | fan), c, dir, r, hx, hz, half, t, total, tag}
var _zones: Array = []


func setup(k: String, m: Node) -> void:
	kind = k
	main = m
	hero = m.hero


# ------------------------------------------------------------------ interface avec main

## Vrai si la ruée a..b touche le boss pour la première fois de ce trait (dégâts gérés par main).
func check_dash(_a: Vector3, _b: Vector3, _stroke_id: int) -> bool:
	return false


func take_hit(dmg: float, _dir: Vector3) -> void:
	_damage(dmg)


func end_stroke(_stroke_id: int) -> void:
	pass


## Vrai si le point p est dans une attaque annoncée qui frappe d'ici eta secondes (ou en cours).
func danger_at(p: Vector3, eta: float) -> bool:
	if dead:
		return false
	var lim := eta + DANGER_MARGIN
	for z: Dictionary in _zones:
		if float(z["t"]) < lim and _in_zone(z, p, DANGER_MARGIN):
			return true
	return _extra_danger(p, eta)


func touching_hero(_p: Vector3) -> bool:
	return false


## Dégâts de zone (techniques, pouvoirs) : point touché, ou Vector3.INF (invulnérable, hors de portée, mort).
func aoe_hit(center: Vector3, reach: float, dmg: float, fx := true) -> Vector3:
	if dead:
		return Vector3.INF
	var at := _aoe_target(center, reach)
	if at == Vector3.INF:
		return Vector3.INF
	var fl := _flash
	_damage(dmg)
	if not fx:
		_flash = fl
	return at


## Trait qu'un bon joueur tracerait maintenant (points au sol depuis le héros), ou vide = attendre.
func bot_stroke(_hero_pos: Vector3) -> PackedVector3Array:
	return PackedVector3Array()


# ------------------------------------------------------------------ virtuelles

func _step(_delta: float) -> void:
	pass


## Une zone annoncée arrive à terme (le coup tombe).
func _zone_fire(_z: Dictionary) -> void:
	pass


func _extra_danger(_p: Vector3, _eta: float) -> bool:
	return false


## Point vulnérable atteint par une attaque de zone, ou Vector3.INF.
func _aoe_target(_center: Vector3, _reach: float) -> Vector3:
	return Vector3.INF


func _on_die() -> void:
	pass


# ------------------------------------------------------------------ boucle

func _process(delta: float) -> void:
	_t += delta
	if _flash > 0.0:
		_flash -= delta
		if ch != null:
			ch.set_flash(1.0 if _flash > 0.0 else 0.0)
	if not dead:
		_tick_zones(delta)
	_step(delta)
	if _stars != null:
		_stars.visible = _stun > 0.0 and not dead
		_stars.rotation.y = _t * 4.0


func _damage(d: float) -> void:
	if dead or d <= 0.0:
		return
	hp -= d
	_flash = 0.15
	if hp <= 0.0:
		hp = 0.0
		dead = true
		_stun = 0.0
		_clear_zones()
		_state = "dying"
		_timer = 0.0
		_on_die()
		main.boss_killed(self)


# ------------------------------------------------------------------ zones annoncées (vfx partagés)

func _zone_node(c: Vector3, dir: Vector3) -> Node3D:
	var n := Node3D.new()
	n.top_level = true
	add_child(n)
	n.global_position = Vector3(c.x, 0, c.z)
	if dir.length_squared() > 0.0001:
		n.rotation.y = atan2(dir.x, dir.z)
	return n


func _new_zone(n: Node3D, fill: Node3D, shape: String, c: Vector3, dir: Vector3, t: float, tag: String) -> Dictionary:
	var z := {"node": n, "fill": fill, "shape": shape, "c": Vector3(c.x, 0, c.z), "dir": dir, "r": 0.0,
		"hx": 0.0, "hz": 0.0, "half": 0.0, "t": t, "total": maxf(t, 0.01), "tag": tag}
	_zones.append(z)
	return z


## Disque de rayon r centré en c, qui frappe dans t secondes.
func _zone_disc(c: Vector3, r: float, t: float, tag: String) -> Dictionary:
	var n := _zone_node(c, Vector3.ZERO)
	var fill: Node3D = main.vfx.tele_disc(n, r)
	var z := _new_zone(n, fill, "disc", c, Vector3(0, 0, 1), t, tag)
	z["r"] = r
	return z


## Rectangle centré en c, long de 2·hz selon dir, large de 2·hx. grow : côté d'où part le remplissage.
func _zone_rect(c: Vector3, dir: Vector3, hx: float, hz: float, t: float, tag: String, grow := Vector2.ZERO) -> Dictionary:
	var d := Vector3(dir.x, 0, dir.z).normalized()
	var n := _zone_node(c, d)
	var fill: Node3D = main.vfx.tele_rect(n, hx, hz, grow)
	var z := _new_zone(n, fill, "rect", c, d, t, tag)
	z["hx"] = hx
	z["hz"] = hz
	return z


## Cône depuis o vers dir (demi-angle half en radians, longueur length).
func _zone_fan(o: Vector3, dir: Vector3, half: float, length: float, t: float, tag: String) -> Dictionary:
	var d := Vector3(dir.x, 0, dir.z).normalized()
	var n := _zone_node(o, d)
	var fill: Node3D = main.vfx.tele_fan(n, half, length)
	var z := _new_zone(n, fill, "fan", o, d, t, tag)
	z["r"] = length
	z["half"] = half
	return z


func _in_zone(z: Dictionary, p: Vector3, m: float) -> bool:
	var c: Vector3 = z["c"]
	var v := Vector3(p.x - c.x, 0, p.z - c.z)
	var shape := String(z["shape"])
	if shape == "disc":
		return v.length() < float(z["r"]) + m
	var d: Vector3 = z["dir"]
	if shape == "rect":
		var side := Vector3(-d.z, 0, d.x)
		return absf(v.dot(d)) < float(z["hz"]) + m and absf(v.dot(side)) < float(z["hx"]) + m
	# cône
	var l := v.length()
	if l > float(z["r"]) + m:
		return false
	if l < 0.3 + m:
		return true
	var ang := acos(clampf(v.dot(d) / l, -1.0, 1.0))
	var half := float(z["half"])
	if ang <= half:
		return true
	return l * sin(minf(ang - half, PI * 0.5)) < m


func _tick_zones(delta: float) -> void:
	var fired: Array = []
	for z: Dictionary in _zones:
		var tl := float(z["t"]) - delta
		z["t"] = tl
		main.vfx.tele_update(z["fill"], clampf(1.0 - tl / float(z["total"]), 0.01, 1.0), tl)
		if tl <= 0.0:
			fired.append(z)
	for z: Dictionary in fired:
		_zones.erase(z)
		_free_zone(z)
		if not dead:
			_zone_fire(z)


func _free_zone(z: Dictionary) -> void:
	var n: Node3D = z["node"]
	if is_instance_valid(n):
		n.queue_free()


func _clear_zones() -> void:
	for z: Dictionary in _zones:
		_free_zone(z)
	_zones.clear()


func _has_zone(tag: String) -> bool:
	for z: Dictionary in _zones:
		if String(z["tag"]) == tag:
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


func _flat(p: Vector3) -> Vector3:
	return Vector3(p.x, 0, p.z)


## Direction au sol vers le héros (devant par défaut).
func _dir_to_hero() -> Vector3:
	var to := hero.position - position
	to.y = 0
	if to.length_squared() < 0.0001:
		return Vector3(0, 0, 1)
	return to.normalized()


## Tourne le corps (qui regarde vers -Z) vers dir.
func _face(dir: Vector3, delta: float, rate := 5.0) -> void:
	if body == null or Vector2(dir.x, dir.z).length_squared() < 0.0001:
		return
	body.rotation.y = lerp_angle(body.rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * rate))


## Cylindre tendu de a à b (pattes, côtes).
func _limb(parent: Node3D, a: Vector3, b: Vector3, r: float, m: Material) -> MeshInstance3D:
	var d := b - a
	var mi := Toon.part(parent, Toon.cyl(r * 0.8, r, maxf(d.length(), 0.01), 6), m, (a + b) * 0.5)
	if d.length_squared() > 0.0001:
		mi.basis = Basis(Quaternion(Vector3.UP, d.normalized()))
	return mi


## Étoiles d'étourdissement (cachées tant que _stun <= 0).
func _make_stars(parent: Node3D, y: float) -> void:
	_stars = Node3D.new()
	parent.add_child(_stars)
	_stars.position = Vector3(0, y, 0)
	for k in 3:
		var a := TAU * float(k) / 3.0
		Toon.part(_stars, Toon.sphere(0.09), Toon.flat(Toon.GOLD), Vector3(cos(a) * 0.42, 0, sin(a) * 0.42))
	_stars.visible = false


## Plus longue suite strictement croissante (ordre des points touchés).
func _lis(order: Array) -> int:
	var best := 0
	var len_at: Array = []
	for i in order.size():
		var l := 1
		for j in i:
			if int(order[j]) < int(order[i]):
				l = maxi(l, int(len_at[j]) + 1)
		len_at.append(l)
		best = maxi(best, l)
	return best


# ------------------------------------------------------------------ robot testeur

func _bot_clamp(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, -BOT_HALF.x, BOT_HALF.x), 0, clampf(p.z, -BOT_HALF.y, BOT_HALF.y))


func _bot_inside(p: Vector3, margin: float) -> bool:
	return absf(p.x) <= BOT_HALF.x - margin and absf(p.z) <= BOT_HALF.y - margin


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
