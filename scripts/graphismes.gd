extends RefCounted
## OPTIONS > GRAPHISMES : ZINZIN / ÉQUILIBRÉ / ÉCO. Tout ce qui tient à la lumière, aux ombres et au post-traitement
## (renderer Compatibility, sur téléphone comme sur bureau) se règle ici, en direct, sans rebâtir la salle :
##  - ZINZIN : soleil à ombres douces (2048, PCF), ombres des lumières ponctuelles (lanternes, feux, sanctuaire :
##    atlas d'ombres réactivé), rayons de soleil appuyés, brume de sol, particules densifiées, lueur colorée des
##    boss, glow plus large, étalonnage plus contrasté et saturé, vignette et grain du papier même sur téléphone,
##    3D rendue plus près de la résolution native (0,9 au lieu de 0,8 sur téléphone) ;
##  - ÉQUILIBRÉ : l'ancien rendu amélioré : soleil 2048 à filtrage léger, ombres de contact des props, rayons,
##    glow d'origine, aucune ombre ponctuelle, pas de brume ;
##  - ÉCO : l'ancien rendu allégé : soleil 1024 à ombre nette et courte, une seule lumière ponctuelle par salle,
##    sans glow ni ombres de contact ni rayons, particules réduites, 3D en dessous de la résolution native.
## Distinct d'ÉCONOMIE BATTERIE (qui borne la cadence à 30 images/s) : on peut vouloir le plein rendu à 30 images/s,
## ou un rendu léger à pleine cadence sur un vieux téléphone.
## Les nœuds d'ambiance se déclarent par groupe : GROUP_ZINZIN (visibles en ZINZIN seulement), GROUP_RICH (cachés en
## ÉCO), GROUP_OMNI (lumières ponctuelles dont l'ombre suit le niveau), GROUP_PARTS (émetteurs dont la densité suit
## le niveau : meta `amount0`). Les lumières de salle se comptent à la construction (max_lights) : un changement de
## niveau vaut pour la salle suivante.

const Toon = preload("res://scripts/toon.gd")
const MIST_SHADER = preload("res://shaders/brume.gdshader")

const LEVELS := ["zinzin", "balanced", "eco"]
const DEFAULT := "zinzin"
const GROUP_ZINZIN := &"gfx_zinzin"
const GROUP_RICH := &"gfx_rich"
const GROUP_OMNI := &"gfx_omni"
const GROUP_PARTS := &"gfx_parts"

static var level := DEFAULT
static var rev := 0  # change à chaque application (les constructeurs qui lisent le niveau peuvent le guetter)


static func is_zinzin() -> bool:
	return level == "zinzin"


static func is_eco() -> bool:
	return level == "eco"


## Niveau lu dans la sauvegarde avant que le monde ne soit bâti (main._build_world précède main._load).
static func load_level(path: String) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		set_level(String(cfg.get_value("settings", "gfx", DEFAULT)))
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--gfx="):
			set_level(s.substr(6))  # mesures et captures : `-- --gfx=eco`


static func set_level(l: String) -> void:
	level = l if l in LEVELS else DEFAULT


## Lumières ponctuelles de props par salle (worlds.gd _light) : ZINZIN et ÉQUILIBRÉ en gardent trois (deux sur
## téléphone en ÉQUILIBRÉ : chaque lumière refait une passe sur ce qu'elle touche), ÉCO une seule.
static func max_lights(base: int) -> int:
	match level:
		"zinzin":
			return base
		"balanced":
			return mini(base, 2) if Toon.lite else base
	return mini(base, 1)


## Densité des particules d'ambiance (facteur sur `amount` déclaré).
static func parts_k() -> float:
	match level:
		"zinzin":
			return 1.6
		"eco":
			return 0.6
	return 1.0


## Force des rayons de soleil (facteur sur la force déclarée du monde ; 0 : cachés).
static func rays_k() -> float:
	match level:
		"zinzin":
			return 2.4
		"eco":
			return 0.0
	return 1.15


## Applique le niveau à toute la scène : réglages du moteur, soleil, environnement, voile, nœuds d'ambiance.
static func apply(tree: SceneTree, env: Environment, sun: DirectionalLight3D, viewport: Viewport, veil: ShaderMaterial) -> void:
	rev += 1
	var lite := Toon.lite
	var zz := is_zinzin()
	var eco := is_eco()
	# --- soleil : taille de la carte d'ombre, filtrage, portée, douceur
	match level:
		"zinzin":
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
			sun.shadow_blur = 1.6
			sun.shadow_opacity = 0.84
			sun.directional_shadow_max_distance = 36.0 if lite else 45.0
		"balanced":
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
			sun.shadow_blur = 1.2
			sun.shadow_opacity = 0.76
			sun.directional_shadow_max_distance = 26.0 if lite else 45.0
		_:
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
			sun.shadow_blur = 1.0
			sun.shadow_opacity = 0.68
			sun.directional_shadow_max_distance = 26.0
	# --- ombres des lumières ponctuelles : atlas réservé en ZINZIN seulement (sinon aucune mémoire)
	viewport.positional_shadow_atlas_size = 2048 if zz else 0
	if zz:
		RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	for n in tree.get_nodes_in_group(GROUP_OMNI):
		var l := n as OmniLight3D
		if l != null:
			l.shadow_enabled = zz
	# --- post-traitement : glow, tonemap, étalonnage
	if eco:
		env.glow_enabled = false
	else:
		env.glow_enabled = true
		if zz:
			env.glow_intensity = 0.85
			env.glow_strength = 1.08
			env.glow_bloom = 0.03
			env.glow_hdr_threshold = 0.98
			env.set_glow_level(0, false)
			env.set_glow_level(1, true)
			env.set_glow_level(2, true)
			env.set_glow_level(3, true)
			env.set_glow_level(4, true)
			env.set_glow_level(5, false)
			env.set_glow_level(6, false)
		else:
			env.glow_intensity = 0.6
			env.glow_strength = 1.1
			env.glow_bloom = 0.0
			env.glow_hdr_threshold = 1.05
			for i in 7:
				env.set_glow_level(i, i == 2 or i == 4)
	# tonemap : linéaire à tous les niveaux. Le filmique (essayé en ZINZIN, exposition 0,92 à 1,18, point blanc 1,2 à
	# 1,6) remonte les demi-teintes d'un bon cinquième (biais d'exposition ×2 du filmique de Godot) : planches, dalles
	# et papier pâlissent en plein jour, ce que ni le contraste ni la clarté ne rattrapent sans ternir les blancs.
	# ZINZIN affirme donc la palette par l'étalonnage : plus de contraste et de saturation.
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.tonemap_white = 1.0
	if zz:
		env.adjustment_saturation = 1.1
		env.adjustment_contrast = 1.2
		env.adjustment_brightness = 1.0
	else:
		env.adjustment_saturation = 1.04
		env.adjustment_contrast = 1.14
		env.adjustment_brightness = 1.0
	# --- voile d'estampe : vignette et grain
	if veil != null:
		veil.set_shader_parameter("vignette", 0.38 if zz else 0.3)
		veil.set_shader_parameter("fine", zz or not lite)
	# --- résolution de la 3D (téléphone : l'interface reste nette quoi qu'il arrive). Anticrénelage : le FXAA du
	# projet. Le MSAA 2x a été essayé en ZINZIN : c'était le poste le plus cher de tous à la mesure (rendu logiciel),
	# pour un gain à peine visible après le FXAA.
	if lite:
		viewport.scaling_3d_scale = 0.9 if zz else (0.8 if not eco else 0.72)
	# --- nœuds d'ambiance
	for n in tree.get_nodes_in_group(GROUP_ZINZIN):
		if n is CPUParticles3D:
			# émetteur caché : arrêté aussi (rien à calculer, et les tirages au hasard du jeu ne bougent pas)
			(n as CPUParticles3D).emitting = zz
		if n is Node3D:
			(n as Node3D).visible = zz
		elif n is CanvasItem:
			(n as CanvasItem).visible = zz
	for n in tree.get_nodes_in_group(GROUP_RICH):
		if n is Node3D:
			(n as Node3D).visible = not eco
	var pk := parts_k()
	for n in tree.get_nodes_in_group(GROUP_PARTS):
		var p := n as CPUParticles3D
		if p != null:
			set_amount(p, pk)


## Émetteur d'ambiance dont la densité suit le niveau (gardé dans son groupe ; `amount` déclaré en meta).
static func register_parts(p: CPUParticles3D) -> void:
	if not p.has_meta(&"amount0"):
		p.set_meta(&"amount0", p.amount)
	p.add_to_group(GROUP_PARTS)
	set_amount(p, parts_k())


static func set_amount(p: CPUParticles3D, k: float) -> void:
	var a0 := int(p.get_meta(&"amount0", p.amount))
	var a := maxi(1, int(round(float(a0) * k)))
	if a != p.amount:
		p.amount = a  # (redémarre l'émetteur : à la construction ou au changement d'option, jamais en plein combat suivi)


## Lumière ponctuelle de décor inscrite : son ombre suit le niveau (ZINZIN : ombre portée).
static func register_light(l: OmniLight3D) -> void:
	l.add_to_group(GROUP_OMNI)
	l.shadow_enabled = is_zinzin()
	l.shadow_bias = 0.08
	l.shadow_normal_bias = 1.6
	l.shadow_blur = 1.2


static var _mist_quad: QuadMesh = null


## Brume de sol du monde (ZINZIN) : nappes couchées en périphérie de l'arène (jamais au centre), couleur de la brume
## du monde un peu refroidie par ses ombres, qui dérivent lentement ; un MultiMesh (1 appel de dessin), sous le
## lointain du monde (il suit la caméra le long de l'étape).
static func build_mist(parent: Node3D, w: Dictionary) -> void:
	if _mist_quad == null:
		_mist_quad = QuadMesh.new()
		_mist_quad.size = Vector2(1.0, 1.0)
	var fog: Color = w.get("fog", Toon.WASHI)
	var sh: Color = w.get("shade", Color(0.8, 0.85, 1.0))
	var tint := fog.lerp(Color(fog.r * sh.r, fog.g * sh.g, fog.b * sh.b), 0.3).lightened(0.08)
	var m := ShaderMaterial.new()
	m.shader = MIST_SHADER
	m.set_shader_parameter("tint", tint)
	var density := float(w.get("fog_density", 0.003))
	m.set_shader_parameter("strength", clampf(0.1 + density * 14.0, 0.13, 0.19))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(w.get("id", 1)) * 101 + 7
	# nappes : deux colonnes (gauche / droite de l'arène) sur toute la longueur de l'étape, et une rangée au loin
	var list: Array = []  # [centre, taille, côté vers le centre (0 : +x, 1 : -x), graine]
	for i in 6:
		var z := lerpf(-10.0, 9.0, (float(i) + 0.5) / 6.0) + rng.randf_range(-0.6, 0.6)
		list.append([Vector3(-6.2 + rng.randf_range(-0.5, 0.5), 0.1, z), Vector2(5.2, 4.2), 1.0, rng.randf()])
		list.append([Vector3(6.2 + rng.randf_range(-0.5, 0.5), 0.1, z), Vector2(5.2, 4.2), 0.0, rng.randf()])
	for i in 3:
		var x := lerpf(-5.0, 5.0, (float(i) + 0.5) / 3.0)
		list.append([Vector3(x, 0.12, -11.5 + rng.randf_range(-0.5, 0.5)), Vector2(6.0, 4.5), 0.5, rng.randf()])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _mist_quad
	mm.instance_count = list.size()
	var flat := Basis(Vector3.RIGHT, -PI * 0.5)
	var aabb := AABB()
	for i in list.size():
		var e: Array = list[i]
		var c: Vector3 = e[0]
		var sz: Vector2 = e[1]
		mm.set_instance_transform(i, Transform3D(flat.scaled(Vector3(sz.x, 1.0, sz.y)), c))
		mm.set_instance_custom_data(i, Color(float(e[2]), float(e[3]), 0.0, 0.0))
		var bx := AABB(c - Vector3(sz.x * 0.5, 0.2, sz.y * 0.5), Vector3(sz.x, 0.4, sz.y))
		aabb = bx if i == 0 else aabb.merge(bx)
	mm.custom_aabb = aabb
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Brume"
	mmi.multimesh = mm
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.add_to_group(GROUP_ZINZIN)
	mmi.visible = is_zinzin()
	parent.add_child(mmi)
