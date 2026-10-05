extends Node3D
## Butin au sol : gemmes d'expérience (jade) et pièces d'or. Elles flottent, sont aspirées quand
## le héros passe près, et volent toutes vers lui à la fin de la salle (gather()).
## main.collect(kind, value) est appelé au ramassage.

const Toon = preload("res://scripts/toon.gd")

const MAGNET := 2.6
const GRAB := 0.6
const JADE := Color("#3FD1B2")

var main: Node
var _items: Array = []  # {node, kind, value, vel, t, pull}
var _gem_mesh: SphereMesh
var _coin_mesh: CylinderMesh
var _gem_mat: StandardMaterial3D
var _coin_mat: StandardMaterial3D
var _gather := false


func _ready() -> void:
	_gem_mesh = SphereMesh.new()
	_gem_mesh.radius = 0.13
	_gem_mesh.height = 0.34
	_gem_mesh.radial_segments = 4
	_gem_mesh.rings = 2
	_coin_mesh = CylinderMesh.new()
	_coin_mesh.top_radius = 0.16
	_coin_mesh.bottom_radius = 0.16
	_coin_mesh.height = 0.04
	_coin_mesh.radial_segments = 12
	_gem_mat = _emissive(JADE, 2.2)
	_coin_mat = _emissive(Toon.GOLD, 1.8)


func _emissive(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.roughness = 0.3
	return m


## Fait jaillir du butin depuis un ennemi tué.
func drop(pos: Vector3, kind: String, count: int, value := 1) -> void:
	for i in count:
		var n := MeshInstance3D.new()
		n.mesh = _gem_mesh if kind == "xp" else _coin_mesh
		n.material_override = _gem_mat if kind == "xp" else _coin_mat
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(n)
		n.position = pos + Vector3(0, 0.6, 0)
		var a := randf() * TAU
		var v := Vector3(cos(a), 0, sin(a)) * randf_range(1.5, 3.2) + Vector3(0, randf_range(3.5, 5.5), 0)
		_items.append({"node": n, "kind": kind, "value": value, "vel": v, "t": randf() * 3.0, "pull": false})


## Fin de salle : tout le butin restant vole vers le héros.
func gather() -> void:
	_gather = true
	for it in _items:
		it.pull = true


func clear() -> void:
	for it in _items:
		var n: Node3D = it.node
		n.queue_free()
	_items.clear()
	_gather = false


func _process(delta: float) -> void:
	if main == null or main.hero == null or not is_instance_valid(main.hero):
		return
	var hp: Vector3 = main.hero.position + Vector3(0, 0.7, 0)
	for i in range(_items.size() - 1, -1, -1):
		var it: Dictionary = _items[i]
		var n: Node3D = it.node
		it.t = float(it.t) + delta
		var vel: Vector3 = it.vel
		if not bool(it.pull):
			# petit saut à l'apparition, puis flottement au sol
			vel.y -= 14.0 * delta
			n.position += vel * delta
			if n.position.y < 0.3:
				n.position.y = 0.3
				vel = Vector3(vel.x * 0.6, 0, vel.z * 0.6) if absf(vel.y) > 0.5 else Vector3.ZERO
			vel.x *= 1.0 - minf(1.0, delta * 2.5)
			vel.z *= 1.0 - minf(1.0, delta * 2.5)
			if vel.length() < 0.2:
				n.position.y = 0.35 + sin(float(it.t) * 3.0) * 0.08
			it.vel = vel
			if Vector2(n.position.x - hp.x, n.position.z - hp.z).length() < MAGNET and float(it.t) > 0.35:
				it.pull = true
		else:
			# aspiré par le héros, de plus en plus vite
			var to := hp - n.position
			var spd := 9.0 + 14.0 * float(it.t) if _gather else 12.0
			n.position += to.normalized() * minf(to.length(), spd * delta)
			if to.length() < GRAB:
				main.collect(String(it.kind), int(it.value))
				n.queue_free()
				_items.remove_at(i)
				continue
		n.rotation.y += delta * (5.0 if it.kind == "coin" else 2.0)
		if it.kind == "coin":
			n.rotation.x = PI / 2.0
	if _items.is_empty():
		_gather = false
