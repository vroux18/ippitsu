extends "res://scripts/boss_mini_base.gd"
## Mini-boss du monde 3 (Cent Contes) — Yuki-onna, la femme des neiges (24 PV × monde), flotte.
##  Le voile de givre est son bouclier (10) : un coup ne fait qu'effleurer.
##  Souffle glacé : cône 70° sur 6 m annoncé 1.1 s. Il laisse un SENTIER DE GIVRE de 5 cristaux,
##  du plus petit (loin d'elle) au plus grand (à ses pieds), pendant 4.5 s.
##  Mécanique de trait : trancher les cristaux DANS L'ORDRE, du petit au grand, en un seul trait
##  (au moins 4 dans l'ordre) brise tout le voile : figée 5.5 s, vulnérable (dégâts ×2). Dans le
##  désordre (2 cristaux ou plus) : un éclat de voile par cristal et le sentier fond.
##  Prépare la colonne de Gashadokuro. Puis : salve de 3 boules de neige (lueur 0.7 s).

const MAGE = preload("res://assets/kaykit/Skeleton_Mage.glb")
const ICE := Color("#BFD6E3")
const SNOW := Color("#F3F5F7")
const LAVENDER := Color("#8C8FA8")
const CRYSTALS := 5
const CRYS_NEAR := 1.5  # distance du plus grand cristal
const CRYS_STEP := 1.1
const CRYS_HIT := 0.8  # distance trait-cristal pour le toucher
const ORDER_MIN := 4
const SHIELD := 10.0
const CRYS_CHIP := 0.8  # voile ébréché par cristal pris dans le désordre
const BREATH_HALF := 0.61  # 35° de part et d'autre
const BREATH_LEN := 6.0
const BREATH_TELE := 1.1
const PATH_TIME := 4.5
const VOLLEY_TELE := 0.7
const HOVER := 0.5

var _veil: Node3D
var _crys: Array = []  # {node, spike, pos, lit}, du plus petit (0) au plus grand
var _order: Array = []
var _seen := {}
var _breath_dir := Vector3(0, 0, 1)
var _glow := 0.3
var _death_played := false


func _ready() -> void:
	title = "Yuki-onna"
	hp = 24.0 * max_hp_mult
	max_hp = hp
	radius = 0.8
	_build()
	_shield_init(SHIELD, Vector3(1.15, 1.6, 1.15), 1.35)
	_state = "spawn"
	_timer = 1.2


# ------------------------------------------------------------------ construction

func _build() -> void:
	Toon.disc(self, 0.8, Color(0, 0, 0, 0.12))
	body = Node3D.new()
	add_child(body)
	# kimono blanc sans pieds : un pan qui s'évase vers le sol, ourlet lavande, obi bleu de Prusse
	Toon.part(body, Toon.cyl(0.3, 0.6, 1.15, 10), Toon.mat_shared(SNOW), Vector3(0, 0.62, 0))
	Toon.part(body, Toon.cyl(0.61, 0.52, 0.06, 10), Toon.mat_shared(LAVENDER), Vector3(0, 0.07, 0))
	Toon.part(body, Toon.cyl(0.32, 0.34, 0.14, 10), Toon.mat_shared(Toon.PRUSSIAN), Vector3(0, 1.08, 0))
	ch = Character.new()
	body.add_child(ch)
	ch.position = Vector3(0, 1.1, 0)
	var tex: Texture2D = load("res://assets/kaykit/tex/skeleton_prussian.png")
	ch.setup(MAGE, 1.45, [["Body", tex]], ["Skeleton_Mage_Hat", "Skeleton_Mage_LegLeft", "Skeleton_Mage_LegRight"], ICE)
	ch.idle = "Idle"
	ch.play("Idle")
	_ghostify()
	# longs cheveux noirs dans le dos
	Toon.part(body, Toon.box(Vector3(0.5, 1.25, 0.1)), Toon.mat_shared(Toon.SUMI), Vector3(0, 1.85, 0.28))
	# voile de givre
	_veil = Node3D.new()
	body.add_child(_veil)
	Toon.part(_veil, Toon.sphere(1.0), Toon.flat(Color(ICE, 0.3)), Vector3(0, 1.35, 0), Vector3(0.95, 1.45, 0.95))
	for k in 6:
		var a := TAU * float(k) / 6.0
		var flake := Toon.part(_veil, Toon.box(Vector3(0.05, 0.05, 0.32)), Toon.flat(Color(SNOW, 0.9)), Vector3(cos(a) * 0.95, 1.35 + 0.5 * sin(a * 2.0), sin(a) * 0.95))
		flake.rotation.y = -a
	_make_stars(body, 2.75)
	body.scale = Vector3.ONE * 0.01


## Rendu fantôme : lueur glacée, matériaux translucides (comme les noyés).
func _ghostify() -> void:
	for n in ch.model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i) as StandardMaterial3D
			if m == null:
				continue
			m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED  # opaque : plus de scintillement
			m.albedo_color.a = 0.8
			var o := m.next_pass as StandardMaterial3D
			if o != null:
				o.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				o.albedo_color.a = 0.55


func _spawn_path() -> void:
	_clear_path(false)
	var me := Vector3(position.x, 0, position.z)
	for i in CRYSTALS:
		# 0 = le plus loin (petit), CRYSTALS - 1 = à ses pieds (grand)
		var dist := CRYS_NEAR + CRYS_STEP * float(CRYSTALS - 1 - i)
		var p := me + _breath_dir * dist
		p = Vector3(clampf(p.x, -HALF.x + 0.5, HALF.x - 0.5), 0, clampf(p.z, -HALF.y + 0.5, HALF.y - 0.5))
		var n := Node3D.new()
		n.top_level = true
		add_child(n)
		n.global_position = p
		var size := 0.45 + 0.17 * float(i)
		Toon.disc(n, 0.3 + 0.12 * float(i), Color(ICE, 0.45), 0.02)
		var spike := Node3D.new()
		n.add_child(spike)
		Toon.part(spike, Toon.cyl(0.0, 0.22, 1.0, 5), Toon.mat_shared(ICE), Vector3(0, 0.5, 0))
		var side := Toon.part(spike, Toon.cyl(0.0, 0.12, 0.6, 5), Toon.mat_shared(SNOW), Vector3(0.16, 0.28, 0.05))
		side.rotation.z = -0.5
		spike.scale = Vector3.ONE * size
		_crys.append({"node": n, "spike": spike, "pos": p, "lit": false, "size": size})


## Le sentier fond (ou éclate vers elle si `burst`).
func _clear_path(burst: bool) -> void:
	for c: Dictionary in _crys:
		var n: Node3D = c["node"]
		if is_instance_valid(n):
			var p: Vector3 = c["pos"]
			main.splash(p + Vector3(0, 0.5, 0), ICE if burst else SNOW, 8 if burst else 4)
			n.queue_free()
	_crys.clear()
	_order = []
	_seen = {}


# ------------------------------------------------------------------ interface avec main

func check_dash(a: Vector3, b: Vector3, stroke_id: int) -> bool:
	if dead:
		return false
	if _state == "path" and hero.dashing:
		_crys_touch(a, b)
	if _state == "spawn" or _state == "dying":
		return false
	# figée : coup plein (×2) ; sous le voile de givre : il effleure et use le voile
	if _last_stroke != stroke_id and _seg_dist(position, a, b) < radius + 0.55:
		_last_stroke = stroke_id
		return true
	return false


## Fin du trait : les cristaux pris du petit au grand brisent le voile.
func end_stroke(_stroke_id: int) -> void:
	if not dead and _state == "path":
		# la dernière image de la ruée n'est pas forcément passée par check_dash
		var pa: Vector3 = main._prev_hero
		_crys_touch(pa, hero.position)
	var order: Array = _order
	_order = []
	_seen = {}
	for c: Dictionary in _crys:
		c["lit"] = false
	if dead or _state != "path" or order.size() < 2:
		# un seul cristal effleuré : rien ne se passe
		return
	if _lis(order) >= ORDER_MIN:
		_shatter()
		return
	# dans le désordre : le givre se brise, le voile n'est qu'ébréché
	var last: Dictionary = _crys[int(order[order.size() - 1])]
	var lp: Vector3 = last["pos"]
	main.clang(lp)
	_clear_path(false)
	_start_volley()
	_shield_dmg(CRYS_CHIP * float(order.size()))


func _aoe_target(center: Vector3, reach: float) -> Vector3:
	if _state == "spawn" or _state == "dying":
		return Vector3.INF
	if Vector2(position.x - center.x, position.z - center.z).length() >= reach + radius:
		return Vector3.INF
	return position + Vector3(0, 1.0, 0)


func _zone_fire(z: Dictionary) -> void:
	if String(z["tag"]) != "breath":
		return
	# le souffle tombe : le héros dans le cône est gelé (1 coup)
	if _in_zone(z, hero.position, 0.2):
		main._hurt_hero()
	var o: Vector3 = z["c"]
	for k in 4:
		main.splash(o + _breath_dir * (1.5 + 1.4 * float(k)) + Vector3(0, 0.4, 0), SNOW, 6)
	main.shake = maxf(float(main.shake), 0.08)
	_spawn_path()
	_state = "path"
	_timer = PATH_TIME
	_glow = 0.3


func _on_die() -> void:
	_clear_path(true)
	_veil.visible = false


## Voile brisé : figée, plus d'attaque jusqu'à la fin de la fenêtre.
func _on_shield_break() -> void:
	_clear_zones()
	_clear_path(true)
	_state = "frozen"
	_glow = 0.3
	_veil.visible = false
	ch.play_once("Hit_A", 1.2)


func _on_shield_back() -> void:
	if _state != "frozen":
		return
	_state = "reform"
	_timer = 0.6
	_veil.visible = true
	_veil.scale = Vector3.ONE * 0.05


# ------------------------------------------------------------------ boucle

func _step(delta: float) -> void:
	var to := hero.position - position
	to.y = 0
	var dist := to.length()
	var dir := _dir_to_hero()
	match _state:
		"spawn":
			_timer -= delta
			body.scale = Vector3.ONE * clampf(1.0 - _timer / 1.2, 0.01, 1.0)
			if _timer <= 0.0:
				body.scale = Vector3.ONE
				_state = "drift"
				_timer = 1.2
		"drift":
			# glisse pour garder ses distances, plutôt dans la moitié haute
			var side := Vector3(-dir.z, 0, dir.x) * sin(_t * 0.7)
			var want := -1.0 if dist < 4.5 else (1.0 if dist > 6.5 else 0.0)
			var up := Vector3(0, 0, -1.0 if position.z > -1.5 else (1.0 if position.z < -6.5 else 0.0))
			position += (dir * want + side * 0.8 + up * 0.6) * 1.6 * delta
			main.clamp_to_arena(self, radius)
			_face(dir, delta)
			_timer -= delta
			if _timer <= 0.0:
				_breath_dir = dir
				_zone_fan(position, _breath_dir, BREATH_HALF, BREATH_LEN, BREATH_TELE, "breath")
				ch.play_once("Spellcast_Shoot", ch.length("Spellcast_Shoot") * 0.55 / BREATH_TELE)
				_state = "breath"
				_timer = BREATH_TELE
		"breath":
			_face(_breath_dir, delta, 8.0)
			_timer -= delta
			_glow = 0.3 + 0.9 * clampf(1.0 - _timer / BREATH_TELE, 0.0, 1.0)
		"path":
			_face(dir, delta, 3.0)
			_timer -= delta
			if _timer <= 0.0:
				_clear_path(false)
				_start_volley()
		"volley":
			_face(dir, delta, 6.0)
			_timer -= delta
			_glow = 0.3 + 0.8 * clampf(1.0 - _timer / VOLLEY_TELE, 0.0, 1.0)
			if _timer <= 0.0:
				_glow = 0.3
				for i in 3:
					var d := dir.rotated(Vector3.UP, deg_to_rad(-15.0 + 15.0 * float(i)))
					main.spawn_bullet(position + Vector3(0, 1.5, 0) + d * 0.9, d)
				_state = "drift"
				_timer = 1.6 if hp > max_hp * 0.5 else 1.1
		"frozen":
			# figée : la fin de la fenêtre (vulnerable_t) reforme le voile (_on_shield_back)
			pass
		"reform":
			_timer -= delta
			_veil.scale = Vector3.ONE * clampf(1.0 - _timer / 0.6, 0.05, 1.0)
			if _timer <= 0.0:
				_veil.scale = Vector3.ONE
				_state = "drift"
				_timer = 1.0
		"dying":
			_timer += delta
			if not _death_played:
				_death_played = true
				ch.hold()
				ch.play_once("Death_A", 1.0, 0.05)
			# elle se dissout en neige qui monte
			body.scale = Vector3.ONE * clampf(1.0 - (_timer - 0.8) / 1.2, 0.01, 1.0)
			if int(_timer * 8.0) != int((_timer - delta) * 8.0) and _timer < 2.0:
				main.splash(position + Vector3(0, 1.0 + _timer, 0), SNOW, 4)
			if _timer > 2.2:
				queue_free()
	_animate(delta)


func _start_volley() -> void:
	_state = "volley"
	_timer = VOLLEY_TELE
	ch.play_once("Spellcast_Shoot", ch.length("Spellcast_Shoot") * 0.55 / VOLLEY_TELE)


## Le sentier pris dans l'ordre brise tout le voile.
func _shatter() -> void:
	main.float_text(position + Vector3(0, 1.6, 0), "雪", Toon.GOLD)
	main.big_hit(position + Vector3(0, 1.0, 0))
	main.splash(position + Vector3(0, 1.4, 0), ICE, 30)
	main.shake = maxf(float(main.shake), 0.69)
	_shield_dmg(shield_max)


func _crys_touch(a: Vector3, b: Vector3) -> void:
	var seg := b - a
	var found: Array = []
	for i in _crys.size():
		if _seen.has(i):
			continue
		var c: Dictionary = _crys[i]
		var p: Vector3 = c["pos"]
		if _seg_dist(p, a, b) < CRYS_HIT:
			var tt := 0.0
			if seg.length_squared() > 0.0001:
				tt = (p - a).dot(seg) / seg.length_squared()
			found.append([tt, i])
	# plusieurs cristaux dans un même segment : dans le sens de la ruée
	found.sort_custom(func(x, y): return x[0] < y[0])
	for f in found:
		var idx := int(f[1])
		_seen[idx] = true
		_order.append(idx)
		var c2: Dictionary = _crys[idx]
		c2["lit"] = true
		var p2: Vector3 = c2["pos"]
		main.small_hit(p2 + Vector3(0, 0.4, 0))


## Flottement, lueur glacée, cristaux qui pulsent du petit vers le grand.
func _animate(delta: float) -> void:
	if _state == "frozen":
		body.position.y = move_toward(body.position.y, 0.0, delta * 3.0)
		body.rotation.z = sin(_t * 12.0) * 0.05
	elif _state != "dying":
		body.position.y = HOVER + sin(_t * 2.0) * 0.12
		body.rotation.z = 0.0
		if _state != "spawn":
			body.scale = Vector3.ONE * (1.06 if _flash > 0.0 else 1.0)
	if _flash <= 0.0:
		ch.set_glow(_glow, ICE)
	for i in _crys.size():
		var c: Dictionary = _crys[i]
		var spike: Node3D = c["spike"]
		var s := float(c["size"])
		if bool(c["lit"]):
			spike.scale = Vector3.ONE * s * 1.3
		else:
			spike.scale = Vector3.ONE * s * (1.0 + 0.2 * maxf(0.0, sin(_t * 5.0 - float(i) * 0.9)))
		spike.rotation.y = _t * 0.6 + float(i)


# ------------------------------------------------------------------ robot testeur

## Sentier : placement au-delà du petit cristal (en les contournant), puis trait du petit au grand
## qui finit à travers elle (le voile tombe). Figée (vulnérable) : iaï à travers, encore et encore.
func bot_stroke(hero_pos: Vector3) -> PackedVector3Array:
	var none := PackedVector3Array()
	if dead:
		return none
	var h := Vector3(hero_pos.x, 0, hero_pos.z)
	var me := Vector3(position.x, 0, position.z)
	if _state == "frozen":
		if vulnerable_t < 0.3:
			return none
		return _bot_line(h, me, 7.3)
	if _state != "path" or _crys.size() < 2 or _timer < 0.4:
		return none
	var c0: Dictionary = _crys[0]
	var c1: Dictionary = _crys[1]
	var p0: Vector3 = c0["pos"]
	var p1: Vector3 = c1["pos"]
	var out := p0 - p1
	out.y = 0
	if out.length_squared() < 0.01:
		out = -_breath_dir
	var lead := _bot_clamp(p0 + out.normalized() * 1.3)
	if h.distance_to(lead) > 1.2:
		var avoid: Array = []
		for c: Dictionary in _crys:
			avoid.append(c["pos"])
		return _bot_route([h, lead], avoid, 1.0)
	var way: Array = [h]
	for c: Dictionary in _crys:
		way.append(c["pos"])
	var last: Vector3 = way[way.size() - 1]
	var fwd := me - last
	fwd.y = 0
	if fwd.length_squared() < 0.01:
		fwd = -out
	way.append(me)
	way.append(me + fwd.normalized() * 1.2)
	return _bot_dense(way)
