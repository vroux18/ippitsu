extends Node3D
## Boss du monde 1 (design/UNIVERS.md), au rythme bouclier → vulnérable :
##  okappa  — Ō-Kappa, mini-boss (24 PV, bouclier 10) : salves en éventail, plongeon sous le héros.
##            Tranché dans le dos, ou cueilli à la sortie de l'eau, sa coupelle se renverse :
##            bouclier brisé, sonné 5.5 s (dégâts ×2).
##  uwabami — Uwabami, serpent de mer (40 PV, bouclier 12) : le trancher dans sa longueur use le
##            bouclier (1 par segment, plus au-delà de 8) ; tout le corps d'un trait le brise.
##            Brisé : il reste en surface, sonné 6 s, et chaque coup sur le corps porte (×2).
## Bouclier levé, un coup ordinaire n'effleure (10 % des dégâts) et use un peu le bouclier.
## main appelle : check_dash(), take_hit(), end_stroke(), danger_at(), touching_hero().

const Toon = preload("res://scripts/toon.gd")
const Yokai = preload("res://scripts/yokai_parts.gd")

const SEGMENTS := 12
const SPACING := 0.9
const SEG_R := 0.55
const HALF := Vector2(4.6, 8.6)  # demi-dimensions de l'arène (comme main.gd)
const BOWL_WATER := Color("#7FB2C8")
# apparence (direction « Masque d'encre », règles en tête de yokai_ink_w1.gd)
const KAPPA_U := 1.68  # échelle d'Ō-Kappa (unités du modèle → m) : le dôme affleure la coupelle (y 2,62)
const KAPPA_W := 1.15  # largeur du corps d'encre (le masque reste devant le dôme)
const SHELL := Color("#5E6B3A")  # carapace olive des kappa
const SHELL_D := Color("#4A5530")
const INK_WAVE := Color("#1B2A3E")  # encre bleue d'Uwabami
const DANGER_MARGIN := 0.35  # marge de danger_at (comme is_danger de main)
const SHIELD_C := Color("#6FB7FF")  # bleu des boucliers (comme enemy.gd)
const CHIP_HP := 0.1  # part des dégâts qui traverse le bouclier
const CHIP_SH := 0.35  # bouclier usé par point de dégât d'un coup simple (×2 pour une figure)
const VULN_MULT := 2.0
const REGEN_TIME := 1.0
const SURF_WINDOW := 1.3  # Ō-Kappa : il sort de l'eau, sa coupelle est exposée

var kind := "okappa"
var main: Node
var hero: Node3D
var title := ""
var hp := 18.0
var max_hp := 18.0
var dead := false
var radius := 1.0
var max_hp_mult := 1.0  # difficulté du monde

var _state := "spawn"
var _timer := 1.2
var _t := 0.0
var _flash := 0.0
var _stun := 0.0
var _last_stroke := -1
var _zone: Node3D
var _zone_fill: Node3D  # visuel partagé de l'annonce (vfx.tele_disc)
var _zone_center := Vector3.ZERO
var _zone_r := 1.6
var _cycle := 0
var _summoned := false

# Ō-Kappa (corps d'encre modelé en code : tête, bras, gouttes ; la coupelle garde sa place, y 2,62)
var body: Node3D
var _mat: StandardMaterial3D  # toon à couleurs de sommets, propre au gardien (éclat des coups, lueur d'annonce)
var _arms: Array = []  # [gauche, droit]
var _drips: Array = []  # pivots des gouttes sous le corps
var _bowl: Node3D
var _water: Node3D
var _pose := 0.0  # 0 : bras au repos (bâton dressé) ; 1 : bras levés et écartés (salve, sortie de l'eau)
var _pose_tgt := 0.0
var _anim_lock := 0.0  # garde la pose levée un instant (sortie de l'eau)
var _death_played := false

# Uwabami
var _segs: Array = []  # Node3D, la tête en premier
var _trail: Array = []  # positions passées de la tête (la plus récente en premier)
var _path: Array = []  # chemin prévu de la traversée
var _path_i := 0
var _hits := {}  # segments tranchés depuis le dernier end_stroke : {index: true}
var _marks: Node3D
var _depth := -1.6  # profondeur du corps (0 = en surface)
var _burst := 0
var _fired := 0
var _surf_t := 0.0  # Ō-Kappa : fenêtre « à la sortie de l'eau »

# bouclier (lu par le HUD)
var shield := 0.0
var shield_max := 0.0
var vulnerable_t := 0.0
var vulnerable_len := 5.5
var _regen := 0.0  # recharge animée du bouclier (secondes restantes)
var _sh_root: Node3D
var _bubble: MeshInstance3D
var _aura: MeshInstance3D
var _sh_mat: StandardMaterial3D
var _aura_mat: StandardMaterial3D
var _sh_size := Vector3.ONE
var _sh_pop := 0.0
var _spark_t := -1.0


func setup(k: String, m: Node) -> void:
	kind = k
	main = m
	hero = m.hero


func _ready() -> void:
	if kind == "okappa":
		title = "Ō-Kappa"
		hp = 24.0
		radius = 1.0
		_build_okappa()
		vulnerable_len = 5.5
		_shield_init(10.0, Vector3(1.2, 1.7, 1.2), 1.4)
	else:
		title = "Uwabami"
		hp = 40.0
		radius = SEG_R
		_build_uwabami()
		vulnerable_len = 6.0
		_shield_init(12.0, Vector3(1.25, 1.1, 1.5), 0.5)
	hp *= max_hp_mult
	max_hp = hp


# ------------------------------------------------------------------ construction

## Ō-Kappa : le kappa commun (yokai_ink_w1.gd) en géant — corps d'encre à obi d'étang (liserés et oreilles
## d'or de l'élite), grande carapace à plaques cerclées d'or, masque vert cerné d'or au bec d'or, grand bâton
## dressé ; la coupelle d'or (son point faible, visible de dos) reste au nœud « bowl », y 2,62. Deux matériaux :
## toon à couleurs de sommets (propre : éclat, lueur) et l'aplat partagé (yeux, eau). Bras et gouttes animés
## en code (_kp_anim).
func _build_okappa() -> void:
	var lite := Toon.lite
	var u := KAPPA_U
	var w := KAPPA_W
	body = Node3D.new()
	add_child(body)
	_mat = Toon.mat(Color.WHITE, true, 0.03)
	_mat.vertex_color_use_as_albedo = true
	_mat.vertex_color_is_srgb = true
	_mat.rim = 0.35
	_mat.rim_tint = 0.5
	_mat.emission_enabled = true
	_mat.emission = Color.WHITE
	_mat.emission_energy_multiplier = 0.0
	# corps : dôme d'encre et obi d'étang ; carapace olive dans le dos, plaques sombres cerclées d'or
	var b := Yokai.Mesher.new(u)
	Yokai.ink_body(b, w, Yokai.INK, Yokai.POND_CLOTH, Yokai.POND_WAVE, Toon.GOLD, lite, true)
	var sc := Vector3(0, 0.95, 0.3 * w)
	var sr := Vector3(0.42 * w, 0.52, 0.2)
	b.ball(sc, sr, SHELL, Vector3.ZERO, 10)
	b.cyl(Vector3(0, 0.95, 0.3 * w), Vector3(0.44 * w, 0.06, 0.1), Toon.GOLD, Vector3(PI / 2.0, 0, 0), 1.0, 12)
	var plates := [Vector2(0, 0.2), Vector2(0.22, 0.0), Vector2(-0.22, 0.0), Vector2(0, -0.22)]
	if not lite:
		plates.append_array([Vector2(0.2, -0.3), Vector2(-0.2, -0.3), Vector2(0.24, 0.26), Vector2(-0.24, 0.26)])
	for q in plates:
		var pv: Vector2 = q
		# plaque posée sur l'ellipsoïde de la carapace (profondeur z déduite), cerne d'or en dessous
		var nz := sqrt(maxf(1.0 - pow(pv.x / sr.x, 2.0) - pow(pv.y / sr.y, 2.0), 0.0))
		var at := sc + Vector3(pv.x, pv.y, sr.z * nz)
		b.ball(at - Vector3(0, 0, 0.012), Vector3(0.12, 0.13, 0.025), Toon.GOLD, Vector3.ZERO, 8)
		b.ball(at, Vector3(0.095, 0.105, 0.03), SHELL_D, Vector3.ZERO, 8)
	_kp_part(body, b.mesh(), Vector3.ZERO)
	# tête : masque vert cerné d'or, sourcils froncés, yeux d'étang, bec d'or, rides d'or ; couronne de paille
	# autour de la coupelle. Le nœud est avancé pour que le masque sorte du dôme élargi.
	var head_z := -0.08 * u
	var a := Yokai.Mesher.new(u)
	var f := Yokai.Mesher.new(u)
	Yokai.mask_plate(a, Yokai.MASK_KAPPA, 1.25, 1.15, true)
	Yokai.mask_brows(a, Toon.SUMI, true, 1.25)
	Yokai.mask_eyes(f, Yokai.EYE_POND, 0.07, 1.25)
	a.spike(Vector3(0, -0.1, Yokai.FACE_Z + 0.01), 0.1, 0.22, Toon.GOLD, Vector3(-PI / 2.0 - 0.3, 0, 0), 0.0, 5, 0.55)
	a.box(Vector3(0, -0.24, Yokai.FACE_Z), Vector3(0.2, 0.03, 0.02), Toon.SUMI)
	if not lite:
		for sx in [-1.0, 1.0]:
			a.box(Vector3(float(sx) * 0.27, -0.06, Yokai.FACE_Z), Vector3(0.03, 0.16, 0.015), Toon.GOLD, Vector3(0, 0, float(sx) * 0.3))
	var crown_z := (0.05 - head_z) / u
	a.cyl(Vector3(0, 0.31, crown_z), Vector3(0.3, 0.06, 0.3), Yokai.STRAW, Vector3.ZERO, 0.9, 12)
	_kp_part(body, Yokai.two(a, f), Vector3(0, 1.22 * u, head_z))
	# coupelle d'or (point faible) et son eau : même place et même nom qu'avant
	_bowl = Node3D.new()
	_bowl.name = "bowl"
	_bowl.position = Vector3(0, 2.62, 0.05)
	body.add_child(_bowl)
	Toon.part(_bowl, Toon.cyl(0.42, 0.3, 0.12, 20), Toon.mat_shared(Toon.GOLD), Vector3.ZERO)
	_water = Toon.part(_bowl, Toon.cyl(0.34, 0.34, 0.02, 20), Toon.mat_shared(BOWL_WATER, false), Vector3(0, 0.07, 0))
	# bras d'encre (épaules du rig d'encre) ; bâton en main droite, dressé (rôle de tireur)
	var ad := {}
	Yokai.ink_arm(ad, Yokai.INK, 1.3)
	_arms.clear()
	for sx in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(float(sx) * 0.42 * w * u, 1.0 * u, -0.02 * u)
		body.add_child(arm)
		var am := _kp_part(arm, ad["arm"], Vector3.ZERO)
		am.scale = Vector3.ONE * u
		_arms.append(arm)
	var hand := Node3D.new()
	hand.position = Vector3(0, -0.44 * u, 0)
	hand.rotation.x = PI
	hand.scale = Vector3.ONE * 1.6
	(_arms[1] as Node3D).add_child(hand)
	_kp_part(hand, Yokai.weapon("staff"), Vector3(0, 0.02, 0))
	# gouttes d'encre sous le corps (elles s'étirent et retombent)
	var dd := {}
	Yokai.ink_drip(dd, Yokai.INK)
	var pts := [Vector3(0.16, 0.36, -0.14), Vector3(-0.19, 0.35, 0.05), Vector3(0.05, 0.34, 0.2)]
	if not lite:
		pts.append(Vector3(-0.08, 0.37, -0.22))
	_drips.clear()
	for p in pts:
		var piv := Node3D.new()
		piv.position = (p as Vector3) * u * Vector3(w, 1.0, w)
		body.add_child(piv)
		var dm := _kp_part(piv, dd["drip"], Vector3.ZERO)
		dm.scale = Vector3.ONE * u
		_drips.append(piv)
	Toon.disc(self, 1.0, Color(0, 0, 0, 0.14))
	body.scale = Vector3.ONE * 0.01
	_arms[1].rotation = Vector3(2.75, 0, 0.3)
	_arms[0].rotation = Vector3(0.35, 0, -0.3)


## Pièce d'Ō-Kappa : surface 0 = toon du gardien, surface 1 (s'il y en a une) = aplat lumineux.
func _kp_part(parent: Node3D, m: Mesh, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.set_surface_override_material(0, _mat)
	if m.get_surface_count() > 1:
		mi.set_surface_override_material(1, Yokai.ink_flat_mat())
	if Toon.lite:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Lueur d'annonce (vermillon) ou éclat blanc des coups sur l'encre du gardien.
func _kp_glow(a: float, col := Toon.VERMILION) -> void:
	if _mat == null:
		return
	_mat.emission = col
	_mat.emission_energy_multiplier = a


## Ō-Kappa : respiration, bras (repos : bâton dressé ; levés et écartés pour la salve et la sortie de l'eau ;
## pendants quand il est sonné), gouttes qui s'étirent, coupelle renversée tant qu'il est sonné.
func _kp_anim(delta: float) -> void:
	if _anim_lock <= 0.0 and _state != "fan":
		_pose_tgt = 0.0
	_pose = move_toward(_pose, _pose_tgt, delta * 4.5)
	var stunned := _state == "stun"
	var dying := _state == "dying"
	if _state == "idle" or _state == "fan":
		body.position.y = absf(sin(_t * 3.2)) * 0.05 if _state == "idle" else 0.0
	for i in 2:
		var arm: Node3D = _arms[i]
		var sx := -1.0 if i == 0 else 1.0
		var rest := Vector3(0.35, 0, -0.3) if i == 0 else Vector3(2.75, 0, 0.3)
		var up := Vector3(2.9, 0, sx * 0.9)
		var want := rest.lerp(up, _pose)
		want.x += sin(_t * 2.2 + float(i) * PI) * 0.1 * (1.0 - _pose)
		if stunned:
			want = Vector3(0.3 + sin(_t * 12.0) * 0.1, 0, sx * 1.25)
		elif dying:
			want = Vector3(0.1, 0, sx * 0.5)
		arm.rotation = arm.rotation.lerp(want, minf(1.0, delta * 8.0))
	var k := 0
	for d in _drips:
		var piv: Node3D = d
		var fast := _state == "sink" or _state == "hidden" or _anim_lock > 0.0
		var st := 1.0 + 0.35 * maxf(sin(_t * (6.0 if fast else 2.4) + float(k) * 1.7), -0.6)
		piv.scale = Vector3(1.0, st, 1.0)
		k += 1
	var tilt := 1.25 if stunned else 0.0
	_bowl.rotation.x = lerpf(_bowl.rotation.x, tilt, minf(1.0, delta * 6.0))
	_water.visible = not stunned and not dying


## Uwabami : long corps d'encre bleue — tête à grand masque de serpent (washi cerné d'or, sourcils froncés,
## yeux d'or, gueule vermillon aux crocs d'or), cornes d'or, crinière d'encre, collerette d'étoffe de Prusse
## à seigaiha ; chaque segment est ceint de la même étoffe, coiffé d'un petit masque washi aux yeux d'or,
## porte une nageoire d'or une fois sur deux et des gouttes aux flancs. Les nœuds des segments gardent leurs
## positions et leur taille (mécanique) ; seule la pièce qu'ils portent change. Deux matériaux partagés.
func _build_uwabami() -> void:
	var lite := Toon.lite
	var head_m := _uwabami_head(lite)
	var seg_m: Array = [_uwabami_seg(lite, false), _uwabami_seg(lite, true)]
	for i in SEGMENTS:
		var s := Node3D.new()
		add_child(s)
		var k := 1.0 - 0.5 * float(i) / float(SEGMENTS - 1)
		var mi := MeshInstance3D.new()
		mi.mesh = head_m if i == 0 else seg_m[i % 2]
		mi.scale = Vector3.ONE * (1.0 if i == 0 else k)
		mi.set_surface_override_material(0, Yokai.mat())
		mi.set_surface_override_material(1, Yokai.ink_flat_mat())
		if lite:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.add_child(mi)
		s.position = Vector3(0, _depth, -HALF.y - 4.0 - i * SPACING)
		_segs.append(s)
	for i in SEGMENTS * 12:
		_trail.append(Vector3(0, 0, -HALF.y - 4.0 - i * SPACING / 12.0))
	_marks = Node3D.new()
	_marks.top_level = true
	add_child(_marks)
	_state = "dive"
	_timer = 0.5


## Tête d'Uwabami (unités du monde, face vers -Z) : crâne et mufle d'encre, grand masque de nō de serpent,
## cornes d'or, crinière d'encre, collerette d'étoffe à la nuque, deux gouttes sous la mâchoire.
static func _uwabami_head(lite: bool) -> ArrayMesh:
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	a.ball(Vector3(0, 0.55, 0.05), Vector3(0.74, 0.62, 0.9), INK_WAVE, Vector3.ZERO, 10)
	a.ball(Vector3(0, 0.42, -0.72), Vector3(0.56, 0.4, 0.5), INK_WAVE, Vector3.ZERO, 8)
	# collerette : anneau d'étoffe de Prusse à la nuque, liseré d'or, écailles d'écume sur le dessus
	a.cyl(Vector3(0, 0.5, 0.78), Vector3(0.8, 0.34, 0.7), Yokai.SEA_CLOTH, Vector3(PI / 2.0, 0, 0), 0.92, 12)
	a.cyl(Vector3(0, 0.5, 0.97), Vector3(0.78, 0.05, 0.68), Toon.GOLD, Vector3(PI / 2.0, 0, 0), 1.0, 12)
	_seigaiha(a, Vector3(0, 0.5, 0.78), Vector2(0.8, 0.7), 5 if lite else 8, 0.1)
	# masque : plaque washi légèrement relevée, cerne d'or ; traits posés dans son repère
	var mrot := Vector3(-0.62, 0, 0)  # relevé vers le ciel : la caméra plonge, la face doit se lire du dessus
	var mb := Basis.from_euler(mrot)
	var mc := Vector3(0, 0.78, -0.9)
	a.ball(mc, Vector3(0.64, 0.6, 0.14), Yokai.MASK_WASHI, mrot, 10)
	a.ball(mc + mb * Vector3(0, 0, 0.06), Vector3(0.7, 0.66, 0.1), Toon.GOLD, mrot, 10)
	var fz := -0.135
	for sx in [-1.0, 1.0]:
		var x := float(sx)
		a.box(mc + mb * Vector3(x * 0.27, 0.3, fz), Vector3(0.3, 0.07, 0.03), Toon.SUMI, Vector3(-0.62, 0, x * 0.42))
		f.ball(mc + mb * Vector3(x * 0.25, 0.1, fz), Vector3(0.14, 0.11, 0.02), Yokai.EYE_GOLD, mrot, 8)
		f.box(mc + mb * Vector3(x * 0.25, 0.1, fz - 0.014), Vector3(0.04, 0.15, 0.012), Toon.SUMI, mrot)
		# crocs d'or qui descendent de la lèvre
		a.spike(mc + mb * Vector3(x * 0.24, -0.17, fz + 0.01), 0.05, 0.22, Toon.GOLD, Vector3(PI - 0.45, 0, x * 0.1), 0.0, 4)
		if not lite:
			a.ball(mc + mb * Vector3(x * 0.07, -0.06, fz), Vector3(0.03, 0.02, 0.012), Toon.SUMI, mrot, 6)
	# gueule : la seule tache de vermillon, là où il crache
	a.box(mc + mb * Vector3(0, -0.24, fz + 0.005), Vector3(0.74, 0.16, 0.04), Toon.VERMILION, mrot)
	a.box(mc + mb * Vector3(0, -0.24, fz - 0.01), Vector3(0.74, 0.03, 0.02), Toon.SUMI, mrot)
	# cornes d'or, crinière d'encre qui coule en arrière
	for sx in [-1.0, 1.0]:
		var x := float(sx)
		a.spike(Vector3(x * 0.36, 1.05, 0.1), 0.12, 0.75, Toon.GOLD, Vector3(0.6, 0, x * 0.35), 0.0, 6)
	var n := 3 if lite else 5
	for i in n:
		var x := (float(i) - 0.5 * float(n - 1)) * 0.22
		a.spike(Vector3(x, 1.0 - absf(x) * 0.5, 0.35), 0.11, 0.7 - absf(x) * 0.6, INK_WAVE, Vector3(-1.1, 0, x * 0.8), 0.0, 5)
	# crête d'or au sommet du crâne (lisible du dessus)
	a.spike(Vector3(0, 1.0, 0.1), 0.2, 0.55, Toon.GOLD, Vector3(-0.35, 0, 0), 0.0, 4, 0.25)
	if not lite:
		for sx in [-1.0, 1.0]:
			var x := float(sx)
			var tip := a.spike(Vector3(x * 0.3, 0.16, -0.62), 0.07, 0.3, INK_WAVE, Vector3(PI, 0, -x * 0.25), 0.3, 5)
			a.ball(tip, Vector3(0.05, 0.06, 0.05), INK_WAVE, Vector3.ZERO, 6)
	return Yokai.two(a, f)


## Segment d'Uwabami (unité ; le nœud le réduit vers la queue) : boule d'encre ceinte d'étoffe de Prusse
## à seigaiha et liserés d'or, petit masque washi aux yeux d'or sur le dos, nageoire d'or (`fin`), gouttes.
static func _uwabami_seg(lite: bool, fin: bool) -> ArrayMesh:
	var a := Yokai.Mesher.new(1.0)
	var f := Yokai.Mesher.new(1.0)
	a.ball(Vector3(0, 0.45, 0), Vector3(0.55, 0.47, 0.69), INK_WAVE, Vector3.ZERO, 10)
	a.cyl(Vector3(0, 0.45, 0.22), Vector3(0.56, 0.24, 0.48), Yokai.SEA_CLOTH, Vector3(PI / 2.0, 0, 0), 1.0, 12)
	for z in [0.09, 0.35]:
		a.cyl(Vector3(0, 0.45, float(z)), Vector3(0.575, 0.035, 0.495), Toon.GOLD, Vector3(PI / 2.0, 0, 0), 1.0, 12)
	_seigaiha(a, Vector3(0, 0.45, 0.22), Vector2(0.56, 0.48), 5 if lite else 8, 0.065)
	# petit masque washi posé sur le dos, tourné vers le ciel : cerne d'or, yeux d'or, sourcil, bouche
	var mrot := Vector3(-1.25, 0, 0)
	var mb := Basis.from_euler(mrot)
	var pc := Vector3(0, 0.9, -0.2)
	a.ball(pc, Vector3(0.26, 0.3, 0.07), Yokai.MASK_WASHI, mrot, 8)
	a.ball(pc + mb * Vector3(0, 0, 0.035), Vector3(0.29, 0.33, 0.05), Toon.GOLD, mrot, 8)
	for sx in [-1.0, 1.0]:
		f.ball(pc + mb * Vector3(float(sx) * 0.1, 0.03, -0.075), Vector3(0.06, 0.045, 0.012), Yokai.EYE_GOLD, mrot, 6)
		f.ball(pc + mb * Vector3(float(sx) * 0.1, 0.03, -0.085), Vector3(0.022, 0.028, 0.01), Toon.SUMI, mrot, 6)
	a.box(pc + mb * Vector3(0, 0.15, -0.075), Vector3(0.26, 0.03, 0.012), Toon.SUMI, mrot)
	a.box(pc + mb * Vector3(0, -0.13, -0.075), Vector3(0.12, 0.024, 0.012), Toon.SUMI, mrot)
	if fin:
		a.spike(Vector3(0, 0.8, 0.42), 0.24, 0.62, Toon.GOLD, Vector3(-0.75, 0, 0), 0.0, 4, 0.3)
	if not lite:
		for sx in [-1.0, 1.0]:
			var x := float(sx)
			var tip := a.spike(Vector3(x * 0.5, 0.3, 0.1), 0.07, 0.3, INK_WAVE, Vector3(PI, 0, -x * 0.25), 0.3, 5)
			a.ball(tip, Vector3(0.05, 0.06, 0.05), INK_WAVE, Vector3.ZERO, 6)
	return Yokai.two(a, f)


## Écailles d'écume (seigaiha) sur le dessus d'un anneau d'étoffe d'axe z : centre `c`, demi-axes `r` (x, y).
static func _seigaiha(a: Yokai.Mesher, c: Vector3, r: Vector2, n: int, w: float) -> void:
	for i in n:
		var ang := -1.9 + 3.8 * float(i) / float(n - 1)
		var at := c + Vector3(sin(ang) * r.x, cos(ang) * r.y, 0)
		a.ball(at, Vector3(w, 0.022, w * 0.6), Yokai.SEA_WAVE, Vector3(0, 0, -ang), 6)


# ------------------------------------------------------------------ interface avec main

## Vrai si la ruée a..b touche le boss pour la première fois de ce trait (dégâts gérés par main).
## Pour Uwabami, les segments touchés sont notés : les dégâts tombent à la fin du trait
## (ruées enchaînées comprises : tout ce qui suit le dernier end_stroke forme un seul tracé).
func check_dash(a: Vector3, b: Vector3, stroke_id: int) -> bool:
	if dead:
		return false
	if kind == "okappa":
		if _state in ["spawn", "sink", "hidden"] or _last_stroke == stroke_id:
			return false
		if _seg_dist(position, a, b) < radius + 0.55:
			_last_stroke = stroke_id
			return true
		return false
	# hors ruée (image qui suit la fin du trait, bond d'ensō) : rien ne compte
	if not hero.dashing:
		return false
	if vulnerable_t > 0.0:
		# sonné en surface : chaque trait qui touche le corps porte (dégâts gérés par main)
		if _last_stroke == stroke_id or _depth < -0.4:
			return false
		for s in _segs:
			var sn: Node3D = s
			if _seg_dist(sn.position, a, b) < SEG_R + 0.5:
				_last_stroke = stroke_id
				return true
		return false
	_mark_segs(a, b)
	return false


## Note les segments d'Uwabami touchés par la ruée a..b.
func _mark_segs(a: Vector3, b: Vector3) -> void:
	if _depth < -0.4:
		return
	for i in SEGMENTS:
		if _hits.has(i):
			continue
		var s: Node3D = _segs[i]
		if _seg_dist(s.position, a, b) < SEG_R + 0.5:
			_hits[i] = true
			main.small_hit(s.position)


func take_hit(dmg: float, dir: Vector3) -> void:
	if dead:
		return
	if kind == "okappa" and vulnerable_t <= 0.0:
		var ry := body.rotation.y
		var fwd := Vector3(-sin(ry), 0, -cos(ry))
		if dir.normalized().dot(fwd) > 0.4 or _surf_t > 0.0:
			# par-derrière, ou à la sortie de l'eau : la coupelle se renverse, le bouclier cède
			main.splash(position + Vector3(0, 2.2, 0), BOWL_WATER, 20)
			_shield_dmg(shield_max)
	_hit(dmg, _figure_hit())


## Fin du trait : la plus longue suite de segments tranchés use le bouclier d'Uwabami.
func end_stroke(_stroke_id: int) -> void:
	if kind == "uwabami" and not dead and vulnerable_t <= 0.0:
		# la dernière image de la ruée n'est pas encore passée par check_dash
		var pa: Vector3 = main._prev_hero
		_mark_segs(pa, hero.position)
	var hit_set: Dictionary = _hits
	_hits = {}
	if kind != "uwabami" or dead or hit_set.is_empty() or vulnerable_t > 0.0:
		return
	var best := 0
	var run := 0
	for i in SEGMENTS:
		if hit_set.has(i):
			run += 1
			best = maxi(best, run)
		else:
			run = 0
	if best == 0:
		return
	var where: Node3D = _segs[0]
	var at := where.position
	if best < 4:
		# coupé en travers : la lame glisse sur les écailles, à peine une égratignure
		main.clang(at)
		_damage(float(best) * CHIP_HP)
		_shield_dmg(float(best) * CHIP_SH)
		return
	# dans sa longueur : un éclat de bouclier par segment, tout le corps le brise
	var sd: float = shield_max if best >= SEGMENTS else float(best) * (1.25 if best >= 8 else 1.0)
	main.float_text(at + Vector3(0, 0.6, 0), "%d / %d" % [best, SEGMENTS], SHIELD_C)
	main.big_hit(at)
	_damage(float(best) * CHIP_HP)
	_shield_dmg(sd)


## Vrai si le point p est dans une attaque annoncée qui frappe d'ici eta secondes (ou en cours).
func danger_at(p: Vector3, eta: float) -> bool:
	if dead:
		return false
	var lim := eta + DANGER_MARGIN
	if _zone != null and _timer < lim:
		if Vector2(p.x - _zone_center.x, p.z - _zone_center.z).length() < _zone_r + DANGER_MARGIN:
			return true
	if kind != "uwabami" or (_state != "telegraph" and _state != "undulate"):
		return false
	# traversée d'Uwabami : la tête suit _path, le corps passe ensuite pendant body_t
	var reach := SEG_R + 0.35 + DANGER_MARGIN
	var speed := 6.5 if hp > max_hp * 0.5 else 8.0
	var body_t := float(SEGMENTS) * SPACING / speed
	var acc := 0.0
	var i0 := 0
	var prev := Vector3.ZERO
	if _state == "telegraph":
		if _path.is_empty():
			return false
		acc = maxf(_timer, 0.0)
		prev = _path[0]
	else:
		if eta < body_t + DANGER_MARGIN:
			for s in _segs:
				var sp: Vector3 = s.position
				if Vector2(p.x - sp.x, p.z - sp.z).length() < reach:
					return true
		i0 = _path_i
		prev = _trail[0]
	for i in range(i0, _path.size()):
		var q: Vector3 = _path[i]
		acc += prev.distance_to(q) / speed
		prev = q
		if acc > lim:
			break
		if acc + body_t > eta - DANGER_MARGIN and Vector2(p.x - q.x, p.z - q.z).length() < reach:
			return true
	return false


func touching_hero(p: Vector3) -> bool:
	if dead:
		return false
	if kind == "okappa":
		return false
	if _state != "undulate" or _depth < -0.3:
		return false
	for s in _segs:
		var q: Vector3 = s.position
		if Vector2(p.x - q.x, p.z - q.z).length() < SEG_R + 0.35:
			return true
	return false


## Dégâts de zone (techniques, pouvoirs) : touche la partie vulnérable la plus proche de `center` dans `reach`.
## Renvoie le point touché, ou Vector3.INF si rien n'est touché (boss invulnérable à cet instant, hors de portée, mort).
## (`reach` plutôt que `radius`, déjà pris par le rayon du boss)
func aoe_hit(center: Vector3, reach: float, dmg: float, fx := true) -> Vector3:
	if dead:
		return Vector3.INF
	var found := false
	var at := Vector3.ZERO
	if kind == "okappa":
		# enfoui ou en train de surgir : intouchable (comme check_dash)
		if _state in ["spawn", "sink", "hidden"]:
			return Vector3.INF
		if Vector2(position.x - center.x, position.z - center.z).length() < reach + radius:
			found = true
			at = position + Vector3(0, 1.2, 0)
	else:
		# Uwabami : seulement quand le corps affleure ; dégâts simples, sans bonus de longueur
		if _depth < -0.4:
			return Vector3.INF
		var best := INF
		for s in _segs:
			var sp: Vector3 = s.position
			var d := Vector2(sp.x - center.x, sp.z - center.z).length()
			if d < reach + SEG_R and d < best:
				best = d
				found = true
				at = Vector3(sp.x, maxf(sp.y, 0.0) + 0.45, sp.z)
	if not found:
		return Vector3.INF
	var fl := _flash
	_hit(dmg)
	if not fx:
		_flash = fl
	return at


# ------------------------------------------------------------------ outils

func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	return Toon.seg_dist_xz(p, a, b)


func _damage(d: float) -> void:
	if dead or d <= 0.0:
		return
	hp -= d
	_flash = 0.15
	if hp <= 0.0:
		hp = 0.0
		dead = true
		vulnerable_t = 0.0
		_cancel()
		if kind == "uwabami":
			_clear_marks()
		_timer = 0.0
		_state = "dying"
		main.boss_killed(self)
	elif kind == "okappa" and not _summoned and hp <= max_hp * 0.5:
		_summoned = true
		main.spawn_minions(["oni", "oni"])


# ------------------------------------------------------------------ bouclier → vulnérable

## Bouclier plein de v points ; bulle d'ellipsoïde `size` (demi-axes) centrée à la hauteur y.
func _shield_init(v: float, size: Vector3, y: float) -> void:
	shield_max = v
	shield = v
	_sh_size = size
	_sh_root = Node3D.new()
	_sh_root.top_level = true
	add_child(_sh_root)
	_sh_mat = _sh_material(Color(SHIELD_C, 0.18))
	_aura_mat = _sh_material(Color(Toon.GOLD, 0.2))
	_bubble = Toon.part(_sh_root, Toon.sphere(1.0), _sh_mat, Vector3(0, y, 0), size)
	_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aura = Toon.part(_sh_root, Toon.sphere(1.0), _aura_mat, Vector3(0, y, 0), size * 1.08)
	_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aura.visible = false
	_shield_visual(0.0)


func _sh_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_BACK
	return m


## Point au sol de la bulle : Ō-Kappa, ou la tête d'Uwabami.
func _sh_anchor() -> Vector3:
	if kind == "okappa":
		return Vector3(position.x, 0, position.z)
	var head: Node3D = _segs[0]
	return Vector3(head.position.x, 0, head.position.z)


## Bulle cachée quand il est sous l'eau (enfoui, plongé).
func _sh_hidden() -> bool:
	if kind == "okappa":
		return _state in ["spawn", "sink", "hidden"]
	return _depth < -0.6


## Le coup vient-il d'une figure (forme reconnue du trait) ? Elle use le bouclier deux fois plus.
func _figure_hit() -> bool:
	var sh = main.get("_shape")
	return sh is Dictionary and not sh.is_empty()


## Coup ordinaire (trait, pouvoir) : bouclier levé, il effleure et use un peu le bouclier ; brisé, ×2.
func _hit(d: float, strong := false) -> void:
	if dead or d <= 0.0:
		return
	if vulnerable_t > 0.0:
		_damage(d * VULN_MULT)
		return
	if shield_max <= 0.0:
		_damage(d)
		return
	_damage(d * CHIP_HP)
	_shield_dmg(d * CHIP_SH * (2.0 if strong else 1.0))


## Use le bouclier de v points (mécanique du boss : gros morceaux) ; à zéro il se brise.
func _shield_dmg(v: float) -> void:
	if dead or v <= 0.0 or vulnerable_t > 0.0 or shield_max <= 0.0:
		return
	shield -= v
	_sh_pop = 0.15
	if _t - _spark_t > 0.2:
		_spark_t = _t
		main.vfx.sparks(_sh_anchor() + Vector3(0, 1.2, 0), Vector3.UP, 3 if v < 2.0 else 8, SHIELD_C)
	if shield > 0.0:
		return
	if _regen > 0.0 and v < shield_max * 0.5:
		# il se reforme : les petits coups n'y font pas de brèche avant la fin de la recharge
		shield = shield_max * 0.05
		return
	_shield_break()


func _shield_break() -> void:
	shield = 0.0
	_regen = 0.0
	vulnerable_t = vulnerable_len
	var p := _sh_anchor()
	main.float_text(p, "BRISÉ", SHIELD_C)
	main.float_text(p + Vector3(0, 0.9, 0), "VULNÉRABLE !", Toon.GOLD)
	main.vfx.ring(Vector3(p.x, 0.1, p.z), SHIELD_C, 2.0)
	main.vfx.sparks(p + Vector3(0, 1.2, 0), Vector3.UP, 16, SHIELD_C)
	main.sfx.play("strike", 1.6, -3.0)
	main.sfx.play("torii", 1.25, -6.0)
	main.feel("heavy")
	main.shake = maxf(float(main.shake), 0.69)
	if kind == "okappa":
		# sonné : coupelle renversée (_kp_anim la penche), bras pendants, plus d'attaque
		_cancel()
		_kp_glow(0.0)
		body.position.y = 0.0
		_state = "stun"
		_pose_tgt = 0.0
		_anim_lock = 0.0
	else:
		# il reste en surface là où il est, sonné, le temps de la fenêtre
		_clear_marks()
		_state = "stun"


## Bouclier remis à neuf (fin de fenêtre) : recharge animée.
func _shield_refill() -> void:
	vulnerable_t = 0.0
	if shield_max <= 0.0 or dead:
		return
	_regen = REGEN_TIME
	shield = maxf(shield, 0.0)


func _shield_tick(delta: float) -> void:
	if shield_max <= 0.0:
		return
	if dead:
		vulnerable_t = 0.0
	elif vulnerable_t > 0.0:
		vulnerable_t -= delta
		if vulnerable_t <= 0.0:
			_shield_refill()
			var p := _sh_anchor()
			main.vfx.ring(Vector3(p.x, 0.1, p.z), SHIELD_C, 1.4)
			main.sfx.play("ink", 0.8, -6.0)
			if _state == "stun":
				_state = "idle" if kind == "okappa" else "dive"
				_timer = 0.8 if kind == "okappa" else 1.0
				if kind == "okappa":
					body.rotation.z = 0.0
				else:
					var hd: Node3D = _segs[0]
					hd.rotation.z = 0.0
	elif _regen > 0.0:
		_regen -= delta
		shield = minf(shield_max, shield + shield_max * delta / REGEN_TIME)
		if _regen <= 0.0:
			_regen = 0.0
			shield = shield_max
	_shield_visual(delta)


## Bulle bleue tant que le bouclier tient (elle gonfle en se reformant), aura dorée quand il est brisé.
func _shield_visual(delta: float) -> void:
	if _sh_root == null:
		return
	_sh_root.global_position = _sh_anchor()
	_sh_pop = maxf(0.0, _sh_pop - delta)
	var off := dead or _sh_hidden()
	_bubble.visible = shield > 0.0 and not off
	if _bubble.visible:
		var k := 1.0 if _regen <= 0.0 else clampf(1.0 - _regen / REGEN_TIME, 0.15, 1.0)
		_bubble.scale = _sh_size * k * (1.0 + _sh_pop + 0.02 * sin(_t * 3.0))
		_sh_mat.albedo_color = Color(SHIELD_C, 0.1 + 0.1 * clampf(shield / shield_max, 0.0, 1.0) + _sh_pop)
	_aura.visible = vulnerable_t > 0.0 and not off
	if _aura.visible:
		var pulse := 0.5 + 0.5 * sin(_t * 9.0)
		_aura.scale = _sh_size * (1.05 + 0.06 * pulse)
		_aura_mat.albedo_color = Color(Toon.GOLD, 0.12 + 0.16 * pulse)


func _make_zone(center: Vector3, r: float, t: float) -> void:
	_cancel()
	_zone = Node3D.new()
	_zone.top_level = true
	add_child(_zone)
	_zone.global_position = Vector3(center.x, 0, center.z)
	_zone_center = Vector3(center.x, 0, center.z)
	_zone_r = r
	_timer = t
	_zone_fill = main.vfx.tele_disc(_zone, r)


func _cancel() -> void:
	if _zone:
		_zone.queue_free()
		_zone = null


func _zone_step(total: float) -> bool:
	var k := 1.0 - _timer / total
	main.vfx.tele_update(_zone_fill, k, _timer)
	return _timer <= 0.0


# ------------------------------------------------------------------ boucle

func _process(delta: float) -> void:
	_t += delta
	if _flash > 0.0:
		_flash -= delta
		if kind == "okappa":
			_kp_glow(1.0 if _flash > 0.0 else 0.0, Color.WHITE)
	_shield_tick(delta)
	if kind == "okappa":
		_okappa(delta)
	else:
		_uwabami(delta)


func _okappa(delta: float) -> void:
	var to := hero.position - position
	to.y = 0
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	if _anim_lock > 0.0:
		_anim_lock -= delta
	if _surf_t > 0.0:
		_surf_t -= delta
	if _state != "dying" and _state != "stun":
		body.rotation.y = lerp_angle(body.rotation.y, atan2(-dir.x, -dir.z), minf(1.0, delta * 5.0))
	match _state:
		"spawn":
			_timer -= delta
			body.scale = Vector3.ONE * clampf(1.0 - _timer / 1.2, 0.01, 1.0)
			if _timer <= 0.0:
				body.scale = Vector3.ONE
				_state = "idle"
				_timer = 1.0
		"idle":
			# garde ses distances en glissant sur le côté
			var side := Vector3(-dir.z, 0, dir.x) * sin(_t * 0.6)
			var want := -1.0 if dist < 4.0 else (1.0 if dist > 6.5 else 0.0)
			position += (dir * want + side * 0.7) * 1.3 * delta
			main.clamp_to_arena(self, radius)
			_timer -= delta
			if _timer <= 0.0:
				_cycle += 1
				if _cycle % 3 == 0:
					_state = "sink"
					_timer = 0.6
				else:
					# bras levés, bâton dressé : la salve se charge
					_state = "fan"
					_timer = 0.8
					_pose_tgt = 1.0
		"fan":
			if _flash <= 0.0:
				_kp_glow(0.55 * (1.0 - _timer / 0.8))
			_timer -= delta
			if _timer <= 0.0:
				if _flash <= 0.0:
					_kp_glow(0.0)
				for i in 5:
					var a := deg_to_rad(-30.0 + 15.0 * i)
					var d := dir.rotated(Vector3.UP, a)
					main.spawn_bullet(position + Vector3(0, 1.4, 0) + d * 0.8, d)
				_state = "idle"
				_timer = 1.5
		"sink":
			_timer -= delta
			body.position.y = lerpf(0.0, -2.6, clampf(1.0 - _timer / 0.6, 0.0, 1.0))
			if _timer <= 0.0:
				_state = "hidden"
				_make_zone(hero.position, 1.6, 1.2)
		"hidden":
			_timer -= delta
			if _zone_step(1.2):
				var c := _zone_center
				_cancel()
				position = Vector3(c.x, 0, c.z)
				main.clamp_to_arena(self, radius)
				main.enemy_strike(c, 1.6)
				body.position.y = 0.0
				# il jaillit bras écartés, puis les laisse retomber
				_pose_tgt = 1.0
				_anim_lock = 0.5
				_state = "idle"
				_timer = 1.4
				_surf_t = SURF_WINDOW
		"stun":
			# coupelle renversée : il titube jusqu'à la fin de la fenêtre (_shield_tick le relève)
			body.rotation.z = sin(_t * 12.0) * 0.08
		"dying":
			_timer += delta
			if not _death_played:
				_death_played = true
				_kp_glow(0.0)
			# il s'affaisse, penche, puis coule
			var kd := minf(_timer, 1.0)
			body.rotation.z = minf(_timer * 1.5, 1.0) * 0.45
			body.scale = Vector3(1.0 + 0.1 * kd, 1.0 - 0.15 * kd, 1.0 + 0.1 * kd)
			if _timer > 1.4:
				body.position.y -= delta * 1.5
			if _timer > 2.2:
				queue_free()
	_kp_anim(delta)


func _uwabami(delta: float) -> void:
	match _state:
		"dive":
			# sous l'eau : on prépare la prochaine traversée
			_depth = move_toward(_depth, -1.6, delta * 2.5)
			_timer -= delta
			if _timer <= 0.0 and _depth <= -1.55:
				_plan_crossing()
				_state = "telegraph"
				_timer = 1.3
		"telegraph":
			# sillage d'écume : le chemin qu'il va prendre
			_timer -= delta
			var k := 1.0 - _timer / 1.3
			for i in _marks.get_child_count():
				var m: Node3D = _marks.get_child(i)
				m.visible = float(i) / float(_marks.get_child_count()) <= k * 1.4
				main.vfx.tele_dot_flash(m as MeshInstance3D, _timer < 0.15)
			if _timer <= 0.0:
				_state = "undulate"
				_path_i = 0
				_segs_at_path_start()
		"undulate":
			_depth = move_toward(_depth, 0.0, delta * 3.0)
			var speed := 6.5 if hp > max_hp * 0.5 else 8.0
			_advance_head(speed * delta)
			if _path_i >= _path.size():
				_clear_marks()
				_state = "rest"
				_timer = 3.2
		"rest":
			# corps posé dans l'arène : la fenêtre pour le trancher dans sa longueur
			_timer -= delta
			if _timer <= 0.0:
				_state = "spit"
				_burst = 0
				_fired = 0
				_timer = 0.6
		"spit":
			var head: Node3D = _segs[0]
			var to := hero.position - head.position
			to.y = 0
			head.rotation.y = lerp_angle(head.rotation.y, atan2(-to.x, -to.z), minf(1.0, delta * 6.0))
			_timer -= delta
			if _timer <= 0.0:
				var d := to.normalized()
				main.spawn_bullet(head.position + Vector3(0, 0.9, 0) + d * 0.9, d)
				_fired += 1
				_timer = 0.14
				if _fired >= 6:
					_fired = 0
					_burst += 1
					_timer = 0.9
					if _burst >= 3:
						_state = "dive"
						_timer = 1.0
		"stun":
			# bouclier brisé : il remonte et reste en surface, sonné (_shield_tick le fait replonger)
			_depth = move_toward(_depth, 0.0, delta * 3.0)
			var hd: Node3D = _segs[0]
			hd.rotation.z = sin(_t * 10.0) * 0.25
		"dying":
			_timer += delta
			_depth = move_toward(_depth, -2.0, delta * 0.9)
			for s in _segs:
				s.rotation.z = sin(_t * 10.0 + s.position.x) * 0.2
			if _timer > 2.6:
				queue_free()
	_update_body()


func _plan_crossing() -> void:
	# traversée en S de haut en bas (ou l'inverse), qui finit posée dans l'arène
	_path.clear()
	var down := randf() < 0.5
	var amp := randf_range(1.8, HALF.x - 1.2)
	var phase := randf() * TAU
	var z0 := -HALF.y - 3.0
	var z1 := HALF.y - 2.5
	var steps := 60
	for i in steps + 1:
		var u := float(i) / steps
		var z := lerpf(z0, z1, u) if down else lerpf(-z0, -z1, u)
		var x := amp * sin(phase + u * TAU * 1.1)
		_path.append(Vector3(x, 0, z))
	_clear_marks()
	for i in range(0, _path.size(), 2):
		var p: Vector3 = _path[i]
		if absf(p.z) > HALF.y + 0.5:
			continue
		var m: MeshInstance3D = main.vfx.tele_dot(_marks, 0.22)
		m.position = Vector3(p.x, m.position.y, p.z)
		m.visible = false


func _clear_marks() -> void:
	for m in _marks.get_children():
		m.queue_free()


func _segs_at_path_start() -> void:
	# le corps démarre caché derrière le point de départ
	var start: Vector3 = _path[0]
	var second: Vector3 = _path[1]
	var back := (start - second).normalized()
	_trail.clear()
	for i in SEGMENTS * 12:
		_trail.append(start + back * (i * SPACING / 12.0))


func _advance_head(dist: float) -> void:
	var head_pos: Vector3 = _trail[0]
	while dist > 0.0 and _path_i < _path.size():
		var target: Vector3 = _path[_path_i]
		var to := target - head_pos
		var d := to.length()
		if d <= dist:
			head_pos = target
			dist -= d
			_path_i += 1
		else:
			head_pos += to / d * dist
			dist = 0.0
		_push_trail(head_pos)


## _trail[0] est la tête « flottante » (position exacte), _trail[1] le dernier échantillon fixé : on compare
## toujours au point FIXÉ. (Avant, on comparait à la tête flottante qu'on venait de déplacer : à 120 Hz un pas
## d'image est plus court que l'écart d'échantillon, la traîne ne grandissait jamais et tout le corps restait
## empilé sous la tête.)
func _push_trail(p: Vector3) -> void:
	var step := SPACING / 12.0
	var anchor: Vector3 = _trail[1] if _trail.size() > 1 else _trail[0]
	var d := p.distance_to(anchor)
	if d < step:
		_trail[0] = p
		return
	var n := int(d / step)
	if _trail.size() > 1:
		_trail.pop_front()  # la tête flottante est remplacée par les échantillons fixés
	for i in range(1, n + 1):
		_trail.push_front(anchor.lerp(p, float(i) / n))
	if _trail[0] != p:
		_trail.push_front(p)
	while _trail.size() > SEGMENTS * 12 + 2:
		_trail.pop_back()


func _update_body() -> void:
	for i in SEGMENTS:
		var s: Node3D = _segs[i]
		var idx := mini(i * 12, _trail.size() - 1)
		var p: Vector3 = _trail[idx]
		var nxt: Vector3 = _trail[mini(idx + 6, _trail.size() - 1)]
		var wave := sin(_t * 4.0 - i * 0.6) * 0.08
		s.position = Vector3(p.x, _depth + wave + (0.0 if i > 0 or _state != "spit" else 0.3), p.z)
		var dir := p - nxt
		if dir.length_squared() > 0.0001 and (i > 0 or _state != "spit"):
			s.rotation.y = atan2(-dir.x, -dir.z)
		s.visible = _depth > -1.5
		var flash := _flash > 0.0
		s.scale = Vector3.ONE * (1.08 if flash else 1.0)


# ------------------------------------------------------------------ robot testeur

## Trait qu'un bon joueur tracerait maintenant (points au sol depuis le héros), ou vide = attendre.
func bot_stroke(hero_pos: Vector3) -> PackedVector3Array:
	var none := PackedVector3Array()
	var h := Vector3(hero_pos.x, 0, hero_pos.z)
	if dead:
		return none
	if kind == "okappa":
		if _state in ["spawn", "sink", "hidden", "dying"]:
			return none
		# trait droit (iaï) à travers lui : à la sortie de l'eau il brise le bouclier, sinon il l'use ;
		# sonné (vulnérable), chaque iaï porte ×2
		return _bot_line(h, Vector3(position.x, 0, position.z), 7.3)
	if vulnerable_t > 0.0:
		# sonné en surface : iaï à travers le segment dans l'arène le plus proche, encore et encore
		if vulnerable_t < 0.3 or _depth < -0.4:
			return none
		var tgt := Vector3.INF
		var best_d := 1e9
		for s in _segs:
			var sn: Node3D = s
			var sp := Vector3(sn.position.x, 0, sn.position.z)
			if not (absf(sp.x) <= BOT_HALF.x - 0.3 and absf(sp.z) <= BOT_HALF.y - 0.3):
				continue
			var dd := h.distance_to(sp)
			if dd < best_d:
				best_d = dd
				tgt = sp
		if tgt == Vector3.INF:
			return none
		return _bot_line(h, tgt, 7.3)
	# Uwabami : corps posé (repos, crachats), tranché d'un bout à l'autre (le bouclier tombe)
	if _depth < -0.3 or not (_state == "rest" or _state == "spit"):
		return none
	var pts: Array = []
	for s in _segs:
		var sn: Node3D = s
		pts.append(Vector3(sn.position.x, 0, sn.position.z))
	var head: Vector3 = pts[0]
	var tail: Vector3 = pts[SEGMENTS - 1]
	if h.distance_to(tail) < h.distance_to(head):
		pts.reverse()
	var first: Vector3 = pts[0]
	var second: Vector3 = pts[1]
	if h.distance_to(first) > 3.0:
		# placement dans le prolongement du bout le plus proche
		var lead := first + (first - second).normalized() * 1.0
		return _bot_route([h, lead], pts, SEG_R + 0.75)
	var last: Vector3 = pts[SEGMENTS - 1]
	var prev: Vector3 = pts[SEGMENTS - 2]
	var way: Array = [h]
	way.append_array(pts)
	way.append(last + (last - prev).normalized() * 1.2)
	return _bot_dense(way)


const BOT_HALF := Vector2(4.3, 8.3)  # bornes des points du robot (comme main._clamp_point)


func _bot_clamp(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, -BOT_HALF.x, BOT_HALF.x), 0, clampf(p.z, -BOT_HALF.y, BOT_HALF.y))


## Polyligne finale : au sol, bornée à l'arène, points espacés de 0.4 m au plus.
func _bot_dense(way: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in way.size():
		var p: Vector3 = way[i]
		if i == 0:
			out.append(Vector3(p.x, 0, p.z))
			continue
		p = _bot_clamp(p)
		var last: Vector3 = out[out.size() - 1]
		var n := int(ceil(last.distance_to(p) / 0.4))
		for k in range(1, n + 1):
			out.append(last.lerp(p, float(k) / float(n)))
	return out


## Relie les points de passage en contournant les points `avoid` (à `clear` m près).
func _bot_route(way: Array, avoid: Array, clear: float) -> PackedVector3Array:
	var first: Vector3 = way[0]
	var pts: Array = [Vector3(first.x, 0, first.z)]
	for i in range(1, way.size()):
		var a: Vector3 = pts[pts.size() - 1]
		var b: Vector3 = way[i]
		_bot_leg(pts, a, _bot_clamp(b), avoid, clear, 3)
	return _bot_dense(pts)


func _bot_leg(out: Array, a: Vector3, b: Vector3, avoid: Array, clear: float, depth: int) -> void:
	var seg := b - a
	seg.y = 0
	var l2 := seg.length_squared()
	var best_t := 2.0
	var hit := Vector3.ZERO
	if depth > 0 and l2 > 0.0001:
		for o in avoid:
			var p: Vector3 = o
			p.y = 0
			if p.distance_to(a) < clear or p.distance_to(b) < clear:
				continue
			var t := clampf((p - a).dot(seg) / l2, 0.0, 1.0)
			if (a + seg * t).distance_to(p) < clear and t < best_t:
				best_t = t
				hit = p
	if best_t > 1.0:
		out.append(b)
		return
	# détour : on passe à côté de l'obstacle le plus proche du départ
	var q := a + seg * best_t
	var n := q - hit
	n.y = 0
	if n.length() < 0.05:
		n = Vector3(-seg.z, 0, seg.x)
		if n.dot(-q) < 0.0:
			n = -n
	var w := _bot_clamp(hit + n.normalized() * (clear + 0.35))
	_bot_leg(out, a, w, avoid, clear, depth - 1)
	_bot_leg(out, w, b, avoid, clear, depth - 1)


## Place libre devant p dans la direction dir avant le bord de l'arène.
func _bot_room(p: Vector3, dir: Vector3) -> float:
	var t := 99.0
	if dir.x > 0.001:
		t = minf(t, (BOT_HALF.x - p.x) / dir.x)
	elif dir.x < -0.001:
		t = minf(t, (-BOT_HALF.x - p.x) / dir.x)
	if dir.z > 0.001:
		t = minf(t, (BOT_HALF.y - p.z) / dir.z)
	elif dir.z < -0.001:
		t = minf(t, (-BOT_HALF.y - p.z) / dir.z)
	return maxf(t, 0.0)


## Trait droit qui traverse tgt, long d'au moins min_len si l'arène le permet (iaï dès 7 m).
func _bot_line(h: Vector3, tgt: Vector3, min_len: float) -> PackedVector3Array:
	var d := tgt - h
	d.y = 0
	var dist := d.length()
	var dir := Vector3(-h.x, 0, -h.z)
	if dist > 0.3:
		dir = d / dist
	if dir.length_squared() < 0.01:
		dir = Vector3(0, 0, 1)
	dir = dir.normalized()
	var l := minf(maxf(min_len, dist + 1.2), _bot_room(h, dir))
	if l < dist + 0.5:
		# cible collée au bord : on la traverse puis on revient vers le centre
		var back := Vector3(-tgt.x, 0, -tgt.z)
		if back.length_squared() < 0.01:
			back = Vector3(0, 0, 1)
		return _bot_dense([h, tgt, tgt + back.normalized() * 2.0])
	return _bot_dense([h, h + dir * l])
