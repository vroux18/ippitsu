extends Node3D
## Yōkai du prototype :
##  oni   — fonce sur le héros, frappe une zone annoncée par un disque qui se remplit
##  kappa — garde ses distances et tire de grosses boules lentes
##  brute — grand oni lent et costaud (il faut l'enchaîner dans un combo)

const Toon = preload("res://scripts/toon.gd")

var kind := "oni"
var hp := 1.0
var speed := 2.0
var radius := 0.45
var hero: Node3D
var main: Node

var dead := false
var last_stroke := -1
var body: Node3D
var _mats: Array[StandardMaterial3D] = []
var _base_colors: Array[Color] = []
var _flash := 0.0
var _spawn := 0.7
var _knock := Vector3.ZERO
var _t := 0.0

# attaque
var _state := "move"  # move | windup | recover
var _timer := 0.0
var _strike_dir := Vector3.FORWARD
var _zone: Node3D
var _zone_fill: MeshInstance3D
var _zone_r := 1.0


func setup(k: String, h: Node3D, m: Node) -> void:
	kind = k
	hero = h
	main = m


func _ready() -> void:
	_t = randf() * 10.0
	body = Node3D.new()
	add_child(body)
	match kind:
		"oni":
			hp = 1.0
			speed = 2.3
			radius = 0.45
			_build_oni(Color("#C8442F"), Toon.PRUSSIAN, 1.0)
		"brute":
			hp = 3.5
			speed = 1.4
			radius = 0.75
			_zone_r = 1.5
			_build_oni(Color("#3B3A44"), Toon.VERMILION, 1.55)
		"kappa":
			hp = 1.0
			speed = 1.6
			radius = 0.45
			_build_kappa()
			_timer = 1.2 + randf() * 1.5
	Toon.disc(self, radius * 0.95, Color(0, 0, 0, 0.22))
	body.scale = Vector3.ONE * 0.01


func _m(c: Color, outline := true) -> StandardMaterial3D:
	var m := Toon.mat(c, outline)
	_mats.append(m)
	_base_colors.append(c)
	return m


func _build_oni(skin_c: Color, cloth_c: Color, s: float) -> void:
	var skin := _m(skin_c)
	var cloth := _m(cloth_c)
	var horn := _m(Toon.FOAM)
	var dark := _m(Toon.SUMI, false)
	var root := Node3D.new()
	root.scale = Vector3.ONE * s
	body.add_child(root)
	Toon.part(root, Toon.capsule(0.13, 0.38), skin, Vector3(-0.15, 0.19, 0))
	Toon.part(root, Toon.capsule(0.13, 0.38), skin, Vector3(0.15, 0.19, 0))
	Toon.part(root, Toon.sphere(0.36), skin, Vector3(0, 0.62, 0), Vector3(1.05, 0.95, 0.95))
	Toon.part(root, Toon.cyl(0.36, 0.33, 0.2), cloth, Vector3(0, 0.42, 0))
	Toon.part(root, Toon.sphere(0.3), skin, Vector3(0, 1.08, -0.02))
	var h1 := Toon.part(root, Toon.cyl(0.0, 0.07, 0.24, 8), horn, Vector3(-0.15, 1.36, -0.02))
	h1.rotation = Vector3(0, 0, 0.35)
	var h2 := Toon.part(root, Toon.cyl(0.0, 0.07, 0.24, 8), horn, Vector3(0.15, 1.36, -0.02))
	h2.rotation = Vector3(0, 0, -0.35)
	Toon.part(root, Toon.box(Vector3(0.07, 0.06, 0.02)), dark, Vector3(-0.1, 1.12, -0.29))
	Toon.part(root, Toon.box(Vector3(0.07, 0.06, 0.02)), dark, Vector3(0.1, 1.12, -0.29))
	Toon.part(root, Toon.box(Vector3(0.2, 0.04, 0.02)), dark, Vector3(0, 0.98, -0.28))
	# massue
	var club := Toon.part(root, Toon.cyl(0.11, 0.05, 0.75, 8), _m(Color("#6B4A2E")), Vector3(0.42, 0.75, -0.1))
	club.rotation = Vector3(-0.5, 0, -0.25)


func _build_kappa() -> void:
	var skin := _m(Color("#4F8C83"))
	var shell := _m(Toon.PRUSSIAN)
	var plate := _m(Toon.FOAM)
	var beak := _m(Toon.GOLD)
	var dark := _m(Toon.SUMI, false)
	Toon.part(body, Toon.capsule(0.11, 0.34), skin, Vector3(-0.13, 0.17, 0))
	Toon.part(body, Toon.capsule(0.11, 0.34), skin, Vector3(0.13, 0.17, 0))
	Toon.part(body, Toon.sphere(0.32), skin, Vector3(0, 0.55, 0))
	Toon.part(body, Toon.sphere(0.34), shell, Vector3(0, 0.6, 0.14), Vector3(1, 1.05, 0.7))
	Toon.part(body, Toon.sphere(0.3), skin, Vector3(0, 1.0, 0))
	Toon.part(body, Toon.cyl(0.2, 0.22, 0.05), plate, Vector3(0, 1.27, 0))
	Toon.part(body, Toon.box(Vector3(0.18, 0.06, 0.14)), beak, Vector3(0, 0.95, -0.3))
	Toon.part(body, Toon.box(Vector3(0.07, 0.07, 0.02)), dark, Vector3(-0.11, 1.07, -0.27))
	Toon.part(body, Toon.box(Vector3(0.07, 0.07, 0.02)), dark, Vector3(0.11, 1.07, -0.27))


func _make_zone() -> void:
	_zone = Node3D.new()
	add_child(_zone)
	var ring := Toon.disc(_zone, _zone_r, Color(Toon.VERMILION, 0.18), 0.03)
	ring.name = "ring"
	_zone_fill = Toon.disc(_zone, _zone_r, Color(Toon.VERMILION, 0.45), 0.035)


func is_harmless() -> bool:
	return _spawn > 0.0 or dead


func take_hit(dmg: float, dir: Vector3) -> bool:
	hp -= dmg
	_flash = 0.12
	_knock = dir.normalized() * (3.0 if kind == "brute" else 7.0)
	if _state == "windup" and kind != "brute":
		_cancel_attack()
	if hp <= 0.0:
		dead = true
		_cancel_attack()
		return true
	return false


func _cancel_attack() -> void:
	_state = "recover"
	_timer = 0.6
	if _zone:
		_zone.queue_free()
		_zone = null


func _process(delta: float) -> void:
	_t += delta
	if dead:
		# s'écrase et disparaît
		body.scale = body.scale.lerp(Vector3(1.6, 0.05, 1.6), minf(1.0, delta * 14.0))
		position += _knock * delta
		_knock = _knock.lerp(Vector3.ZERO, minf(1.0, delta * 8.0))
		_timer += delta
		if _timer > 0.35:
			queue_free()
		return

	if _spawn > 0.0:
		_spawn -= delta
		var k := clampf(1.0 - _spawn / 0.7, 0.0, 1.0)
		body.scale = Vector3.ONE * (ease(k, 0.4) * (1.0 + 0.15 * sin(k * PI)))
		return
	body.scale = Vector3.ONE

	# flash blanc au coup
	if _flash > 0.0:
		_flash -= delta
	for i in _mats.size():
		_mats[i].albedo_color = Toon.FOAM if _flash > 0.0 else _base_colors[i]

	var to_hero := hero.position - position
	to_hero.y = 0
	var dist := to_hero.length()
	var dir := to_hero / maxf(dist, 0.001)

	match kind:
		"oni", "brute":
			_melee(delta, dir, dist)
		"kappa":
			_shooter(delta, dir, dist)

	position += _knock * delta
	_knock = _knock.lerp(Vector3.ZERO, minf(1.0, delta * 9.0))
	main.clamp_to_arena(self, radius)

	# dandinement
	body.position.y = absf(sin(_t * 9.0)) * 0.06 if _state == "move" else 0.0


func _face(dir: Vector3, delta: float, rate := 10.0) -> void:
	body.rotation.y = lerp_angle(body.rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * rate))


func _melee(delta: float, dir: Vector3, dist: float) -> void:
	var reach := 0.6 + _zone_r
	match _state:
		"move":
			_face(dir, delta)
			if dist > reach - 0.3:
				position += dir * speed * delta
			else:
				_state = "windup"
				_timer = 0.85 if kind == "oni" else 1.1
				_strike_dir = dir
				_make_zone()
		"windup":
			var total := 0.85 if kind == "oni" else 1.1
			var k := 1.0 - _timer / total
			_zone.position = _strike_dir * (_zone_r * 0.9)
			_zone_fill.scale = Vector3(k, 1, k)
			body.rotation.x = -0.35 * k
			_timer -= delta
			if _timer <= 0.0:
				var center := position + _strike_dir * (_zone_r * 0.9)
				main.enemy_strike(center, _zone_r)
				body.rotation.x = 0.4
				_cancel_attack()
				_timer = 0.7
		"recover":
			body.rotation.x = lerpf(body.rotation.x, 0.0, minf(1.0, delta * 6.0))
			_timer -= delta
			if _timer <= 0.0:
				_state = "move"


func _shooter(delta: float, dir: Vector3, dist: float) -> void:
	_face(dir, delta, 6.0)
	if _state == "move":
		# reste à distance moyenne, glisse sur le côté
		var side := Vector3(-dir.z, 0, dir.x) * sin(_t * 0.8)
		var want := 0.0
		if dist < 4.5:
			want = -1.0
		elif dist > 7.0:
			want = 1.0
		position += (dir * want + side * 0.6) * speed * delta
		_timer -= delta
		if _timer <= 0.0:
			_state = "windup"
			_timer = 0.6
	elif _state == "windup":
		var k := 1.0 - _timer / 0.6
		body.scale = Vector3.ONE * (1.0 + 0.25 * k)
		for i in _mats.size():
			_mats[i].albedo_color = _base_colors[i].lerp(Toon.VERMILION, 0.6 * k)
		_timer -= delta
		if _timer <= 0.0:
			body.scale = Vector3.ONE
			main.spawn_bullet(position + Vector3(0, 0.9, 0) + dir * 0.4, dir)
			_state = "move"
			_timer = 2.6 + randf() * 1.2
