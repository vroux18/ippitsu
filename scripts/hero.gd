extends Node3D
## Le ronin : petit personnage chibi qui fonce le long du trait.

const Toon = preload("res://scripts/toon.gd")

signal dash_finished

const DASH_SPEED := 34.0
const RADIUS := 0.35

var max_hp := 5
var hp := 5
var dashing := false
var invuln := 0.0  # invincibilité après un coup reçu (temps de jeu)
var path := PackedVector3Array()
var path_i := 0
var facing := Vector3(0, 0, -1)

var body: Node3D
var sword_pivot: Node3D
var _t := 0.0
var _lean := 0.0


func _ready() -> void:
	Toon.disc(self, 0.42, Color(0, 0, 0, 0.22))
	body = Node3D.new()
	add_child(body)

	var dark := Toon.mat(Toon.SUMI)
	var skin := Toon.mat(Toon.SKIN)
	var red_flat := Toon.mat(Toon.VERMILION, false)

	# jambes, corps (kimono), ceinture
	Toon.part(body, Toon.capsule(0.11, 0.42), dark, Vector3(-0.13, 0.2, 0))
	Toon.part(body, Toon.capsule(0.11, 0.42), dark, Vector3(0.13, 0.2, 0))
	Toon.part(body, Toon.cyl(0.24, 0.34, 0.5), dark, Vector3(0, 0.62, 0))
	Toon.part(body, Toon.cyl(0.32, 0.33, 0.09), red_flat, Vector3(0, 0.5, 0))
	# bras gauche
	var arm := Toon.part(body, Toon.capsule(0.09, 0.36), dark, Vector3(-0.34, 0.66, 0))
	arm.rotation = Vector3(0, 0, -0.4)
	# tête, cheveux, chignon, bandeau
	Toon.part(body, Toon.sphere(0.36), skin, Vector3(0, 1.17, 0))
	Toon.part(body, Toon.sphere(0.375), dark, Vector3(0, 1.27, 0.04), Vector3(1, 0.72, 1))
	Toon.part(body, Toon.sphere(0.12), dark, Vector3(0, 1.58, 0.14))
	Toon.part(body, Toon.cyl(0.372, 0.372, 0.07, 20), red_flat, Vector3(0, 1.24, 0))
	# yeux
	Toon.part(body, Toon.box(Vector3(0.06, 0.1, 0.02)), Toon.mat(Toon.SUMI, false), Vector3(-0.12, 1.13, -0.34))
	Toon.part(body, Toon.box(Vector3(0.06, 0.1, 0.02)), Toon.mat(Toon.SUMI, false), Vector3(0.12, 1.13, -0.34))

	# sabre tenu dans la main droite
	sword_pivot = Node3D.new()
	sword_pivot.position = Vector3(0.36, 0.66, 0)
	body.add_child(sword_pivot)
	var r_arm := Toon.part(sword_pivot, Toon.capsule(0.09, 0.36), dark, Vector3.ZERO)
	r_arm.rotation = Vector3(0, 0, 0.4)
	Toon.part(sword_pivot, Toon.box(Vector3(0.05, 0.05, 0.22)), dark, Vector3(0.05, -0.12, -0.05))
	var guard := Toon.part(sword_pivot, Toon.cyl(0.07, 0.07, 0.03), Toon.mat(Toon.GOLD), Vector3(0.05, -0.12, -0.17))
	guard.rotation = Vector3(PI / 2, 0, 0)
	Toon.part(sword_pivot, Toon.box(Vector3(0.035, 0.07, 0.95)), Toon.mat(Toon.FOAM, true, 0.02), Vector3(0.05, -0.12, -0.66))


func start_dash(p: PackedVector3Array) -> void:
	if p.size() < 2:
		return
	path = p
	path_i = 1
	dashing = true


func dash_end() -> Vector3:
	if dashing and path.size() > 0:
		return path[path.size() - 1]
	return position


func face(dir: Vector3) -> void:
	dir.y = 0
	if dir.length_squared() < 0.0001:
		return
	facing = dir.normalized()


func hurt() -> void:
	hp -= 1
	invuln = 1.2


func _process(delta: float) -> void:
	_t += delta
	if dashing:
		var move := DASH_SPEED * delta
		while move > 0.0 and path_i < path.size():
			var target := path[path_i]
			var to := target - position
			to.y = 0
			var d := to.length()
			if d <= move:
				position = Vector3(target.x, 0, target.z)
				move -= d
				path_i += 1
			else:
				position += to / d * move
				move = 0.0
			if d > 0.001:
				face(to)
		if path_i >= path.size():
			dashing = false
			dash_finished.emit()

	if invuln > 0.0:
		invuln -= delta
		body.visible = dashing or fmod(invuln, 0.16) > 0.07
	else:
		body.visible = true

	# orientation et posture
	var target_rot := atan2(-facing.x, -facing.z)
	body.rotation.y = lerp_angle(body.rotation.y, target_rot, minf(1.0, delta * (40.0 if dashing else 14.0)))
	_lean = lerpf(_lean, 1.0 if dashing else 0.0, minf(1.0, delta * 25.0))
	body.rotation.x = -0.45 * _lean
	body.position.y = 0.0 if dashing else sin(_t * 5.0) * 0.025
	# sabre : levé au repos, tendu vers l'avant pendant la ruée
	sword_pivot.rotation = Vector3(lerpf(0.9, -0.2, _lean), lerpf(0.0, -0.9, _lean), 0)
