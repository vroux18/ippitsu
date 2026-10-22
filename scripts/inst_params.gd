extends RefCounted
## Paramètres d'instance (`instance uniform`) des effets peints, sous budget.
##
## Avec le rendu Compatibility, Godot réserve 16 emplacements vec4 du tampon global des paramètres d'instance à
## CHAQUE nœud dont la matière en déclare, tant que le nœud existe (même caché, même rangé dans une réserve). Ce
## tampon est borné par GL_MAX_UNIFORM_BLOCK_SIZE : 64 Kio sur bureau (256 nœuds) mais 16 Kio sur bien des GPU de
## téléphone (Mali : 64 nœuds en tout). Au-delà, Godot refuse l'emplacement (« Too many instances using shader
## instance variables ») et le nœud lit le tampon à côté de ses emplacements : sur téléphone, des couleurs et des
## âges aberrants (grande flaque magenta au liseré cyan sous le héros, brûlure de Foyer et ondes de Marée), sur
## bureau des zéros. Les taches d'encre qui restent au sol, les traits et les quads en réserve suffisent à épuiser
## 64 places pendant un combat chargé.
##
## Ici : les BUDGET premiers nœuds vivants gardent la matière partagée (paramètres d'instance) ; au-delà, le nœud
## reçoit sa propre matière (même shader, les mêmes paramètres en `uniform` ordinaires) : même image, toujours un
## appel de dessin par effet, aucun emplacement du tampon global.

## Nœuds à paramètres d'instance vivants au plus : 56 × 16 = 896 emplacements < 1024 (16 Kio, minimum GLES3).
const BUDGET := 56

static var live := 0  # nœuds liés à une matière partagée et présents dans l'arbre
static var force_own := false  # préchauffage : forcer la matière propre (compile la variante d'avance)
static var _variants := {}  # Shader partagé -> sa variante sans paramètres d'instance


## Pose la matière de `gi` : la matière partagée `mat` tant que le budget le permet, sinon une matière propre.
static func bind(gi: GeometryInstance3D, mat: ShaderMaterial) -> void:
	if not force_own and live < BUDGET:
		gi.material_override = mat
		if gi.is_inside_tree():
			live += 1
		gi.tree_entered.connect(_enter)
		gi.tree_exiting.connect(_exit)
		return
	gi.material_override = own_material(mat)


static func _enter() -> void:
	live += 1


static func _exit() -> void:
	live = maxi(live - 1, 0)


## Règle un paramètre d'instance de `gi`, quelle que soit sa matière (partagée ou propre).
static func set_param(gi: GeometryInstance3D, pname: StringName, value: Variant) -> void:
	var m := gi.material_override
	if m != null and m.has_meta(&"ip_own"):
		(m as ShaderMaterial).set_shader_parameter(pname, value)
	else:
		gi.set_instance_shader_parameter(pname, value)


## Matière propre équivalente à `mat` : variante du shader où les paramètres d'instance sont des uniform.
static func own_material(mat: ShaderMaterial) -> ShaderMaterial:
	var sh: Shader = _variants.get(mat.shader)
	if sh == null:
		sh = Shader.new()
		sh.code = mat.shader.code.replace("instance uniform ", "uniform ")
		_variants[mat.shader] = sh
	var m := ShaderMaterial.new()
	m.shader = sh
	m.render_priority = mat.render_priority
	for u in mat.shader.get_shader_uniform_list():
		var v = mat.get_shader_parameter(u["name"])
		if v != null:
			m.set_shader_parameter(u["name"], v)
	m.set_meta(&"ip_own", true)
	return m
