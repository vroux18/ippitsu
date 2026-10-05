extends Node3D
## Squelettes de samouraï (KayKit) :
##  oni   — Minion : fonce sur le héros, frappe une zone annoncée par un disque qui se remplit
##  kappa — Mage : garde ses distances et lance de grosses boules lentes
##  brute — Warrior : grand, lent et costaud (il faut l'enchaîner dans un combo)

const Toon = preload("res://scripts/toon.gd")
const Character = preload("res://scripts/character.gd")
const MINION = preload("res://assets/kaykit/Skeleton_Minion.glb")
const WARRIOR = preload("res://assets/kaykit/Skeleton_Warrior.glb")
const MAGE = preload("res://assets/kaykit/Skeleton_Mage.glb")

const SPAWN_TIME := 1.0

var kind := "oni"
var hp := 1.0
var speed := 2.0
var radius := 0.45
var hero: Node3D
var main: Node

var dead := false
var last_stroke := -1
var body: Node3D
var ch: Node3D
var _flash := 0.0
var _spawn := SPAWN_TIME
var _knock := Vector3.ZERO
var _t := 0.0
var _walk := "Walking_D_Skeletons"

# attaque
var _state := "move"  # move | windup | recover
var _timer := 0.0
var _windup := 1.0
var _attack := "1H_Melee_Attack_Chop"
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
	ch = Character.new()
	body.add_child(ch)
	match kind:
		"oni":
			hp = 1.0
			speed = 2.3
			radius = 0.45
			_windup = 1.0
			ch.setup(MINION, 1.6, [["Cloak", load("res://assets/kaykit/tex/skeleton_red.png")]])
			ch.attach("handslot.r", _blade(0.75, Color("#8A8F96")))
		"brute":
			hp = 3.5
			speed = 1.4
			radius = 0.75
			_zone_r = 1.5
			_windup = 1.2
			_attack = "2H_Melee_Attack_Chop"
			_walk = "Walking_A"
			ch.setup(WARRIOR, 2.4, [["Helmet", load("res://assets/kaykit/tex/skeleton_gold.png")], ["Cloak", load("res://assets/kaykit/tex/skeleton_ink.png")]])
			ch.attach("handslot.r", _blade(1.25, Color("#6E747C")))
		"kappa":
			hp = 1.0
			speed = 1.6
			radius = 0.45
			_walk = "Walking_B"
			ch.setup(MAGE, 1.75, [["Hat", load("res://assets/kaykit/tex/skeleton_prussian.png")], ["Body", load("res://assets/kaykit/tex/skeleton_prussian.png")]], [], Toon.GOLD)
			ch.attach("handslot.r", _staff())
			_timer = 1.4 + randf() * 1.5
	ch.idle = "Idle_Combat"
	Toon.disc(self, radius * 0.95, Color(0, 0, 0, 0.22))
	ch.play_once("Spawn_Ground_Skeletons", ch.length("Spawn_Ground_Skeletons") / SPAWN_TIME, 0.0)


func _blade(blade_len: float, steel: Color) -> Node3D:
	var k := Node3D.new()
	Toon.part(k, Toon.box(Vector3(0.05, 0.2, 0.05)), Toon.mat(Color("#4A3A2C")), Vector3.ZERO)
	Toon.part(k, Toon.box(Vector3(0.035, blade_len, 0.08)), Toon.mat(steel, true, 0.015), Vector3(0, 0.1 + blade_len / 2.0, 0))
	return k


func _staff() -> Node3D:
	var k := Node3D.new()
	Toon.part(k, Toon.cyl(0.03, 0.03, 1.3, 8), Toon.mat(Color("#4A3A2C")), Vector3(0, 0.35, 0))
	Toon.part(k, Toon.sphere(0.12), Toon.mat(Toon.VERMILION), Vector3(0, 1.05, 0))
	return k


func _make_zone() -> void:
	_zone = Node3D.new()
	add_child(_zone)
	Toon.disc(_zone, _zone_r, Color(Toon.VERMILION, 0.18), 0.03)
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
		_timer = 0.0
		ch.hold()
		ch.play_once("Death_C_Skeletons", 1.6, 0.05)
		return true
	ch.play_once("Hit_A", 1.6)
	return false


func _cancel_attack() -> void:
	_state = "recover"
	_timer = 0.6
	if _zone:
		_zone.queue_free()
		_zone = null


func _process(delta: float) -> void:
	_t += delta
	if _flash > 0.0:
		_flash -= delta
		ch.set_flash(1.0 if _flash > 0.0 else 0.0)

	if dead:
		# s'effondre, puis s'enfonce dans le ponton
		position += _knock * delta
		_knock = _knock.lerp(Vector3.ZERO, minf(1.0, delta * 8.0))
		_timer += delta
		if _timer > 1.1:
			body.position.y -= delta * 1.5
		if _timer > 1.6:
			queue_free()
		return

	if _spawn > 0.0:
		_spawn -= delta
		var to := hero.position - position
		body.rotation.y = atan2(-to.x, -to.z)
		return

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


func _face(dir: Vector3, delta: float, rate := 10.0) -> void:
	body.rotation.y = lerp_angle(body.rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * rate))


func _melee(delta: float, dir: Vector3, dist: float) -> void:
	var reach := 0.6 + _zone_r
	match _state:
		"move":
			_face(dir, delta)
			if dist > reach - 0.3:
				position += dir * speed * delta
				ch.play(_walk, speed / 1.6)
			else:
				ch.play("Idle_Combat")
			if dist <= reach - 0.3:
				_state = "windup"
				_timer = _windup
				_strike_dir = dir
				_make_zone()
				# le coup de l'animation tombe pile à la fin de l'annonce
				ch.play_once(_attack, ch.length(_attack) * 0.5 / _windup)
		"windup":
			var k := 1.0 - _timer / _windup
			_zone.position = _strike_dir * (_zone_r * 0.9)
			_zone_fill.scale = Vector3(k, 1, k)
			_timer -= delta
			if _timer <= 0.0:
				var center := position + _strike_dir * (_zone_r * 0.9)
				main.enemy_strike(center, _zone_r)
				_cancel_attack()
				_timer = 1.3
		"recover":
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
		var v := (dir * want + side * 0.6) * speed
		position += v * delta
		if v.length() > 0.3:
			ch.play(_walk, 0.8)
		else:
			ch.play("Idle_Combat")
		_timer -= delta
		if _timer <= 0.0:
			_state = "windup"
			_timer = 0.7
			ch.play_once("Spellcast_Shoot", ch.length("Spellcast_Shoot") * 0.55 / 0.7)
	elif _state == "windup":
		var k := 1.0 - _timer / 0.7
		ch.set_glow(0.55 * k)
		_timer -= delta
		if _timer <= 0.0:
			ch.set_glow(0.0)
			main.spawn_bullet(position + Vector3(0, 1.1, 0) + dir * 0.5, dir)
			_state = "move"
			_timer = 2.6 + randf() * 1.2
