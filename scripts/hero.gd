extends Node3D
## Le ronin : il fonce le long du trait.
## Par défaut (USE_NINJA_RIG) : ninja modelé et animé en code (ninja_rig.gd) — cagoule à fente unique,
## hachimaki, veste croisée, obi, tekko, hakama et kyahan, katana au fourreau dans le dos (tiré pendant l'action),
## palette tirée de la tenue de la garde-robe. Sinon : ancien rōdeur KayKit habillé (yokai_parts.hero_parts).
## Écharpe à deux pans qui flottent (couleur de l'écharpe de la garde-robe), simulée ici.
## Lisibilité : liseré de lumière, anneau au sol dessiné par-dessus le décor (no_depth_test), qui respire au repos.

const Toon = preload("res://scripts/toon.gd")
const Character = preload("res://scripts/character.gd")
const NinjaRig = preload("res://scripts/ninja_rig.gd")
const Yokai = preload("res://scripts/yokai_parts.gd")
## Vrai : ninja procédural ; faux : retour au modèle KayKit (un seul interrupteur).
const USE_NINJA_RIG := true
# modèle KayKit : chargé seulement si le ninja procédural est coupé
const MODEL_PATH := "res://assets/kaykit/Rogue_Hooded.glb"
const CAPE_TEX_PATH := "res://assets/kaykit/tex/rogue_cape.png"

signal dash_finished
signal landed  # fin d'un bond (ensō)

const DASH_SPEED := 28.0  # ruée un peu moins fulgurante : on voit mieux le ronin trancher
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
# apparence de l'Atelier : sillage de lame (ruban qui suit la ruée)
const TRAIL_LIFE := 0.22
var _trail: MeshInstance3D
var _trail_mesh: ImmediateMesh
var _trail_col := Color.WHITE
var _trail_pts: Array = []  # [point, âge, naissance]
var _trail_clock := 0.0
# tenue de shinobi
const SCARF_DEF := Color("#D7372B")  # écharpe d'origine : vermillon
const DRAWN_T := 1.6  # le sabre reste en main un instant après l'action
const LEAN := 0.24  # penché de course
var _blade_hand: Node3D
var _hilt: MeshInstance3D  # poignée qui dépasse du fourreau (cachée quand le sabre est tiré)
var _drawn_t := 0.0
var _life := 0.0
var _scarf_col := SCARF_DEF
var _scarf_mat: StandardMaterial3D  # col de l'écharpe (sommets blancs teintés)
var _outfit_id := "sumi"  # tenue de la garde-robe (palette du ninja procédural)
var _knot: Node3D  # nœud de l'écharpe dans la nuque : point d'attache des pans
var _tails: MeshInstance3D
var _tails_mesh: ImmediateMesh
var _tail_p: Array = []  # deux PackedVector3Array : maillons des pans (monde)
var _tail_o: Array = []  # positions à l'image précédente (verlet)
var _tail_n := 7
const TAIL_SEG := 0.12
# anneau au sol (lisibilité)
var _ring: Node3D
var ring_off := false  # accueil, carte des mondes (barque) : anneau au sol caché (posé par main)


func _ready() -> void:
	Toon.blob(self, 0.5, 0.32)  # ombre de contact douce
	body = Node3D.new()
	add_child(body)
	if USE_NINJA_RIG:
		ch = NinjaRig.new()
		body.add_child(ch)
		ch.setup(NinjaRig.hero_config(_outfit_id), 1.75)
		ch.spin_self = false  # la toupie fait déjà tourner le corps (_process)
		_dress_rig()
	else:
		ch = Character.new()
		body.add_child(ch)
		ch.setup(load(MODEL_PATH) as PackedScene, 1.75, [
			["Cape", load(CAPE_TEX_PATH)],
			["Rogue", load("res://assets/kaykit/tex/rogue_ink.png")],
		], ["Knife", "Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Throwable"])
		# l'écharpe à deux pans remplace la cape KayKit (même couleur de garde-robe)
		ch.hide_meshes(["Cape"])
		_blade_hand = _katana()
		ch.attach("handslot.r", _blade_hand)
		_dress()
	# liseré clair et franc : la silhouette se détache des sols sombres (indigo des mondes 1, 7, 8)
	ch.paint(null, 0.65, 0.12)
	_make_tails()
	_make_ring()


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


## Tenue de shinobi posée sur les os (maillages partagés, un par os, matériau commun des pièces).
func _dress() -> void:
	var d := Yokai.hero_parts(ch.scale_factor)
	var shadow := not Toon.lite
	_scarf_mat = Toon.mat(_scarf_col, true, 0.026)
	_scarf_mat.vertex_color_use_as_albedo = true
	_scarf_mat.vertex_color_is_srgb = true
	for bone in d:
		var b := String(bone)
		var mesh := d[bone] as Mesh
		if b == "hilt":
			_hilt = ch.attach_mesh("chest", mesh, Yokai.mat(), shadow)
		elif b == "scarf":
			ch.attach_mesh("chest", mesh, _scarf_mat, shadow)
		else:
			ch.attach_mesh(b, mesh, Yokai.mat(), shadow)
	_knot = Node3D.new()
	_knot.position = Vector3(0, 0.22, -0.36) * ch.scale_factor
	ch.attach("chest", _knot)


## Ninja procédural : katana tiré en main, poignée au fourreau, col de l'écharpe, nœud des pans dans la nuque.
func _dress_rig() -> void:
	_blade_hand = ch.blade
	_hilt = ch.hilt
	_scarf_mat = Toon.mat(_scarf_col, true, 0.026)
	_scarf_mat.vertex_color_use_as_albedo = true
	_scarf_mat.vertex_color_is_srgb = true
	ch.attach_mesh("neck", NinjaRig.collar_mesh(), _scarf_mat, not Toon.lite)
	_knot = ch.knot


## Course (ruée, trajets) : l'animation de course si le modèle l'a gardée, sinon la marche accélérée.
func run_anim(speed: float, blend := 0.08) -> void:
	if USE_NINJA_RIG:
		ch.play("Running_A", speed, blend)
		return
	if ch.anim != null and ch.anim.has_animation("Running_A"):
		ch.play("Running_A", speed, blend)
	else:
		ch.play("Walking_A", speed * 1.1, blend)


## Pans de l'écharpe : deux rubans (encre + couleur) recalculés à chaque image, tournés vers la caméra.
func _make_tails() -> void:
	_tail_n = 5 if Toon.lite else 7
	_tails_mesh = ImmediateMesh.new()
	_tails = MeshInstance3D.new()
	_tails.top_level = true
	_tails.mesh = _tails_mesh
	_tails.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_tails.material_override = m
	add_child(_tails)
	_tail_p = [PackedVector3Array(), PackedVector3Array()]
	_tail_o = [PackedVector3Array(), PackedVector3Array()]


## Anneau au sol : liseré d'encre et anneau washi, repère vermillon devant ; dessiné par-dessus le décor.
func _make_ring() -> void:
	_ring = Node3D.new()
	_ring.position = Vector3(0, 0.03, 0)
	add_child(_ring)
	var outer := TorusMesh.new()
	outer.inner_radius = 0.5
	outer.outer_radius = 0.66
	outer.rings = 32
	outer.ring_segments = 3
	var inner := TorusMesh.new()
	inner.inner_radius = 0.545
	inner.outer_radius = 0.6
	inner.rings = 32
	inner.ring_segments = 3
	var o := Toon.part(_ring, outer, _ring_mat(Color(Toon.SUMI, 0.5), 10), Vector3.ZERO, Vector3(1, 0.05, 1))
	o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var i := Toon.part(_ring, inner, _ring_mat(Color(Toon.WASHI, 0.85), 11), Vector3(0, 0.002, 0), Vector3(1, 0.05, 1))
	i.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# repère de direction : petite pointe vermillon au bord avant (l'anneau suit le regard)
	var tip := Toon.part(_ring, Toon.cyl(0.0, 0.09, 0.01, 3), _ring_mat(Color(Toon.VERMILION, 0.95), 12), Vector3(0, 0.004, -0.68))
	tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _ring_mat(c: Color, prio: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.no_depth_test = true
	m.render_priority = prio
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func start_dash(p: PackedVector3Array) -> void:
	if p.size() < 2 or dead:
		return
	if not dashing:
		# trait court : coup de sabre ; long trait : il court (pieds au sol), sabre en avant
		var plen := 0.0
		for i in range(1, p.size()):
			plen += p[i].distance_to(p[i - 1])
		if plen < 3.0:
			ch.play_once("1H_Melee_Attack_Slice_Horizontal", 2.6)
		else:
			run_anim(2.6)
	_drawn_t = DRAWN_T
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
	_drawn_t = DRAWN_T
	ch.play_once("2H_Melee_Attack_Spinning", 1.8)


## Garde (retour) : posture de parade, intouchable un instant.
func guard(d: float) -> void:
	guard_t = d
	_drawn_t = DRAWN_T
	ch.play_once("Block", 1.2)


## Bond (ensō) : saut en cloche vers `to`, signal `landed` à l'atterrissage.
func leap(to: Vector3, d: float) -> void:
	_leap_from = position
	_leap_to = Vector3(to.x, 0, to.z)
	_leap_t = 0.0
	_leap_dur = d
	_drawn_t = DRAWN_T
	face(_leap_to - position)
	ch.play_once("Jump_Full_Short", 1.6)


## Estoc (crochet) : demi-tour et coup d'estoc.
func stab(dir: Vector3) -> void:
	face(dir)
	snap_facing()
	_drawn_t = DRAWN_T
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
			if not ch._once and ch.idle != "":
				ch.play(ch.idle, 1.0, 0.15)  # arrivé : il se pose
			dash_finished.emit()
		elif not ch._once:
			# le coup de sabre fini, la ruée continue en courant (plus de glissade figée)
			run_anim(2.6)

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
		body.position.y = sin(PI * k) * 3.4  # bond haut, lisible depuis la caméra
		if k >= 1.0:
			_leap_t = -1.0
			body.position.y = 0.0
			_dust()
			landed.emit()

	if invuln > 0.0 and not dead:
		invuln -= delta
		body.visible = dashing or fmod(invuln, 0.16) > 0.07
	else:
		body.visible = true
	if _flash > 0.0:
		_flash -= delta
		# éclat blanc qui retombe (plus net qu'un simple allumé / éteint)
		ch.set_flash(0.35 + 0.65 * clampf(_flash / 0.15, 0.0, 1.0) if _flash > 0.0 else 0.0)

	# orientation et posture
	var target_rot := atan2(-facing.x, -facing.z)
	if spinning <= 0.0:
		body.rotation.y = lerp_angle(body.rotation.y, target_rot, minf(1.0, delta * (40.0 if dashing else 14.0)))
	_lean = lerpf(_lean, 1.0 if dashing else 0.0, minf(1.0, delta * 25.0))
	body.rotation.x = -LEAN * _lean  # léger penché de course, pas de vol plané
	if _trail != null:
		_update_trail(delta)
	_life = fmod(_life + delta, 1000.0)
	_update_pose(delta)
	_update_tails(delta)


## Apparence choisie à l'Atelier (meta.apply_run_start) : couleur de l'écharpe (cape), sillage de lame.
## Rappelée à chaud par la garde-robe : sans écharpe portée, la cape retrouve sa texture d'origine.
func set_look(cape: Color, cape_on: bool, trail: Color, trail_on: bool) -> void:
	# l'écharpe à deux pans prend la couleur de l'écharpe portée (vermillon d'origine)
	_scarf_col = cape if cape_on else SCARF_DEF
	if _scarf_mat != null:
		_scarf_mat.albedo_color = _scarf_col
	if not USE_NINJA_RIG and ch != null and ch.model != null:
		var cape_tex := load(CAPE_TEX_PATH) as Texture2D
		for n in ch.model.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi == null or mi.mesh == null or not ("Cape" in String(mi.name)):
				continue
			for i in mi.mesh.get_surface_count():
				var m := mi.get_surface_override_material(i) as StandardMaterial3D
				if m == null:
					continue
				if cape_on:
					m.albedo_texture = null
					m.albedo_color = cape
				else:
					m.albedo_texture = cape_tex
					m.albedo_color = Color.WHITE
	if is_instance_valid(_trail):
		_trail.queue_free()
	_trail = null
	_trail_pts.clear()
	if trail_on:
		_trail_col = trail
		_trail_mesh = ImmediateMesh.new()
		_trail = MeshInstance3D.new()
		_trail.top_level = true
		_trail.mesh = _trail_mesh
		_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_trail.material_override = Toon.brush_mat()  # pinceau qui s'effiloche
		add_child(_trail)


## Tenue de la garde-robe : ninja procédural -> palette de la tenue (id tiré du nom de l'atlas,
## « rogue_<id>.png », cf. meta.OUTFITS) ; KayKit -> atlas recoloré (corps, bras, jambes, capuche).
func set_outfit(tex: Texture2D) -> void:
	if tex == null:
		return
	if USE_NINJA_RIG:
		var id := tex.resource_path.get_file().get_basename().trim_prefix("rogue_")
		_outfit_id = id if NinjaRig.OUTFIT_PAL.has(id) else "sumi"
		if ch != null:
			ch.set_palette(NinjaRig.hero_config(_outfit_id))
		return
	if ch == null or ch.model == null:
		return
	for n in ch.model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.visible:
			continue
		var nm := String(mi.name)
		if not ("Rogue" in nm) or "Cape" in nm or "Eyes" in nm:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i) as StandardMaterial3D
			if m != null:
				m.albedo_texture = tex


## Posture : sabre tiré pendant l'action (sinon au fourreau), respiration au repos, anneau au sol qui pulse.
func _update_pose(delta: float) -> void:
	if _drawn_t > 0.0:
		_drawn_t -= delta
	var drawn: bool = dashing or _drawn_t > 0.0 or ch._once or dead
	if _blade_hand != null:
		_blade_hand.visible = drawn
	if _hilt != null:
		_hilt.visible = not drawn
	var calm := not dashing and not dead and spinning <= 0.0 and _leap_t < 0.0
	if calm:
		# respiration : le buste se soulève à peine
		var b := sin(_life * 2.4)
		body.scale = Vector3(1.0 - 0.006 * b, 1.0 + 0.014 * b, 1.0 - 0.006 * b)
	else:
		body.scale = body.scale.lerp(Vector3.ONE, minf(1.0, delta * 12.0))
	if _ring != null:
		_ring.visible = not dead and not ring_off
		_ring.rotation.y = body.rotation.y
		var s := 1.0 + 0.05 * sin(_life * 3.0) if calm else 0.9
		_ring.scale = _ring.scale.lerp(Vector3(s, 1.0, s), minf(1.0, delta * 10.0))


## Pans de l'écharpe (verlet) : accrochés au nœud de la nuque, ils pendent et ondulent au repos,
## filent derrière le héros et claquent au vent pendant la ruée.
func _update_tails(delta: float) -> void:
	if _tails == null or _knot == null or not _knot.is_inside_tree():
		return
	_tails.visible = body.visible
	var dt := clampf(delta, 0.001, 0.05)
	var anchor := _knot.global_position
	var right := Vector3(-facing.z, 0, facing.x)
	var back := -facing
	for t in 2:
		var p: PackedVector3Array = _tail_p[t]
		var o: PackedVector3Array = _tail_o[t]
		var root := anchor + right * (0.05 if t == 0 else -0.05)
		if p.size() != _tail_n or p[0].distance_to(root) > 2.0:
			# première image ou téléportation : les pans repartent pendus sous le nœud
			p = PackedVector3Array()
			for i in _tail_n:
				p.append(root + Vector3(0, -TAIL_SEG * float(i), 0) + back * 0.03 * float(i))
			o = p.duplicate()
		p[0] = root
		o[0] = root
		var rate := 15.0 if dashing else 2.3
		var amp := 7.0 if dashing else 1.2
		for i in range(1, _tail_n):
			var cur := p[i]
			var vel := (cur - o[i]) * 0.9
			var flap := right * sin(_life * rate + float(i) * 0.8 + float(t) * 1.7) * amp * (float(i) / float(_tail_n))
			var acc := Vector3(0, -9.0, 0) + back * (2.0 if dashing else 0.6) + flap
			o[i] = cur
			p[i] = cur + vel + acc * dt * dt
		# longueur fixe : chaque maillon reste à TAIL_SEG du précédent, jamais sous le sol
		for i in range(1, _tail_n):
			var dv := p[i] - p[i - 1]
			var l := dv.length()
			var q := p[i - 1] + (dv / l * TAIL_SEG if l > 0.0001 else Vector3(0, -TAIL_SEG, 0))
			q.y = maxf(q.y, 0.04)
			p[i] = q
		_tail_p[t] = p
		_tail_o[t] = o
	_draw_tails()


func _draw_tails() -> void:
	_tails_mesh.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam != null else global_position + Vector3(0, 10, 6)
	var ink := Color(Toon.SUMI, 1.0)
	_tails_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in 2:
		var p: PackedVector3Array = _tail_p[t]
		var n := p.size()
		if n < 2:
			continue
		var sides := PackedVector3Array()
		var lift := PackedVector3Array()
		for i in n:
			var dv := p[mini(i + 1, n - 1)] - p[maxi(i - 1, 0)]
			var view := eye - p[i]
			var sd := dv.cross(view)
			if sd.length_squared() < 0.000001:
				sd = Vector3(-facing.z, 0, facing.x)
			sides.append(sd.normalized())
			lift.append(view.normalized() * 0.012)  # la couleur passe devant l'encre
		for i in range(n - 1):
			var w0 := _tail_w(i, n)
			var w1 := _tail_w(i + 1, n)
			var a := p[i]
			var b := p[i + 1]
			# contour d'encre (pleine largeur), puis l'étoffe colorée, plus sombre vers la pointe (plis)
			_quad(a - sides[i] * w0, a + sides[i] * w0, b + sides[i + 1] * w1, b - sides[i + 1] * w1, ink, ink)
			var k0 := float(i) / float(n - 1)
			var k1 := float(i + 1) / float(n - 1)
			var c0 := _scarf_col.darkened(0.08 + 0.28 * k0 + (0.1 if i % 2 == 1 else 0.0))
			var c1 := _scarf_col.darkened(0.08 + 0.28 * k1 + (0.1 if i % 2 == 0 else 0.0))
			_quad(a - sides[i] * w0 * 0.62 + lift[i], a + sides[i] * w0 * 0.62 + lift[i],
				b + sides[i + 1] * w1 * 0.62 + lift[i + 1], b - sides[i + 1] * w1 * 0.62 + lift[i + 1], c0, c1)
	_tails_mesh.surface_end()


## Demi-largeur d'un pan au maillon i : large au nœud, effilé, pointe fine.
func _tail_w(i: int, n: int) -> float:
	if i >= n - 1:
		return 0.012
	return lerpf(0.075, 0.045, float(i) / float(n - 1))


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cc: Color) -> void:
	for v in [[a, ca], [b, ca], [c, cc], [a, ca], [c, cc], [d, cc]]:
		var pair: Array = v
		_tails_mesh.surface_set_color(pair[1])
		_tails_mesh.surface_add_vertex(pair[0])


## Atterrissage d'un bond : petite bouffée de poussière (anneau washi, giclée).
func _dust() -> void:
	var m := get_parent()
	if m == null:
		return
	var fx = m.get("vfx")
	if fx != null and is_instance_valid(fx) and fx.has_method("ring"):
		fx.ring(Vector3(position.x, 0.08, position.z), Toon.WASHI, 0.8)
	if m.has_method("splash"):
		m.call("splash", position + Vector3(0, 0.15, 0), Toon.WASHI, 5)


## Ruban vertical à hauteur de lame, qui s'efface en TRAIL_LIFE secondes.
func _update_trail(delta: float) -> void:
	_trail_clock = fmod(_trail_clock + delta, 1000.0)
	for p in _trail_pts:
		p[1] = float(p[1]) + delta
	while not _trail_pts.is_empty() and float(_trail_pts[0][1]) > TRAIL_LIFE:
		_trail_pts.pop_front()
	if dashing or _leap_t >= 0.0:
		_trail_pts.append([body.global_position + Vector3(0, 0.9, 0), 0.0, _trail_clock])
	_trail_mesh.clear_surfaces()
	if _trail_pts.size() < 2:
		return
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n := _trail_pts.size()
	for i in n:
		var p: Array = _trail_pts[i]
		var k := 1.0 - float(p[1]) / TRAIL_LIFE
		# pointe effilée à la tête du trait
		var tip := minf(1.0, float(n - 1 - i) * 0.45 + 0.4)
		var c := Color(_trail_col, 0.8 * k)
		var pos: Vector3 = p[0]
		var u := float(p[2]) * 7.0
		_trail_mesh.surface_set_color(c)
		_trail_mesh.surface_set_uv(Vector2(u, 0.0))
		_trail_mesh.surface_set_uv2(Vector2(1.0 - k, 0.0))
		_trail_mesh.surface_add_vertex(pos + Vector3(0, 0.34 * k * tip, 0))
		_trail_mesh.surface_set_color(c)
		_trail_mesh.surface_set_uv(Vector2(u, 1.0))
		_trail_mesh.surface_set_uv2(Vector2(1.0 - k, 0.0))
		_trail_mesh.surface_add_vertex(pos - Vector3(0, 0.34 * k * tip, 0))
	_trail_mesh.surface_end()
