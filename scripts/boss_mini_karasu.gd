extends "res://scripts/boss_mini_base.gd"
## Mini-boss du monde 6 (Kurama) — le chef des karasu-tengu (22 PV × monde).
##  Son manteau de plumes est son bouclier (10) : un coup ne fait qu'effleurer. Posé au sol, une BOUCLE
##  fermée tracée autour de lui (cercle or au sol) arrache tout le manteau : à terre 5.5 s, vulnérable
##  (dégâts ×2). En vol, il est hors d'atteinte. Prépare Sōjōbō (tornade tranchée, puis boucle).
##  Attaques : salve de plumes en éventail (lueur 0.8 s) ; envol puis piqué en ligne (bande annoncée
##  1.0 s, 12 m/s) qui le repose près du héros.

const WARRIOR = preload("res://assets/kaykit/Skeleton_Warrior.glb")
const Loop = preload("res://scripts/boss_loop.gd")
const FEATHER := Color("#1E1C22")
const FEATHER_HI := Color("#2E2A34")
const HINT_R := 2.1  # rayon conseillé de la boucle
const SHIELD := 10.0
const VOLLEY_TELE := 0.8
const DIVE_TELE := 1.0
const DIVE_SPEED := 12.0
const DIVE_W := 0.9  # demi-largeur de la bande du piqué
const SOAR_T := 0.7
const FLY_Y := 3.2

var _wings: Array = []  # pivots des ailes
var _cloak: Node3D
var _hint: Node3D
var _pts: Array = []  # Vector2 de la ruée depuis le dernier end_stroke
var _cycle := 0
var _dive_from := Vector3.ZERO
var _dive_to := Vector3.ZERO
var _dive_dir := Vector3(0, 0, 1)
var _fly := 0.0  # hauteur de vol (0 = posé)
var _death_played := false


func _ready() -> void:
	title = "Karasu-tengu"
	hp = 22.0 * max_hp_mult
	max_hp = hp
	radius = 1.0
	_build()
	_shield_init(SHIELD, Vector3(1.4, 1.8, 1.4), 1.4)
	_state = "spawn"
	_timer = 1.2


# ------------------------------------------------------------------ construction

func _build() -> void:
	Toon.disc(self, 1.0, Color(0, 0, 0, 0.16))
	body = Node3D.new()
	add_child(body)
	ch = Character.new()
	body.add_child(ch)
	var ink: Texture2D = load("res://assets/kaykit/tex/skeleton_ink.png")
	var red: Texture2D = load("res://assets/kaykit/tex/skeleton_red.png")
	ch.setup(WARRIOR, 2.6, [["Cloak", ink], ["Helmet", red]], [], Toon.GOLD)
	ch.idle = "Idle_Combat"
	ch.play("Idle_Combat")
	# tête de corbeau : bec d'or, tokin vermillon
	var beak := Toon.part(body, Toon.cyl(0.0, 0.13, 0.55, 6), Toon.mat(Toon.GOLD), Vector3(0, 2.25, -0.5))
	beak.rotation.x = -PI / 2.0
	Toon.part(body, Toon.box(Vector3(0.22, 0.18, 0.22)), Toon.mat(Toon.VERMILION), Vector3(0, 2.75, -0.1))
	# grandes ailes noires dans le dos
	for s in [-1.0, 1.0]:
		var sx := float(s)
		var pv := Node3D.new()
		body.add_child(pv)
		pv.position = Vector3(sx * 0.35, 1.9, 0.3)
		var wing := Toon.part(pv, Toon.box(Vector3(1.6, 0.08, 0.7)), Toon.mat(FEATHER), Vector3(sx * 0.8, 0, 0.1))
		wing.rotation.y = sx * 0.25
		for k in 4:
			var f := Toon.part(pv, Toon.box(Vector3(0.18, 0.06, 0.6)), Toon.mat(FEATHER_HI), Vector3(sx * (0.4 + 0.35 * float(k)), -0.05, 0.55))
			f.rotation.y = sx * 0.1 * float(k)
		_wings.append(pv)
	# manteau de plumes (le bouclier) : collerette de plumes sombres
	_cloak = Node3D.new()
	body.add_child(_cloak)
	_cloak.position = Vector3(0, 1.6, 0)
	for k in 10:
		var a := TAU * float(k) / 10.0
		var pl := Toon.part(_cloak, Toon.box(Vector3(0.22, 0.9, 0.06)), Toon.mat(FEATHER), Vector3(cos(a) * 0.62, -0.2, sin(a) * 0.62))
		pl.rotation = Vector3(0.25, PI * 0.5 - a, 0.0)
	_hint = Loop.hint_ring(self, HINT_R, Toon.GOLD)
	_make_stars(body, 3.0)
	body.scale = Vector3.ONE * 0.01


# ------------------------------------------------------------------ interface avec main

func check_dash(a: Vector3, b: Vector3, stroke_id: int) -> bool:
	if dead:
		return false
	if hero.dashing and _grounded():
		Loop.record(_pts, a, b)
	if not _hittable():
		return false
	# à terre : coup plein (×2) ; dans son manteau : il effleure et use les plumes
	if _last_stroke != stroke_id and _seg_dist(position, a, b) < radius + 0.55:
		_last_stroke = stroke_id
		return true
	return false


## Fin du trait : une boucle fermée autour de lui, posé, arrache le manteau.
func end_stroke(_stroke_id: int) -> void:
	if not dead and not _pts.is_empty():
		# la dernière image de la ruée n'est pas forcément passée par check_dash
		var pa: Vector3 = main._prev_hero
		Loop.record(_pts, pa, hero.position)
	var pts: Array = _pts
	_pts = []
	if dead or pts.size() < 6 or vulnerable_t > 0.0 or not _grounded():
		return
	var loop := Loop.find_loop(pts, Vector2(position.x, position.z))
	if loop.size() < 3:
		return
	_tear()


func touching_hero(p: Vector3) -> bool:
	if dead or _state != "rush" or _fly > 1.2:
		return false
	return Vector2(p.x - position.x, p.z - position.z).length() < radius + 0.35


func _extra_danger(p: Vector3, _eta: float) -> bool:
	if _state != "rush":
		return false
	return _seg_dist(p, position, _dive_to) < DIVE_W + DANGER_MARGIN


func _aoe_target(center: Vector3, reach: float) -> Vector3:
	if not _hittable():
		return Vector3.INF
	if Vector2(position.x - center.x, position.z - center.z).length() >= reach + radius:
		return Vector3.INF
	return position + Vector3(0, 1.4, 0)


func _zone_fire(z: Dictionary) -> void:
	if String(z["tag"]) == "dive":
		_state = "rush"
		ch.play("Walking_D_Skeletons", 2.6)


func _on_die() -> void:
	_cloak.visible = false
	_hint.visible = false
	ch.set_glow(0.0)


## Manteau arraché : à terre, plus d'attaque jusqu'à la fin de la fenêtre.
func _on_shield_break() -> void:
	_clear_zones()
	ch.set_glow(0.0)
	_state = "torn"
	_cloak.visible = false
	ch.play_once("Hit_A", 1.2)


func _on_shield_back() -> void:
	if _state != "torn":
		return
	_state = "regrow"
	_timer = 0.6
	_cloak.visible = true
	_cloak.scale = Vector3.ONE * 0.05


func _sh_hidden() -> bool:
	return _fly > 1.0


# ------------------------------------------------------------------ boucle

func _step(delta: float) -> void:
	var dir := _dir_to_hero()
	match _state:
		"spawn":
			_timer -= delta
			body.scale = Vector3.ONE * clampf(1.0 - _timer / 1.2, 0.01, 1.0)
			if _timer <= 0.0:
				body.scale = Vector3.ONE
				_state = "perch"
				_timer = 1.6
		"perch":
			_face(dir, delta, 4.0)
			_fly = move_toward(_fly, 0.0, delta * 6.0)
			_timer -= delta
			if _timer <= 0.0:
				_cycle += 1
				if _cycle % 2 == 1:
					_state = "volley"
					_timer = VOLLEY_TELE
					ch.play_once("1H_Melee_Attack_Slice_Horizontal", 0.8)
				else:
					_state = "soar"
					_timer = SOAR_T
					main.splash(position + Vector3(0, 0.5, 0), FEATHER, 10)
		"volley":
			_face(dir, delta, 4.0)
			_timer -= delta
			if _flash <= 0.0:
				ch.set_glow(0.55 * clampf(1.0 - _timer / VOLLEY_TELE, 0.0, 1.0), Toon.VERMILION)
			if _timer <= 0.0:
				ch.set_glow(0.0)
				# plumes en éventail (plus nombreuses quand il faiblit)
				var n := 5 if hp > max_hp * 0.5 else 7
				var spread := deg_to_rad(60.0 if n == 5 else 84.0)
				for i in n:
					var ang := -spread * 0.5 + spread * float(i) / float(n - 1)
					var d := dir.rotated(Vector3.UP, ang)
					main.spawn_bullet(position + Vector3(0, 1.4, 0) + d * 1.2, d)
				_state = "perch"
				_timer = 2.6 if hp > max_hp * 0.5 else 2.2
		"soar":
			_timer -= delta
			_fly = lerpf(FLY_Y, 0.0, clampf(_timer / SOAR_T, 0.0, 1.0))
			if _timer <= 0.0:
				_start_dive()
		"dive":
			# en l'air au-dessus du départ : la bande se remplit (_zone_fire lance le piqué)
			_face(_dive_dir, delta, 8.0)
			_fly = FLY_Y
		"rush":
			var left := Vector2(_dive_to.x - position.x, _dive_to.z - position.z).length()
			var mv := DIVE_SPEED * delta
			var total := maxf(Vector2(_dive_to.x - _dive_from.x, _dive_to.z - _dive_from.z).length(), 0.01)
			if left <= mv:
				_land()
			else:
				position += _dive_dir * mv
				_fly = FLY_Y * clampf(left / total, 0.0, 1.0)
		"torn":
			_fly = move_toward(_fly, 0.0, delta * 6.0)
		"regrow":
			_timer -= delta
			_cloak.scale = Vector3.ONE * clampf(1.0 - _timer / 0.6, 0.05, 1.0)
			if _timer <= 0.0:
				_cloak.scale = Vector3.ONE
				_state = "perch"
				_timer = 1.4
		"dying":
			_timer += delta
			if not _death_played:
				_death_played = true
				ch.hold()
				ch.play_once("Death_C_Skeletons", 1.2, 0.05)
			_fly = move_toward(_fly, 0.0, delta * 4.0)
			body.position.y = _fly - maxf(_timer - 1.4, 0.0) * 1.5
			if _timer > 2.2:
				queue_free()
	_animate()


## Piqué : du point d'envol vers le héros (un peu au-delà), bande annoncée au sol.
func _start_dive() -> void:
	_dive_from = Vector3(position.x, 0, position.z)
	var d := Vector3(hero.position.x, 0, hero.position.z) - _dive_from
	var l := d.length()
	_dive_dir = d / l if l > 0.3 else _dir_to_hero()
	var e := _dive_from + _dive_dir * clampf(l + 1.5, 3.0, 9.0)
	_dive_to = Vector3(clampf(e.x, -HALF.x + 1.0, HALF.x - 1.0), 0, clampf(e.z, -HALF.y + 1.0, HALF.y - 1.0))
	var v := _dive_to - _dive_from
	var vl := v.length()
	if vl < 1.0:
		_land()
		return
	_dive_dir = v / vl
	_zone_rect(_dive_from + v * 0.5, _dive_dir, DIVE_W, vl * 0.5, DIVE_TELE, "dive", Vector2(0, -1))
	_state = "dive"


## Il se pose au bout du piqué : la fenêtre pour la boucle.
func _land() -> void:
	position = Vector3(_dive_to.x, 0, _dive_to.z)
	main.clamp_to_arena(self, radius)
	_fly = 0.0
	_state = "perch"
	_timer = 2.8 if hp > max_hp * 0.5 else 2.3
	main.splash(position + Vector3(0, 0.4, 0), FEATHER, 12)
	main.vfx.ring(Vector3(position.x, 0.08, position.z), Toon.SUMI, 1.4)
	ch.play("Idle_Combat")


func _grounded() -> bool:
	return _state == "perch" or _state == "volley" or _state == "regrow"


func _hittable() -> bool:
	return not (_state in ["spawn", "soar", "dive", "rush", "dying"])


## La boucle arrache tout le manteau : le bouclier tombe d'un coup.
func _tear() -> void:
	main.float_text(position + Vector3(0, 1.6, 0), "円", Toon.GOLD)
	main.big_hit(position + Vector3(0, 1.0, 0))
	main.splash(position + Vector3(0, 1.4, 0), FEATHER, 26)
	main.shake = maxf(float(main.shake), 0.4)
	_shield_dmg(shield_max)


## Vol, ailes qui battent, cercle-guide quand il est posé.
func _animate() -> void:
	if _state != "dying":
		body.position.y = _fly
	var flying := _state == "soar" or _state == "dive" or _state == "rush"
	var amp := 0.6 if flying else 0.12
	var rate := 12.0 if flying else 2.5
	for i in _wings.size():
		var pv: Node3D = _wings[i]
		var sx := -1.0 if i % 2 == 0 else 1.0
		pv.rotation.z = sx * (0.25 + sin(_t * rate) * amp)
	_hint.visible = _state == "perch" or _state == "volley"
	_hint.rotation.y = _t * 0.4
	if _state == "torn":
		body.rotation.z = sin(_t * 12.0) * 0.06
	elif _state != "dying":
		body.rotation.z = 0.0
	if _state != "spawn" and _state != "dying":
		body.scale = Vector3.ONE * (1.08 if _flash > 0.0 else 1.0)


# ------------------------------------------------------------------ robot testeur

## Posé : placement sur le cercle-guide, puis boucle de 400° autour de lui (le manteau tombe) ;
## à terre (vulnérable) : iaï à travers, encore et encore.
func bot_stroke(hero_pos: Vector3) -> PackedVector3Array:
	var none := PackedVector3Array()
	if dead:
		return none
	var h := Vector3(hero_pos.x, 0, hero_pos.z)
	var c := Vector3(position.x, 0, position.z)
	if _state == "torn":
		if vulnerable_t < 0.3:
			return none
		return _bot_line(h, c, 7.3)
	if _state != "perch" and _state != "volley":
		return none
	return _bot_loop(h, c, HINT_R)


## Boucle autour de c (rayon r) : d'abord se placer sur le cercle, puis 400° d'un seul trait.
func _bot_loop(h: Vector3, c: Vector3, r: float) -> PackedVector3Array:
	var off := h - c
	var d := off.length()
	var phi := atan2(off.z, off.x) if d > 0.05 else PI * 0.5
	if d < r - 0.6 or d > r + 0.6:
		for k in [0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6]:
			var th := phi + deg_to_rad(30.0) * float(k)
			var q := c + Vector3(cos(th), 0, sin(th)) * r
			if _bot_inside(q, 0.25):
				return _bot_dense([h, q])
		return PackedVector3Array()
	var way: Array = [h]
	for i in range(0, 41):
		var th2 := phi + deg_to_rad(400.0) * float(i) / 40.0
		way.append(c + Vector3(cos(th2), 0, sin(th2)) * r)
	return _bot_dense(way)
