extends Node3D
## Le ronin (KayKit Rogue encapuchonné) : il fonce le long du trait.

const Toon = preload("res://scripts/toon.gd")
const Character = preload("res://scripts/character.gd")
const MODEL = preload("res://assets/kaykit/Rogue_Hooded.glb")

signal dash_finished
signal landed  # fin d'un bond (ensō)

const DASH_SPEED := 34.0
const RADIUS := 0.35

var max_hp := 5
var speed_mult := 1.0  # bonus de vitesse de ruée (pouvoirs)
# techniques des formes de trait : pendant ces mouvements le héros ne peut pas être touché
var spinning := 0.0
var guard_t := 0.0
var _leap_t := -1.0
var _leap_dur := 0.4
var _leap_from := Vector3.ZERO
var _leap_to := Vector3.ZERO
var hp := 5
var dashing := false
var dead := false
var invuln := 0.0  # invincibilité après un coup reçu (temps de jeu)
var path := PackedVector3Array()
var path_i := 0
var facing := Vector3(0, 0, -1)

var body: Node3D
var ch: Node3D
var _lean := 0.0
var _flash := 0.0


func _ready() -> void:
	Toon.disc(self, 0.42, Color(0, 0, 0, 0.12))
	body = Node3D.new()
	add_child(body)
	ch = Character.new()
	body.add_child(ch)
	ch.setup(MODEL, 1.75, [
		["Cape", load("res://assets/kaykit/tex/rogue_cape.png")],
		["Rogue", load("res://assets/kaykit/tex/rogue_ink.png")],
	], ["Knife", "Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Throwable"])
	ch.attach("handslot.r", _katana())


func _katana() -> Node3D:
	# lame légèrement courbe, tsuba dorée, poignée d'encre
	var k := Node3D.new()
	var dark := Toon.mat(Toon.SUMI)
	Toon.part(k, Toon.box(Vector3(0.05, 0.24, 0.05)), dark, Vector3(0, 0.0, 0))
	var guard := Toon.part(k, Toon.cyl(0.07, 0.07, 0.025), Toon.mat(Toon.GOLD), Vector3(0, 0.13, 0))
	guard.rotation = Vector3.ZERO
	var blade := Toon.part(k, Toon.box(Vector3(0.03, 0.85, 0.065)), Toon.mat(Toon.FOAM, true, 0.015), Vector3(0, 0.57, 0.015))
	blade.rotation.x = 0.06
	return k


func start_dash(p: PackedVector3Array) -> void:
	if p.size() < 2 or dead:
		return
	if not dashing:
		ch.play_once("1H_Melee_Attack_Slice_Horizontal", 2.6)
	path = p
	path_i = 1
	dashing = true


## Arrête net la ruée (bouclier, ricochet).
func stop_dash() -> void:
	if dashing:
		dashing = false
		path_i = path.size()
		dash_finished.emit()


## Toupie (boucle) : le héros tourne sur lui-même, sabre tendu.
func spin(d: float) -> void:
	spinning = d
	ch.play_once("2H_Melee_Attack_Spinning", 1.8)


## Garde (retour) : posture de parade, intouchable un instant.
func guard(d: float) -> void:
	guard_t = d
	ch.play_once("Block", 1.2)


## Bond (ensō) : saut en cloche vers `to`, signal `landed` à l'atterrissage.
func leap(to: Vector3, d: float) -> void:
	_leap_from = position
	_leap_to = Vector3(to.x, 0, to.z)
	_leap_t = 0.0
	_leap_dur = d
	face(_leap_to - position)
	ch.play_once("Jump_Full_Short", 1.6)


## Estoc (crochet) : demi-tour et coup d'estoc.
func stab(dir: Vector3) -> void:
	face(dir)
	snap_facing()
	ch.play_once("1H_Melee_Attack_Stab", 2.2)


## Vrai pendant une technique qui protège (toupie, garde, bond).
func protected() -> bool:
	return spinning > 0.0 or guard_t > 0.0 or _leap_t >= 0.0


func dash_end() -> Vector3:
	if dashing and path.size() > 0:
		return path[path.size() - 1]
	return position


func face(dir: Vector3) -> void:
	dir.y = 0
	if dir.length_squared() < 0.0001:
		return
	facing = dir.normalized()


func snap_facing() -> void:
	body.rotation.y = atan2(-facing.x, -facing.z)


func hurt() -> void:
	hp -= 1
	invuln = 1.2
	_flash = 0.15
	if hp <= 0:
		dead = true
		ch.hold()
		ch.play_once("Death_A", 1.0)
	else:
		ch.play_once("Hit_A", 1.4)


## Annule toupie, garde et bond (changement de salle).
func cancel_moves() -> void:
	spinning = 0.0
	guard_t = 0.0
	_leap_t = -1.0
	body.position.y = 0.0


func _process(delta: float) -> void:
	if dashing:
		var move := DASH_SPEED * speed_mult * delta
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

	# techniques
	if spinning > 0.0:
		spinning -= delta
		body.rotation.y += delta * 26.0
	if guard_t > 0.0:
		guard_t -= delta
	if _leap_t >= 0.0:
		_leap_t += delta
		var k := clampf(_leap_t / _leap_dur, 0.0, 1.0)
		var p := _leap_from.lerp(_leap_to, k)
		position = Vector3(p.x, 0, p.z)
		body.position.y = sin(PI * k) * 2.4
		if k >= 1.0:
			_leap_t = -1.0
			body.position.y = 0.0
			landed.emit()

	if invuln > 0.0 and not dead:
		invuln -= delta
		body.visible = dashing or fmod(invuln, 0.16) > 0.07
	else:
		body.visible = true
	if _flash > 0.0:
		_flash -= delta
		ch.set_flash(1.0 if _flash > 0.0 else 0.0)

	# orientation et posture
	var target_rot := atan2(-facing.x, -facing.z)
	if spinning <= 0.0:
		body.rotation.y = lerp_angle(body.rotation.y, target_rot, minf(1.0, delta * (40.0 if dashing else 14.0)))
	_lean = lerpf(_lean, 1.0 if dashing else 0.0, minf(1.0, delta * 25.0))
	body.rotation.x = -0.35 * _lean
