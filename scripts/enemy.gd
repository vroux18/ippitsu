extends Node3D
## Squelettes de samouraï (KayKit) :
##  oni   — Minion : fonce sur le héros, frappe une zone annoncée par un disque qui se remplit
##  kappa — Mage : garde ses distances et lance de grosses boules lentes
##  brute — Warrior : grand, lent et costaud (il faut l'enchaîner dans un combo)
##  tate  — Warrior au grand bouclier rond : invulnérable de face (cône 120°), il faut le prendre à revers
##  funa  — Funa-yūrei, Minion noyé translucide : émerge au bord du ponton, lance une louche d'eau, replonge
## Ennemis signature (un par monde) :
##  umibozu     — (1) moine de mer : plonge sous les planches, ressurgit sous le héros (disque annoncé), touchable seulement émergé
##  kitsunebi   — (2) feu-follet renard : se téléporte sur une zone annoncée ; à sa mort il se scinde en deux kitsunebi_s
##  yukionna    — (3) fantôme des neiges : gèle une bande annoncée ; la glace freine la ruée qui la traverse
##  kasha       — (4) chat-charrette en feu : charge en ligne droite (couloir annoncé), laisse une traînée de feu
##  kagebo      — (5) double d'encre : rejoue plus tard le dernier trait du héros, tourné vers lui (chemin annoncé)

const Toon = preload("res://scripts/toon.gd")
const Character = preload("res://scripts/character.gd")
const MINION = preload("res://assets/kaykit/Skeleton_Minion.glb")
const WARRIOR = preload("res://assets/kaykit/Skeleton_Warrior.glb")
const MAGE = preload("res://assets/kaykit/Skeleton_Mage.glb")
const ROGUE = preload("res://assets/kaykit/Rogue_Hooded.glb")

const SPAWN_TIME := 1.0
const HALF := Vector2(4.6, 8.6)  # demi-dimensions de l'arène (même valeur que main.HALF)
const EDGE_IN := 0.4  # funa : distance au bord du ponton

var _steer := Vector3.ZERO
var _stagger := 0.0  # tate : garde ouverte après un coup bloqué
var _steer_t := 0.0
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
var _deco: Node3D  # accessoires posés sur le corps (oreilles, roues…), cachés pendant l'apparition
var _glow_a := 0.0  # lueur de base (fantômes, feu)
var _glow_c := Toon.VERMILION

# attaque
var _state := "move"  # move | windup | charge | recover
var _timer := 0.0
var _windup := 1.0
var _attack := "1H_Melee_Attack_Chop"
var _strike_dir := Vector3.FORWARD
var _zone: Node3D
var _tele: Node3D  # visuel partagé de l'annonce (vfx.tele_disc)
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

# umibōzu : sous les planches, il suit le héros puis ressurgit sous lui
const UMI_UP := 2.6
const UMI_UNDER := 1.4
const UMI_WINDUP := 1.0
const UMI_SWIM := 3.2
var _ripple_t := 0.0
var _waits := 0

# kitsune-bi
const FOX_FIRE := Color("#8FE3FF")
const FOX_PALE := Color("#FFF3D6")

# couloirs annoncés (yuki-onna, kasha, kagebō) : polyligne au sol + annonces rectangulaires
var _lane := PackedVector3Array()
var _lane_w := 1.2
var _teles: Array = []
var _li := 1
var _ctime := 0.0
var _cspeed := 10.0
var _hit_cd := 0.0

# yuki-onna : bande de givre
const ICE_C := Color("#BFE8FF")
const YUKI_W := 1.2
const YUKI_LEN := 9.0
const YUKI_WINDUP := 1.3
const ICE_TIME := 3.5
const ICE_SLOW := 0.45
var _ice: Node3D
var _ice_mat: StandardMaterial3D
var _ice_pts := PackedVector3Array()
var _ice_t := 0.0
var _slow_id := -1
var _slowed := false

# kasha : charge et traînée de feu
const KASHA_FIRE := Color("#FF5A1F")
const KASHA_W := 1.3
const KASHA_LEN := 8.5
const KASHA_WINDUP := 1.1
const KASHA_SPEED := 12.0
const FIRE_TIME := 2.0
var _wheels: Array = []
var _fire_a := Vector3.ZERO
var _fire_b := Vector3.ZERO
var _fire_t := 0.0

# kagebō : copie du dernier trait du héros
const KAGE_W := 1.0
const KAGE_MAX := 9.0
const KAGE_WINDUP := 1.3
const KAGE_SPEED := 14.0
var _rec := PackedVector3Array()
var _rec_id := -1


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
	_deco = Node3D.new()
	body.add_child(_deco)
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
		"umibozu":
			# moine de mer : crâne lisse bleu nuit, yeux d'or, perle lumineuse à la main
			hp = 1.5
			speed = 1.0
			radius = 0.5
			_zone_r = 1.0
			_walk = "Walking_A"
			ch.setup(MINION, 1.75, [["", load("res://assets/kaykit/tex/skeleton_prussian.png")]], [], Toon.GOLD)
			_tint(Color("#8FA6BA"), 1.0)
			ch.attach("handslot.r", _orb(0.12, Color("#9FE0FF")))
		"kitsunebi", "kitsunebi_s":
			# feu-follet renard : pâle et translucide, oreilles et queue, flamme bleue à la main
			var mini := kind == "kitsunebi_s"
			hp = 0.5 if mini else 1.5
			speed = 2.4 if mini else 1.8
			radius = 0.32 if mini else 0.42
			_zone_r = 0.7 if mini else 0.95
			_windup = 0.75 if mini else 0.9
			_walk = "Idle_Combat"
			var h := 0.95 if mini else 1.35
			ch.setup(MAGE, h, [["", load("res://assets/kaykit/tex/skeleton_gold.png")]], ["Skeleton_Mage_Hat"], FOX_FIRE)
			_tint(FOX_PALE, 0.85)
			_glow_a = 0.45
			_glow_c = FOX_FIRE
			ch.attach("handslot.r", _orb(0.1 if mini else 0.15, FOX_FIRE))
			_ears(h, Color("#F4EBDD"))
			var tail := Toon.part(_deco, Toon.capsule(0.1 * h, 0.55 * h), Toon.mat(Color("#F4EBDD")), Vector3(0, 0.3 * h, 0.22 * h))
			tail.rotation.x = 0.8
			_timer = randf_range(1.2, 2.0)
			if mini:
				_spawn = 0.4
		"yukionna":
			# femme des neiges : fantôme blanc bleuté, longue chevelure noire
			hp = 2.0
			speed = 1.5
			radius = 0.45
			_walk = "Walking_B"
			var hy := 1.85
			ch.setup(MAGE, hy, [], ["Skeleton_Mage_Hat"], Color("#7FD8FF"))
			_tint(Color("#E8F4FF"), 0.7)
			_glow_a = 0.3
			_glow_c = ICE_C
			Toon.part(_deco, Toon.box(Vector3(0.26 * hy, 0.5 * hy, 0.04 * hy)), Toon.mat(Toon.SUMI), Vector3(0, 0.68 * hy, 0.17 * hy))
			_timer = randf_range(1.5, 2.5)
		"kasha":
			# chat-charrette : squelette rouge, oreilles de chat, deux roues en feu
			hp = 2.5
			speed = 1.7
			radius = 0.6
			_walk = "Walking_A"
			var hk := 1.7
			ch.setup(WARRIOR, hk, [["Helmet", load("res://assets/kaykit/tex/skeleton_gold.png")], ["", load("res://assets/kaykit/tex/skeleton_red.png")]])
			_glow_a = 0.2
			_glow_c = KASHA_FIRE
			_ears(hk, Toon.SUMI)
			for s in [-1.0, 1.0]:
				var sx := float(s)
				var spin := Node3D.new()
				spin.position = Vector3(sx * 0.46, 0.36, 0.05)
				_deco.add_child(spin)
				var hub := Node3D.new()
				hub.rotation.z = PI / 2.0
				spin.add_child(hub)
				Toon.part(hub, Toon.cyl(0.34, 0.34, 0.07, 14), Toon.mat(Toon.WOOD, true, 0.02), Vector3.ZERO)
				Toon.part(hub, Toon.cyl(0.09, 0.09, 0.11, 10), Toon.mat(Toon.GOLD, true, 0.02), Vector3.ZERO)
				Toon.part(hub, Toon.box(Vector3(0.6, 0.075, 0.05)), Toon.mat(Toon.SUMI, false), Vector3.ZERO)
				_wheels.append(spin)
				main.vfx.burner(_deco, 0.22, 4, Vector3(sx * 0.46, 0.15, 0.05))
			_timer = randf_range(1.5, 2.5)
		"kagebo":
			# double d'encre : le ronin lui-même, noir et translucide
			hp = 2.0
			speed = 2.0
			radius = 0.45
			_walk = "Walking_A"
			ch.setup(ROGUE, 1.75, [["", load("res://assets/kaykit/tex/rogue_ink.png")]], ["Knife", "Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Throwable"])
			_tint(Color(0.3, 0.29, 0.34), 0.85)
			ch.attach("handslot.r", _blade(0.85, Toon.SUMI))
			_timer = randf_range(2.0, 3.0)
	# rythme un peu plus posé : marche -10 %, annonces des coups +15 %
	speed *= 0.9
	_windup *= 1.15
	if _glow_a > 0.0:
		_base_glow()
	ch.idle = "Blocking" if kind == "tate" else ("Idle" if kind == "kagebo" else "Idle_Combat")
	_shadow = Toon.disc(self, radius * 0.95, Color(0, 0, 0, 0.12))
	if kind == "funa":
		# pas d'apparition au sol : il sort de l'eau au bord du ponton
		_spawn = 0.0
		position = _nearest_edge(position)
		_start_emerge()
		return
	if kind == "umibozu":
		# il sort de l'eau sur place
		_spawn = 0.0
		_surface()
		return
	if kind == "kagebo" or kind == "kitsunebi_s":
		return  # apparition par mise à l'échelle (_process)
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


## Boule lumineuse tenue à la main (perle du moine, flamme du renard).
func _orb(r: float, c: Color) -> Node3D:
	var k := Node3D.new()
	Toon.part(k, Toon.sphere(r), main.vfx.glow_mat(c, 3.0), Vector3(0, 0.15, 0))
	return k


## Oreilles pointues (renard, chat) sur le haut du crâne.
func _ears(h: float, c: Color) -> void:
	for s in [-1.0, 1.0]:
		var sx := float(s)
		var e := Toon.part(_deco, Toon.cyl(0.0, 0.07 * h, 0.16 * h, 6), Toon.mat(c), Vector3(sx * 0.13 * h, 0.97 * h, 0.02 * h))
		e.rotation.z = -sx * 0.3


## Rendu fantôme : teinte bleutée et matériaux translucides.
func _ghostify() -> void:
	_glow_a = 0.35
	_glow_c = FUNA_TINT
	ch.set_glow(0.35, FUNA_TINT)
	_tint(Color.WHITE, 0.75)


## Teinte (multipliée à la texture) et transparence de tous les matériaux du modèle.
func _tint(c: Color, alpha: float) -> void:
	for n in ch.model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i) as StandardMaterial3D
			if m == null:
				continue
			m.albedo_color = Color(c.r, c.g, c.b, alpha)
			if alpha >= 1.0:
				continue
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS  # pas de scintillement entre les morceaux du modèle
			# contour d'encre lui aussi estompé
			var o := m.next_pass as StandardMaterial3D
			if o != null:
				o.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				o.albedo_color.a = alpha * 0.66


func _base_glow() -> void:
	ch.set_glow(_glow_a, _glow_c)


func _make_zone(fixed := false) -> void:
	_zone = Node3D.new()
	# zone fixe : reste à l'endroit visé, en coordonnées globales
	_zone.top_level = fixed
	add_child(_zone)
	_tele = main.vfx.tele_disc(_zone, _zone_r)


func is_harmless() -> bool:
	if (kind == "funa" or kind == "umibozu") and _phase != "up":
		return true
	return _spawn > 0.0 or dead


## Vrai si un coup venant dans la direction `dir` (ruée du héros) frappe le bouclier (cône frontal 120°).
func blocks(dir: Vector3) -> bool:
	if kind != "tate" or dead or _stagger > 0.0:
		return false
	var d := Vector3(dir.x, 0, dir.z)
	if d.length_squared() < 0.0001:
		return false
	var front := Vector3(-sin(body.rotation.y), 0, -cos(body.rotation.y))
	return d.normalized().dot(front) < -0.5


## Bouclier frappé : la garde s'ouvre un instant (le coup suivant passe).
func shield_break() -> void:
	_stagger = 1.4
	if _state == "windup":
		_cancel_attack()
	ch.play_once("Hit_A", 1.2)


func take_hit(dmg: float, dir: Vector3) -> bool:
	hp -= dmg
	_flash = 0.12
	_knock = dir.normalized() * (3.0 if kind == "brute" else (4.5 if kind == "tate" or kind == "kasha" else 7.0))
	if kind == "funa" or _state == "charge":
		_knock = Vector3.ZERO
	if _state == "windup" and kind != "brute":
		_cancel_attack()
	if hp <= 0.0:
		_die()
		# mort sobre : petit recul (~0.5 m), pas de vrille
		_knock = Vector3.ZERO if kind == "funa" else dir.normalized() * 4.0
		return true
	ch.play_once("Hit_A", 1.6)
	if kind == "umibozu":
		# touché sans être tranché net : il replonge aussitôt
		_phase = "dive"
		_ptimer = FUNA_DIVE
	return false


## Zone d'attaque en préparation : [centre, rayon, temps restant], ou [] s'il n'y en a pas.
func danger_zone() -> Array:
	if _state == "windup" and _zone != null:
		if kind == "funa" or kind == "umibozu" or kind == "kitsunebi" or kind == "kitsunebi_s":
			return [_target, _zone_r, _timer]
		if _lane.size() >= 2:
			return [_lane_closest(_probe()), _lane_w * 0.5, _timer]
		return [position + _strike_dir * (_zone_r * 0.9), _zone_r, _timer]
	if _fire_t > 0.0:
		# traînée de feu encore chaude
		return [_seg_closest(_probe(), _fire_a, _fire_b), 0.3, 0.0]
	return []


## Point à tester pour l'alerte d'arrivée : la fin du trait en cours, sinon le héros.
func _probe() -> Vector3:
	var s = main.stroke
	if main.touching and is_instance_valid(s):
		var p: Vector3 = s.last()
		return p
	return hero.position


## Dégâts « indirects » (brûlure, foudre, feu) : pas de recul ni d'animation de coup.
func hurt_dot(dmg: float) -> bool:
	if dead or is_harmless():
		return false
	hp -= dmg
	_flash = maxf(_flash, 0.05)
	if hp <= 0.0:
		_die()
		_knock = Vector3.ZERO
		return true
	return false


func _die() -> void:
	dead = true
	_cancel_attack()
	_timer = 0.0
	_thaw()
	_clear_ice()
	_fire_t = 0.0
	ch.hold()
	ch.play_once("Death_A" if kind == "kagebo" else "Death_C_Skeletons", 2.4, 0.05)
	if kind == "kitsunebi":
		call_deferred("_split")


func push(v: Vector3) -> void:
	# un mort n'est plus projeté (fin sobre)
	if kind != "brute" and kind != "funa" and not dead and _state != "charge":
		_knock += v


func _cancel_attack() -> void:
	_state = "recover"
	_timer = 0.6
	_base_glow()
	main.free_token(self)
	if _zone:
		_zone.queue_free()
		_zone = null
	_teles = []


func _exit_tree() -> void:
	if _slowed:
		_thaw()


func _process(delta: float) -> void:
	_t += delta
	if _flash > 0.0:
		_flash -= delta
		ch.set_flash(1.0 if _flash > 0.0 else 0.0)
		if _flash <= 0.0 and _glow_a > 0.0:
			_base_glow()

	if dead:
		# mort sobre (0.6 s) : petit recul, bascule en arrière, puis s'enfonce dans le sol
		position += _knock * delta
		_knock = _knock.lerp(Vector3.ZERO, minf(1.0, delta * 8.0))
		_timer += delta
		body.rotation.x = 0.35 * clampf(_timer / 0.2, 0.0, 1.0)
		var sink := clampf((_timer - 0.2) / 0.4, 0.0, 1.0)
		if sink > 0.0:
			body.position.y = -1.3 * sink * sink
		body.scale = Vector3.ONE * (1.0 - 0.2 * sink)
		if _shadow:
			_shadow.visible = sink < 0.5
		if _timer > 0.6:
			queue_free()
		return

	if _spawn > 0.0:
		_spawn -= delta
		_deco.visible = _spawn <= 0.0
		var to := hero.position - position
		body.rotation.y = atan2(-to.x, -to.z)
		if kind == "kagebo" or kind == "kitsunebi_s":
			var full := 0.4 if kind == "kitsunebi_s" else SPAWN_TIME
			body.scale = Vector3.ONE * (clampf(1.0 - _spawn / full, 0.05, 1.0) if _spawn > 0.0 else 1.0)
		return

	if kind == "funa":
		_ghost(delta)
		return

	if dummy:
		return

	if _hit_cd > 0.0:
		_hit_cd -= delta
	if _fire_t > 0.0:
		_update_fire(delta)
	if _ice != null:
		_update_ice(delta)
	if kind == "kagebo":
		_record()

	var to_hero := hero.position - position
	to_hero.y = 0
	var dist := to_hero.length()
	var dir := to_hero / maxf(dist, 0.001)

	match kind:
		"oni", "brute", "tate":
			_melee(delta, dir, dist)
		"kappa":
			_shooter(delta, dir, dist)
		_:
			if _stagger > 0.0:
				# assommé (pouvoirs) : ni marche ni attaque
				_stagger -= delta
				if _state == "charge":
					_end_charge()
			else:
				match kind:
					"umibozu":
						_umibozu(delta, dir, dist)
					"kitsunebi", "kitsunebi_s":
						_kitsune(delta, dir, dist)
					"yukionna":
						_yuki(delta, dir, dist)
					"kasha":
						_kasha(delta, dir, dist)
					"kagebo":
						_kagebo(delta, dir, dist)

	position += _knock * delta
	_knock = _knock.lerp(Vector3.ZERO, minf(1.0, delta * 9.0))
	main.clamp_to_arena(self, radius)


func _face(dir: Vector3, delta: float, rate := 10.0) -> void:
	body.rotation.y = lerp_angle(body.rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * rate))


func _melee(delta: float, dir: Vector3, dist: float) -> void:
	if _stagger > 0.0:
		# garde ouverte : il titube, ni marche ni attaque
		_stagger -= delta
		return
	var reach := 0.6 + _zone_r
	match _state:
		"move":
			# le porteur de bouclier pivote lentement : on peut le contourner
			_face(dir, delta, 3.0 if kind == "tate" else 10.0)
			if dist > reach - 0.3:
				# chemin : par la passerelle si le héros est sur une autre plateforme
				# recalculé 5 fois par seconde seulement (parcours des plateformes)
				_steer_t -= delta
				if _steer_t <= 0.0:
					_steer_t = 0.2
					_steer = main.steer_dir(position, hero.position)
				var sd := _steer
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
			# remplissage, pulsation et flash final (vfx.tele_update)
			main.vfx.tele_update(_tele, k, _timer)
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
	elif _state == "recover":
		# sort ici quand le tir a été interrompu par un coup
		_timer -= delta
		if _timer <= 0.0:
			_state = "move"
			_timer = 1.5


# ------------------------------------------------------------------ déplacements communs

## Marche vers le héros (par les passerelles si besoin).
func _walk_to_hero(delta: float, spd: float) -> void:
	_steer_t -= delta
	if _steer_t <= 0.0:
		_steer_t = 0.2
		_steer = main.steer_dir(position, hero.position)
	position += _steer * spd * delta
	if _steer != Vector3.ZERO:
		_face(_steer, delta)
	ch.play(_walk, maxf(spd / 1.6, 0.6))


## Garde une distance entre `near` et `far` en glissant sur le côté.
func _drift(delta: float, dir: Vector3, dist: float, near: float, far: float) -> void:
	var side := Vector3(-dir.z, 0, dir.x) * sin(_t * 0.8)
	var fwd := dir
	var want := 0.0
	if dist < near:
		want = -1.0
	elif dist > far:
		want = 1.0
		_steer_t -= delta
		if _steer_t <= 0.0:
			_steer_t = 0.2
			_steer = main.steer_dir(position, hero.position)
		fwd = _steer
	var v := (fwd * want + side * 0.6) * speed
	position += v * delta
	if v.length() > 0.3:
		ch.play(_walk, 0.8)
	else:
		ch.play(ch.idle)


func _flat_dist(p: Vector3) -> float:
	return Vector2(p.x - position.x, p.z - position.z).length()


func _seg_closest(p: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var ab := b - a
	ab.y = 0.0
	var t := 0.0
	if ab.length_squared() > 0.0001:
		t = clampf(Vector3(p.x - a.x, 0, p.z - a.z).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return Vector3(a.x + ab.x * t, 0, a.z + ab.z * t)


func _path_closest(pts: PackedVector3Array, p: Vector3) -> Vector3:
	if pts.size() == 0:
		return position
	var best := pts[0]
	var bd := INF
	for i in range(1, pts.size()):
		var q := _seg_closest(p, pts[i - 1], pts[i])
		var d := Vector2(q.x - p.x, q.z - p.z).length()
		if d < bd:
			bd = d
			best = q
	return best


func _lane_closest(p: Vector3) -> Vector3:
	return _path_closest(_lane, p)


func _path_len(pts: PackedVector3Array) -> float:
	var l := 0.0
	for i in range(1, pts.size()):
		l += pts[i].distance_to(pts[i - 1])
	return l


## Avance de `a` vers `b` tant que le sol est ferme ; renvoie le dernier point sûr.
func _cut_walkable(a: Vector3, b: Vector3) -> Vector3:
	var d := b - a
	d.y = 0.0
	var n := int(ceil(d.length() / 0.25))
	var last := Vector3(a.x, 0, a.z)
	for i in range(1, n + 1):
		var p := a + d * (float(i) / float(n))
		p.y = 0.0
		var ok: bool = main.arena.walkable(p, radius * 0.8) and not main.hazards.is_hole(p, 0.1)
		if not ok:
			break
		last = p
	return last


## Couloir annoncé le long d'une polyligne : une annonce rectangulaire par segment.
func _make_lane(pts: PackedVector3Array, w: float) -> void:
	_lane = pts
	_lane_w = w
	_zone = Node3D.new()
	_zone.top_level = true
	add_child(_zone)
	_tele = null
	_teles = []
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var d := pts[i] - a
		d.y = 0.0
		var l := maxf(d.length(), 0.1)
		var seg := Node3D.new()
		_zone.add_child(seg)
		seg.position = Vector3(a.x, 0, a.z)
		seg.rotation.y = atan2(-d.x, -d.z)
		# part de a (z = 0) et se remplit vers -z
		var tl: Node3D = main.vfx.tele_rect(seg, w * 0.5, l * 0.5, Vector2(0, 1))
		tl.position.z = -l * 0.5
		_teles.append(tl)


func _update_lane(k: float) -> void:
	for tl in _teles:
		main.vfx.tele_update(tl, k, _timer)


## Fin de l'annonce : la course commence (le couloir s'efface, le jeton reste pris).
func _start_charge(spd: float) -> void:
	if _zone:
		_zone.queue_free()
		_zone = null
	_teles = []
	_state = "charge"
	_li = 1
	_cspeed = spd
	_ctime = _path_len(_lane) / spd + 0.4
	_hit_cd = 0.0
	_knock = Vector3.ZERO


func _charge(delta: float) -> void:
	_ctime -= delta
	var move := _cspeed * delta
	while move > 0.0 and _li < _lane.size():
		var tgt := _lane[_li]
		var to := tgt - position
		to.y = 0.0
		var d := to.length()
		if d > 0.001:
			body.rotation.y = atan2(-to.x, -to.z)
		if d <= move:
			position = Vector3(tgt.x, position.y, tgt.z)
			move -= d
			_li += 1
		else:
			position += to / d * move
			move = 0.0
	_knock = Vector3.ZERO
	# contact : un seul coup tous les 0.6 s
	if _hit_cd <= 0.0 and _flat_dist(hero.position) < radius + 0.4:
		_hit_cd = 0.6
		main.enemy_strike(Vector3(position.x, 0, position.z), radius + 0.25)
	if _li >= _lane.size() or _ctime <= 0.0:
		_end_charge()


func _end_charge() -> void:
	main.free_token(self)
	_base_glow()
	if kind == "kasha" and _lane.size() >= 2:
		var from := _lane[0]
		var to := Vector3(position.x, 0, position.z)
		if from.distance_to(to) > 0.8:
			_fire_a = from
			_fire_b = to
			_fire_t = FIRE_TIME
			# points tous les 0.4 m : les flammes couvrent toute la traînée
			var pts := PackedVector3Array()
			var n := int(ceil(from.distance_to(to) / 0.4))
			for i in n + 1:
				pts.append(from.lerp(to, float(i) / float(n)))
			main.vfx.fire_trail(pts, FIRE_TIME)
		ch.play_once("Hit_A", 0.8)
	elif kind == "kagebo":
		for i in range(1, _lane.size()):
			main.vfx.slash_line(_lane[i - 1], _lane[i])
	_state = "recover"
	_timer = 1.6 if kind == "kasha" else 1.5
	_lane = PackedVector3Array()


# ------------------------------------------------------------------ umibōzu

func _surface() -> void:
	_phase = "rise"
	_ptimer = FUNA_EMERGE
	body.visible = true
	body.position.y = FUNA_DEPTH
	_shadow.visible = true
	_face_hero_now()
	ch.play("Idle_Combat")


func _umibozu(delta: float, dir: Vector3, dist: float) -> void:
	_ptimer -= delta
	match _phase:
		"rise":
			# sort de l'eau, encore intouchable
			body.position.y = lerpf(FUNA_DEPTH, 0.0, clampf(1.0 - _ptimer / FUNA_EMERGE, 0.0, 1.0))
			_face(dir, delta, 8.0)
			if _ptimer <= 0.0:
				body.position.y = 0.0
				_phase = "up"
				_ptimer = UMI_UP
		"up":
			# émergé : lent et vulnérable
			if dist > 1.2:
				_walk_to_hero(delta, speed)
			else:
				_face(dir, delta, 6.0)
				ch.play("Idle_Combat")
			if _ptimer <= 0.0:
				_phase = "dive"
				_ptimer = FUNA_DIVE
		"dive":
			_knock = Vector3.ZERO
			body.position.y = lerpf(0.0, FUNA_DEPTH, clampf(1.0 - _ptimer / FUNA_DIVE, 0.0, 1.0))
			if _ptimer <= 0.0:
				_phase = "under"
				_ptimer = UMI_UNDER
				_waits = 0
				body.visible = false
				_shadow.visible = false
		"under":
			_knock = Vector3.ZERO
			if _state == "windup":
				main.vfx.tele_update(_tele, 1.0 - _timer / UMI_WINDUP, _timer)
				_timer -= delta
				if _timer <= 0.0:
					main.enemy_strike(_target, _zone_r)
					main.vfx.water_burst(_target, _zone_r)
					_end_ghost_attack()
					_surface()
				return
			# sous les planches : il file vers le héros, trahi par des rides
			_walk_to_hero(delta, UMI_SWIM)
			_ripple_t -= delta
			if _ripple_t <= 0.0:
				_ripple_t = 0.3
				main.vfx.ring(Vector3(position.x, 0.06, position.z), Toon.FOAM, 0.55)
			if _ptimer > 0.0:
				return
			_ptimer = 0.3
			_waits += 1
			if _waits > 8:
				# pas de jeton ni d'ouverture : il remonte sans frapper
				_surface()
				return
			var t: Vector3 = main.arena.clamp_walk(Vector3(hero.position.x, 0, hero.position.z), radius)
			var hole: bool = main.hazards.is_hole(t, 0.1)
			if hole or dist > 7.5 or not main.take_token(self):
				return
			_target = t
			position = t
			_state = "windup"
			_timer = UMI_WINDUP
			_make_zone(true)
			_zone.global_position = _target


# ------------------------------------------------------------------ kitsune-bi

func _blink_fx(p: Vector3) -> void:
	main.vfx.ring(Vector3(p.x, 0.08, p.z), FOX_FIRE, 0.6)
	main.splash(p + Vector3(0, 0.6, 0), FOX_FIRE, 6)


func _kitsune(delta: float, dir: Vector3, dist: float) -> void:
	var mini := kind == "kitsunebi_s"
	# flotte au-dessus du sol
	body.position.y = lerpf(body.position.y, 0.3 + 0.12 * sin(_t * 3.0), minf(1.0, delta * 4.0))
	_face(dir, delta, 8.0)
	match _state:
		"move":
			_drift(delta, dir, dist, 2.8, 5.0)
			_timer -= delta
			if _timer <= 0.0:
				var t: Vector3 = main.arena.clamp_walk(Vector3(hero.position.x, 0, hero.position.z), radius)
				var hole: bool = main.hazards.is_hole(t, 0.1)
				if hole or not main.take_token(self):
					_timer = 0.4
					return
				# il annonce où il va apparaître… et y frappe
				_target = t
				_state = "windup"
				_timer = _windup
				_make_zone(true)
				_zone.global_position = _target
				ch.play_once("Spellcast_Shoot", ch.length("Spellcast_Shoot") * 0.55 / _windup)
		"windup":
			var k := 1.0 - _timer / _windup
			main.vfx.tele_update(_tele, k, _timer)
			ch.set_glow(_glow_a + 1.2 * k, _glow_c)
			_timer -= delta
			if _timer <= 0.0:
				_blink_fx(position)
				position = _target
				_blink_fx(_target)
				main.enemy_strike(_target, _zone_r)
				_cancel_attack()
				# reste un instant sur place : la fenêtre pour le trancher
				_timer = 1.1 if mini else 1.5
		"recover":
			_timer -= delta
			if _timer <= 0.0:
				_state = "move"
				_timer = randf_range(1.6, 2.4) * (0.7 if mini else 1.0)
				if randf() < 0.5:
					# clignement d'esquive : petit saut de côté, sans dégâts
					var side := Vector3(-dir.z, 0, dir.x) * (1.0 if randf() < 0.5 else -1.0)
					var p: Vector3 = main.arena.clamp_walk(position + side * 2.0, radius)
					var hole: bool = main.hazards.is_hole(p, 0.1)
					if not hole:
						_blink_fx(position)
						position = p
						_blink_fx(p)


## Mort du grand feu-follet : deux petits feux s'en échappent.
func _split() -> void:
	if not is_instance_valid(main) or not is_inside_tree():
		return
	var mult := float(get_meta("max_hp", 1.5)) / 1.5
	var a0 := randf() * TAU
	var sc = get_script()
	for i in 2:
		var a := a0 + PI * float(i)
		var e = sc.new()
		e.setup("kitsunebi_s", hero, main)
		var p: Vector3 = main.arena.clamp_walk(position + Vector3(cos(a), 0, sin(a)) * 0.9, 0.35)
		e.position = p
		main.add_child(e)
		e.hp *= mult
		e.set_meta("max_hp", e.hp)
		main.enemies.append(e)
	_blink_fx(position)


# ------------------------------------------------------------------ yuki-onna

func _yuki(delta: float, dir: Vector3, dist: float) -> void:
	match _state:
		"move":
			_face(dir, delta, 6.0)
			_drift(delta, dir, dist, 4.0, 6.5)
			_timer -= delta
			if _timer <= 0.0:
				if not main.take_token(self):
					_timer = 0.4
					return
				var a := Vector3(position.x, 0, position.z) + dir * 0.6
				var b := _cut_walkable(a, a + dir * YUKI_LEN)
				if a.distance_to(b) < 2.0:
					main.free_token(self)
					_timer = 0.6
					return
				_strike_dir = dir
				_make_lane(PackedVector3Array([a, b]), YUKI_W)
				_state = "windup"
				_timer = YUKI_WINDUP
				ch.play_once("Spellcast_Shoot", ch.length("Spellcast_Shoot") * 0.55 / YUKI_WINDUP)
		"windup":
			_face(_strike_dir, delta, 8.0)
			var k := 1.0 - _timer / YUKI_WINDUP
			_update_lane(k)
			ch.set_glow(_glow_a + 0.8 * k, _glow_c)
			_timer -= delta
			if _timer <= 0.0:
				main.enemy_strike(_lane_closest(hero.position), _lane_w * 0.5)
				_freeze(_lane)
				_cancel_attack()
				_lane = PackedVector3Array()
				_timer = 0.9
		"recover":
			_timer -= delta
			if _timer <= 0.0:
				_state = "move"
				_timer = randf_range(2.6, 3.6)


## La bande annoncée gèle : plaque de givre qui freine la ruée.
func _freeze(pts: PackedVector3Array) -> void:
	_clear_ice()
	_ice_pts = pts.duplicate()
	_ice_t = ICE_TIME
	_ice = Node3D.new()
	_ice.top_level = true
	add_child(_ice)
	_ice_mat = Toon.flat(Color(ICE_C, 0.55))
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var d := pts[i] - a
		d.y = 0.0
		var mi := Toon.part(_ice, Toon.box(Vector3(YUKI_W, 0.02, maxf(d.length(), 0.1))), _ice_mat, Vector3(a.x + d.x * 0.5, 0.06, a.z + d.z * 0.5))
		mi.rotation.y = atan2(-d.x, -d.z)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		main.vfx.sparks(Vector3(a.x + d.x * 0.5, 0.2, a.z + d.z * 0.5), Vector3.UP, 6, ICE_C)


func _update_ice(delta: float) -> void:
	_ice_t -= delta
	_ice_mat.albedo_color.a = 0.55 * clampf(_ice_t / 0.6, 0.0, 1.0)
	var on: bool = hero.dashing
	var sid: int = main.stroke_id
	if _slowed and (not on or sid != _slow_id):
		_thaw()
	if on and sid != _slow_id and _ice_t > 0.0:
		var q := _path_closest(_ice_pts, hero.position)
		if Vector2(q.x - hero.position.x, q.z - hero.position.z).length() < YUKI_W * 0.5:
			# la ruée patine sur le givre : ralentie jusqu'à la fin de ce trait
			_slow_id = sid
			_slowed = true
			hero.speed_mult *= ICE_SLOW
			main.float_text(hero.position, "GIVRE", ICE_C)
			main.splash(hero.position, ICE_C, 8)
	if _ice_t <= 0.0:
		_clear_ice()


## Rend sa vitesse à la ruée freinée (si c'est toujours le même trait).
func _thaw() -> void:
	if not _slowed:
		return
	_slowed = false
	if is_instance_valid(main) and is_instance_valid(hero) and int(main.stroke_id) == _slow_id:
		hero.speed_mult /= ICE_SLOW


func _clear_ice() -> void:
	if _ice != null:
		_ice.queue_free()
		_ice = null
	_ice_t = 0.0


# ------------------------------------------------------------------ kasha

func _kasha(delta: float, dir: Vector3, dist: float) -> void:
	var roll := 4.0
	match _state:
		"move":
			_face(dir, delta, 8.0)
			_drift(delta, dir, dist, 2.5, 6.5)
			_timer -= delta
			if _timer <= 0.0 and dist < 9.5:
				if not main.take_token(self):
					_timer = 0.4
					return
				var a := Vector3(position.x, 0, position.z)
				var b := _cut_walkable(a, a + dir * clampf(dist + 2.5, 4.0, KASHA_LEN))
				if a.distance_to(b) < 2.0:
					main.free_token(self)
					_timer = 0.6
					return
				_strike_dir = dir
				_make_lane(PackedVector3Array([a, b]), KASHA_W)
				_state = "windup"
				_timer = KASHA_WINDUP
		"windup":
			# il gratte le sol, les roues s'embrasent
			_face(_strike_dir, delta, 12.0)
			var k := 1.0 - _timer / KASHA_WINDUP
			_update_lane(k)
			ch.play(_walk, 2.6)
			ch.set_glow(_glow_a + 1.0 * k, _glow_c)
			roll = 14.0
			_timer -= delta
			if _timer <= 0.0:
				_start_charge(KASHA_SPEED)
		"charge":
			ch.play(_walk, 3.5)
			roll = 30.0
			_charge(delta)
		"recover":
			# étourdi après la charge : la fenêtre pour le frapper
			roll = 0.0
			_timer -= delta
			if _timer <= 0.0:
				_state = "move"
				_timer = randf_range(2.2, 3.2)
	for w in _wheels:
		var wn: Node3D = w
		wn.rotation.x -= roll * delta


func _update_fire(delta: float) -> void:
	_fire_t -= delta
	var on: bool = hero.dashing
	if on or _hit_cd > 0.0:
		return
	var q := _seg_closest(hero.position, _fire_a, _fire_b)
	if Vector2(q.x - hero.position.x, q.z - hero.position.z).length() < 0.45:
		_hit_cd = 0.8
		main.enemy_strike(q, 0.3)


# ------------------------------------------------------------------ kagebō

## Mémorise le trait du héros dès qu'il part en ruée.
func _record() -> void:
	var on: bool = hero.dashing
	var sid: int = main.stroke_id
	if on and sid != _rec_id:
		_rec_id = sid
		var p: PackedVector3Array = hero.path
		_rec = p.duplicate()


func _simplify(src: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	if src.size() == 0:
		return out
	out.append(src[0])
	for i in range(1, src.size()):
		if src[i].distance_to(out[out.size() - 1]) >= 0.9:
			out.append(src[i])
			if out.size() >= 9:
				break
	var last := src[src.size() - 1]
	if out.size() < 9 and last.distance_to(out[out.size() - 1]) >= 0.3:
		out.append(last)
	return out


## Le dernier trait du héros, reparti d'ici et tourné vers lui (coupé au bord de l'arène).
func _mirror_path(dir: Vector3, dist: float) -> PackedVector3Array:
	var a := Vector3(position.x, 0, position.z)
	var out := PackedVector3Array()
	out.append(a)
	var src := _simplify(_rec)
	if src.size() < 2 or _path_len(src) < 1.5:
		out.append(_cut_walkable(a, a + dir * clampf(dist + 1.5, 3.0, 8.0)))
		return out
	var v := src[src.size() - 1] - src[0]
	v.y = 0.0
	if v.length() < 0.5:
		# trait qui revient sur lui-même (boucle, retour) : on oriente son premier segment
		v = src[1] - src[0]
		v.y = 0.0
	var rot := atan2(dir.x, dir.z) - atan2(v.x, v.z)
	var total := 0.0
	var prev := a
	for i in range(1, src.size()):
		var off := (src[i] - src[0]).rotated(Vector3.UP, rot)
		var p := a + Vector3(off.x, 0, off.z)
		var seg := p - prev
		var sl := seg.length()
		if total + sl > KAGE_MAX:
			p = prev + seg * ((KAGE_MAX - total) / maxf(sl, 0.001))
			out.append(_cut_walkable(prev, p))
			break
		var q := _cut_walkable(prev, p)
		out.append(q)
		total += prev.distance_to(q)
		if q.distance_to(p) > 0.05:
			break  # bord atteint
		prev = q
	return out


func _kagebo(delta: float, dir: Vector3, dist: float) -> void:
	match _state:
		"move":
			_face(dir, delta, 8.0)
			_drift(delta, dir, dist, 3.0, 6.0)
			_timer -= delta
			if _timer <= 0.0 and dist < 9.0:
				if not main.take_token(self):
					_timer = 0.4
					return
				var pts := _mirror_path(dir, dist)
				if pts.size() < 2 or _path_len(pts) < 1.5:
					main.free_token(self)
					_timer = 0.6
					return
				_make_lane(pts, KAGE_W)
				_state = "windup"
				_timer = KAGE_WINDUP
				ch.play(ch.idle)
		"windup":
			if _lane.size() >= 2:
				_face(_lane[1] - _lane[0], delta, 10.0)
			var k := 1.0 - _timer / KAGE_WINDUP
			_update_lane(k)
			ch.set_glow(0.9 * k, Toon.VERMILION)
			_timer -= delta
			if _timer <= 0.0:
				_start_charge(KAGE_SPEED)
				ch.play_once("1H_Melee_Attack_Slice_Horizontal", 2.0)
		"charge":
			_charge(delta)
		"recover":
			# encre qui sèche : immobile, à découvert
			_timer -= delta
			if _timer <= 0.0:
				_state = "move"
				_timer = randf_range(2.4, 3.4)


# ------------------------------------------------------------------ funa

## Point du bord le plus proche de `p` (les noyés sortent de l'eau, jamais du milieu du ponton).
func _nearest_edge(p: Vector3) -> Vector3:
	# bords du cadre courant (la zone de combat d'une étape, sinon l'arène)
	var b: Rect2 = main.arena.bounds
	var c := b.get_center()
	var hx := b.size.x * 0.5
	var hz := b.size.y * 0.5
	var ex := hx - EDGE_IN
	var ez := hz - EDGE_IN
	var lx := p.x - c.x
	var lz := p.z - c.y
	var dx := hx - absf(lx)
	var dz := hz - absf(lz)
	var q := Vector3(ex * (1.0 if lx >= 0.0 else -1.0), 0, clampf(lz, -ez, ez)) if dx <= dz else Vector3(clampf(lx, -ex, ex), 0, ez * (1.0 if lz >= 0.0 else -1.0))
	q += Vector3(c.x, 0, c.y)
	# salles en plateformes : toujours sur la terre ferme
	return main.arena.clamp_walk(q, radius)


## Autre point du bord, loin de l'ancien et pas collé au héros.
func _random_edge() -> Vector3:
	var b: Rect2 = main.arena.bounds
	var c := b.get_center()
	var hx := b.size.x * 0.5
	var hz := b.size.y * 0.5
	var ex := hx - EDGE_IN
	var ez := hz - EDGE_IN
	var best := position
	for attempt in 20:
		var q := Vector3.ZERO
		# les grands côtés sont plus souvent choisis (proportion des longueurs)
		if randf() < hz / (hx + hz):
			q = Vector3(ex * (1.0 if randf() < 0.5 else -1.0), 0, randf_range(-ez + 0.4, ez - 0.4))
		else:
			q = Vector3(randf_range(-ex + 0.4, ex - 0.4), 0, ez * (1.0 if randf() < 0.5 else -1.0))
		q = main.arena.clamp_walk(q + Vector3(c.x, 0, c.y), radius)
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
				main.vfx.tele_update(_tele, k, _timer)
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
