extends Node3D
## Yōkai d'encre (monde 1, direction « Masque d'encre ») : pas de squelette KayKit, un corps d'encre vivante
## modelé en code (yokai_parts.ink_parts), masque de nō devant, gouttes qui coulent sous le corps. Animation
## procédurale (attente, marche, coup, lancer, incantation, garde, coup reçu, mort, apparition) sur quelques
## articulations ; même interface que character.gd / ninja_rig.gd (sauf `setup(kind, height)`), enemy.gd garde
## toute sa logique et ses noms d'animations KayKit (traduits ici en clips).
## Repère : face vers -Z, droite = +X ; unités du modèle (H_REF m de haut), mises à l'échelle à la hauteur voulue.
## Articulations : flotteur (bob) -> corps (penche) -> tête (masque, hoche ; tombe à la mort) ; deux bras
## (épaules) qui portent main et arme ; gouttes (ou tentacules) sous le corps, étirées et balancées en code.
## Matériaux : un toon à contour par yōkai (éclat de touche, lueur), un aplat partagé pour les yeux et l'eau.

const Toon = preload("res://scripts/toon.gd")
const Yokai = preload("res://scripts/yokai_parts.gd")

const H_REF := 1.75  # hauteur de référence du modelé (m)
const OUTLINE := 0.024
const SHOULDER := Vector3(0.40, 1.0, -0.02)
const HEAD_POS := Vector3(0, 1.22, 0)
const HEAD_TILT := 0.35  # masque relevé vers la caméra (vue plongeante)
const HAND_Y := -0.44

# clips
const C_IDLE := 0
const C_WALK := 1
const C_CHOP := 2
const C_CAST := 3
const C_THROW := 4
const C_HIT := 5
const C_DEATH := 6
const C_SPAWN := 7
const C_BLOCK := 8
const CLIP_LEN := [2.4, 1.0, 1.1, 1.2, 1.0, 0.6, 1.3, 1.0, 1.0]

# cases de pose
const S_FLOAT := 0  # translation du flotteur
const S_BODY := 1  # rotation du corps
const S_HEAD := 2  # rotation de la tête (en plus de l'inclinaison de repos)
const S_HEADP := 3  # translation de la tête (le masque tombe)
const S_ARM_L := 4
const S_ARM_R := 5
const S_DRIP := 6  # x : étirement des gouttes
const SLOTS := 7

# poses clés
const K_REST := 0
const K_CHOP_UP := 1
const K_CHOP_DOWN := 2
const K_CAST_UP := 3
const K_CAST_PUSH := 4
const K_THROW_BACK := 5
const K_THROW_REL := 6
const K_HIT := 7
const K_SLUMP := 8
const K_DOWN := 9
const K_UNDER := 10
const K_OVER := 11
# clip -> [instant, clé, instant, clé…] (lissé entre deux clés) ; le coup / le tir tombent à u = 0,5
const SEQ := {
	C_CHOP: [0.0, K_REST, 0.4, K_CHOP_UP, 0.52, K_CHOP_DOWN, 0.74, K_CHOP_DOWN, 1.0, K_REST],
	C_CAST: [0.0, K_REST, 0.42, K_CAST_UP, 0.56, K_CAST_PUSH, 0.8, K_CAST_PUSH, 1.0, K_REST],
	C_THROW: [0.0, K_REST, 0.4, K_THROW_BACK, 0.55, K_THROW_REL, 0.75, K_THROW_REL, 1.0, K_REST],
	C_HIT: [0.0, K_HIT, 0.35, K_HIT, 1.0, K_REST],
	C_DEATH: [0.0, K_REST, 0.3, K_SLUMP, 1.0, K_DOWN],
	C_SPAWN: [0.0, K_UNDER, 0.7, K_OVER, 1.0, K_REST],
}
## Bras au repos par genre : [droit, gauche]. Arme levée au-dessus de la tête = tireur (règle de lisibilité).
const REST_ARMS := {
	"oni": [Vector3(2.6, 0, 0.35), Vector3(0.25, 0, -0.3)],
	"brute": [Vector3(2.5, 0, 0.4), Vector3(0.3, 0, -0.35)],
	"kappa": [Vector3(2.3, 0, 0.3), Vector3(0.35, 0, -0.3)],
	"tate": [Vector3(0.45, 0, 0.45), Vector3(1.25, 0, -0.2)],
	"funa": [Vector3(2.3, 0, 0.3), Vector3(0.4, 0, -0.3)],
	"umibozu": [Vector3(1.1, 0, 0.3), Vector3(0.35, 0, -0.3)],
	"kappa_yumi": [Vector3(0.5, 0, 0.3), Vector3(0.9, 0, -0.4)],
	"ika": [Vector3(0.5, 0, 0.4), Vector3(0.5, 0, -0.4)],
	"umi_nyobo": [Vector3(1.2, 0, 0.3), Vector3(0.6, 0, -0.3)],
	# monde 2 (yokai_ink_w2.gd) : feu levé en main droite ; griffes basses en avant ; mains sur le ventre ; lanterne levée
	"kitsunebi": [Vector3(2.4, 0, 0.35), Vector3(0.6, 0, -0.4)],
	"kitsunebi_s": [Vector3(2.4, 0, 0.35), Vector3(0.6, 0, -0.4)],
	"kamaitachi": [Vector3(0.6, 0, 0.5), Vector3(0.6, 0, -0.5)],
	"tanuki": [Vector3(1.3, 0, 0.3), Vector3(1.3, 0, -0.3)],
	"tanuki_d": [Vector3(1.3, 0, 0.3), Vector3(1.3, 0, -0.3)],
	"kitsune_tsukai": [Vector3(2.75, 0, 0.3), Vector3(0.5, 0, -0.3)],
	# monde 3 (yokai_ink_w3.gd) : souffle des deux mains ; bras tendus de l'enfant qui court ; mains molles du spectre ;
	# glaçons écartés de la stalactite (immobile)
	"yukionna": [Vector3(1.5, 0, 0.35), Vector3(1.5, 0, -0.35)],
	"yuki_warashi": [Vector3(1.6, 0, 0.5), Vector3(1.6, 0, -0.5)],
	"onryo": [Vector3(1.7, 0, 0.25), Vector3(1.7, 0, -0.25)],
	"tsurara": [Vector3(0.0, 0, 0.5), Vector3(0.0, 0, -0.5)],
}

var model: Node3D  # racine mise à l'échelle
var anim: AnimationPlayer = null  # pas d'AnimationPlayer : animation procédurale
var skeleton: Skeleton3D = null
var scale_factor := 1.0
var idle := "Idle_Combat"
var kind := "oni"
var elite := false
var _built := false
var _current := ""
var _once := false
var _mats: Array[StandardMaterial3D] = []
var _mat_o: StandardMaterial3D  # encre, masque, étoffe : toon à contour (éclat, lueur)
var _float: Node3D
var _body: Node3D
var _head: Node3D
var _arms: Array[Node3D] = []  # [gauche, droite]
var _hands: Array[Node3D] = []  # [gauche, droite] : supports des objets accrochés (unités du monde)
var _drips: Array[Node3D] = []
var _drip_spread := 0.0
var _parts: Array[MeshInstance3D] = []
var _part_id := PackedStringArray()
var _slots := {}
# lecture
var _clip := C_IDLE
var _t := 0.0
var _speed := 1.0
var _loop := true
var _blend := 0.0
var _blend_len := 0.0
var _from: Array[Vector3] = []
var _tgt: Array[Vector3] = []
var _out: Array[Vector3] = []
var _ka: Array[Vector3] = []
var _kb: Array[Vector3] = []
var _life := 0.0
var _rest_r := Vector3(0.3, 0, 0.3)
var _rest_l := Vector3(0.3, 0, -0.3)


# ------------------------------------------------------------------ montage

## `k` : genre (Yokai.is_ink) ; `height` : hauteur voulue (m).
func setup(k: String, height := H_REF) -> void:
	kind = k
	scale_factor = height / H_REF
	var arms: Array = REST_ARMS.get(kind, [Vector3(0.3, 0, 0.3), Vector3(0.3, 0, -0.3)])
	_rest_r = arms[0]
	_rest_l = arms[1]
	model = Node3D.new()
	model.name = "Ink"
	add_child(model)
	model.scale = Vector3.ONE * scale_factor
	_mat_o = Toon.mat(Color.WHITE, true, OUTLINE)
	_mat_o.vertex_color_use_as_albedo = true
	_mat_o.vertex_color_is_srgb = true
	_mat_o.rim = 0.35
	_mat_o.rim_tint = 0.5
	_mat_o.emission_enabled = true
	_mat_o.emission = Color.WHITE
	_mat_o.emission_energy_multiplier = 0.0
	_mats.clear()
	_mats.append(_mat_o)
	_make_joints()
	_dress()
	for arr in [_from, _tgt, _out, _ka, _kb]:
		arr.clear()
		for j in SLOTS:
			arr.append(Vector3.ZERO)
	_built = true
	_current = idle
	_clip = _clip_of(idle)
	_eval(0.0)
	for j in SLOTS:
		_out[j] = _tgt[j]
	_apply()


func _make_joints() -> void:
	_float = Node3D.new()
	model.add_child(_float)
	_body = Node3D.new()
	_float.add_child(_body)
	_head = Node3D.new()
	_head.position = HEAD_POS
	_body.add_child(_head)
	_arms.clear()
	_hands.clear()
	for s in [-1.0, 1.0]:
		var sx := float(s)
		var arm := Node3D.new()
		arm.position = Vector3(sx * SHOULDER.x, SHOULDER.y, SHOULDER.z)
		_body.add_child(arm)
		_arms.append(arm)
		# support de la main : objets accrochés en unités du monde, +Y dans le prolongement du bras
		var hand := Node3D.new()
		hand.position = Vector3(0, HAND_Y, 0)
		hand.rotation.x = PI
		hand.scale = Vector3.ONE / maxf(scale_factor, 0.001)
		arm.add_child(hand)
		_hands.append(hand)


## Pièces (maillages partagés du genre) posées sur les articulations.
func _dress() -> void:
	var d := Yokai.ink_parts(kind, elite)
	_parts.clear()
	_part_id = PackedStringArray()
	_part_on(_body, "body", d)
	_part_on(_body, "fixed", d)
	_part_on(_head, "head", d)
	_part_on(_arms[0], "arm", d)
	_part_on(_arms[1], "arm", d)
	# arme en main droite (unités du monde, dans le support de la main)
	var w := _part_on(_hands[1], "weapon_r", d)
	if w != null:
		w.position = Vector3(0, 0.02, 0)
	# gouttes (ou tentacules) sous le corps : un pivot chacune, penchée vers l'extérieur de `spread`
	for n in _drips:
		n.queue_free()
	_drips.clear()
	_drip_spread = float(d.get("spread", 0.0))
	var pts: PackedVector3Array = d.get("drips", PackedVector3Array())
	for p in pts:
		var piv := Node3D.new()
		piv.position = p
		_body.add_child(piv)
		_drips.append(piv)
		_part_on(piv, "drip", d)


func _part_on(parent: Node3D, id: String, d: Dictionary) -> MeshInstance3D:
	var m := d.get(id) as Mesh
	if m == null:
		return null
	var mi := MeshInstance3D.new()
	mi.name = id
	mi.mesh = m
	mi.set_surface_override_material(0, _mat_o)
	if m.get_surface_count() > 1:
		mi.set_surface_override_material(1, Yokai.ink_flat_mat())
	if Toon.lite:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	_parts.append(mi)
	_part_id.append(id)
	return mi


## Élite : mêmes pièces, variante dorée (cerne du masque, liserés, oreilles d'or) ; maillages du cache.
func set_elite(on: bool) -> void:
	if elite == on or not _built:
		return
	elite = on
	var d := Yokai.ink_parts(kind, elite)
	for i in _parts.size():
		var mi := _parts[i]
		if is_instance_valid(mi):
			var m := d.get(_part_id[i]) as Mesh
			if m != null:
				mi.mesh = m


# ------------------------------------------------------------------ interface de Character

func has_animation(_a: String) -> bool:
	return true


func length(a: String) -> float:
	return float(CLIP_LEN[_clip_of(a)])


## Animation en boucle (attente, marche, garde).
func play(a: String, speed := 1.0, blend := 0.2) -> void:
	if a == "" or not _built:
		return
	if a == _current and not _once:
		_speed = speed
		return
	_once = false
	_current = a
	_start(_clip_of(a), speed, blend, true)


## Animation jouée une fois, puis retour à `idle`.
func play_once(a: String, speed := 1.0, blend := 0.1) -> void:
	if a == "" or not _built:
		return
	var again := a == _current
	_once = true
	_current = a
	_start(_clip_of(a), speed, 0.05 if again else blend, false)


## Fige la pose finale (mort) : la boucle ne reprend pas.
func hold() -> void:
	_once = false
	idle = ""


func set_flash(a: float) -> void:
	for m in _mats:
		m.emission = Color.WHITE
		m.emission_energy_multiplier = a


func set_glow(a: float, color := Toon.VERMILION) -> void:
	for m in _mats:
		m.emission = color
		m.emission_energy_multiplier = a


func paint(_detail: Texture2D, rim: float, rim_tint: float) -> void:
	for m in _mats:
		m.rim = rim
		m.rim_tint = rim_tint


## Accroche un objet (unités du monde) : « handslot.r » / « handslot.l » dans les mains, « head » sur la tête,
## tout autre nom sur le corps.
func attach(bone: String, node: Node3D) -> void:
	var holder := _holder(bone)
	holder.add_child(node)


func attach_mesh(bone: String, mesh: Mesh, material: Material, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	attach(bone, mi)
	return mi


## Rien à cacher : pas de sous-maillages importés.
func hide_meshes(_patterns: Array) -> void:
	pass


func _holder(bone: String) -> Node3D:
	match bone:
		"handslot.r", "hand.r", "wrist.r":
			return _hands[1]
		"handslot.l", "hand.l", "wrist.l":
			return _hands[0]
	var key := "head" if bone == "head" or bone == "Head" else "body"
	var got = _slots.get(key)
	if got != null and is_instance_valid(got):
		return got
	var holder := Node3D.new()
	holder.scale = Vector3.ONE / maxf(scale_factor, 0.001)
	if key == "head":
		_head.add_child(holder)
	else:
		_body.add_child(holder)
	_slots[key] = holder
	return holder


## Nom d'animation KayKit -> clip procédural (inconnu : attente).
func _clip_of(a: String) -> int:
	match a:
		"Walking_A", "Walking_B", "Walking_C", "Walking_D_Skeletons", "Walking_Backwards", "Running_A", "Running_B", "Running_C":
			return C_WALK
		"Block", "Blocking", "Block_Hit":
			return C_BLOCK
		"1H_Melee_Attack_Chop", "2H_Melee_Attack_Chop", "1H_Melee_Attack_Slice_Horizontal", "1H_Melee_Attack_Slice_Diagonal", \
		"2H_Melee_Attack_Slice", "2H_Melee_Attack_Spinning", "1H_Melee_Attack_Stab", "2H_Melee_Attack_Stab":
			return C_CHOP
		"Spellcast_Shoot", "Spellcasting", "Spellcast_Raise":
			return C_CAST
		"Throw":
			return C_THROW
		"Hit_A", "Hit_B":
			return C_HIT
		"Death_A", "Death_B", "Death_C_Skeletons":
			return C_DEATH
		"Spawn_Ground_Skeletons", "Spawn_Ground":
			return C_SPAWN
	return C_IDLE


func _start(clip: int, speed: float, blend: float, loop: bool) -> void:
	for j in SLOTS:
		_from[j] = _out[j]
	_clip = clip
	_t = 0.0
	_speed = speed
	_loop = loop
	_blend = 0.0
	_blend_len = maxf(blend, 0.0)


# ------------------------------------------------------------------ animation

func _process(delta: float) -> void:
	if not _built:
		return
	var dt := clampf(delta, 0.0, 0.1)
	_life = fmod(_life + dt, 1000.0)
	_t += dt * maxf(_speed, 0.0)
	var ln := float(CLIP_LEN[_clip])
	if _t >= ln:
		if _loop:
			_t = fmod(_t, ln)
		else:
			_t = ln
			if _once and idle != "":
				_once = false
				_current = ""
				play(idle)
	_eval(clampf(_t / float(CLIP_LEN[_clip]), 0.0, 1.0))
	if _blend < _blend_len:
		_blend += dt
		var w := clampf(_blend / maxf(_blend_len, 0.0001), 0.0, 1.0)
		w = w * w * (3.0 - 2.0 * w)
		for j in SLOTS:
			_out[j] = _from[j].lerp(_tgt[j], w)
	else:
		for j in SLOTS:
			_out[j] = _tgt[j]
	_apply()


func _apply() -> void:
	_float.position = _out[S_FLOAT]
	_body.rotation = _out[S_BODY]
	_head.rotation = Vector3(HEAD_TILT, 0, 0) + _out[S_HEAD]
	_head.position = HEAD_POS + _out[S_HEADP]
	_arms[0].rotation = _out[S_ARM_L]
	_arms[1].rotation = _out[S_ARM_R]
	# gouttes : elles s'étirent et retombent chacune à son rythme ; tentacules : balancement (spread)
	var stretch := maxf(_out[S_DRIP].x, 0.2)
	for i in _drips.size():
		var n := _drips[i]
		var ph := _life * 2.6 + float(i) * 1.7
		var sw := 0.1 + 0.25 * _drip_spread
		n.scale = Vector3(1, stretch * (1.0 + 0.3 * sin(ph)), 1)
		var out := Vector3.ZERO
		if _drip_spread > 0.0:
			var p := n.position
			out = Vector3(-p.z, 0, p.x).normalized() * _drip_spread  # penché vers l'extérieur
		n.rotation = out + Vector3(sw * sin(ph * 0.7), 0, sw * cos(ph * 0.9 + 0.5))


## Pose du clip courant à l'avancement `u` (0..1) dans _tgt.
func _eval(u: float) -> void:
	_key(K_REST, _tgt)
	match _clip:
		C_IDLE:
			var b := sin(u * TAU)
			_tgt[S_FLOAT] += Vector3(0, 0.03 * b, 0)
			_tgt[S_BODY] += Vector3(0.025 * b, 0, 0.015 * sin(u * TAU * 0.5))
			_tgt[S_HEAD] += Vector3(0.04 * b, 0, 0)
			_tgt[S_ARM_L] += Vector3(0.04 * b, 0, -0.03 * b)
			_tgt[S_ARM_R] += Vector3(-0.04 * b, 0, 0.03 * b)
			_tgt[S_DRIP] = Vector3(1.0 + 0.15 * b, 0, 0)
		C_BLOCK:
			# garde tenue : penché derrière le bouclier, souffle léger
			var b := sin(u * TAU)
			_tgt[S_FLOAT] += Vector3(0, 0.02 * b, 0)
			_tgt[S_BODY] += Vector3(-0.14 + 0.02 * b, 0, 0)
			_tgt[S_ARM_L] = Vector3(1.3, 0, -0.15)
			_tgt[S_DRIP] = Vector3(1.0 + 0.1 * b, 0, 0)
		C_WALK:
			# dandinement : rebond à chaque pas, roulis, bras en balancier, tête qui suit, gouttes tirées
			var p := u * TAU
			var s := sin(p)
			_tgt[S_FLOAT] += Vector3(0, 0.055 * absf(sin(p)), 0)
			_tgt[S_BODY] += Vector3(-0.1, 0.05 * s, 0.07 * s)
			_tgt[S_HEAD] += Vector3(0.06 * absf(cos(p)), -0.06 * s, 0)
			_tgt[S_ARM_L] += Vector3(0.45 * s, 0, 0)
			_tgt[S_ARM_R] += Vector3(-0.35 * s, 0, 0)
			_tgt[S_DRIP] = Vector3(1.3 + 0.1 * absf(s), 0, 0)
		_:
			if not SEQ.has(_clip):
				return
			var seq: Array = SEQ[_clip]
			_seq(seq, u)


func _seq(seq: Array, u: float) -> void:
	var n := seq.size() >> 1
	var i := 0
	while i < n - 2 and u > float(seq[(i + 1) * 2]):
		i += 1
	var t0 := float(seq[i * 2])
	var t1 := float(seq[(i + 1) * 2])
	var w := clampf((u - t0) / maxf(t1 - t0, 0.0001), 0.0, 1.0)
	w = w * w * (3.0 - 2.0 * w)
	_key(int(seq[i * 2 + 1]), _ka)
	_key(int(seq[i * 2 + 3]), _kb)
	for j in SLOTS:
		_tgt[j] = _ka[j].lerp(_kb[j], w)


# ------------------------------------------------------------------ poses clés
# Bras : rotation x positive = main vers l'avant (-Z), ~π = bras levé au-dessus de la tête ; z = écarté.
# Corps : x négatif = penché en avant. Flotteur : y = hauteur au-dessus du sol (0 au repos).

func _key(k: int, b: Array[Vector3]) -> void:
	for j in SLOTS:
		b[j] = Vector3.ZERO
	b[S_ARM_L] = _rest_l
	b[S_ARM_R] = _rest_r
	b[S_DRIP] = Vector3(1.0, 0, 0)
	match k:
		K_CHOP_UP:
			# arme haute, corps cambré en arrière
			b[S_ARM_R] = Vector3(3.1, 0, 0.3)
			b[S_ARM_L] = Vector3(_rest_l.x + 0.3, 0, _rest_l.z - 0.2)
			b[S_BODY] = Vector3(0.22, 0, 0)
			b[S_HEAD] = Vector3(0.1, 0, 0)
			b[S_FLOAT] = Vector3(0, 0.06, 0)
			b[S_DRIP] = Vector3(0.8, 0, 0)
		K_CHOP_DOWN:
			# l'arme s'abat devant, le corps plonge, les gouttes giclent
			b[S_ARM_R] = Vector3(0.5, 0, 0.3)
			b[S_ARM_L] = Vector3(_rest_l.x - 0.3, 0, _rest_l.z - 0.3)
			b[S_BODY] = Vector3(-0.38, 0, 0)
			b[S_HEAD] = Vector3(-0.25, 0, 0)
			b[S_FLOAT] = Vector3(0, -0.06, 0)
			b[S_DRIP] = Vector3(1.5, 0, 0)
		K_CAST_UP:
			# les deux bras montent, corps en arrière : la charge
			b[S_ARM_R] = Vector3(2.5, 0, 0.5)
			b[S_ARM_L] = Vector3(2.5, 0, -0.5)
			b[S_BODY] = Vector3(0.18, 0, 0)
			b[S_HEAD] = Vector3(0.15, 0, 0)
			b[S_FLOAT] = Vector3(0, 0.08, 0)
			b[S_DRIP] = Vector3(0.7, 0, 0)
		K_CAST_PUSH:
			# les bras poussent devant, corps en avant : le tir part
			b[S_ARM_R] = Vector3(1.55, 0, 0.3)
			b[S_ARM_L] = Vector3(1.55, 0, -0.3)
			b[S_BODY] = Vector3(-0.25, 0, 0)
			b[S_HEAD] = Vector3(-0.1, 0, 0)
			b[S_FLOAT] = Vector3(0, -0.03, 0)
			b[S_DRIP] = Vector3(1.4, 0, 0)
		K_THROW_BACK:
			b[S_ARM_R] = Vector3(2.9, 0, 0.5)
			b[S_BODY] = Vector3(0.2, 0.35, 0)
			b[S_HEAD] = Vector3(0.1, -0.2, 0)
			b[S_DRIP] = Vector3(0.8, 0, 0)
		K_THROW_REL:
			b[S_ARM_R] = Vector3(1.0, 0, 0.3)
			b[S_ARM_L] = Vector3(_rest_l.x + 0.2, 0, _rest_l.z - 0.3)
			b[S_BODY] = Vector3(-0.3, -0.3, 0)
			b[S_HEAD] = Vector3(-0.15, 0.1, 0)
			b[S_DRIP] = Vector3(1.4, 0, 0)
		K_HIT:
			# encaissé : rejeté en arrière, bras ouverts, gouttes rentrées
			b[S_BODY] = Vector3(0.3, 0, 0.1)
			b[S_HEAD] = Vector3(0.25, 0, 0)
			b[S_ARM_L] = Vector3(_rest_l.x + 0.5, 0, _rest_l.z - 0.4)
			b[S_ARM_R] = Vector3(_rest_r.x - 0.4, 0, _rest_r.z + 0.4)
			b[S_DRIP] = Vector3(0.6, 0, 0)
		K_SLUMP:
			# s'affaisse : penché en avant, bras ballants, le masque se décroche
			b[S_BODY] = Vector3(-0.35, 0, 0.15)
			b[S_HEAD] = Vector3(-0.6, 0, 0)
			b[S_HEADP] = Vector3(0, -0.1, -0.12)
			b[S_ARM_L] = Vector3(0.1, 0, -0.5)
			b[S_ARM_R] = Vector3(0.1, 0, 0.5)
			b[S_DRIP] = Vector3(1.6, 0, 0)
		K_DOWN:
			# le masque tombe devant lui, l'encre s'étire
			b[S_BODY] = Vector3(-0.5, 0, 0.25)
			b[S_HEAD] = Vector3(-1.6, 0, 0.3)
			b[S_HEADP] = Vector3(0.1, -0.75, -0.45)
			b[S_ARM_L] = Vector3(-0.2, 0, -0.7)
			b[S_ARM_R] = Vector3(-0.2, 0, 0.7)
			b[S_DRIP] = Vector3(2.2, 0, 0)
		K_UNDER:
			# apparition : il monte de la flaque d'encre
			b[S_FLOAT] = Vector3(0, -1.5, 0)
			b[S_HEAD] = Vector3(-0.3, 0, 0)
			b[S_DRIP] = Vector3(0.3, 0, 0)
		K_OVER:
			b[S_FLOAT] = Vector3(0, 0.1, 0)
			b[S_BODY] = Vector3(0.08, 0, 0)
			b[S_DRIP] = Vector3(1.6, 0, 0)
