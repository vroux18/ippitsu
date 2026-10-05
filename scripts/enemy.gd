extends Node3D
## Squelettes de samouraï (KayKit) :
##  oni   — Minion : fonce sur le héros, frappe une zone annoncée par un disque qui se remplit
##  kappa — Mage : garde ses distances et lance de grosses boules lentes
##  brute — Warrior : grand, lent et costaud (il faut l'enchaîner dans un combo)
##  tate  — Warrior au grand bouclier rond : invulnérable de face (cône 120°), il faut le prendre à revers
##  funa  — Funa-yūrei, Minion noyé translucide : émerge au bord du ponton, lance une louche d'eau, replonge

const Toon = preload("res://scripts/toon.gd")
const Character = preload("res://scripts/character.gd")
const MINION = preload("res://assets/kaykit/Skeleton_Minion.glb")
const WARRIOR = preload("res://assets/kaykit/Skeleton_Warrior.glb")
const MAGE = preload("res://assets/kaykit/Skeleton_Mage.glb")

const SPAWN_TIME := 1.0
const HALF := Vector2(4.6, 8.6)  # demi-dimensions de l'arène (même valeur que main.HALF)
const EDGE_IN := 0.4  # funa : distance au bord du ponton

var kind := "oni"
var hp := 1.0
var speed := 2.0
var radius := 0.45
var hero: Node3D
var main: Node

var dead := false
var dummy := false  # mannequin du tutoriel : ne bouge pas, n'attaque pas
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
var _shadow: MeshInstance3D

# funa : cycle émerge → visible → plonge → caché
const FUNA_TINT := Color("#7FB2C8")
const FUNA_DEPTH := -1.2
const FUNA_EMERGE := 0.6
const FUNA_UP := 2.2
const FUNA_DIVE := 0.5
const FUNA_UNDER := 3.0
var _phase := "emerge"  # emerge | up | dive | under
var _ptimer := 0.0
var _shot := false
var _target := Vector3.ZERO


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
		"tate":
			hp = 2.0
			speed = 1.8
			radius = 0.55
			_zone_r = 1.0
			_windup = 1.0
			_walk = "Walking_A"
			ch.setup(WARRIOR, 1.9, [["Cloak", load("res://assets/kaykit/tex/skeleton_ink.png")], ["Helmet", load("res://assets/kaykit/tex/skeleton_gold.png")]])
			ch.attach("handslot.l", _shield())
			ch.attach("handslot.r", _blade(0.8, Color("#8A8F96")))
		"funa":
			hp = 1.0
			speed = 0.0
			radius = 0.45
			_zone_r = 1.2
			_windup = 1.1
			ch.setup(MINION, 1.6, [])
			ch.attach("handslot.r", _ladle())
			_ghostify()
	ch.idle = "Blocking" if kind == "tate" else "Idle_Combat"
	_shadow = Toon.disc(self, radius * 0.95, Color(0, 0, 0, 0.12))
	if kind == "funa":
		# pas d'apparition au sol : il sort de l'eau au bord du ponton
		_spawn = 0.0
		position = _nearest_edge(position)
		_start_emerge()
		return
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


## Grand bouclier rond : disque de bois aplati, bordure sumi, bosse dorée au centre.
func _shield() -> Node3D:
	var k := Node3D.new()
	var disc := Node3D.new()
	# l'axe du cylindre (Y) devient la normale du bouclier, tournée vers l'extérieur de la main
	disc.rotation.x = PI / 2.0
	disc.position = Vector3(0, 0.05, 0.08)
	k.add_child(disc)
	Toon.part(disc, Toon.cyl(0.46, 0.46, 0.05, 24), Toon.mat(Toon.SUMI, false), Vector3.ZERO)
	Toon.part(disc, Toon.cyl(0.4, 0.4, 0.07, 24), Toon.mat(Toon.WOOD, true, 0.02), Vector3.ZERO)
	# bosse dorée des deux côtés (l'orientation exacte de l'os de la main varie)
	Toon.part(disc, Toon.sphere(0.11), Toon.mat(Toon.GOLD, true, 0.02), Vector3(0, 0.04, 0), Vector3(1, 0.55, 1))
	Toon.part(disc, Toon.sphere(0.11), Toon.mat(Toon.GOLD, true, 0.02), Vector3(0, -0.04, 0), Vector3(1, 0.55, 1))
	return k


## Louche (hishaku) du noyé : manche de bois et petite coupe.
func _ladle() -> Node3D:
	var k := Node3D.new()
	Toon.part(k, Toon.cyl(0.02, 0.02, 0.8, 8), Toon.mat(Color("#4A3A2C")), Vector3(0, 0.3, 0))
	Toon.part(k, Toon.cyl(0.13, 0.1, 0.12, 12), Toon.mat(Toon.WOOD, true, 0.015), Vector3(0, 0.72, 0.08))
	return k


## Rendu fantôme : teinte bleutée et matériaux translucides.
func _ghostify() -> void:
	ch.set_glow(0.35, FUNA_TINT)
	for n in ch.model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i) as StandardMaterial3D
			if m == null:
				continue
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color.a = 0.75
			# contour d'encre lui aussi estompé
			var o := m.next_pass as StandardMaterial3D
			if o != null:
				o.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				o.albedo_color.a = 0.5


func _make_zone(fixed := false) -> void:
	_zone = Node3D.new()
	# zone fixe : reste à l'endroit visé, en coordonnées globales
	_zone.top_level = fixed
	add_child(_zone)
	Toon.disc(_zone, _zone_r, Color(Toon.VERMILION, 0.18), 0.03)
	_zone_fill = Toon.disc(_zone, _zone_r, Color(Toon.VERMILION, 0.45), 0.035)


func is_harmless() -> bool:
	if kind == "funa" and _phase != "up":
		return true
	return _spawn > 0.0 or dead


## Vrai si un coup venant dans la direction `dir` (ruée du héros) frappe le bouclier (cône frontal 120°).
func blocks(dir: Vector3) -> bool:
	if kind != "tate" or dead:
		return false
	var d := Vector3(dir.x, 0, dir.z)
	if d.length_squared() < 0.0001:
		return false
	var front := Vector3(-sin(body.rotation.y), 0, -cos(body.rotation.y))
	return d.normalized().dot(front) < -0.5


func take_hit(dmg: float, dir: Vector3) -> bool:
	hp -= dmg
	_flash = 0.12
	_knock = dir.normalized() * (3.0 if kind == "brute" else (4.5 if kind == "tate" else 7.0))
	if kind == "funa":
		_knock = Vector3.ZERO
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


## Zone d'attaque en préparation : [centre, rayon, temps restant], ou [] s'il n'y en a pas.
func danger_zone() -> Array:
	if _state == "windup" and _zone != null:
		if kind == "funa":
			return [_target, _zone_r, _timer]
		return [position + _strike_dir * (_zone_r * 0.9), _zone_r, _timer]
	return []


## Dégâts « indirects » (brûlure, foudre, feu) : pas de recul ni d'animation de coup.
func hurt_dot(dmg: float) -> bool:
	if dead or is_harmless():
		return false
	hp -= dmg
	_flash = maxf(_flash, 0.05)
	if hp <= 0.0:
		dead = true
		_cancel_attack()
		_timer = 0.0
		ch.hold()
		ch.play_once("Death_C_Skeletons", 1.6, 0.05)
		return true
	return false


func push(v: Vector3) -> void:
	if kind != "brute" and kind != "funa":
		_knock += v


func _cancel_attack() -> void:
	_state = "recover"
	_timer = 0.6
	main.free_token(self)
	if _zone:
		_zone.queue_free()
		_zone = null


func _process(delta: float) -> void:
	_t += delta
	if _flash > 0.0:
		_flash -= delta
		ch.set_flash(1.0 if _flash > 0.0 else 0.0)
		if _flash <= 0.0 and kind == "funa":
			ch.set_glow(0.35, FUNA_TINT)

	if dead:
		# projeté en tournoyant, puis s'effondre et s'enfonce dans le ponton
		if _timer < 0.35:
			body.rotation.y += delta * 22.0
			body.position.y = sin(_timer / 0.35 * PI) * 0.9
		elif body.position.y > 0.0 and _timer < 1.1:
			body.position.y = 0.0
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

	if kind == "funa":
		_ghost(delta)
		return

	if dummy:
		return

	var to_hero := hero.position - position
	to_hero.y = 0
	var dist := to_hero.length()
	var dir := to_hero / maxf(dist, 0.001)

	match kind:
		"oni", "brute", "tate":
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
				# chemin : par la passerelle si le héros est sur une autre plateforme
				var sd: Vector3 = main.steer_dir(position, hero.position)
				position += sd * speed * delta
				if sd != Vector3.ZERO:
					_face(sd, delta)
				ch.play(_walk, speed / 1.6)
			else:
				# tate : garde le bouclier levé à l'arrêt
				ch.play(ch.idle)
			if dist <= reach - 0.3:
				# jeton d'attaque : au plus N ennemis en préparation en même temps
				if not main.take_token(self):
					var around := Vector3(-dir.z, 0, dir.x) * (1.0 if get_instance_id() % 2 == 0 else -1.0)
					position += around * 1.0 * delta
					ch.play(_walk, 0.6)
					return
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
			# dernier instant : la zone flashe blanc écume
			(_zone_fill.material_override as StandardMaterial3D).albedo_color = Color(Toon.FOAM, 0.85) if _timer < 0.15 else Color(Toon.VERMILION, 0.45)
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
			if not main.take_token(self):
				_timer = 0.4
				return
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
			main.free_token(self)
			_state = "move"
			_timer = 2.6 + randf() * 1.2


# ------------------------------------------------------------------ funa

## Point du bord le plus proche de `p` (les noyés sortent de l'eau, jamais du milieu du ponton).
func _nearest_edge(p: Vector3) -> Vector3:
	var ex := HALF.x - EDGE_IN
	var ez := HALF.y - EDGE_IN
	var dx := HALF.x - absf(p.x)
	var dz := HALF.y - absf(p.z)
	if dx <= dz:
		return Vector3(ex * (1.0 if p.x >= 0.0 else -1.0), 0, clampf(p.z, -ez, ez))
	return Vector3(clampf(p.x, -ex, ex), 0, ez * (1.0 if p.z >= 0.0 else -1.0))


## Autre point du bord, loin de l'ancien et pas collé au héros.
func _random_edge() -> Vector3:
	var ex := HALF.x - EDGE_IN
	var ez := HALF.y - EDGE_IN
	var best := position
	for attempt in 20:
		var q := Vector3.ZERO
		# les grands côtés sont plus souvent choisis (proportion des longueurs)
		if randf() < HALF.y / (HALF.x + HALF.y):
			q = Vector3(ex * (1.0 if randf() < 0.5 else -1.0), 0, randf_range(-ez + 0.4, ez - 0.4))
		else:
			q = Vector3(randf_range(-ex + 0.4, ex - 0.4), 0, ez * (1.0 if randf() < 0.5 else -1.0))
		best = q
		if q.distance_to(position) > 3.0 and q.distance_to(hero.position) > 2.0:
			break
	return best


func _start_emerge() -> void:
	_phase = "emerge"
	_ptimer = FUNA_EMERGE
	_shot = false
	body.visible = true
	body.position.y = FUNA_DEPTH
	_shadow.visible = true
	_face_hero_now()
	ch.play("Idle_Combat")


func _face_hero_now() -> void:
	var to := hero.position - position
	if Vector2(to.x, to.z).length() > 0.01:
		body.rotation.y = atan2(-to.x, -to.z)


func _ghost(delta: float) -> void:
	_ptimer -= delta
	match _phase:
		"emerge":
			# monte depuis l'eau, intouchable
			_face_hero_now()
			body.position.y = lerpf(FUNA_DEPTH, 0.0, clampf(1.0 - _ptimer / FUNA_EMERGE, 0.0, 1.0))
			if _ptimer <= 0.0:
				body.position.y = 0.0
				_phase = "up"
				_ptimer = FUNA_UP
		"up":
			if _state != "windup":
				var to := hero.position - position
				to.y = 0
				_face(to, delta, 6.0)
			# une seule louche par sortie, lancée assez tôt pour finir avant de replonger
			if not _shot and _ptimer < FUNA_UP - 0.25 and _ptimer > _windup + 0.05:
				if main.take_token(self):
					_shot = true
					_state = "windup"
					_timer = _windup
					_target = Vector3(hero.position.x, 0, hero.position.z)
					_strike_dir = _target - position
					_make_zone(true)
					_zone.global_position = _target
					ch.play_once("Throw", ch.length("Throw") * 0.5 / _windup)
			if _state == "windup":
				var k := 1.0 - _timer / _windup
				_zone_fill.scale = Vector3(k, 1, k)
				# dernier instant : la zone flashe blanc écume
				(_zone_fill.material_override as StandardMaterial3D).albedo_color = Color(Toon.FOAM, 0.85) if _timer < 0.15 else Color(Toon.VERMILION, 0.45)
				_timer -= delta
				if _timer <= 0.0:
					main.enemy_strike(_target, _zone_r)
					_end_ghost_attack()
			if _ptimer <= 0.0:
				_end_ghost_attack()
				_phase = "dive"
				_ptimer = FUNA_DIVE
		"dive":
			body.position.y = lerpf(0.0, FUNA_DEPTH, clampf(1.0 - _ptimer / FUNA_DIVE, 0.0, 1.0))
			if _ptimer <= 0.0:
				_phase = "under"
				_ptimer = FUNA_UNDER
				body.visible = false
				_shadow.visible = false
		"under":
			if _ptimer <= 0.0:
				position = _random_edge()
				_start_emerge()


## Fin (ou abandon) de la louche : libère le jeton et efface la zone.
func _end_ghost_attack() -> void:
	if _state == "windup" or _zone != null:
		main.free_token(self)
	_state = "move"
	if _zone:
		_zone.queue_free()
		_zone = null
