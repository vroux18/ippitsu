extends RefCounted
## Les huit mondes (univers Hokusai, puis Kurama, Ryūgū-jō et Yomi) : données (palette, ambiance, ennemis, difficulté)
## et décor procédural : lointain, props autour de l'arène, particules d'ambiance.
## Uniquement des const et des fonctions static. Matériaux et maillages partagés via des caches ;
## uniquement StandardMaterial3D et CPUParticles3D (renderer Compatibility).
## Performances : tout le décor d'une salle est fusionné par matériau (2 lots : avec / sans ombre)
## et les éléments répétés nombreux (bambous, écume, glaçons, cailloux, papiers) sont des MultiMesh.
## Le lointain « estampe » (ciel en bokashi, montagnes en couches, brume en bandes, oiseaux,
## silhouettes) tient en un seul maillage à couleurs de sommets, sans lumière.

const Toon = preload("res://scripts/toon.gd")
const Decor = preload("res://scripts/decor.gd")
const WATER_SHADER = preload("res://shaders/water.gdshader")

## Surface du vide (eau, lave, encre) : le plan de arena.gd est à y = -0.6, épaisseur 0.1.
const VOID_Y := -0.55
## Zone des particules d'ambiance (couvre l'arène et un peu au-delà).
const PART_AREA := AABB(Vector3(-6, 0, -11), Vector3(12, 5, 22))
const NONE2 := Vector2(9999.0, 9999.0)
const NONE4 := Vector4(9999.0, 9999.0, 0.0, 0.0)
const MAX_LIGHTS := 3  # OmniLight3D de props par salle (mobile)
## Distance des props de bord au bord de la plateforme (empreinte toujours à plus de 0.3).
const EDGE_OFF := 0.55

# couleurs propres aux décors
const TANZAKU := [Color("#EBB8C3"), Color("#B9D3E8"), Color("#F1E3A6"), Color("#C2DFB3"), Color("#FBF8F0")]
const STONE := Color("#B9B3A6")
const STONE_DARK := Color("#8F897D")
const GRAVE := Color("#8F8E92")
const SNOW := Color("#F2F5F8")
const SNOW_SHADE := Color("#B9BCCF")
const BONNET := Color("#2E3446")
const BASALT := Color("#3A3433")
const IRON := Color("#3B3A3E")
const BRAISE := Color("#8E2A1E")
const LAVA := Color("#1E1517")
const LAVA_GOLD := Color("#E0A84A")
const EMBER := Color("#F29A3A")
const FLAME_CORE := Color("#FFD27A")
const SEAL_RED := Color("#B8352A")
const HULL := Color("#4A3A2E")
const CREW := Color("#27324A")
const ICE := Color("#BFD6E3")
const INK_SEA := Color("#1B2232")
# architecture (toits de tuiles, plâtre des kura et des donjons), communes à tous les mondes
const KAWARA := Color("#3A3F4E")  # tuile gris indigo
const KAWARA_DARK := Color("#262A36")  # faîtage, bandeaux
const SHIKKUI := Color("#EDE7DA")  # plâtre blanc

## Index 0 = monde 1. Lecture seule (dictionnaires constants) : dupliquer avant de modifier.
const WORLDS: Array = [
	{
		"id": 1,
		"name": "Grande Vague",
		"kanji": "波",
		"subtitle": "Sous la vague au large de Kanagawa",
		"color": Color("#1F3A5F"),
		"sky": Color("#EFE6D2"),
		"fog": Color("#EFE6D2"),
		"fog_density": 0.0028,
		"sun_color": Color(1.0, 0.9, 0.78),
		"sun_energy": 0.72,
		"ambient_color": Color(0.86, 0.9, 1.0),
		"ambient_energy": 0.3,
		"ground": [Color("#C79B6A"), Color("#BC8F5F"), Color("#D3A874"), Color("#B08458"), Color("#C49668")],  # hinoki doré, chaud et lumineux (le gris délavé faisait triste)
		"ground_style": "planks",
		"edge": Color("#1B1A1E"),
		"under": Color("#3E3631"),
		"void": Color("#1F3A5F"),
		"void_metal": true,
		"enemies": {"oni": 4, "kappa": 2, "brute": 1, "tate": 1, "funa": 2, "umibozu": 2, "kappa_yumi": 2, "ika": 2, "umi_nyobo": 1},
		"hp_mult": 1.0,
	},
	{
		"id": 2,
		"name": "Tanabata",
		"kanji": "竹",
		"subtitle": "Feux de renards la nuit à Oji",
		"color": Color("#5E7F4A"),
		"sky": Color("#1F2A3A"),
		"fog": Color("#2C3848"),
		"fog_density": 0.0035,
		"sun_color": Color(0.78, 0.85, 1.0),
		"sun_energy": 0.55,
		"ambient_color": Color(0.58, 0.68, 0.88),
		"ambient_energy": 0.5,
		"ground": [Color("#6E726E"), Color("#656965"), Color("#777B76"), Color("#5E625E"), Color("#6A6E69")],  # ardoise froide, mousse dans les joints
		"ground_style": "stones",
		"edge": Color("#26252B"),
		"under": Color("#3E4A3A"),
		"void": Color("#1E3330"),
		"void_metal": true,
		"enemies": {"oni": 3, "kappa": 2, "brute": 1, "tate": 1, "funa": 1, "kitsunebi": 2, "kamaitachi": 2, "tanuki": 2, "kitsune_tsukai": 1, "kappa_yumi": 1, "shinobi": 2, "shuriken": 1},
		"hp_mult": 1.15,
	},
	{
		"id": 3,
		"name": "Cent Contes",
		"kanji": "雪",
		"subtitle": "Neige sur la Sumida",
		"color": Color("#8C8FA8"),
		"sky": Color("#D9DFE6"),
		"fog": Color("#E2E7EC"),
		"fog_density": 0.0045,
		"sun_color": Color(0.95, 0.97, 1.0),
		"sun_energy": 0.55,
		"ambient_color": Color(0.8, 0.86, 0.95),
		"ambient_energy": 0.45,
		"ground": [Color("#DDE1E6"), Color("#D2D7DE"), Color("#C8CFD8"), Color("#D7DCE2"), Color("#C2CAD4")],
		"ground_style": "snow",
		"edge": Color("#3A3A48"),
		"under": Color("#8C8FA8"),
		"void": Color("#34465A"),
		"void_metal": true,
		"enemies": {"oni": 2, "kappa": 1, "brute": 1, "tate": 1, "funa": 3, "yukionna": 2, "yuki_warashi": 2, "onryo": 2, "tsurara": 1, "kamaitachi": 1, "umi_nyobo": 1},
		"hp_mult": 1.3,
	},
	{
		"id": 4,
		"name": "Fuji Rouge",
		"kanji": "火",
		"subtitle": "Vent du sud, ciel clair (Gaifu kaisei)",
		"color": Color("#8E2A1E"),
		"sky": Color("#3F5677"),
		"fog": Color("#5A4A4E"),
		"fog_density": 0.003,
		"sun_color": Color(1.0, 0.72, 0.52),
		"sun_energy": 0.8,
		"ambient_color": Color(1.0, 0.75, 0.6),
		"ambient_energy": 0.3,
		"ground": [Color("#47423F"), Color("#4F4A46"), Color("#55504B"), Color("#3D3937"), Color("#4A4541")],
		"ground_style": "basalt",
		"edge": Color("#141215"),
		"under": Color("#2A2220"),
		"void": Color("#241A1A"),
		"void_metal": false,
		"enemies": {"oni": 2, "kappa": 1, "brute": 2, "tate": 1, "funa": 1, "kasha": 2, "hinotama": 2, "teppo": 2, "tengu": 2, "kanabo": 1, "moryo": 1},
		"hp_mult": 1.45,
	},
	{
		"id": 5,
		"name": "Trente-six Vues",
		"kanji": "墨",
		"subtitle": "Trente-six vues du mont Fuji",
		"color": Color("#0E1A2E"),
		"sky": Color("#EAD2C8"),
		"fog": Color("#E4C3B8"),
		"fog_density": 0.0035,
		"sun_color": Color(1.0, 0.88, 0.82),
		"sun_energy": 0.7,
		"ambient_color": Color(1.0, 0.9, 0.9),
		"ambient_energy": 0.35,
		"ground": [Color("#B2AA9A"), Color("#A9A191"), Color("#BAB2A2"), Color("#A39B8B"), Color("#AFA797")],  # papier vieilli, plus soutenu (le blanc saturait)
		"ground_style": "paper",
		"edge": Color("#1B1A1E"),
		"under": Color("#3A3530"),
		"void": Color("#0E1A2E"),
		"void_metal": true,
		"enemies": {"oni": 2, "kappa": 1, "brute": 1, "tate": 2, "funa": 1, "kagebo": 2, "sumidama": 2, "kasa": 2, "moryo": 1, "onryo": 1, "teppo": 1, "tengu": 1, "kitsune_tsukai": 1, "shinobi": 2, "shuriken": 2, "kemuri": 2, "kunoichi": 1},
		"hp_mult": 1.6,
	},
	{
		"id": 6,
		"name": "Kurama",
		"kanji": "天",
		"subtitle": "La forêt des tengu sur le mont Kurama",
		"color": Color("#2F4A34"),
		"sky": Color("#C6CFBD"),
		"fog": Color("#AEBDA9"),
		"fog_density": 0.0042,
		"sun_color": Color(0.96, 0.95, 0.84),
		"sun_energy": 0.64,
		"ambient_color": Color(0.74, 0.88, 0.76),
		"ambient_energy": 0.42,
		"ground": [Color("#676856"), Color("#5E5F4D"), Color("#6E6F5C"), Color("#57594A"), Color("#636452")],  # dalles moussues
		"ground_style": "stones",
		"edge": Color("#1A1E1A"),
		"under": Color("#33402F"),
		"void": Color("#1C2C22"),
		"void_metal": true,
		"enemies": {"oni": 2, "kappa": 1, "brute": 1, "tate": 1, "funa": 1, "tengu": 2, "kamaitachi": 1, "moryo": 1, "karasu": 3, "yamabushi": 2, "konoha": 2, "shinobi": 2, "shuriken": 1, "kemuri": 1, "kunoichi": 2},
		"hp_mult": 1.7,
	},
	{
		"id": 7,
		"name": "Ryūgū-jō",
		"kanji": "龍",
		"subtitle": "Le palais du roi dragon sous la mer",
		"color": Color("#1E5A5E"),
		"sky": Color("#3F8486"),
		"fog": Color("#4E8C8A"),
		"fog_density": 0.0055,
		"sun_color": Color(0.78, 0.96, 0.94),
		"sun_energy": 0.6,
		"ambient_color": Color(0.6, 0.9, 0.92),
		"ambient_energy": 0.5,
		"ground": [Color("#6A3C35"), Color("#61362F"), Color("#73443B"), Color("#5A332D"), Color("#673A33")],  # planches laquées du palais
		"ground_style": "planks",
		"edge": Color("#14181C"),
		"under": Color("#2A3A3E"),
		"void": Color("#0E3A44"),
		"void_metal": true,
		"enemies": {"oni": 2, "kappa": 1, "brute": 1, "tate": 1, "funa": 2, "umibozu": 1, "ika": 2, "umi_nyobo": 1, "kani": 3, "ningyo": 2, "fugu": 2},
		"hp_mult": 1.8,
	},
	{
		"id": 8,
		"name": "Yomi",
		"kanji": "冥",
		"subtitle": "Le pays des morts, au-delà de la pente de Yomotsu",
		"color": Color("#3A2E48"),
		"sky": Color("#3A3442"),
		"fog": Color("#4A4452"),
		"fog_density": 0.005,
		"sun_color": Color(0.82, 0.78, 0.95),
		"sun_energy": 0.55,
		"ambient_color": Color(0.7, 0.64, 0.88),
		"ambient_energy": 0.48,
		"ground": [Color("#5B585E"), Color("#525056"), Color("#615E64"), Color("#4B494F"), Color("#57545A")],  # dalles de cendre
		"ground_style": "stones",
		"edge": Color("#0E0C10"),
		"under": Color("#242028"),
		"void": Color("#140F1C"),
		"void_metal": false,
		"enemies": {"oni": 2, "kappa": 1, "brute": 1, "tate": 1, "onryo": 2, "kagebo": 1, "kanabo": 1, "moryo": 1, "gaki": 3, "gokusotsu": 2, "shiryo": 2, "kemuri": 1},
		"hp_mult": 1.9,
	},
]

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}


## Données du monde `id` (1..WORLDS.size()).
static func world(id: int) -> Dictionary:
	var d: Dictionary = WORLDS[clampi(id, 1, WORLDS.size()) - 1]
	return d


## Matière du sol du monde (shaders/ground.gdshader) : 2e teinte des tuiles, mousse, usure,
## couleur d'incrustation rare (accent unique du monde, alpha 0 = aucune). Le rouge est gardé pour le
## jeu (ennemis, attaques annoncées) : les sols restent dans les gris, indigos et ocres de l'estampe.
static func floor_look(id: int) -> Dictionary:
	match clampi(id, 1, WORLDS.size()):
		1:
			return {"alt": Color("#9C7148"), "alt_k": 0.4, "moss": Color("#4E5A48"), "moss_k": 0.0, "wear": 0.5, "accent": Color("#34486A"), "leaves": [Color("#E3B4BF"), Color("#F0D3D9")]}
		2:
			return {"alt": Color("#5D6B60"), "alt_k": 0.5, "moss": Color("#3F5440"), "moss_k": 0.45, "wear": 0.2, "accent": Color(0, 0, 0, 0), "leaves": [Color("#7E8F55"), Color("#9AA36A")]}
		3:
			return {"alt": Color("#B8C2CE"), "alt_k": 0.4, "moss": Color("#9AA6B4"), "moss_k": 0.0, "wear": 0.0, "accent": Color(0, 0, 0, 0)}
		4:
			return {"alt": Color("#3A3230"), "alt_k": 0.6, "moss": Color("#5A3A2C"), "moss_k": 0.0, "wear": 0.3, "accent": Color(0, 0, 0, 0)}
		5:
			return {"alt": Color("#A39A88"), "alt_k": 0.4, "moss": Color("#8E8674"), "moss_k": 0.0, "wear": 0.2, "accent": Color(0, 0, 0, 0)}
		6:
			return {"alt": Color("#556048"), "alt_k": 0.6, "moss": Color("#3D5236"), "moss_k": 0.6, "wear": 0.15, "accent": Color(0, 0, 0, 0), "leaves": [Color("#8A6A3A"), Color("#6B7240")]}
		7:
			return {"alt": Color("#4E3A36"), "alt_k": 0.5, "moss": Color("#2E4A48"), "moss_k": 0.2, "wear": 0.35, "accent": Color("#A8843E"), "leaves": [Color("#D6C7B2")]}
		8:
			return {"alt": Color("#4A4552"), "alt_k": 0.55, "moss": Color("#3E3A48"), "moss_k": 0.0, "wear": 0.3, "accent": Color(0, 0, 0, 0), "leaves": [Color("#8C8794")]}
		_:
			return {"alt": Color("#9C9384"), "alt_k": 0.5, "moss": Color("#7E786A"), "moss_k": 0.0, "wear": 0.25, "accent": Color(0, 0, 0, 0)}


## Eau (ou lave, encre) du vide : fond profond / clair, écume, intensité des rubans, vitesse, rubans par mètre,
## écume du bord, force du motif seigaiha au large (0 : aucun ; jamais au pied des plateformes).
static func water_style(id: int) -> Dictionary:
	match clampi(id, 1, WORLDS.size()):
		1:
			return {"deep": Color("#142A48"), "shallow": Color("#24466E"), "foam": Color("#E2E8EA"), "k": 0.42, "flow": 1.0, "band": 0.8, "shore": 0.55, "sei": 0.32}
		2:
			return {"deep": Color("#13221F"), "shallow": Color("#24403B"), "foam": Color("#9FB8A8"), "k": 0.25, "flow": 0.5, "band": 0.6, "shore": 0.3, "sei": 0.16}
		3:
			return {"deep": Color("#26364A"), "shallow": Color("#3E536A"), "foam": Color("#DCE6EE"), "k": 0.35, "flow": 0.6, "band": 0.7, "shore": 0.5, "sei": 0.2}
		4:
			return {"deep": Color("#1A1212"), "shallow": Color("#2E201E"), "foam": Color("#7A3018"), "k": 0.3, "flow": 0.35, "band": 0.5, "shore": 0.35, "sei": 0.0}
		6:
			return {"deep": Color("#121E17"), "shallow": Color("#26392D"), "foam": Color("#A9B89C"), "k": 0.22, "flow": 0.45, "band": 0.6, "shore": 0.3, "sei": 0.14}
		7:
			return {"deep": Color("#082A33"), "shallow": Color("#145060"), "foam": Color("#9EE0DA"), "k": 0.3, "flow": 0.6, "band": 0.7, "shore": 0.4, "sei": 0.26}
		8:
			return {"deep": Color("#0D0A13"), "shallow": Color("#211A2C"), "foam": Color("#8E7FB0"), "k": 0.22, "flow": 0.3, "band": 0.5, "shore": 0.3, "sei": 0.0}
		_:
			return {"deep": Color("#0A1322"), "shallow": Color("#16243A"), "foam": Color("#CFC6B2"), "k": 0.3, "flow": 0.7, "band": 0.9, "shore": 0.45, "sei": 0.24}


## Matériau du vide d'un monde (un par monde affiché : son cadre d'écume change d'une salle à l'autre).
static func water_material(id: int) -> ShaderMaterial:
	var s := water_style(id)
	var m := ShaderMaterial.new()
	m.shader = WATER_SHADER
	m.set_shader_parameter("deep", s["deep"])
	m.set_shader_parameter("shallow", s["shallow"])
	m.set_shader_parameter("foam", s["foam"])
	m.set_shader_parameter("foam_k", float(s["k"]))
	m.set_shader_parameter("flow", float(s["flow"]))
	m.set_shader_parameter("band", float(s["band"]))
	m.set_shader_parameter("shore_k", float(s["shore"]))
	m.set_shader_parameter("sei_k", float(s.get("sei", 0.0)))
	m.set_shader_parameter("fine", not Toon.lite)
	return m


# ------------------------------------------------------------------ matériaux (cache)

## Toon à contour d'encre (ou non), partagé par couleur.
static func _toon(color: Color, outline := true, osz := 0.03) -> StandardMaterial3D:
	var key := "t%s_%d_%.3f" % [color.to_html(true), 1 if outline else 0, osz]
	if _mats.has(key):
		var cached: StandardMaterial3D = _mats[key]
		return cached
	var m := Toon.mat(color, outline, osz)
	_mats[key] = m
	return m


## Toon sans contour, visible des deux faces (feuilles, herbes : maillages plats).
static func _toon_ds(color: Color) -> StandardMaterial3D:
	var key := "d" + color.to_html(true)
	if _mats.has(key):
		var cached: StandardMaterial3D = _mats[key]
		return cached
	var m := Toon.mat(color, false)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m


## Toon lumineux (flammes, lanternes, veines de lave).
static func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var key := "g%s_%.2f" % [color.to_html(true), energy]
	if _mats.has(key):
		var cached: StandardMaterial3D = _mats[key]
		return cached
	var m := Toon.mat(color, false)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	_mats[key] = m
	return m


## Aplat sans lumière pour le très lointain (transparent seulement si alpha < 1).
static func _flat(color: Color) -> StandardMaterial3D:
	var key := "f" + color.to_html(true)
	if _mats.has(key):
		var cached: StandardMaterial3D = _mats[key]
		return cached
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if color.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m


## Aplat opaque à couleurs de sommets : tout le lointain « estampe » d'un monde en un draw call.
static func _vc_mat() -> StandardMaterial3D:
	if _mats.has("vc_flat"):
		var cached: StandardMaterial3D = _mats["vc_flat"]
		return cached
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats["vc_flat"] = m
	return m


## Vague d'encre : le dégradé de sommets de Decor.great_wave assombri.
static func _ink_wave_mat() -> StandardMaterial3D:
	if _mats.has("ink_wave"):
		var cached: StandardMaterial3D = _mats["ink_wave"]
		return cached
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.albedo_color = Color(0.26, 0.26, 0.32)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats["ink_wave"] = m
	return m


## Matériau de particules : couleur par particule, fondu alpha, additif pour les lueurs.
static func _pmat(billboard: bool, additive: bool) -> StandardMaterial3D:
	var key := "p%d%d" % [1 if billboard else 0, 1 if additive else 0]
	if _mats.has(key):
		var cached: StandardMaterial3D = _mats[key]
		return cached
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mats[key] = m
	return m


# ------------------------------------------------------------------ briques

static func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(s * 7919 + 4243)
	return r


static func _at(p: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot) * Basis.from_scale(scl), p)


## Maillages partagés (cache de decor.gd).
static func _ball(r: float, h: float, seg := 8, rings := 4) -> SphereMesh:
	return Decor.ball(r, h, seg, rings)


static func _box(s: Vector3) -> BoxMesh:
	return Decor.box(s)


static func _cyl(top: float, bottom: float, h: float, sides := 8) -> CylinderMesh:
	return Decor.cyl(top, bottom, h, sides)


## Base dont l'axe Y suit `d`.
static func _basis_y(d: Vector3) -> Basis:
	if d.length_squared() < 0.000001:
		return Basis()
	var y := d.normalized()
	var ref := Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.FORWARD
	var x := y.cross(ref).normalized()
	var z := x.cross(y)
	return Basis(x, y, z)


## Ajoute une primitive au lot du matériau `m` (1 draw call par matériau au final).
static func _add(b: Dictionary, m: Material, mesh: Mesh, xf: Transform3D) -> void:
	var k := m.get_instance_id()
	if not b.has(k):
		var st0 := SurfaceTool.new()
		st0.begin(Mesh.PRIMITIVE_TRIANGLES)
		b[k] = [st0, m]
	var entry: Array = b[k]
	var st: SurfaceTool = entry[0]
	Decor.merge_into(st, mesh, xf)  # copie CPU : pas de relecture GPU par pièce


static func _flush(b: Dictionary, parent: Node3D, shadow := false) -> void:
	for k in b:
		var entry: Array = b[k]
		var st: SurfaceTool = entry[0]
		var m: Material = entry[1]
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = m
		if shadow:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		else:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)


## Segment conique de a (rayon r0) vers c (rayon r1), placé par `xf`.
static func _limb(b: Dictionary, m: Material, a: Vector3, c: Vector3, r0: float, r1: float, sides := 6, xf := Transform3D.IDENTITY) -> void:
	var d := c - a
	var l := d.length()
	if l < 0.001:
		return
	_add(b, m, _cyl(r1, r0, l, sides), xf * Transform3D(_basis_y(d), (a + c) * 0.5))


## Corde qui s'affaisse entre a et c (suite de segments).
static func _rope(b: Dictionary, m: Material, a: Vector3, c: Vector3, sag: float, r := 0.02) -> void:
	var n := 6
	var prev := a
	for i in range(1, n + 1):
		var t := float(i) / n
		var q := a.lerp(c, t) + Vector3(0, -sag * 4.0 * t * (1.0 - t), 0)
		_limb(b, m, prev, q, r, r, 4)
		prev = q


## Lot d'instances (MultiMesh) : une clé = un maillage + un matériau.
static func _inst(ctx: Dictionary, key: String, mesh: Mesh, mat: Material, xf: Transform3D, shadow := false) -> void:
	var mm: Dictionary = ctx["mm"]
	if not mm.has(key):
		mm[key] = [mesh, mat, [], shadow]
	var e: Array = mm[key]
	var list: Array = e[2]
	list.append(xf)


static func _flush_mm(mm: Dictionary, parent: Node3D) -> void:
	for k in mm:
		var e: Array = mm[k]
		var list: Array = e[2]
		if list.is_empty():
			continue
		var mesh: Mesh = e[0]
		var mat: Material = e[1]
		var shadow: bool = e[3]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		multi.instance_count = list.size()
		for i in list.size():
			var t: Transform3D = list[i]
			multi.set_instance_transform(i, t)
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = multi
		mi.material_override = mat
		if shadow:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		else:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)


## Hauteur de la surface d'une berge en dôme (centre cx, cz ; rayon r ; aplatie à 0.15 r).
static func _dome_y(cx: float, cz: float, r: float, x: float, z: float) -> float:
	var d := Vector2(x - cx, z - cz).length() / r
	return VOID_Y + 0.15 * r * sqrt(maxf(1.0 - d * d, 0.0))


# ------------------------------------------------------------------ maillages faits main (cache)

## Croissant d'écume plat (deux traits concentriques), centré sur l'origine, tourné vers +Z.
static func _crescent_mesh() -> ArrayMesh:
	if _meshes.has("crescent"):
		var cached: ArrayMesh = _meshes["crescent"]
		return cached
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for arc in 2:
		var rad := 0.5 - arc * 0.13
		var span := 1.0 - arc * 0.35
		var wmax := 0.09 - arc * 0.03
		var n := 10
		for i in n:
			var a0 := lerpf(-span, span, float(i) / n)
			var a1 := lerpf(-span, span, float(i + 1) / n)
			var w0 := wmax * sin(PI * float(i) / n) + 0.004
			var w1 := wmax * sin(PI * float(i + 1) / n) + 0.004
			var o0 := Vector3(sin(a0), 0, cos(a0))
			var o1 := Vector3(sin(a1), 0, cos(a1))
			st.add_vertex(o0 * (rad - w0 * 0.5))
			st.add_vertex(o1 * (rad - w1 * 0.5))
			st.add_vertex(o1 * (rad + w1 * 0.5))
			st.add_vertex(o0 * (rad - w0 * 0.5))
			st.add_vertex(o1 * (rad + w1 * 0.5))
			st.add_vertex(o0 * (rad + w0 * 0.5))
	var mesh := st.commit()
	_meshes["crescent"] = mesh
	return mesh


## Panache de feuilles de bambou retombantes (sommet des tiges).
static func _spray_mesh() -> ArrayMesh:
	if _meshes.has("spray"):
		var cached: ArrayMesh = _meshes["spray"]
		return cached
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for k in 9:
		var yaw := TAU * k / 9.0 + (0.3 if k % 2 == 0 else 0.0)
		var dir := Vector3(cos(yaw), 0, sin(yaw))
		var side := Vector3(-dir.z, 0, dir.x)
		var ln := 0.5 + 0.14 * float(k % 3)
		var droop := -0.22 - 0.1 * float(k % 2)
		var base := dir * 0.04
		var mid := dir * ln * 0.5 + Vector3(0, droop * 0.3, 0)
		var tip := dir * ln + Vector3(0, droop, 0)
		var wdt := 0.065
		st.add_vertex(base)
		st.add_vertex(mid + side * wdt)
		st.add_vertex(mid - side * wdt)
		st.add_vertex(mid - side * wdt)
		st.add_vertex(mid + side * wdt)
		st.add_vertex(tip)
	var mesh := st.commit()
	_meshes["spray"] = mesh
	return mesh


## Touffe d'herbes / roseaux (lames fines en éventail), hauteur ~0.5.
static func _tuft_mesh() -> ArrayMesh:
	if _meshes.has("tuft"):
		var cached: ArrayMesh = _meshes["tuft"]
		return cached
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for k in 7:
		var yaw := TAU * k / 7.0
		var dir := Vector3(cos(yaw), 0, sin(yaw))
		var side := Vector3(-dir.z, 0, dir.x)
		var h := 0.32 + 0.1 * float(k % 3)
		var tip := dir * (0.14 + 0.05 * float(k % 2)) + Vector3(0, h, 0)
		st.add_vertex(-side * 0.025)
		st.add_vertex(side * 0.025)
		st.add_vertex(tip)
	var mesh := st.commit()
	_meshes["tuft"] = mesh
	return mesh


# ------------------------------------------------------------------ lointain « estampe » (couleurs de sommets)

static func _vc_begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _vc_end(st: SurfaceTool, root: Node3D) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Estampe"
	mi.mesh = st.commit()
	mi.material_override = _vc_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


static func _vv(st: SurfaceTool, col: Color, p: Vector3) -> void:
	st.set_color(col)
	st.add_vertex(p)


static func _vtri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	_vv(st, ca, a)
	_vv(st, cb, b)
	_vv(st, cc, c)


## Quadrilatère a-b-c-d (dans l'ordre du contour), une couleur par sommet.
static func _vquad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	_vtri(st, a, b, c, ca, cb, cc)
	_vtri(st, a, c, d, ca, cc, cd)


## Rectangle vertical face à +Z, de `lo` (bas-gauche) à `hi` (haut-droit), dégradé vertical.
static func _vrect(st: SurfaceTool, lo: Vector3, hi: Vector3, c_lo: Color, c_hi: Color) -> void:
	_vquad(st, Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(lo.x, hi.y, lo.z), c_lo, c_lo, c_hi, c_hi)


## Trait d'encre plat de a à b (largeur w) dans le plan XY.
static func _vstroke(st: SurfaceTool, a: Vector3, b: Vector3, w: float, col: Color) -> void:
	var d := b - a
	var n := Vector3(-d.y, d.x, 0).normalized() * w * 0.5
	_vquad(st, a - n, b - n, b + n, a + n, col, col, col, col)


## Chaîne de montagnes en aplat (rideau face à +Z) : crête irrégulière, dégradé bokashi
## de `top_c` (crête) vers `low_c` (pied fondu dans la brume).
static func _ridge(st: SurfaceTool, rng: RandomNumberGenerator, x0: float, x1: float, z: float, base_y: float, h: float, top_c: Color, low_c: Color, steps := 28) -> void:
	var ph1 := rng.randf() * TAU
	var ph2 := rng.randf() * TAU
	var f1 := rng.randf_range(5.0, 8.0)
	var f2 := rng.randf_range(13.0, 19.0)
	var ys := PackedFloat32Array()
	for i in steps + 1:
		var t := float(i) / steps
		var y := h * (0.6 + 0.28 * sin(t * f1 + ph1) + 0.14 * sin(t * f2 + ph2)) + h * rng.randf_range(-0.06, 0.06)
		ys.append(maxf(y, h * 0.12))
	for i in steps:
		var xa := lerpf(x0, x1, float(i) / steps)
		var xb := lerpf(x0, x1, float(i + 1) / steps)
		var ya := ys[i]
		var yb := ys[i + 1]
		var ca := low_c.lerp(top_c, clampf(ya / h, 0.0, 1.0))
		var cb := low_c.lerp(top_c, clampf(yb / h, 0.0, 1.0))
		_vquad(st, Vector3(xa, base_y, z), Vector3(xb, base_y, z), Vector3(xb, base_y + yb, z), Vector3(xa, base_y + ya, z), low_c, low_c, cb, ca)


## Bande de brume (kasumi) aux bouts arrondis, dégradée de haut en bas.
static func _band(st: SurfaceTool, c: Vector3, w: float, hgt: float, top_c: Color, low_c: Color) -> void:
	var r := hgt * 0.5
	var ww := maxf(w, hgt * 2.2)
	var pts := PackedVector3Array()
	for k in 7:
		var a := -PI * 0.5 + PI * k / 6.0
		pts.append(c + Vector3(ww * 0.5 - r + cos(a) * r, sin(a) * r, 0))
	for k in 7:
		var a := PI * 0.5 + PI * k / 6.0
		pts.append(c + Vector3(-ww * 0.5 + r + cos(a) * r, sin(a) * r, 0))
	var cm := low_c.lerp(top_c, 0.5)
	var n := pts.size()
	for i in n:
		var p0 := pts[i]
		var p1 := pts[(i + 1) % n]
		var c0 := low_c.lerp(top_c, clampf((p0.y - c.y + r) / hgt, 0.0, 1.0))
		var c1 := low_c.lerp(top_c, clampf((p1.y - c.y + r) / hgt, 0.0, 1.0))
		_vtri(st, c, p0, p1, cm, c0, c1)


## Oiseau en « M » vu de loin.
static func _bird(st: SurfaceTool, p: Vector3, s: float, col: Color) -> void:
	for sx: float in [-1.0, 1.0]:
		var e := p + Vector3(sx * s * 0.45, s * 0.22, 0)
		var t := p + Vector3(sx * s, s * 0.04, 0)
		_vtri(st, p + Vector3(0, s * 0.07, 0), e, p + Vector3(0, -s * 0.07, 0), col, col, col)
		_vtri(st, e, t, e + Vector3(0, -s * 0.11, 0), col, col, col)


static func _flock(st: SurfaceTool, rng: RandomNumberGenerator, c: Vector3, n: int, spread: Vector3, s: float, col: Color) -> void:
	for i in n:
		var p := c + Vector3(rng.randf_range(-spread.x, spread.x), rng.randf_range(-spread.y, spread.y), rng.randf_range(-spread.z, spread.z))
		_bird(st, p, s * rng.randf_range(0.7, 1.2), col)


## Pagode en silhouette : étages, toits aux coins relevés, flèche ; fenêtres si `win.a > 0`.
static func _sil_pagoda(st: SurfaceTool, base: Vector3, s: float, tiers: int, col: Color, roof_c: Color, win: Color) -> void:
	var y := base.y
	var w := s
	var z := base.z
	var none := Color(0, 0, 0, 0)
	for k in tiers:
		var bh := 0.5 * s
		_vrect(st, Vector3(base.x - w * 0.32, y, z), Vector3(base.x + w * 0.32, y + bh, z), col, col)
		if win.a > 0.0:
			_vrect(st, Vector3(base.x - w * 0.08, y + bh * 0.25, z + 0.15), Vector3(base.x + w * 0.08, y + bh * 0.75, z + 0.15), win, win)
		y += bh
		# toit incurvé aux coins relevés (sori)
		_sil_roof(st, base.x, y - 0.04 * s, z + 0.25, w * 0.84, 0.24 * s, 0.13 * s, 0.07 * s, roof_c, none, 0.16, none)
		y += 0.2 * s
		w *= 0.86
	# sōrin : mât, neuf anneaux (kurin), flamme (suien) et perle
	_vstroke(st, Vector3(base.x, y, z), Vector3(base.x, y + 1.1 * s, z), 0.06 * s, roof_c)
	for k in 9:
		var ry := y + 0.12 * s + k * 0.085 * s
		_vrect(st, Vector3(base.x - 0.1 * s, ry, z + 0.05), Vector3(base.x + 0.1 * s, ry + 0.035 * s, z + 0.05), roof_c, roof_c)
	_vdisc(st, Vector3(base.x, y + 1.18 * s, z + 0.05), 0.07 * s, roof_c, roof_c, 8)


## Bateau à voile carrée (bezaisen) en silhouette ; `facing` = ±1 (côté de la proue).
static func _sil_boat(st: SurfaceTool, p: Vector3, s: float, hull: Color, sail: Color, facing: float) -> void:
	var f := facing
	_vquad(st, p + Vector3(-1.0 * s * f, 0, 0), p + Vector3(1.0 * s * f, 0, 0), p + Vector3(1.45 * s * f, 0.42 * s, 0), p + Vector3(-1.15 * s * f, 0.32 * s, 0), hull, hull, hull, hull)
	_vstroke(st, p + Vector3(0, 0.3 * s, 0.1), p + Vector3(0, 2.7 * s, 0.1), 0.07 * s, hull)
	var sd := sail.darkened(0.08)
	_vquad(st, p + Vector3(-0.75 * s, 0.75 * s, 0.2), p + Vector3(0.75 * s, 0.75 * s, 0.2), p + Vector3(0.7 * s, 2.5 * s, 0.2), p + Vector3(-0.7 * s, 2.5 * s, 0.2), sd, sd, sail, sail)
	for k in 3:
		var x := (-0.37 + k * 0.37) * s
		_vstroke(st, p + Vector3(x, 0.78 * s, 0.3), p + Vector3(x, 2.47 * s, 0.3), 0.035 * s, sail.darkened(0.25))


## Temple en silhouette : grand toit en croupe aux coins relevés, ligne de neige si `snow.a > 0`.
static func _sil_temple(st: SurfaceTool, p: Vector3, s: float, wall: Color, roof: Color, snow: Color) -> void:
	_vrect(st, p + Vector3(-1.2 * s, 0, 0), p + Vector3(1.2 * s, 0.8 * s, 0), wall, wall)
	# piliers sombres de la façade
	for k in 5:
		var x := p.x + (float(k) - 2.0) * 0.55 * s
		_vrect(st, Vector3(x - 0.05 * s, p.y, p.z + 0.1), Vector3(x + 0.05 * s, p.y + 0.78 * s, p.z + 0.1), roof, roof)
	# grand toit en croupe (irimoya) : pans incurvés, égout relevé, tuiles de faîte
	_sil_roof(st, p.x, p.y + 0.74 * s, p.z + 0.2, 2.05 * s, 0.82 * s, 0.24 * s, 0.1 * s, roof, snow, 0.42, roof)


## Lisière de conifères (triangles), chapeaux de neige si `cap.a > 0`.
static func _sil_trees(st: SurfaceTool, rng: RandomNumberGenerator, x0: float, x1: float, z: float, y0: float, n: int, h: float, col: Color, cap: Color) -> void:
	for i in n:
		var hh := h * rng.randf_range(0.6, 1.3)
		var w := hh * 0.32
		var b := Vector3(rng.randf_range(x0, x1), y0 + rng.randf_range(-0.3, 0.6), z + rng.randf_range(-1.0, 1.0))
		_vtri(st, b + Vector3(-w, 0, 0), b + Vector3(w, 0, 0), b + Vector3(0, hh, 0), col, col, col)
		_vtri(st, b + Vector3(-w * 0.8, hh * 0.4, 0.05), b + Vector3(w * 0.8, hh * 0.4, 0.05), b + Vector3(0, hh * 1.1, 0.05), col, col, col)
		if cap.a > 0.0:
			_vtri(st, b + Vector3(-w * 0.42, hh * 0.72, 0.1), b + Vector3(w * 0.42, hh * 0.72, 0.1), b + Vector3(0, hh * 1.1, 0.1), cap, cap, cap)


## Pont en arc en silhouette (tablier, garde-corps, poteaux), piles sur les côtés ; neige si `snow.a > 0`.
static func _sil_bridge(st: SurfaceTool, c: Vector3, span: float, rise: float, thick: float, col: Color, snow: Color, piles: int) -> void:
	var n := 18
	var half := span * 0.5
	for i in n:
		var x0 := lerpf(-half, half, float(i) / n)
		var x1 := lerpf(-half, half, float(i + 1) / n)
		var y0 := rise * (1.0 - pow(x0 / half, 2.0))
		var y1 := rise * (1.0 - pow(x1 / half, 2.0))
		_vquad(st, c + Vector3(x0, y0 - thick, 0), c + Vector3(x1, y1 - thick, 0), c + Vector3(x1, y1, 0), c + Vector3(x0, y0, 0), col, col, col, col)
		_vquad(st, c + Vector3(x0, y0 + thick * 0.75, 0.1), c + Vector3(x1, y1 + thick * 0.75, 0.1), c + Vector3(x1, y1 + thick * 0.95, 0.1), c + Vector3(x0, y0 + thick * 0.95, 0.1), col, col, col, col)
		_vstroke(st, c + Vector3(x0, y0, 0.1), c + Vector3(x0, y0 + thick * 0.95, 0.1), thick * 0.1, col)
		if snow.a > 0.0:
			_vquad(st, c + Vector3(x0, y0 - 0.02, 0.2), c + Vector3(x1, y1 - 0.02, 0.2), c + Vector3(x1, y1 + thick * 0.22, 0.2), c + Vector3(x0, y0 + thick * 0.22, 0.2), snow, snow, snow, snow)
	var per_side := maxi(int(ceil(float(piles) * 0.5)), 1)
	for k in piles:
		var sx: float = -1.0 if k % 2 == 0 else 1.0
		var j := floorf(float(k) * 0.5)
		var x := sx * half * (0.45 + 0.4 * j / maxf(float(per_side - 1), 1.0))
		var y := rise * (1.0 - pow(x / half, 2.0)) - thick
		_vrect(st, c + Vector3(x - thick * 0.18, -2.0, 0.05), c + Vector3(x + thick * 0.18, y, 0.05), col, col)


## Ensō : cercle zen tracé d'un seul geste (s'amincit, ouverture en fin de trait).
static func _enso(st: SurfaceTool, c: Vector3, r: float, thick: float, col: Color) -> void:
	var n := 40
	var a0 := 0.6
	var span := TAU * 0.9
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var w0 := thick * (1.0 - 0.75 * t0) * (0.85 + 0.15 * sin(t0 * 31.0))
		var w1 := thick * (1.0 - 0.75 * t1) * (0.85 + 0.15 * sin(t1 * 31.0))
		var d0 := Vector3(cos(a0 + span * t0), sin(a0 + span * t0), 0)
		var d1 := Vector3(cos(a0 + span * t1), sin(a0 + span * t1), 0)
		_vquad(st, c + d0 * (r - w0 * 0.5), c + d1 * (r - w1 * 0.5), c + d1 * (r + w1 * 0.5), c + d0 * (r + w0 * 0.5), col, col, col, col)


## Fudō Myōō en silhouette : rocher, corps assis, tête, épée, halo de flammes (karura-en).
static func _fudo(st: SurfaceTool, p: Vector3, s: float, body: Color, fin: Color, fout: Color) -> void:
	var hc := p + Vector3(0, 6.2 * s, -0.5)
	var n := 20
	for k in n:
		var a0 := TAU * k / n
		var a1 := TAU * (k + 1) / n
		_vtri(st, hc, hc + Vector3(cos(a0), sin(a0), 0) * 3.0 * s, hc + Vector3(cos(a1), sin(a1), 0) * 3.0 * s, fout, fin, fin)
	for k in 15:
		var a := deg_to_rad(-30.0 + 240.0 * k / 14.0)
		var tip_r := (4.3 + 0.9 * sin(k * 1.7)) * s
		_vtri(st, hc + Vector3(cos(a - 0.13), sin(a - 0.13), 0) * 2.7 * s, hc + Vector3(cos(a + 0.13), sin(a + 0.13), 0) * 2.7 * s,
			hc + Vector3(cos(a + 0.18), sin(a + 0.18), 0) * tip_r, fin, fin, fout)
	var z := p.z + 0.3
	_vquad(st, Vector3(p.x - 2.8 * s, p.y, z), Vector3(p.x + 2.8 * s, p.y, z), Vector3(p.x + 2.1 * s, p.y + 1.5 * s, z), Vector3(p.x - 2.1 * s, p.y + 1.5 * s, z), body, body, body, body)
	_vquad(st, Vector3(p.x - 1.7 * s, p.y + 1.5 * s, z), Vector3(p.x + 1.7 * s, p.y + 1.5 * s, z), Vector3(p.x + 1.0 * s, p.y + 4.9 * s, z), Vector3(p.x - 1.0 * s, p.y + 4.9 * s, z), body, body, body, body)
	var head := Vector3(p.x, p.y + 5.6 * s, z)
	for k in 8:
		var a0 := TAU * k / 8.0
		var a1 := TAU * (k + 1) / 8.0
		_vtri(st, head, head + Vector3(cos(a0), sin(a0), 0) * 0.8 * s, head + Vector3(cos(a1), sin(a1), 0) * 0.8 * s, body, body, body)
	_vstroke(st, Vector3(p.x + 1.4 * s, p.y + 2.2 * s, z + 0.1), Vector3(p.x + 1.9 * s, p.y + 7.0 * s, z + 0.1), 0.22 * s, Color("#B8B2A6"))


## Personnage croqué du Hokusai Manga (traits d'encre), en pleine course si `pose` = ±1.
static func _sketch_man(st: SurfaceTool, p: Vector3, s: float, col: Color, pose: float) -> void:
	var hip := p + Vector3(0, 0.9 * s, 0)
	var neck := hip + Vector3(0.12 * s * pose, 0.6 * s, 0)
	_vstroke(st, hip, neck, 0.08 * s, col)
	var hc := neck + Vector3(0.05 * s * pose, 0.2 * s, 0)
	for k in 6:
		var a0 := TAU * k / 6.0
		var a1 := TAU * (k + 1) / 6.0
		_vtri(st, hc, hc + Vector3(cos(a0), sin(a0), 0) * 0.13 * s, hc + Vector3(cos(a1), sin(a1), 0) * 0.13 * s, col, col, col)
	_vstroke(st, hip, p + Vector3(0.32 * s * pose, 0, 0), 0.06 * s, col)
	_vstroke(st, hip, hip + Vector3(-0.2 * s * pose, -0.45 * s, 0), 0.06 * s, col)
	_vstroke(st, hip + Vector3(-0.2 * s * pose, -0.45 * s, 0), p + Vector3(-0.42 * s * pose, 0.08 * s, 0), 0.05 * s, col)
	var sh := neck - Vector3(0, 0.08 * s, 0)
	_vstroke(st, sh, sh + Vector3(0.38 * s * pose, -0.22 * s, 0), 0.05 * s, col)
	_vstroke(st, sh, sh + Vector3(-0.3 * s * pose, -0.3 * s, 0), 0.05 * s, col)


# --- estampe : formes partagées par les huit lointains (une seule logique de palette :
# indigo / bleu de Prusse, vermillon, ocre, crème du washi, encre sumi), toutes dans le maillage « Estampe »

## Disque face à +Z (soleil, lune, perle, halo) : `c_in` au centre, `c_out` au bord.
static func _vdisc(st: SurfaceTool, c: Vector3, r: float, c_in: Color, c_out: Color, seg := 28) -> void:
	for k in seg:
		var a0 := TAU * k / seg
		var a1 := TAU * (k + 1) / seg
		_vtri(st, c, c + Vector3(cos(a0), sin(a0), 0) * r, c + Vector3(cos(a1), sin(a1), 0) * r, c_in, c_out, c_out)


## Ellipse face à +Z (nuage en écaille, coussin d'aiguilles, rocher lointain), dégradée du haut vers le bas.
static func _vellipse(st: SurfaceTool, c: Vector3, rx: float, ry: float, top_c: Color, low_c: Color, seg := 14) -> void:
	var cm := low_c.lerp(top_c, 0.5)
	for k in seg:
		var a0 := TAU * k / seg
		var a1 := TAU * (k + 1) / seg
		var p0 := c + Vector3(cos(a0) * rx, sin(a0) * ry, 0)
		var p1 := c + Vector3(cos(a1) * rx, sin(a1) * ry, 0)
		_vtri(st, c, p0, p1, cm, low_c.lerp(top_c, (sin(a0) + 1.0) * 0.5), low_c.lerp(top_c, (sin(a1) + 1.0) * 0.5))


## Couleur d'un ciel en bokashi à deux dégradés (y0 → y1 → y2), pour fondre en aplat opaque
## ce qui était un voile transparent (halo, Voie lactée, nuages) : plus de tri alpha ni de draw call.
static func _sky_at(y: float, sky: Array) -> Color:
	var y0: float = sky[0]
	var y1: float = sky[2]
	var y2: float = sky[4]
	var c0: Color = sky[1]
	var c1: Color = sky[3]
	var c2: Color = sky[5]
	if y < y1:
		return c0.lerp(c1, clampf((y - y0) / maxf(y1 - y0, 0.001), 0.0, 1.0))
	return c1.lerp(c2, clampf((y - y1) / maxf(y2 - y1, 0.001), 0.0, 1.0))


## Voile incliné (rayon de lumière, Voie lactée) peint en aplat : couleur du ciel derrière, mêlée
## de `tint` à `a`, sommet par sommet. Centre `c`, largeur `w`, hauteur `h`, angle `ang` (autour de Z).
static func _veil_band(st: SurfaceTool, c: Vector3, w: float, h: float, ang: float, tint: Color, a: float, sky: Array, nseg := 8) -> void:
	var ax := Vector3(cos(ang), sin(ang), 0)
	var ay := Vector3(-sin(ang), cos(ang), 0)
	for i in nseg:
		var ua := lerpf(-0.5, 0.5, float(i) / nseg) * w
		var ub := lerpf(-0.5, 0.5, float(i + 1) / nseg) * w
		var pts: Array[Vector3] = [c + ax * ua - ay * h * 0.5, c + ax * ub - ay * h * 0.5, c + ax * ub + ay * h * 0.5, c + ax * ua + ay * h * 0.5]
		var cols: Array[Color] = []
		for q in pts:
			cols.append(_sky_at(q.y, sky).lerp(tint, a))
		_vquad(st, pts[0], pts[1], pts[2], pts[3], cols[0], cols[1], cols[2], cols[3])


## Hauteur du profil d'un mont à la distance `ax` de l'axe : plateau sommital, flancs concaves.
static func _mount_y(ax: float, hw: float, tw: float, h: float, p: float) -> float:
	if ax <= tw:
		return h
	return h * pow(maxf(1.0 - (ax - tw) / maxf(hw - tw, 0.001), 0.0), p)


## Mont en aplat face à +Z (Fuji, pics) : demi-base `hw`, flancs concaves (exposant `p` > 1), sommet
## tronqué (`top_w` × hw), bokashi de `low_c` (pied) à `top_c` (cime) ; calotte `cap` (neige, cendre)
## sur `cap_frac` de la hauteur, bord inférieur en dents de coulées (alpha 0 : sans calotte).
static func _sil_mount(st: SurfaceTool, base: Vector3, hw: float, h: float, p: float, top_w: float, top_c: Color, low_c: Color, cap: Color, cap_frac: float, n := 24) -> void:
	var tw := hw * top_w
	for i in n:
		var xa := lerpf(-hw, hw, float(i) / n)
		var xb := lerpf(-hw, hw, float(i + 1) / n)
		var ya := _mount_y(absf(xa), hw, tw, h, p)
		var yb := _mount_y(absf(xb), hw, tw, h, p)
		_vquad(st, Vector3(base.x + xa, base.y, base.z), Vector3(base.x + xb, base.y, base.z), Vector3(base.x + xb, base.y + yb, base.z),
			Vector3(base.x + xa, base.y + ya, base.z), low_c, low_c, low_c.lerp(top_c, yb / h), low_c.lerp(top_c, ya / h))
	if cap.a <= 0.0 or cap_frac <= 0.0:
		return
	var ys := h * (1.0 - cap_frac)
	var jd := h * cap_frac * 0.55
	var xc := tw + (hw - tw) * (1.0 - pow(clampf((ys - jd) / h, 0.0, 1.0), 1.0 / p))
	var m := 18
	var z := base.z + 0.3
	var cap_lo := cap.darkened(0.08)
	for i in m:
		var xa := lerpf(-xc, xc, float(i) / m)
		var xb := lerpf(-xc, xc, float(i + 1) / m)
		var ta := _mount_y(absf(xa), hw, tw, h, p)
		var tb := _mount_y(absf(xb), hw, tw, h, p)
		var ba := minf(_cap_edge(i, ys, jd), ta)
		var bb := minf(_cap_edge(i + 1, ys, jd), tb)
		if ta - ba < 0.01 and tb - bb < 0.01:
			continue
		_vquad(st, Vector3(base.x + xa, base.y + ba, z), Vector3(base.x + xb, base.y + bb, z), Vector3(base.x + xb, base.y + tb, z),
			Vector3(base.x + xa, base.y + ta, z), cap_lo, cap_lo, cap, cap)


## Bord inférieur de la calotte : une dent sur deux descend (coulées de neige du Fuji).
static func _cap_edge(i: int, ys: float, jd: float) -> float:
	if i % 2 == 1:
		return ys - jd * (0.55 + 0.45 * sin(float(i) * 2.3))
	return ys + jd * 0.12


## Dessus d'un toit en aplat à l'abscisse relative t ∈ [-1, 1] : faîtage plat sur |t| < rr, pans concaves.
static func _roof_top(t: float, rr: float, rise: float, lift: float) -> float:
	var a := absf(t)
	if a <= rr:
		return rise
	var u := (a - rr) / maxf(1.0 - rr, 0.001)
	return rise * pow(1.0 - u, 1.8) + lift * pow(u, 6.0)


## Toit incurvé en aplat (face à +Z) posé sur un mur dont le haut est en (cx, y) : demi-largeur `hw`,
## faîtage de demi-longueur `rr` × hw, hauteur `rise`, égout relevé aux coins (`lift`), épaisseur `th` ;
## liseré de neige si `snow.a > 0`, ornements de faîte (onigawara, shachihoko) si `orn.a > 0`.
static func _sil_roof(st: SurfaceTool, cx: float, y: float, z: float, hw: float, rise: float, lift: float, th: float, col: Color, snow: Color, rr: float, orn: Color) -> void:
	var n := 16
	var cd := col.darkened(0.18)
	for i in n:
		var ta := lerpf(-1.0, 1.0, float(i) / n)
		var tb := lerpf(-1.0, 1.0, float(i + 1) / n)
		var ya := _roof_top(ta, rr, rise, lift)
		var yb := _roof_top(tb, rr, rise, lift)
		var ua := maxf(absf(ta) - rr, 0.0) / maxf(1.0 - rr, 0.001)
		var ub := maxf(absf(tb) - rr, 0.0) / maxf(1.0 - rr, 0.001)
		var la := minf(-th + lift * pow(ua, 6.0), ya - th * 0.6)
		var lb := minf(-th + lift * pow(ub, 6.0), yb - th * 0.6)
		_vquad(st, Vector3(cx + ta * hw, y + la, z), Vector3(cx + tb * hw, y + lb, z), Vector3(cx + tb * hw, y + yb, z), Vector3(cx + ta * hw, y + ya, z), cd, cd, col, col)
		if snow.a > 0.0:
			_vquad(st, Vector3(cx + ta * hw, y + ya - th * 0.7, z + 0.08), Vector3(cx + tb * hw, y + yb - th * 0.7, z + 0.08),
				Vector3(cx + tb * hw, y + yb + th * 0.3, z + 0.08), Vector3(cx + ta * hw, y + ya + th * 0.3, z + 0.08), snow, snow, snow, snow)
	if orn.a <= 0.0 or rr <= 0.02:
		return
	# ornements aux bouts du faîtage : queue de poisson relevée vers l'extérieur
	for sx: float in [-1.0, 1.0]:
		var ex := cx + sx * rr * hw
		var ey := y + rise
		_vtri(st, Vector3(ex - sx * th * 0.8, ey, z + 0.1), Vector3(ex + sx * th * 0.6, ey, z + 0.1), Vector3(ex + sx * th * 0.9, ey + th * 2.4, z + 0.1), orn, orn, orn)
		_vtri(st, Vector3(ex - sx * th * 0.8, ey, z + 0.1), Vector3(ex + sx * th * 0.9, ey + th * 2.4, z + 0.1), Vector3(ex - sx * th * 0.2, ey + th * 1.6, z + 0.1), orn, orn, orn)


## Donjon (tenshukaku) en aplat, pied en `b` : base de pierre ishigaki aux flancs incurvés, quatre
## étages blancs à fenêtres, toits incurvés aux coins relevés, pignon chidori-hafu, shachihoko au faîte.
static func _sil_castle(st: SurfaceTool, b: Vector3, s: float, wall: Color, roof: Color, stone: Color, win: Color, gold: Color, snow: Color) -> void:
	var z := b.z
	var bw := 3.6 * s
	var tw := 2.6 * s
	var bh := 1.3 * s
	var n := 8
	for i in n:
		var ya := bh * float(i) / n
		var yb := bh * float(i + 1) / n
		var wa := tw + (bw - tw) * pow(1.0 - float(i) / n, 2.0)
		var wb := tw + (bw - tw) * pow(1.0 - float(i + 1) / n, 2.0)
		var ca := stone.darkened(0.22).lerp(stone, float(i) / n)
		var cb := stone.darkened(0.22).lerp(stone, float(i + 1) / n)
		_vquad(st, Vector3(b.x - wa * 0.5, b.y + ya, z), Vector3(b.x + wa * 0.5, b.y + ya, z), Vector3(b.x + wb * 0.5, b.y + yb, z),
			Vector3(b.x - wb * 0.5, b.y + yb, z), ca, ca, cb, cb)
	var widths := PackedFloat32Array([2.3, 1.85, 1.4, 1.0])
	var heights := PackedFloat32Array([0.8, 0.7, 0.62, 0.58])
	var none := Color(0, 0, 0, 0)
	var y := b.y + bh
	for k in 4:
		var w := widths[k] * s
		var h := heights[k] * s
		_vrect(st, Vector3(b.x - w * 0.5, y, z + 0.1), Vector3(b.x + w * 0.5, y + h, z + 0.1), wall.darkened(0.1), wall)
		var nw := 5 - k
		for j in nw:
			var wx := b.x + (float(j) - (nw - 1) * 0.5) * (w / (float(nw) + 0.6))
			_vrect(st, Vector3(wx - 0.08 * s, y + h * 0.38, z + 0.2), Vector3(wx + 0.08 * s, y + h * 0.64, z + 0.2), win, win)
		y += h
		var top := k == 3
		var rise: float = 0.46 * s if top else 0.3 * s
		var rr: float = 0.42 if top else 0.62
		_sil_roof(st, b.x, y, z + 0.3, w * 0.5 + 0.36 * s, rise, 0.15 * s, 0.08 * s, roof, snow, rr, gold if top else none)
		if k == 1:
			# chidori-hafu : pignon triangulaire au milieu du pan
			_vtri(st, Vector3(b.x - 0.46 * s, y + 0.02 * s, z + 0.4), Vector3(b.x + 0.46 * s, y + 0.02 * s, z + 0.4), Vector3(b.x, y + 0.48 * s, z + 0.4), roof, roof, roof)
			_vtri(st, Vector3(b.x - 0.3 * s, y + 0.06 * s, z + 0.45), Vector3(b.x + 0.3 * s, y + 0.06 * s, z + 0.45), Vector3(b.x, y + 0.36 * s, z + 0.45), wall, wall, wall)
		y += 0.08 * s


## Rangée de toits de ville (machiya, kura) en aplat de x0 à x1, faîtes où courent les ninjas ;
## un ninja bondit au-dessus d'un des toits si `ninja.a > 0`.
static func _sil_roofline(st: SurfaceTool, rng: RandomNumberGenerator, x0: float, x1: float, z: float, y0: float, s: float, wall: Color, roof: Color, snow: Color, ninja: Color) -> void:
	var x := x0
	var k := 0
	var jumper := rng.randi_range(1, 3)
	var none := Color(0, 0, 0, 0)
	while x < x1:
		var w := rng.randf_range(2.2, 3.6) * s
		var h := rng.randf_range(0.8, 1.5) * s
		var cx := x + w * 0.5
		var zz := z + (0.3 if k % 2 == 0 else 0.0)
		_vrect(st, Vector3(x, y0, zz), Vector3(x + w, y0 + h, zz), wall.darkened(0.12), wall)
		var rise := rng.randf_range(0.35, 0.55) * s
		_sil_roof(st, cx, y0 + h, zz + 0.12, w * 0.56, rise, 0.12 * s, 0.08 * s, roof, snow, rng.randf_range(0.3, 0.55), roof)
		if ninja.a > 0.0 and k == jumper:
			_sil_ninja(st, Vector3(cx + w * 0.45, y0 + h + rise + 0.75 * s, zz + 0.6), s * 0.6, ninja, 1.0 if rng.randf() < 0.5 else -1.0)
		x += w * rng.randf_range(0.82, 1.0)
		k += 1


## Ninja en silhouette qui bondit d'un toit à l'autre (`f` = ±1 : sens du saut) : buste penché, tête,
## bandeau qui flotte, sabre dans le dos, jambe avant repliée.
static func _sil_ninja(st: SurfaceTool, p: Vector3, s: float, col: Color, f: float) -> void:
	var sh := p + Vector3(0.28 * s * f, 0.42 * s, 0)
	_vstroke(st, p, sh, 0.2 * s, col)
	var hc := sh + Vector3(0.1 * s * f, 0.17 * s, 0)
	_vdisc(st, hc, 0.11 * s, col, col, 8)
	_vstroke(st, hc + Vector3(-0.08 * s * f, 0.02 * s, 0), hc + Vector3(-0.44 * s * f, 0.12 * s, 0), 0.035 * s, col)
	_vstroke(st, hc + Vector3(-0.08 * s * f, 0.0, 0), hc + Vector3(-0.38 * s * f, -0.05 * s, 0), 0.03 * s, col)
	_vstroke(st, p + Vector3(-0.16 * s * f, -0.06 * s, 0), sh + Vector3(-0.06 * s * f, 0.34 * s, 0), 0.04 * s, col)
	_vstroke(st, sh, sh + Vector3(0.38 * s * f, -0.05 * s, 0), 0.06 * s, col)
	_vstroke(st, sh, sh + Vector3(-0.3 * s * f, -0.22 * s, 0), 0.06 * s, col)
	var knee := p + Vector3(0.3 * s * f, -0.12 * s, 0)
	_vstroke(st, p, knee, 0.09 * s, col)
	_vstroke(st, knee, knee + Vector3(-0.05 * s * f, -0.28 * s, 0), 0.07 * s, col)
	_vstroke(st, p, p + Vector3(-0.42 * s * f, -0.22 * s, 0), 0.08 * s, col)


## Torii en aplat face à +Z, pieds en `p` (hauteur ≈ 3.5 s) : piliers, nuki, gakuzuka, kasagi relevé.
static func _sil_torii(st: SurfaceTool, p: Vector3, s: float, col: Color) -> void:
	for sx: float in [-1.0, 1.0]:
		_vstroke(st, p + Vector3(sx * 1.1 * s, 0, 0), p + Vector3(sx * 1.0 * s, 3.05 * s, 0), 0.22 * s, col)
	_vrect(st, p + Vector3(-1.45 * s, 2.32 * s, 0.05), p + Vector3(1.45 * s, 2.48 * s, 0.05), col, col)
	_vrect(st, p + Vector3(-0.08 * s, 2.48 * s, 0.05), p + Vector3(0.08 * s, 2.95 * s, 0.05), col, col)
	var n := 8
	for i in n:
		var ta := lerpf(-1.0, 1.0, float(i) / n)
		var tb := lerpf(-1.0, 1.0, float(i + 1) / n)
		var ya := 2.95 * s + 0.32 * s * pow(absf(ta), 2.5)
		var yb := 2.95 * s + 0.32 * s * pow(absf(tb), 2.5)
		_vquad(st, p + Vector3(ta * 1.8 * s, ya, 0.1), p + Vector3(tb * 1.8 * s, yb, 0.1), p + Vector3(tb * 1.8 * s, yb + 0.26 * s, 0.1),
			p + Vector3(ta * 1.8 * s, ya + 0.26 * s, 0.1), col, col, col, col)


## Lanterne de pierre (tōrō) en aplat, pied en `p` (hauteur ≈ 1.6 s) : fenêtre de la chambre à feu en `light`.
static func _sil_toro(st: SurfaceTool, p: Vector3, s: float, col: Color, light: Color) -> void:
	_vrect(st, p + Vector3(-0.34 * s, 0, 0), p + Vector3(0.34 * s, 0.14 * s, 0), col, col)
	_vrect(st, p + Vector3(-0.1 * s, 0.14 * s, 0), p + Vector3(0.1 * s, 0.74 * s, 0), col, col)
	_vrect(st, p + Vector3(-0.3 * s, 0.74 * s, 0), p + Vector3(0.3 * s, 0.86 * s, 0), col, col)
	_vrect(st, p + Vector3(-0.22 * s, 0.86 * s, 0), p + Vector3(0.22 * s, 1.2 * s, 0), col, col)
	_vrect(st, p + Vector3(-0.13 * s, 0.92 * s, 0.05), p + Vector3(0.13 * s, 1.14 * s, 0.05), light, light)
	_vquad(st, p + Vector3(-0.48 * s, 1.2 * s, 0), p + Vector3(0.48 * s, 1.2 * s, 0), p + Vector3(0.12 * s, 1.44 * s, 0), p + Vector3(-0.12 * s, 1.44 * s, 0), col, col, col, col)
	for sx: float in [-1.0, 1.0]:
		_vtri(st, p + Vector3(sx * 0.48 * s, 1.2 * s, 0), p + Vector3(sx * 0.56 * s, 1.3 * s, 0), p + Vector3(sx * 0.36 * s, 1.24 * s, 0), col, col, col)
	_vdisc(st, p + Vector3(0, 1.52 * s, 0), 0.08 * s, col, col, 8)


## Pin de Hokusai en aplat : tronc penché en S (`lean` : sens), branches horizontales et plateaux
## d'aiguilles plats en couches (reflet `leaf_hi` dessus).
static func _sil_pine(st: SurfaceTool, rng: RandomNumberGenerator, p: Vector3, s: float, lean: float, trunk: Color, leaf: Color, leaf_hi: Color) -> void:
	var pts: Array[Vector3] = [p]
	var q := p
	for k in 4:
		q += Vector3(lean * s * (0.35 + 0.3 * sin(float(k) * 1.9)), 1.1 * s, 0)
		pts.append(q)
	for k in 4:
		_vstroke(st, pts[k], pts[k + 1], s * (0.32 - k * 0.06), trunk)
	for k in range(1, 5):
		var c: Vector3 = pts[k]
		var dir: float = -1.0 if k % 2 == 0 else 1.0
		var tip := c + Vector3(dir * s * rng.randf_range(0.9, 1.6), rng.randf_range(-0.1, 0.3) * s, 0.1)
		_vstroke(st, c, tip, s * 0.08, trunk)
		var rx := s * rng.randf_range(1.0, 1.5) * (1.15 - k * 0.1)
		_vellipse(st, tip + Vector3(0, 0.12 * s, 0.2), rx, rx * 0.28, leaf, leaf.darkened(0.18), 12)
		_vellipse(st, tip + Vector3(0, 0.2 * s, 0.3), rx * 0.7, rx * 0.15, leaf_hi, leaf, 10)


## Cèdre géant (sugi) en aplat, pied en `b`, haut de `h` : fût roux, étages de branches en pointe, de plus
## en plus sombres vers la cime, le pied fondu dans la brume `mist`.
static func _sil_cedar(st: SurfaceTool, b: Vector3, h: float, col: Color, mist: Color) -> void:
	var w := h * 0.15
	_vstroke(st, b, b + Vector3(0, h * 0.92, 0), w * 0.18, mist.lerp(col.lerp(Color("#5A3A2A"), 0.4), 0.7))
	var n := 9
	for k in n:
		var t := float(k) / n
		var y0 := b.y + h * lerpf(0.12, 0.86, t)
		var hw := w * lerpf(1.0, 0.25, t)
		var c_hi := mist.lerp(col, clampf(0.35 + t * 0.9, 0.0, 1.0))
		var c_lo := mist.lerp(col, clampf(0.15 + t * 0.9, 0.0, 1.0))
		var z := b.z + 0.05 * k
		_vtri(st, Vector3(b.x - hw, y0, z), Vector3(b.x + hw, y0, z), Vector3(b.x, y0 + h * 0.2, z), c_lo, c_lo, c_hi)


## Kasumi : bande de brume en gradins (une longue barre, deux plus courtes décalées), comme les
## nuées stylisées qui découpent les plans des estampes.
static func _kasumi(st: SurfaceTool, c: Vector3, w: float, h: float, top_c: Color, low_c: Color) -> void:
	_band(st, c, w, h, top_c, low_c)
	_band(st, c + Vector3(-w * 0.22, h * 0.55, -0.25), w * 0.5, h * 0.7, top_c, low_c)
	_band(st, c + Vector3(w * 0.25, -h * 0.5, 0.25), w * 0.42, h * 0.65, top_c, low_c)

# ------------------------------------------------------------------ lointain

## Œil de la caméra d'accueil (main._menu_transform : barque au large en z = 17.5, caméra en retrait, en
## hauteur, un peu à droite, fov 38° en largeur). Le lointain (z < -60, invisible en jeu) est composé pour
## elle comme une estampe : sur un écran portrait (19,5:9), horizon à 0.376 de la hauteur, titre de
## l'accueil entre 0.2 et 0.31, barque et héros au centre sous 0.33. D'où : le mont principal d'un côté,
## cime vers 0.285 ; soleil ou lune de l'autre côté, à la même hauteur, que rien ne coupe ; brumes (kasumi)
## minces et basses, au pied des monts (sous 0.335) ; oiseaux dans le ciel libre au-dessus du titre.
## Le proche (z > -55) sert aussi au haut de l'écran de jeu.
const HOME_EYE := Vector3(1.7, 3.1, 25.1)


## Point du lointain, à la profondeur `z`, qui tombe en (xs, ys) sur l'écran d'accueil (fractions de la
## largeur et de la hauteur depuis le coin haut gauche ; approximation au centième près).
static func _hp(xs: float, ys: float, z: float) -> Vector3:
	var d := HOME_EYE.z - z
	return Vector3(HOME_EYE.x + (xs - 0.712) * d / 1.477, HOME_EYE.y + (0.376 - ys) * d / 0.677, z)


## Taille (m) à la profondeur `z` d'une fraction `f` de la largeur de l'écran d'accueil.
static func _hw(f: float, z: float) -> float:
	return f * (HOME_EYE.z - z) / 1.477


## Le lointain du monde : vu surtout depuis la caméra d'accueil (basse, vers -Z ; voir HOME_EYE)
## et en haut de la vue de jeu. Tout est hors de |x| < 9 et |z| < 12.
static func build_backdrop(world_id: int, parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Backdrop"
	parent.add_child(root)
	match clampi(world_id, 1, WORLDS.size()):
		1:
			_backdrop_wave(root)
		2:
			_backdrop_tanabata(root)
		3:
			_backdrop_contes(root)
		4:
			_backdrop_fuji_rouge(root)
		6:
			_backdrop_kurama(root)
		7:
			_backdrop_ryugu(root)
		8:
			_backdrop_yomi(root)
		_:
			_backdrop_ink(root)


## Monde 1 : port de Kanagawa. Ciel d'aube du premier jour, soleil vermillon, chaînes bleues en couches,
## Fuji de Prusse coupé de kasumi, cap au pin de Hokusai, villages (un ninja court sur les faîtes), voiles
## et oiseaux de mer ; Grande Vague, îlots ; plus près : torii dans l'eau, entrepôts kura sur pilotis
## frappés du mon du clan, ponton du port, lanterne de port, pieux d'amarrage, barques.
static func _backdrop_wave(root: Node3D) -> void:
	var rng := _rng(11)
	var lite: bool = Toon.lite
	var st := _vc_begin()
	_vrect(st, Vector3(-340, -2, -250), Vector3(340, 30, -250), Color("#EDB48F"), Toon.WASHI)
	_vrect(st, Vector3(-340, 30, -250), Vector3(340, 160, -250), Toon.WASHI, Color("#DCD6C6"))
	# soleil vermillon du premier jour, à droite sous le titre : rien ne le coupe
	_vdisc(st, _hp(0.83, 0.285, -236.0), 10.0, Toon.VERMILION, Toon.VERMILION.darkened(0.06), 32)
	_ridge(st, rng, -280.0, 280.0, -215.0, -1.0, 9.0, Color("#8597B0"), Color("#E6D8C2"), 34)
	_ridge(st, rng, -260.0, 260.0, -192.0, -1.0, 6.0, Color("#5F7593"), Color("#DCD3C1"), 34)
	# Fuji de Prusse à gauche, aux flancs concaves, neige aux coulées dentelées ; cime sous le trait du titre
	var fuji := _hp(0.25, 0.283, -170.0)
	_sil_mount(st, Vector3(fuji.x, -1.0, -170.0), 44.0, fuji.y + 1.0, 1.7, 0.05, Color("#3F5878"), Color("#9AA8BC"), Toon.WASHI, 0.27)
	# kasumi minces au pied du Fuji seulement, une bande basse sous le soleil
	_kasumi(st, Vector3(fuji.x + 6.0, 3.0, -150.0), 110.0, 1.1, Color("#F7F0E2"), Toon.WASHI)
	_kasumi(st, Vector3(fuji.x - 12.0, 7.2, -146.0), 56.0, 0.8, Color("#F7F0E2"), Toon.WASHI)
	_kasumi(st, _hp(0.86, 0.338, -200.0), 70.0, 0.9, Color("#F7F0E2"), Color("#EFE2CE"))
	_kasumi(st, _hp(0.6, 0.366, -140.0), 90.0, 1.0, Color("#F7F0E2"), Toon.WASHI)
	_ridge(st, rng, -220.0, 220.0, -128.0, -1.0, 3.2, Color("#3F5878"), Color("#C9C6B8"), 30)
	# cap au pin de Hokusai, villages de pêcheurs (faîtes où court un ninja)
	_ridge(st, rng, -86.0, -46.0, -124.0, -1.0, 2.6, Color("#33496A"), Color("#C9C6B8"), 10)
	_sil_pine(st, rng, Vector3(-64, 1.2, -123.5), 2.0, 0.7, Color("#22283A"), Color("#2F4A3C"), Color("#4E6E5B"))
	_sil_roofline(st, rng, -110.0, -36.0, -126.5, -0.6, 1.8, Color("#4A5E78"), Color("#2E3B52"), Color(0, 0, 0, 0), Color("#1B2232"))
	_sil_roofline(st, rng, -2.0, 110.0, -126.5, -0.6, 1.8, Color("#4A5E78"), Color("#2E3B52"), Color(0, 0, 0, 0), Color("#1B2232"))
	# brumes basses entre les plans (jamais plus haut que le pied des monts)
	for k in (3 if lite else 5):
		_kasumi(st, Vector3(rng.randf_range(-90.0, 60.0), 1.6 + k * 0.9, -112.0 - k * 6.0),
			rng.randf_range(40.0, 90.0), rng.randf_range(0.8, 1.4), Color("#F7F0E2"), Color("#E9DCC6"))
	for k in (4 if lite else 7):
		var z := rng.randf_range(-115.0, -45.0)
		var face: float = -1.0 if rng.randf() < 0.5 else 1.0
		_sil_boat(st, Vector3(rng.randf_range(-60.0, 60.0), VOID_Y, z), rng.randf_range(0.9, 1.5) * (1.0 - z / 260.0), Color("#2E3B52"), Color("#F4EEDF"), face)
	# oiseaux de mer dans le ciel libre, au-dessus du titre et loin du soleil
	_flock(st, rng, _hp(0.24, 0.15, -95.0), 7, Vector3(9, 2.5, 4), 1.2, Color("#2B3448"))
	_flock(st, rng, _hp(0.7, 0.19, -120.0), 5, Vector3(7, 2, 3), 1.4, Color("#3A4660"))
	_vc_end(st, root)
	# rides d'écume au large
	var foam := {}
	var fm := _toon(Toon.FOAM, false)
	for i in 40:
		var x := rng.randf_range(-27.0, 27.0)
		var z := rng.randf_range(-70.0, -13.0)
		_add(foam, fm, Toon.box(Vector3(rng.randf_range(1.8, 6.6), 0.02, 0.14)), _at(Vector3(x, VOID_Y + 0.01, z)))
	_flush(foam, root)
	# la Grande Vague de Kanagawa à droite (vue de profil depuis l'accueil, la lèvre vers le Fuji, la crête
	# sous le soleil), une plus petite au loin ; îlots à pins
	var wv := _hp(0.88, 0.0, -58.0)
	var w1: Node3D = Decor.great_wave(root, Vector3(wv.x, VOID_Y, -58.0), 2.3, 1)
	w1.rotation.y = -1.2
	var wv2 := _hp(0.97, 0.0, -95.0)
	var w2: Node3D = Decor.great_wave(root, Vector3(wv2.x, VOID_Y, -95.0), 1.6, 2)
	w2.rotation.y = -0.9
	# îlots fusionnés dans un même lot (6 draw calls pour les trois)
	var isl := {}
	Decor.island_into(isl, _at(Vector3(14, VOID_Y, -30), Vector3.ZERO, Vector3.ONE * 1.4), 1)
	Decor.island_into(isl, _at(Vector3(-34, VOID_Y, -70), Vector3.ZERO, Vector3.ONE * 2.4), 2)
	Decor.island_into(isl, _at(Vector3(45, VOID_Y, -110), Vector3.ZERO, Vector3.ONE * 3.0), 3)
	_flush(isl, root, false)
	# le port, plus près
	var b := {}
	var bn := {}
	# entrepôts kura sur pilotis, frappés du mon du clan, toits de tuiles où courent les ninjas
	for k in 3:
		var kx := _at(Vector3(-21.0 - k * 0.5, VOID_Y, -31.0 - k * 4.4), Vector3(0, PI * 0.5 + rng.randf_range(-0.06, 0.06), 0))
		_kura_into(b, bn, kx, rng.randf_range(3.0, 3.6), 2.8, rng.randf_range(2.2, 2.8), k % 4)
	Decor.torii_into(b, _at(Vector3(-14.0, VOID_Y, -27.0), Vector3(0, 0.3, 0), Vector3.ONE * 0.95), -0.7)
	var px := _at(Vector3(13.0, 0.0, -19.0), Vector3(0, -0.12, 0))
	Decor.pier_into(b, px, 1.7, 7.5, -0.05, VOID_Y - 0.4)
	for k in 4:
		Decor.sake_barrel_into(b, bn, px * _at(Vector3(rng.randf_range(-0.45, 0.45), -0.05, -2.8 + k * 0.6), Vector3(0, rng.randf() * TAU, 0)))
	Decor.net_rack_into(b, bn, px * _at(Vector3(0, 0, 1.6), Vector3(0, PI * 0.5, 0)), -0.05)
	_port_lantern_into(b, bn, _at(Vector3(11.0, VOID_Y, -24.5), Vector3.ZERO, Vector3.ONE * 1.3))
	for k in 12:
		var top := _bitt_into(b, bn, Vector3(-10.6 + rng.randf_range(-0.2, 0.2), VOID_Y - 0.3, -12.5 - k * 2.3), rng.randf_range(1.2, 1.9))
		if rng.randf() < 0.3:
			Decor.gull_into(bn, _at(top, Vector3(0, rng.randf() * TAU, 0)))
	_boat_into(b, _at(Vector3(-17.5, VOID_Y, -17.0), Vector3(0, 0.5, 0), Vector3.ONE * 1.1), 2)
	_boat_into(b, _at(Vector3(18.0, VOID_Y, -33.0), Vector3(0, -0.3, 0), Vector3.ONE * 1.2), 3)
	_boat_into(b, _at(Vector3(-6.0, VOID_Y, -38.0), Vector3(0, 0.1, 0), Vector3.ONE * 1.3), 0)
	_flush(b, root, false)
	_flush(bn, root, false)


## Monde 2 : nuit de Tanabata, ciel en bokashi nocturne, Voie lactée, chaînes sombres, pagode aux fenêtres
## éclairées, nuages en bandes devant la lune, feux de renards sous une allée de torii qui gravit la colline,
## cascade de Kirifuri ; rideau de bambous, allée de torii, pont arqué vermillon.
static func _backdrop_tanabata(root: Node3D) -> void:
	var rng := _rng(22)
	var lite: bool = Toon.lite
	var sky: Array = [-2.0, Color("#2E3B4E"), 40.0, Color("#1F2A3A"), 160.0, Color("#121A26")]
	var st := _vc_begin()
	_vrect(st, Vector3(-340, -2, -252), Vector3(340, 40, -252), Color("#2E3B4E"), Color("#1F2A3A"))
	_vrect(st, Vector3(-340, 40, -252), Vector3(340, 160, -252), Color("#1F2A3A"), Color("#121A26"))
	# Voie lactée en écharpe au-dessus du titre, halo de la lune peints dans le ciel (aplats mêlés au bokashi)
	var mw := _hp(0.42, 0.13, -248.0)
	_veil_band(st, mw, 420.0, 22.0, -0.3, Color(0.9, 0.9, 1.0), 0.08, sky)
	_veil_band(st, mw + Vector3(0, 0, 1), 420.0, 8.0, -0.3, Color(0.95, 0.95, 1.0), 0.12, sky)
	var moon := _hp(0.8, 0.27, -200.0)
	var mh := _hp(0.8, 0.27, -244.0)
	var halo := _sky_at(mh.y, sky)
	_vdisc(st, mh, 17.0, halo.lerp(Color("#F4ECD2"), 0.18), halo, 32)
	for i in (40 if lite else 70):
		var p := Vector3(rng.randf_range(-170.0, 170.0), rng.randf_range(18.0, 150.0), rng.randf_range(-246.0, -240.0))
		var r := rng.randf_range(0.18, 0.42)
		_vquad(st, p + Vector3(0, -r, 0), p + Vector3(r, 0, 0), p + Vector3(0, r, 0), p + Vector3(-r, 0, 0),
			Color("#F6F0DC"), Color("#F6F0DC"), Color("#F6F0DC"), Color("#F6F0DC"))
	_ridge(st, rng, -280.0, 280.0, -205.0, -1.0, 15.0, Color("#2C384C"), Color("#2C3848"), 30)
	_ridge(st, rng, -260.0, 260.0, -178.0, -1.0, 9.0, Color("#1C2531"), Color("#283444"), 30)
	# pleine lune de la nuit des étoiles, à droite sous le titre ; un nuage mince passe dessous
	_vdisc(st, moon, 8.0, Color("#F4ECD2"), Color("#EAE0C2"), 32)
	_band(st, _hp(0.78, 0.332, -170.0), 40.0, 0.9, Color("#5A6880"), Color("#3B475C"))
	_band(st, _hp(0.9, 0.342, -170.0), 26.0, 0.7, Color("#5A6880"), Color("#3B475C"))
	# mont sombre de la bambouseraie à gauche (crête pâle sous la lune), collines basses ailleurs
	var pk := _hp(0.27, 0.29, -150.0)
	_sil_mount(st, Vector3(pk.x, -1.0, -150.0), 34.0, pk.y + 1.0, 1.25, 0.04, Color("#34425A"), Color("#222C3A"), Color("#3E4C66"), 0.1, 18)
	for hx: float in [0.04, 0.52, 0.66, 0.95]:
		var hp := _hp(hx, rng.randf_range(0.33, 0.345), -130.0)
		_sil_mount(st, Vector3(hp.x, -1.0, -130.0), rng.randf_range(16.0, 22.0), hp.y + 1.0, 1.15, 0.03, Color("#26313F"), Color("#26313F"), Color(0, 0, 0, 0), 0.0, 14)
	_kasumi(st, _hp(0.35, 0.362, -140.0), 70.0, 1.1, Color("#3E4A60"), Color("#2C3848"))
	# pagode aux fenêtres éclairées à droite, sous la lune
	var pg := _hp(0.9, 0.0, -105.5)
	_ridge(st, rng, pg.x - 16.0, pg.x + 40.0, -106.0, -1.0, 5.0, Color("#18202A"), Color("#202B38"), 12)
	_sil_pagoda(st, Vector3(pg.x, 2.6, -105.5), 2.6, 5, Color("#141A22"), Color("#0F141B"), Color("#F2C46A"))
	# allée de torii (Fushimi Inari) qui monte la colline, chaque porche tenant un feu de renard
	for k in 7:
		var t := float(k) / 6.0
		var tp := Vector3(lerpf(-44.0, -8.0, t), 1.4 + 5.0 * t + sin(t * 9.0) * 1.2, -96.5)
		_sil_torii(st, tp, 0.55, Color("#6E2420"))
	for i in 22:
		var t := float(i) / 21.0
		var c := Vector3(lerpf(-46.0, -6.0, t), 2.0 + 5.0 * t + sin(t * 9.0) * 1.2, -96.0)
		_vrect(st, c - Vector3(0.28, 0.4, 0), c + Vector3(0.28, 0.4, 0), Color("#F6D58A"), Color("#FBE9B8"))
	# cascade de Kirifuri au bord gauche de l'accueil : falaise, filets d'eau digités, brume au pied (aplats)
	var fo := Vector3(_hp(0.04, 0.0, -90.0).x, VOID_Y, -90.0)
	var cliff := Color("#2F3B45")
	_vrect(st, fo + Vector3(-8, 0, 0), fo + Vector3(8, 30, 0), cliff, cliff)
	var hi := Color("#3A4752")
	var cb := Basis(Vector3(0, 0, 1), 0.08)
	var cc := fo + Vector3(-0.5, 29, 4.0)
	_vquad(st, cc + cb * Vector3(-6.5, -2, 0), cc + cb * Vector3(6.5, -2, 0), cc + cb * Vector3(6.5, 2, 0), cc + cb * Vector3(-6.5, 2, 0), hi, hi, hi, hi)
	var water := Color("#DCE7EF")
	for k in 6:
		var x := -4.0 + k * 1.6 + rng.randf_range(-0.3, 0.3)
		var w := rng.randf_range(0.5, 1.2)
		_vrect(st, fo + Vector3(x - w * 0.5, 1.0, 0.7), fo + Vector3(x + w * 0.5, 27.0, 0.7), water, water)
		for sx: float in [-1.0, 1.0]:
			var sb := Basis(Vector3(0, 0, 1), sx * 0.18)
			var sc := fo + Vector3(x + sx * w * 0.5, 3.5, 0.8)
			var hw2 := w * 0.175
			_vquad(st, sc + sb * Vector3(-hw2, -3, 0), sc + sb * Vector3(hw2, -3, 0), sc + sb * Vector3(hw2, 3, 0), sc + sb * Vector3(-hw2, 3, 0), water, water, water, water)
	var mist := cliff.lerp(Color(0.92, 0.95, 1.0), 0.5)
	for k in 4:
		_vellipse(st, fo + Vector3(-4.0 + k * 2.8, 0.6, 1.5 + k * 0.05), 4.0, 2.5, mist, mist.darkened(0.06), 12)
	_vc_end(st, root)
	# rideau lointain de tiges (aplats) et leurs feuillages sombres
	var far := {}
	var g1 := _flat(Color("#2C4434"))
	var g2 := _flat(Color("#38563F"))
	var gl := _flat(Color("#27402F"))
	for i in 56:
		var x := rng.randf_range(-34.0, 34.0)
		var z := rng.randf_range(-40.0, -24.0)
		var h := rng.randf_range(14.0, 24.0)
		# vus de l'accueil, les fûts du milieu restent bas (la lune et le mont au-dessus) ; les grands
		# encadrent l'image sur les bords (en jeu, seul le pied des fûts paraît, en haut de l'écran)
		var xs := 0.712 + 1.477 * (x - HOME_EYE.x) / (HOME_EYE.z - z)
		if xs > 0.1 and xs < 0.9:
			h = h * 0.3
		var w := rng.randf_range(0.22, 0.42)
		var gm: StandardMaterial3D = g1 if rng.randf() < 0.5 else g2
		_add(far, gm, Toon.cyl(w * 0.8, w, h, 5), _at(Vector3(x, VOID_Y + h * 0.5, z), Vector3(0, 0, rng.randf_range(-0.04, 0.04))))
		_add(far, gl, _ball(rng.randf_range(1.2, 2.2), rng.randf_range(0.8, 1.4), 7, 3), _at(Vector3(x, VOID_Y + h, z)))
	_flush(far, root)
	# bosquets de bambous géants, allée de torii vermillon, pont arqué
	var b := {}
	var bn := {}
	for k in 9:
		var bx := -12.0 + k * 3.0 + rng.randf_range(-0.6, 0.6)
		var bz := rng.randf_range(-16.5, -13.5)
		var bsc := rng.randf_range(2.6, 3.4)
		if absf(bx) < 7.5:
			continue  # le lointain suit la caméra : au milieu, ces géants se dresseraient sur le chemin du haut
		Decor.bamboo_into(b, bn, _at(Vector3(bx, VOID_Y, bz), Vector3.ZERO, Vector3.ONE * bsc), 200 + k)
	for k in 5:
		Decor.bamboo_into(b, bn, _at(Vector3(rng.randf_range(10.5, 12.5), VOID_Y, -11.0 + k * 3.8), Vector3.ZERO, Vector3.ONE * rng.randf_range(2.4, 3.2)), 220 + k)
	for k in 3:
		Decor.bamboo_into(b, bn, _at(Vector3(rng.randf_range(-15.0, -14.0), VOID_Y, -10.0 + k * 5.0), Vector3.ZERO, Vector3.ONE * rng.randf_range(2.4, 3.0)), 240 + k)
	for k in 9:
		Decor.torii_into(b, _at(Vector3(-11.0, VOID_Y, -12.5 - k * 2.3), Vector3.ZERO, Vector3.ONE * 0.8), 0.0)
	var bxf := _at(Vector3(16.5, VOID_Y + 0.3, -23.0), Vector3(0, -0.35, 0))
	Decor.arched_bridge_into(b, bxf, 7.0, 1.4, Toon.VERMILION.darkened(0.08), Color("#3B2E25"), -0.7)
	for sx: float in [-1.0, 1.0]:
		var e := bxf * Vector3(sx * 4.0, -0.3, 0.0)
		Decor.rock_into(b, _at(Vector3(e.x, VOID_Y, e.z), Vector3.ZERO, Vector3.ONE * 1.4), 300 + int(sx))
		Decor.stone_lantern_into(b, bn, _at(Vector3(e.x, VOID_Y + 0.45, e.z), Vector3.ZERO, Vector3.ONE * 0.9))
	_flush(b, root, false)
	_flush(bn, root, false)


## Monde 3 : temple sous la neige. Ciel bokashi lavande en haut, chaînes blanches en couches,
## lisière de conifères enneigés, toits de temples, ville d'Edo aux toits blancs et son donjon,
## pont de la Sumida sous la neige, corbeaux ;
## berges, pagode, cimetière, pins, beffroi, torii enneigé, lanternes flottantes.
static func _backdrop_contes(root: Node3D) -> void:
	var rng := _rng(33)
	var st := _vc_begin()
	_vrect(st, Vector3(-340, -2, -252), Vector3(340, 24, -252), Color("#E2E7EC"), Color("#D3D9E2"))
	_vrect(st, Vector3(-340, 24, -252), Vector3(340, 160, -252), Color("#D3D9E2"), Color("#6F7896"))
	# pâle soleil d'hiver, à gauche sous le titre
	_vdisc(st, _hp(0.14, 0.29, -236.0), 9.0, Color("#F6E2D8"), Color("#EDD3C8"), 28)
	_ridge(st, rng, -280.0, 280.0, -222.0, -1.0, 17.0, Color("#F2F5F8"), Color("#A9AFC2"), 34)
	_ridge(st, rng, -260.0, 260.0, -196.0, -1.0, 11.0, Color("#E9EDF2"), Color("#9AA1B6"), 30)
	# grand mont blanc à droite du héros (pied lavande, calotte de neige jusqu'à mi-pente), collines basses
	var pk := _hp(0.7, 0.285, -172.0)
	_sil_mount(st, Vector3(pk.x, -1.0, -172.0), 40.0, pk.y + 1.0, 1.45, 0.04, Color("#C9CEDC"), Color("#A9AFC2"), Color("#F4F7FA"), 0.5, 26)
	for i in 7:
		var h := rng.randf_range(9.0, 15.0)
		_sil_mount(st, Vector3(-120.0 + i * 33.0 + rng.randf_range(-6.0, 6.0), -1.0, rng.randf_range(-165.0, -140.0)),
			h * 1.6, h, 1.2, 0.02, Color("#B9BFD0"), Color("#A9AFC2"), Color("#EEF2F6"), 0.5, 14)
	_kasumi(st, Vector3(pk.x - 4.0, 3.0, -150.0), 90.0, 1.1, Color("#F2F5F8"), Color("#DDE2EA"))
	_sil_trees(st, rng, -160.0, 160.0, -138.0, -1.0, (40 if Toon.lite else 70), 6.0, Color("#3E4656"), SNOW)
	for k in 3:
		_sil_temple(st, Vector3(-70.0 + k * 62.0 + rng.randf_range(-8.0, 8.0), 0.5, -134.0), rng.randf_range(4.0, 6.0), Color("#4A4652"), Color("#2E2C33"), SNOW)
	_sil_bridge(st, Vector3(-26.0, VOID_Y, -74.0), 48.0, 3.4, 0.8, Color("#3A3A48"), SNOW, 6)
	# ville d'Edo sous la neige le long de la berge (toits blancs, un ninja d'un faîte à l'autre) et son
	# donjon blanc devant le flanc du mont
	_sil_roofline(st, rng, -120.0, -40.0, -112.0, -0.6, 1.7, Color("#5A5868"), Color("#34323C"), SNOW, Color("#1E1C24"))
	_sil_roofline(st, rng, 6.0, 120.0, -112.0, -0.6, 1.7, Color("#5A5868"), Color("#34323C"), SNOW, Color("#1E1C24"))
	var cs := _hp(0.9, 0.0, -116.0)
	_sil_castle(st, Vector3(cs.x, -0.6, -116.0), 3.0, Color("#ECEEF2"), Color("#34323C"), Color("#7E7B86"), Color("#2A2830"), Color("#B9B3A6"), SNOW)
	_kasumi(st, Vector3(-20, 3.6, -104), 120.0, 1.2, Color("#F2F5F8"), Color("#DDE2EA"))
	# corbeaux dans le ciel libre
	_flock(st, rng, _hp(0.3, 0.16, -80.0), 7, Vector3(8, 2.5, 4), 1.0, Color("#2B2A30"))
	_flock(st, rng, _hp(0.86, 0.2, -110.0), 5, Vector3(6, 2, 3), 1.4, Color("#3A3942"))
	_vc_end(st, root)
	# berges enneigées : (x, z, rayon)
	var banks: Array[Vector3] = [Vector3(-11, -20, 7), Vector3(10, -19, 6), Vector3(0, -33, 10),
		Vector3(-12.5, -4, 3.5), Vector3(12.5, 1, 3.5)]
	var sb := {}
	var snow := _toon(SNOW, false)
	var shade := _toon(SNOW_SHADE, false)
	for bk in banks:
		_add(sb, snow, Toon.sphere(1.0), _at(Vector3(bk.x, VOID_Y, bk.y), Vector3.ZERO, Vector3(bk.z, bk.z * 0.15, bk.z)))
		_add(sb, shade, Toon.cyl(bk.z * 1.03, bk.z * 1.06, 0.05, 18), _at(Vector3(bk.x, VOID_Y + 0.02, bk.y)))
	# pagode sur la berge de gauche, beffroi et torii enneigé sur la berge du fond
	var b := {}
	var bn := {}
	_pagoda_into(sb, _at(Vector3(-11, VOID_Y + 7.0 * 0.15 - 0.08, -20), Vector3(0, 0.3, 0), Vector3.ONE * 1.5))
	Decor.bell_tower_into(sb, bn, _at(Vector3(-2.5, _dome_y(0, -33, 10, -2.5, -36) - 0.05, -36.0), Vector3(0, 0.2, 0), Vector3.ONE * 1.25), true)
	_snow_torii(sb, bn, _at(Vector3(2.5, _dome_y(0, -33, 10, 2.5, -29) - 0.08, -29.0), Vector3(0, -0.15, 0), Vector3.ONE * 0.75))
	for k in 4:
		var lx := 1.2 + k * 0.9
		var lz := -25.5 + k * 0.3
		Decor.stone_lantern_into(b, bn, _at(Vector3(lx, _dome_y(0, -33, 10, lx, lz) - 0.04, lz), Vector3.ZERO, Vector3.ONE * 0.8))
	# cimetière : stèles en rangées sur la berge de droite
	var gm := _toon(GRAVE, true, 0.02)
	for i in 4:
		for j in 4:
			var lx := -2.4 + j * 1.5 + rng.randf_range(-0.2, 0.2)
			var lz := -2.0 + i * 1.3 + rng.randf_range(-0.2, 0.2)
			var y := _dome_y(0, 0, 6, lx, lz) - 0.05
			var xf := _at(Vector3(10.0 + lx, y, -19.0 + lz), Vector3(rng.randf_range(-0.06, 0.06), rng.randf_range(-0.2, 0.2), rng.randf_range(-0.08, 0.08)),
				Vector3.ONE * rng.randf_range(0.9, 1.25))
			_stele_into(b, gm, snow, xf)
	_sotoba_into(b, _at(Vector3(10.2, _dome_y(10, -19, 6, 10.2, -22.5) - 0.05, -22.5)), rng)
	# pins enneigés sur les berges
	var pspots: Array[Vector3] = [Vector3(-15, 0.1, -17), Vector3(-7, 0.1, -23), Vector3(-5, 0.6, -30), Vector3(6, 0.6, -31),
		Vector3(14, -0.1, -16), Vector3(-12.5, -0.15, -4), Vector3(12.8, -0.15, 1)]
	for p in pspots:
		_snow_pine_into(sb, _at(p, Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * rng.randf_range(1.3, 2.0)))
	Decor.stone_lantern_into(b, bn, _at(Vector3(7.0, 0.15, -16.5)))
	_flush(sb, root, true)
	# lanternes flottantes (tōrō nagashi) et glaçons sur l'étang
	var placed := 0
	for attempt in 160:
		if placed >= 30:
			break
		var p := Vector3.ZERO
		if rng.randf() < 0.65:
			p = Vector3(rng.randf_range(-15.0, 15.0), VOID_Y, rng.randf_range(-36.0, -13.0))
		else:
			var sx: float = -1.0 if rng.randf() < 0.5 else 1.0
			p = Vector3(sx * rng.randf_range(9.5, 14.0), VOID_Y, rng.randf_range(-11.0, 6.0))
		var inside := false
		for bk in banks:
			if Vector2(p.x - bk.x, p.z - bk.y).length() < bk.z * 1.1:
				inside = true
				break
		if inside:
			continue
		if placed % 3 == 2:
			_add(bn, _toon(ICE, false), _cyl(0.6, 0.62, 0.06, 6), _at(p + Vector3(0, 0.02, 0), Vector3(0, rng.randf() * TAU, 0), Vector3(rng.randf_range(0.8, 1.8), 1, rng.randf_range(0.6, 1.4))))
		else:
			_toro_into(bn, _at(p, Vector3(0, rng.randf() * TAU, 0)))
		placed += 1
	_flush(b, root, false)
	_flush(bn, root, false)


## Monde 4 : Fuji rouge (Gaifū kaisei) sous un ciel bokashi bleu de Prusse, nuages en écailles,
## pagode Chūreitō, Fudō Myōō et son halo de flammes, fumée du sommet ; coulées de lave noire
## veinée d'or, piques de roche, torches géantes de Yoshida, torii qui encadre le Fuji.
static func _backdrop_fuji_rouge(root: Node3D) -> void:
	var rng := _rng(44)
	var fx := 8.0
	var fz := -165.0
	var st := _vc_begin()
	_vrect(st, Vector3(-340, -2, -252), Vector3(340, 28, -252), Color("#D9A07A"), Color("#5E7393"))
	_vrect(st, Vector3(-340, 28, -252), Vector3(340, 160, -252), Color("#5E7393"), Toon.PRUSSIAN)
	_ridge(st, rng, -260.0, -36.0, -152.0, -1.0, 11.0, Color("#33403C"), Color("#5A4A4E"), 18)
	_ridge(st, rng, 52.0, 260.0, -152.0, -1.0, 11.0, Color("#33403C"), Color("#5A4A4E"), 18)
	_ridge(st, rng, -220.0, 220.0, -116.0, -1.0, 3.6, Color("#1E2523"), Color("#3A3335"), 30)
	_ridge(st, rng, -52.0, -16.0, -112.0, -1.0, 4.5, Color("#1A211F"), Color("#2F2A2C"), 10)
	_sil_pagoda(st, Vector3(-34, 2.6, -111.5), 2.4, 5, Color("#3A2422"), Color("#24171A"), Color(0, 0, 0, 0))
	# Fudō et son halo de flammes au bord gauche de l'accueil
	_fudo(st, Vector3(_hp(0.1, 0.0, -100.0).x, -1.0, -100.0), 1.5, Color("#1E1517"), LAVA_GOLD, BRAISE)
	# fumée du sommet : bandes qui partent au-dessus et à droite de la cime, sans la couvrir
	for k in 4:
		_band(st, Vector3(fx + 11.0 + k * 8.0, 32.5 + k * 3.2, fz + 8.0), 14.0 + k * 6.0, 1.3, Color("#9A8C86"), Color("#7C6E6A"))
	_flock(st, rng, _hp(0.3, 0.17, -100.0), 5, Vector3(8, 2.5, 4), 1.4, Color("#1E1A1C"))
	# Gaifū kaisei : Fuji rouge aux flancs concaves, cime sombre, coulées de neige qui s'évasent
	_sil_mount(st, Vector3(fx, -1.0, fz), 52.0, 30.0, 1.45, 0.06, Color("#B5502F"), Color("#6E3324"), Color("#4A221E"), 0.2, 28)
	var white := Color("#F1EEE6")
	for k in 9:
		var xa := rng.randf_range(-0.9, 0.9) * 3.0
		var d1 := rng.randf_range(3.0, 7.5)
		var top := Vector3(fx + xa, 29.0 - 0.3, fz + 0.6)
		var foot := Vector3(fx + xa * (1.0 + d1 * 0.3) + rng.randf_range(-0.6, 0.6), 29.0 - d1, fz + 0.6)
		_vtri(st, top + Vector3(-0.4, 0, 0), top + Vector3(0.4, 0, 0), foot, white, white, white.darkened(0.06))
	# forêt sombre au pied
	_vellipse(st, Vector3(fx, -2.0, -140.0), 70.0, 7.0, Color("#2B3F3C"), Color("#22332F"), 24)
	# nuages en écailles (alto-cumulus de l'estampe)
	var rows: int = 3 if Toon.lite else 5
	for row in rows:
		for col in 18:
			var x := -150.0 + col * 17.0 + (8.5 if row % 2 == 1 else 0.0) + rng.randf_range(-2.0, 2.0)
			var r := 4.5 - row * 0.35
			# au-dessus de la cime (derrière le titre), jamais à sa hauteur
			_vellipse(st, Vector3(x, 41.0 + row * 5.0, -195.0 - row * 3.0), r, r * 0.5, Color("#EDE6D8"), Color("#DCD2C0"), 10)
	_vc_end(st, root)
	# coulées de lave noire veinées d'or, du fond vers l'arène et le long des côtés
	var lava := {}
	var veins := {}
	var lm := _toon(LAVA, false)
	var vm := _glow(LAVA_GOLD, 1.4)
	_lava_flow(lava, veins, lm, vm, Vector2(-22, -85), Vector2(-6, -13), 3.6, rng)
	_lava_flow(lava, veins, lm, vm, Vector2(16, -95), Vector2(5, -13), 3.2, rng)
	_lava_flow(lava, veins, lm, vm, Vector2(-11.5, -45), Vector2(-11.5, 8), 2.6, rng)
	_lava_flow(lava, veins, lm, vm, Vector2(12, -45), Vector2(11.5, 8), 2.6, rng)
	_flush(lava, root)
	_flush(veins, root)
	# piques de roche, torii qui encadre le Fuji, lanternes sur basalte
	var sp := {}
	var bn := {}
	var bm := _toon(BASALT, true, 0.03)
	for i in 16:
		var p := Vector2.ZERO
		if rng.randf() < 0.6:
			p = Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(-42.0, -13.5))
			if absf(p.x) < 4.5 and p.y > -30.0 and p.y < -24.0:
				p.x += 9.0
		else:
			var sx: float = -1.0 if rng.randf() < 0.5 else 1.0
			p = Vector2(sx * rng.randf_range(13.0, 18.0), rng.randf_range(-12.0, 6.0))
		var h := rng.randf_range(3.0, 8.0)
		if p.y < -13.5:
			h = minf(h, 5.0)  # derrière l'arène : vus de l'accueil, ils resteraient devant le Fuji
		var base := Vector3(p.x, VOID_Y - 0.2, p.y)
		_limb(sp, bm, base, base + Vector3(rng.randf_range(-0.2, 0.2) * h, h, rng.randf_range(-0.2, 0.2) * h), rng.randf_range(0.8, 1.8), 0.05, 5)
	Decor.torii_into(sp, _at(Vector3(0, VOID_Y, -27.0), Vector3.ZERO, Vector3.ONE * 1.1), -0.6)
	for sx: float in [-1.0, 1.0]:
		_add(sp, bm, _cyl(0.5, 0.6, 0.9, 6), _at(Vector3(sx * 4.4, VOID_Y + 0.05, -26.0)))
		Decor.stone_lantern_into(sp, bn, _at(Vector3(sx * 4.4, VOID_Y + 0.5, -26.0), Vector3.ZERO, Vector3.ONE * 1.1))
	# torches géantes du Yoshida Hi-Matsuri
	var spots: Array[Vector3] = [Vector3(-10, VOID_Y, -11), Vector3(10, VOID_Y, -11), Vector3(-10, VOID_Y, -3),
		Vector3(10, VOID_Y, -3), Vector3(-10, VOID_Y, 5), Vector3(10, VOID_Y, 5), Vector3(-5.5, VOID_Y, -13.5), Vector3(5.5, VOID_Y, -13.5)]
	for p in spots:
		_yoshida_into(sp, bn, _at(p))
	_flush(sp, root, true)
	_flush(bn, root, false)


## Monde 5 : mer d'encre. Ciel de papier rose d'aube sous une bande de Prusse, chaînes d'encre
## en couches, ensō dans le ciel, pont de Mannen qui encadre le petit Fuji, donjon d'encre et toits
## de la ville du château (un ninja sur les faîtes), donjon en volume près de l'arène, banc de sable
## et croquis du Manga, grues, voiles ; grandes vagues noires, barques, pinceaux, papiers, barrique.
static func _backdrop_ink(root: Node3D) -> void:
	var rng := _rng(55)
	var lite: bool = Toon.lite
	var sky: Array = [-2.0, Color("#EDC2B4"), 26.0, Color("#EAD2C8"), 160.0, Color("#8FA3B8")]
	var st := _vc_begin()
	_vrect(st, Vector3(-340, -2, -252), Vector3(340, 26, -252), Color("#EDC2B4"), Color("#EAD2C8"))
	_vrect(st, Vector3(-340, 26, -252), Vector3(340, 160, -252), Color("#EAD2C8"), Color("#8FA3B8"))
	# soleil pâle à droite sous le titre ; ensō d'encre tracé dans le ciel libre en haut à gauche ;
	# bandes de nuages rose d'aube / washi basses, au pied des chaînes (aplats fondus dans le ciel)
	_vdisc(st, _hp(0.84, 0.285, -236.0), 9.0, Color("#F3D3B5"), Color("#EFCBAE"), 28)
	_enso(st, _hp(0.2, 0.15, -196.0), 9.0, 1.6, Toon.SUMI)
	for k in 6:
		var cy := 2.6 + k * 1.5
		var cz := -200.0 - k * 5.0
		var tint: Color = Color("#E4B7B0") if k % 2 == 0 else Toon.WASHI
		var a: float = 0.7 if k % 2 == 0 else 0.8
		var col := _sky_at(cy, sky).lerp(tint, a)
		_kasumi(st, Vector3(rng.randf_range(-90.0, 50.0), cy, cz), rng.randf_range(80.0, 160.0), rng.randf_range(0.9, 1.6), col.lightened(0.04), col)
	_ridge(st, rng, -280.0, 280.0, -210.0, -1.0, 11.0, Color("#5B6070"), Color("#E4C3B8"), 34)
	_ridge(st, rng, -260.0, 260.0, -184.0, -1.0, 6.5, Color("#2B3448"), Color("#DDBFB4"), 34)
	# le donjon d'encre sur sa colline, à gauche : murs de washi, toits de sumi, shachihoko d'or ; pins
	# de Hokusai sur les épaules de la colline
	var cs := _hp(0.27, 0.0, -150.0)
	_sil_mount(st, Vector3(cs.x, -1.0, -152.0), 34.0, 8.0, 1.0, 0.28, Color("#3A3F52"), Color("#6E6A72"), Color(0, 0, 0, 0), 0.0, 18)
	_sil_castle(st, Vector3(cs.x, 6.4, -150.5), 3.6, Toon.WASHI, Toon.SUMI, Color("#4A4642"), Color("#2A2830"), Toon.GOLD, Color(0, 0, 0, 0))
	for sx: float in [-1.0, 1.0]:
		_sil_pine(st, rng, Vector3(cs.x + sx * 13.0, 3.6, -149.5), 1.7, -sx * 0.6, Toon.SUMI, Color("#2B3448"), Color("#5B6070"))
	_kasumi(st, Vector3(cs.x + 4.0, 2.6, -138.0), 80.0, 1.0, Color("#F1E1D6"), Color("#E6CFC4"))
	# petit Fuji d'encre au creux du pont de Mannen, à droite du héros
	var mb := _hp(0.72, 0.0, -100.0)
	_sil_mount(st, Vector3(mb.x, -0.6, -140), 16.0, 9.0, 1.6, 0.06, Color("#2B3448"), Color("#5B6070"), Toon.WASHI, 0.3, 18)
	_sil_bridge(st, Vector3(mb.x, VOID_Y, -100.0), 60.0, 8.4, 1.3, Color("#2E2A28"), Color(0, 0, 0, 0), 6)
	# toits de la ville du château (un ninja sur les faîtes)
	_sil_roofline(st, rng, -74.0, -40.0, -116.0, -0.6, 1.5, Color("#6E6A72"), Color("#2A2830"), Color(0, 0, 0, 0), Toon.SUMI)
	_sil_roofline(st, rng, 34.0, 96.0, -116.0, -0.6, 1.5, Color("#6E6A72"), Color("#2A2830"), Color(0, 0, 0, 0), Toon.SUMI)
	_ridge(st, rng, -70.0, 70.0, -62.0, VOID_Y - 0.3, 1.0, Color("#D9CCB1"), Color("#C9BBA0"), 14)
	for k in (5 if lite else 8):
		var x := rng.randf_range(-40.0, 40.0)
		var pose: float = -1.0 if rng.randf() < 0.5 else 1.0
		_sketch_man(st, Vector3(x, VOID_Y + 0.45, -61.6), rng.randf_range(0.9, 1.2), Color("#2A2830"), pose)
	_flock(st, rng, _hp(0.66, 0.17, -90.0), 7, Vector3(9, 2.5, 4), 1.3, Color("#F6F2EA"))
	for k in (3 if lite else 5):
		var z := rng.randf_range(-95.0, -40.0)
		var face: float = -1.0 if rng.randf() < 0.5 else 1.0
		_sil_boat(st, Vector3(rng.randf_range(-55.0, 55.0), VOID_Y, z), rng.randf_range(0.9, 1.4) * (1.0 - z / 260.0), Color("#1B1A1E"), Color("#F1E8D6"), face)
	_vc_end(st, root)
	# grandes vagues noires
	var w1: Node3D = Decor.great_wave(root, Vector3(-22, VOID_Y, -46), 2.8, 5)
	w1.rotation.y = 0.55
	_ink_wave(w1)
	var w2: Node3D = Decor.great_wave(root, Vector3(30, VOID_Y, -78), 3.8, 6)
	w2.rotation.y = -0.45
	_ink_wave(w2)
	# barques oshiokuri et leurs rameurs, pinceaux plantés comme des mâts, barrique du tonnelier
	var b := {}
	var bn := {}
	_boat_into(b, _at(Vector3(-14, VOID_Y, -28), Vector3(0, 0.3, 0), Vector3.ONE * 1.5), 4)
	_boat_into(b, _at(Vector3(8, VOID_Y, -36), Vector3(0, -0.25, 0), Vector3.ONE * 1.7), 4)
	_boat_into(b, _at(Vector3(-30, VOID_Y, -55), Vector3(0, 0.5, 0), Vector3.ONE * 2.2), 3)
	_brush_into(b, _at(Vector3(-11, VOID_Y, -15), Vector3(0, 0, 0.18), Vector3.ONE * 2.0))
	_brush_into(b, _at(Vector3(11.5, VOID_Y, -17), Vector3(0.1, 0, -0.15), Vector3.ONE * 2.3))
	_barrel_giant_into(b, bn, _at(Vector3(15.5, VOID_Y, -25.0), Vector3(0, -0.25, 0), Vector3.ONE * 1.4))
	_castle_into(b, bn, _at(Vector3(20.5, VOID_Y, -45.0), Vector3(0, -0.35, 0)))
	_flush(b, root, true)
	# feuilles de papier déchiré qui flottent sur l'encre et dans l'air
	var pa := _toon(Color("#F1E8D6"), false)
	var pb := _toon(Color("#E2D6BD"), false)
	for i in 22:
		var p := Vector3.ZERO
		if rng.randf() < 0.65:
			p = Vector3(rng.randf_range(-25.0, 25.0), rng.randf_range(1.0, 14.0), rng.randf_range(-60.0, -14.0))
		else:
			var sx: float = -1.0 if rng.randf() < 0.5 else 1.0
			p = Vector3(sx * rng.randf_range(10.0, 18.0), rng.randf_range(2.0, 8.0), rng.randf_range(-10.0, 4.0))
		if rng.randf() < 0.3:
			p.y = VOID_Y + 0.02
		var rot := Vector3(rng.randf_range(-0.6, 0.6), rng.randf() * TAU, rng.randf_range(-0.6, 0.6))
		if p.y < 0.0:
			rot = Vector3(0, rot.y, 0)
		var pm: StandardMaterial3D = pa if rng.randf() < 0.6 else pb
		_sheet_into(bn, pm, _at(p, rot), rng.randf_range(1.0, 2.6), rng.randf_range(1.2, 3.2))
	_flush(bn, root, false)


## Assombrit une vague de Decor.great_wave (1er enfant = la nappe à couleurs de sommets).
static func _ink_wave(w: Node3D) -> void:
	if w.get_child_count() == 0:
		return
	var sheet: MeshInstance3D = w.get_child(0) as MeshInstance3D
	if sheet == null:
		return
	sheet.material_override = _ink_wave_mat()


## Coulée de lave : ruban sinueux de dalles noires, veines d'or lumineuses dessus.
static func _lava_flow(lava: Dictionary, veins: Dictionary, lm: Material, vm: Material, src: Vector2, dst: Vector2, width: float, rng: RandomNumberGenerator) -> void:
	var n := 10
	var pts: Array[Vector2] = []
	var side := (dst - src).orthogonal().normalized()
	for i in n + 1:
		var t := float(i) / n
		var wob := sin(t * 7.0 + rng.randf() * 0.5) * 1.6 * (1.0 - t * 0.6)
		pts.append(src.lerp(dst, t) + side * wob)
	for i in n:
		var a := pts[i]
		var c := pts[i + 1]
		var d := c - a
		var l := d.length()
		var ang := atan2(d.x, d.y)
		var w := width * lerpf(1.0, 0.75, float(i) / n)
		var mid := (a + c) * 0.5
		_add(lava, lm, Toon.box(Vector3(w, 0.08, l + 0.6)), _at(Vector3(mid.x, VOID_Y + 0.03, mid.y), Vector3(0, ang, 0)))
		for k in 2:
			var off := (k - 0.5) * w * 0.45 + rng.randf_range(-0.2, 0.2)
			var vp := mid + side * off
			_add(veins, vm, Toon.box(Vector3(0.09, 0.02, l * rng.randf_range(0.6, 0.95))),
				_at(Vector3(vp.x, VOID_Y + 0.08, vp.y), Vector3(0, ang + rng.randf_range(-0.25, 0.25), 0)))

# ------------------------------------------------------------------ props autour de l'arène

## Décor de salle autour des zones jouables `rects` (Rect2 : x min, z min, largeur x, profondeur z).
## Grands props hors de l'arène, alignements et petits props au ras des bords (jamais à moins de 0.3
## d'une zone jouable, rien de haut au bas de l'écran), petits props dans les vides entre plateformes,
## tapis d'éléments répétés (MultiMesh). Tout est fusionné : ~1 draw call par matériau.
## `zone` (facultatif, tronçon d'une étape) : les props de bord restent dans cette tranche de z.
## `pieces` (étapes) : pièces de décor posées sur la terre ferme (_set_pieces), dans les mêmes lots.
static func build_props(world_id: int, parent: Node3D, rects: Array, rng_seed: int, zone := Rect2(), max_lights := MAX_LIGHTS, pieces: Array = []) -> void:
	var wid := clampi(world_id, 1, WORLDS.size())
	var rng := _rng(rng_seed * 31 + wid)
	var root := Node3D.new()
	root.name = "Props"
	parent.add_child(root)
	var ctx := {"lights": 0, "root": root, "rects": rects, "taken": [], "avoid": [], "bs": {}, "bn": {}, "mm": {}, "zone": zone, "max_lights": max_lights}
	_reserve_gate(ctx)
	# grands props dans le vide autour de l'arène
	for i in rng.randi_range(13, 17):
		var p := _spot_outer(ctx, rng)
		if p == NONE2:
			continue
		_take(ctx, p)
		_prop_big(wid, ctx, p, rng)
		_contact(ctx, p, 1.5)
	# alignements de bord : clôtures, cordes sacrées, fanions…
	for i in rng.randi_range(2, 4):
		var run := _spot_run(ctx, rng)
		if run.is_empty():
			continue
		_prop_run(wid, ctx, run, rng)
	# petits props de bord, juste à côté d'une plateforme
	for i in rng.randi_range(5, 8):
		var e := _spot_edge(ctx, rng)
		if e == NONE4:
			continue
		_take(ctx, Vector2(e.x, e.y))
		_prop_edge(wid, ctx, e, rng)
		_contact(ctx, Vector2(e.x, e.y), 0.7)
	# petits props dans les vides entre plateformes
	for i in rng.randi_range(3, 7):
		var p := _spot_gap(ctx, rng)
		if p == NONE2:
			continue
		_take(ctx, p)
		_prop_small(wid, ctx, p, rng)
		_contact(ctx, p, 0.8)
	# tapis d'éléments répétés
	_fill(wid, ctx, rng)
	# pièces de décor sur la terre ferme (tirages à part : le décor autour ne change pas)
	if not pieces.is_empty():
		_set_pieces(wid, ctx, pieces, _rng(rng_seed * 13 + 7))
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var mm: Dictionary = ctx["mm"]
	_flush(bs, root, true)
	_flush(bn, root, false)
	_flush_mm(mm, root)


## Garde dégagé l'arrière du torii de sortie (même calcul que arena.gd).
static func _reserve_gate(ctx: Dictionary) -> void:
	var rects: Array = ctx["rects"]
	if rects.is_empty():
		return
	var high: Rect2 = rects[0]
	for r in rects:
		var rr: Rect2 = r
		if rr.position.y < high.position.y or (is_equal_approx(rr.position.y, high.position.y) and absf(rr.get_center().x) < absf(high.get_center().x)):
			high = rr
	var gx := clampf(0.0, high.position.x + 1.2, high.end.x - 1.2)
	var avoid: Array = ctx["avoid"]
	avoid.append(Vector3(gx, high.position.y, 2.3))


## Vrai si `p` est dans la tranche de z du tronçon (toujours vrai pour une salle unique).
static func _in_zone(ctx: Dictionary, p: Vector2) -> bool:
	var zone: Rect2 = ctx.get("zone", Rect2())
	if not zone.has_area():
		return true
	return p.y >= zone.position.y - 0.6 and p.y <= zone.end.y + 0.6


## Ombre de contact douce dans l'eau au pied d'un prop (instances : un seul draw call par salle).
static func _contact(ctx: Dictionary, p: Vector2, r: float) -> void:
	_inst(ctx, "contact_ao", Toon.blob_mesh(), Toon.blob_mat(0.34), _at(Vector3(p.x, PIT_Y + 0.004, p.y), Vector3.ZERO, Vector3(r, 1.0, r)))


static func _take(ctx: Dictionary, p: Vector2) -> void:
	var taken: Array = ctx["taken"]
	taken.append(p)


## Vrai si `p` est hors de toutes les zones jouables (élargies de `margin`), loin des props déjà
## posés (`spacing`, 0 = ignoré) et hors des zones réservées.
static func _ok(ctx: Dictionary, p: Vector2, margin: float, spacing: float) -> bool:
	var rects: Array = ctx["rects"]
	for r in rects:
		var rr: Rect2 = r
		if rr.grow(margin).has_point(p):
			return false
	if spacing > 0.0:
		var taken: Array = ctx["taken"]
		for q in taken:
			var qq: Vector2 = q
			if qq.distance_to(p) < spacing:
				return false
	var avoid: Array = ctx["avoid"]
	for a in avoid:
		var av: Vector3 = a
		if Vector2(av.x, av.y).distance_to(p) < av.z:
			return false
	return true


## Emplacement d'un grand prop : sur les côtés ou au fond, jamais au bas de l'écran.
static func _spot_outer(ctx: Dictionary, rng: RandomNumberGenerator) -> Vector2:
	for attempt in 40:
		var p := Vector2.ZERO
		if rng.randf() < 0.62:
			var sx: float = -1.0 if rng.randf() < 0.5 else 1.0
			p = Vector2(sx * rng.randf_range(5.7, 9.0), rng.randf_range(-12.5, 6.0))
		else:
			p = Vector2(rng.randf_range(-8.5, 8.5), rng.randf_range(-13.8, -10.0))
		if _ok(ctx, p, 1.1, 1.9):
			return p
	return NONE2


## Emplacement d'un petit prop dans un vide intérieur de l'arène.
static func _spot_gap(ctx: Dictionary, rng: RandomNumberGenerator) -> Vector2:
	for attempt in 40:
		var p := Vector2(rng.randf_range(-4.2, 4.2), rng.randf_range(-8.2, 6.8))
		if _ok(ctx, p, 0.9, 1.3):
			return p
	return NONE2


## Emplacement de bord : (x, z, normale sortante x, normale sortante z), à EDGE_OFF du bord ouest,
## est ou nord d'une plateforme (jamais au sud : un prop y masquerait la plateforme vue d'en haut).
static func _spot_edge(ctx: Dictionary, rng: RandomNumberGenerator) -> Vector4:
	var rects: Array = ctx["rects"]
	if rects.is_empty():
		return NONE4
	for attempt in 30:
		var r: Rect2 = rects[rng.randi_range(0, rects.size() - 1)]
		var t := rng.randf_range(0.12, 0.88)
		var n := Vector2.ZERO
		var p := Vector2.ZERO
		var side := rng.randi_range(0, 2)
		if side == 0:
			n = Vector2(-1, 0)
			p = Vector2(r.position.x, lerpf(r.position.y, r.end.y, t))
		elif side == 1:
			n = Vector2(1, 0)
			p = Vector2(r.end.x, lerpf(r.position.y, r.end.y, t))
		else:
			n = Vector2(0, -1)
			p = Vector2(lerpf(r.position.x, r.end.x, t), r.position.y)
		p += n * EDGE_OFF
		if p.y > 6.8 or not _in_zone(ctx, p):
			continue
		if _ok(ctx, p, 0.5, 1.2):
			return Vector4(p.x, p.y, n.x, n.y)
	return NONE4


## Alignement le long d'un bord ouest, est ou nord : [a, b, normale sortante] (Vector2), ou [] si rien.
static func _spot_run(ctx: Dictionary, rng: RandomNumberGenerator) -> Array:
	var rects: Array = ctx["rects"]
	if rects.is_empty():
		return []
	for attempt in 20:
		var r: Rect2 = rects[rng.randi_range(0, rects.size() - 1)]
		var side := rng.randi_range(0, 2)
		var span := rng.randf_range(1.6, 3.2)
		var n := Vector2.ZERO
		var a := Vector2.ZERO
		var b := Vector2.ZERO
		if side < 2:
			var x: float = r.position.x if side == 0 else r.end.x
			n = Vector2(-1, 0) if side == 0 else Vector2(1, 0)
			var z0 := rng.randf_range(r.position.y + 0.2, maxf(r.end.y - span - 0.2, r.position.y + 0.2))
			a = Vector2(x, z0)
			b = Vector2(x, minf(z0 + span, r.end.y - 0.2))
		else:
			n = Vector2(0, -1)
			var x0 := rng.randf_range(r.position.x + 0.2, maxf(r.end.x - span - 0.2, r.position.x + 0.2))
			a = Vector2(x0, r.position.y)
			b = Vector2(minf(x0 + span, r.end.x - 0.2), r.position.y)
		a += n * 0.42
		b += n * 0.42
		if a.distance_to(b) < 1.0 or maxf(a.y, b.y) > 6.8 or not _in_zone(ctx, a) or not _in_zone(ctx, b):
			continue
		var good := true
		var steps := int(ceil(a.distance_to(b) / 0.3))
		for i in steps + 1:
			if not _ok(ctx, a.lerp(b, float(i) / steps), 0.3, 0.7):
				good = false
				break
		if good:
			return [a, b, n]
	return []


## Point au hasard dans le vide autour de l'arène (côtés, fond) ou dans ses trous.
## `reach` : distance max au-delà des bords ; `low` : autorise le bas de l'écran (éléments plats).
static func _ring_pt(ctx: Dictionary, rng: RandomNumberGenerator, margin: float, spacing: float, reach: float, low: bool) -> Vector2:
	var zmax: float = 9.6 if low else 6.5
	for attempt in 12:
		var p := Vector2.ZERO
		var u := rng.randf()
		if u < 0.55:
			var sx: float = -1.0 if rng.randf() < 0.5 else 1.0
			p = Vector2(sx * (4.7 + margin + pow(rng.randf(), 1.4) * reach), rng.randf_range(-14.0, zmax))
		elif u < 0.88:
			p = Vector2(rng.randf_range(-5.0 - reach, 5.0 + reach), -8.7 - margin - pow(rng.randf(), 1.4) * reach)
		else:
			p = Vector2(rng.randf_range(-4.4, 4.4), rng.randf_range(-8.4, minf(8.4, zmax)))
		if p.y > zmax:
			continue
		if _ok(ctx, p, margin, spacing):
			return p
	return NONE2


## Pilier qui sort du vide jusqu'au niveau du sol (support des props de bord).
static func _pillar(ctx: Dictionary, p: Vector2, r: float, color: Color) -> void:
	var bn: Dictionary = ctx["bn"]
	var h := 0.0 - (VOID_Y - 0.35)
	_add(bn, _toon(color, true, 0.02), _cyl(r * 0.9, r, h, 6), _at(Vector3(p.x, -h * 0.5, p.y)))


## Angle (rotation.y) pour que le +Z local regarde le point (tx, tz) depuis p.
static func _face(p: Vector2, tx: float, tz: float) -> float:
	return atan2(tx - p.x, tz - p.y)


static func _light_ok(ctx: Dictionary) -> bool:
	var n: int = ctx["lights"]
	var m: int = ctx.get("max_lights", MAX_LIGHTS)
	return n < m


static func _use_light(ctx: Dictionary) -> void:
	var n: int = ctx["lights"]
	ctx["lights"] = n + 1


## Lumière ponctuelle chaude (dans la limite de MAX_LIGHTS par salle, sans ombre).
static func _light(ctx: Dictionary, pos: Vector3, col: Color, energy: float, reach: float) -> void:
	if not _light_ok(ctx):
		return
	_use_light(ctx)
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = reach
	l.shadow_enabled = false
	var root: Node3D = ctx["root"]
	root.add_child(l)


## Lanterne de pierre (allumée si le budget de lumières le permet et si `lit`).
static func _stone_lantern(ctx: Dictionary, pos: Vector3, s: float, lit: bool) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	Decor.stone_lantern_into(bs, bn, _at(pos, Vector3.ZERO, Vector3.ONE * s))
	if lit:
		_light(ctx, pos + Vector3(0, 0.81 * s, 0), Color(1.0, 0.72, 0.4), 0.6, 3.0 * s)


## Couleurs des fanions nobori du monde : [tissu, encre] (jamais de vermillon vif).
static func _nobori_colors(wid: int) -> Array:
	match wid:
		1:
			return [Color("#2E4A6B"), Toon.WASHI]
		2:
			return [Color("#EFE6D2"), Color("#8E3A2A")]
		3:
			return [Color("#3A3A48"), Color("#E6DCC6")]
		4:
			return [Color("#2A2226"), Toon.GOLD]
		6:
			return [Color("#F1E8D6"), Color("#8E2A1E")]
		7:
			return [Color("#1E4E52"), Toon.GOLD]
		8:
			return [Color("#2A2430"), Color("#C9B8E8")]
		_:
			return [Color("#F1E8D6"), Toon.SUMI]


## Croissants d'écume autour d'un rocher / d'un pieu (instances).
static func _foam_ring(ctx: Dictionary, p: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	var n := rng.randi_range(3, 5)
	var a0 := rng.randf() * TAU
	for k in n:
		var yaw := a0 + TAU * k / n + rng.randf_range(-0.3, 0.3)
		var s := r / 0.5 * rng.randf_range(1.05, 1.3)
		_inst(ctx, "foam", _crescent_mesh(), _flat(Color(Toon.FOAM, 0.5)), _at(Vector3(p.x, VOID_Y + 0.012, p.y), Vector3(0, yaw, 0), Vector3(s, 1, s)))


static func _prop_big(wid: int, ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	match wid:
		1:
			_big_wave(ctx, p, rng)
		2:
			_big_tanabata(ctx, p, rng)
		3:
			_big_contes(ctx, p, rng)
		4:
			_big_fuji(ctx, p, rng)
		6:
			_big_kurama(ctx, p, rng)
		7:
			_big_ryugu(ctx, p, rng)
		8:
			_big_yomi(ctx, p, rng)
		_:
			_big_ink(ctx, p, rng)


static func _fill(wid: int, ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	match wid:
		1:
			_fill_wave(ctx, rng)
		2:
			_fill_tanabata(ctx, rng)
		3:
			_fill_contes(ctx, rng)
		4:
			_fill_fuji(ctx, rng)
		6:
			_fill_kurama(ctx, rng)
		7:
			_fill_ryugu(ctx, rng)
		8:
			_fill_yomi(ctx, rng)
		_:
			_fill_ink(ctx, rng)


# --- pièces de décor sur la terre ferme (étapes)

## Pièces de décor posées DANS les zones jouables des étapes, par monde : [nom, longueur, largeur] (m).
## Ce sont des obstacles (arena.gd les retire du sol praticable : on les contourne, on les survole d'un
## trait) : peu nombreuses, basses (rien qui masque les ennemis), lisibles d'en haut grâce à leur socle.
const SET_PIECES := {
	1: [["bollards", 1.4, 0.8], ["cargo", 1.1, 1.0], ["skiff", 2.2, 0.9]],  # quai : bittes, fret, barque à sec
	2: [["fox_pair", 1.4, 0.8]],  # plus de touffes de bambous au milieu du chemin (on aurait dit qu'elles sortaient du sol)  # îlots de bambous, renards de pierre
	3: [["frozen_pond", 2.2, 1.5], ["frozen_pond", 1.6, 1.2], ["jizo_row", 1.6, 0.8]],  # mares gelées, jizō
	4: [["lava_crack", 2.4, 0.9], ["lava_crack", 1.6, 0.9], ["basalt", 1.1, 1.1]],  # failles de lave, orgues
	5: [["screen", 1.9, 0.8], ["seal", 1.0, 1.0], ["scrolls", 1.4, 0.9]],  # paravents, sceau, rouleaux
	6: [["roots", 1.5, 1.4], ["sacred_rock", 1.3, 1.1], ["posts", 1.6, 0.9]],  # souches de cèdre, rocher sacré, poteaux d'entraînement
	7: [["coral", 1.2, 1.1], ["clams", 1.7, 1.0]],  # coraux, lit de bénitiers
	8: [["graves", 1.8, 0.8], ["lantern_row", 2.2, 0.8]],  # tombes et sotoba, rangée de lanternes
}


static func set_piece_kinds(world_id: int) -> Array:
	var k: Array = SET_PIECES.get(clampi(world_id, 1, WORLDS.size()), [])
	return k


## Pièces de décor (`pieces` : [empreinte Rect2, nom, quart de tour ?, hauteur du socle (facultative, 0 :
## le sol)], coordonnées du parent). L'axe local x suit la longueur (quart de tour : elle suit z). Ombre
## douce et socle cerné d'encre. Le sanctuaire en pose aussi dans l'eau, sur un socle ou en îlot (build_hub).
static func _set_pieces(_wid: int, ctx: Dictionary, pieces: Array, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	for pc in pieces:
		var pa: Array = pc
		var fp: Rect2 = pa[0]
		var kind := String(pa[1])
		var turned := bool(pa[2])
		var py: float = float(pa[3]) if pa.size() > 3 else 0.0
		var c := fp.get_center()
		var ln: float = fp.size.y if turned else fp.size.x
		var wd: float = fp.size.x if turned else fp.size.y
		var yaw: float = PI * 0.5 if turned else 0.0
		var xf := _at(Vector3(c.x, py, c.y), Vector3(0, yaw, 0))
		_inst(ctx, "piece_ao", Toon.blob_mesh(), Toon.blob_mat(0.3), _at(Vector3(c.x, py + 0.016, c.y), Vector3.ZERO, Vector3(fp.size.x * 0.66, 1.0, fp.size.y * 0.66)))
		match kind:
			"bollards":
				_sp_bollards(bs, bn, xf, ln, wd, rng)
			"cargo":
				_sp_cargo(bs, bn, xf, ln, wd, rng)
			"skiff":
				_sp_skiff(bs, bn, xf, ln, wd)
			"grove":
				_sp_grove(bs, bn, xf, ln, wd, rng)
			"fox_pair":
				_sp_fox_pair(bs, bn, xf, ln, wd)
			"frozen_pond":
				_sp_frozen_pond(bs, bn, xf, ln, wd, rng)
			"jizo_row":
				_sp_jizo_row(bs, bn, xf, ln, wd)
			"lava_crack":
				_sp_lava_crack(bs, bn, xf, ln, wd, rng)
			"basalt":
				_sp_basalt(bs, bn, xf, ln, wd, rng)
			"screen":
				_sp_screen(bs, bn, xf, ln, wd)
			"seal":
				_sp_seal(bs, bn, xf, ln, wd)
			"scrolls":
				_sp_scrolls(bs, bn, xf, ln, wd, rng)
			"roots":
				_sp_roots(bs, bn, xf, ln, wd, rng)
			"sacred_rock":
				_sp_sacred_rock(bs, bn, xf, ln, wd, rng)
			"posts":
				_sp_posts(bs, bn, xf, ln, wd, rng)
			"coral":
				_sp_coral(bs, bn, xf, ln, wd, rng)
			"clams":
				_sp_clams(bs, bn, xf, ln, wd, rng)
			"graves":
				_sp_graves(bs, bn, xf, ln, wd, rng)
			"lantern_row":
				_sp_lantern_row(bs, bn, xf, ln, wd)
			_:
				_sp_base(bs, xf, ln, wd, STONE_DARK, 0.3)


## Socle de la pièce : pavé bas cerné d'encre qui couvre toute l'empreinte.
static func _sp_base(bs: Dictionary, xf: Transform3D, ln: float, wd: float, col: Color, h: float) -> void:
	# deux gradins : le liseré d'encre souligne un chanfrein au lieu d'un pavé brut
	var m := _toon(col, true, 0.02)
	var hl := h * 0.6
	_add(bs, m, _box(Vector3(ln - 0.06, hl, wd - 0.06)), xf * _at(Vector3(0, hl * 0.5, 0)))
	_add(bs, m, _box(Vector3(ln - 0.16, h - hl, wd - 0.16)), xf * _at(Vector3(0, hl + (h - hl) * 0.5, 0)))


## Butte basse (mousse, sable, neige) à la taille de l'empreinte, sommet à `h`.
static func _sp_mound(bs: Dictionary, xf: Transform3D, ln: float, wd: float, col: Color, h: float) -> void:
	_add(bs, _toon(col, true, 0.02), _ball(0.5, 1.0, 12, 4), xf * _at(Vector3.ZERO, Vector3.ZERO, Vector3(ln, h * 2.0, wd)))


## Monde 1 : plate-forme d'amarrage, deux ou trois bittes reliées d'un cordage, rouleau de corde.
static func _sp_bollards(bs: Dictionary, bn: Dictionary, xf: Transform3D, ln: float, wd: float, rng: RandomNumberGenerator) -> void:
	_sp_base(bs, xf, ln, wd, Color("#5A4632"), 0.06)
	var seam := _toon(Color("#3A2C20"), false)
	for k in int(ln / 0.32):
		_add(bn, seam, _box(Vector3(0.025, 0.012, wd - 0.12)), xf * _at(Vector3(-ln * 0.5 + 0.2 + float(k) * 0.32, 0.066, 0)))
	var rope := _toon(Decor.KOMO, false)
	var n: int = 2 if ln < 1.3 else 3
	var tops: Array[Vector3] = []
	for k in n:
		var lx := lerpf(-ln * 0.5 + 0.26, ln * 0.5 - 0.26, float(k) / float(n - 1))
		var base: Vector3 = xf * Vector3(lx, 0.06, rng.randf_range(-0.08, 0.08) * wd)
		tops.append(_bitt_into(bs, bn, base, rng.randf_range(0.55, 0.8)))
	for k in tops.size() - 1:
		_rope(bn, rope, tops[k] - Vector3(0, 0.12, 0), tops[k + 1] - Vector3(0, 0.12, 0), 0.12, 0.022)
	_add(bn, rope, Decor.torus(0.08, 0.17, 10, 4), xf * _at(Vector3(rng.randf_range(-0.2, 0.2) * ln, 0.08, wd * 0.26)))


## Monde 1 : fret du quai, caisse cerclée, tonneaux de saké (un sur la caisse).
static func _sp_cargo(bs: Dictionary, bn: Dictionary, xf: Transform3D, ln: float, wd: float, rng: RandomNumberGenerator) -> void:
	_sp_base(bs, xf, ln, wd, Color("#5A4632"), 0.05)
	var crate := _toon(Color("#8A6A44"), true, 0.02)
	var band := _toon(Color("#3A2C20"), false)
	var cx := -ln * 0.5 + 0.34
	_add(bs, crate, _box(Vector3(0.56, 0.5, 0.56)), xf * _at(Vector3(cx, 0.3, 0)))
	_add(bn, band, _box(Vector3(0.58, 0.05, 0.58)), xf * _at(Vector3(cx, 0.42, 0)))
	_add(bn, band, _box(Vector3(0.05, 0.52, 0.58)), xf * _at(Vector3(cx, 0.3, 0)))
	Decor.sake_barrel_into(bs, bn, xf * _at(Vector3(cx, 0.55, 0), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * 0.7))
	Decor.sake_barrel_into(bs, bn, xf * _at(Vector3(ln * 0.5 - 0.3, 0.05, -wd * 0.2), Vector3(0, rng.randf_range(-0.5, 0.5), 0), Vector3.ONE * 0.85))
	Decor.sake_barrel_into(bs, bn, xf * _at(Vector3(ln * 0.5 - 0.32, 0.05, wd * 0.24), Vector3(0, rng.randf_range(-0.5, 0.5), 0), Vector3.ONE * 0.8), Toon.PRUSSIAN)


## Monde 1 : barque tirée au sec sur deux tréteaux, rame posée en travers.
static func _sp_skiff(bs: Dictionary, bn: Dictionary, xf: Transform3D, ln: float, wd: float) -> void:
	_sp_base(bs, xf, ln, wd, Color("#5A4632"), 0.05)
	var trestle := _toon(Decor.PILE, true, 0.02)
	for sx: float in [-1.0, 1.0]:
		_add(bs, trestle, _box(Vector3(0.12, 0.2, wd - 0.16)), xf * _at(Vector3(sx * ln * 0.28, 0.15, 0)))
	var s := Vector3(ln / 4.3, 0.62, (wd - 0.22) / 0.62)
	_boat_into(bs, xf * _at(Vector3(-0.3 * s.x, 0.2, 0), Vector3.ZERO, s), 0)
	_limb(bn, _toon(Color("#2A221C")), Vector3(-ln * 0.32, 0.1, wd * 0.4), Vector3(ln * 0.22, 0.09, wd * 0.3), 0.022, 0.022, 4, xf)


## Monde 2 : bosquet de bambous sur un îlot de mousse, pousses au pied.
static func _sp_grove(bs: Dictionary, bn: Dictionary, xf: Transform3D, ln: float, wd: float, rng: RandomNumberGenerator) -> void:
	_sp_mound(bs, xf, ln, wd, MOSS_K, 0.16)
	var stem := _toon(Decor.BAMBOO, true, 0.016)
	var node_m := _toon(Decor.BAMBOO_NODE, false)
	var leaf := _toon(Decor.BAMBOO_LEAF, false)
	for k in rng.randi_range(5, 7):
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * 0.3
		var base := Vector3(cos(a) * d * ln, 0.08, sin(a) * d * wd)
		var h := rng.randf_range(1.1, 1.6)
		var top := base + Vector3(base.x * 0.25, h, base.z * 0.25)
		_limb(bs, stem, base, top, 0.04, 0.03, 6, xf)
		for q in 2:
			_add(bn, node_m, _cyl(0.05, 0.05, 0.025, 6), xf * _at(base.lerp(top, 0.35 + float(q) * 0.3)))
		for j in 3:
			var yaw := rng.randf() * TAU
			var dir := Vector3(cos(yaw), rng.randf_range(-0.35, 0.2), sin(yaw)).normalized()
			_limb(bn, leaf, top, top + dir * rng.randf_range(0.22, 0.32), 0.03, 0.0, 3, xf)
	var shoot := _toon(Decor.SHOOT, true, 0.02)
	for k in 2:
		var q := Vector3(rng.randf_range(-0.32, 0.32) * ln, 0.1, rng.randf_range(-0.28, 0.28) * wd)
		_limb(bs, shoot, q, q + Vector3(0, 0.18, 0), 0.06, 0.0, 6, xf)


## Monde 2 : deux renards de pierre sur un socle, petite lanterne entre eux.
static func _sp_fox_pair(bs: Dictionary, bn: Dictionary, xf: Transform3D, ln: float, wd: float) -> void:
	_sp_base(bs, xf, ln, wd, STONE_DARK, 0.12)
	for sx: float in [-1.0, 1.0]:
		_kitsune_into(bs, xf * _at(Vector3(sx * (ln * 0.5 - 0.3), 0.12, 0), Vector3(0, -sx * 0.35, 0), Vector3.ONE * 0.62))
	Decor.stone_lantern_into(bs, bn, xf * _at(Vector3(0, 0.12, -wd * 0.1), Vector3.ZERO, Vector3.ONE * 0.55))


## Monde 3 : mare gelée (glace bleutée dans un bourrelet de neige), fissures claires, bosses de neige.
static func _sp_frozen_pond(bs: Dictionary, bn: Dictionary, xf: Transform3D, ln: float, wd: float, rng: RandomNumberGenerator) -> void:
	var snow := _toon(SNOW, true, 0.02)
	_sp_mound(bs, xf, ln, wd, SNOW, 0.06)
	_add(bs, snow, Decor.torus(0.4, 0.5, 16, 4), xf * _at(Vector3(0, 0.06, 0), Vector3.ZERO, Vector3(ln, 0.9, wd)))
	_add(bn, _toon(Color("#6E9CBB"), false), _cyl(0.5, 0.5, 0.01, 18), xf * _at(Vector3(0, 0.062, 0), Vector3.ZERO, Vector3(ln * 0.84, 1.0, wd * 0.84)))
	_add(bn, _toon(Color("#A9CBE0"), false), _cyl(0.5, 0.5, 0.01, 18), xf * _at(Vector3(0, 0.07, 0), Vector3.ZERO, Vector3(ln * 0.7, 1.0, wd * 0.66)))
	var crack := _toon(Color("#E9F4FA"), false)
	for k in 3:
		_add(bn, crack, _box(Vector3(rng.randf_range(0.2, 0.36) * ln, 0.006, 0.022)),
			xf * _at(Vector3(rng.randf_range(-0.18, 0.18) * ln, 0.078, rng.randf_range(-0.14, 0.14) * wd), Vector3(0, rng.randf() * PI, 0)))
	for k in 2:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.12, 0.18)
		_add(bs, snow, _ball(r, r * 1.1, 8, 4), xf * _at(Vector3(cos(a) * ln * 0.46, 0.08, sin(a) * wd * 0.46)))


## Monde 3 : trois jizō enneigés sur un socle de pierre.
static func _sp_jizo_row(bs: Dictionary, bn: Dictionary, xf: Transform3D, ln: float, wd: float) -> void:
	_sp_base(bs, xf, ln, wd, STONE_DARK, 0.1)
	_add(bn, _toon(SNOW, false), _box(Vector3(ln - 0.12, 0.03, wd - 0.12)), xf * _at(Vector3(0, 0.11, 0)))
	for k in 3:
		var lx := lerpf(-ln * 0.5 + 0.3, ln * 0.5 - 0.3, float(k) / 2.0)
		_jizo_into(bs, xf * _at(Vector3(lx, 0.1, 0), Vector3(0, (float(k) - 1.0) * 0.2, 0), Vector3.ONE * 0.85))


## Monde 4 : faille de lave entre deux lèvres de basalte (lueur en zigzag), éclats relevés.
static func _sp_lava_crack(bs: Dictionary, bn: Dictionary, xf: Transform3D, ln: float, wd: float, rng: RandomNumberGenerator) -> void:
	_sp_base(bs, xf, ln, wd, Color("#2A2422"), 0.05)
	var halo := _glow(Color("#9E3412"), 0.6)
	var hot := _glow(Color("#FF7A2E"), 1.8)
	var core := _glow(FLAME_CORE, 2.2)
	var n := 6
	var pts: Array[Vector3] = []
	for k in n + 1:
		var lz := 0.0
		if k > 0 and k < n:
			lz = rng.randf_range(-0.16, 0.16) * wd
		pts.append(Vector3(lerpf(-ln * 0.42, ln * 0.42, float(k) / float(n)), 0.0, lz))
	for k in n:
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[k + 1]
		var d := b - a
		var turn := atan2(-d.z, d.x)  # l'axe x du segment suit la faille
		var l := d.length() + 0.04
		var mid := (a + b) * 0.5
		_add(bn, halo, _box(Vector3(l, 0.01, 0.3)), xf * _at(mid + Vector3(0, 0.052, 0), Vector3(0, turn, 0)))
		_add(bn, hot, _box(Vector3(l, 0.012, 0.14)), xf * _at(mid + Vector3(0, 0.056, 0), Vector3(0, turn, 0)))
		_add(bn, core, _box(Vector3(l * 0.9, 0.014, 0.05)), xf * _at(mid + Vector3(0, 0.06, 0), Vector3(0, turn, 0)))
	var rock := _toon(BASALT, true, 0.02)
	for k in 5:
		var q := Vector3(rng.randf_range(-0.42, 0.42) * ln, 0.05, (0.34 if k % 2 == 0 else -0.34) * wd)
		var h := rng.randf_range(0.12, 0.3)
		_add(bs, rock, _cyl(rng.randf_range(0.07, 0.12), rng.randf_range(0.11, 0.16), h, 6), xf * _at(q + Vector3(0, h * 0.5, 0), Vector3(0, rng.randf() * TAU, 0)))


## Monde 4 : orgues de basalte basses, auréole de braise au pied.
static func _sp_basalt(bs: Dictionary, bn: Dictionary, xf: Transform3D, ln: float, wd: float, rng: RandomNumberGenerator) -> void:
	_add(bn, _glow(Color("#C07A2A"), 0.7), _cyl(0.5, 0.5, 0.01, 14), xf * _at(Vector3(0, 0.008, 0), Vector3.ZERO, Vector3(ln, 1.0, wd)))
	var m := _toon(BASALT, true, 0.025)
	var cap := _toon(Color("#4A4240"), false)
	var s := minf(ln, wd)
	var cols: Array = [[0.0, 0.0, 0.26, 0.95], [0.27, 0.12, 0.19, 0.6], [-0.26, 0.15, 0.18, 0.5], [0.1, -0.27, 0.17, 0.42], [-0.2, -0.22, 0.15, 0.7]]
	for cd in cols:
		var ca: Array = cd
		var q := Vector3(float(ca[0]) * ln, 0.0, float(ca[1]) * wd)
		var r: float = float(ca[2]) * s
		var h: float = float(ca[3]) * rng.randf_range(0.85, 1.1)
		var turn := rng.randf() * TAU
		_add(bs, m, _cyl(r, r * 1.06, h, 6), xf * _at(q + Vector3(0, h * 0.5, 0), Vector3(0, turn, 0)))
		_add(bn, cap, _cyl(r * 0.9, r * 0.9, 0.01, 6), xf * _at(q + Vector3(0, h + 0.006, 0), Vector3(0, turn, 0)))


## Monde 5 : paravent à quatre feuilles (byōbu) sur un socle laqué.
static func _sp_screen(bs: Dictionary, bn: Dictionary, xf: Transform3D, ln: float, wd: float) -> void:
	_sp_base(bs, xf, ln, wd, Color("#2A1F1A"), 0.05)
	_add(bn, _toon(Toon.SUMI, false), _box(Vector3(ln * 0.6, 0.006, 0.05)), xf * _at(Vector3(0, 0.054, wd * 0.3)))
	_byobu_into(bs, xf * _at(Vector3(-0.02 * ln, 0.05, 0.09), Vector3.ZERO, Vector3(ln / 1.95, 1.0, 1.0)))


## Monde 5 : grand sceau de peintre et son empreinte, sur une feuille de washi.
static func _sp_seal(bs: Dictionary, _bn: Dictionary, xf: Transform3D, ln: float, wd: float) -> void:
	_sp_base(bs, xf, ln, wd, Toon.WASHI, 0.03)
	_seal_into(bs, xf * _at(Vector3(-0.2 * ln, 0.03, -0.05 * wd), Vector3.ZERO, Vector3.ONE * 0.8))


## Monde 5 : table basse laquée, rouleaux de papier, pierre à encre et pinceau.
static func _sp_scrolls(bs: Dictionary, bn: Dictionary, xf: Transform3D, ln: float, wd: float, rng: RandomNumberGenerator) -> void:
	_sp_base(bs, xf, ln, wd, Color("#3A2A22"), 0.26)
	var paper := _toon(Toon.WASHI, true, 0.012)
	var rod := _toon(Color("#2A1F1A"), false)
	for k in 3:
		var lz := (float(k) - 1.0) * 0.17 * wd / 0.9
		var l := ln * rng.randf_range(0.42, 0.6)
		var lx := rng.randf_range(-0.12, 0.05) * ln
		_add(bs, paper, _cyl(0.065, 0.065, l, 10), xf * _at(Vector3(lx, 0.33, lz), Vector3(0, 0, PI * 0.5)))
		_add(bn, rod, _cyl(0.035, 0.035, l + 0.08, 6), xf * _at(Vector3(lx, 0.33, lz), Vector3(0, 0, PI * 0.5)))
	_add(bs, _toon(Toon.SUMI, true, 0.012), _box(Vector3(0.24, 0.05, 0.16)), xf * _at(Vector3(ln * 0.34, 0.285, -wd * 0.12)))
	_limb(bn, _toon(Color("#B89B5E"), false), Vector3(ln * 0.22, 0.29, wd * 0.22), Vector3(ln * 0.44, 0.29, wd * 0.12), 0.018, 0.018, 5, xf)


## Monde 6 : souche de cèdre sur la mousse, racines noueuses qui rampent, jeune cèdre à côté.
static func _sp_roots(bs: Dictionary, bn: Dictionary, xf: Transform3D, ln: float, wd: float, rng: RandomNumberGenerator) -> void:
	_sp_mound(bs, xf, ln, wd, MOSS_K, 0.1)
	var bark := _toon(CEDAR_BARK, true, 0.025)
	var r := 0.2 * minf(ln, wd) + 0.08
	var h := rng.randf_range(0.45, 0.65)
	_add(bs, bark, _cyl(r, r * 1.25, h, 9), xf * _at(Vector3(0, h * 0.5, 0)))
	_add(bn, _toon(Color("#B08A5E"), false), _cyl(r * 0.9, r * 0.9, 0.012, 9), xf * _at(Vector3(0, h + 0.006, 0)))
	_add(bn, _toon(Color("#8A6A44"), false), Decor.torus(r * 0.4, r * 0.5, 9, 3), xf * _at(Vector3(0, h + 0.014, 0)))
	for k in 6:
		var a := TAU * float(k) / 6.0 + rng.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(a) * ln, 0.0, sin(a) * wd) * 0.5
		var mid := dir * 0.55 + Vector3(0, 0.16, 0)
		var tip := dir * 0.9 + Vector3(0, 0.03, 0)
		_limb(bs, bark, Vector3(dir.x * 0.25, h * 0.45, dir.z * 0.25), mid, 0.11, 0.08, 6, xf)
		_limb(bs, bark, mid, tip, 0.08, 0.03, 5, xf)
	_sapling_into(bs, xf * _at(Vector3(ln * 0.3, 0.05, -wd * 0.28), Vector3.ZERO, Vector3.ONE * 0.6))


## Monde 6 : rocher sacré moussu ceint d'une shimenawa, shide de papier.
static func _sp_sacred_rock(bs: Dictionary, bn: Dictionary, xf: Transform3D, ln: float, wd: float, rng: RandomNumberGenerator) -> void:
	_sp_mound(bs, xf, ln, wd, MOSS_K, 0.08)
	Decor.rock_into(bs, xf * _at(Vector3(0, 0.04, 0), Vector3.ZERO, Vector3(ln * 0.74, 1.1, wd * 0.74)), rng.randi() % 100000, Color("#6E7A68"))
	var rope := _toon(Decor.STRAW, true, 0.015)
	_add(bs, rope, Decor.torus(0.36, 0.42, 16, 4), xf * _at(Vector3(0, 0.34, 0), Vector3.ZERO, Vector3(ln * 0.86, 1.0, wd * 0.86)))
	var paper := _toon(Decor.SHIDE, false)
	for k in 4:
		var a := PI * 0.25 + PI * 0.5 * float(k)
		var q := Vector3(cos(a) * ln * 0.34, 0.24, sin(a) * wd * 0.34)
		_add(bn, paper, _box(Vector3(0.06, 0.16, 0.012)), xf * _at(q, Vector3(0, -a + PI * 0.5, 0)))


## Monde 6 : aire d'entraînement des tengu (Ushiwakamaru à Kurama) : dalle de pierre, trois poteaux de
## makiwara criblés de kunai, shuriken tombés au sol. Bas : rien qui masque les ennemis.
static func _sp_posts(bs: Dictionary, bn: Dictionary, xf: Transform3D, ln: float, wd: float, rng: RandomNumberGenerator) -> void:
	_sp_base(bs, xf, ln, wd, STONE_DARK, 0.08)
	for k in 3:
		var lx := lerpf(-ln * 0.5 + 0.28, ln * 0.5 - 0.28, float(k) / 2.0)
		var lz: float = (0.12 if k == 1 else -0.08) * wd
		var px := xf * _at(Vector3(lx, 0.08, lz), Vector3(0, rng.randf_range(-0.4, 0.4), 0), Vector3.ONE * (0.72 + 0.08 * float(k % 2)))
		_kunai_post_into(bs, bn, px, rng)
	for k in 2:
		_shuriken_into(bn, xf * _at(Vector3(rng.randf_range(-0.35, 0.35) * ln, 0.086, rng.randf_range(0.2, 0.4) * wd), Vector3(0, rng.randf() * TAU, 0)))


## Monde 7 : coraux sur une butte de sable, coquillages.
static func _sp_coral(bs: Dictionary, bn: Dictionary, xf: Transform3D, ln: float, wd: float, rng: RandomNumberGenerator) -> void:
	_sp_mound(bs, xf, ln, wd, Color("#CDBB95"), 0.1)
	var spots: Array = [Vector3(-0.18, 0.06, -0.12), Vector3(0.2, 0.06, 0.05), Vector3(-0.05, 0.06, 0.24)]
	for k in spots.size():
		var q: Vector3 = spots[k]
		var col: Color = CORAL[(k + rng.randi_range(0, 3)) % CORAL.size()]
		_coral_into(bs, xf * _at(Vector3(q.x * ln, q.y, q.z * wd), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * rng.randf_range(0.6, 0.8)), rng, col)
	var shell := _toon(Color("#E7C9C0"), true, 0.012)
	for k in 3:
		var a := rng.randf() * TAU
		_add(bn, shell, _ball(0.05, 0.05, 6, 3), xf * _at(Vector3(cos(a) * ln * 0.4, 0.06, sin(a) * wd * 0.4)))


## Monde 7 : lit de bénitiers entrouverts (perles lumineuses) sur le sable.
static func _sp_clams(bs: Dictionary, bn: Dictionary, xf: Transform3D, ln: float, wd: float, rng: RandomNumberGenerator) -> void:
	_sp_mound(bs, xf, ln, wd, Color("#CDBB95"), 0.08)
	for sx: float in [-1.0, 1.0]:
		_clam_into(bs, bn, xf * _at(Vector3(sx * ln * 0.25, 0.04, rng.randf_range(-0.06, 0.06)), Vector3(0, rng.randf_range(-0.4, 0.4), 0), Vector3.ONE * 0.7))
	_coral_into(bs, xf * _at(Vector3(0, 0.05, -wd * 0.22), Vector3.ZERO, Vector3.ONE * 0.45), rng, CORAL[rng.randi() % CORAL.size()])


## Monde 8 : deux stèles et une gerbe de sotoba sur un socle de cendre, offrande et bougie.
static func _sp_graves(bs: Dictionary, bn: Dictionary, xf: Transform3D, ln: float, wd: float, rng: RandomNumberGenerator) -> void:
	_sp_base(bs, xf, ln, wd, ASH_DARK, 0.06)
	var stone := _toon(GRAVE, true, 0.025)
	var cap := _toon(ASH, true, 0.02)
	for sx: float in [-1.0, 1.0]:
		_stele_into(bs, stone, cap, xf * _at(Vector3(sx * ln * 0.27, 0.06, -wd * 0.05), Vector3(0, rng.randf_range(-0.12, 0.12), 0), Vector3.ONE * 0.85))
	_sotoba_into(bs, xf * _at(Vector3(0, 0.06, -wd * 0.25), Vector3.ZERO, Vector3.ONE * 0.85), rng)
	_offering_into(bs, bn, xf * _at(Vector3(0, 0.06, wd * 0.22), Vector3.ZERO, Vector3.ONE * 0.8))


## Monde 8 : rangée de trois lanternes de pierre sur des dalles.
static func _sp_lantern_row(bs: Dictionary, bn: Dictionary, xf: Transform3D, ln: float, wd: float) -> void:
	_sp_base(bs, xf, ln, wd, ASH_DARK, 0.04)
	for k in 3:
		var lx := lerpf(-ln * 0.5 + 0.36, ln * 0.5 - 0.36, float(k) / 2.0)
		Decor.stone_lantern_into(bs, bn, xf * _at(Vector3(lx, 0.04, 0), Vector3.ZERO, Vector3.ONE * 0.85))


# --- alignements de bord

static func _prop_run(wid: int, ctx: Dictionary, run: Array, rng: RandomNumberGenerator) -> void:
	var a2: Vector2 = run[0]
	var b2: Vector2 = run[1]
	var n2: Vector2 = run[2]
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var a := Vector3(a2.x, 0.0, a2.y)
	var c := Vector3(b2.x, 0.0, b2.y)
	var roll := rng.randf()
	var kind := "fence"
	if wid == 1:
		if roll < 0.4:
			kind = "rope"
		elif roll < 0.65:
			kind = "nobori"
		elif roll < 0.82:
			kind = "maku"
		else:
			kind = "shime"
	elif wid == 2:
		if roll < 0.45:
			kind = "fence"
		elif roll < 0.65:
			kind = "shime"
		elif roll < 0.82:
			kind = "maku"
		else:
			kind = "nobori"
	elif wid == 3:
		if roll < 0.45:
			kind = "fence"
		elif roll < 0.75:
			kind = "shime"
		else:
			kind = "jizo"
	elif wid == 4:
		if roll < 0.4:
			kind = "chain"
		elif roll < 0.6:
			kind = "shime"
		elif roll < 0.82:
			kind = "maku"
		else:
			kind = "nobori"
	elif wid == 6:
		if roll < 0.35:
			kind = "shime"
		elif roll < 0.58:
			kind = "fence"
		elif roll < 0.8:
			kind = "maku"
		else:
			kind = "nobori"
	elif wid == 7:
		if roll < 0.45:
			kind = "rope"
		elif roll < 0.75:
			kind = "nobori"
		else:
			kind = "shime"
	elif wid == 8:
		if roll < 0.4:
			kind = "chain"
		elif roll < 0.65:
			kind = "shime"
		elif roll < 0.8:
			kind = "maku"
		else:
			kind = "fence"
	else:
		if roll < 0.3:
			kind = "shime"
		elif roll < 0.5:
			kind = "fence"
		elif roll < 0.75:
			kind = "shoji"
		else:
			kind = "nobori"
	if kind == "fence":
		Decor.fence_into(bs, bn, a, c, 0.62, VOID_Y - 0.3, wid == 3)
	elif kind == "rope":
		_rope_rail(ctx, a, c)
	elif kind == "nobori":
		_nobori_line(ctx, a, c, n2, wid)
	elif kind == "shime":
		_shime_run(ctx, a, c)
	elif kind == "chain":
		_chain_rail(ctx, a, c)
	elif kind == "maku":
		_maku_run(ctx, a, c, n2, wid)
	elif kind == "shoji":
		_shoji_run(ctx, a, c)
	else:
		_jizo_ledge(ctx, a, c, n2)
	var steps := maxi(int(a2.distance_to(b2) / 0.7), 1)
	for i in steps + 1:
		_take(ctx, a2.lerp(b2, float(i) / steps))


## Garde-corps de port : pieux et gros cordage qui pend entre eux.
static func _rope_rail(ctx: Dictionary, a: Vector3, c: Vector3) -> void:
	var bs: Dictionary = ctx["bs"]
	var pile := _toon(Decor.PILE, true, 0.02)
	var rope := _toon(Color("#B9A57E"), true, 0.012)
	var n := maxi(int(ceil(a.distance_to(c) / 1.1)), 1)
	var hh := 0.75 - (VOID_Y - 0.3)
	var prev := Vector3.ZERO
	for i in n + 1:
		var q := a.lerp(c, float(i) / n)
		_add(bs, pile, _cyl(0.06, 0.07, hh, 6), _at(Vector3(q.x, VOID_Y - 0.3 + hh * 0.5, q.z)))
		_add(bs, pile, _ball(0.07, 0.08, 6, 3), _at(Vector3(q.x, 0.77, q.z)))
		var top := Vector3(q.x, 0.62, q.z)
		if i > 0:
			_rope(bs, rope, prev, top, 0.16, 0.022)
		prev = top


## Rangée de fanions nobori, bannières tournées vers l'extérieur.
static func _nobori_line(ctx: Dictionary, a: Vector3, c: Vector3, n2: Vector2, wid: int) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var cols := _nobori_colors(wid)
	var cloth: Color = cols[0]
	var ink: Color = cols[1]
	var n := clampi(int(a.distance_to(c) / 1.1) + 1, 2, 4)
	var rot: float = PI if n2.x < -0.5 else 0.0
	for i in n:
		var q := a.lerp(c, float(i) / (n - 1))
		Decor.nobori_into(bs, bn, _at(q, Vector3(0, rot, 0)), cloth, ink, VOID_Y - 0.3, _mon_kind(wid))


## Shimenawa tendue entre deux poteaux de bois sombre.
static func _shime_run(ctx: Dictionary, a: Vector3, c: Vector3) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var post := _toon(Color("#3B2E25"), true, 0.02)
	var hh := 1.15 - (VOID_Y - 0.3)
	for q: Vector3 in [a, c]:
		_add(bs, post, _cyl(0.055, 0.065, hh, 6), _at(Vector3(q.x, VOID_Y - 0.3 + hh * 0.5, q.z)))
		_add(bs, post, _box(Vector3(0.16, 0.05, 0.16)), _at(Vector3(q.x, 1.17, q.z)))
	Decor.shimenawa_into(bs, bn, a + Vector3(0, 1.0, 0), c + Vector3(0, 1.0, 0))


## Rambarde de chaîne entre des poteaux de fer.
static func _chain_rail(ctx: Dictionary, a: Vector3, c: Vector3) -> void:
	var bs: Dictionary = ctx["bs"]
	var iron := _toon(IRON, true, 0.02)
	var n := maxi(int(ceil(a.distance_to(c) / 1.2)), 1)
	var hh := 0.85 - (VOID_Y - 0.3)
	var prev := Vector3.ZERO
	for i in n + 1:
		var q := a.lerp(c, float(i) / n)
		_add(bs, iron, _cyl(0.07, 0.09, hh, 6), _at(Vector3(q.x, VOID_Y - 0.3 + hh * 0.5, q.z)))
		_add(bs, iron, _cyl(0.11, 0.11, 0.06, 6), _at(Vector3(q.x, 0.87, q.z)))
		var top := Vector3(q.x, 0.72, q.z)
		if i > 0:
			_links(bs, iron, prev, top, 0.2)
		prev = top


## Mon du clan d'un monde (Decor.mon_into), sur ses bannières, rideaux et entrepôts.
static func _mon_kind(wid: int) -> int:
	match wid:
		1, 5, 7:
			return 0  # trois tomoe
		3:
			return 1  # deux barres
		2, 8:
			return 2  # losange
		_:
			return 3  # étoile de shuriken (forges du Fuji, tengu de Kurama)


## Jinmaku : rideau de camp tendu entre des perches, rayé d'encre, mon du clan répété face à l'arène.
static func _maku_run(ctx: Dictionary, a: Vector3, c: Vector3, n2: Vector2, wid: int) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var cols := _nobori_colors(wid)
	var cloth: Color = cols[0]
	var ink: Color = cols[1]
	var pole := Decor._toon("pole", Decor.POLE, true, 0.02)
	var cm := Decor._toon("nobori_" + cloth.to_html(false), cloth, true, 0.012)
	var im := Decor._toon("nobori_ink_" + ink.to_html(false), ink, false)
	var d := c - a
	var l := d.length()
	var n := maxi(int(ceil(l / 1.3)), 1)
	var hh := 1.05 - (VOID_Y - 0.3)
	for i in n + 1:
		var q := a.lerp(c, float(i) / n)
		_add(bs, pole, _cyl(0.03, 0.04, hh, 6), _at(Vector3(q.x, VOID_Y - 0.3 + hh * 0.5, q.z)))
		_add(bs, pole, _ball(0.045, 0.09, 6, 3), _at(Vector3(q.x, 1.08, q.z)))
	var mid := (a + c) * 0.5
	var yaw := atan2(d.x, d.z)
	_add(bs, cm, _box(Vector3(0.012, 0.5, l)), _at(Vector3(mid.x, 0.72, mid.z), Vector3(0, yaw, 0)))
	for y: float in [0.52, 0.9]:
		_add(bn, im, _box(Vector3(0.016, 0.06, l + 0.004)), _at(Vector3(mid.x, y, mid.z), Vector3(0, yaw, 0)))
	var inward := atan2(-n2.x, -n2.y)
	var fwd := Vector3(-n2.x, 0, -n2.y) * 0.009
	for i in n:
		var q := a.lerp(c, (float(i) + 0.5) / n)
		Decor.mon_into(bn, im, _at(Vector3(q.x, 0.71, q.z) + fwd, Vector3(0, inward, 0)), 0.15, _mon_kind(wid))


## Rangée de shōji : panneaux de washi à croisillons (kumiko) sur une planche d'engawa, le long du bord.
static func _shoji_run(ctx: Dictionary, a: Vector3, c: Vector3) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var paper := _toon(Toon.WASHI, true, 0.015)
	var frame := _toon(Color("#2A1F1A"), false)
	var deck := _toon(Color("#5B4630"), true, 0.02)
	var post := _toon(Decor.PILE, true, 0.02)
	var d := c - a
	var l := d.length()
	if l < 0.4:
		return
	var yaw := atan2(d.x, d.z)
	var bas := Basis.from_euler(Vector3(0, yaw, 0))
	var along := d / l
	var mid := (a + c) * 0.5
	_add(bs, deck, _box(Vector3(0.36, 0.06, l + 0.2)), _at(Vector3(mid.x, -0.03, mid.z), Vector3(0, yaw, 0)))
	var hh := -0.06 - (VOID_Y - 0.3)
	for q: Vector3 in [a, c]:
		_add(bs, post, _cyl(0.05, 0.06, hh, 6), _at(Vector3(q.x, VOID_Y - 0.3 + hh * 0.5, q.z)))
	var n := maxi(int(round(l / 0.62)), 1)
	var pw := l / n
	for i in n:
		var cp := a + along * pw * (float(i) + 0.5)
		var px := Transform3D(bas, Vector3(cp.x, 0.0, cp.z))
		_add(bs, paper, _box(Vector3(0.02, 0.84, pw - 0.04)), px * _at(Vector3(0, 0.46, 0)))
		_add(bn, frame, _box(Vector3(0.036, 0.04, pw)), px * _at(Vector3(0, 0.9, 0)))
		_add(bn, frame, _box(Vector3(0.036, 0.08, pw)), px * _at(Vector3(0, 0.06, 0)))
		for sz: float in [-1.0, 1.0]:
			_add(bn, frame, _box(Vector3(0.036, 0.86, 0.035)), px * _at(Vector3(0, 0.47, sz * (pw * 0.5 - 0.018))))
		if Toon.lite:
			continue
		for sz: float in [-1.0, 1.0]:
			_add(bn, frame, _box(Vector3(0.03, 0.78, 0.012)), px * _at(Vector3(0, 0.47, sz * pw / 6.0)))
		for y: float in [0.3, 0.5, 0.7]:
			_add(bn, frame, _box(Vector3(0.03, 0.012, pw - 0.04)), px * _at(Vector3(0, y, 0)))


## Rebord de pierre enneigé et rangée de jizō tournés vers l'arène.
static func _jizo_ledge(ctx: Dictionary, a: Vector3, c: Vector3, n2: Vector2) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var stone := _toon(Color("#6E6C72"), true, 0.02)
	var off := Vector3(n2.x, 0, n2.y) * 0.13
	var a2 := a + off
	var c2 := c + off
	var mid := (a2 + c2) * 0.5
	var l := a2.distance_to(c2)
	var yaw := atan2(c2.x - a2.x, c2.z - a2.z)
	var hh := 0.05 - (VOID_Y - 0.3)
	_add(bs, stone, _box(Vector3(0.5, hh, l + 0.4)), _at(Vector3(mid.x, 0.05 - hh * 0.5, mid.z), Vector3(0, yaw, 0)))
	_add(bn, _toon(SNOW, false), _box(Vector3(0.52, 0.05, l + 0.42)), _at(Vector3(mid.x, 0.06, mid.z), Vector3(0, yaw, 0)))
	var face := atan2(-n2.x, -n2.y)
	var n := maxi(int(l / 0.55), 1)
	for i in n + 1:
		var q := a2.lerp(c2, float(i) / n)
		_jizo_into(bs, _at(Vector3(q.x, 0.075, q.z), Vector3(0, face, 0), Vector3.ONE * 0.75))

# --- petits props de bord

static func _prop_edge(wid: int, ctx: Dictionary, e: Vector4, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var p := Vector2(e.x, e.y)
	var out := Vector2(e.z, e.w)
	var pos := Vector3(p.x, 0.0, p.y)
	# regarde vers la plateforme / bras de potence et bannière vers l'extérieur
	var to_arena := _face(p, p.x - out.x, p.y - out.y)
	var arm_out := atan2(-out.y, out.x)
	var flag_rot: float = PI if out.x < -0.5 else 0.0
	var cols := _nobori_colors(wid)
	var cloth: Color = cols[0]
	var ink: Color = cols[1]
	# rare : poteau d'entraînement des ninjas criblé de kunai (pas sous la mer de Ryūgū)
	if wid != 7 and rng.randf() < 0.07:
		_pillar(ctx, p, 0.22, Decor.PILE)
		_kunai_post_into(bs, bn, _at(pos, Vector3(0, to_arena, 0), Vector3.ONE * 0.85), rng)
		return
	var roll := rng.randf()
	match wid:
		1:
			if roll < 0.2:
				Decor.paper_lantern_into(bs, bn, _at(pos, Vector3(0, arm_out, 0)), Toon.WASHI, VOID_Y - 0.35)
			elif roll < 0.34 and _light_ok(ctx):
				_pillar(ctx, p, 0.22, STONE_DARK)
				_stone_lantern(ctx, pos, 0.62, true)
			elif roll < 0.5:
				_pillar(ctx, p, 0.22, Decor.PILE)
				Decor.sake_barrel_into(bs, bn, _at(pos, Vector3(0, to_arena, 0), Vector3.ONE * 0.62))
				if rng.randf() < 0.5:
					Decor.sake_barrel_into(bn, bn, _at(pos + Vector3(0, 0.35, 0), Vector3(0, to_arena + 0.4, 0), Vector3.ONE * 0.5))
			elif roll < 0.64:
				var top := _bitt_into(bs, bn, Vector3(p.x, VOID_Y - 0.3, p.y), 1.75)
				if rng.randf() < 0.6:
					Decor.gull_into(bn, _at(top, Vector3(0, rng.randf() * TAU, 0)))
			elif roll < 0.76:
				_pillar(ctx, p, 0.22, Decor.PILE)
				for k in 3:
					Decor.glass_float_into(bn, _at(pos + Vector3(rng.randf_range(-0.08, 0.08), k * 0.12, rng.randf_range(-0.08, 0.08)), Vector3.ZERO, Vector3.ONE * 0.6), k)
			elif roll < 0.88:
				Decor.nobori_into(bs, bn, _at(pos, Vector3(0, flag_rot, 0)), cloth, ink, VOID_Y - 0.35)
			else:
				_pillar(ctx, p, 0.22, Decor.PILE)
				Decor.hokora_into(bs, bn, _at(pos, Vector3(0, to_arena, 0), Vector3.ONE * 0.72), Color("#B98E52"), Color("#3A3530"))
		2:
			if roll < 0.22:
				_pillar(ctx, p, 0.22, STONE_DARK)
				_tanzaku_into(bn, _at(pos, Vector3.ZERO, Vector3.ONE * 0.8), rng)
			elif roll < 0.42:
				_pillar(ctx, p, 0.22, STONE_DARK)
				_kitsune_into(bs, _at(pos, Vector3(0, to_arena, 0), Vector3.ONE * 0.62))
			elif roll < 0.56 and _light_ok(ctx):
				_pillar(ctx, p, 0.22, STONE_DARK)
				_stone_lantern(ctx, pos, 0.6, true)
			elif roll < 0.72:
				Decor.paper_lantern_into(bs, bn, _at(pos, Vector3(0, arm_out, 0)), Color("#F1E3A6"), VOID_Y - 0.35)
			elif roll < 0.86:
				Decor.nobori_into(bs, bn, _at(pos, Vector3(0, flag_rot, 0)), cloth, ink, VOID_Y - 0.35)
			else:
				_pillar(ctx, p, 0.22, STONE_DARK)
				Decor.hokora_into(bs, bn, _at(pos, Vector3(0, to_arena, 0), Vector3.ONE * 0.72), Color("#7A5A3E"), Color("#2E2C33"))
		3:
			if roll < 0.2:
				Decor.paper_lantern_into(bs, bn, _at(pos, Vector3(0, arm_out, 0)), Toon.WASHI, VOID_Y - 0.35)
				return
			if roll > 0.9:
				# lanternes flottantes au pied du bord, sur l'eau
				for k in 2:
					_toro_into(bn, _at(Vector3(p.x + out.x * 0.15 * k, VOID_Y, p.y + out.y * 0.15 * k - 0.2 * k), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * 0.8))
				return
			_pillar(ctx, p, 0.22, Color("#6E6C72"))
			_add(bn, _toon(SNOW, false), _cyl(0.2, 0.235, 0.05, 8), _at(Vector3(p.x, -0.01, p.y)))
			if roll < 0.38:
				_jizo_into(bs, _at(pos, Vector3(0, to_arena, 0), Vector3.ONE * 0.82))
			elif roll < 0.52:
				_stele_into(bs, _toon(GRAVE, true, 0.02), _toon(SNOW, false), _at(pos, Vector3(0, to_arena, 0.05), Vector3.ONE * 0.62))
			elif roll < 0.64:
				_offering_into(bs, bn, _at(pos, Vector3(0, to_arena, 0)))
			elif roll < 0.76:
				_wagasa_into(bs, _at(pos, Vector3(0, to_arena, 0)), false, BONNET)
			elif _light_ok(ctx):
				_stone_lantern(ctx, pos, 0.6, true)
			else:
				_jizo_into(bs, _at(pos, Vector3(0, to_arena, 0), Vector3.ONE * 0.82))
		4:
			if roll > 0.9:
				Decor.nobori_into(bs, bn, _at(pos, Vector3(0, flag_rot, 0)), cloth, ink, VOID_Y - 0.35)
				return
			_pillar(ctx, p, 0.22, BASALT)
			if roll < 0.28 and _light_ok(ctx):
				_brazier_into(bs, bn, _at(pos, Vector3.ZERO, Vector3.ONE * 0.6))
				_light(ctx, pos + Vector3(0, 0.8, 0), Color(1.0, 0.55, 0.25), 0.55, 3.5)
			elif roll < 0.46:
				_oni_mask_into(bs, bn, _at(pos, Vector3(0, to_arena, 0), Vector3.ONE * 0.7))
			elif roll < 0.58:
				_brazier_into(bs, bn, _at(pos, Vector3.ZERO, Vector3.ONE * 0.55))
			elif roll < 0.7:
				for k in 2:
					Decor.katana_into(bs, _at(pos + Vector3((k - 0.5) * 0.14, 0, 0), Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2)), Vector3.ONE * 0.85))
			elif roll < 0.8:
				_ingots_into(bs, bn, _at(pos, Vector3(0, rng.randf() * TAU, 0)))
			else:
				_yoshida_into(bs, bn, _at(pos, Vector3.ZERO, Vector3.ONE * 0.3))
		6, 7, 8:
			_edge_new(wid, ctx, p, out, rng, to_arena, arm_out, flag_rot, cloth, ink)
		_:
			if roll < 0.25:
				_brush_into(bs, _at(Vector3(p.x, VOID_Y, p.y), Vector3(out.y * 0.15, 0, -out.x * 0.15), Vector3.ONE * 0.45))
			elif roll < 0.45:
				_papers_into(bn, p, rng, 2, VOID_Y + 0.02, 0.2)
			elif roll < 0.6:
				_pillar(ctx, p, 0.22, Color("#3A3530"))
				_seal_into(bs, _at(pos, Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * 0.42))
			elif roll < 0.74:
				_pillar(ctx, p, 0.22, Color("#3A3530"))
				Decor.kadomatsu_into(bs, bn, _at(pos, Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * 0.62))
			elif roll < 0.88:
				Decor.nobori_into(bs, bn, _at(pos, Vector3(0, flag_rot, 0)), cloth, ink, VOID_Y - 0.35)
			else:
				_pillar(ctx, p, 0.22, Color("#3A3530"))
				_kagami_into(bs, _at(pos, Vector3(0, to_arena, 0), Vector3.ONE * 0.8))


# --- petits props dans les vides entre plateformes (bas)

static func _prop_small(wid: int, ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var sd := rng.randi() % 100000
	var roll := rng.randf()
	match wid:
		1:
			if roll < 0.5:
				var s := rng.randf_range(0.45, 0.75)
				Decor.rock_into(bs, _at(Vector3(p.x, VOID_Y, p.y), Vector3.ZERO, Vector3.ONE * s), sd)
				_foam_ring(ctx, p, s * 0.7, rng)
				if rng.randf() < 0.35:
					Decor.gull_into(bn, _at(Vector3(p.x, VOID_Y + 0.33 * s, p.y), Vector3(0, rng.randf() * TAU, 0)))
			elif roll < 0.75:
				for k in rng.randi_range(2, 3):
					Decor.glass_float_into(bn, _at(Vector3(p.x + rng.randf_range(-0.4, 0.4), VOID_Y - 0.06, p.y + rng.randf_range(-0.4, 0.4))), k)
				_foam_ring(ctx, p, 0.4, rng)
			else:
				var top := _bitt_into(bs, bn, Vector3(p.x, VOID_Y - 0.3, p.y), 1.1)
				Decor.gull_into(bn, _at(top, Vector3(0, rng.randf() * TAU, 0)))
				_foam_ring(ctx, p, 0.3, rng)
		2:
			if roll < 0.7:
				Decor.rock_into(bs, _at(Vector3(p.x, VOID_Y, p.y), Vector3.ZERO, Vector3.ONE * rng.randf_range(0.6, 0.8)), sd)
				var top := Vector3(p.x, VOID_Y + 0.22, p.y)
				if rng.randf() < 0.5:
					_tanzaku_into(bn, _at(top, Vector3.ZERO, Vector3.ONE * 0.75), rng)
				else:
					_kitsune_into(bs, _at(top, Vector3(0, _face(p, 0.0, p.y + 3.0), 0), Vector3.ONE * 0.6))
			else:
				var stone := _toon(STONE, true, 0.02)
				for k in 4:
					_add(bs, stone, _cyl(0.3, 0.34, 0.14, 7), _at(Vector3(p.x + (k - 1.5) * 0.45, VOID_Y + 0.03, p.y + rng.randf_range(-0.2, 0.2)), Vector3(0, rng.randf() * TAU, 0)))
				_stone_lantern(ctx, Vector3(p.x, VOID_Y + 0.1, p.y - 0.5), 0.45, false)
		3:
			if roll < 0.35:
				var top := _mound_into(bn, bn, p, rng.randf_range(0.45, 0.7), rng)
				if rng.randf() < 0.5:
					_wagasa_into(bn, _at(Vector3(p.x, top, p.y), Vector3(0, rng.randf() * TAU, 0)), true, Color("#5B6C8F"))
			elif roll < 0.7:
				for k in rng.randi_range(2, 3):
					_toro_into(bn, _at(Vector3(p.x + rng.randf_range(-0.5, 0.5), VOID_Y, p.y + rng.randf_range(-0.5, 0.5)), Vector3(0, rng.randf() * TAU, 0)))
			else:
				var top := _mound_into(bn, bn, p, 0.6, rng)
				_stele_into(bn, _toon(GRAVE, true, 0.02), _toon(SNOW, false), _at(Vector3(p.x, top - 0.04, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * 0.7))
		4:
			if roll < 0.45:
				_spikes_into(bs, bn, p, 0.55, rng)
			elif roll < 0.75:
				_basalt_into(bs, p, 0.3, VOID_Y + 0.3, rng)
				_anvil_into(bs, bn, _at(Vector3(p.x, VOID_Y + 0.3, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * 0.6))
			else:
				_basalt_into(bs, p, 0.3, VOID_Y + 0.25, rng)
				for k in 2:
					Decor.katana_into(bs, _at(Vector3(p.x + (k - 0.5) * 0.2, VOID_Y + 0.25, p.y), Vector3(rng.randf_range(-0.25, 0.25), rng.randf() * TAU, rng.randf_range(-0.25, 0.25)), Vector3.ONE * 0.8))
		6, 7, 8:
			_small_new(wid, ctx, p, rng, sd)
		_:
			if roll < 0.4:
				_papers_into(bn, p, rng, rng.randi_range(2, 3), VOID_Y + 0.02, 0.5)
			elif roll < 0.6:
				_seal_into(bs, _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * 0.6))
			elif roll < 0.8:
				_brush_into(bs, _at(Vector3(p.x, VOID_Y, p.y), Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2)), Vector3.ONE * 0.5))
			else:
				_ink_claw_into(bs, bn, _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, _face(p, 0.0, p.y), 0), Vector3.ONE * 0.45), rng)


# --- monde 1 : port de Kanagawa

static func _big_wave(ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var sd := rng.randi() % 100000
	var roll := rng.randf()
	if roll < 0.22:
		# rocher et son écume, couronné d'un cerisier, d'un pin, d'une lanterne ou de mouettes
		var s := rng.randf_range(1.3, 2.0)
		Decor.rock_into(bs, _at(Vector3(p.x, VOID_Y, p.y), Vector3.ZERO, Vector3.ONE * s), sd)
		_foam_ring(ctx, p, s * 0.72, rng)
		var at := Vector3(p.x, VOID_Y + 0.33 * s, p.y)
		var r2 := rng.randf()
		if r2 < 0.3:
			Decor.sakura_into(bs, bn, _at(at, Vector3.ZERO, Vector3.ONE * rng.randf_range(0.9, 1.3)), sd)
		elif r2 < 0.55:
			Decor.pine_into(bs, _at(at, Vector3.ZERO, Vector3.ONE * rng.randf_range(0.9, 1.2)), sd)
		elif r2 < 0.7 and _light_ok(ctx):
			_stone_lantern(ctx, at, 0.8, true)
		else:
			for k in rng.randi_range(1, 2):
				Decor.gull_into(bn, _at(at + Vector3(rng.randf_range(-0.3, 0.3), -0.05, rng.randf_range(-0.3, 0.3)), Vector3(0, rng.randf() * TAU, 0)))
	elif roll < 0.4:
		_moored_boat(ctx, p, rng)
	elif roll < 0.55:
		_side_pier(ctx, p, rng)
	elif roll < 0.66:
		var s := rng.randf_range(0.85, 1.1)
		var xf := _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, rng.randf_range(-0.3, 0.3), 0), Vector3.ONE * s)
		_port_lantern_into(bs, bn, xf)
		_light(ctx, xf * Vector3(0, 2.46, 0), Color(1.0, 0.78, 0.5), 0.7, 3.5)
		_foam_ring(ctx, p, 0.75 * s, rng)
		if rng.randf() < 0.4:
			Decor.gull_into(bn, xf * _at(Vector3(0.38, 0.8, 0.38), Vector3(0, rng.randf() * TAU, 0)))
	elif roll < 0.77:
		_floating_shrine(ctx, p, rng)
	elif roll < 0.89:
		_piles(ctx, p, rng)
	else:
		Decor.net_rack_into(bs, bn, _at(Vector3(p.x, 0.0, p.y), Vector3(0, rng.randf_range(-0.3, 0.3), 0)), VOID_Y - 0.3)
		for k in rng.randi_range(2, 4):
			Decor.glass_float_into(bn, _at(Vector3(p.x + rng.randf_range(-1.0, 1.0), VOID_Y - 0.06, p.y + rng.randf_range(0.4, 0.9))), k)


## Barque oshiokuri amarrée à un pieu, cargaison, mouette sur la proue.
static func _moored_boat(ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var rot: float = PI * 0.5 if absf(p.x) > 5.0 else 0.0
	rot += rng.randf_range(-0.25, 0.25)
	if rng.randf() < 0.5:
		rot += PI
	var s := rng.randf_range(0.65, 0.8)
	var xf := _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, rot, 0), Vector3.ONE * s)
	_boat_into(bs, xf, rng.randi_range(0, 1))
	Decor.sake_barrel_into(bn, bn, xf * _at(Vector3(0.1, 0.24, 0), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * 0.75))
	_add(bn, _toon(Color("#4A4438"), false), _ball(0.32, 0.22, 8, 3), xf * _at(Vector3(0.9, 0.3, 0)))
	var post := xf * Vector3(-2.0, 0.0, 0.7)
	var top := _bitt_into(bs, bn, Vector3(post.x, VOID_Y - 0.3, post.z), 1.5)
	_rope(bn, _toon(Decor.KOMO, false), xf * Vector3(-1.6, 0.3, 0.15), top - Vector3(0, 0.3, 0), 0.25, 0.018)
	if rng.randf() < 0.6:
		Decor.gull_into(bn, xf * _at(Vector3(2.2, 0.56, 0), Vector3(0, PI * 0.5, 0)))


## Ponton secondaire : tonneaux de saké, flotteurs de verre ou lanterne, mouette.
static func _side_pier(ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var rot: float = 0.0 if absf(p.x) > 5.0 else PI * 0.5
	rot += rng.randf_range(-0.08, 0.08)
	var l := rng.randf_range(2.2, 3.0)
	var xf := _at(Vector3(p.x, 0.0, p.y), Vector3(0, rot, 0))
	Decor.pier_into(bs, xf, 1.3, l, -0.08, VOID_Y - 0.3)
	var labels: Array[Color] = [Color("#2E3446"), Toon.PRUSSIAN, Color("#5B4630")]
	for k in rng.randi_range(2, 4):
		var q := Vector3(rng.randf_range(-0.35, 0.35), -0.08, -l * 0.35 + k * 0.42)
		Decor.sake_barrel_into(bs, bn, xf * _at(q, Vector3(0, rng.randf_range(-0.5, 0.5), 0), Vector3.ONE * 0.8), labels[k % labels.size()])
	if rng.randf() < 0.5:
		for k in 3:
			Decor.glass_float_into(bn, xf * _at(Vector3(rng.randf_range(-0.4, 0.4), -0.08, l * 0.3 + rng.randf_range(-0.2, 0.2))), k)
	else:
		var arm: float = PI if p.x < 0.0 else 0.0
		Decor.paper_lantern_into(bs, bn, xf * _at(Vector3(0.55, -0.08, l * 0.42), Vector3(0, arm, 0)), Toon.WASHI)
	if rng.randf() < 0.4:
		Decor.gull_into(bn, xf * _at(Vector3(-0.68, 0.15, -l * 0.45), Vector3(0, rng.randf() * TAU, 0)))


## Petit sanctuaire flottant : radeau, hokora, torii dans l'eau, deux lanternes.
static func _floating_shrine(ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var xf := _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, _face(p, 0.0, p.y), 0))
	_add(bs, _toon(Decor.PLANK, true, 0.02), _box(Vector3(1.1, 0.14, 0.9)), xf * _at(Vector3(0, 0.05, -0.2)))
	Decor.hokora_into(bs, bn, xf * _at(Vector3(0, 0.12, -0.3), Vector3.ZERO, Vector3.ONE * 0.85), Color("#B98E52"), Color("#3A3530"))
	Decor.torii_into(bs, xf * _at(Vector3(0, 0, 0.75), Vector3.ZERO, Vector3.ONE * 0.24), -0.4)
	for sx: float in [-1.0, 1.0]:
		_toro_into(bn, xf * _at(Vector3(sx * 0.42, 0.12, 0.1), Vector3.ZERO, Vector3.ONE * 0.7))
	_foam_ring(ctx, p, 0.8, rng)


## Pieux d'amarrage en ligne, reliés par une corde, mouettes perchées.
static func _piles(ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var rope := _toon(Decor.KOMO, false)
	var dir := Vector2.from_angle(rng.randf() * TAU)
	var n := rng.randi_range(3, 5)
	var tops: Array[Vector3] = []
	for k in n:
		var q := p + dir * (float(k) - (n - 1) * 0.5) * 0.8
		if not _ok(ctx, q, 0.5, 0.0):
			continue
		var top := _bitt_into(bs, bn, Vector3(q.x, VOID_Y - 0.3, q.y), rng.randf_range(1.2, 1.8))
		tops.append(top - Vector3(0, 0.2, 0))
		if rng.randf() < 0.35:
			Decor.gull_into(bn, _at(top, Vector3(0, rng.randf() * TAU, 0)))
		_foam_ring(ctx, q, 0.22, rng)
	for k in tops.size() - 1:
		_rope(bn, rope, tops[k], tops[k + 1], 0.18, 0.018)


static func _fill_wave(ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var fm := _flat(Color(Toon.FOAM, 0.5))  # écume en lavis (plus de taches blanches franches)
	var cm := _crescent_mesh()
	for i in 46:
		var p := _ring_pt(ctx, rng, 0.35, 0.0, 6.0, true)
		if p == NONE2:
			continue
		var s := rng.randf_range(0.6, 1.5)
		_inst(ctx, "foam", cm, fm, _at(Vector3(p.x, VOID_Y + 0.012, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3(s, 1, s)))
	for i in rng.randi_range(4, 7):
		var p := _ring_pt(ctx, rng, 0.4, 0.8, 4.0, true)
		if p == NONE2:
			continue
		Decor.glass_float_into(bn, _at(Vector3(p.x, VOID_Y - 0.06, p.y), Vector3(0, rng.randf() * TAU, 0)), rng.randi_range(0, 2))
	for i in rng.randi_range(3, 5):
		var p := _ring_pt(ctx, rng, 0.6, 1.2, 4.5, false)
		if p == NONE2:
			continue
		var s := rng.randf_range(0.4, 0.7)
		Decor.rock_into(bs, _at(Vector3(p.x, VOID_Y, p.y), Vector3.ZERO, Vector3.ONE * s), rng.randi() % 100000)
		_foam_ring(ctx, p, s * 0.7, rng)


# --- monde 2 : bambouseraie de Tanabata

static func _big_tanabata(ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var sd := rng.randi() % 100000
	var roll := rng.randf()
	if roll < 0.2:
		var s := rng.randf_range(1.2, 1.6)
		Decor.rock_into(bs, _at(Vector3(p.x, VOID_Y, p.y), Vector3.ZERO, Vector3.ONE * s), sd)
		var at := Vector3(p.x, VOID_Y + 0.33 * s, p.y)
		Decor.bamboo_into(bs, bn, _at(at, Vector3.ZERO, Vector3.ONE * rng.randf_range(1.0, 1.3)), sd)
		if rng.randf() < 0.6:
			_tanzaku_into(bn, _at(at + Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))), rng)
	elif roll < 0.34:
		_fox_shrine(ctx, p, rng)
	elif roll < 0.48:
		_torii_alley(ctx, p, rng)
	elif roll < 0.6:
		var s := rng.randf_range(1.1, 1.4)
		Decor.rock_into(bs, _at(Vector3(p.x, VOID_Y, p.y), Vector3.ZERO, Vector3.ONE * s), sd)
		_stone_lantern(ctx, Vector3(p.x, VOID_Y + 0.33 * s, p.y), 0.85, true)
	elif roll < 0.72 and absf(p.x) > 5.5 and _ok(ctx, p + Vector2(0, 2.0), 1.0, 0.0) and _ok(ctx, p - Vector2(0, 2.0), 1.0, 0.0):
		_vermilion_bridge(ctx, p, rng)
	elif roll < 0.86:
		_sasa(ctx, p, rng)
	else:
		_moss_shrine(ctx, p, rng)


## Deux renards de pierre gardant un hokora, sur un socle qui sort de l'eau.
static func _fox_shrine(ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var xf := _at(Vector3(p.x, 0.0, p.y), Vector3(0, _face(p, 0.0, p.y), 0))
	_add(bs, _toon(STONE_DARK, true, 0.025), _box(Vector3(1.7, 0.9, 1.1)), xf * _at(Vector3(0, -0.3, 0)))
	_add(bs, _toon(STONE, true, 0.025), _box(Vector3(1.5, 0.08, 0.9)), xf * _at(Vector3(0, 0.19, 0)))
	Decor.hokora_into(bs, bn, xf * _at(Vector3(0, 0.23, -0.18), Vector3.ZERO, Vector3.ONE * 0.9), Color("#7A5A3E"), Color("#2E2C33"))
	for sx: float in [-1.0, 1.0]:
		_kitsune_into(bs, xf * _at(Vector3(sx * 0.58, 0.23, 0.15), Vector3(0, -sx * 0.35, 0), Vector3.ONE * 0.72))
	if rng.randf() < 0.5:
		var cols := _nobori_colors(2)
		var cloth: Color = cols[0]
		var ink: Color = cols[1]
		for sx: float in [-1.0, 1.0]:
			var rot: float = PI if sx < 0.0 else 0.0
			Decor.nobori_into(bs, bn, xf * _at(Vector3(sx * 0.95, 0.0, 0.45), Vector3(0, rot, 0)), cloth, ink, VOID_Y - 0.3)


## Allée de petits torii (Fushimi Inari) qui s'enfonce le long de l'arène.
static func _torii_alley(ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var side := absf(p.x) > 5.0
	var dir: Vector2 = Vector2(0, -1) if side else Vector2(1, 0)
	var yaw: float = 0.0 if side else PI * 0.5
	var n := rng.randi_range(3, 5)
	var s := 0.27
	for k in n:
		var q := p + dir * (float(k) - (n - 1) * 0.5) * 0.7
		if not _ok(ctx, q, 1.3, 0.0):
			continue
		Decor.torii_into(bs, _at(Vector3(q.x, VOID_Y, q.y), Vector3(0, yaw, 0), Vector3.ONE * s), -0.6 / s)
	var q0 := p - dir * ((n - 1) * 0.5 * 0.7 + 0.7)
	if _ok(ctx, q0, 0.6, 0.0):
		Decor.rock_into(bs, _at(Vector3(q0.x, VOID_Y, q0.y), Vector3.ZERO, Vector3.ONE * 0.9), rng.randi() % 100000)
		_stone_lantern(ctx, Vector3(q0.x, VOID_Y + 0.3, q0.y), 0.6, false)


## Pont arqué vermillon le long de l'arène, rochers et lanternes à ses pieds.
static func _vermilion_bridge(ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var xf := _at(Vector3(p.x, VOID_Y + 0.25, p.y), Vector3(0, PI * 0.5, 0))
	Decor.arched_bridge_into(bs, xf, 3.4, 0.9, Toon.VERMILION.darkened(0.08), Color("#3B2E25"), -0.6)
	for sx: float in [-1.0, 1.0]:
		var e := xf * Vector3(sx * 1.95, -0.25, 0)
		Decor.rock_into(bs, _at(Vector3(e.x, VOID_Y, e.z), Vector3.ZERO, Vector3.ONE * 0.8), rng.randi() % 100000)
		_stone_lantern(ctx, Vector3(e.x, VOID_Y + 0.26, e.z), 0.5, false)


## Grand bambou de Tanabata : tanzaku, banderoles fukinagashi et kusudama.
static func _sasa(ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var s := rng.randf_range(1.2, 1.5)
	Decor.rock_into(bs, _at(Vector3(p.x, VOID_Y, p.y), Vector3.ZERO, Vector3.ONE * s), rng.randi() % 100000)
	var at := Vector3(p.x, VOID_Y + 0.3 * s, p.y)
	_tanzaku_into(bs, _at(at, Vector3.ZERO, Vector3.ONE * 1.6), rng)
	var top := at + Vector3(0, 2.6, 0)
	for k in 4:
		var a := TAU * k / 4.0 + rng.randf() * 0.5
		var q := top + Vector3(cos(a) * 0.45, -0.3 - k * 0.1, sin(a) * 0.45)
		var col: Color = TANZAKU[rng.randi_range(0, TANZAKU.size() - 1)]
		_add(bn, _toon(col, false), _ball(0.09, 0.16, 7, 3), _at(q))
		for j in 5:
			var c2: Color = TANZAKU[(k + j) % TANZAKU.size()]
			var aj := TAU * j / 5.0
			_add(bn, _toon(c2, false), _box(Vector3(0.035, 0.85, 0.006)), _at(q + Vector3(cos(aj) * 0.06, -0.5, sin(aj) * 0.06), Vector3(0, aj, 0)))


## Îlot de mousse avec hokora, renard et petite lanterne.
static func _moss_shrine(ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var r := rng.randf_range(1.0, 1.3)
	_inst(ctx, "moss", _ball(1.0, 0.5, 10, 4), _toon(Color("#3E5A3A"), true, 0.02), _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3(r, r * 0.8, r)))
	var top := VOID_Y + 0.2 * r - 0.03
	var face := _face(p, 0.0, p.y)
	var fwd := Vector3(sin(face), 0, cos(face))
	Decor.hokora_into(bs, bn, _at(Vector3(p.x, top, p.y) - fwd * 0.2, Vector3(0, face, 0), Vector3.ONE * 0.8), Color("#7A5A3E"), Color("#2E2C33"))
	_kitsune_into(bs, _at(Vector3(p.x, top, p.y) + fwd * 0.45 + Vector3(fwd.z, 0, -fwd.x) * 0.35, Vector3(0, face, 0), Vector3.ONE * 0.55))
	_stone_lantern(ctx, Vector3(p.x, top, p.y) + fwd * 0.45 - Vector3(fwd.z, 0, -fwd.x) * 0.4, 0.45, false)


## Bambouseraie dense (instances) sur des îlots de mousse, roseaux et pas japonais.
static func _fill_tanabata(ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	var stem_a := _toon(Decor.BAMBOO, true, 0.018)
	var stem_b := _toon(Color("#6F8F4C"), true, 0.018)
	var node_m := _toon(Decor.BAMBOO_NODE, false)
	var leaf := _toon_ds(Decor.BAMBOO_LEAF)
	var moss := _toon(Color("#3E5A3A"), true, 0.02)
	var stem_mesh := _cyl(0.05, 0.06, 1.0, 6)
	var node_mesh := _cyl(0.068, 0.068, 0.035, 6)
	var spray := _spray_mesh()
	var clumps := 0
	for i in 40:
		if clumps >= 16:
			break
		var c := _ring_pt(ctx, rng, 0.9, 1.3, 6.5, false)
		if c == NONE2:
			continue
		clumps += 1
		var mr := rng.randf_range(0.7, 1.2)
		_inst(ctx, "moss", _ball(1.0, 0.5, 10, 4), moss, _at(Vector3(c.x, VOID_Y, c.y), Vector3(0, rng.randf() * TAU, 0), Vector3(mr, mr * 0.8, mr)))
		for k in rng.randi_range(3, 7):
			var a := rng.randf() * TAU
			var d := sqrt(rng.randf()) * mr * 0.7
			var base := Vector3(c.x + cos(a) * d, VOID_Y + 0.1, c.y + sin(a) * d)
			if not _ok(ctx, Vector2(base.x, base.z), 0.45, 0.0):
				continue
			var h := rng.randf_range(3.2, 6.5)
			var bas := Basis.from_euler(Vector3(rng.randf_range(-0.06, 0.06), 0, rng.randf_range(-0.06, 0.06)))
			var sxf := Transform3D(bas * Basis.from_scale(Vector3(1, h, 1)), base + bas * Vector3(0, h * 0.5, 0))
			if rng.randf() < 0.6:
				_inst(ctx, "stem_a", stem_mesh, stem_a, sxf)
			else:
				_inst(ctx, "stem_b", stem_mesh, stem_b, sxf)
			var seg := rng.randf_range(0.5, 0.65)
			var t := seg
			while t < h - 0.2:
				_inst(ctx, "node", node_mesh, node_m, Transform3D(bas, base + bas * Vector3(0, t, 0)))
				t += seg
			var ss := rng.randf_range(0.9, 1.4)
			_inst(ctx, "spray", spray, leaf, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * ss), base + bas * Vector3(0, h, 0)))
			if h > 4.2:
				_inst(ctx, "spray", spray, leaf, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * ss * 0.7), base + bas * Vector3(0, h * 0.72, 0)))
	var reed := _toon_ds(Color("#4F6E3E"))
	for i in 34:
		var p := _ring_pt(ctx, rng, 0.35, 0.0, 3.0, false)
		if p == NONE2:
			continue
		var s := rng.randf_range(0.8, 1.6)
		_inst(ctx, "reed", _tuft_mesh(), reed, _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3(s, s * rng.randf_range(0.9, 1.4), s)))
	var stone := _toon(STONE, true, 0.02)
	for i in 14:
		var p := _ring_pt(ctx, rng, 0.4, 0.0, 2.5, true)
		if p == NONE2:
			continue
		_inst(ctx, "step", _cyl(0.3, 0.34, 0.14, 7), stone, _at(Vector3(p.x, VOID_Y + 0.03, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * rng.randf_range(0.7, 1.2)))

# --- monde 3 : temple sous la neige

static func _big_contes(ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var roll := rng.randf()
	var face := _face(p, 0.0, p.y)
	if roll < 0.12 and _ok(ctx, p, 1.6, 0.0):
		# beffroi et sa cloche bonshō
		var top := _mound_into(bs, bn, p, 1.5, rng)
		Decor.bell_tower_into(bs, bn, _at(Vector3(p.x, top - 0.1, p.y), Vector3(0, face, 0), Vector3.ONE * 0.62), true)
		return
	if roll < 0.22:
		# torii enneigé (de profil sur les côtés pour ne pas déborder sur l'arène)
		var top := _mound_into(bs, bn, p, 1.3, rng)
		var yaw: float = PI * 0.5 if absf(p.x) > 5.0 else 0.0
		_snow_torii(bs, bn, _at(Vector3(p.x, top - 0.12, p.y), Vector3(0, yaw, 0), Vector3.ONE * 0.4))
		return
	if roll < 0.32:
		# lanternes flottantes d'Obon parmi les glaçons
		for k in rng.randi_range(4, 6):
			_toro_into(bn, _at(Vector3(p.x + rng.randf_range(-1.0, 1.0), VOID_Y, p.y + rng.randf_range(-1.0, 1.0)), Vector3(0, rng.randf() * TAU, 0)))
		for k in 3:
			var q := p + Vector2(rng.randf_range(-1.2, 1.2), rng.randf_range(-1.2, 1.2))
			_inst(ctx, "floe", _cyl(0.6, 0.62, 0.06, 6), _toon(ICE, false), _at(Vector3(q.x, VOID_Y + 0.02, q.y), Vector3(0, rng.randf() * TAU, 0), Vector3(rng.randf_range(0.6, 1.2), 1, rng.randf_range(0.5, 1.0))))
		return
	var r := rng.randf_range(1.1, 1.6)
	var top := _mound_into(bs, bn, p, r, rng)
	var r2 := rng.randf()
	if r2 < 0.3:
		for k in rng.randi_range(1, 2):
			var q := Vector3(p.x + rng.randf_range(-0.5, 0.5), top - 0.1, p.y + rng.randf_range(-0.5, 0.5))
			_snow_pine_into(bs, _at(q, Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * rng.randf_range(1.0, 1.5)))
	elif r2 < 0.55:
		var gm := _toon(GRAVE, true, 0.02)
		var cap := _toon(SNOW, false)
		for k in rng.randi_range(2, 3):
			var q := Vector3(p.x + (k - 1) * 0.55 + rng.randf_range(-0.1, 0.1), top - 0.12, p.y + rng.randf_range(-0.3, 0.3))
			_stele_into(bs, gm, cap, _at(q, Vector3(rng.randf_range(-0.08, 0.08), face + rng.randf_range(-0.3, 0.3), rng.randf_range(-0.1, 0.1)),
				Vector3.ONE * rng.randf_range(0.8, 1.05)))
		var back := Vector3(-sin(face), 0, -cos(face)) * 0.5
		_sotoba_into(bs, _at(Vector3(p.x, top - 0.12, p.y) + back, Vector3(0, face, 0)), rng)
	elif r2 < 0.75:
		var side := Vector3(cos(face), 0, -sin(face))
		var n := rng.randi_range(2, 4)
		for k in n:
			var q := Vector3(p.x, top - 0.1, p.y) + side * (k - (n - 1) * 0.5) * 0.5
			_jizo_into(bs, _at(q, Vector3(0, face, 0)))
		_offering_into(bs, bn, _at(Vector3(p.x, top - 0.1, p.y) + Vector3(sin(face), 0, cos(face)) * 0.5, Vector3(0, face, 0)))
	elif r2 < 0.87 and _light_ok(ctx):
		_stone_lantern(ctx, Vector3(p.x, top - 0.08, p.y), 0.85, true)
	elif r2 < 0.94:
		var cols: Array[Color] = [BONNET, Color("#5B6C8F"), Toon.WASHI]
		_wagasa_into(bs, _at(Vector3(p.x - 0.3, top - 0.05, p.y), Vector3(0, rng.randf() * TAU, 0)), true, cols[rng.randi_range(0, 2)])
		_wagasa_into(bs, _at(Vector3(p.x + 0.4, top - 0.05, p.y + 0.2), Vector3(0, face, 0)), false, cols[rng.randi_range(0, 2)])
	else:
		for k in 2:
			var a := rng.randf() * TAU
			_mound_into(bs, bn, p + Vector2(cos(a), sin(a)) * r * 0.9, r * 0.55, rng)


static func _fill_contes(ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	var bn: Dictionary = ctx["bn"]
	var lump := _toon(SNOW, false)
	for i in 40:
		var p := _ring_pt(ctx, rng, 0.35, 0.0, 6.0, true)
		if p == NONE2:
			continue
		var s := rng.randf_range(0.4, 1.5)
		if p.y > 6.5:
			s *= 0.6
		_inst(ctx, "lump", _ball(0.5, 0.36, 9, 4), lump, _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3(s, s * rng.randf_range(0.7, 1.1), s * rng.randf_range(0.8, 1.2))))
	var ice := _toon(ICE, false)
	for i in 16:
		var p := _ring_pt(ctx, rng, 0.35, 0.0, 5.0, true)
		if p == NONE2:
			continue
		var s := rng.randf_range(0.6, 1.6)
		_inst(ctx, "floe", _cyl(0.6, 0.62, 0.06, 6), ice, _at(Vector3(p.x, VOID_Y + 0.02, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3(s, 1, s * rng.randf_range(0.6, 1.0))))
	var reed := _toon_ds(Color("#9C9480"))
	for i in 26:
		var p := _ring_pt(ctx, rng, 0.4, 0.0, 3.5, false)
		if p == NONE2:
			continue
		var s := rng.randf_range(0.8, 1.5)
		_inst(ctx, "reed", _tuft_mesh(), reed, _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3(s, s * 1.3, s)))
	for i in rng.randi_range(6, 10):
		var p := _ring_pt(ctx, rng, 0.4, 0.0, 4.0, true)
		if p == NONE2:
			continue
		_toro_into(bn, _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, rng.randf() * TAU, 0)))


# --- monde 4 : forges du Fuji rouge

static func _big_fuji(ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var roll := rng.randf()
	if roll < 0.16:
		_spikes_into(bs, bn, p, rng.randf_range(0.9, 1.3), rng)
	elif roll < 0.29:
		_basalt_into(bs, p, 0.5, 0.05, rng)
		var s := rng.randf_range(0.9, 1.1)
		_brazier_into(bs, bn, _at(Vector3(p.x, 0.05, p.y), Vector3.ZERO, Vector3.ONE * s))
		_light(ctx, Vector3(p.x, 0.05 + 1.3 * s, p.y), Color(1.0, 0.55, 0.25), 0.55, 3.5)
	elif roll < 0.4:
		_basalt_into(bs, p, 0.5, -0.05, rng)
		_anvil_into(bs, bn, _at(Vector3(p.x, -0.05, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * rng.randf_range(0.9, 1.1)))
		_ingots_into(bs, bn, _at(Vector3(p.x + 0.75, VOID_Y + 0.05, p.y + 0.3), Vector3(0, rng.randf() * TAU, 0)))
	elif roll < 0.49:
		_chain_into(bs, p, rng)
	elif roll < 0.58:
		_basalt_into(bs, p, 0.45, -0.1, rng)
		_oni_mask_into(bs, bn, _at(Vector3(p.x, -0.1, p.y), Vector3(0, _face(p, 0.0, p.y), 0), Vector3.ONE * rng.randf_range(1.0, 1.2)))
	elif roll < 0.7 and _ok(ctx, p, 1.9, 0.0):
		var xf := _at(Vector3(p.x, 0.0, p.y), Vector3(0, rng.randf_range(-0.25, 0.25), 0), Vector3.ONE * 0.8)
		_forge_into(bs, bn, xf)
		_light(ctx, xf * Vector3(-0.35, 0.5, 0.5), Color(1.0, 0.5, 0.2), 0.7, 3.5)
	elif roll < 0.84:
		_katanas(ctx, p, rng)
	else:
		_basalt_into(bs, p, 0.55, VOID_Y + 0.3, rng)
		_yoshida_into(bs, bn, _at(Vector3(p.x, VOID_Y + 0.25, p.y), Vector3.ZERO, Vector3.ONE * 0.55))
		_light(ctx, Vector3(p.x, VOID_Y + 2.6, p.y), Color(1.0, 0.55, 0.25), 0.6, 4.0)


## Cimetière de katanas plantés dans une butte de basalte, auréole de braise.
static func _katanas(ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	_basalt_into(bs, p, 0.45, VOID_Y + 0.35, rng)
	for k in rng.randi_range(5, 8):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.0, 0.85)
		var y: float = VOID_Y + 0.35 if d < 0.45 else VOID_Y + 0.02
		var tilt := Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
		Decor.katana_into(bs, _at(Vector3(p.x + cos(a) * d, y, p.y + sin(a) * d), tilt, Vector3.ONE * rng.randf_range(0.8, 1.05)))
	_add(bn, _glow(Color("#C07A2A"), 0.8), _cyl(1.1, 1.1, 0.02, 12), _at(Vector3(p.x, VOID_Y + 0.01, p.y)))


static func _fill_fuji(ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	var bm := _toon(BASALT, true, 0.025)
	var chunk := _ball(0.5, 0.55, 6, 3)
	for i in 42:
		var p := _ring_pt(ctx, rng, 0.4, 0.0, 6.0, true)
		if p == NONE2:
			continue
		var s := rng.randf_range(0.25, 0.8)
		if p.y > 6.5:
			s *= 0.5
		_inst(ctx, "chunk", chunk, bm, _at(Vector3(p.x, VOID_Y - 0.05, p.y), Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4)), Vector3.ONE * s))
	var gm := _glow(LAVA_GOLD, 1.2)
	for i in 26:
		var p := _ring_pt(ctx, rng, 0.35, 0.0, 6.0, true)
		if p == NONE2:
			continue
		_inst(ctx, "crack", _box(Vector3(1.0, 0.02, 0.06)), gm, _at(Vector3(p.x, VOID_Y + 0.01, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3(rng.randf_range(0.4, 1.4), 1, 1)))
	var pool := _glow(Color("#C07A2A"), 0.8)
	for i in 6:
		var p := _ring_pt(ctx, rng, 0.6, 0.0, 5.0, false)
		if p == NONE2:
			continue
		var s := rng.randf_range(0.6, 1.3)
		_inst(ctx, "pool", _cyl(0.6, 0.6, 0.02, 10), pool, _at(Vector3(p.x, VOID_Y + 0.005, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3(s, 1, s * rng.randf_range(0.6, 1.0))))


# --- monde 5 : mer d'encre et Trente-six vues

static func _big_ink(ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var face := _face(p, 0.0, p.y)
	var roll := rng.randf()
	if roll < 0.18:
		# barque dans le sens de la longueur de l'arène (côtés) ou de sa largeur (fond)
		var rot: float = PI * 0.5 if absf(p.x) > 5.0 else 0.0
		_boat_into(bs, _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, rot + rng.randf_range(-0.2, 0.2), 0), Vector3.ONE * rng.randf_range(0.6, 0.8)), rng.randi_range(0, 2))
	elif roll < 0.31:
		_brush_into(bs, _at(Vector3(p.x, VOID_Y, p.y), Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25)), Vector3.ONE * rng.randf_range(0.8, 1.2)))
	elif roll < 0.4:
		_papers_into(bn, p, rng, 2, VOID_Y + 0.02, 0.4)
		_seal_into(bs, _at(Vector3(p.x, VOID_Y + 0.03, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * rng.randf_range(0.9, 1.2)))
	elif roll < 0.48:
		_papers_into(bn, p, rng, rng.randi_range(3, 5), VOID_Y + 0.02, 1.0)
	elif roll < 0.6:
		# porte du Nouvel An : deux kadomatsu et une shimenawa sur un radeau
		var xf := _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, face, 0))
		_add(bs, _toon(Color("#5B4630"), true, 0.02), _box(Vector3(1.9, 0.2, 0.9)), xf * _at(Vector3(0, 0.05, 0)))
		_sheet_into(bn, _toon(Toon.WASHI, false), xf * _at(Vector3(0, 0.16, 0)), 1.6, 0.7)
		for sx: float in [-1.0, 1.0]:
			Decor.kadomatsu_into(bs, bn, xf * _at(Vector3(sx * 0.62, 0.15, 0), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * 0.8))
		Decor.shimenawa_into(bs, bn, xf * Vector3(-0.62, 1.05, 0.0), xf * Vector3(0.62, 1.05, 0.0))
	elif roll < 0.7 and _ok(ctx, p, 1.6, 0.0):
		_barrel_giant_into(bs, bn, _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, rng.randf_range(-0.3, 0.3), 0), Vector3.ONE * 0.7))
	elif roll < 0.84:
		_ink_claw_into(bs, bn, _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, face, 0), Vector3.ONE * rng.randf_range(0.8, 1.1)), rng)
	elif roll < 0.92:
		var xf := _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, rng.randf_range(-0.3, 0.3), 0))
		_add(bs, _toon(Color("#5B4630"), true, 0.02), _box(Vector3(1.8, 0.2, 0.7)), xf * _at(Vector3(0, 0.05, 0)))
		_byobu_into(bs, xf * _at(Vector3(0, 0.15, 0), Vector3.ZERO, Vector3.ONE * 0.9))
	else:
		var xf := _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, face, 0))
		_add(bs, _toon(Color("#5B4630"), true, 0.02), _box(Vector3(0.9, 0.2, 0.9)), xf * _at(Vector3(0, 0.05, 0)))
		_kagami_into(bs, xf * _at(Vector3(0, 0.15, 0), Vector3.ZERO, Vector3.ONE * 1.2))
		_papers_into(bn, p, rng, 2, VOID_Y + 0.02, 0.9)


static func _fill_ink(ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	var pa := _toon(Color("#F1E8D6"), false)
	var pb := _toon(Color("#E2D6BD"), false)
	var sheet := _box(Vector3(0.4, 0.008, 0.3))
	for i in 40:
		var p := _ring_pt(ctx, rng, 0.35, 0.0, 6.0, true)
		if p == NONE2:
			continue
		var xf := _at(Vector3(p.x, VOID_Y + 0.012, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3(rng.randf_range(0.6, 2.0), 1, rng.randf_range(0.6, 1.8)))
		if rng.randf() < 0.6:
			_inst(ctx, "paper_a", sheet, pa, xf)
		else:
			_inst(ctx, "paper_b", sheet, pb, xf)
	var fm := _flat(Toon.FOAM)
	for i in 22:
		var p := _ring_pt(ctx, rng, 0.35, 0.0, 6.0, true)
		if p == NONE2:
			continue
		var s := rng.randf_range(0.6, 1.4)
		_inst(ctx, "foam", _crescent_mesh(), fm, _at(Vector3(p.x, VOID_Y + 0.012, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3(s, 1, s)))

# ------------------------------------------------------------------ modèles (ajoutés aux lots, placés par `xf`)

## Statue de renard (kitsune) assise sur son socle, foulard vermillon ; regarde vers +Z local.
static func _kitsune_into(b: Dictionary, xf: Transform3D) -> void:
	var stone := _toon(STONE, true, 0.025)
	var dark := _toon(STONE_DARK, true, 0.025)
	var bib := _toon(Toon.VERMILION.darkened(0.12), true, 0.015)
	var eye := _toon(Toon.GOLD, false)
	_add(b, dark, _box(Vector3(0.55, 0.22, 0.75)), xf * _at(Vector3(0, 0.11, 0)))
	_add(b, stone, _ball(0.24, 0.3, 8, 4), xf * _at(Vector3(0, 0.35, -0.08)))
	_add(b, stone, _ball(0.18, 0.6, 8, 5), xf * _at(Vector3(0, 0.55, -0.02), Vector3(-0.25, 0, 0)))
	for sx: float in [-1.0, 1.0]:
		_limb(b, stone, Vector3(sx * 0.08, 0.22, 0.14), Vector3(sx * 0.07, 0.62, 0.06), 0.04, 0.035, 5, xf)
	_add(b, stone, _ball(0.13, 0.24, 8, 4), xf * _at(Vector3(0, 0.86, 0.04)))
	_limb(b, stone, Vector3(0, 0.84, 0.1), Vector3(0, 0.8, 0.31), 0.07, 0.01, 5, xf)
	for sx: float in [-1.0, 1.0]:
		_limb(b, stone, Vector3(sx * 0.07, 0.94, 0.02), Vector3(sx * 0.1, 1.13, 0.0), 0.045, 0.0, 4, xf)
		_add(b, eye, _ball(0.018, 0.03, 5, 3), xf * _at(Vector3(sx * 0.055, 0.89, 0.15)))
	_limb(b, stone, Vector3(0, 0.3, -0.25), Vector3(0.05, 0.6, -0.42), 0.07, 0.09, 6, xf)
	_limb(b, stone, Vector3(0.05, 0.6, -0.42), Vector3(0.02, 0.95, -0.32), 0.09, 0.02, 6, xf)
	_add(b, bib, _cyl(0.13, 0.17, 0.1, 8), xf * _at(Vector3(0, 0.72, 0.04), Vector3(0.3, 0, 0)))
	_add(b, bib, _box(Vector3(0.18, 0.15, 0.02)), xf * _at(Vector3(0, 0.63, 0.16), Vector3(0.25, 0, 0)))


## Bambou de Tanabata : tige, panache de feuilles, rameaux et bandes tanzaku colorées.
static func _tanzaku_into(b: Dictionary, xf: Transform3D, rng: RandomNumberGenerator) -> void:
	var x2 := xf * _at(Vector3.ZERO, Vector3(0, rng.randf() * TAU, 0))
	var stem := _toon(Decor.BAMBOO, true, 0.015)
	var node_m := _toon(Decor.BAMBOO_NODE, false)
	var leaf := _toon(Decor.BAMBOO_LEAF, false)
	var h := rng.randf_range(1.7, 2.2)
	var top := Vector3(rng.randf_range(-0.08, 0.08), h, rng.randf_range(-0.08, 0.08))
	_limb(b, stem, Vector3.ZERO, top, 0.035, 0.025, 6, x2)
	for k in 4:
		_add(b, node_m, _cyl(0.042, 0.042, 0.025, 6), x2 * _at(top * (0.2 + k * 0.22)))
	for k in 6:
		var yaw := TAU * k / 6.0 + rng.randf_range(-0.3, 0.3)
		var d := Vector3(cos(yaw), rng.randf_range(-0.5, 0.1), sin(yaw)).normalized()
		_limb(b, leaf, top, top + d * rng.randf_range(0.25, 0.4), 0.03, 0.0, 3, x2)
	for k in 2:
		var yaw := rng.randf() * TAU + k * PI
		var a := top * (0.62 + k * 0.16)
		var c := a + Vector3(cos(yaw) * 0.45, -0.05, sin(yaw) * 0.45)
		_limb(b, stem, a, c, 0.014, 0.008, 4, x2)
		for j in 3:
			var q := a.lerp(c, 0.3 + j * 0.3)
			var col: Color = TANZAKU[rng.randi_range(0, TANZAKU.size() - 1)]
			_add(b, _toon(col, false), _box(Vector3(0.07, 0.24, 0.006)),
				x2 * _at(q - Vector3(0, 0.13, 0), Vector3(rng.randf_range(-0.1, 0.1), yaw + rng.randf_range(-0.4, 0.4), 0)))


## Congère / îlot de neige (ellipsoïde + bosses, liseré lavande au ras du vide). Renvoie la hauteur du sommet.
static func _mound_into(b: Dictionary, bn: Dictionary, p: Vector2, r: float, rng: RandomNumberGenerator) -> float:
	var snow := _toon(SNOW, true, 0.02)
	var shade := _toon(SNOW_SHADE, false)
	var sz := rng.randf_range(0.8, 1.15)
	_add(b, snow, _ball(r, r * 0.7, 12, 5), _at(Vector3(p.x, VOID_Y, p.y), Vector3.ZERO, Vector3(1, 1, sz)))
	for k in rng.randi_range(1, 2):
		var a := rng.randf() * TAU
		var rr := r * rng.randf_range(0.35, 0.55)
		_add(b, snow, _ball(rr, rr * 0.8, 9, 4), _at(Vector3(p.x + cos(a) * r * 0.8, VOID_Y, p.y + sin(a) * r * 0.8 * sz)))
	_add(bn, shade, _cyl(r * 1.05, r * 1.1, 0.05, 14), _at(Vector3(p.x, VOID_Y + 0.02, p.y), Vector3.ZERO, Vector3(1, 1, sz)))
	return VOID_Y + r * 0.35


## Stèle (haka) : deux gradins, fût, calotte de neige.
static func _stele_into(b: Dictionary, stone: Material, cap: Material, xf: Transform3D) -> void:
	_add(b, stone, _box(Vector3(0.62, 0.14, 0.5)), xf * _at(Vector3(0, 0.07, 0)))
	_add(b, stone, _box(Vector3(0.46, 0.14, 0.38)), xf * _at(Vector3(0, 0.21, 0)))
	_add(b, stone, _box(Vector3(0.3, 0.86, 0.26)), xf * _at(Vector3(0, 0.71, 0)))
	_add(b, cap, _box(Vector3(0.33, 0.06, 0.29)), xf * _at(Vector3(0, 1.16, 0)))
	_add(b, cap, _box(Vector3(0.6, 0.03, 0.12)), xf * _at(Vector3(0, 0.155, 0.18)))


## Jizō : corps de pierre, bonnet et bavoir sombres (jamais vermillon), neige sur le bonnet.
static func _jizo_into(b: Dictionary, xf: Transform3D) -> void:
	var stone := _toon(Color("#9A978F"), true, 0.02)
	var head := _toon(Color("#A7A49C"), true, 0.02)
	var cloth := _toon(BONNET, true, 0.02)
	var snow := _toon(SNOW, false)
	_add(b, stone, _cyl(0.2, 0.23, 0.1, 8), xf * _at(Vector3(0, 0.05, 0)))
	_add(b, stone, Toon.capsule(0.15, 0.55), xf * _at(Vector3(0, 0.36, 0)))
	_add(b, cloth, _cyl(0.12, 0.19, 0.16, 8), xf * _at(Vector3(0, 0.52, 0.01)))
	_add(b, head, _ball(0.12, 0.23, 8, 4), xf * _at(Vector3(0, 0.71, 0)))
	_add(b, cloth, _ball(0.13, 0.14, 8, 4), xf * _at(Vector3(0, 0.78, -0.01)))
	_add(b, snow, _ball(0.09, 0.06, 7, 3), xf * _at(Vector3(0, 0.84, -0.01)))


## Pin enneigé : tronc, trois étages coniques, chapeaux de neige.
static func _snow_pine_into(b: Dictionary, xf: Transform3D) -> void:
	var trunk := _toon(Decor.BARK_PINE, true, 0.025)
	var green := _toon(Decor.PINE_B, true, 0.025)
	var snow := _toon(SNOW, false)
	_add(b, trunk, _cyl(0.08, 0.12, 0.8, 6), xf * _at(Vector3(0, 0.4, 0)))
	var radii := PackedFloat32Array([0.9, 0.7, 0.5])
	var hs := PackedFloat32Array([0.9, 0.8, 0.7])
	var y := 0.5
	for k in 3:
		var r := radii[k]
		var h := hs[k]
		var yc := y + h * 0.5
		_add(b, green, _cyl(0.0, r, h, 7), xf * _at(Vector3(0, yc, 0), Vector3(0, k * 0.4, 0)))
		var hsn := h * 0.55
		_add(b, snow, _cyl(0.0, r * 0.62, hsn, 7), xf * _at(Vector3(0, yc + h * 0.5 + 0.02 - hsn * 0.5, 0), Vector3(0, k * 0.4, 0)))
		y += h * 0.55


## Lanterne flottante d'Obon : socle de bois, cube de papier lumineux dans un cadre (montants d'angle,
## traverse médiane : quatre fenêtres de papier par face), couvercle.
static func _toro_into(b: Dictionary, xf: Transform3D) -> void:
	var wood := _toon(Color("#3B2E25"), false)
	_add(b, wood, _box(Vector3(0.36, 0.06, 0.36)), xf * _at(Vector3(0, 0.03, 0)))
	_add(b, _glow(Color("#FBE3B0"), 0.9), _box(Vector3(0.26, 0.3, 0.26)), xf * _at(Vector3(0, 0.21, 0)))
	for k in 4:
		var cx: float = 0.13 if k % 2 == 0 else -0.13
		var cz: float = 0.13 if k < 2 else -0.13
		_add(b, wood, _box(Vector3(0.035, 0.3, 0.035)), xf * _at(Vector3(cx, 0.21, cz)))
	_add(b, wood, _box(Vector3(0.275, 0.025, 0.275)), xf * _at(Vector3(0, 0.21, 0)))
	_add(b, wood, _box(Vector3(0.3, 0.03, 0.3)), xf * _at(Vector3(0, 0.375, 0)))


## Pagode à trois toits enneigés (bois sombre, murs crème), flèche sōrin.
static func _pagoda_into(b: Dictionary, xf: Transform3D) -> void:
	var base_m := _toon(Color("#7E7B80"))
	var wall := _toon(Color("#E6DCC6"))
	var wood := _toon(Color("#4A3428"))
	var roof := _toon(Color("#2E2C33"))
	var snow := _toon(SNOW, false)
	var spire := _toon(Color("#5A4A3A"), true, 0.02)
	_add(b, base_m, _box(Vector3(3.2, 0.4, 3.2)), xf * _at(Vector3(0, 0.2, 0)))
	var y := 0.4
	for k in 3:
		var w := 2.2 - k * 0.45
		var h := 1.1 - k * 0.1
		_add(b, wall, _box(Vector3(w, h, w)), xf * _at(Vector3(0, y + h * 0.5, 0)))
		for c in 4:
			var cx: float = (w * 0.5 - 0.05) * (1.0 if c % 2 == 0 else -1.0)
			var cz: float = (w * 0.5 - 0.05) * (1.0 if c < 2 else -1.0)
			_add(b, wood, _box(Vector3(0.13, h, 0.13)), xf * _at(Vector3(cx, y + h * 0.5, cz)))
		y += h
		# toit incurvé (hōgyō) aux coins relevés, neige posée dessus (même profil, un peu plus petit)
		var rw := w + 1.2
		_add(b, roof, Decor.roof_mesh(rw, rw, 0.5, 0.0, 0.4, 0.07), xf * _at(Vector3(0, y, 0)))
		_add(b, snow, Decor.roof_mesh(rw * 0.9, rw * 0.9, 0.47, 0.0, 0.4, 0.04), xf * _at(Vector3(0, y + 0.07, 0)))
		y += 0.3
	_add(b, spire, _cyl(0.05, 0.07, 1.6, 6), xf * _at(Vector3(0, y + 0.95, 0)))
	for k in 5:
		_add(b, spire, _cyl(0.14, 0.14, 0.04, 8), xf * _at(Vector3(0, y + 0.45 + k * 0.22, 0)))
	_add(b, spire, _ball(0.1, 0.2, 8, 4), xf * _at(Vector3(0, y + 1.8, 0)))


## Torii enneigé : neige sur le kasagi, le nuki et les socles.
static func _snow_torii(b: Dictionary, bn: Dictionary, xf: Transform3D) -> void:
	Decor.torii_into(b, xf, 0.0)
	var snow := _toon(SNOW, false)
	_add(bn, snow, _box(Vector3(4.4, 0.12, 0.52)), xf * _at(Vector3(0, 3.47, 0)))
	_add(bn, snow, _box(Vector3(5.7, 0.07, 0.18)), xf * _at(Vector3(0, 2.585, 0)))
	for sx: float in [-1.0, 1.0]:
		_add(bn, snow, _cyl(0.22, 0.26, 0.08, 10), xf * _at(Vector3(sx * 2.2, 0.44, 0)))


## Sotoba : planchettes de bois clair à inscriptions d'encre, plantées derrière les tombes.
static func _sotoba_into(b: Dictionary, xf: Transform3D, rng: RandomNumberGenerator) -> void:
	var wood := _toon(Toon.WOOD, true, 0.012)
	var ink := _toon(Toon.SUMI, false)
	var n := rng.randi_range(4, 6)
	for k in n:
		var h := rng.randf_range(1.1, 1.45)
		var px := xf * _at(Vector3((float(k) - (n - 1) * 0.5) * 0.13, 0, 0), Vector3(rng.randf_range(-0.12, -0.04), 0, rng.randf_range(-0.05, 0.05)))
		_add(b, wood, _box(Vector3(0.1, h, 0.02)), px * _at(Vector3(0, h * 0.5, 0)))
		_add(b, wood, _cyl(0.0, 0.07, 0.08, 4), px * _at(Vector3(0, h + 0.04, 0), Vector3(0, PI * 0.25, 0), Vector3(1, 1, 0.3)))
		_add(b, ink, _box(Vector3(0.022, h * 0.7, 0.024)), px * _at(Vector3(0, h * 0.5, 0)))


## Offrandes : petit plateau de bois, boule de riz, coupe, bougie allumée.
static func _offering_into(b: Dictionary, bn: Dictionary, xf: Transform3D) -> void:
	var wood := _toon(Toon.WOOD, true, 0.015)
	var white := _toon(Color("#F4F1EA"), true, 0.012)
	_add(b, wood, _box(Vector3(0.3, 0.14, 0.3)), xf * _at(Vector3(0, 0.07, 0)))
	_add(b, wood, _box(Vector3(0.36, 0.03, 0.36)), xf * _at(Vector3(0, 0.155, 0)))
	_add(b, white, _ball(0.08, 0.1, 7, 3), xf * _at(Vector3(-0.06, 0.2, 0.0)))
	_add(b, white, _cyl(0.035, 0.025, 0.05, 6), xf * _at(Vector3(0.09, 0.195, 0.06)))
	_add(b, white, _cyl(0.018, 0.018, 0.12, 5), xf * _at(Vector3(0.08, 0.23, -0.07)))
	_add(bn, _glow(FLAME_CORE, 1.6), _cyl(0.0, 0.02, 0.05, 4), xf * _at(Vector3(0.08, 0.315, -0.07)))


## Wagasa : ombrelle de papier huilé, ouverte posée au sol ou fermée appuyée.
static func _wagasa_into(b: Dictionary, xf: Transform3D, open: bool, col: Color) -> void:
	var cloth := _toon(col, true, 0.015)
	var stick := _toon(Color("#5A4434"), true, 0.012)
	var rim := _toon(Toon.WASHI, false)
	if open:
		var x2 := xf * _at(Vector3(0, 0.3, 0), Vector3(0.9, 0, 0.2))
		_add(b, cloth, _cyl(0.04, 0.55, 0.22, 12), x2)
		_add(b, rim, Decor.torus(0.285, 0.315, 12, 4), x2)
		_add(b, stick, _cyl(0.012, 0.012, 0.7, 5), x2 * _at(Vector3(0, -0.3, 0)))
	else:
		var x2 := xf * _at(Vector3.ZERO, Vector3(0, 0, 0.25))
		_add(b, stick, _cyl(0.012, 0.012, 1.0, 5), x2 * _at(Vector3(0, 0.5, 0)))
		_add(b, cloth, _cyl(0.025, 0.07, 0.6, 8), x2 * _at(Vector3(0, 0.62, 0)))


## Colonnes de basalte : une centrale dont le sommet est à `top`, d'autres plus basses autour.
static func _basalt_into(b: Dictionary, p: Vector2, r: float, top: float, rng: RandomNumberGenerator) -> void:
	var m := _toon(BASALT, true, 0.025)
	var y0 := VOID_Y - 0.3
	var h := top - y0
	_add(b, m, _cyl(r, r * 1.05, h, 6), _at(Vector3(p.x, y0 + h * 0.5, p.y), Vector3(0, rng.randf() * TAU, 0)))
	for k in rng.randi_range(3, 5):
		var a := TAU * k / 5.0 + rng.randf_range(-0.3, 0.3)
		var rr := r * rng.randf_range(0.45, 0.7)
		var hh := h * rng.randf_range(0.35, 0.8)
		_add(b, m, _cyl(rr, rr * 1.05, hh, 6), _at(Vector3(p.x + cos(a) * r * 1.2, y0 + hh * 0.5, p.y + sin(a) * r * 1.2)))


## Piques de roche noire plantées dans la lave, auréole dorée à leur pied.
static func _spikes_into(b: Dictionary, bn: Dictionary, p: Vector2, s: float, rng: RandomNumberGenerator) -> void:
	var m := _toon(BASALT, true, 0.025)
	for k in rng.randi_range(2, 4):
		var a := rng.randf() * TAU
		var d := 0.0 if k == 0 else rng.randf_range(0.4, 0.8) * s
		var base := Vector3(p.x + cos(a) * d, VOID_Y - 0.1, p.y + sin(a) * d)
		var h := rng.randf_range(1.4, 2.8) * s * (1.0 if k == 0 else 0.6)
		var tip := base + Vector3(rng.randf_range(-0.25, 0.25) * h, h, rng.randf_range(-0.25, 0.25) * h)
		_limb(b, m, base, tip, rng.randf_range(0.35, 0.55) * s, 0.02, 5)
	_add(bn, _glow(Color("#C07A2A"), 0.8), _cyl(0.95 * s, 0.95 * s, 0.02, 12), _at(Vector3(p.x, VOID_Y + 0.01, p.y)))


## Enclume de forge avec une lame chauffée au rouge orangé et un marteau.
static func _anvil_into(b: Dictionary, bn: Dictionary, xf: Transform3D) -> void:
	var iron := _toon(IRON, true, 0.025)
	var wood := _toon(Color("#5A4434"), true, 0.015)
	_add(b, iron, _box(Vector3(0.6, 0.15, 0.45)), xf * _at(Vector3(0, 0.075, 0)))
	_add(b, iron, _box(Vector3(0.3, 0.3, 0.25)), xf * _at(Vector3(0, 0.3, 0)))
	_add(b, iron, _box(Vector3(0.8, 0.16, 0.34)), xf * _at(Vector3(0, 0.53, 0)))
	_limb(b, iron, Vector3(0.4, 0.53, 0), Vector3(0.78, 0.57, 0), 0.1, 0.01, 6, xf)
	_add(bn, _glow(Color("#E07A30"), 1.3), _box(Vector3(0.7, 0.02, 0.06)), xf * _at(Vector3(-0.05, 0.62, 0.02), Vector3(0, 0.15, 0)))
	_add(bn, _toon(Color("#2A221C"), false), _box(Vector3(0.18, 0.04, 0.05)), xf * _at(Vector3(-0.47, 0.62, 0.07), Vector3(0, 0.15, 0)))
	# marteau posé contre l'enclume
	_add(b, wood, _cyl(0.02, 0.02, 0.5, 5), xf * _at(Vector3(0.1, 0.25, 0.3), Vector3(0.5, 0, 0.2)))
	_add(b, iron, _box(Vector3(0.16, 0.07, 0.07)), xf * _at(Vector3(0.12, 0.47, 0.42), Vector3(0.5, 0, 0.2)))


## Brasero : trépied, vasque, braises et flammes (la lumière éventuelle est ajoutée à part).
static func _brazier_into(b: Dictionary, bn: Dictionary, xf: Transform3D) -> void:
	var iron := _toon(IRON, true, 0.025)
	for k in 3:
		var a := TAU * k / 3.0
		_limb(b, iron, Vector3(cos(a) * 0.35, 0, sin(a) * 0.35), Vector3(cos(a) * 0.18, 0.72, sin(a) * 0.18), 0.035, 0.03, 5, xf)
	_add(b, iron, _cyl(0.42, 0.22, 0.25, 8), xf * _at(Vector3(0, 0.82, 0)))
	_add(bn, _glow(Color("#C8642A"), 1.0), _cyl(0.38, 0.38, 0.04, 8), xf * _at(Vector3(0, 0.93, 0)))
	_add(bn, _glow(EMBER, 2.0), _cyl(0.0, 0.25, 0.6, 6), xf * _at(Vector3(0, 1.24, 0)))
	_add(bn, _glow(FLAME_CORE, 2.4), _cyl(0.0, 0.14, 0.4, 5), xf * _at(Vector3(0, 1.15, 0)))
	for k in 3:
		var a := TAU * k / 3.0 + 0.5
		var q := Vector3(cos(a) * 0.2, 0.95, sin(a) * 0.2)
		_limb(bn, _glow(EMBER, 2.0), q, q + Vector3(cos(a) * 0.08, 0.32, sin(a) * 0.08), 0.1, 0.0, 5, xf)


## Chaîne tendue entre deux poteaux de fer, qui pend au milieu.
static func _chain_into(b: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var dir := Vector2.from_angle(rng.randf() * TAU)
	var a := Vector3(p.x - dir.x * 0.95, 0, p.y - dir.y * 0.95)
	var c := Vector3(p.x + dir.x * 0.95, 0, p.y + dir.y * 0.95)
	var iron := _toon(IRON, true, 0.02)
	for q: Vector3 in [a, c]:
		_add(b, iron, _cyl(0.09, 0.12, 2.2, 6), _at(Vector3(q.x, VOID_Y + 0.8, q.z)))
		_add(b, iron, _cyl(0.14, 0.14, 0.08, 6), _at(Vector3(q.x, VOID_Y + 1.92, q.z)))
	_links(b, iron, Vector3(a.x, 1.25, a.z), Vector3(c.x, 1.25, c.z), 0.55)


## Maillons (tores étirés, alternés à 90°) le long d'une chaînette de a à c.
static func _links(b: Dictionary, m: Material, a: Vector3, c: Vector3, sag: float) -> void:
	var d := c - a
	var span := d.length()
	if span < 0.1:
		return
	var n := maxi(int(span / 0.13), 4)
	var tor := Decor.torus(0.035, 0.07, 8, 4)
	var side := d.cross(Vector3.UP).normalized()
	for i in n + 1:
		var t := float(i) / n
		var pt := _sag(a, d, sag, t)
		var tg := (_sag(a, d, sag, minf(t + 0.02, 1.0)) - _sag(a, d, sag, maxf(t - 0.02, 0.0))).normalized()
		var axis := side if i % 2 == 0 else tg.cross(side).normalized()
		var z := tg.cross(axis).normalized()
		_add(b, m, tor, Transform3D(Basis(tg * 1.5, axis, z), pt))


static func _sag(a: Vector3, d: Vector3, sag: float, t: float) -> Vector3:
	return a + d * t + Vector3(0, -sag * 4.0 * t * (1.0 - t), 0)


## Masque d'oni (rouge braise, cornes d'os, yeux d'or) accroché à un poteau ; regarde vers +Z local.
static func _oni_mask_into(b: Dictionary, bn: Dictionary, xf: Transform3D) -> void:
	var wood := _toon(Color("#3B2E25"))
	var face := _toon(BRAISE)
	var bone := _toon(Color("#D8C9A3"), true, 0.02)
	var ink := _toon(Toon.SUMI, false)
	var eye := _glow(Toon.GOLD, 1.2)
	_add(b, wood, _box(Vector3(0.14, 1.6, 0.14)), xf * _at(Vector3(0, 0.8, 0)))
	_add(b, wood, _box(Vector3(0.7, 0.1, 0.1)), xf * _at(Vector3(0, 1.5, 0)))
	var c := Vector3(0, 1.22, 0.14)
	_add(b, face, _ball(0.25, 0.56, 10, 6), xf * _at(c, Vector3.ZERO, Vector3(1, 1, 0.5)))
	for sx: float in [-1.0, 1.0]:
		_limb(b, bone, c + Vector3(sx * 0.13, 0.17, 0.0), c + Vector3(sx * 0.24, 0.42, -0.03), 0.055, 0.0, 5, xf)
		_add(bn, ink, _box(Vector3(0.15, 0.045, 0.05)), xf * _at(c + Vector3(sx * 0.09, 0.08, 0.11), Vector3(0, 0, -sx * 0.4)))
		_add(bn, eye, _ball(0.035, 0.06, 6, 3), xf * _at(c + Vector3(sx * 0.09, 0.02, 0.12)))
		_limb(b, bone, c + Vector3(sx * 0.07, -0.12, 0.11), c + Vector3(sx * 0.075, -0.04, 0.12), 0.022, 0.0, 4, xf)
	_add(bn, ink, _box(Vector3(0.22, 0.05, 0.04)), xf * _at(c + Vector3(0, -0.13, 0.11)))


## Barque oshiokuri (proue effilée relevée vers +X local) et rameurs courbés.
static func _boat_into(b: Dictionary, xf: Transform3D, rowers: int) -> void:
	var hull := _toon(HULL)
	var rim := _toon(Color("#2A221C"))
	var crew := _toon(CREW, true, 0.02)
	var skin := _toon(Toon.SKIN, true, 0.02)
	_add(b, hull, _box(Vector3(3.0, 0.28, 0.62)), xf * _at(Vector3(0, 0.1, 0)))
	for sz: float in [-1.0, 1.0]:
		_add(b, rim, _box(Vector3(3.0, 0.06, 0.08)), xf * _at(Vector3(0, 0.27, sz * 0.3)))
	_limb(b, hull, Vector3(1.45, 0.1, 0), Vector3(2.3, 0.55, 0), 0.31, 0.03, 4, xf)
	_add(b, hull, _box(Vector3(0.3, 0.36, 0.62)), xf * _at(Vector3(-1.55, 0.16, 0)))
	for k in rowers:
		var x := -1.0 + k * (2.0 / maxf(float(rowers - 1), 1.0))
		_limb(b, crew, Vector3(x, 0.25, 0), Vector3(x + 0.18, 0.62, 0), 0.11, 0.08, 6, xf)
		_add(b, skin, _ball(0.08, 0.16, 6, 3), xf * _at(Vector3(x + 0.24, 0.7, 0)))
		_limb(b, rim, Vector3(x + 0.1, 0.5, 0.25), Vector3(x - 0.5, -0.1, 0.9), 0.025, 0.025, 4, xf)


## Pinceau géant planté pointe dans l'encre (inclinaison et échelle dans `xf`).
static func _brush_into(b: Dictionary, xf: Transform3D) -> void:
	var hair := _toon(Toon.SUMI, true, 0.02)
	var lac := _toon(Color("#2A1F1A"))
	var cane := _toon(Color("#B89B5E"))
	var knot := _toon(Color("#8A7040"), false)
	_add(b, hair, _ball(0.17, 0.5, 8, 4), xf * _at(Vector3(0, 0.05, 0)))
	_limb(b, hair, Vector3(0, -0.1, 0), Vector3(0, -0.5, 0), 0.15, 0.0, 7, xf)
	_add(b, lac, _cyl(0.1, 0.14, 0.26, 8), xf * _at(Vector3(0, 0.38, 0)))
	_add(b, cane, _cyl(0.075, 0.085, 2.6, 8), xf * _at(Vector3(0, 1.8, 0)))
	for k in 3:
		_add(b, knot, _cyl(0.088, 0.088, 0.035, 8), xf * _at(Vector3(0, 0.95 + k * 0.75, 0)))
	_add(b, lac, _cyl(0.09, 0.09, 0.1, 8), xf * _at(Vector3(0, 3.13, 0)))
	_add(b, _toon(Toon.GOLD, false), Decor.torus(0.04, 0.065, 10, 4), xf * _at(Vector3(0, 3.24, 0), Vector3(PI * 0.5, 0, 0)))


## Sceau de peintre : cylindre rouge cerclé d'or, poignée en boule, empreinte à côté.
static func _seal_into(b: Dictionary, xf: Transform3D) -> void:
	var red := _toon(SEAL_RED)
	var knob := _toon(Color("#E9DFC9"), true, 0.02)
	var washi := _toon(Toon.WASHI, false)
	_add(b, red, _cyl(0.3, 0.32, 0.6, 12), xf * _at(Vector3(0, 0.3, 0)))
	_add(b, _toon(Toon.GOLD, false), _cyl(0.33, 0.33, 0.06, 12), xf * _at(Vector3(0, 0.5, 0)))
	_add(b, knob, _cyl(0.1, 0.16, 0.12, 8), xf * _at(Vector3(0, 0.66, 0)))
	_add(b, knob, _ball(0.15, 0.24, 8, 4), xf * _at(Vector3(0, 0.82, 0)))
	_add(b, red, _box(Vector3(0.45, 0.01, 0.45)), xf * _at(Vector3(0.65, 0.0, 0.1), Vector3(0, 0.2, 0)))
	_add(b, washi, _box(Vector3(0.3, 0.012, 0.04)), xf * _at(Vector3(0.65, 0.002, 0.04), Vector3(0, 0.2, 0)))
	_add(b, washi, _box(Vector3(0.04, 0.012, 0.3)), xf * _at(Vector3(0.7, 0.002, 0.1), Vector3(0, 0.2, 0)))


## Feuilles de papier déchiré posées sur l'encre (quelques traits d'encre dessus).
static func _papers_into(b: Dictionary, p: Vector2, rng: RandomNumberGenerator, count: int, y: float, spread: float) -> void:
	var m1 := _toon(Toon.WASHI, false)
	var m2 := _toon(Color("#E2D6BD"), false)
	var ink := _toon(Toon.SUMI, false)
	for k in count:
		var a := rng.randf() * TAU
		var d := rng.randf() * spread
		var c := Vector3(p.x + cos(a) * d, y + k * 0.012, p.y + sin(a) * d)
		var xf := _at(c, Vector3(rng.randf_range(-0.05, 0.05), rng.randf() * TAU, rng.randf_range(-0.05, 0.05)))
		var w := rng.randf_range(0.5, 1.0)
		var l := rng.randf_range(0.6, 1.2)
		var pm: StandardMaterial3D = m1 if rng.randf() < 0.6 else m2
		_sheet_into(b, pm, xf, w, l)
		if rng.randf() < 0.5:
			_add(b, ink, Toon.box(Vector3(w * 0.7, 0.004, 0.05)),
				xf * _at(Vector3(0, 0.009, rng.randf_range(-l * 0.3, l * 0.3)), Vector3(0, rng.randf_range(-0.4, 0.4), 0)))


## Feuille déchirée : rectangle principal et coins arrachés décalés.
static func _sheet_into(b: Dictionary, m: Material, xf: Transform3D, w: float, l: float) -> void:
	_add(b, m, Toon.box(Vector3(w, 0.012, l)), xf)
	_add(b, m, Toon.box(Vector3(w * 0.45, 0.012, l * 0.35)), xf * _at(Vector3(w * 0.4, 0.004, l * 0.45), Vector3(0, 0.5, 0)))
	_add(b, m, Toon.box(Vector3(w * 0.3, 0.012, l * 0.25)), xf * _at(Vector3(-w * 0.45, -0.003, -l * 0.42), Vector3(0, -0.4, 0)))

## Bitte d'amarrage : pieu sombre de `base` sur `h`, cordage enroulé ; renvoie le sommet.
static func _bitt_into(b: Dictionary, bn: Dictionary, base: Vector3, h: float) -> Vector3:
	var pile := _toon(Decor.PILE, true, 0.02)
	var rope := _toon(Decor.KOMO, false)
	_add(b, pile, _cyl(0.09, 0.11, h, 6), _at(base + Vector3(0, h * 0.5, 0)))
	_add(b, pile, _cyl(0.12, 0.12, 0.05, 6), _at(base + Vector3(0, h + 0.02, 0)))
	_add(bn, rope, Decor.torus(0.1, 0.14, 10, 4), _at(base + Vector3(0, h - 0.25, 0)))
	_add(bn, rope, Decor.torus(0.1, 0.14, 10, 4), _at(base + Vector3(0, h - 0.18, 0)))
	return base + Vector3(0, h + 0.05, 0)


## Lanterne de port (jōyatō) : socle de pierre à gradins dans l'eau, fût, chambre de papier lumineuse, toit.
static func _port_lantern_into(b: Dictionary, bn: Dictionary, xf: Transform3D) -> void:
	var stone := _toon(Decor.STONE, true, 0.025)
	var dark := _toon(STONE_DARK, true, 0.025)
	var wood := _toon(Color("#3B2E25"), true, 0.02)
	var paper := _glow(Color("#FBE3B0"), 1.1)
	var roof := _toon(Color("#2E2C33"), true, 0.02)
	_add(b, dark, _box(Vector3(1.1, 0.5, 1.1)), xf * _at(Vector3(0, 0.25, 0)))
	_add(b, stone, _box(Vector3(0.85, 0.3, 0.85)), xf * _at(Vector3(0, 0.65, 0)))
	_add(b, stone, _box(Vector3(0.62, 0.25, 0.62)), xf * _at(Vector3(0, 0.92, 0)))
	_add(b, stone, _box(Vector3(0.3, 1.1, 0.3)), xf * _at(Vector3(0, 1.6, 0)))
	_add(b, dark, _box(Vector3(0.6, 0.08, 0.6)), xf * _at(Vector3(0, 2.19, 0)))
	_add(bn, paper, _box(Vector3(0.44, 0.46, 0.44)), xf * _at(Vector3(0, 2.46, 0)))
	for k in 4:
		var cx: float = 0.24 if k % 2 == 0 else -0.24
		var cz: float = 0.24 if k < 2 else -0.24
		_add(b, wood, _box(Vector3(0.06, 0.5, 0.06)), xf * _at(Vector3(cx, 2.46, cz)))
	for sz: float in [-1.0, 1.0]:
		_add(b, wood, _box(Vector3(0.5, 0.04, 0.03)), xf * _at(Vector3(0, 2.46, sz * 0.225)))
		_add(b, wood, _box(Vector3(0.03, 0.04, 0.5)), xf * _at(Vector3(sz * 0.225, 2.46, 0)))
	Decor.roof_into(b, b, roof, roof, xf * _at(Vector3(0, 2.71, 0)), 0.86, 0.86, 0.32, 0.0, 0.45)


## Entrepôt kura sur pilotis (face à +Z local, empreinte w × d, murs de hauteur h) : soubassement namako
## (losanges de plâtre sur ardoise), mur de plâtre, fenêtre, mon du clan, toit de tuiles incurvé.
static func _kura_into(b: Dictionary, bn: Dictionary, xf: Transform3D, w: float, d: float, h: float, mon: int) -> void:
	var pile := _toon(Decor.PILE, true, 0.02)
	var deck := Decor._toon("pier_plank", Decor.PLANK, true, 0.02)
	var plaster := _toon(SHIKKUI, true, 0.025)
	var trim := _toon(SHIKKUI, false)
	var tile := _toon(KAWARA, true, 0.025)
	var ridge := _toon(KAWARA_DARK, false)
	var ink := _toon(Toon.SUMI, false)
	for i in 3:
		for sz: float in [-1.0, 1.0]:
			_add(b, pile, _cyl(0.08, 0.09, 1.0, 6), xf * _at(Vector3((float(i) - 1.0) * (w * 0.5 - 0.2), 0.1, sz * (d * 0.5 - 0.2))))
	var y0 := 0.69
	_add(b, deck, _box(Vector3(w + 0.3, 0.14, d + 0.3)), xf * _at(Vector3(0, 0.62, 0)))
	var lo := h * 0.38
	_add(b, tile, _box(Vector3(w, lo, d)), xf * _at(Vector3(0, y0 + lo * 0.5, 0)))
	_add(b, plaster, _box(Vector3(w - 0.02, h - lo, d - 0.02)), xf * _at(Vector3(0, y0 + lo + (h - lo) * 0.5, 0)))
	_add(bn, ridge, _box(Vector3(w + 0.06, 0.08, d + 0.06)), xf * _at(Vector3(0, y0 + lo, 0)))
	if not Toon.lite:
		var nd := maxi(int(w / 0.42), 2)
		for k in nd:
			var x := (float(k) - (nd - 1) * 0.5) * (w / float(nd))
			_add(bn, trim, _box(Vector3(0.17, 0.17, 0.02)), xf * _at(Vector3(x, y0 + lo * 0.5, d * 0.5 + 0.006), Vector3(0, 0, PI * 0.25)))
		_add(bn, trim, _box(Vector3(0.62, 0.54, 0.05)), xf * _at(Vector3(w * 0.22, y0 + h * 0.72, d * 0.5 + 0.015)))
	_add(bn, ink, _box(Vector3(0.46, 0.38, 0.06)), xf * _at(Vector3(w * 0.22, y0 + h * 0.72, d * 0.5 + 0.025)))
	Decor.mon_into(bn, ink, xf * _at(Vector3(-w * 0.18, y0 + h * 0.74, d * 0.5 + 0.012)), 0.32, mon)
	Decor.roof_into(b, bn, tile, ridge, xf * _at(Vector3(0, y0 + h, 0)), w + 0.6, d + 0.7, h * 0.36, 0.62, 0.3)


## Donjon (tenshukaku) en volume, face à +Z local : socle ishigaki aux flancs évasés, trois étages de plâtre
## à fenêtres d'encre, toits de tuiles incurvés aux coins relevés, pignon chidori, shachihoko d'or.
static func _castle_into(b: Dictionary, bn: Dictionary, xf: Transform3D) -> void:
	var stone := _toon(Color("#6E6A62"), true, 0.03)
	var plaster := _toon(SHIKKUI, true, 0.025)
	var tile := _toon(KAWARA, true, 0.025)
	var ridge := _toon(KAWARA_DARK, false)
	var ink := _toon(Toon.SUMI, false)
	var gold := _toon(Toon.GOLD, true, 0.02)
	# ishigaki : gradins de pierre qui s'évasent vers le pied (pente concave des murs de château)
	for k in 4:
		var t := float(k) / 3.0
		var wk := lerpf(5.6, 4.4, pow(t, 0.7))
		_add(b, stone, _box(Vector3(wk, 0.62, wk * 0.9)), xf * _at(Vector3(0, -0.2 + 0.6 * k, 0)))
	var widths := PackedFloat32Array([3.8, 3.0, 2.2])
	var heights := PackedFloat32Array([1.25, 1.1, 1.0])
	var y := 1.9
	for k in 3:
		var w := widths[k]
		var h := heights[k]
		_add(b, plaster, _box(Vector3(w, h, w * 0.86)), xf * _at(Vector3(0, y + h * 0.5, 0)))
		var nw := 4 - k
		if not Toon.lite:
			for j in nw:
				var wx := (float(j) - (nw - 1) * 0.5) * (w / (float(nw) + 0.4))
				_add(bn, ink, _box(Vector3(0.22, 0.32, 0.05)), xf * _at(Vector3(wx, y + h * 0.55, w * 0.43 + 0.01)))
		y += h
		var top := k == 2
		var rh: float = 0.95 if top else 0.6
		var rl: float = 0.4 if top else 0.6
		Decor.roof_into(b, bn, tile, ridge, xf * _at(Vector3(0, y, 0)), w + 1.0, w * 0.86 + 1.0, rh, rl, 0.38)
		if k == 1:
			# chidori-hafu : pignon triangulaire sur le pan avant
			_add(b, tile, _cyl(0.62, 0.62, 0.55, 3), xf * _at(Vector3(0, y + 0.22, w * 0.43 + 0.1), Vector3(-PI * 0.5, 0, 0), Vector3(1.0, 1.0, 0.6)))
		if top:
			var r := rl * (w + 1.0) * 0.5
			for sx: float in [-1.0, 1.0]:
				_limb(bn, gold, Vector3(sx * r, y + rh + 0.05, 0), Vector3(sx * (r + 0.12), y + rh + 0.42, 0), 0.07, 0.02, 4, xf)
		y += 0.18


## Forge (tatara) : socle de basalte, four d'argile à gueule rougeoyante, cheminée, auvent,
## soufflet, enclume et bac de trempe. Face à +Z local.
static func _forge_into(b: Dictionary, bn: Dictionary, xf: Transform3D) -> void:
	var clay := _toon(Color("#6B4A3A"), true, 0.025)
	var wood := _toon(Color("#4A3428"), true, 0.02)
	var roof := _toon(Color("#2E2C33"), true, 0.025)
	var fire := _glow(EMBER, 2.0)
	var core := _glow(FLAME_CORE, 2.4)
	_add(b, _toon(BASALT, true, 0.03), _box(Vector3(2.4, 1.2, 1.9)), xf * _at(Vector3(0, -0.5, 0)))
	_add(b, clay, _box(Vector3(1.0, 0.9, 0.7)), xf * _at(Vector3(-0.35, 0.55, -0.25)))
	_add(bn, fire, _box(Vector3(0.36, 0.26, 0.04)), xf * _at(Vector3(-0.35, 0.42, 0.11)))
	_add(bn, core, _box(Vector3(0.2, 0.14, 0.05)), xf * _at(Vector3(-0.35, 0.4, 0.115)))
	_add(b, clay, _cyl(0.16, 0.22, 1.5, 8), xf * _at(Vector3(-0.55, 1.7, -0.35)))
	_add(bn, fire, _cyl(0.12, 0.12, 0.03, 8), xf * _at(Vector3(-0.55, 2.46, -0.35)))
	for k in 4:
		var px: float = 1.05 if k % 2 == 0 else -1.05
		var pz: float = 0.8 if k < 2 else -0.8
		_add(b, wood, _box(Vector3(0.08, 1.8, 0.08)), xf * _at(Vector3(px, 1.0, pz)))
	# auvent de tuiles incurvé aux coins relevés
	Decor.roof_into(b, b, roof, roof, xf * _at(Vector3(0, 1.9, 0)), 2.7, 2.1, 0.42, 0.7, 0.35)
	_add(b, wood, _box(Vector3(0.5, 0.35, 0.3)), xf * _at(Vector3(0.55, 0.28, -0.2)))
	_add(b, wood, _cyl(0.025, 0.025, 0.5, 5), xf * _at(Vector3(0.55, 0.3, 0.1), Vector3(PI * 0.5, 0, 0)))
	_anvil_into(b, bn, xf * _at(Vector3(0.6, 0.1, 0.45), Vector3(0, 0.4, 0), Vector3.ONE * 0.7))
	_add(b, wood, _box(Vector3(0.6, 0.22, 0.3)), xf * _at(Vector3(-0.6, 0.21, 0.55)))
	_add(bn, _toon(Toon.PRUSSIAN, false), _box(Vector3(0.5, 0.02, 0.22)), xf * _at(Vector3(-0.6, 0.31, 0.55)))


## Pile de lingots d'acier (tamahagane), le dernier encore rougeoyant.
static func _ingots_into(b: Dictionary, bn: Dictionary, xf: Transform3D) -> void:
	var iron := _toon(Color("#55545C"), true, 0.015)
	for layer in 3:
		for k in 3 - layer:
			var off := (float(k) - (2 - layer) * 0.5) * 0.16
			var y := 0.05 + layer * 0.09
			if layer % 2 == 0:
				_add(b, iron, _box(Vector3(0.14, 0.08, 0.36)), xf * _at(Vector3(off, y, 0)))
			else:
				_add(b, iron, _box(Vector3(0.36, 0.08, 0.14)), xf * _at(Vector3(0, y, off)))
	_add(bn, _glow(Color("#E07A30"), 1.2), _box(Vector3(0.12, 0.03, 0.3)), xf * _at(Vector3(0, 0.25, 0)))


## Torche géante du Yoshida Hi-Matsuri : socle de basalte, fût cerclé, flamme orangée à cœur d'or.
static func _yoshida_into(b: Dictionary, bn: Dictionary, xf: Transform3D) -> void:
	var stone := _toon(BASALT, true, 0.03)
	var body := _toon(Color("#6B4A2E"))
	var band := _toon(Color("#2E241C"), false)
	var flame := _glow(EMBER, 2.0)
	var core := _glow(FLAME_CORE, 2.4)
	_add(b, stone, _cyl(0.75, 0.9, 0.9, 6), xf * _at(Vector3(0, 0.15, 0)))
	_add(b, body, _cyl(0.62, 0.42, 3.0, 8), xf * _at(Vector3(0, 2.1, 0)))
	for k in 3:
		var hy := 1.2 + k * 1.0
		var rr := 0.42 + 0.2 * (hy - 0.6) / 3.0 + 0.025
		_add(b, band, _cyl(rr, rr, 0.12, 8), xf * _at(Vector3(0, hy, 0)))
	_add(bn, flame, _cyl(0.0, 0.62, 1.6, 7), xf * _at(Vector3(0, 4.4, 0)))
	_add(bn, core, _cyl(0.0, 0.36, 1.0, 6), xf * _at(Vector3(0, 4.15, 0)))
	for k in 3:
		var a := TAU * k / 3.0 + 0.4
		var q := Vector3(cos(a) * 0.4, 3.75, sin(a) * 0.4)
		_limb(bn, flame, q, q + Vector3(cos(a) * 0.3, 0.8, sin(a) * 0.3), 0.2, 0.0, 5, xf)


## Barrique géante du tonnelier (Fujimigahara) dressée face à +Z, le tonnelier à l'ouvrage dedans.
static func _barrel_giant_into(b: Dictionary, bn: Dictionary, xf: Transform3D) -> void:
	var wood := _toon(Color("#B48A50"), true, 0.02)
	var hoop := _toon(Decor.BAMBOO_NODE, true, 0.015)
	var crew := _toon(CREW, true, 0.02)
	var skin := _toon(Toon.SKIN, true, 0.02)
	var r := 1.1
	var c := Vector3(0, r - 0.35, 0)
	for k in 16:
		var a := TAU * k / 16.0
		_add(b, wood, _box(Vector3(0.44, 0.09, 1.0)), xf * Transform3D(Basis(Vector3(0, 0, 1), a + PI * 0.5), c + Vector3(cos(a), sin(a), 0) * r))
	for zz: float in [-0.32, 0.32]:
		_add(b, hoop, Decor.torus(r + 0.03, r + 0.11, 24, 4), xf * _at(c + Vector3(0, 0, zz), Vector3(PI * 0.5, 0, 0)))
	var foot := c + Vector3(0.15, -r + 0.06, 0)
	_limb(b, crew, foot + Vector3(0, 0.05, 0), foot + Vector3(-0.1, 0.45, 0.05), 0.13, 0.1, 6, xf)
	_add(b, skin, _ball(0.1, 0.19, 7, 3), xf * _at(foot + Vector3(-0.12, 0.6, 0.08)))
	_limb(b, crew, foot + Vector3(-0.05, 0.4, 0.1), foot + Vector3(0.35, 0.55, 0.15), 0.04, 0.035, 5, xf)
	_limb(bn, _toon(Color("#5A4434"), true, 0.012), foot + Vector3(0.35, 0.55, 0.15), foot + Vector3(0.5, 0.78, 0.15), 0.025, 0.025, 5, xf)


## Vague noire : bosse d'encre et doigts recourbés vers +Z local, griffes d'écume au bout.
static func _ink_claw_into(b: Dictionary, bn: Dictionary, xf: Transform3D, rng: RandomNumberGenerator) -> void:
	var ink := _toon(INK_SEA, true, 0.02)
	var foam := _toon(Toon.FOAM, true, 0.012)
	_add(b, ink, _ball(1.0, 0.8, 10, 4), xf * _at(Vector3(0, 0.0, -0.2)))
	var n := rng.randi_range(3, 5)
	for k in n:
		var x := (float(k) - (n - 1) * 0.5) * 0.42
		var h := rng.randf_range(1.0, 1.5) * (1.0 - absf(x) * 0.35)
		var a := Vector3(x, 0.2, -0.25)
		var p1 := Vector3(x * 1.05, h * 0.7, -0.1)
		var p2 := Vector3(x * 1.1, h, 0.3)
		var p3 := Vector3(x * 1.1, h * 0.78, 0.7)
		_limb(b, ink, a, p1, 0.24, 0.17, 6, xf)
		_limb(b, ink, p1, p2, 0.17, 0.1, 6, xf)
		_limb(b, ink, p2, p3, 0.1, 0.03, 5, xf)
		_add(bn, foam, _ball(0.08, 0.11, 6, 3), xf * _at(p2 + Vector3(0, 0.07, 0)))
		for j in 3:
			var dir := Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.7, -0.1), 1.0).normalized()
			_limb(bn, foam, p3, p3 + dir * rng.randf_range(0.12, 0.24), 0.035, 0.0, 4, xf)
	for j in 4:
		_add(bn, foam, _ball(rng.randf_range(0.18, 0.3), 0.08, 7, 3), xf * _at(Vector3(rng.randf_range(-0.9, 0.9), 0.02, rng.randf_range(0.4, 0.9))))


## Paravent byōbu à quatre feuilles en zigzag : washi, cadre laqué, nuage d'or, Fuji d'encre.
static func _byobu_into(b: Dictionary, xf: Transform3D) -> void:
	var paper := _toon(Toon.WASHI, true, 0.015)
	var frame := _toon(Color("#2A1F1A"), false)
	var gold := _toon(Toon.GOLD, false)
	var ink := _toon(Toon.SUMI, false)
	var pw := 0.48
	var start := Vector3(-pw * 1.8, 0, 0)
	for k in 4:
		var yaw: float = 0.4 if k % 2 == 0 else -0.4
		var dir := Vector3(cos(yaw), 0, -sin(yaw))
		var px := xf * _at(start + dir * pw * 0.5, Vector3(0, yaw, 0))
		_add(b, paper, _box(Vector3(pw, 1.1, 0.02)), px * _at(Vector3(0, 0.62, 0)))
		_add(b, frame, _box(Vector3(pw + 0.02, 0.04, 0.03)), px * _at(Vector3(0, 1.18, 0)))
		_add(b, frame, _box(Vector3(pw + 0.02, 0.06, 0.03)), px * _at(Vector3(0, 0.06, 0)))
		_add(b, gold, _box(Vector3(pw - 0.03, 0.16, 0.024)), px * _at(Vector3(0, 1.0, 0)))
		if k == 1 or k == 2:
			_add(b, ink, _cyl(0.05, 0.22, 0.26, 3), px * _at(Vector3(0, 0.6, 0.012), Vector3.ZERO, Vector3(1, 1, 0.05)))
		start += dir * pw


## Kagami-mochi : support sanbō, deux mochi superposés, bigarade et feuille.
static func _kagami_into(b: Dictionary, xf: Transform3D) -> void:
	var wood := _toon(Toon.WOOD, true, 0.015)
	var mochi := _toon(Color("#F6F1E6"), true, 0.015)
	var orange := _toon(Color("#E08A2E"), true, 0.012)
	_add(b, wood, _box(Vector3(0.34, 0.18, 0.34)), xf * _at(Vector3(0, 0.09, 0)))
	_add(b, wood, _box(Vector3(0.46, 0.04, 0.46)), xf * _at(Vector3(0, 0.2, 0)))
	_add(b, _toon(Toon.WASHI, false), _box(Vector3(0.36, 0.01, 0.36)), xf * _at(Vector3(0, 0.225, 0), Vector3(0, PI * 0.25, 0)))
	_add(b, mochi, _ball(0.17, 0.15, 10, 4), xf * _at(Vector3(0, 0.29, 0)))
	_add(b, mochi, _ball(0.13, 0.12, 10, 4), xf * _at(Vector3(0, 0.39, 0)))
	_add(b, orange, _ball(0.075, 0.13, 8, 4), xf * _at(Vector3(0, 0.5, 0)))
	_add(b, _toon(Decor.PINE_A, false), _box(Vector3(0.12, 0.012, 0.05)), xf * _at(Vector3(0.04, 0.565, 0), Vector3(0, 0.5, 0.3)))


## Kunai de fer noirci : lame en feuille, poignée entourée de corde, anneau ; pointe vers +Z local.
## Matériaux déjà présents dans presque toutes les salles (encre, corde) : pas de draw call en plus.
static func _kunai_into(b: Dictionary, xf: Transform3D) -> void:
	var iron := _toon(Toon.SUMI, false)
	var wrap := Decor._toon("komo_rope", Decor.ROPE_DARK, false)
	_add(b, iron, _cyl(0.0, 0.04, 0.18, 4), xf * _at(Vector3(0, 0, 0.09), Vector3(PI * 0.5, 0, 0), Vector3(1, 1, 0.3)))
	_add(b, wrap, _cyl(0.012, 0.014, 0.11, 5), xf * _at(Vector3(0, 0, -0.055), Vector3(PI * 0.5, 0, 0)))
	_add(b, iron, Decor.torus(0.016, 0.03, 8, 3), xf * _at(Vector3(0, 0, -0.135), Vector3(0, 0, PI * 0.5)))


## Poteau d'entraînement (face à +Z local) : pieu de bois, paille de makiwara liée, kunai plantés,
## ofuda de papier épinglé par un kunai.
static func _kunai_post_into(b: Dictionary, bn: Dictionary, xf: Transform3D, rng: RandomNumberGenerator) -> void:
	var wood := Decor._toon("pole", Decor.POLE, true, 0.02)
	var straw := Decor._toon("straw", Decor.STRAW, true, 0.02)
	var rope := Decor._toon("komo_rope", Decor.ROPE_DARK, false)
	var paper := Decor._toon("shide", Decor.SHIDE, true, 0.008)
	var ink := _toon(Toon.SUMI, false)
	_add(b, wood, _cyl(0.075, 0.085, 0.95, 7), xf * _at(Vector3(0, 0.475, 0)))
	_add(b, wood, _cyl(0.09, 0.075, 0.05, 7), xf * _at(Vector3(0, 0.97, 0)))
	_add(b, straw, _cyl(0.1, 0.1, 0.22, 8), xf * _at(Vector3(0, 0.62, 0)))
	for y: float in [0.53, 0.71]:
		_add(bn, rope, _cyl(0.104, 0.104, 0.025, 8), xf * _at(Vector3(0, y, 0)))
	_add(bn, paper, _box(Vector3(0.08, 0.2, 0.006)), xf * _at(Vector3(0, 0.84, 0.086)))
	_add(bn, ink, _box(Vector3(0.012, 0.13, 0.008)), xf * _at(Vector3(0, 0.83, 0.088)))
	_kunai_into(bn, xf * _at(Vector3(0, 0.9, 0.2), Vector3(0.15, PI, 0)))
	for k in 2:
		var a := rng.randf_range(0.6, 1.2) * (1.0 if k == 0 else -1.0)
		var dv := Vector3(sin(a), 0, cos(a))
		_kunai_into(bn, xf * _at(Vector3(dv.x * 0.22, 0.58 + k * 0.09, dv.z * 0.22), Vector3(rng.randf_range(-0.2, 0.2), a + PI, 0)))


## Shuriken à quatre branches de fer noirci, posé à plat.
static func _shuriken_into(b: Dictionary, xf: Transform3D) -> void:
	var steel := _toon(Toon.SUMI, false)
	for k in 4:
		var a := PI * 0.5 * k
		_add(b, steel, _cyl(0.0, 0.035, 0.11, 4), xf * Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(1, 1, 0.25)), Vector3(sin(a), 0, cos(a)) * 0.055))
	_add(b, steel, _cyl(0.035, 0.035, 0.012, 8), xf)


# ------------------------------------------------------------------ particules d'ambiance

## Particules en boucle sur PART_AREA, propres à chaque monde.
static func build_particles(world_id: int, parent: Node3D) -> void:
	var area := PART_AREA
	var ctr := area.get_center()
	match clampi(world_id, 1, WORLDS.size()):
		6, 7, 8:
			_particles_new(clampi(world_id, 1, WORLDS.size()), parent, area, ctr)
		1:
			# pétales de cerisier et quelques mouettes qui planent au-dessus du fond
			Decor.petals(parent, area)
			var g := _emitter(parent, "Gulls", Vector3(0, 4.6, -12.5), Vector3(9.0, 0.7, 1.6), 5, 22.0, _gull_mesh())
			g.direction = Vector3(1, 0, 0.05)
			g.spread = 8.0
			g.gravity = Vector3.ZERO
			g.initial_velocity_min = 0.7
			g.initial_velocity_max = 1.1
			g.color_ramp = _fade(0.08, 0.9)
			g.emitting = true
		2:
			# feux follets (kitsune-bi) : petites flammes or et blanches qui flottent
			var p := _emitter(parent, "KitsuneBi", Vector3(ctr.x, 1.6, ctr.z), Vector3(area.size.x * 0.5, 1.2, area.size.z * 0.5), 36, 5.0, _sphere_mesh("fire", 0.06, true))
			p.direction = Vector3.UP
			p.spread = 180.0
			p.gravity = Vector3(0, 0.05, 0)
			p.initial_velocity_min = 0.08
			p.initial_velocity_max = 0.25
			p.scale_amount_min = 0.8
			p.scale_amount_max = 1.7
			p.color_ramp = _fade(0.2, 0.75)
			p.color_initial_ramp = _ramp([Color(1.0, 0.82, 0.45), Color(1.0, 0.95, 0.8), Color(0.95, 0.75, 0.35)], false)
			p.emitting = true
		3:
			# neige en diagonale (le vent pousse vers +X : émetteur décalé à contre-vent)
			var life := 4.6
			var p := _emitter(parent, "Snow", Vector3(ctr.x - 1.2, area.position.y + area.size.y, ctr.z), Vector3(area.size.x * 0.5 + 1.2, 0.05, area.size.z * 0.5), 70, life, _sphere_mesh("snow", 0.035, false))
			p.direction = Vector3(0.45, -1.0, 0.12)
			p.spread = 6.0
			p.gravity = Vector3(0.04, -0.15, 0)
			p.initial_velocity_min = 1.1
			p.initial_velocity_max = 1.4
			p.scale_amount_min = 0.7
			p.scale_amount_max = 1.6
			p.color_ramp = _fade(0.08, 0.9)
			p.emitting = true
		4:
			# braises orange qui montent
			var p := _emitter(parent, "Embers", Vector3(ctr.x, area.position.y + 0.1, ctr.z), Vector3(area.size.x * 0.5, 0.1, area.size.z * 0.5), 50, 4.0, _quad_mesh("ember", Vector2(0.07, 0.07), true))
			p.direction = Vector3.UP
			p.spread = 25.0
			p.gravity = Vector3(0.08, 0.3, 0.02)
			p.initial_velocity_min = 0.5
			p.initial_velocity_max = 1.1
			p.angle_min = 0.0
			p.angle_max = 360.0
			p.angular_velocity_min = -200.0
			p.angular_velocity_max = 200.0
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.5
			var g := Gradient.new()
			g.offsets = PackedFloat32Array([0.0, 0.1, 0.6, 1.0])
			g.colors = PackedColorArray([Color(1.0, 0.85, 0.5, 0.0), Color(1.0, 0.8, 0.45, 1.0), Color(1.0, 0.45, 0.15, 0.85), Color(0.5, 0.1, 0.05, 0.0)])
			p.color_ramp = g
			p.emitting = true
		_:
			# fragments de papier et d'encre qui dérivent avec le vent
			var p := _emitter(parent, "Paper", Vector3(ctr.x - 2.2, 2.4, ctr.z), Vector3(area.size.x * 0.5, 2.2, area.size.z * 0.5), 44, 7.0, _quad_mesh("paper", Vector2(0.13, 0.1), false))
			p.direction = Vector3(1.0, 0.12, 0.2)
			p.spread = 25.0
			p.gravity = Vector3(0.1, -0.03, 0.02)
			p.initial_velocity_min = 0.25
			p.initial_velocity_max = 0.55
			p.angle_min = 0.0
			p.angle_max = 360.0
			p.angular_velocity_min = -150.0
			p.angular_velocity_max = 150.0
			p.scale_amount_min = 0.8
			p.scale_amount_max = 1.6
			p.color_ramp = _fade(0.1, 0.85)
			p.color_initial_ramp = _ramp([Toon.WASHI, Color("#F6F0E2"), Toon.SUMI], true)
			p.emitting = true
	if not Toon.lite:
		_motes(clampi(world_id, 1, WORLDS.size()), parent, area, ctr)


## Poussière en suspension qui dérive lentement à hauteur d'homme (pas en mode léger) : la lumière
## a de l'épaisseur. Rien pour la neige, le plancton et les braises (déjà des particules qui flottent).
static func _motes(wid: int, parent: Node3D, area: AABB, ctr: Vector3) -> void:
	var cols: Array = []
	match wid:
		1:
			cols = [Color(1.0, 0.93, 0.8, 0.55), Color(0.95, 0.9, 0.82, 0.4)]
		5:
			cols = [Color(0.3, 0.27, 0.3, 0.45), Color(0.95, 0.9, 0.82, 0.45)]
		6:
			cols = [Color(0.92, 0.9, 0.6, 0.5), Color(0.8, 0.85, 0.6, 0.4)]
		8:
			cols = [Color(0.78, 0.72, 0.95, 0.45), Color(0.6, 0.58, 0.7, 0.35)]
		_:
			return
	var p := _emitter(parent, "Motes", Vector3(ctr.x, 1.3, ctr.z), Vector3(area.size.x * 0.5, 1.1, area.size.z * 0.5), 22, 8.0, _quad_mesh("mote", Vector2(0.035, 0.035), false))
	p.direction = Vector3(1.0, 0.2, 0.0)
	p.spread = 180.0
	p.gravity = Vector3(0.02, 0.01, 0)
	p.initial_velocity_min = 0.03
	p.initial_velocity_max = 0.1
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.color_ramp = _fade(0.25, 0.7)
	p.color_initial_ramp = _ramp(cols, false)
	p.emitting = true


static func _emitter(parent: Node3D, nm: String, center: Vector3, extents: Vector3, amount: int, life: float, mesh: Mesh) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = nm
	parent.add_child(p)
	p.position = center
	p.local_coords = false
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.mesh = mesh
	return p


## Fondu alpha : apparition jusqu'à `t_in`, disparition à partir de `t_out`.
static func _fade(t_in: float, t_out: float) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, t_in, t_out, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	return g


## Teintes initiales : réparties uniformément (constant = tirage parmi des couleurs franches).
static func _ramp(cols: Array, constant: bool) -> Gradient:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var pc := PackedColorArray()
	for i in cols.size():
		var c: Color = cols[i]
		offs.append(float(i) / maxf(float(cols.size() - 1), 1.0) if not constant else float(i) / float(cols.size()))
		pc.append(c)
	g.offsets = offs
	g.colors = pc
	if constant:
		g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	return g


## Sphère de particule (maillage propre : porte son matériau, jamais partagé avec le cache de décor).
static func _sphere_mesh(key: String, r: float, additive: bool) -> SphereMesh:
	if _meshes.has(key):
		var cached: SphereMesh = _meshes[key]
		return cached
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 6
	m.rings = 3
	m.material = _pmat(false, additive)
	_meshes[key] = m
	return m


static func _quad_mesh(key: String, size: Vector2, additive: bool) -> QuadMesh:
	if _meshes.has(key):
		var cached: QuadMesh = _meshes[key]
		return cached
	var q := QuadMesh.new()
	q.size = size
	q.material = _pmat(true, additive)
	_meshes[key] = q
	return q


## Mouette en vol (ailes en « M » le long de Z, vol vers +X), couleurs de sommets.
static func _gull_mesh() -> ArrayMesh:
	if _meshes.has("gull"):
		var cached: ArrayMesh = _meshes["gull"]
		return cached
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var w := Color("#F4F2EC")
	var g := Color("#9AA3AD")
	var d := Color("#3A3F48")
	_vtri(st, Vector3(0.22, 0, 0), Vector3(0, 0.02, 0.05), Vector3(-0.2, 0, 0), w, w, w)
	_vtri(st, Vector3(0.22, 0, 0), Vector3(-0.2, 0, 0), Vector3(0, 0.02, -0.05), w, w, w)
	for sz: float in [-1.0, 1.0]:
		var e := Vector3(0.02, 0.07, sz * 0.22)
		var t := Vector3(-0.08, 0.0, sz * 0.48)
		_vtri(st, Vector3(0.08, 0.01, 0), e, Vector3(-0.06, 0.01, 0), w, g, w)
		_vtri(st, e, t, Vector3(-0.07, 0.05, sz * 0.25), g, d, g)
	var mesh := st.commit()
	mesh.surface_set_material(0, _pmat(false, false))
	_meshes["gull"] = mesh
	return mesh


# ------------------------------------------------------------------ fosses (vides intérieurs de l'arène)
# Les vides entre plateformes, dans le cadre de l'arène, deviennent des fosses : paroi visible sous
# les bords qui font face à la caméra, gouffre sombre, fond lointain à peine éclairé, bord propre au
# monde (planches cassées, pierres ébréchées, neige, braise, papier déchiré). Tout est plat et bas
# (jamais au-dessus du sol), hors des plateformes. ~3-5 draw calls : 1 nappe à couleurs de sommets,
# 1 nappe additive (reflets / lave), 1 matériau de bord (+ contour), braises du monde 4.

const PIT_HALF := Vector2(4.6, 8.6)  # cadre de l'arène (HALF de arena.gd)
const PIT_Y := VOID_Y + 0.008  # juste au-dessus du plan du vide
const PIT_FADE := 0.7  # fondu vers la mer là où une fosse touche le bord de l'arène
const PIT_WALL_N := 0.75  # hauteur apparente de la paroi sous un bord nord (face à la caméra)
const PIT_BRIDGE_W := 2.7  # comme arena.gd : un rectangle plus étroit est une passerelle

## Couleurs des fosses : haut de paroi, bas de paroi, gouffre, fond lointain, lignes, reflets.
static func _pit_style(wid: int) -> Dictionary:
	match wid:
		1:
			return {"wall": Color("#5E554B"), "low": Color("#262019"), "deep": Color("#03070D"), "floor": Color("#0D2036"),
				"line": Color("#2E2116"), "glint": Color(0.72, 0.86, 1.0)}
		2:
			return {"wall": Color("#5C5E54"), "low": Color("#24271F"), "deep": Color("#020606"), "floor": Color("#0A221E"),
				"line": Color("#23241F"), "glint": Color(1.0, 0.9, 0.62)}
		3:
			return {"wall": Color("#B4CADA"), "low": Color("#4A6278"), "deep": Color("#060C16"), "floor": Color("#13253C"),
				"line": Color("#7E98AE"), "glint": Color(0.82, 0.93, 1.0)}
		4:
			return {"wall": Color("#4A3A34"), "low": Color("#1E1210"), "deep": Color("#0A0302"), "floor": Color("#2E0C05"),
				"line": Color("#1A1110"), "glint": Color(1.0, 0.5, 0.15)}
		6:
			return {"wall": Color("#5A5E4C"), "low": Color("#1F271E"), "deep": Color("#020604"), "floor": Color("#0C1C12"),
				"line": Color("#262A20"), "glint": Color(0.8, 1.0, 0.7)}
		7:
			return {"wall": Color("#6E3328"), "low": Color("#241A1C"), "deep": Color("#01080C"), "floor": Color("#0A2E36"),
				"line": Color("#2A1A16"), "glint": Color(0.6, 1.0, 0.95)}
		8:
			return {"wall": Color("#56525A"), "low": Color("#1E1A22"), "deep": Color("#040208"), "floor": Color("#1A0E26"),
				"line": Color("#2A2630"), "glint": Color(0.8, 0.65, 1.0)}
		_:
			return {"wall": Color("#8C8270"), "low": Color("#2A2622"), "deep": Color("#010204"), "floor": Color("#08101E"),
				"line": Color("#3A342C"), "glint": Toon.WASHI}


## Fosses de la salle dans les vides intérieurs `voids` (Rect2, cf. arena.gd void_rects).
## Renvoie l'état à passer à animate_pits() à chaque image (vide si rien à animer).
static func build_pits(world_id: int, parent: Node3D, rects: Array, voids: Array, rng_seed: int) -> Dictionary:
	var state := {}
	if voids.is_empty():
		return state
	var wid := clampi(world_id, 1, WORLDS.size())
	var rng := _rng(rng_seed * 23 + wid * 5 + 1)
	var sty := _pit_style(wid)
	var wide: Array = []
	var narrow: Array = []
	for r in rects:
		var rr: Rect2 = r
		if minf(rr.size.x, rr.size.y) < PIT_BRIDGE_W:
			narrow.append(rr)
		else:
			wide.append(rr)
	var segs := _pit_segments(voids, wide, rng)
	var root := Node3D.new()
	root.name = "Pits"
	parent.add_child(root)
	var st := _vc_begin()
	var gl := _vc_begin()
	for v in voids:
		var vr: Rect2 = v
		_pit_grid(st, vr, segs, wide, sty)
	var ctx := {"rng": rng, "voids": voids, "segs": segs, "wide": wide, "narrow": narrow, "sty": sty,
		"st": st, "gl": gl, "glow": 0, "bs": {}, "embers": []}
	_pit_details(wid, ctx)
	_pit_flush(root, st, _wmat("pit", -3, false), "PitDepth")
	var n_glow: int = ctx["glow"]
	if n_glow > 0:
		var gm := _wmat("pit_glow_%d" % wid, -2, true)
		_pit_flush(root, gl, gm, "PitGlow")
		state["glow"] = gm
		state["pulse"] = 1.6 if wid == 4 else 0.8
	var bs: Dictionary = ctx["bs"]
	_flush(bs, root, false)
	var embers: Array = ctx["embers"]
	if not embers.is_empty():
		_pit_embers(root, embers)
	return state


## Pouls des lueurs des fosses (reflets qui scintillent, lave qui respire) : un paramètre de matériau.
static func animate_pits(state: Dictionary, t: float) -> void:
	if not state.has("glow"):
		return
	var m: StandardMaterial3D = state["glow"]
	var k: float = state["pulse"]
	m.albedo_color = Color(1, 1, 1, 0.7 + 0.22 * sin(t * k) + 0.08 * sin(t * k * 2.7 + 1.3))


## Aplat sans lumière à couleurs de sommets avec alpha (fosses) ; `prio` ordonne les nappes transparentes.
static func _wmat(key: String, prio: int, additive: bool) -> StandardMaterial3D:
	if _mats.has(key):
		var cached: StandardMaterial3D = _mats[key]
		return cached
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.render_priority = prio
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mats[key] = m
	return m


static func _pit_flush(root: Node3D, st: SurfaceTool, mat: Material, nm: String) -> void:
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


## Bords plateforme / fosse : [a, b, côté, hauteur de paroi visible, phase] ; côté 0 = plateforme au nord,
## 1 = au sud (paroi cachée), 2 = à l'ouest, 3 = à l'est (paroi visible seulement si elle regarde la caméra).
static func _pit_segments(voids: Array, wide: Array, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for v in voids:
		var vr: Rect2 = v
		for r in wide:
			var rr: Rect2 = r
			var x0 := maxf(vr.position.x, rr.position.x)
			var x1 := minf(vr.end.x, rr.end.x)
			if x1 - x0 > 0.02:
				if absf(rr.end.y - vr.position.y) < 0.01:
					_seg_add(out, Vector2(x0, vr.position.y), Vector2(x1, vr.position.y), 0)
				elif absf(rr.position.y - vr.end.y) < 0.01:
					_seg_add(out, Vector2(x0, vr.end.y), Vector2(x1, vr.end.y), 1)
			var z0 := maxf(vr.position.y, rr.position.y)
			var z1 := minf(vr.end.y, rr.end.y)
			if z1 - z0 > 0.02:
				if absf(rr.end.x - vr.position.x) < 0.01:
					_seg_add(out, Vector2(vr.position.x, z0), Vector2(vr.position.x, z1), 2)
				elif absf(rr.position.x - vr.end.x) < 0.01:
					_seg_add(out, Vector2(vr.end.x, z0), Vector2(vr.end.x, z1), 3)
	for s in out:
		var sg: Array = s
		var a: Vector2 = sg[0]
		var kind: int = sg[2]
		var band := 0.0
		if kind == 0:
			band = PIT_WALL_N
		elif kind == 2 and a.x < -0.2:
			band = 0.08 + 0.07 * -a.x
		elif kind == 3 and a.x > 0.2:
			band = 0.08 + 0.07 * a.x
		sg.append(band)
		sg.append(rng.randf() * TAU)
	return out


## Ajoute un bord, fusionné avec un bord colinéaire du même côté qui le chevauche (plateformes superposées).
static func _seg_add(out: Array, a: Vector2, b: Vector2, kind: int) -> void:
	var horiz := kind < 2
	for s in out:
		var sg: Array = s
		var k: int = sg[2]
		if k != kind:
			continue
		var sa: Vector2 = sg[0]
		var sb: Vector2 = sg[1]
		if horiz and absf(sa.y - a.y) < 0.01 and a.x <= sb.x + 0.01 and b.x >= sa.x - 0.01:
			sg[0] = Vector2(minf(sa.x, a.x), a.y)
			sg[1] = Vector2(maxf(sb.x, b.x), a.y)
			return
		if not horiz and absf(sa.x - a.x) < 0.01 and a.y <= sb.y + 0.01 and b.y >= sa.y - 0.01:
			sg[0] = Vector2(a.x, minf(sa.y, a.y))
			sg[1] = Vector2(a.x, maxf(sb.y, b.y))
			return
	out.append([a, b, kind])


## Normale d'un bord, dirigée vers la fosse.
static func _seg_n(kind: int) -> Vector2:
	match kind:
		0:
			return Vector2(0, 1)
		1:
			return Vector2(0, -1)
		2:
			return Vector2(1, 0)
	return Vector2(-1, 0)


## Hauteur de paroi le long du bord : bas de paroi irrégulier (roche, terre, glace).
static func _band_at(band: float, along: float, ph: float) -> float:
	return band * (1.0 + 0.16 * sin(along * 8.3 + ph) + 0.08 * sin(along * 21.0 + ph * 0.5))


## 1 en haut d'une paroi visible, 0 à son pied (ou hors paroi).
static func _pit_wall(p: Vector2, segs: Array) -> float:
	var w := 0.0
	for s in segs:
		var sg: Array = s
		var band: float = sg[3]
		if band <= 0.0:
			continue
		var a: Vector2 = sg[0]
		var b: Vector2 = sg[1]
		var kind: int = sg[2]
		var d := -1.0
		var along := 0.0
		if kind == 0:
			if p.x >= a.x - 0.02 and p.x <= b.x + 0.02:
				d = p.y - a.y
				along = p.x
		elif kind == 2:
			if p.y >= a.y - 0.02 and p.y <= b.y + 0.02:
				d = p.x - a.x
				along = p.y
		else:
			if p.y >= a.y - 0.02 and p.y <= b.y + 0.02:
				d = a.x - p.x
				along = p.y
		if d < -0.001:
			continue
		var ph: float = sg[4]
		w = maxf(w, 1.0 - d / _band_at(band, along, ph))
	return clampf(w, 0.0, 1.0)


static func _rect_dist(r: Rect2, p: Vector2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, p.x - r.end.x), 0.0)
	var dz := maxf(maxf(r.position.y - p.y, p.y - r.end.y), 0.0)
	return sqrt(dx * dx + dz * dz)


static func _plat_dist(wide: Array, p: Vector2) -> float:
	var d := 99.0
	for r in wide:
		var rr: Rect2 = r
		d = minf(d, _rect_dist(rr, p))
	return d


## Couleur d'un point de fosse : paroi (haut clair -> pied sombre), gouffre près des bords,
## fond lointain un peu plus clair au large, fondu vers la mer aux bords ouverts de l'arène.
static func _pit_col(p: Vector2, segs: Array, wide: Array, sty: Dictionary) -> Color:
	var deep: Color = sty["deep"]
	var flo: Color = sty["floor"]
	var col := deep.lerp(flo, smoothstep(0.4, 2.0, _plat_dist(wide, p)) * 0.9)
	var w := _pit_wall(p, segs)
	if w > 0.0:
		var low: Color = sty["low"]
		var top: Color = sty["wall"]
		var cw := deep.lerp(low, w * 2.0)
		if w >= 0.5:
			cw = low.lerp(top, (w - 0.5) * 2.0)
		col = col.lerp(cw, clampf(w * 3.0, 0.0, 1.0))
	var s := minf(PIT_HALF.x - absf(p.x), PIT_HALF.y - absf(p.y))
	col.a = 0.95 * clampf((s + PIT_FADE) / (PIT_FADE + 0.45), 0.0, 1.0)
	return col


## Abscisses de la grille d'une fosse : pas de 0.22, resserré près des bords (dégradé de paroi),
## prolongé de PIT_FADE hors du cadre de l'arène là où la fosse est ouverte sur la mer.
static func _pit_axis(lo: float, hi: float, ext_lo: bool, ext_hi: bool) -> PackedFloat32Array:
	var vals: Array = []
	var a := lo - (PIT_FADE if ext_lo else 0.0)
	var b := hi + (PIT_FADE if ext_hi else 0.0)
	var x := a
	while x < b - 0.001:
		vals.append(x)
		x += 0.22
	vals.append(b)
	vals.append(lo)
	vals.append(hi)
	for o in [0.05, 0.11, 0.18, 0.27, 0.38, 0.5, 0.64, 0.8]:
		var of := float(o)
		if lo + of < hi:
			vals.append(lo + of)
		if hi - of > lo:
			vals.append(hi - of)
	vals.sort()
	var out := PackedFloat32Array()
	for v in vals:
		var f := float(v)
		if out.is_empty() or f - out[out.size() - 1] > 0.02:
			out.append(f)
	return out


static func _pit_grid(st: SurfaceTool, v: Rect2, segs: Array, wide: Array, sty: Dictionary) -> void:
	var xs := _pit_axis(v.position.x, v.end.x, v.position.x <= -PIT_HALF.x + 0.01, v.end.x >= PIT_HALF.x - 0.01)
	var zs := _pit_axis(v.position.y, v.end.y, v.position.y <= -PIT_HALF.y + 0.01, v.end.y >= PIT_HALF.y - 0.01)
	var nx := xs.size()
	var nz := zs.size()
	var cols: Array = []
	for j in nz:
		for i in nx:
			cols.append(_pit_col(Vector2(xs[i], zs[j]), segs, wide, sty))
	for j in nz - 1:
		for i in nx - 1:
			var c00: Color = cols[j * nx + i]
			var c10: Color = cols[j * nx + i + 1]
			var c11: Color = cols[(j + 1) * nx + i + 1]
			var c01: Color = cols[(j + 1) * nx + i]
			_vquad(st, Vector3(xs[i], PIT_Y, zs[j]), Vector3(xs[i + 1], PIT_Y, zs[j]),
				Vector3(xs[i + 1], PIT_Y, zs[j + 1]), Vector3(xs[i], PIT_Y, zs[j + 1]), c00, c10, c11, c01)


## Fuseau plat le long de `pts` (plan XZ, hauteur y) : largeur w0 -> w1 (+ `belly` au milieu),
## couleur c0 -> c1 ; `fade` : extrémités fondues.
static func _wribbon(st: SurfaceTool, pts: PackedVector2Array, y: float, w0: float, w1: float, c0: Color, c1: Color, belly := 0.0, fade := false) -> void:
	var n := pts.size()
	if n < 2:
		return
	var pl := Vector3.ZERO
	var pr := Vector3.ZERO
	var pc := c0
	for i in n:
		var t := float(i) / float(n - 1)
		var d := pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		var nr := Vector2(-d.y, d.x).normalized() * (0.5 * (lerpf(w0, w1, t) + belly * sin(PI * t)))
		var col := c0.lerp(c1, t)
		if fade:
			col.a *= clampf(sin(PI * t) * 2.5, 0.0, 1.0)
		var l := Vector3(pts[i].x + nr.x, y, pts[i].y + nr.y)
		var r := Vector3(pts[i].x - nr.x, y, pts[i].y - nr.y)
		if i > 0:
			_vquad(st, pl, l, r, pr, pc, col, col, pc)
		pl = l
		pr = r
		pc = col


## Disque irrégulier (éventail) de couleur c_in au centre vers c_out au bord.
static func _wblob(st: SurfaceTool, rng: RandomNumberGenerator, c: Vector2, rx: float, rz: float, y: float, c_in: Color, c_out: Color, seg := 10) -> void:
	var rot := rng.randf() * TAU
	var cc := Vector3(c.x, y, c.y)
	var pts: Array[Vector3] = []
	for i in seg:
		var a := TAU * float(i) / float(seg)
		var k := rng.randf_range(0.85, 1.12)
		var q := Vector2(cos(a) * rx * k, sin(a) * rz * k).rotated(rot)
		pts.append(Vector3(c.x + q.x, y, c.y + q.y))
	for i in seg:
		_vtri(st, cc, pts[i], pts[(i + 1) % seg], c_in, c_out, c_out)


## Reflet en étoile à quatre branches effilées.
static func _sparkle(st: SurfaceTool, c: Vector2, s: float, y: float, col: Color) -> void:
	var clear := Color(col, 0.0)
	for k in 4:
		var d := Vector2.from_angle(PI * 0.5 * k) * s * (1.0 if k % 2 == 0 else 0.55)
		var side := Vector2(-d.y, d.x).normalized() * s * 0.15
		_vtri(st, Vector3(c.x + side.x, y, c.y + side.y), Vector3(c.x - side.x, y, c.y - side.y), Vector3(c.x + d.x, y, c.y + d.y), col, col, clear)


static func _pick_rect(rs: Array, rng: RandomNumberGenerator) -> Rect2:
	var total := 0.0
	for r in rs:
		var rr: Rect2 = r
		total += rr.get_area()
	var x := rng.randf() * total
	for r in rs:
		var rr: Rect2 = r
		x -= rr.get_area()
		if x <= 0.0:
			return rr
	var last: Rect2 = rs[rs.size() - 1]
	return last


## Point du fond de la fosse, à `dmin` des plateformes et hors des parois (NONE2 si rien).
static func _pit_pt(ctx: Dictionary, dmin: float) -> Vector2:
	var rng: RandomNumberGenerator = ctx["rng"]
	var voids: Array = ctx["voids"]
	var wide: Array = ctx["wide"]
	var segs: Array = ctx["segs"]
	for attempt in 10:
		var v := _pick_rect(voids, rng)
		var p := Vector2(rng.randf_range(v.position.x, v.end.x), rng.randf_range(v.position.y, v.end.y))
		if _plat_dist(wide, p) >= dmin and _pit_wall(p, segs) < 0.05:
			return p
	return NONE2


## Points le long des bords plateforme / fosse (hors des bouts de passerelle) : [point, normale, côté].
static func _pit_edge_pts(ctx: Dictionary, spacing: float, hidden_ok: bool) -> Array:
	var rng: RandomNumberGenerator = ctx["rng"]
	var segs: Array = ctx["segs"]
	var narrow: Array = ctx["narrow"]
	var out: Array = []
	for s in segs:
		var sg: Array = s
		var a: Vector2 = sg[0]
		var b: Vector2 = sg[1]
		var kind: int = sg[2]
		if kind == 1 and not hidden_ok:
			continue
		var n := _seg_n(kind)
		var ln := a.distance_to(b)
		var t := rng.randf_range(0.15, 0.6) * spacing
		while t < ln - 0.12:
			var q := a.lerp(b, t / ln)
			var free := true
			for r in narrow:
				var rr: Rect2 = r
				if rr.grow(0.15).has_point(q + n * 0.1):
					free = false
					break
			if free:
				out.append([q, n, kind])
			t += spacing * rng.randf_range(0.6, 1.4)
	return out


## Point d'une paroi visible : à `frac` de sa hauteur, en `t` (0..1) le long du bord.
static func _wall_pt(sg: Array, t: float, frac: float) -> Vector2:
	var a: Vector2 = sg[0]
	var b: Vector2 = sg[1]
	var kind: int = sg[2]
	var band: float = sg[3]
	var ph: float = sg[4]
	var q := a.lerp(b, t)
	var along: float = q.x if kind == 0 else q.y
	return q + _seg_n(kind) * _band_at(band, along, ph) * frac


## Lignes parallèles au bord dans les parois visibles (strates, assises de pierre…), à `frac` de la hauteur.
static func _pit_lines(ctx: Dictionary, frac: float, w: float, col: Color) -> void:
	var st: SurfaceTool = ctx["st"]
	var segs: Array = ctx["segs"]
	for s in segs:
		var sg: Array = s
		var band: float = sg[3]
		if band < 0.14:
			continue
		var a: Vector2 = sg[0]
		var b: Vector2 = sg[1]
		var steps := maxi(int(a.distance_to(b) / 0.1), 2)
		var pts := PackedVector2Array()
		for i in steps + 1:
			pts.append(_wall_pt(sg, float(i) / steps, frac))
		_wribbon(st, pts, PIT_Y + 0.002, w, w, col, col, 0.0, true)


## Coulures le long des parois visibles : glaçons (fins pointus), encre (gouttes), mousse, fissures.
## `fn` : 0 = glaçon, 1 = coulure d'encre, 2 = mousse, 3 = fissure de braise (nappe additive).
static func _pit_drips(ctx: Dictionary, spacing: float, fn: int, col: Color) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var segs: Array = ctx["segs"]
	var st: SurfaceTool = ctx["st"]
	var gl: SurfaceTool = ctx["gl"]
	for s in segs:
		var sg: Array = s
		var band: float = sg[3]
		if band < 0.14:
			continue
		var a: Vector2 = sg[0]
		var b: Vector2 = sg[1]
		var ln := a.distance_to(b)
		var tg := (b - a).normalized()
		var t := rng.randf_range(0.1, 0.5) * spacing
		while t < ln - 0.08:
			var u := t / ln
			var q := _wall_pt(sg, u, 0.0)
			var y := PIT_Y + 0.003
			match fn:
				0:
					var tip := _wall_pt(sg, u, rng.randf_range(0.2, 0.65))
					var hw := rng.randf_range(0.025, 0.055)
					_vtri(st, Vector3(q.x + tg.x * hw, y, q.y + tg.y * hw), Vector3(q.x - tg.x * hw, y, q.y - tg.y * hw),
						Vector3(tip.x, y, tip.y), col, col, Color(col, col.a * 0.3))
				1:
					var tip := _wall_pt(sg, u, rng.randf_range(0.25, 0.8))
					_wribbon(st, PackedVector2Array([q, q.lerp(tip, 0.5) + tg * rng.randf_range(-0.02, 0.02), tip]), y,
						rng.randf_range(0.03, 0.05), 0.014, col, Color(col, col.a * 0.7))
					_wblob(st, rng, tip, 0.022, 0.03, y, col, Color(col, col.a * 0.6), 6)
				2:
					var c := _wall_pt(sg, u, rng.randf_range(0.03, 0.2))
					_wblob(st, rng, c, rng.randf_range(0.06, 0.14), rng.randf_range(0.04, 0.08), y, col, Color(col, 0.0), 7)
				_:
					var pts := PackedVector2Array([q])
					var fr := 0.0
					var side := 0.0
					while fr < 0.85:
						fr += rng.randf_range(0.12, 0.22)
						side += rng.randf_range(-0.05, 0.05)
						pts.append(_wall_pt(sg, u, minf(fr, 0.95)) + tg * side)
					_wribbon(gl, pts, PIT_Y + 0.004, 0.035, 0.006, col, Color(col, 0.0))
					ctx["glow"] = int(ctx["glow"]) + 1
			t += spacing * rng.randf_range(0.6, 1.5)


## Reflets lointains au fond de la fosse (nappe additive, scintillent avec animate_pits).
static func _pit_glints(ctx: Dictionary, per_m2: float, smin: float, smax: float) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var gl: SurfaceTool = ctx["gl"]
	var sty: Dictionary = ctx["sty"]
	var col: Color = sty["glint"]
	for i in int(_pit_area(ctx) * per_m2):
		var p := _pit_pt(ctx, 0.7)
		if p == NONE2:
			continue
		_sparkle(gl, p, rng.randf_range(smin, smax), PIT_Y + 0.004, Color(col, rng.randf_range(0.25, 0.6)))
		ctx["glow"] = int(ctx["glow"]) + 1


static func _pit_area(ctx: Dictionary) -> float:
	var voids: Array = ctx["voids"]
	var a := 0.0
	for v in voids:
		var vr: Rect2 = v
		a += vr.get_area()
	return a


## Pièce de bord qui dépasse dans la fosse : part du bord (point q, normale n), penche vers le bas.
static func _stub_xf(q: Vector2, n: Vector2, y: float, l: float, tilt: float, yaw_off: float) -> Transform3D:
	var bas := Basis(Vector3.UP, atan2(n.x, n.y) + yaw_off) * Basis(Vector3.RIGHT, tilt)
	var dir := bas * Vector3(0, 0, 1)
	return Transform3D(bas, Vector3(q.x, y, q.y) + dir * (l * 0.5 - 0.03))


## Détails propres au monde : lignes et coulures des parois, reflets ou lave au fond, bord cassé.
static func _pit_details(wid: int, ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var st: SurfaceTool = ctx["st"]
	var gl: SurfaceTool = ctx["gl"]
	var bs: Dictionary = ctx["bs"]
	var sty: Dictionary = ctx["sty"]
	var line: Color = sty["line"]
	var area := _pit_area(ctx)
	match wid:
		1:
			# strates de terre, épaves au fond, reflets de l'eau tout en bas ; planches arrachées au bord
			_pit_lines(ctx, 0.3, 0.03, Color(line, 0.6))
			_pit_lines(ctx, 0.58, 0.022, Color(line, 0.45))
			for i in int(area / 3.0):
				var p := _pit_pt(ctx, 0.6)
				if p == NONE2:
					continue
				var d := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.1, 0.16)
				_wribbon(st, PackedVector2Array([p - d, p + d]), PIT_Y + 0.003, 0.05, 0.04, Color(Color("#2A2018"), 0.65), Color(Color("#2A2018"), 0.65))
			_pit_glints(ctx, 0.7, 0.05, 0.1)
			var wood := _toon(Color("#8E6B3E"), true, 0.012)
			for e in _pit_edge_pts(ctx, 0.42, true):
				var ea: Array = e
				var q: Vector2 = ea[0]
				var n: Vector2 = ea[1]
				if rng.randf() < 0.65:
					var l := rng.randf_range(0.16, 0.42)
					_add(bs, wood, _box(Vector3(rng.randf_range(0.07, 0.12), 0.045, l)),
						_stub_xf(q, n, -0.035, l, rng.randf_range(0.15, 0.55), rng.randf_range(-0.18, 0.18)))
				if rng.randf() < 0.45:
					var l2 := rng.randf_range(0.1, 0.2)
					var tg := Vector2(-n.y, n.x) * rng.randf_range(-0.08, 0.08)
					_add(bs, wood, _box(Vector3(0.025, 0.02, l2)),
						_stub_xf(q + tg, n, -0.03, l2, rng.randf_range(-0.25, 0.45), rng.randf_range(-0.7, 0.7)))
		2:
			# paroi maçonnée (assises et joints), mousse qui pend, reflets d'étoiles ; dalles ébréchées
			_pit_lines(ctx, 0.33, 0.026, Color(line, 0.7))
			_pit_lines(ctx, 0.66, 0.026, Color(line, 0.6))
			_pit_joints(ctx, Color(line, 0.6))
			_pit_drips(ctx, 0.5, 2, Color(Color("#3E5A3A"), 0.75))
			_pit_glints(ctx, 0.9, 0.04, 0.09)
			var stone := _toon(Color("#6E6A60"), true, 0.015)
			for e in _pit_edge_pts(ctx, 0.5, true):
				if rng.randf() < 0.4:
					continue
				var ea: Array = e
				var q: Vector2 = ea[0]
				var n: Vector2 = ea[1]
				var l := rng.randf_range(0.12, 0.2)
				_add(bs, stone, _box(Vector3(rng.randf_range(0.16, 0.28), 0.07, l)),
					_stub_xf(q, n, -0.06, l, rng.randf_range(0.1, 0.4), rng.randf_range(-0.25, 0.25)))
		3:
			# paroi de glace : glaçons, fissures claires, fond bleu nuit ; bourrelets de neige au bord
			_pit_lines(ctx, 0.45, 0.018, Color(line, 0.55))
			_pit_drips(ctx, 0.16, 0, Color(Color("#E8F2F8"), 0.85))
			_pit_cracks(ctx, Color(Color("#E6F0F6"), 0.5))
			_pit_glints(ctx, 0.6, 0.04, 0.08)
			var snow := _toon(SNOW, false)
			for e in _pit_edge_pts(ctx, 0.3, true):
				var ea: Array = e
				var q: Vector2 = ea[0]
				var n: Vector2 = ea[1]
				var r := rng.randf_range(0.08, 0.16)
				var tg := Vector2(-n.y, n.x) * rng.randf_range(-0.06, 0.06)
				var c := q + tg + n * r * 0.35
				_add(bs, snow, _ball(r, r * 0.55, 7, 3), _at(Vector3(c.x, -0.025, c.y), Vector3(0, rng.randf() * TAU, 0)))
		4:
			# basalte veiné de braise, lave qui respire au fond, liseré incandescent ; éclats noirs au bord
			_pit_lines(ctx, 0.4, 0.024, Color(line, 0.7))
			_pit_drips(ctx, 0.55, 3, Color(1.0, 0.45, 0.12, 0.8))
			_pit_rim_glow(ctx)
			var embers: Array = ctx["embers"]
			for i in int(area / 1.6) + 1:
				var p := _pit_pt(ctx, 0.45)
				if p == NONE2:
					continue
				var r := minf(_plat_dist(ctx["wide"], p) - 0.25, rng.randf_range(0.4, 0.9))
				_wblob(gl, rng, p, r, r * rng.randf_range(0.6, 0.9), PIT_Y + 0.003, Color(1.0, 0.42, 0.1, 0.5), Color(0.9, 0.2, 0.04, 0.0), 12)
				_wblob(gl, rng, p, r * 0.35, r * 0.25, PIT_Y + 0.005, Color(1.0, 0.75, 0.35, 0.45), Color(1.0, 0.45, 0.1, 0.0), 8)
				ctx["glow"] = int(ctx["glow"]) + 1
				embers.append(Vector3(p.x, PIT_Y + 0.05, p.y))
			var basalt := _toon(BASALT, true, 0.015)
			for e in _pit_edge_pts(ctx, 0.45, true):
				if rng.randf() < 0.35:
					continue
				var ea: Array = e
				var q: Vector2 = ea[0]
				var n: Vector2 = ea[1]
				var l := rng.randf_range(0.12, 0.28)
				_add(bs, basalt, _box(Vector3(rng.randf_range(0.08, 0.14), 0.06, l)),
					_stub_xf(q, n, -0.05, l, rng.randf_range(0.3, 0.7), rng.randf_range(-0.3, 0.3)))
		6, 7, 8:
			_pit_new(wid, ctx)
		_:
			# encre : coulures sur la paroi de papier, lavis pâles au fond ; bord de papier déchiré
			_pit_lines(ctx, 0.5, 0.02, Color(line, 0.5))
			_pit_drips(ctx, 0.3, 1, Color(Toon.SUMI, 0.85))
			for i in int(area / 4.0):
				var p := _pit_pt(ctx, 0.8)
				if p == NONE2:
					continue
				var d := Vector2.from_angle(rng.randf_range(-0.4, 0.4))
				var l := minf(_plat_dist(ctx["wide"], p) - 0.2, rng.randf_range(0.5, 1.1))
				var pts := PackedVector2Array()
				for k in 7:
					var u := float(k) / 6.0 - 0.5
					pts.append(p + d * u * l * 2.0 + Vector2(-d.y, d.x) * sin(u * 5.0) * 0.06)
				_wribbon(gl, pts, PIT_Y + 0.004, 0.02, 0.01, Color(Toon.WASHI, 0.14), Color(Toon.WASHI, 0.1), 0.06, true)
				ctx["glow"] = int(ctx["glow"]) + 1
			_pit_glints(ctx, 0.35, 0.03, 0.06)
			var paper := _toon(Color("#E9DFC9"), false)
			for e in _pit_edge_pts(ctx, 0.3, true):
				if rng.randf() < 0.3:
					continue
				var ea: Array = e
				var q: Vector2 = ea[0]
				var n: Vector2 = ea[1]
				var l := rng.randf_range(0.08, 0.2)
				_add(bs, paper, _box(Vector3(rng.randf_range(0.1, 0.2), 0.012, l)),
					_stub_xf(q, n, -0.012, l, rng.randf_range(0.2, 0.6), rng.randf_range(-0.4, 0.4)))


## Joints verticaux entre les assises de pierre (décalés d'une assise à l'autre).
static func _pit_joints(ctx: Dictionary, col: Color) -> void:
	var st: SurfaceTool = ctx["st"]
	var segs: Array = ctx["segs"]
	for s in segs:
		var sg: Array = s
		var band: float = sg[3]
		if band < 0.3:
			continue
		var a: Vector2 = sg[0]
		var b: Vector2 = sg[1]
		var ln := a.distance_to(b)
		for row in 3:
			var off: float = 0.0 if row % 2 == 0 else 0.25
			var x := 0.2 + off
			while x < ln - 0.1:
				var u := x / ln
				var p0 := _wall_pt(sg, u, row * 0.33 + 0.02)
				var p1 := _wall_pt(sg, u, row * 0.33 + 0.31)
				_wribbon(st, PackedVector2Array([p0, p1]), PIT_Y + 0.002, 0.022, 0.022, col, col)
				x += 0.5


## Fissures claires qui partent du haut des parois de glace.
static func _pit_cracks(ctx: Dictionary, col: Color) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var st: SurfaceTool = ctx["st"]
	var segs: Array = ctx["segs"]
	for s in segs:
		var sg: Array = s
		var band: float = sg[3]
		if band < 0.3:
			continue
		var a: Vector2 = sg[0]
		var b: Vector2 = sg[1]
		var ln := a.distance_to(b)
		var tg := (b - a).normalized()
		var t := rng.randf_range(0.2, 0.8)
		while t < ln - 0.2:
			var u := t / ln
			var pts := PackedVector2Array([_wall_pt(sg, u, 0.02)])
			var side := 0.0
			for k in 4:
				side += rng.randf_range(-0.08, 0.08)
				pts.append(_wall_pt(sg, u, 0.15 + k * 0.17) + tg * side)
			_wribbon(st, pts, PIT_Y + 0.003, 0.02, 0.006, col, Color(col, 0.1))
			t += rng.randf_range(0.6, 1.3)


## Liseré de braise le long des bords (sauf ceux cachés par la plateforme) + halo plus large.
static func _pit_rim_glow(ctx: Dictionary) -> void:
	var gl: SurfaceTool = ctx["gl"]
	var segs: Array = ctx["segs"]
	for s in segs:
		var sg: Array = s
		var kind: int = sg[2]
		if kind == 1:
			continue
		var a: Vector2 = sg[0]
		var b: Vector2 = sg[1]
		var n := _seg_n(kind)
		var steps := maxi(int(a.distance_to(b) / 0.15), 2)
		var p1 := PackedVector2Array()
		var p2 := PackedVector2Array()
		for i in steps + 1:
			var q := a.lerp(b, float(i) / steps)
			var wob := 0.015 * sin(q.x * 13.0 + q.y * 11.0)
			p1.append(q + n * (0.04 + wob))
			p2.append(q + n * 0.12)
		_wribbon(gl, p2, PIT_Y + 0.003, 0.2, 0.2, Color(1.0, 0.35, 0.08, 0.28), Color(1.0, 0.35, 0.08, 0.28), 0.0, true)
		_wribbon(gl, p1, PIT_Y + 0.005, 0.035, 0.035, Color(1.0, 0.62, 0.22, 0.85), Color(1.0, 0.62, 0.22, 0.85), 0.0, true)
		ctx["glow"] = int(ctx["glow"]) + 1


## Braises qui montent du fond des fosses de lave.
static func _pit_embers(root: Node3D, pts: Array) -> void:
	var p := CPUParticles3D.new()
	p.name = "PitEmbers"
	root.add_child(p)
	p.local_coords = false
	p.amount = clampi(pts.size() * 4, 6, 20)
	p.lifetime = 1.8
	p.preprocess = 1.8
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	p.emission_points = PackedVector3Array(pts)
	p.mesh = _quad_mesh("ember", Vector2(0.07, 0.07), true)
	p.direction = Vector3.UP
	p.spread = 20.0
	p.gravity = Vector3(0.05, 0.12, 0.0)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.6
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 0.6, 1.0])
	g.colors = PackedColorArray([Color(1.0, 0.85, 0.5, 0.0), Color(1.0, 0.8, 0.45, 1.0), Color(1.0, 0.45, 0.15, 0.8), Color(0.5, 0.1, 0.05, 0.0)])
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = true


# ================================================================== mondes 6 à 8
# Kurama (forêt de cèdres des tengu), Ryūgū-jō (palais du roi dragon sous la mer),
# Yomi (pays des morts). Mêmes règles que les mondes 1 à 5 : lointain en un maillage à couleurs de
# sommets, props fusionnés par matériau, éléments répétés en MultiMesh, peu de lumières.

const CEDAR_BARK := Color("#5A3A2A")
const CEDAR_A := Color("#2E4A34")
const CEDAR_B := Color("#3A5A40")
const MOSS_K := Color("#3E5A3A")
const KURAMA_RED := Color("#B8352A")
const CORAL := [Color("#D9705E"), Color("#E39A6A"), Color("#C2456A"), Color("#E8B04A")]
const PALACE_RED := Color("#B8452E")
const SEA_DEEP := Color("#0E3A44")
const ASH := Color("#6E6A70")
const ASH_DARK := Color("#4A464E")
const BONE := Color("#D8D2C4")
const YOMI_GLOW := Color("#B9A8E8")

# --- lointain

## Monde 6 : mont Kurama. Ciel de brume verte, chaînes boisées en couches, temple vermillon et pagode
## sur la crête, escalier de pierre sous une allée de torii, corbeaux ; cèdres géants (sugi) sur des îlots de mousse, grand
## masque de tengu sur la falaise, torii vermillon et lanternes du chemin des racines.
static func _backdrop_kurama(root: Node3D) -> void:
	var rng := _rng(66)
	var st := _vc_begin()
	_vrect(st, Vector3(-340, -2, -252), Vector3(340, 26, -252), Color("#D9DDC8"), Color("#C6CFBD"))
	_vrect(st, Vector3(-340, 26, -252), Vector3(340, 160, -252), Color("#C6CFBD"), Color("#6E8278"))
	# soleil voilé de brume à droite sous le titre, halo peint dans le ciel
	var sky: Array = [-2.0, Color("#D9DDC8"), 26.0, Color("#C6CFBD"), 160.0, Color("#6E8278")]
	var sh := _hp(0.82, 0.285, -246.0)
	var halo := _sky_at(sh.y, sky)
	_vdisc(st, sh, 15.0, halo.lerp(Color("#F4F2DE"), 0.35), halo, 28)
	_vdisc(st, _hp(0.82, 0.285, -236.0), 8.5, Color("#F6F4E2"), Color("#EEEDD6"), 28)
	_ridge(st, rng, -280.0, 280.0, -215.0, -1.0, 15.0, Color("#8A9C8C"), Color("#C9D2BF"), 34)
	_ridge(st, rng, -260.0, 260.0, -190.0, -1.0, 11.0, Color("#5C7362"), Color("#B9C4B0"), 34)
	_sil_trees(st, rng, -200.0, 200.0, -186.0, 3.0, 60, 6.0, Color("#4A6152"), Color(0, 0, 0, 0))
	# le mont Kurama, à gauche du héros, boisé jusqu'à la cime ; collines basses dans la brume
	var pk := _hp(0.4, 0.285, -165.0)
	_sil_mount(st, Vector3(pk.x, -1.0, -165.0), 40.0, pk.y + 1.0, 1.3, 0.04, Color("#3E5848"), Color("#7E9282"), Color("#33493A"), 0.22, 26)
	_sil_trees(st, rng, pk.x - 22.0, pk.x + 22.0, -164.0, 6.0, (16 if Toon.lite else 26), 4.5, Color("#2E4434"), Color(0, 0, 0, 0))
	for i in 6:
		var h := rng.randf_range(10.0, 16.0)
		_sil_mount(st, Vector3(-120.0 + i * 40.0 + rng.randf_range(-8.0, 8.0), -1.0, rng.randf_range(-155.0, -140.0)),
			h * 1.5, h, 1.1, 0.03, Color("#4E6656"), Color("#7E9282"), Color(0, 0, 0, 0), 0.0, 14)
	_ridge(st, rng, -220.0, 220.0, -134.0, -1.0, 7.5, Color("#33493A"), Color("#A9B6A2"), 30)
	_sil_trees(st, rng, -160.0, 160.0, -130.0, 2.5, 90, 6.0, Color("#26392C"), Color(0, 0, 0, 0))
	# Kurama-dera sur la crête, à droite du héros : grand hall vermillon, pagode, escalier sous les torii
	var tx := _hp(0.66, 0.0, -129.0).x + 22.0
	_sil_temple(st, Vector3(tx - 22.0, 6.5, -129.0), 3.6, Color("#9A3324"), Color("#22201E"), Color(0, 0, 0, 0))
	_sil_pagoda(st, Vector3(tx - 4.0, 6.0, -128.5), 2.0, 3, Color("#8E2A1E"), Color("#22201E"), Color(0, 0, 0, 0))
	# escalier de pierre qui monte au temple
	for k in 14:
		var t := float(k) / 13.0
		var c := Vector3(tx + lerpf(-12.0, -20.0, t), lerpf(-0.5, 6.4, t), -127.5)
		var hw := 1.6 - 0.6 * t
		_vrect(st, c - Vector3(hw, 0.14, 0), c + Vector3(hw, 0.14, 0), Color("#8F8C80"), Color("#A7A496"))
	# allée de torii vermillon qui gravit l'escalier, lanternes de pierre à son pied
	for k in 5:
		var t := float(k) / 4.0
		_sil_torii(st, Vector3(tx + lerpf(-12.6, -19.4, t), lerpf(-0.45, 6.2, t), -127.2), 0.62 - 0.12 * t, Color("#9A3324"))
	for sx: float in [-1.0, 1.0]:
		_sil_toro(st, Vector3(tx - 12.0 + sx * 2.6, -0.5, -127.0), 0.9, Color("#8F8C80"), Color("#F2D58A"))
	# brumes basses entre les plans
	for k in (4 if Toon.lite else 6):
		_kasumi(st, Vector3(rng.randf_range(-90.0, 90.0), 2.4 + k * 1.5 + rng.randf_range(-0.5, 0.5), -116.0 - k * 7.0),
			rng.randf_range(40.0, 90.0), rng.randf_range(0.9, 1.6), Color("#E6EADB"), Color("#C9D2BF"))
	# corbeaux dans le ciel libre
	_flock(st, rng, _hp(0.25, 0.17, -90.0), 8, Vector3(9, 2.5, 4), 1.1, Color("#141416"))
	_flock(st, rng, _hp(0.62, 0.21, -110.0), 5, Vector3(6, 2, 3), 1.5, Color("#1E1E22"))
	# deux grandes bandes de brume (kasumi) devant la forêt
	_kasumi(st, Vector3(0, 3.0, -70), 160.0, 1.6, Color("#EEF0E4"), Color("#DCE2D2"))
	_kasumi(st, Vector3(10, 5.5, -95), 120.0, 1.1, Color("#EEF0E4"), Color("#DCE2D2"))
	# cèdres géants dans la brume au bord droit de l'accueil (silhouettes : le pied fond dans la brume)
	for cv: Vector3 in [Vector3(0.98, 0.1, -70.0), Vector3(0.93, 0.19, -88.0)]:
		var cb := _hp(cv.x, 0.0, cv.z)
		var ct := _hp(cv.x, cv.y, cv.z)
		_sil_cedar(st, Vector3(cb.x, -1.0, cv.z), ct.y + 1.0, Color("#22362A"), Color("#B9C4B0"))
	_vc_end(st, root)
	# cèdres géants sur leurs îlots de mousse
	var b := {}
	var bn := {}
	var moss := _toon(MOSS_K, true, 0.02)
	var spots: Array[Vector3] = [Vector3(-13.0, VOID_Y, -16.0), Vector3(-17.5, VOID_Y, -25.0), Vector3(13.5, VOID_Y, -18.0),
		Vector3(18.5, VOID_Y, -28.0), Vector3(-12.5, VOID_Y, -6.0), Vector3(12.8, VOID_Y, -4.0), Vector3(-14.0, VOID_Y, 4.0),
		Vector3(14.5, VOID_Y, 5.0), Vector3(-24.0, VOID_Y, -37.0), Vector3(14.0, VOID_Y, -41.0), Vector3(-25.0, VOID_Y, -45.0),
		Vector3(27.0, VOID_Y, -52.0)]  # les plus lointains encadrent l'accueil (ni devant le mont ni devant le soleil)
	for p in spots:
		var s := rng.randf_range(1.7, 2.4)
		_add(b, moss, _ball(1.0, 0.5, 10, 4), _at(p, Vector3.ZERO, Vector3(1.6 * s * 0.6, 0.6, 1.6 * s * 0.6)))
		_cedar_into(b, _at(p + Vector3(0, 0.1, 0), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * s), rng)
	# torii vermillon du chemin, lanternes de pierre sur rochers moussus
	Decor.torii_into(b, _at(Vector3(0, VOID_Y, -28.0), Vector3.ZERO, Vector3.ONE * 1.05), -0.6)
	for sx: float in [-1.0, 1.0]:
		_add(b, moss, _ball(0.8, 0.5, 8, 4), _at(Vector3(sx * 4.4, VOID_Y, -26.5)))
		Decor.stone_lantern_into(b, bn, _at(Vector3(sx * 4.4, VOID_Y + 0.2, -26.5), Vector3.ZERO, Vector3.ONE * 1.05))
	# falaise et grand masque de tengu qui veille sur la forêt
	var cliff := _at(Vector3(-21.0, VOID_Y, -58.0), Vector3(0, 0.4, 0))
	Decor.rock_into(b, cliff * _at(Vector3.ZERO, Vector3.ZERO, Vector3(6.0, 9.0, 5.0)), 661, Color("#5E6A5A"))
	_tengu_mask_into(b, bn, cliff * _at(Vector3(0.0, 2.1, 2.5), Vector3.ZERO, Vector3.ONE * 2.6))
	Decor.rock_into(b, _at(Vector3(23.0, VOID_Y, -64.0), Vector3(0, -0.5, 0), Vector3(5.0, 7.0, 4.0)), 662, Color("#56604F"))
	_hauchiwa_into(b, _at(Vector3(22.0, VOID_Y + 3.6, -61.5), Vector3(-0.2, -0.4, 0.3), Vector3.ONE * 2.2))
	for k in 6:
		_crow_into(b, _at(Vector3(rng.randf_range(-16.0, 16.0), VOID_Y + rng.randf_range(0.6, 1.2), rng.randf_range(-34.0, -20.0)), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * 0.9))
	_flush(b, root, true)
	_flush(bn, root, false)


## Monde 7 : Ryūgū-jō. Lumière bleu-vert qui descend de la surface, récifs en couches, palais du roi
## dragon (toits d'or, murs vermillon) sur la crête, rayons de lumière, bancs de poissons, tortues ;
## près de l'arène : coraux, bénitiers à perle, forêts de varech, porte vermillon du palais.
static func _backdrop_ryugu(root: Node3D) -> void:
	var rng := _rng(77)
	var st := _vc_begin()
	_vrect(st, Vector3(-340, -2, -252), Vector3(340, 30, -252), Color("#2A6268"), Color("#4E9496"))
	_vrect(st, Vector3(-340, 30, -252), Vector3(340, 160, -252), Color("#4E9496"), Color("#A9D6CF"))
	# perle de lumière (le soleil vu sous la mer) à droite sous le titre, son halo peint dans le ciel
	var sky: Array = [-2.0, Color("#2A6268"), 30.0, Color("#4E9496"), 160.0, Color("#A9D6CF")]
	var ph := _hp(0.84, 0.285, -240.0)
	var halo := _sky_at(ph.y, sky)
	_vdisc(st, ph, 15.0, halo.lerp(Color(0.95, 1.0, 0.95), 0.25), halo, 32)
	_vdisc(st, _hp(0.84, 0.285, -205.0), 7.5, Color("#F4F1EA"), Color("#E4ECE4"), 32)
	_ridge(st, rng, -280.0, 280.0, -212.0, -1.0, 13.0, Color("#2E6A6E"), Color("#3E8084"), 34)
	# mont de corail à gauche, cime rosée ; le palais du roi dragon sur la crête, à droite du héros
	var pk := _hp(0.25, 0.29, -175.0)
	_sil_mount(st, Vector3(pk.x, -1.0, -175.0), 38.0, pk.y + 1.0, 1.35, 0.05, Color("#245A60"), Color("#3E8084"), Color("#D9705E"), 0.16, 26)
	_ridge(st, rng, -260.0, 260.0, -186.0, -1.0, 10.0, Color("#1E4E54"), Color("#357478"), 34)
	_sil_temple(st, Vector3(0.0, 6.0, -183.0), 6.5, Color("#B8452E"), Color("#C49A45"), Color(0, 0, 0, 0))
	_sil_pagoda(st, Vector3(-28.0, 5.0, -182.5), 3.4, 5, Color("#A63C28"), Color("#C49A45"), Color("#F2D58A"))
	_sil_pagoda(st, Vector3(_hp(0.98, 0.0, -182.5).x, 5.0, -182.5), 3.0, 4, Color("#A63C28"), Color("#C49A45"), Color("#F2D58A"))
	_ridge(st, rng, -220.0, 220.0, -130.0, -1.0, 5.0, Color("#163E44"), Color("#2C6A6E"), 30)
	# bancs de poissons et tortues dans l'eau libre, à gauche (loin de la perle)
	for k in 6:
		_school(st, rng, _hp(rng.randf_range(0.06, 0.6), rng.randf_range(0.2, 0.32), rng.randf_range(-120.0, -70.0)), 12, 1.0, Color("#1E4A52"))
	for k in 3:
		var face: float = -1.0 if rng.randf() < 0.5 else 1.0
		_sil_turtle(st, _hp(0.12 + k * 0.22, rng.randf_range(0.16, 0.24), -100.0 - k * 12.0), rng.randf_range(2.0, 3.2), Color("#1A3E44"), face)
	# brumes de sable en suspens, basses
	for k in 3:
		_kasumi(st, Vector3(rng.randf_range(-90.0, 30.0), 1.8 + k * 1.4, -140.0 - k * 10.0), rng.randf_range(50.0, 90.0), 0.9, Color("#5FA3A2"), Color("#4E9496"))
	_vc_end(st, root)
	# rayons de lumière obliques qui tombent de la surface (transparents : un seul lot, un draw call)
	var rays := {}
	var rm := _flat(Color(0.9, 1.0, 0.95, 0.06))
	for k in (4 if Toon.lite else 7):
		_add(rays, rm, _box(Vector3(rng.randf_range(4.0, 9.0), 120, 0.1)),
			_at(Vector3(-80.0 + k * 26.0 + rng.randf_range(-6.0, 6.0), 40.0, -150.0 - k * 4.0), Vector3(0, 0, 0.28)))
	_flush(rays, root)
	# récifs proches : coraux, bénitiers, varech
	var b := {}
	var bn := {}
	var rock := Color("#3E5E60")
	var reefs: Array[Vector3] = [Vector3(-13.0, VOID_Y, -15.0), Vector3(13.5, VOID_Y, -17.0), Vector3(-17.0, VOID_Y, -27.0),
		Vector3(18.0, VOID_Y, -30.0), Vector3(-12.5, VOID_Y, -3.0), Vector3(13.0, VOID_Y, 2.0), Vector3(-6.0, VOID_Y, -38.0),
		Vector3(9.0, VOID_Y, -44.0)]
	for i in reefs.size():
		var p: Vector3 = reefs[i]
		var s := rng.randf_range(1.6, 2.4)
		Decor.rock_into(b, _at(p, Vector3.ZERO, Vector3(s, s * 0.8, s)), 770 + i, rock)
		for k in rng.randi_range(2, 4):
			var col: Color = CORAL[rng.randi_range(0, CORAL.size() - 1)]
			var q := p + Vector3(rng.randf_range(-0.6, 0.6) * s, 0.3 * s, rng.randf_range(-0.6, 0.6) * s)
			_coral_into(b, _at(q, Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * rng.randf_range(1.2, 1.9)), rng, col)
		if i % 3 == 0:
			_clam_into(b, bn, _at(p + Vector3(0.8 * s, 0.05, 0.6 * s), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * 1.3))
	for k in 10:
		var sx: float = -1.0 if k % 2 == 0 else 1.0
		_kelp_into(b, _at(Vector3(sx * rng.randf_range(10.5, 15.0), VOID_Y, rng.randf_range(-24.0, 8.0))), rng, rng.randf_range(4.0, 7.0))
	# porte du palais : torii vermillon aux lanternes de pierre, tortue de pierre
	Decor.torii_into(b, _at(Vector3(0, VOID_Y, -27.0), Vector3.ZERO, Vector3.ONE * 1.1), -0.6)
	for sx: float in [-1.0, 1.0]:
		Decor.rock_into(b, _at(Vector3(sx * 4.6, VOID_Y, -26.0), Vector3.ZERO, Vector3(1.3, 0.9, 1.3)), 790 + int(sx), rock)
		Decor.stone_lantern_into(b, bn, _at(Vector3(sx * 4.6, VOID_Y + 0.35, -26.0), Vector3.ZERO, Vector3.ONE * 1.05))
	_kame_into(b, bn, _at(Vector3(-20.0, VOID_Y + 0.2, -50.0), Vector3(0, 0.6, 0), Vector3.ONE * 3.2))
	_flush(b, root, true)
	_flush(bn, root, false)


## Monde 8 : Yomi. Ciel violet presque noir, chaînes de cendre, pins morts en silhouette, procession
## de lanternes au loin, le rocher de Yomotsu Hirasaka ; près de l'arène : pins morts sur des
## buttes de cendre, stèles, torii brisé, lanternes flottantes sur le fleuve des morts.
static func _backdrop_yomi(root: Node3D) -> void:
	var rng := _rng(88)
	var st := _vc_begin()
	_vrect(st, Vector3(-340, -2, -252), Vector3(340, 24, -252), Color("#5A4A66"), Color("#3A3442"))
	_vrect(st, Vector3(-340, 24, -252), Vector3(340, 160, -252), Color("#3A3442"), Color("#120E18"))
	_ridge(st, rng, -280.0, 280.0, -215.0, -1.0, 15.0, Color("#2E2A36"), Color("#4A4452"), 34)
	# la pente de Yomotsu Hirasaka : grand mont de cendre à gauche, crête pâle sous la lune
	var pk := _hp(0.27, 0.29, -170.0)
	_sil_mount(st, Vector3(pk.x, -1.0, -170.0), 40.0, pk.y + 1.0, 1.3, 0.04, Color("#4A4258"), Color("#2A2632"), Color("#6E6480"), 0.12, 26)
	_ridge(st, rng, -260.0, 260.0, -190.0, -1.0, 10.0, Color("#221E28"), Color("#3E3846"), 34)
	_sil_dead_trees(st, rng, -180.0, 180.0, -186.0, 4.0, 40, 7.0, Color("#1A1720"))
	_ridge(st, rng, -220.0, 220.0, -130.0, -1.0, 5.0, Color("#16131A"), Color("#2E2A34"), 30)
	_sil_dead_trees(st, rng, -140.0, 140.0, -127.0, 1.5, 50, 5.0, Color("#0E0C12"))
	# torii noirs sur la pente, une lanterne pâle au pied de chacun
	for k in 4:
		var x := -60.0 + k * 38.0 + rng.randf_range(-6.0, 6.0)
		var y := 2.0 + rng.randf_range(0.0, 2.0)
		_sil_torii(st, Vector3(x, y, -126.0), 1.75, Color("#0A080C"))
		_sil_toro(st, Vector3(x + 3.2, y, -125.8), 1.1, Color("#0A080C"), Color("#C9B8E8"))
	# procession de lanternes pâles qui descend vers le fleuve
	for i in 26:
		var t := float(i) / 25.0
		var c := Vector3(lerpf(-50.0, 10.0, t), 1.5 + 6.0 * (1.0 - t) + sin(t * 8.0) * 1.0, -98.0)
		_vrect(st, c - Vector3(0.3, 0.42, 0), c + Vector3(0.3, 0.42, 0), Color("#C9B8E8"), Color("#F0E8FF"))
	# brumes basses sur le fleuve des morts
	for k in 5:
		_band(st, Vector3(rng.randf_range(-90.0, 90.0), 2.0 + k * 1.3 + rng.randf_range(-0.4, 0.4), -112.0 - k * 7.0),
			rng.randf_range(40.0, 90.0), rng.randf_range(0.8, 1.4), Color("#5E5468"), Color("#3E3846"))
	_flock(st, rng, _hp(0.36, 0.18, -90.0), 6, Vector3(8, 2.5, 4), 1.2, Color("#0A080C"))
	# lune pâle voilée, à droite sous le titre (halo peint dans le ciel), et le grand rocher qui ferme le
	# passage (Chibiki-iwa)
	var sky: Array = [-2.0, Color("#5A4A66"), 24.0, Color("#3A3442"), 160.0, Color("#120E18")]
	var mh := _hp(0.83, 0.28, -244.0)
	var halo := _sky_at(mh.y, sky)
	_vdisc(st, mh, 16.0, halo.lerp(Color(0.8, 0.7, 1.0), 0.22), halo, 32)
	_vdisc(st, _hp(0.83, 0.28, -210.0), 8.0, Color("#D9D0E6"), Color("#CBC0DC"), 32)
	_vellipse(st, Vector3(-34, 4.0, -150), 14.0, 11.0, Color("#2A2630"), Color("#221E28"), 18)
	_vc_end(st, root)
	# buttes de cendre, pins morts, stèles, torii brisé
	var b := {}
	var bn := {}
	var mounds: Array[Vector3] = [Vector3(-13.0, -16.0, 2.4), Vector3(13.5, -18.0, 2.2), Vector3(-17.0, -28.0, 3.0),
		Vector3(18.0, -30.0, 3.0), Vector3(-12.5, -4.0, 1.8), Vector3(13.0, 1.0, 1.8), Vector3(-6.0, -38.0, 2.6), Vector3(8.0, -42.0, 2.8)]
	var gm := _toon(Color("#7A7680"), true, 0.02)
	var gcap := _toon(Color("#5E5A64"), false)
	for i in mounds.size():
		var m: Vector3 = mounds[i]
		var top := _ash_mound_into(b, Vector2(m.x, m.y), m.z, rng)
		var c := Vector3(m.x, top - 0.08, m.y)
		if i % 2 == 0:
			_dead_pine_into(b, _at(c, Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * rng.randf_range(1.6, 2.2)), rng)
		else:
			for k in 3:
				var q := c + Vector3((k - 1) * 0.6, 0, rng.randf_range(-0.3, 0.3))
				_stele_into(b, gm, gcap, _at(q, Vector3(rng.randf_range(-0.1, 0.1), rng.randf_range(-0.3, 0.3), rng.randf_range(-0.12, 0.12)), Vector3.ONE * 1.1))
			_sotoba_into(b, _at(c + Vector3(0, 0, -0.7)), rng)
	# torii brisé au bord du fleuve
	var tx := _at(Vector3(0, VOID_Y, -27.0))
	var pillar := _toon(Color("#3A3440"), true, 0.03)
	_add(b, pillar, _cyl(0.28, 0.32, 4.2, 10), tx * _at(Vector3(-2.2, 2.1, 0)))
	_add(b, pillar, _cyl(0.28, 0.32, 2.2, 10), tx * _at(Vector3(2.2, 1.1, 0), Vector3(0, 0, -0.08)))
	_add(b, pillar, _box(Vector3(5.8, 0.4, 0.5)), tx * _at(Vector3(-0.4, 3.0, 0.2), Vector3(0.1, 0.2, -0.55)))
	_add(b, pillar, _box(Vector3(1.6, 0.35, 0.45)), tx * _at(Vector3(2.6, 0.2, 0.9), Vector3(0.0, 0.5, 0.1)))
	for sx: float in [-1.0, 1.0]:
		_add(b, _toon(ASH_DARK, true, 0.02), _cyl(0.5, 0.6, 0.8, 6), _at(Vector3(sx * 4.4, VOID_Y + 0.05, -26.0)))
		Decor.stone_lantern_into(b, bn, _at(Vector3(sx * 4.4, VOID_Y + 0.45, -26.0), Vector3.ZERO, Vector3.ONE * 1.05))
	_flush(b, root, true)
	# lanternes flottantes sur le fleuve des morts
	for i in 26:
		var p := Vector3(rng.randf_range(-16.0, 16.0), VOID_Y, rng.randf_range(-36.0, -13.0))
		if rng.randf() < 0.35:
			var sx: float = -1.0 if rng.randf() < 0.5 else 1.0
			p = Vector3(sx * rng.randf_range(9.5, 14.0), VOID_Y, rng.randf_range(-11.0, 6.0))
		var near := false
		for m in mounds:
			var mm: Vector3 = m
			if Vector2(p.x - mm.x, p.z - mm.y).length() < mm.z * 1.15:
				near = true
				break
		if not near:
			_toro_into(bn, _at(p, Vector3(0, rng.randf() * TAU, 0)))
	_flush(bn, root, false)


# --- silhouettes du lointain

## Poisson en silhouette (losange et queue), tourné vers `facing` (±1).
static func _fish(st: SurfaceTool, p: Vector3, s: float, col: Color, facing: float) -> void:
	var f := facing
	_vquad(st, p + Vector3(-0.5 * s * f, 0, 0), p + Vector3(0, 0.22 * s, 0), p + Vector3(0.55 * s * f, 0, 0), p + Vector3(0, -0.22 * s, 0), col, col, col, col)
	_vtri(st, p + Vector3(-0.45 * s * f, 0, 0), p + Vector3(-0.85 * s * f, 0.25 * s, 0), p + Vector3(-0.85 * s * f, -0.25 * s, 0), col, col, col)


## Banc de poissons qui nagent dans le même sens.
static func _school(st: SurfaceTool, rng: RandomNumberGenerator, c: Vector3, n: int, s: float, col: Color) -> void:
	var f: float = -1.0 if rng.randf() < 0.5 else 1.0
	for i in n:
		var p := c + Vector3(rng.randf_range(-6.0, 6.0), rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0))
		_fish(st, p, s * rng.randf_range(0.7, 1.2), col, f)


## Tortue de mer en silhouette : carapace en dôme, tête, nageoires.
static func _sil_turtle(st: SurfaceTool, p: Vector3, s: float, col: Color, facing: float) -> void:
	var n := 10
	for k in n:
		var a0 := PI * float(k) / n
		var a1 := PI * float(k + 1) / n
		_vtri(st, p, p + Vector3(cos(a0) * s, sin(a0) * s * 0.55, 0), p + Vector3(cos(a1) * s, sin(a1) * s * 0.55, 0), col, col, col)
	var hc := p + Vector3(facing * s * 1.15, s * 0.12, 0)
	_vquad(st, hc + Vector3(-0.25 * s, -0.12 * s, 0), hc + Vector3(0.2 * s, -0.1 * s, 0), hc + Vector3(0.22 * s, 0.1 * s, 0), hc + Vector3(-0.25 * s, 0.14 * s, 0), col, col, col, col)
	_vtri(st, p + Vector3(facing * s * 0.5, 0, 0), p + Vector3(facing * s * 1.1, -0.6 * s, 0), p + Vector3(facing * s * 0.1, -0.05 * s, 0), col, col, col)
	_vtri(st, p + Vector3(-facing * s * 0.5, 0, 0), p + Vector3(-facing * s * 1.0, -0.4 * s, 0), p + Vector3(-facing * s * 0.8, 0.0, 0), col, col, col)


## Arbres morts en silhouette : tronc penché, branches nues.
static func _sil_dead_trees(st: SurfaceTool, rng: RandomNumberGenerator, x0: float, x1: float, z: float, y0: float, n: int, h: float, col: Color) -> void:
	for i in n:
		var b := Vector3(rng.randf_range(x0, x1), y0 + rng.randf_range(-0.3, 0.4), z + rng.randf_range(-1.0, 1.0))
		var hh := h * rng.randf_range(0.6, 1.3)
		var top := b + Vector3(rng.randf_range(-0.25, 0.25) * hh, hh, 0)
		_vstroke(st, b, top, hh * 0.07, col)
		for k in 3:
			var q := b.lerp(top, rng.randf_range(0.45, 0.85))
			var sx: float = -1.0 if k % 2 == 0 else 1.0
			_vstroke(st, q, q + Vector3(sx * hh * rng.randf_range(0.2, 0.4), hh * rng.randf_range(0.05, 0.25), 0), hh * 0.035, col)


# --- modèles (ajoutés aux lots, placés par `xf`)

## Cèdre du Japon (sugi) : tronc roux droit, étages coniques sombres.
static func _cedar_into(b: Dictionary, xf: Transform3D, rng: RandomNumberGenerator) -> void:
	var bark := _toon(CEDAR_BARK, true, 0.025)
	var g1 := _toon(CEDAR_A, true, 0.025)
	var g2 := _toon(CEDAR_B, true, 0.025)
	var h := rng.randf_range(4.2, 5.4)
	_add(b, bark, _cyl(0.12, 0.26, h, 7), xf * _at(Vector3(0, h * 0.5, 0)))
	for k in 5:
		var t := float(k) / 4.0
		var r := lerpf(1.25, 0.35, t)
		var hh := lerpf(1.3, 0.8, t)
		var gm: StandardMaterial3D = g1 if k % 2 == 0 else g2
		_add(b, gm, _cyl(0.0, r, hh, 7), xf * _at(Vector3(0, lerpf(h * 0.42, h + 0.2, t), 0), Vector3(0, k * 0.5, 0)))


## Jeune cèdre (instancié en masse dans le remplissage) : deux étages coniques sur un fût court.
static func _sapling_into(b: Dictionary, xf: Transform3D) -> void:
	_add(b, _toon(CEDAR_BARK, true, 0.02), _cyl(0.05, 0.08, 0.6, 5), xf * _at(Vector3(0, 0.3, 0)))
	_add(b, _toon(CEDAR_A, true, 0.02), _cyl(0.0, 0.42, 0.7, 6), xf * _at(Vector3(0, 0.75, 0)))
	_add(b, _toon(CEDAR_B, true, 0.02), _cyl(0.0, 0.3, 0.55, 6), xf * _at(Vector3(0, 1.1, 0), Vector3(0, 0.4, 0)))


## Masque de tengu : visage vermillon au long nez, sourcils blancs, yeux d'or, tokin noir ; regarde vers +Z local.
static func _tengu_mask_into(b: Dictionary, bn: Dictionary, xf: Transform3D) -> void:
	var face := _toon(KURAMA_RED)
	var brow := _toon(Color("#EFE6D2"), true, 0.02)
	var ink := _toon(Toon.SUMI, false)
	var eye := _glow(Toon.GOLD, 1.2)
	_add(b, face, _ball(0.5, 1.1, 10, 6), xf * _at(Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, 0.45)))
	_limb(b, face, Vector3(0, -0.02, 0.18), Vector3(0, -0.12, 0.95), 0.14, 0.05, 7, xf)
	for sx: float in [-1.0, 1.0]:
		_limb(b, brow, Vector3(sx * 0.08, 0.22, 0.22), Vector3(sx * 0.36, 0.3, 0.12), 0.07, 0.03, 5, xf)
		_add(bn, eye, _ball(0.06, 0.08, 6, 3), xf * _at(Vector3(sx * 0.17, 0.1, 0.22)))
	_add(bn, ink, _box(Vector3(0.36, 0.05, 0.05)), xf * _at(Vector3(0, -0.3, 0.2)))
	_add(b, _toon(Color("#1E1C20")), _box(Vector3(0.22, 0.16, 0.2)), xf * _at(Vector3(0, 0.5, 0.08)))


## Éventail de plumes du tengu (hauchiwa) : manche, plumes en éventail ; plan local XY.
static func _hauchiwa_into(b: Dictionary, xf: Transform3D) -> void:
	var wood := _toon(Color("#3B2E25"), true, 0.015)
	var feather := _toon(Color("#2E2A30"), true, 0.015)
	var tip := _toon(Color("#EFE6D2"), false)
	_add(b, wood, _cyl(0.025, 0.03, 0.5, 5), xf * _at(Vector3(0, 0.25, 0)))
	for k in 9:
		var a := deg_to_rad(-60.0 + 15.0 * k)
		var d := Vector3(sin(a), cos(a), 0)
		_limb(b, feather, Vector3(0, 0.5, 0), Vector3(0, 0.5, 0) + d * 0.62, 0.05, 0.09, 4, xf)
		_add(b, tip, _ball(0.06, 0.05, 5, 3), xf * _at(Vector3(0, 0.5, 0) + d * 0.66))


## Corbeau posé : corps noir, tête, bec d'or, queue ; regarde vers +Z local.
static func _crow_into(b: Dictionary, xf: Transform3D) -> void:
	var black := _toon(Color("#1E1C22"), true, 0.015)
	_add(b, black, _ball(0.12, 0.2, 7, 3), xf * _at(Vector3(0, 0.14, 0), Vector3(0.3, 0, 0), Vector3(1, 1, 1.5)))
	_add(b, black, _ball(0.07, 0.13, 6, 3), xf * _at(Vector3(0, 0.27, 0.13)))
	_limb(b, _toon(Toon.GOLD, false), Vector3(0, 0.27, 0.18), Vector3(0, 0.25, 0.3), 0.03, 0.0, 4, xf)
	_limb(b, black, Vector3(0, 0.12, -0.12), Vector3(0, 0.08, -0.32), 0.06, 0.02, 4, xf)


## Îlot de mousse (ellipsoïde vert) ; renvoie la hauteur du sommet.
static func _moss_mound_into(b: Dictionary, p: Vector2, r: float, rng: RandomNumberGenerator) -> float:
	var moss := _toon(MOSS_K, true, 0.02)
	var sz := rng.randf_range(0.8, 1.15)
	_add(b, moss, _ball(r, r * 0.6, 10, 4), _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3(1, 1, sz)))
	return VOID_Y + r * 0.28


## Corail branchu : rameaux coniques, bouts plus clairs.
static func _coral_into(b: Dictionary, xf: Transform3D, rng: RandomNumberGenerator, col: Color) -> void:
	var m := _toon(col, true, 0.018)
	var tip := _toon(col.lightened(0.3), false)
	for k in rng.randi_range(4, 7):
		var a := rng.randf() * TAU
		var base := Vector3(cos(a) * 0.12, 0.0, sin(a) * 0.12)
		var mid := base + Vector3(cos(a) * rng.randf_range(0.1, 0.3), rng.randf_range(0.35, 0.6), sin(a) * rng.randf_range(0.1, 0.3))
		var top := mid + Vector3(cos(a + 0.6) * rng.randf_range(0.05, 0.2), rng.randf_range(0.2, 0.45), sin(a + 0.6) * rng.randf_range(0.05, 0.2))
		_limb(b, m, base, mid, 0.07, 0.05, 5, xf)
		_limb(b, m, mid, top, 0.05, 0.03, 5, xf)
		_add(b, tip, _ball(0.05, 0.1, 5, 3), xf * _at(top))
		if rng.randf() < 0.6:
			_limb(b, m, mid, mid + Vector3(cos(a - 1.0) * 0.2, 0.18, sin(a - 1.0) * 0.2), 0.035, 0.02, 4, xf)


## Bénitier géant entrouvert et sa perle lumineuse.
static func _clam_into(b: Dictionary, bn: Dictionary, xf: Transform3D) -> void:
	var shell := _toon(Color("#C9B9A6"), true, 0.02)
	var lip := _toon(Color("#E7C9C0"), false)
	_add(b, shell, _ball(0.5, 0.3, 10, 4), xf * _at(Vector3(0, 0.05, 0), Vector3.ZERO, Vector3(1, 1, 0.8)))
	_add(b, shell, _ball(0.5, 0.3, 10, 4), xf * _at(Vector3(0, 0.3, -0.24), Vector3(-0.9, 0, 0), Vector3(1, 1, 0.8)))
	_add(bn, lip, _cyl(0.42, 0.42, 0.03, 12), xf * _at(Vector3(0, 0.12, 0), Vector3.ZERO, Vector3(1, 1, 0.75)))
	_add(bn, _glow(Color("#F4F1EA"), 1.6), _ball(0.13, 0.26, 8, 4), xf * _at(Vector3(0, 0.24, 0.05)))


## Varech : quelques lanières qui ondulent vers la surface (hauteur `h`).
static func _kelp_into(b: Dictionary, xf: Transform3D, rng: RandomNumberGenerator, h: float) -> void:
	var g := _toon(Color("#4E6E3A"), true, 0.015)
	var g2 := _toon(Color("#6A7E3A"), true, 0.015)
	for k in rng.randi_range(3, 5):
		var a := rng.randf() * TAU
		var prev := Vector3(cos(a) * 0.25, 0, sin(a) * 0.25)
		var hh := h * rng.randf_range(0.6, 1.0)
		var ph := rng.randf() * TAU
		var gm: StandardMaterial3D = g if k % 2 == 0 else g2
		for j in 6:
			var t := float(j + 1) / 6.0
			var q := Vector3(cos(a) * 0.25 + sin(t * 5.0 + ph) * 0.35, hh * t, sin(a) * 0.25 + cos(t * 4.0 + ph) * 0.2)
			_limb(b, gm, prev, q, 0.07 * (1.0 - t * 0.5), 0.06 * (1.0 - t * 0.5), 4, xf)
			prev = q


## Tortue de pierre (kame) : carapace à écailles, tête tendue, nageoires ; stèle sur le dos.
static func _kame_into(b: Dictionary, bn: Dictionary, xf: Transform3D) -> void:
	var stone := _toon(Color("#6E7A74"), true, 0.025)
	var dark := _toon(Color("#4A5652"), false)
	_add(b, stone, _ball(0.75, 0.7, 10, 5), xf * _at(Vector3(0, 0.25, 0), Vector3.ZERO, Vector3(1, 1, 1.25)))
	for k in 6:
		var a := TAU * k / 6.0
		_add(bn, dark, _cyl(0.16, 0.16, 0.02, 6), xf * _at(Vector3(cos(a) * 0.38, 0.52, sin(a) * 0.48), Vector3(cos(a) * 0.5, 0, sin(a) * 0.5)))
	_limb(b, stone, Vector3(0, 0.3, 0.8), Vector3(0, 0.45, 1.25), 0.2, 0.16, 6, xf)
	_add(b, stone, _ball(0.2, 0.32, 8, 4), xf * _at(Vector3(0, 0.48, 1.32)))
	for sx: float in [-1.0, 1.0]:
		_limb(b, stone, Vector3(sx * 0.55, 0.15, 0.5), Vector3(sx * 1.05, 0.05, 0.85), 0.14, 0.08, 5, xf)
		_limb(b, stone, Vector3(sx * 0.55, 0.15, -0.55), Vector3(sx * 0.9, 0.05, -0.9), 0.12, 0.07, 5, xf)
	_add(b, stone, _box(Vector3(0.5, 1.4, 0.16)), xf * _at(Vector3(0, 1.3, 0)))
	_add(bn, _toon(Toon.GOLD, false), _box(Vector3(0.06, 1.0, 0.17)), xf * _at(Vector3(0, 1.3, 0)))


## Butte de cendre (ellipsoïde gris) ; renvoie la hauteur du sommet.
static func _ash_mound_into(b: Dictionary, p: Vector2, r: float, rng: RandomNumberGenerator) -> float:
	var ash := _toon(ASH, true, 0.02)
	var sz := rng.randf_range(0.8, 1.15)
	_add(b, ash, _ball(r, r * 0.55, 10, 4), _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3(1, 1, sz)))
	return VOID_Y + r * 0.27


## Pin mort : tronc tordu gris, branches nues, quelques touffes d'aiguilles sèches.
static func _dead_pine_into(b: Dictionary, xf: Transform3D, rng: RandomNumberGenerator) -> void:
	var bark := _toon(Color("#4A4448"), true, 0.025)
	var dry := _toon(Color("#4A4E44"), true, 0.02)
	var p1 := Vector3(rng.randf_range(-0.3, 0.3), 1.1, rng.randf_range(-0.3, 0.3))
	var p2 := p1 + Vector3(rng.randf_range(-0.5, 0.5), 0.9, rng.randf_range(-0.5, 0.5))
	var p3 := p2 + Vector3(rng.randf_range(-0.6, 0.6), 0.6, rng.randf_range(-0.6, 0.6))
	_limb(b, bark, Vector3.ZERO, p1, 0.22, 0.16, 6, xf)
	_limb(b, bark, p1, p2, 0.16, 0.11, 6, xf)
	_limb(b, bark, p2, p3, 0.11, 0.04, 5, xf)
	for k in 4:
		var from: Vector3 = p1.lerp(p3, float(k) / 3.0)
		var a := rng.randf() * TAU
		var to := from + Vector3(cos(a) * rng.randf_range(0.5, 0.9), rng.randf_range(-0.1, 0.3), sin(a) * rng.randf_range(0.5, 0.9))
		_limb(b, bark, from, to, 0.06, 0.015, 4, xf)
		if k % 2 == 1:
			_add(b, dry, _ball(0.3, 0.12, 7, 3), xf * _at(to + Vector3(0, 0.04, 0)))


## Crânes et ossements posés au sol autour de `p` (hauteur `y`, étalement `spread`).
static func _bones_into(b: Dictionary, p: Vector2, rng: RandomNumberGenerator, y: float, spread := 1.0) -> void:
	var bone := _toon(BONE, true, 0.012)
	var ink := _toon(Toon.SUMI, false)
	for k in rng.randi_range(2, 3):
		var a := rng.randf() * TAU
		var c := Vector3(p.x + cos(a) * 0.3 * spread, y + 0.1, p.y + sin(a) * 0.3 * spread)
		var yaw := rng.randf() * TAU
		_add(b, bone, _ball(0.11, 0.2, 7, 4), _at(c, Vector3(0, yaw, 0)))
		var fwd := Vector3(sin(yaw), 0, cos(yaw))
		var side := Vector3(fwd.z, 0, -fwd.x)
		for sx: float in [-1.0, 1.0]:
			_add(b, ink, _ball(0.03, 0.04, 5, 3), _at(c + fwd * 0.09 + side * sx * 0.045 + Vector3(0, 0.02, 0)))
	for k in rng.randi_range(2, 4):
		var a := rng.randf() * TAU
		var q := Vector3(p.x + cos(a) * 0.4 * spread, y + 0.04, p.y + sin(a) * 0.4 * spread)
		var d := Vector3(cos(a + 1.3), 0, sin(a + 1.3)) * 0.2 * spread
		_limb(b, bone, q - d, q + d, 0.03, 0.03, 4)


# --- props autour de l'arène

static func _big_kurama(ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var face := _face(p, 0.0, p.y)
	var roll := rng.randf()
	if roll < 0.3:
		# cèdre sur son îlot de mousse, parfois un corbeau au pied
		var top := _moss_mound_into(bs, p, rng.randf_range(0.9, 1.3), rng)
		_cedar_into(bs, _at(Vector3(p.x, top - 0.05, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * rng.randf_range(0.75, 1.0)), rng)
		if rng.randf() < 0.4:
			_crow_into(bs, _at(Vector3(p.x + 0.6, top - 0.03, p.y + 0.4), Vector3(0, rng.randf() * TAU, 0)))
	elif roll < 0.44:
		# masque de tengu sur un poteau, devant un rocher moussu
		Decor.rock_into(bs, _at(Vector3(p.x, VOID_Y, p.y), Vector3.ZERO, Vector3.ONE * rng.randf_range(1.2, 1.6)), rng.randi() % 100000, Color("#5E6A5A"))
		var xf := _at(Vector3(p.x, VOID_Y + 0.3, p.y), Vector3(0, face, 0))
		_add(bs, _toon(Color("#3B2E25")), _box(Vector3(0.12, 1.9, 0.12)), xf * _at(Vector3(0, 0.95, 0)))
		_tengu_mask_into(bs, bn, xf * _at(Vector3(0, 1.75, 0.12), Vector3.ZERO, Vector3.ONE * 0.55))
	elif roll < 0.56 and _light_ok(ctx):
		var top := _moss_mound_into(bs, p, 0.9, rng)
		_stone_lantern(ctx, Vector3(p.x, top - 0.05, p.y), 0.85, true)
	elif roll < 0.68:
		# petit sanctuaire vermillon et son torii miniature
		var top := _moss_mound_into(bs, p, 1.1, rng)
		var fwd := Vector3(sin(face), 0, cos(face))
		Decor.hokora_into(bs, bn, _at(Vector3(p.x, top, p.y) - fwd * 0.3, Vector3(0, face, 0), Vector3.ONE * 0.85), Color("#9A3324"), Color("#2E2C33"))
		Decor.torii_into(bs, _at(Vector3(p.x, top, p.y) + fwd * 0.55, Vector3(0, face, 0), Vector3.ONE * 0.22), 0.0)
	elif roll < 0.8:
		# grand éventail de plumes planté dans un rocher, corbeaux autour
		Decor.rock_into(bs, _at(Vector3(p.x, VOID_Y, p.y), Vector3.ZERO, Vector3.ONE * 1.1), rng.randi() % 100000, Color("#5E6A5A"))
		_hauchiwa_into(bs, _at(Vector3(p.x, VOID_Y + 0.3, p.y), Vector3(rng.randf_range(-0.2, 0.2), face, rng.randf_range(-0.25, 0.25)), Vector3.ONE * 1.6))
		for k in rng.randi_range(1, 2):
			_crow_into(bs, _at(Vector3(p.x + rng.randf_range(-0.5, 0.5), VOID_Y + 0.42, p.y + rng.randf_range(-0.5, 0.5)), Vector3(0, rng.randf() * TAU, 0)))
	else:
		# bosquet de jeunes cèdres et rochers moussus
		_moss_mound_into(bs, p, rng.randf_range(1.0, 1.4), rng)
		for k in rng.randi_range(2, 4):
			var q := Vector3(p.x + rng.randf_range(-0.7, 0.7), VOID_Y + 0.15, p.y + rng.randf_range(-0.7, 0.7))
			_sapling_into(bs, _at(q, Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * rng.randf_range(0.9, 1.4)))


static func _fill_kurama(ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	var moss := _toon(MOSS_K, true, 0.02)
	for i in 30:
		var p := _ring_pt(ctx, rng, 0.4, 0.0, 6.0, true)
		if p == NONE2:
			continue
		var s := rng.randf_range(0.35, 1.0)
		if p.y > 6.5:
			s *= 0.6
		_inst(ctx, "moss", _ball(1.0, 0.5, 10, 4), moss, _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3(s, s * 0.7, s * rng.randf_range(0.8, 1.2))))
	var fern := _toon_ds(Color("#4F6E3E"))
	for i in 34:
		var p := _ring_pt(ctx, rng, 0.35, 0.0, 3.5, false)
		if p == NONE2:
			continue
		var s := rng.randf_range(0.8, 1.5)
		_inst(ctx, "reed", _tuft_mesh(), fern, _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3(s, s * 1.1, s)))
	var stem := _toon(CEDAR_BARK, true, 0.018)
	var cone := _toon(CEDAR_A, true, 0.02)
	for i in 14:
		var p := _ring_pt(ctx, rng, 0.9, 1.2, 6.5, false)
		if p == NONE2:
			continue
		var h := rng.randf_range(2.6, 4.2)
		_inst(ctx, "sugi_t", _cyl(0.07, 0.12, 1.0, 6), stem, _at(Vector3(p.x, VOID_Y + h * 0.5, p.y), Vector3.ZERO, Vector3(1, h, 1)))
		for k in 3:
			var r := 0.8 - k * 0.2
			_inst(ctx, "sugi_c", _cyl(0.0, 1.0, 1.0, 7), cone, _at(Vector3(p.x, VOID_Y + h * (0.55 + k * 0.2), p.y), Vector3(0, k * 0.6, 0), Vector3(r, 0.9 - k * 0.1, r)))
	var stone := _toon(STONE, true, 0.02)
	for i in 10:
		var p := _ring_pt(ctx, rng, 0.4, 0.0, 2.5, true)
		if p == NONE2:
			continue
		_inst(ctx, "step", _cyl(0.3, 0.34, 0.14, 7), stone, _at(Vector3(p.x, VOID_Y + 0.03, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * rng.randf_range(0.7, 1.2)))


static func _big_ryugu(ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var face := _face(p, 0.0, p.y)
	var roll := rng.randf()
	var rock := Color("#3E5E60")
	if roll < 0.3:
		# récif : rocher et coraux
		var s := rng.randf_range(1.0, 1.5)
		Decor.rock_into(bs, _at(Vector3(p.x, VOID_Y, p.y), Vector3.ZERO, Vector3(s, s * 0.7, s)), rng.randi() % 100000, rock)
		for k in rng.randi_range(2, 4):
			var col: Color = CORAL[rng.randi_range(0, CORAL.size() - 1)]
			var q := Vector3(p.x + rng.randf_range(-0.5, 0.5) * s, VOID_Y + 0.25 * s, p.y + rng.randf_range(-0.5, 0.5) * s)
			_coral_into(bs, _at(q, Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * rng.randf_range(0.8, 1.3)), rng, col)
	elif roll < 0.44:
		# bénitier et sa perle (lumière bleu-vert si le budget le permet)
		Decor.rock_into(bs, _at(Vector3(p.x, VOID_Y, p.y), Vector3.ZERO, Vector3(1.2, 0.5, 1.2)), rng.randi() % 100000, rock)
		var xf := _at(Vector3(p.x, VOID_Y + 0.18, p.y), Vector3(0, face, 0), Vector3.ONE * rng.randf_range(0.9, 1.2))
		_clam_into(bs, bn, xf)
		_light(ctx, xf * Vector3(0, 0.4, 0.1), Color(0.6, 1.0, 0.95), 0.6, 3.5)
	elif roll < 0.58:
		_kelp_into(bs, _at(Vector3(p.x, VOID_Y, p.y)), rng, rng.randf_range(2.6, 4.0))
		_coral_into(bs, _at(Vector3(p.x + 0.5, VOID_Y, p.y + 0.3)), rng, CORAL[rng.randi_range(0, CORAL.size() - 1)])
	elif roll < 0.7 and _ok(ctx, p, 1.4, 0.0):
		# tortue de pierre à stèle d'or
		_kame_into(bs, bn, _at(Vector3(p.x, VOID_Y + 0.1, p.y), Vector3(0, face, 0), Vector3.ONE * rng.randf_range(0.7, 0.9)))
	elif roll < 0.82:
		# lanterne du palais sur un socle de corail
		Decor.rock_into(bs, _at(Vector3(p.x, VOID_Y, p.y), Vector3.ZERO, Vector3(1.0, 0.6, 1.0)), rng.randi() % 100000, rock)
		if _light_ok(ctx):
			Decor.stone_lantern_into(bs, bn, _at(Vector3(p.x, VOID_Y + 0.25, p.y), Vector3.ZERO, Vector3.ONE * 0.85))
			_light(ctx, Vector3(p.x, VOID_Y + 0.95, p.y), Color(0.55, 1.0, 0.95), 0.6, 3.2)
		else:
			_coral_into(bs, _at(Vector3(p.x, VOID_Y + 0.25, p.y)), rng, CORAL[0])
	else:
		# colonnes du palais englouti, vermillon et or
		var red := _toon(PALACE_RED, true, 0.025)
		var gold := _toon(Toon.GOLD, true, 0.02)
		for k in rng.randi_range(1, 2):
			var q := Vector3(p.x + (k - 0.5) * 1.2, VOID_Y, p.y + rng.randf_range(-0.3, 0.3))
			var h := rng.randf_range(1.6, 2.8)
			_add(bs, red, _cyl(0.24, 0.26, h, 10), _at(q + Vector3(0, h * 0.5, 0), Vector3(rng.randf_range(-0.08, 0.08), 0, rng.randf_range(-0.08, 0.08))))
			_add(bs, gold, _cyl(0.32, 0.32, 0.12, 10), _at(q + Vector3(0, h, 0)))
		_coral_into(bs, _at(Vector3(p.x, VOID_Y, p.y + 0.6)), rng, CORAL[rng.randi_range(0, CORAL.size() - 1)])


static func _fill_ryugu(ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	var weed := _toon_ds(Color("#4E7A4A"))
	for i in 34:
		var p := _ring_pt(ctx, rng, 0.35, 0.0, 4.0, false)
		if p == NONE2:
			continue
		var s := rng.randf_range(0.8, 1.6)
		_inst(ctx, "weed", _tuft_mesh(), weed, _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3(s, s * 1.5, s)))
	var rock := _toon(Color("#3E5E60"), true, 0.02)
	for i in 26:
		var p := _ring_pt(ctx, rng, 0.4, 0.0, 6.0, true)
		if p == NONE2:
			continue
		var s := rng.randf_range(0.25, 0.7)
		_inst(ctx, "pebble", _ball(0.5, 0.5, 6, 3), rock, _at(Vector3(p.x, VOID_Y - 0.05, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3(s, s * 0.6, s)))
	for k in CORAL.size():
		var cm := _toon(CORAL[k], true, 0.018)
		for i in 5:
			var p := _ring_pt(ctx, rng, 0.45, 0.0, 5.0, true)
			if p == NONE2:
				continue
			var s := rng.randf_range(0.5, 0.9)
			_inst(ctx, "coral%d" % k, _ball(0.5, 0.6, 7, 3), cm, _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3(s, s * 0.8, s)))
	var foam := _flat(Color(0.85, 1.0, 0.98, 0.7))
	for i in 18:
		var p := _ring_pt(ctx, rng, 0.35, 0.0, 6.0, true)
		if p == NONE2:
			continue
		var s := rng.randf_range(0.6, 1.3)
		_inst(ctx, "foam", _crescent_mesh(), foam, _at(Vector3(p.x, VOID_Y + 0.012, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3(s, 1, s)))


static func _big_yomi(ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var face := _face(p, 0.0, p.y)
	var roll := rng.randf()
	var r := rng.randf_range(1.0, 1.4)
	var top := _ash_mound_into(bs, p, r, rng)
	var c := Vector3(p.x, top - 0.06, p.y)
	if roll < 0.28:
		_dead_pine_into(bs, _at(c, Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * rng.randf_range(0.8, 1.1)), rng)
	elif roll < 0.48:
		# stèles et planchettes sotoba
		var gm := _toon(Color("#7A7680"), true, 0.02)
		var cap := _toon(Color("#5E5A64"), false)
		for k in rng.randi_range(2, 3):
			var q := c + Vector3((k - 1) * 0.55 + rng.randf_range(-0.1, 0.1), 0, rng.randf_range(-0.3, 0.3))
			_stele_into(bs, gm, cap, _at(q, Vector3(rng.randf_range(-0.1, 0.1), face + rng.randf_range(-0.3, 0.3), rng.randf_range(-0.12, 0.12)), Vector3.ONE * rng.randf_range(0.8, 1.0)))
		_sotoba_into(bs, _at(c + Vector3(-sin(face), 0, -cos(face)) * 0.5, Vector3(0, face, 0)), rng)
	elif roll < 0.62 and _light_ok(ctx):
		Decor.stone_lantern_into(bs, bn, _at(c, Vector3.ZERO, Vector3.ONE * 0.9))
		_light(ctx, c + Vector3(0, 0.75, 0), Color(0.75, 0.6, 1.0), 0.6, 3.4)
	elif roll < 0.76:
		_bones_into(bs, p, rng, top - 0.08)
		_dead_pine_into(bs, _at(c + Vector3(0.4, 0, 0.2), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * 0.6), rng)
	elif roll < 0.88:
		# lanternes de papier pâles sur des perches
		for k in 2:
			var q := c + Vector3((k - 0.5) * 0.8, 0, 0)
			Decor.paper_lantern_into(bs, bn, _at(q, Vector3(0, face + PI * 0.5, 0)), Color("#D9D0E6"), 0.0)
	else:
		# jizō veilleurs aux bonnets sombres
		var side := Vector3(cos(face), 0, -sin(face))
		for k in 3:
			_jizo_into(bs, _at(c + side * (k - 1) * 0.5, Vector3(0, face, 0)))


static func _fill_yomi(ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	var bn: Dictionary = ctx["bn"]
	var ash := _toon(ASH, true, 0.02)
	for i in 36:
		var p := _ring_pt(ctx, rng, 0.35, 0.0, 6.0, true)
		if p == NONE2:
			continue
		var s := rng.randf_range(0.35, 1.2)
		if p.y > 6.5:
			s *= 0.6
		_inst(ctx, "ash", _ball(0.5, 0.36, 9, 4), ash, _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3(s, s * rng.randf_range(0.6, 1.0), s * rng.randf_range(0.8, 1.2))))
	var reed := _toon_ds(Color("#5A5660"))
	for i in 24:
		var p := _ring_pt(ctx, rng, 0.4, 0.0, 3.5, false)
		if p == NONE2:
			continue
		var s := rng.randf_range(0.8, 1.4)
		_inst(ctx, "reed", _tuft_mesh(), reed, _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3(s, s * 1.3, s)))
	var wisp := _glow(YOMI_GLOW, 1.4)
	for i in 10:
		var p := _ring_pt(ctx, rng, 0.5, 0.0, 5.0, false)
		if p == NONE2:
			continue
		_inst(ctx, "wisp", _ball(0.12, 0.24, 6, 3), wisp, _at(Vector3(p.x, VOID_Y + rng.randf_range(0.6, 1.6), p.y)))
	for i in rng.randi_range(6, 10):
		var p := _ring_pt(ctx, rng, 0.4, 0.0, 4.0, true)
		if p == NONE2:
			continue
		_toro_into(bn, _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, rng.randf() * TAU, 0)))


## Petits props de bord des mondes 6 à 8 (même règles que _prop_edge).
static func _edge_new(wid: int, ctx: Dictionary, p: Vector2, _out: Vector2, rng: RandomNumberGenerator, to_arena: float, arm_out: float, flag_rot: float, cloth: Color, ink: Color) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var pos := Vector3(p.x, 0.0, p.y)
	var roll := rng.randf()
	if roll > 0.88:
		Decor.nobori_into(bs, bn, _at(pos, Vector3(0, flag_rot, 0)), cloth, ink, VOID_Y - 0.35)
		return
	match wid:
		6:
			if roll < 0.2:
				Decor.paper_lantern_into(bs, bn, _at(pos, Vector3(0, arm_out, 0)), Color("#D9573F"), VOID_Y - 0.35)
				return
			_pillar(ctx, p, 0.22, Color("#4E5A48"))
			_add(bn, _toon(MOSS_K, false), _cyl(0.2, 0.235, 0.05, 8), _at(Vector3(p.x, -0.01, p.y)))
			if roll < 0.36 and _light_ok(ctx):
				_stone_lantern(ctx, pos, 0.6, true)
			elif roll < 0.52:
				_add(bs, _toon(Color("#3B2E25")), _box(Vector3(0.08, 1.0, 0.08)), _at(pos + Vector3(0, 0.5, 0)))
				_tengu_mask_into(bs, bn, _at(pos + Vector3(0, 0.9, 0), Vector3(0, to_arena, 0), Vector3.ONE * 0.4) * _at(Vector3(0, 0, 0.08)))
			elif roll < 0.66:
				_crow_into(bs, _at(pos, Vector3(0, to_arena, 0), Vector3.ONE * 1.2))
			elif roll < 0.78:
				Decor.hokora_into(bs, bn, _at(pos, Vector3(0, to_arena, 0), Vector3.ONE * 0.72), Color("#9A3324"), Color("#2E2C33"))
			else:
				_sapling_into(bs, _at(pos, Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * 0.8))
		7:
			_pillar(ctx, p, 0.22, Color("#3E5E60"))
			if roll < 0.24:
				_coral_into(bs, _at(pos, Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * 0.7), rng, CORAL[rng.randi_range(0, CORAL.size() - 1)])
			elif roll < 0.4 and _light_ok(ctx):
				Decor.stone_lantern_into(bs, bn, _at(pos, Vector3.ZERO, Vector3.ONE * 0.6))
				_light(ctx, pos + Vector3(0, 0.5, 0), Color(0.55, 1.0, 0.95), 0.55, 3.0)
			elif roll < 0.56:
				_clam_into(bs, bn, _at(pos, Vector3(0, to_arena, 0), Vector3.ONE * 0.55))
			elif roll < 0.72:
				var red := _toon(PALACE_RED, true, 0.02)
				_add(bs, red, _cyl(0.12, 0.13, 1.1, 8), _at(pos + Vector3(0, 0.55, 0)))
				_add(bs, _toon(Toon.GOLD, true, 0.015), _ball(0.13, 0.2, 8, 4), _at(pos + Vector3(0, 1.15, 0)))
			else:
				_kelp_into(bs, _at(pos), rng, 1.6)
		_:
			_pillar(ctx, p, 0.22, ASH_DARK)
			if roll < 0.22 and _light_ok(ctx):
				_stone_lantern(ctx, pos, 0.6, false)
				_light(ctx, pos + Vector3(0, 0.5, 0), Color(0.75, 0.6, 1.0), 0.55, 3.0)
			elif roll < 0.4:
				_stele_into(bs, _toon(Color("#7A7680"), true, 0.02), _toon(Color("#5E5A64"), false), _at(pos, Vector3(0, to_arena, 0.05), Vector3.ONE * 0.62))
			elif roll < 0.55:
				Decor.paper_lantern_into(bs, bn, _at(pos, Vector3(0, arm_out, 0)), Color("#D9D0E6"), VOID_Y - 0.35)
			elif roll < 0.7:
				_bones_into(bs, p, rng, 0.0, 0.4)
			else:
				_jizo_into(bs, _at(pos, Vector3(0, to_arena, 0), Vector3.ONE * 0.82))


## Petits props des vides entre plateformes, mondes 6 à 8.
static func _small_new(wid: int, ctx: Dictionary, p: Vector2, rng: RandomNumberGenerator, sd: int) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var roll := rng.randf()
	match wid:
		6:
			if roll < 0.5:
				Decor.rock_into(bs, _at(Vector3(p.x, VOID_Y, p.y), Vector3.ZERO, Vector3.ONE * rng.randf_range(0.55, 0.8)), sd, Color("#5E6A5A"))
				_add(bn, _toon(MOSS_K, false), _ball(0.3, 0.12, 7, 3), _at(Vector3(p.x, VOID_Y + 0.25, p.y)))
				if rng.randf() < 0.4:
					_crow_into(bs, _at(Vector3(p.x, VOID_Y + 0.3, p.y), Vector3(0, rng.randf() * TAU, 0)))
			else:
				var top := _moss_mound_into(bs, p, 0.6, rng)
				_sapling_into(bs, _at(Vector3(p.x, top - 0.05, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * rng.randf_range(0.8, 1.1)))
		7:
			if roll < 0.45:
				Decor.rock_into(bs, _at(Vector3(p.x, VOID_Y, p.y), Vector3.ZERO, Vector3.ONE * rng.randf_range(0.5, 0.75)), sd, Color("#3E5E60"))
				_coral_into(bs, _at(Vector3(p.x, VOID_Y + 0.2, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * 0.7), rng, CORAL[rng.randi_range(0, CORAL.size() - 1)])
			elif roll < 0.75:
				_clam_into(bs, bn, _at(Vector3(p.x, VOID_Y + 0.02, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * 0.7))
			else:
				_kelp_into(bs, _at(Vector3(p.x, VOID_Y, p.y)), rng, 1.4)
		_:
			if roll < 0.45:
				for k in rng.randi_range(2, 3):
					_toro_into(bn, _at(Vector3(p.x + rng.randf_range(-0.5, 0.5), VOID_Y, p.y + rng.randf_range(-0.5, 0.5)), Vector3(0, rng.randf() * TAU, 0)))
			else:
				var top := _ash_mound_into(bs, p, 0.6, rng)
				_bones_into(bs, p, rng, top - 0.06)


# --- particules

## Particules d'ambiance des mondes 6 à 8.
static func _particles_new(wid: int, parent: Node3D, area: AABB, ctr: Vector3) -> void:
	match wid:
		6:
			# aiguilles de cèdre et feuilles qui tombent, corbeaux qui planent au fond
			var p := _emitter(parent, "Needles", Vector3(ctr.x - 1.0, area.position.y + area.size.y, ctr.z), Vector3(area.size.x * 0.5 + 1.0, 0.05, area.size.z * 0.5), 40, 6.0, _quad_mesh("needle", Vector2(0.05, 0.14), false))
			p.direction = Vector3(0.3, -1.0, 0.1)
			p.spread = 15.0
			p.gravity = Vector3(0.05, -0.1, 0)
			p.initial_velocity_min = 0.6
			p.initial_velocity_max = 0.9
			p.angle_min = 0.0
			p.angle_max = 360.0
			p.angular_velocity_min = -120.0
			p.angular_velocity_max = 120.0
			p.scale_amount_min = 0.8
			p.scale_amount_max = 1.5
			p.color_ramp = _fade(0.08, 0.9)
			p.color_initial_ramp = _ramp([Color("#4E6E3E"), Color("#7A6A3A"), Color("#3A5A40")], true)
			p.emitting = true
			var g := _emitter(parent, "Crows", Vector3(0, 4.8, -12.5), Vector3(9.0, 0.7, 1.6), 5, 22.0, _crow_mesh())
			g.direction = Vector3(1, 0, 0.05)
			g.spread = 8.0
			g.gravity = Vector3.ZERO
			g.initial_velocity_min = 0.8
			g.initial_velocity_max = 1.2
			g.color_ramp = _fade(0.08, 0.9)
			g.emitting = true
		7:
			# bulles qui montent, plancton qui scintille
			var b := _emitter(parent, "Bubbles", Vector3(ctr.x, area.position.y + 0.1, ctr.z), Vector3(area.size.x * 0.5, 0.1, area.size.z * 0.5), 46, 4.5, _sphere_mesh("bubble", 0.05, true))
			b.direction = Vector3.UP
			b.spread = 12.0
			b.gravity = Vector3(0.02, 0.25, 0)
			b.initial_velocity_min = 0.5
			b.initial_velocity_max = 1.0
			b.scale_amount_min = 0.6
			b.scale_amount_max = 1.8
			b.color_ramp = _fade(0.1, 0.85)
			b.color_initial_ramp = _ramp([Color(0.8, 1.0, 0.98), Color(0.95, 1.0, 1.0), Color(0.7, 0.95, 0.95)], false)
			b.emitting = true
			var s := _emitter(parent, "Plankton", Vector3(ctr.x, 1.8, ctr.z), Vector3(area.size.x * 0.5, 1.4, area.size.z * 0.5), 30, 6.0, _sphere_mesh("plankton", 0.03, true))
			s.direction = Vector3(1, 0.1, 0)
			s.spread = 180.0
			s.gravity = Vector3.ZERO
			s.initial_velocity_min = 0.05
			s.initial_velocity_max = 0.15
			s.color_ramp = _fade(0.25, 0.7)
			s.color_initial_ramp = _ramp([Color(0.6, 1.0, 0.9), Color(1.0, 0.95, 0.7)], true)
			s.emitting = true
		_:
			# cendre qui tombe, âmes errantes qui montent
			var a := _emitter(parent, "Ash", Vector3(ctr.x - 1.0, area.position.y + area.size.y, ctr.z), Vector3(area.size.x * 0.5 + 1.0, 0.05, area.size.z * 0.5), 56, 6.0, _quad_mesh("ash", Vector2(0.07, 0.07), false))
			a.direction = Vector3(0.2, -1.0, 0.05)
			a.spread = 12.0
			a.gravity = Vector3(0.03, -0.08, 0)
			a.initial_velocity_min = 0.5
			a.initial_velocity_max = 0.8
			a.angle_min = 0.0
			a.angle_max = 360.0
			a.angular_velocity_min = -90.0
			a.angular_velocity_max = 90.0
			a.scale_amount_min = 0.6
			a.scale_amount_max = 1.4
			a.color_ramp = _fade(0.08, 0.9)
			a.color_initial_ramp = _ramp([Color("#8E8A94"), Color("#5E5A64"), Color("#B8B2BE")], true)
			a.emitting = true
			var w := _emitter(parent, "Souls", Vector3(ctr.x, 0.8, ctr.z), Vector3(area.size.x * 0.5, 0.6, area.size.z * 0.5), 22, 5.0, _sphere_mesh("soul", 0.07, true))
			w.direction = Vector3.UP
			w.spread = 30.0
			w.gravity = Vector3(0, 0.06, 0)
			w.initial_velocity_min = 0.1
			w.initial_velocity_max = 0.3
			w.scale_amount_min = 0.8
			w.scale_amount_max = 1.6
			w.color_ramp = _fade(0.2, 0.7)
			w.color_initial_ramp = _ramp([Color(0.75, 0.6, 1.0), Color(0.9, 0.85, 1.0), Color(0.6, 0.75, 1.0)], false)
			w.emitting = true


## Particules de l'accueil autour de la barque pour les mondes 6 à 8 (main._build_boat_fx).
## Renvoie faux pour un autre monde (rien n'est créé).
static func boat_fx(id: int, parent: Node3D, c: Vector3, ext: Vector3, k: float) -> bool:
	match id:
		6:
			var p := _emitter(parent, "Needles", c + Vector3(-0.8, 1.6, 0), Vector3(ext.x + 0.8, 0.05, ext.z), int(26 * k), 6.0, _quad_mesh("needle", Vector2(0.05, 0.14), false))
			p.direction = Vector3(0.3, -1.0, 0.1)
			p.spread = 15.0
			p.gravity = Vector3(0.05, -0.1, 0)
			p.initial_velocity_min = 0.5
			p.initial_velocity_max = 0.8
			p.angle_min = 0.0
			p.angle_max = 360.0
			p.color_ramp = _fade(0.08, 0.9)
			p.color_initial_ramp = _ramp([Color("#4E6E3E"), Color("#7A6A3A"), Color("#3A5A40")], true)
			p.emitting = true
			return true
		7:
			var b := _emitter(parent, "Bubbles", c + Vector3(0, -1.6, 0), Vector3(ext.x, 0.1, ext.z), int(24 * k), 4.5, _sphere_mesh("bubble", 0.05, true))
			b.direction = Vector3.UP
			b.spread = 12.0
			b.gravity = Vector3(0.02, 0.25, 0)
			b.initial_velocity_min = 0.4
			b.initial_velocity_max = 0.9
			b.scale_amount_min = 0.6
			b.scale_amount_max = 1.6
			b.color_ramp = _fade(0.1, 0.85)
			b.emitting = true
			return true
		8:
			var w := _emitter(parent, "Souls", c + Vector3(0, -0.6, 0), ext, int(16 * k), 5.0, _sphere_mesh("soul", 0.07, true))
			w.direction = Vector3.UP
			w.spread = 30.0
			w.gravity = Vector3(0, 0.05, 0)
			w.initial_velocity_min = 0.08
			w.initial_velocity_max = 0.25
			w.color_ramp = _fade(0.2, 0.7)
			w.color_initial_ramp = _ramp([Color(0.75, 0.6, 1.0), Color(0.9, 0.85, 1.0)], false)
			w.emitting = true
			return true
	return false


## Corbeau en vol (ailes en « M » le long de Z, vol vers +X), couleurs de sommets sombres.
static func _crow_mesh() -> ArrayMesh:
	if _meshes.has("crow"):
		var cached: ArrayMesh = _meshes["crow"]
		return cached
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var w := Color("#2A2830")
	var g := Color("#1A181E")
	var d := Color("#0C0B0E")
	_vtri(st, Vector3(0.22, 0, 0), Vector3(0, 0.02, 0.05), Vector3(-0.2, 0, 0), w, w, w)
	_vtri(st, Vector3(0.22, 0, 0), Vector3(-0.2, 0, 0), Vector3(0, 0.02, -0.05), w, w, w)
	for sz: float in [-1.0, 1.0]:
		var e := Vector3(0.02, 0.07, sz * 0.22)
		var t := Vector3(-0.08, 0.0, sz * 0.48)
		_vtri(st, Vector3(0.08, 0.01, 0), e, Vector3(-0.06, 0.01, 0), w, g, w)
		_vtri(st, e, t, Vector3(-0.07, 0.05, sz * 0.25), g, d, g)
	var mesh := st.commit()
	mesh.surface_set_material(0, _pmat(false, false))
	_meshes["crow"] = mesh
	return mesh


# --- fosses

## Détails des fosses des mondes 6 à 8 (voir _pit_details).
static func _pit_new(wid: int, ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var bs: Dictionary = ctx["bs"]
	var sty: Dictionary = ctx["sty"]
	var line: Color = sty["line"]
	match wid:
		6:
			# paroi de pierre moussue, racines qui pendent, lucioles au fond ; racines au bord
			_pit_lines(ctx, 0.35, 0.026, Color(line, 0.7))
			_pit_lines(ctx, 0.68, 0.022, Color(line, 0.55))
			_pit_joints(ctx, Color(line, 0.55))
			_pit_drips(ctx, 0.35, 2, Color(Color("#3E5A3A"), 0.8))
			_pit_glints(ctx, 0.6, 0.04, 0.08)
			var root := _toon(CEDAR_BARK, true, 0.012)
			for e in _pit_edge_pts(ctx, 0.5, true):
				if rng.randf() < 0.45:
					continue
				var ea: Array = e
				var q: Vector2 = ea[0]
				var n: Vector2 = ea[1]
				var l := rng.randf_range(0.18, 0.42)
				_add(bs, root, _cyl(0.02, 0.045, l, 5), _stub_xf(q, n, -0.04, l, rng.randf_range(0.6, 1.2), rng.randf_range(-0.4, 0.4)) * _at(Vector3.ZERO, Vector3(PI * 0.5, 0, 0)))
		7:
			# paroi laquée à filets d'or, eau profonde qui scintille ; coraux au bord
			_pit_lines(ctx, 0.25, 0.02, Color(Toon.GOLD, 0.55))
			_pit_lines(ctx, 0.6, 0.026, Color(line, 0.6))
			_pit_glints(ctx, 1.1, 0.04, 0.1)
			for e in _pit_edge_pts(ctx, 0.55, true):
				if rng.randf() < 0.5:
					continue
				var ea: Array = e
				var q: Vector2 = ea[0]
				var n: Vector2 = ea[1]
				var col: Color = CORAL[rng.randi_range(0, CORAL.size() - 1)]
				var c := q + n * 0.08
				_add(bs, _toon(col, true, 0.012), _ball(rng.randf_range(0.06, 0.11), 0.14, 6, 3), _at(Vector3(c.x, -0.04, c.y)))
		_:
			# paroi de cendre, coulées d'encre, âmes violettes tout au fond ; ossements au bord
			_pit_lines(ctx, 0.45, 0.02, Color(line, 0.55))
			_pit_drips(ctx, 0.35, 1, Color(Color("#2A2430"), 0.85))
			_pit_glints(ctx, 0.5, 0.05, 0.1)
			var bone := _toon(BONE, true, 0.01)
			for e in _pit_edge_pts(ctx, 0.6, true):
				if rng.randf() < 0.55:
					continue
				var ea: Array = e
				var q: Vector2 = ea[0]
				var n: Vector2 = ea[1]
				var l := rng.randf_range(0.12, 0.24)
				_add(bs, bone, _box(Vector3(0.035, 0.035, l)), _stub_xf(q, n, -0.03, l, rng.randf_range(0.2, 0.6), rng.randf_range(-0.6, 0.6)))


# ================================================================== sanctuaire d'arrivée
# Chaque monde a son arrivée (arena.gd HUBS : quai, allée, escalier… du bas jusqu'au torii). Ici, le décor
# posé dans l'eau de part et d'autre du chemin : jamais sur la terre ferme, rien de haut au bas de l'écran,
# rien de haut devant le chemin. Mêmes lots que le décor des salles (bs / bn par matériau, MultiMesh).

## Décor d'arrivée du monde autour du chemin `rects` (sol du sanctuaire). `lit` : une lumière ponctuelle.
static func build_hub(world_id: int, parent: Node3D, rects: Array, rng_seed: int, lit: bool) -> void:
	var wid := clampi(world_id, 1, WORLDS.size())
	var rng := _rng(rng_seed * 17 + wid * 3)
	var root := Node3D.new()
	root.name = "Sanctuaire"
	parent.add_child(root)
	var ctx := {"lights": 0, "root": root, "rects": rects, "taken": [], "avoid": [], "bs": {}, "bn": {}, "mm": {},
		"zone": Rect2(), "max_lights": 1 if lit else 0, "pieces": []}
	match wid:
		1:
			_hub_harbour(ctx, rng)
		2:
			_hub_tanabata(ctx, rng)
		3:
			_hub_snow(ctx, rng)
		4:
			_hub_volcano(ctx, rng)
		6:
			_hub_kurama(ctx, rng)
		7:
			_hub_palace(ctx, rng)
		8:
			_hub_yomi(ctx, rng)
		_:
			_hub_pavilion_court(ctx, rng)
	var pieces: Array = ctx["pieces"]
	if not pieces.is_empty():
		_set_pieces(wid, ctx, pieces, rng)
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var mm: Dictionary = ctx["mm"]
	_flush(bs, root, true)
	_flush(bn, root, false)
	_flush_mm(mm, root)


## Pièce de décor du monde (SET_PIECES) centrée en `c`, longueur `ln` (le long de x, de z si `turned`),
## socle à la hauteur `y` (0 : sur un socle sorti de l'eau ; VOID_Y : îlot posé sur l'eau).
static func _hub_piece(ctx: Dictionary, kind: String, c: Vector2, ln: float, wd: float, turned: bool, y: float) -> void:
	var sz: Vector2 = Vector2(wd, ln) if turned else Vector2(ln, wd)
	var pieces: Array = ctx["pieces"]
	pieces.append([Rect2(c - sz * 0.5, sz), kind, turned, y])
	_take(ctx, c)


## Socle de pierre (ou de bois) qui sort de l'eau jusqu'à `top`, ombre douce au pied.
static func _hub_pad(ctx: Dictionary, c: Vector2, sz: Vector2, col: Color, top := 0.0) -> void:
	var bs: Dictionary = ctx["bs"]
	var h := top - (VOID_Y - 0.25)
	_add(bs, _toon(col, true, 0.025), _box(Vector3(sz.x, h, sz.y)), _at(Vector3(c.x, top - h * 0.5, c.y)))
	_contact(ctx, c, maxf(sz.x, sz.y) * 0.75)
	_take(ctx, c)


## Point libre dans l'eau du sanctuaire (loin du chemin et des pièces déjà posées), ou NONE2.
static func _hub_spot(ctx: Dictionary, rng: RandomNumberGenerator, margin: float, spacing: float) -> Vector2:
	for attempt in 30:
		var p := Vector2(rng.randf_range(-4.4, 4.4), rng.randf_range(-8.3, 7.4))
		if _ok(ctx, p, margin, spacing):
			return p
	return NONE2


## Monde 1 : port de Kanagawa. Quai d'arrivée, ponton de planches jusqu'au torii, barques amarrées le long
## du ponton, bittes d'amarrage et leurs cordages (mouettes), lanterne de port (jōyatō), séchoir à filets,
## fanions au mon du clan, radeau de tonneaux de saké, flotteurs de verre.
static func _hub_harbour(ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	# barques amarrées entre l'embarcadère et la tête du ponton, proue vers le torii
	for sx: float in [-1.0, 1.0]:
		var bp := Vector3(sx * 3.1, VOID_Y, -3.1)
		_boat_into(bs, _at(bp, Vector3(0, PI * 0.5 + sx * 0.06, 0), Vector3.ONE * 0.75), 1 if sx > 0.0 else 0)
		_contact(ctx, Vector2(bp.x, bp.z), 1.3)
		_foam_ring(ctx, Vector2(bp.x, bp.z), 0.8, rng)
		_take(ctx, Vector2(bp.x, bp.z))
	# bittes d'amarrage au bord du quai, reliées deux à deux par un cordage
	var rope := _toon(Decor.KOMO, false)
	var tops: Array[Vector3] = []
	for x: float in [-3.5, -2.6, -1.7, 1.7, 2.6, 3.5]:
		tops.append(_bitt_into(bs, bn, Vector3(x, VOID_Y - 0.2, 3.05), rng.randf_range(1.05, 1.3)))
		_foam_ring(ctx, Vector2(x, 3.05), 0.2, rng)
	for k: int in [0, 1, 3, 4]:
		_rope(bn, rope, tops[k] - Vector3(0, 0.14, 0), tops[k + 1] - Vector3(0, 0.14, 0), 0.14, 0.022)
	Decor.gull_into(bn, _at(tops[0], Vector3(0, 0.6, 0)))
	Decor.gull_into(bn, _at(tops[4], Vector3(0, -2.2, 0)))
	# lanterne de port à gauche de la tête du ponton, séchoir à filets à droite
	_port_lantern_into(bs, bn, _at(Vector3(-3.75, VOID_Y, -6.6), Vector3(0, 0.3, 0), Vector3.ONE * 0.8))
	_contact(ctx, Vector2(-3.75, -6.6), 0.9)
	_light(ctx, Vector3(-3.75, VOID_Y + 2.0, -6.6), Color(1.0, 0.78, 0.5), 0.9, 4.0)
	Decor.net_rack_into(bs, bn, _at(Vector3(3.75, 0.0, -6.8), Vector3(0, PI * 0.5, 0)), VOID_Y - 0.1)
	# fanions du port au mon du clan, de part et d'autre de l'embarcadère
	var nc: Array = _nobori_colors(1)
	for sx: float in [-1.0, 1.0]:
		Decor.nobori_into(bs, bn, _at(Vector3(sx * 3.95, 0.0, 1.95)), nc[0], nc[1], VOID_Y - 0.2, 1)
	# barque et radeau de tonneaux le long du quai (bas de l'écran : rien de haut)
	_boat_into(bs, _at(Vector3(4.15, VOID_Y, 5.9), Vector3(0, PI * 0.5, 0), Vector3.ONE * 0.55), 0)
	_contact(ctx, Vector2(4.15, 5.9), 0.9)
	_add(bs, _toon(Decor.PLANK, true, 0.02), _box(Vector3(0.8, 0.1, 1.7)), _at(Vector3(-4.12, VOID_Y + 0.04, 6.0)))
	for k in 2:
		Decor.sake_barrel_into(bs, bn, _at(Vector3(-4.12, VOID_Y + 0.09, 5.55 + k * 0.85), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * 0.72),
			Toon.PRUSSIAN if k == 1 else Decor.LABEL)
	_contact(ctx, Vector2(-4.12, 6.0), 0.9)
	# flotteurs de verre à la dérive
	var floats: Array[Vector2] = [Vector2(2.3, 2.3), Vector2(-2.4, 2.1), Vector2(4.0, -0.3), Vector2(-4.15, -2.4), Vector2(2.1, -4.4)]
	for i in floats.size():
		var fp: Vector2 = floats[i]
		Decor.glass_float_into(bn, _at(Vector3(fp.x, VOID_Y - 0.06, fp.y), Vector3(0, rng.randf() * TAU, 0)), i)


## Monde 2 : nuit de Tanabata. Allée de pierre entre les bambous, petits sanctuaires (hokora) au bout des
## alcôves, bambous chargés de vœux (tanzaku) sur des îlots de mousse, chōchin allumés le long du chemin,
## renards de pierre qui gardent le parvis du torii, bosquets aux coins du haut.
static func _hub_tanabata(ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var moss := _toon(MOSS_K, true, 0.02)
	# hokora au bout de chaque alcôve, tourné vers l'allée
	for hs: Vector3 in [Vector3(-4.22, -1.4, PI * 0.5), Vector3(4.22, 1.8, -PI * 0.5)]:
		_hub_pad(ctx, Vector2(hs.x, hs.y), Vector2(0.72, 0.9), STONE_DARK)
		Decor.hokora_into(bs, bn, _at(Vector3(hs.x, 0.0, hs.y), Vector3(0, hs.z, 0)), Color("#6E4A32"), Color("#2E3446"))
	# renards de pierre de part et d'autre du parvis
	for sx: float in [-1.0, 1.0]:
		_hub_pad(ctx, Vector2(sx * 3.55, -6.2), Vector2(1.5, 0.9), STONE_DARK)
		_hub_piece(ctx, "fox_pair", Vector2(sx * 3.55, -6.2), 1.4, 0.8, false, 0.0)
	# bambous de Tanabata chargés de vœux, sur leurs îlots de mousse
	var wishes: Array[Vector2] = [Vector2(-3.3, 1.6), Vector2(-2.4, -4.3), Vector2(2.45, -1.3), Vector2(2.8, -3.9)]
	for p in wishes:
		_add(bs, moss, _ball(0.5, 0.36, 10, 4), _at(Vector3(p.x, VOID_Y + 0.05, p.y)))
		_tanzaku_into(bs, _at(Vector3(p.x, VOID_Y + 0.15, p.y)), rng)
		_contact(ctx, p, 0.7)
		_take(ctx, p)
	# lanterne de pierre au pied de l'allée
	_hub_pad(ctx, Vector2(-2.6, 2.95), Vector2(0.62, 0.62), STONE_DARK)
	Decor.stone_lantern_into(bs, bn, _at(Vector3(-2.6, 0.0, 2.95), Vector3.ZERO, Vector3.ONE * 0.9))
	# chōchin sur leurs perches, penchés au-dessus du bord de l'allée
	var lan := Color("#F2C46A")
	for ls: Vector3 in [Vector3(-1.95, -4.6, 0.0), Vector3(1.95, -4.6, PI), Vector3(-1.95, 2.2, 0.0), Vector3(1.95, -0.5, PI)]:
		Decor.paper_lantern_into(bs, bn, _at(Vector3(ls.x, 0.0, ls.y), Vector3(0, ls.z, 0)), lan, VOID_Y - 0.05)
		_contact(ctx, Vector2(ls.x, ls.y), 0.35)
		_take(ctx, Vector2(ls.x, ls.y))
	_light(ctx, Vector3(-1.55, 1.47, -4.6), Color(1.0, 0.75, 0.45), 0.8, 3.6)
	# bosquets de bambous aux coins du haut et sur le flanc gauche
	var groves: Array[Vector2] = [Vector2(-3.95, -7.7), Vector2(3.95, -7.9), Vector2(-4.05, -3.4)]
	for i in groves.size():
		var g: Vector2 = groves[i]
		_add(bs, moss, _ball(0.75, 0.4, 10, 4), _at(Vector3(g.x, VOID_Y + 0.02, g.y)))
		Decor.bamboo_into(bs, bn, _at(Vector3(g.x, VOID_Y + 0.1, g.y)), 410 + i)
		_contact(ctx, g, 0.9)
		_take(ctx, g)


## Monde 3 : sanctuaire sous la neige. Allée enneigée aux pas-japonais balayés, pont de planches à
## garde-corps vermillon au-dessus de l'eau gelée, mares gelées et congères, pins et jizō sous la neige,
## lanternes de pierre coiffées de neige, beffroi au parvis, glaçons et lanternes flottantes.
static func _hub_snow(ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var snow := _toon(SNOW, false)
	# pas-japonais balayés le long de l'allée (sauf sur le pont)
	var slab := _toon(Color("#7E8494"), true, 0.015)
	var z := 8.0
	while z > -7.0:
		if z > 0.1 or z < -2.7:
			_add(bn, slab, _cyl(0.3, 0.34, 0.04, 7), _at(Vector3(rng.randf_range(-0.14, 0.14), 0.05, z), Vector3(0, rng.randf() * TAU, 0)))
		z -= 0.74
	# garde-corps vermillon du pont : poteaux dans l'eau, lisses, giboshi d'or, neige sur la main courante
	var lac := _toon(Toon.VERMILION.darkened(0.12), true, 0.02)
	var knob := _toon(Toon.GOLD.darkened(0.1), true, 0.015)
	for sx: float in [-1.0, 1.0]:
		var x := sx * 1.17
		var y0 := VOID_Y - 0.1
		for k in 5:
			var pz := lerpf(-2.3, -0.3, float(k) / 4.0)
			var hh := 0.62 - y0
			_add(bs, lac, _box(Vector3(0.08, hh, 0.08)), _at(Vector3(x, y0 + hh * 0.5, pz)))
		_add(bs, lac, _box(Vector3(0.07, 0.06, 2.1)), _at(Vector3(x, 0.55, -1.3)))
		_add(bs, lac, _box(Vector3(0.05, 0.05, 2.0)), _at(Vector3(x, 0.3, -1.3)))
		_add(bn, snow, _box(Vector3(0.09, 0.04, 2.0)), _at(Vector3(x, 0.6, -1.3)))
		for kz: float in [-2.3, -0.3]:
			_add(bs, knob, _ball(0.06, 0.14, 6, 3), _at(Vector3(x, 0.69, kz)))
	# congère à pins enneigés à gauche du pont, jizō sur la congère de droite
	var top := _mound_into(bs, bn, Vector2(-3.1, -1.3), 1.0, rng)
	_snow_pine_into(bs, _at(Vector3(-3.2, top - 0.08, -1.4), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * 0.95))
	_take(ctx, Vector2(-3.1, -1.3))
	var top2 := _mound_into(bs, bn, Vector2(3.0, -1.2), 1.1, rng)
	_hub_piece(ctx, "jizo_row", Vector2(3.0, -1.2), 1.6, 0.8, false, top2 - 0.06)
	# mares gelées (glace bleutée dans un bourrelet de neige) au pied de l'allée
	for sx: float in [-1.0, 1.0]:
		_hub_piece(ctx, "frozen_pond", Vector2(sx * 3.0, 1.9), 2.2, 1.5, false, VOID_Y + 0.05)
	# lanternes de pierre coiffées de neige devant le parvis (une seule allumée)
	for sx: float in [-1.0, 1.0]:
		var lp := Vector2(sx * 2.35, -4.4)
		_hub_pad(ctx, lp, Vector2(0.7, 0.7), STONE_DARK)
		Decor.stone_lantern_into(bs, bn, _at(Vector3(lp.x, 0.0, lp.y), Vector3.ZERO, Vector3.ONE * 1.05))
		_add(bn, snow, _ball(0.36, 0.14, 8, 3), _at(Vector3(lp.x, 1.1, lp.y)))
	_light(ctx, Vector3(-2.35, 0.85, -4.4), Color(1.0, 0.8, 0.55), 0.7, 3.5)
	# beffroi enneigé à gauche du parvis, pin enneigé à droite
	_hub_pad(ctx, Vector2(-4.0, -6.9), Vector2(1.3, 1.3), STONE_DARK)
	Decor.bell_tower_into(bs, bn, _at(Vector3(-4.0, 0.0, -6.9), Vector3(0, 0.25, 0), Vector3.ONE * 0.6), true)
	var top3 := _mound_into(bs, bn, Vector2(4.0, -7.0), 0.85, rng)
	_snow_pine_into(bs, _at(Vector3(4.0, top3 - 0.08, -7.0), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * 1.05))
	_take(ctx, Vector2(4.0, -7.0))
	# petites congères le long du quai d'arrivée (basses)
	for sx: float in [-1.0, 1.0]:
		_mound_into(bs, bn, Vector2(sx * 4.15, 5.3), 0.5, rng)
		_take(ctx, Vector2(sx * 4.15, 5.3))
	# glaçons et lanternes flottantes (tōrō nagashi) sur l'eau libre
	var ice := _toon(ICE, false)
	for i in (6 if Toon.lite else 10):
		var p := _hub_spot(ctx, rng, 0.5, 0.9)
		if p == NONE2:
			continue
		_take(ctx, p)
		if i % 3 == 2:
			_add(bn, ice, _cyl(0.5, 0.52, 0.06, 6), _at(Vector3(p.x, VOID_Y + 0.02, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3(rng.randf_range(0.7, 1.2), 1, rng.randf_range(0.5, 0.9))))
		else:
			_toro_into(bn, _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, rng.randf() * TAU, 0)))


## Monde 4 : escalier de basalte du Fuji rouge. Volées droites et paliers en zigzag au-dessus de la lave,
## braseros sur leurs fûts de basalte au pied de chaque volée, orgues basaltiques, piques de roche,
## couronne de braise dans la lave.
static func _hub_volcano(ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var bm := _toon(BASALT, true, 0.025)
	# braseros sur des fûts de basalte, de part et d'autre de la première et de la dernière volée
	var fires: Array[Vector2] = [Vector2(-1.9, 3.3), Vector2(1.9, 3.3), Vector2(-1.9, -4.95), Vector2(1.9, -4.95)]
	for p in fires:
		_add(bs, bm, _cyl(0.28, 0.33, -(VOID_Y - 0.25), 6), _at(Vector3(p.x, (VOID_Y - 0.25) * 0.5, p.y)))
		_brazier_into(bs, bn, _at(Vector3(p.x, 0.0, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * 0.62))
		_contact(ctx, p, 0.6)
		_take(ctx, p)
	_light(ctx, Vector3(1.9, 1.0, 3.3), Color(1.0, 0.55, 0.25), 0.8, 4.0)
	# orgues de basalte dans la lave (plus hautes au fond, près du torii)
	var cols: Array[Vector3] = [Vector3(3.2, 1.4, 0.5), Vector3(-3.1, -3.0, 0.8), Vector3(3.95, -6.9, 1.4), Vector3(-3.95, -7.2, 1.2)]
	for cv in cols:
		_basalt_into(bs, Vector2(cv.x, cv.y), 0.42, cv.z, rng)
		_contact(ctx, Vector2(cv.x, cv.y), 1.0)
		_take(ctx, Vector2(cv.x, cv.y))
	# piques de roche noire, auréole de braise
	for sp: Vector2 in [Vector2(-4.1, 3.3), Vector2(4.15, -2.9), Vector2(-4.1, -1.0)]:
		_spikes_into(bs, bn, sp, 0.5, rng)
		_take(ctx, sp)
	# orgues basses et leur auréole au bas de l'écran, à droite du palier d'arrivée
	_hub_piece(ctx, "basalt", Vector2(4.05, 6.0), 1.1, 1.1, false, VOID_Y + 0.02)
	# éclats de lave refroidie (instances) sur l'eau libre
	var chunk := _ball(0.5, 0.55, 6, 3)
	var gm := _glow(LAVA_GOLD, 1.2)
	for i in (8 if Toon.lite else 14):
		var p := _hub_spot(ctx, rng, 0.45, 0.5)
		if p == NONE2:
			continue
		_inst(ctx, "chunk", chunk, bm, _at(Vector3(p.x, VOID_Y - 0.05, p.y), Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, 0), Vector3.ONE * rng.randf_range(0.25, 0.6)))
		if i % 2 == 0:
			_inst(ctx, "crack", _box(Vector3(1.0, 0.02, 0.06)), gm, _at(Vector3(p.x, VOID_Y + 0.01, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3(rng.randf_range(0.4, 1.0), 1, 1)))


## Monde 5 : cour du pavillon de papier. Porte, grande cour de washi coupée d'un tapis d'indigo à liseré
## d'or jusqu'au torii, pavillons ouverts aux cloisons de shōji, paravents, pinceaux géants plantés dans
## l'encre, sceau et rouleaux près de la porte, andon allumés, feuilles qui flottent sur l'encre.
static func _hub_pavilion_court(ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	# tapis d'indigo de la porte au torii (aplat sur le papier), liseré d'or
	_add(bn, _toon(Color("#2E3446"), false), _box(Vector3(1.1, 0.008, 16.2)), _at(Vector3(0, 0.006, 0.1)))
	var gold := _toon(Toon.GOLD, false)
	for sx: float in [-1.0, 1.0]:
		_add(bn, gold, _box(Vector3(0.04, 0.008, 16.2)), _at(Vector3(sx * 0.6, 0.007, 0.1)))
	# pavillons ouverts de part et d'autre de la véranda
	for sx: float in [-1.0, 1.0]:
		_hub_pavilion(ctx, Vector2(sx * 3.55, -6.2), sx)
	# paravents (byōbu) le long de la cour, pinceaux géants plantés dans l'encre
	for sx: float in [-1.0, 1.0]:
		_hub_pad(ctx, Vector2(sx * 3.8, 1.2), Vector2(0.95, 2.05), Color("#2A1F1A"))
		_hub_piece(ctx, "screen", Vector2(sx * 3.8, 1.2), 1.9, 0.8, true, 0.0)
		_brush_into(bs, _at(Vector3(sx * 3.95, VOID_Y, -1.8), Vector3(0, 0, -sx * 0.12), Vector3.ONE * 0.75))
		_contact(ctx, Vector2(sx * 3.95, -1.8), 0.5)
		_take(ctx, Vector2(sx * 3.95, -1.8))
	# sceau du peintre et table aux rouleaux de part et d'autre de la porte (bas de l'écran : bas)
	_hub_pad(ctx, Vector2(3.65, 6.3), Vector2(1.1, 1.1), Color("#3A2A22"))
	_hub_piece(ctx, "seal", Vector2(3.65, 6.3), 1.0, 1.0, false, 0.0)
	_hub_pad(ctx, Vector2(-3.65, 6.3), Vector2(1.0, 1.5), Color("#3A2A22"))
	_hub_piece(ctx, "scrolls", Vector2(-3.65, 6.3), 1.4, 0.9, true, 0.0)
	# andon (lanternes de papier) aux coins de la cour
	for sx: float in [-1.0, 1.0]:
		var ap := Vector2(sx * 3.6, 4.15)
		_hub_pad(ctx, ap, Vector2(0.5, 0.5), Color("#3A2A22"))
		_toro_into(bs, _at(Vector3(ap.x, 0.0, ap.y), Vector3(0, 0.2 * sx, 0), Vector3.ONE * 1.5))
	_light(ctx, Vector3(-3.6, 0.35, 4.15), Color(1.0, 0.82, 0.6), 0.7, 3.5)
	# feuilles de papier qui flottent sur l'encre
	for pp: Vector2 in [Vector2(4.1, -3.9), Vector2(-4.1, -4.2), Vector2(4.15, 3.0), Vector2(-4.2, 2.9)]:
		_papers_into(bn, pp, rng, 2, VOID_Y + 0.01, 0.3)


## Pavillon ouvert (azumaya) sur son socle : quatre poteaux laqués, plancher, cloisons de shōji au fond et
## côté eau (`outer` : ±1, côté de l'eau), toit de tuiles en pavillon.
static func _hub_pavilion(ctx: Dictionary, c: Vector2, outer: float) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	_hub_pad(ctx, c, Vector2(1.5, 1.5), Color("#5B5550"))
	var lac := _toon(Color("#2A1F1A"), true, 0.02)
	var paper := _toon(Toon.WASHI, true, 0.012)
	var tile := _toon(KAWARA, true, 0.025)
	var ridge := _toon(KAWARA_DARK, false)
	var hp := 1.35
	for k in 4:
		var px: float = 0.58 if k % 2 == 0 else -0.58
		var pz: float = 0.58 if k < 2 else -0.58
		_add(bs, lac, _box(Vector3(0.09, hp, 0.09)), _at(Vector3(c.x + px, hp * 0.5, c.y + pz)))
	_add(bs, lac, _box(Vector3(1.3, 0.06, 1.3)), _at(Vector3(c.x, 0.03, c.y)))
	_add(bs, paper, _box(Vector3(1.1, 1.0, 0.03)), _at(Vector3(c.x, 0.7, c.y - 0.58)))
	_add(bs, paper, _box(Vector3(0.03, 1.0, 1.1)), _at(Vector3(c.x + outer * 0.58, 0.7, c.y)))
	for k in 3:
		_add(bn, lac, _box(Vector3(1.1, 0.025, 0.02)), _at(Vector3(c.x, 0.4 + k * 0.3, c.y - 0.6)))
		_add(bn, lac, _box(Vector3(0.02, 0.025, 1.1)), _at(Vector3(c.x + outer * 0.6, 0.4 + k * 0.3, c.y)))
	Decor.roof_into(bs, bn, tile, ridge, _at(Vector3(c.x, hp, c.y)), 1.9, 1.9, 0.62, 0.0, 0.42)


## Monde 6 : escalier de pierre de Kurama. Volées de marches entre des cèdres sur leurs îlots de mousse,
## lanternes de pierre au bord des marches (corbeaux), rocher sacré ceint de sa corde, poteaux
## d'entraînement des tengu, souche aux racines noueuses près de l'arrivée.
static func _hub_kurama(ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	# cèdres sur îlots de mousse : entre le palier et l'arrivée, aux coins du parvis
	var cedars: Array[Vector3] = [Vector3(-4.0, 2.6, 0.7), Vector3(4.0, 2.4, 0.7), Vector3(-3.95, -7.4, 0.8), Vector3(3.95, -7.0, 0.8)]
	for cv in cedars:
		var top := _moss_mound_into(bs, Vector2(cv.x, cv.y), 0.9, rng)
		_cedar_into(bs, _at(Vector3(cv.x, top - 0.05, cv.y), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * cv.z), rng)
		_contact(ctx, Vector2(cv.x, cv.y), 1.1)
		_take(ctx, Vector2(cv.x, cv.y))
	# lanternes de pierre au bord des volées, corbeaux sur deux d'entre elles
	var lamps: Array[Vector2] = [Vector2(-2.0, 2.2), Vector2(2.0, 2.2), Vector2(-2.0, -3.75), Vector2(2.0, -3.75)]
	for i in lamps.size():
		var lp: Vector2 = lamps[i]
		_hub_pad(ctx, lp, Vector2(0.6, 0.6), Color("#5E6A5A"))
		Decor.stone_lantern_into(bs, bn, _at(Vector3(lp.x, 0.0, lp.y), Vector3.ZERO, Vector3.ONE * 0.95))
		if i == 1 or i == 2:
			_crow_into(bs, _at(Vector3(lp.x, 1.36, lp.y), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * 0.8))
	_light(ctx, Vector3(-2.0, 0.78, -3.75), Color(1.0, 0.8, 0.5), 0.7, 3.5)
	# rocher sacré à gauche du haut de l'escalier, poteaux d'entraînement à droite
	_hub_piece(ctx, "sacred_rock", Vector2(-3.3, -3.7), 1.3, 1.1, false, VOID_Y + 0.06)
	_hub_pad(ctx, Vector2(3.4, -3.7), Vector2(1.0, 1.7), STONE_DARK)
	_hub_piece(ctx, "posts", Vector2(3.4, -3.7), 1.6, 0.9, true, 0.0)
	# souche et racines à gauche de l'arrivée (basse)
	_hub_piece(ctx, "roots", Vector2(-4.05, 6.3), 1.2, 1.2, false, VOID_Y + 0.06)
	# feuilles mortes sur l'eau (instances)
	var leaf := _box(Vector3(0.12, 0.006, 0.07))
	var lm: Array[StandardMaterial3D] = [_toon(Color("#8A6A3A"), false), _toon(Color("#6B7240"), false)]
	for i in (10 if Toon.lite else 18):
		var p := _hub_spot(ctx, rng, 0.25, 0.0)
		if p == NONE2:
			continue
		_inst(ctx, "leaf%d" % (i % 2), leaf, lm[i % 2], _at(Vector3(p.x, VOID_Y + 0.012, p.y), Vector3(0, rng.randf() * TAU, 0)))


## Monde 7 : porte de corail du palais du roi dragon. Deux tours de porte laquées (toits de tuiles vertes à
## faîtage d'or, mon du palais) et leur corde sacrée au-dessus de l'allée, îlots de corail et lit de
## bénitiers, varech aux coins du parvis, lanternes de pierre, tortue de pierre à la stèle.
static func _hub_palace(ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	for sx: float in [-1.0, 1.0]:
		_hub_gate_tower(ctx, Vector2(sx * 2.45, 2.9))
	Decor.shimenawa_into(bs, bn, Vector3(-1.95, 1.55, 2.9), Vector3(1.95, 1.55, 2.9))
	# îlots de corail et lit de bénitiers
	_hub_piece(ctx, "coral", Vector2(-4.0, 1.4), 1.2, 1.1, false, VOID_Y + 0.06)
	_hub_piece(ctx, "coral", Vector2(4.0, 1.3), 1.2, 1.1, false, VOID_Y + 0.06)
	_hub_piece(ctx, "coral", Vector2(3.6, -4.1), 1.2, 1.1, false, VOID_Y + 0.06)
	_hub_piece(ctx, "clams", Vector2(-3.6, -4.1), 1.7, 1.0, false, VOID_Y + 0.06)
	# varech aux coins du parvis
	for kp: Vector2 in [Vector2(-3.95, -7.3), Vector2(4.0, -6.9)]:
		_kelp_into(bs, _at(Vector3(kp.x, VOID_Y, kp.y)), rng, 2.2)
		_take(ctx, kp)
	# lanternes de pierre au bout de la cour des récifs
	for sx: float in [-1.0, 1.0]:
		var lp := Vector2(sx * 4.1, -1.4)
		_hub_pad(ctx, lp, Vector2(0.6, 0.6), Color("#5E6A66"))
		Decor.stone_lantern_into(bs, bn, _at(Vector3(lp.x, 0.0, lp.y), Vector3.ZERO, Vector3.ONE * 0.9))
	_light(ctx, Vector3(0.0, 1.6, 2.9), Color(0.8, 1.0, 0.95), 0.7, 4.0)
	# tortue de pierre et sa stèle, à gauche de l'arrivée (basse)
	_kame_into(bs, bn, _at(Vector3(-4.0, VOID_Y + 0.15, 6.0), Vector3(0, 0.3, 0), Vector3.ONE * 0.55))
	_contact(ctx, Vector2(-4.0, 6.0), 0.8)
	_take(ctx, Vector2(-4.0, 6.0))
	# coquillages et petits coraux épars sur l'eau
	for i in (5 if Toon.lite else 9):
		var p := _hub_spot(ctx, rng, 0.5, 0.9)
		if p == NONE2:
			continue
		_take(ctx, p)
		var col: Color = CORAL[rng.randi_range(0, CORAL.size() - 1)]
		_coral_into(bs, _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * rng.randf_range(0.5, 0.8)), rng, col)


## Tour de porte du palais (yagura) sur son socle : corps laqué vermillon, bandeau de plâtre au mon d'or,
## toit de tuiles vert de mer au faîtage d'or.
static func _hub_gate_tower(ctx: Dictionary, c: Vector2) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	_hub_pad(ctx, c, Vector2(1.35, 1.15), Color("#5E6A66"))
	var lac := _toon(PALACE_RED, true, 0.025)
	var plaster := _toon(SHIKKUI, true, 0.02)
	var tile := _toon(Color("#2E6A5E"), true, 0.025)
	var gold := _toon(Toon.GOLD, true, 0.015)
	_add(bs, lac, _box(Vector3(1.15, 0.9, 0.95)), _at(Vector3(c.x, 0.45, c.y)))
	_add(bs, lac, _box(Vector3(1.22, 0.08, 1.02)), _at(Vector3(c.x, 0.92, c.y)))
	_add(bs, plaster, _box(Vector3(1.05, 0.36, 0.88)), _at(Vector3(c.x, 1.12, c.y)))
	Decor.mon_into(bn, gold, _at(Vector3(c.x, 1.12, c.y + 0.452)), 0.13, 0)
	Decor.roof_into(bs, bn, tile, gold, _at(Vector3(c.x, 1.3, c.y)), 1.7, 1.45, 0.55, 0.45, 0.45)


## Monde 8 : allée de Yomi. Torii noirs au-dessus de l'allée de cendre (piliers dans l'eau, ofuda pâles),
## tombes et sotoba, rangée de lanternes, pins morts sur leurs buttes de cendre, lanternes flottantes.
static func _hub_yomi(ctx: Dictionary, rng: RandomNumberGenerator) -> void:
	var bs: Dictionary = ctx["bs"]
	for tz: float in [2.8, -3.6]:
		_hub_dark_torii(ctx, tz, 1.78)
	# tombes à gauche du bas de l'allée, rangée de lanternes à droite du haut
	_hub_pad(ctx, Vector2(-3.3, 2.6), Vector2(0.95, 1.95), ASH_DARK)
	_hub_piece(ctx, "graves", Vector2(-3.3, 2.6), 1.8, 0.8, true, 0.0)
	_hub_pad(ctx, Vector2(3.4, -3.6), Vector2(0.95, 2.35), ASH_DARK)
	_hub_piece(ctx, "lantern_row", Vector2(3.4, -3.6), 2.2, 0.8, true, 0.0)
	_light(ctx, Vector3(3.4, 0.8, -3.6), Color(0.78, 0.7, 1.0), 0.8, 4.0)
	# pins morts sur leurs buttes de cendre
	var pines: Array[Vector2] = [Vector2(-3.9, -7.2), Vector2(4.0, -7.6), Vector2(3.9, 2.4)]
	for p in pines:
		var top := _ash_mound_into(bs, p, 0.9, rng)
		_dead_pine_into(bs, _at(Vector3(p.x, top - 0.08, p.y), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * 0.85), rng)
		_contact(ctx, p, 1.0)
		_take(ctx, p)
	# sotoba le long de l'arrivée (basses)
	for sx: float in [-1.0, 1.0]:
		var sp := Vector2(sx * 3.75, 5.2)
		var t2 := _ash_mound_into(bs, sp, 0.55, rng)
		_sotoba_into(bs, _at(Vector3(sp.x, t2 - 0.05, sp.y), Vector3(0, rng.randf_range(-0.3, 0.3), 0), Vector3.ONE * 0.8), rng)
		_take(ctx, sp)
	# lanternes flottantes sur le fleuve des morts
	var bn: Dictionary = ctx["bn"]
	for i in (6 if Toon.lite else 11):
		var p := _hub_spot(ctx, rng, 0.45, 0.8)
		if p == NONE2:
			continue
		_take(ctx, p)
		_toro_into(bn, _at(Vector3(p.x, VOID_Y, p.y), Vector3(0, rng.randf() * TAU, 0)))


## Torii noir de Yomi au-dessus de l'allée en `z` : piliers dans l'eau à ±`half`, socles au ras de l'eau,
## nuki, gakuzuka, kasagi aux bouts relevés, ofuda pâles sur les piliers.
static func _hub_dark_torii(ctx: Dictionary, z: float, half: float) -> void:
	var bs: Dictionary = ctx["bs"]
	var bn: Dictionary = ctx["bn"]
	var post := _toon(Color("#2A2430"), true, 0.03)
	var beam := _toon(Color("#141018"), true, 0.03)
	var pale := _glow(YOMI_GLOW, 1.1)
	var y0 := VOID_Y - 0.1
	var top := 2.55
	for sx: float in [-1.0, 1.0]:
		var x := sx * half
		_add(bs, post, _cyl(0.12, 0.15, top - y0, 10), _at(Vector3(x, (top + y0) * 0.5, z)))
		_add(bs, beam, _cyl(0.19, 0.2, 0.5, 10), _at(Vector3(x, VOID_Y + 0.25, z)))
		_add(bn, pale, _box(Vector3(0.09, 0.2, 0.012)), _at(Vector3(x, 1.2, z + 0.15)))
		_contact(ctx, Vector2(x, z), 0.45)
		_take(ctx, Vector2(x, z))
	_add(bs, post, _box(Vector3(half * 2.0 + 0.7, 0.16, 0.14)), _at(Vector3(0, 2.05, z)))
	_add(bs, post, _box(Vector3(0.16, 0.34, 0.12)), _at(Vector3(0, 2.3, z)))
	var w := half + 0.75
	var nk := 6
	for i in nk:
		var x0 := lerpf(-w, w, float(i) / nk)
		var x1 := lerpf(-w, w, float(i + 1) / nk)
		var ya := top + 0.22 * pow(absf(x0) / w, 2.6)
		var yb := top + 0.22 * pow(absf(x1) / w, 2.6)
		var l := Vector2(x1 - x0, yb - ya).length() + 0.03
		_add(bs, beam, _box(Vector3(l, 0.18, 0.32)), Transform3D(Basis(Vector3(0, 0, 1), atan2(yb - ya, x1 - x0)), Vector3((x0 + x1) * 0.5, (ya + yb) * 0.5, z)))
