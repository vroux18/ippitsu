extends RefCounted
## Reconnaissance des formes spéciales du trait (UNIVERS.md §4.8).
## Fonctions statiques pures : on travaille dans le plan XZ (y ignoré / mis à 0).
## Usage : const StrokeShapes = preload("res://scripts/stroke_shapes.gd")
##         var info: Dictionary = StrokeShapes.detect(stroke.points)
##
## Méthode : le trait est nettoyé, rééchantillonné à un pas qui suit sa longueur, puis lu par caps (direction
## d'une corde glissante) : le tremblement du pouce disparaît, les coins arrondis restent des coins. Chaque
## figure est un candidat noté (produit des conditions, 1 = toutes tenues) ; detect() prend le premier candidat
## qui tient dans l'ordre ORDER (zigzag, triangle, vague, ensō, aller-retour, boucle, pointe, trait droit,
## crochet : les portes des détecteurs les rendent exclusifs, un cercle n'est jamais un zigzag, un demi-tour serré
## jamais un crochet), near_miss() le candidat le mieux noté parmi ceux qui ont manqué, avec la condition la plus
## manquée. Les figures de l'arbre (LEARNED : vague, pointe, triangle) se distinguent des six autres par un
## critère simple : la vague a deux virages arrondis de sens opposés (le zigzag a des coins, la boucle et l'ensō
## un seul sens), la pointe un seul coin aigu et deux branches proches (le crochet, une barbe courte), le triangle
## trois coins et se referme (l'ensō est rond, le zigzag ouvert). Pas encore apprises (`locked`), elles restent
## lues mais ne rapportent rien : un geste qui a leur forme n'est AUCUNE figure (pas de repli sur la suivante dans
## l'ordre : un V de pointe verrouillée n'est pas un crochet).
## Ensō ou boucle : le même cercle est lu (grand virage d'un même sens, ou boucle entre deux croisements), puis
## c'est la taille qui tranche (SPLIT_R, ou SPLIT_CM d'écran quand main passe l'échelle), et pour un cercle moyen
## pris entre deux longues amorces, les amorces (LOOP_TAILS) : c'est une boucle dans un trait.
## Les seuils de forme sont relatifs (au rayon, à l'aller, à la longueur du trait) ; les seuls seuils absolus
## sont ceux qui ont un sens de jeu (trait droit de 7 m, aller d'au moins 3 m, rayon qui sépare boucle et ensō).
## Vérification : tools/fig_corpus.gd (`-- --figtest`) joue un corpus de gestes réalistes.

const EPS := 0.000001
const CLEAN_DIST := 0.02        # points plus proches que ça = confondus
const MIN_LENGTH := 0.5         # trait trop court : aucune forme
const SIMPLIFY_TOL := 0.3       # tolérance RDP (simplify, gardé pour les outils)

# Échelle d'analyse : pas de rééchantillonnage et corde des caps, en fraction de la longueur du trait (bornés)
const STEP_K := 0.01
const STEP_MIN := 0.05
const STEP_MAX := 0.15
const HEAD_K := 0.06
const HEAD_MIN := 0.15
const HEAD_MAX := 0.5
const RUN_TOL := 20.0           # contre-virage toléré (degrés cumulés) dans un virage « du même sens »

# Cercles : ensō (grand cercle, ouvert jusqu'à 35 %, ou dépassé) et uzu (petite boucle, dans un trait ou seule)
const CURL_MIN_R := 0.5
const SPLIT_R := 1.5            # rayon (m au sol) qui sépare la boucle (plus petite) de l'ensō (plus grand)
const SPLIT_CM := 0.7           # ... ou 0,7 cm d'écran quand l'échelle est connue (jamais sous SPLIT_R_MIN)
const SPLIT_R_MIN := 1.3
const ENSO_MIN_TURN := 210.0    # un ensō ouvert d'un bon tiers (234°) passe encore, un C (≤ 180°) jamais
const ENSO_ROUND := 0.30        # écart-type du rayon / rayon : un cercle à main levée, un peu ovale, passe
const LOOP_MIN_TURN := 230.0    # une boucle tracée vite ne se recoupe pas toujours (un « ρ », un « e » ouvert)
const LOOP_ROUND := 0.45
const LOOP_R_MAX := 2.8         # grand cercle entre deux longues amorces : encore une boucle jusqu'à ce rayon
const LOOP_TAILS := 1.1         # amorces d'au moins 1,1 rayon de part et d'autre : boucle dans un trait, pas ensō
const LOOP_CORNER := 110.0      # un vrai coin dans la boucle : un triangle de zigzag qui se recoupe, pas une boucle
const CURL_COVER := 0.65        # longueur de l'arc / (tour × rayon) : au moins 0,65, sinon ce n'est pas un cercle
const CURL_BAND := 0.25         # l'arc s'arrête là où le trait quitte la bande de ± 25 % autour du cercle ajusté
const CURL_MIN_SPAN := 170.0    # les points font le tour du centre ajusté sur au moins 170° : un croissant (demi-tour aux côtés bombés) n'est pas un cercle
const ENSO_MIN_SPAN := 195.0    # ... et sur 195° pour un ensō (le tour mesuré par les virages gonfle avec les bouts tremblés ; l'étendue vue du centre, non)
# Kaeshi (aller-retour) : demi-tour serré, retour le long de l'aller
const RET_FAR := 3.0
const RET_GAP := 1.2
const RET_GAP_K := 0.3
const RET_DEV := 1.0
const RET_DEV_K := 0.25
const RET_SAMPLES := 24
# Inazuma (zigzag) : virages nets alternés, branches droites
const ZZ_ANGLE := 70.0          # angle vrai du coin (entre les branches) ; la perspective au sol en vole jusqu'à 15°
const ZZ_SEED := 45.0           # virage sur la corde qui fait d'un point un coin possible
const ZZ_FOCUS := 0.75          # le virage sur la corde fait au moins 75 % de l'angle du coin : un coin, pas un arc (un S)
const ZZ_WIN_K := 0.1           # corde du virage : 10 % du trait, entre 0,3 et 0,9 m
const ZZ_WIN_K2 := 0.16         # seconde corde, plus longue (coins très arrondis d'un grand Z)
const ZZ_WIN_MIN := 0.3
const ZZ_WIN_MAX := 0.9
const ZZ_BRANCH_K := 0.15       # branche entre deux virages : 15 % du trait, au moins 0,5 m
const ZZ_BRANCH_MIN := 0.5
const ZZ_END_K := 0.5           # les deux bouts : au moins la moitié d'une branche
const ZZ_STRAIGHT := 0.3        # flèche d'une branche / sa longueur : une branche est droite, pas un arc (un S)
const ZZ_COUNT := 2             # un Z (2 virages) suffit
const ZZ_CURVE := 200.0         # un virage cumulé de plus de 200° dans le même sens : une courbe, pas un zigzag
# Ittō (trait droit)
const ST_LEN := 7.0
const ST_DEV := 0.5
const ST_DEV_K := 0.06
# Kagi (crochet) : un trait droit dont la fin se replie nettement en arrière, une barbe courte (le glyphe : une
# hampe et une barbe qui remonte le long d'elle). Le crochet est la figure la plus facile à faire sans le vouloir
# (un trait de combat qui tourne vers un second ennemi, le doigt qui dérape en levant) : il demande une intention
# claire, chaque critère écarte un geste naturel (tools/fig_corpus.gd, traits de combat naturels)
const HK_MIN := 112.0           # virage au coin (moyenne des deux lectures, près du coin et sur les cordes entières) :
const HK_MIN_ANY := 110.0       # la barbe revient vers la hampe (angle intérieur ≤ 68°, chaque lecture ≤ 70°) ; un L, non
const HK_MAX := 172.0           # l'aller-retour est testé avant : un retour court et replié reste un crochet
const HK_LAST := 0.9            # barbe d'au moins 0,9 m...
const HK_LAST_K := 0.155        # ... et 15,5 % du trait : une virgule du doigt qui dérape en levant n'est pas une barbe
const HK_LAST_MAX_K := 0.42     # barbe d'au plus 42 % du trait : au-delà, une seconde moitié de trait (un V, un L)
const HK_PREV := 0.8
const HK_STRAIGHT := 0.3        # flèche de la barbe / sa longueur
const HK_SHAFT := 0.1           # flèche de la hampe / sa longueur : une hampe droite, pas un trait qui s'enroule

# Figures de l'arbre (apprises dans la branche Voie) : vague (S), pointe (V), triangle.
# Kekkai (triangle) : tracé fermé à trois coins vifs, tous du même sens
const TRI_CLOSE := 0.14         # écart entre le départ et l'arrivée : au plus 14 % du trait (fermé)
const TRI_EXT_MIN := 48.0       # virage à chaque sommet (180° - angle intérieur) : au moins 48° (angle ≤ 132°)...
const TRI_EXT_MAX := 158.0      # ... au plus 158° (angle ≥ 22° : plus aigu, c'est un aller-retour)
const TRI_STRAIGHT := 0.22      # flèche d'un côté / sa longueur : des côtés droits (un cercle n'a pas de coins)
const TRI_SIDE := 0.12          # le plus petit côté fait au moins 12 % du trait
# Kunai (pointe) : un V, un seul coin aigu, deux branches de longueur proche
const PT_ANGLE := 70.0          # angle intérieur du coin, sous 70°
const PT_ANGLE_MIN := 12.0      # (plus fermé : un aller-retour)
const PT_RATIO := 0.66          # branche courte / branche longue : au moins 0,66 (un crochet a une barbe courte)
const PT_BRANCH := 1.0          # chaque branche fait au moins 1 m
const PT_STRAIGHT := 0.2        # branches droites
const PT_OTHER := 55.0          # aucun autre coin (virage sur la corde) au-delà de 55°
# Ressac (vague) : un S, deux arcs arrondis de sens opposés, aucun coin vif
const WV_ARC := 85.0            # chaque arc tourne d'au moins 85° (lu par les caps : un arc vrai de 135° en perd jusqu'à 40)
const WV_ARC_MAX := 250.0       # ... et d'au plus 250° (au-delà, une boucle)
const WV_CORNER := 62.0         # aucun virage sur la corde au-delà de 62° : arrondi, pas un zigzag
const WV_COVER := 0.6           # les deux arcs couvrent au moins 60 % du trait
const WV_BAL := 0.4             # l'arc le plus court fait au moins 40 % de la longueur du plus long

# ordre des candidats (_candidates) : le zigzag d'abord (ses portes l'excluent de toute courbe), le triangle
# (fermé mais anguleux : jamais un ensō), la vague (deux virages opposés : un grand arc de S redressé à l'écran
# ressemble à un ensō, l'ensō n'a jamais d'arc contraire), l'ensō, l'aller-retour avant la boucle (un demi-tour
# aux côtés écartés est une boucle plate, mais c'est un retour), la pointe (un V équilibré, avant le crochet), le
# trait droit, le crochet
const ORDER := ["zigzag", "triangle", "wave", "enso", "return", "loop", "point", "straight", "hook"]
# figures apprises dans l'arbre (meta.fig_learned) ; main remplit `locked` avec celles pas encore apprises :
# leur forme est lue mais ne donne aucune figure (ni la leur, ni une autre), et le diagnostic ne la propose pas
const LEARNED := ["wave", "point", "triangle"]
static var locked: Array = []


## Trait de combat : il part du héros, puis suit le doigt. Le geste du joueur commence au point `lead_n`
## (premier contact du doigt) : on lit d'abord ce geste seul, l'amorce depuis le héros ne doit pas casser la
## figure ; si le geste seul ne dit rien, le trait entier est lu. `scale` : mètres au sol par centimètre d'écran
## au niveau du geste (0 : inconnu), pour le rayon qui sépare boucle et ensō.
static func detect_lead(points: PackedVector3Array, lead_n: int, scale: float = 0.0) -> Dictionary:
	if lead_n > 0 and lead_n < points.size() - 2:
		var r := detect(points.slice(lead_n), scale)
		if not r.is_empty():
			return r
		# le trait entier, amorce comprise, ne vaut que pour le trait droit (l'amorce prolonge le geste) : partout
		# ailleurs le coin entre l'amorce et le geste fabriquerait une figure (zigzag, crochet, cercle refermé)
		r = detect(points, scale)
		if String(r.get("shape", "")) == "straight":
			return r
		return {}
	return detect(points, scale)


## Détecte la forme du trait. Renvoie {} ou {"shape": String, ...infos} :
## enso / loop : center, radius ; return : far ; zigzag : corners ; straight : dir ; hook : tip, dir ;
## wave : center ; point : tip, dir (axe du V vers la pointe) ; triangle : corners (3 sommets), center.
static func detect(points: PackedVector3Array, scale: float = 0.0) -> Dictionary:
	var f := _features(points)
	if f.is_empty():
		return {}
	for c: Dictionary in _candidates(f, scale):
		if float(c["score"]) >= 1.0:
			if String(c["shape"]) in locked:
				return {}  # la forme d'une figure pas encore apprise : aucune figure, pas de repli sur une autre
			var out := c.duplicate()
			out.erase("score")
			out.erase("reason")
			return out
	return {}


# ---------------------------------------------------------------- utilitaires publics

## Longueur totale de la polyligne.
static func length(points: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, points.size()):
		total += points[i].distance_to(points[i - 1])
	return total


## Ramer–Douglas–Peucker en 2D (XZ), version itérative.
static func simplify(points: PackedVector3Array, tolerance: float) -> PackedVector3Array:
	var n := points.size()
	if n < 3:
		return points.duplicate()
	var keep := PackedByteArray()
	keep.resize(n)
	keep.fill(0)
	keep[0] = 1
	keep[n - 1] = 1
	var stack := PackedInt32Array([0, n - 1])
	while stack.size() >= 2:
		var b := stack[stack.size() - 1]
		var a := stack[stack.size() - 2]
		stack.resize(stack.size() - 2)
		var best := -1.0
		var idx := -1
		for k in range(a + 1, b):
			var d := _seg_dist(points[k], points[a], points[b])
			if d > best:
				best = d
				idx = k
		if idx >= 0 and best > tolerance:
			keep[idx] = 1
			stack.append(a)
			stack.append(idx)
			stack.append(idx)
			stack.append(b)
	var out := PackedVector3Array()
	for i in range(n):
		if keep[i] == 1:
			out.append(points[i])
	return out


## Angle de rotation signé cumulé (degrés) le long de la polyligne, dans le plan XZ.
static func turning_deg(points: PackedVector3Array) -> float:
	var total := 0.0
	var has_prev := false
	var prev := Vector2.ZERO
	for i in range(1, points.size()):
		var d := Vector2(points[i].x - points[i - 1].x, points[i].z - points[i - 1].z)
		if d.length_squared() < EPS:
			continue
		if has_prev:
			total += atan2(prev.cross(d), prev.dot(d))
		prev = d
		has_prev = true
	return rad_to_deg(total)


# ---------------------------------------------------------------- lecture du trait

## Trait nettoyé, rééchantillonné, caps et virages. {} si le trait est trop court.
static func _features(points: PackedVector3Array) -> Dictionary:
	var p := _clean(points)
	if p.size() < 3:
		return {}
	var L := length(p)
	if L < MIN_LENGTH:
		return {}
	var step := clampf(L * STEP_K, STEP_MIN, STEP_MAX)
	var q := _resample_step(p, step)
	var n := q.size()
	var w := maxi(1, int(round(clampf(L * HEAD_K, HEAD_MIN, HEAD_MAX) / step)))
	if n < 2 * w + 3:
		w = maxi(1, (n - 3) / 2)
	# cap de la corde [i-w, i+w] en chaque point, et virage d'un cap au suivant (degrés signés)
	var head := PackedFloat32Array()
	head.resize(n)
	var turn := PackedFloat32Array()
	turn.resize(n)
	turn.fill(0.0)
	for i in range(w, n - w):
		var d := q[i + w] - q[i - w]
		head[i] = atan2(d.z, d.x)
	for i in range(w, n - w - 1):
		turn[i] = rad_to_deg(wrapf(head[i + 1] - head[i], -PI, PI))
	return {"p": p, "L": L, "q": q, "step": step, "w": w, "turn": turn, "run": _trim_run(turn, _best_run(turn, w, n - w - 1))}


## Les bouts du virage qui traînent sur les amorces droites (le bruit y fait encore un peu « tourner ») sont
## rognés : on retire, de chaque côté, les pas dont le virage moyen sur trois pas reste sous le tiers du virage
## moyen du reste. [degrés, indice de début, indice de fin]
static func _trim_run(turn: PackedFloat32Array, run: Array) -> Array:
	var i0 := int(run[1])
	var i1 := int(run[2])
	if i1 - i0 < 6:
		return run
	var lim := float(run[0]) / float(i1 - i0) * 0.35
	while i1 - i0 > 6 and absf(turn[i0] + turn[i0 + 1] + turn[i0 + 2]) / 3.0 < lim:
		i0 += 1
	while i1 - i0 > 6 and absf(turn[i1 - 1] + turn[i1 - 2] + turn[i1 - 3]) / 3.0 < lim:
		i1 -= 1
	var deg := 0.0
	for k in range(i0, i1):
		deg += turn[k]
	return [absf(deg), i0, i1]


## Plus grand virage cumulé dans un même sens (un contre-virage de moins de RUN_TOL degrés, le tremblement,
## ne le coupe pas) : [degrés, indice de début, indice de fin] dans q.
static func _best_run(turn: PackedFloat32Array, i_start: int, i_end: int) -> Array:
	var best := 0.0
	var b0 := i_start
	var b1 := i_start
	var s := 0.0
	var acc := 0.0
	var a0 := i_start
	var cnt := 0.0
	var c0 := i_start
	for i in range(i_start, i_end):
		var d := turn[i]
		if s == 0.0:
			if absf(d) > 0.01:
				s = signf(d)
			acc += d
		elif signf(d) == s or absf(d) < 0.01:
			acc += d
			cnt = 0.0
		else:
			if cnt == 0.0:
				c0 = i
			cnt += absf(d)
			acc += d
			if cnt > RUN_TOL:
				# le virage s'inverse pour de bon : nouveau virage depuis le début du contre-virage
				s = -s
				acc = s * cnt
				a0 = c0
				cnt = 0.0
		if absf(acc) > best:
			best = absf(acc)
			b0 = a0
			b1 = i + 1
	return [best, b0, b1]


## Virage (degrés signés) en chaque point entre les cordes [i-w, i] et [i, i+w].
static func _corner_turn(q: PackedVector3Array, w: int) -> PackedFloat32Array:
	var n := q.size()
	var t := PackedFloat32Array()
	t.resize(n)
	t.fill(0.0)
	for i in range(w, n - w):
		var a := Vector2(q[i].x - q[i - w].x, q[i].z - q[i - w].z)
		var b := Vector2(q[i + w].x - q[i].x, q[i + w].z - q[i].z)
		if a.length_squared() < EPS or b.length_squared() < EPS:
			continue
		t[i] = rad_to_deg(atan2(a.cross(b), a.dot(b)))
	return t


## Coins : un par série de points qui virent fort dans le même sens (le pic). [[indice, signe], ...]
static func _corners(t: PackedFloat32Array, thresh: float) -> Array:
	var out: Array = []
	var n := t.size()
	var i := 0
	while i < n:
		if absf(t[i]) <= thresh:
			i += 1
			continue
		var sg := signf(t[i])
		var best := i
		while i < n and absf(t[i]) > thresh * 0.6 and signf(t[i]) == sg:
			if absf(t[i]) > absf(t[best]):
				best = i
			i += 1
		out.append([best, sg])
	return out


# ---------------------------------------------------------------- candidats

static func _candidates(f: Dictionary, scale: float) -> Array:
	# les figures verrouillées sont lues aussi : un geste qui en a la forme ne retombe pas sur la figure suivante
	# (un V de pointe pas encore apprise n'est pas un crochet) ; detect() le lit comme aucune figure
	var curl := _curl(f, scale)
	return [_zigzag(f), _triangle(f), _wave(f), curl[0], _return(f), curl[1], _point(f), _straight(f), _hook(f)]


## Candidat : porte × produit des conditions (rapport ≥ 1 : tenue) ; la raison est la condition la plus manquée.
static func _cand(shape: String, checks: Array, gate: float, info: Dictionary = {}) -> Dictionary:
	var score := clampf(gate, 0.0, 1.0)
	var reason := ""
	var low := 2.0
	for ck: Array in checks:
		var r := clampf(float(ck[0]), 0.0, 1.0)
		score *= r
		if r < low:
			low = r
			reason = String(ck[1])
	var out := {"shape": shape, "reason": reason, "score": score}
	out.merge(info)
	return out


## Rayon qui sépare la boucle de l'ensō : 0,7 cm d'écran quand l'échelle est connue, sinon 1,5 m au sol.
static func split_radius(scale: float) -> float:
	if scale > 0.0:
		return maxf(SPLIT_R_MIN, SPLIT_CM * scale)
	return SPLIT_R


## Cercles : trois lectures, dans l'ordre (le grand virage d'un même sens, la boucle entre deux croisements du
## trait, le trait entier si le virage s'est fragmenté) ; la première qui dessine un vrai cercle (rond, de la
## longueur de son tour, qui fait le tour de son centre) décide entre ensō et boucle. Sinon les candidats les
## mieux notés servent au diagnostic. [ensō, boucle]
static func _curl(f: Dictionary, scale: float) -> Array:
	var q: PackedVector3Array = f["q"]
	var n := q.size()
	var w: int = f["w"]
	var t_all := absf(turning_deg(q))
	# [sous-trait, tour, premier indice, dernier indice dans q]
	var srcs: Array = []
	var run: Array = f["run"]
	if float(run[0]) >= 150.0:
		var i0 := int(run[1])
		var i1 := mini(n - 1, int(run[2]))
		# la corde des caps rogne les deux bouts de l'arc : le tour est aussi mesuré, segment à segment, un peu plus large
		var t_full := absf(turning_deg(q.slice(maxi(0, i0 - w), mini(n, i1 + w + 1))))
		srcs.append([q.slice(i0, i1 + 1), maxf(float(run[0]), t_full), i0, i1])
	# boucle entre deux croisements : le trait se recoupe (une boucle serrée, un ensō « fermé » en dépassant)
	var x := _first_cross(q)
	if not x.is_empty():
		var i: int = x[0]
		var j: int = x[1]
		var sub := PackedVector3Array([x[2]])
		sub.append_array(q.slice(i + 1, j + 1))
		sub.append(x[2])
		srcs.append([sub, absf(turning_deg(sub)), i + 1, j])
	# le trait entier : seulement si le grand virage s'est fragmenté (une hésitation dans l'ensō) ; sinon il ne
	# ferait que réunir une petite boucle et ses amorces dans un faux grand cercle
	if float(run[0]) < 0.85 * t_all:
		srcs.append([q, t_all, 0, n - 1])
	# coins francs (corde du zigzag) : une boucle n'en a pas
	var wz := maxi(1, int(round(clampf(float(f["L"]) * ZZ_WIN_K, ZZ_WIN_MIN, ZZ_WIN_MAX) / float(f["step"]))))
	var ct := _corner_turn(q, wz)
	var best_e := {"shape": "enso", "reason": "", "score": 0.0}
	var best_l := {"shape": "loop", "reason": "", "score": 0.0}
	var split := split_radius(scale)
	for s: Array in srcs:
		var sub: PackedVector3Array = s[0]
		if sub.size() < 4:
			continue
		var peak := 0.0
		for k in range(int(s[2]), int(s[3]) + 1):
			peak = maxf(peak, absf(ct[k]))
		var fit := _circle_fit(sub)
		if float(fit[1]) < EPS:
			continue
		# le grand virage traîne sur les amorces (le bruit y « tourne » encore) : l'arc est rogné là où le trait
		# quitte la bande du cercle, puis le cercle est réajusté sur l'arc seul
		var arc := _arc_trim(sub, fit[0], fit[1])
		if arc.size() >= 4:
			sub = arc
			fit = _circle_fit(sub)
		var c: Vector3 = fit[0]
		var r: float = fit[1]
		var rnd: float = fit[2] / maxf(r, EPS)
		if r < EPS:
			continue
		# tour de l'arc : la somme des virages (plus la corde perdue aux deux bouts), ou la lecture de la source ;
		# le geste du doigt commence et finit par une corde (points espacés) : il manque la moitié de chacune
		var turn: float = s[1]
		if s[0].size() != sub.size():
			turn = maxf(turn, absf(turning_deg(sub)) + rad_to_deg(float(f["step"]) / r))
		if int(s[2]) == 0 or int(s[3]) >= n - 1:
			var p: PackedVector3Array = f["p"]
			turn += rad_to_deg((p[1].distance_to(p[0]) + p[p.size() - 1].distance_to(p[p.size() - 2])) / (2.0 * r)) * 0.5
		# amorces avant et après le cercle, lues par la géométrie : une amorce tangente de longueur t finit à
		# √(r² + t²) du centre (plus sûr que l'indice où le virage commence)
		var tail_in := sqrt(maxf(0.0, q[0].distance_squared_to(c) - r * r))
		var tail_out := sqrt(maxf(0.0, q[n - 1].distance_squared_to(c) - r * r))
		var tails := minf(tail_in, tail_out) / maxf(r, EPS)
		# l'arc doit avoir la longueur de son tour et faire le tour de son centre : un trait qui tourne beaucoup
		# mais loin du cercle ajusté (un demi-tour aux côtés bombés) n'en est pas un
		var cov := length(sub) / maxf(deg_to_rad(turn) * r, EPS)
		var cover := minf(cov, 1.0) / CURL_COVER
		var span_deg := _angular_span(sub, c)
		var span := span_deg / CURL_MIN_SPAN
		# il faut au moins une bonne moitié de tour pour parler de cercle
		var gate := (turn - 100.0) / 100.0
		# ensō : grand, rond, presque fermé ; pas une boucle prise entre deux longues amorces (sauf très grand)
		var e_tails := 1.0 if r > LOOP_R_MAX else LOOP_TAILS / maxf(tails, EPS)
		var e := _cand("enso", [
			[minf(turn / ENSO_MIN_TURN, span_deg / ENSO_MIN_SPAN), "fais presque tout le tour"],
			[r / split, "cercle trop petit"],
			[ENSO_ROUND / maxf(rnd, EPS), "pas assez rond"],
			[e_tails, "trop de trait avant et après le cercle"],
			[cover, "pas un cercle"],
			[span, "pas un cercle"],
		], gate, {"center": c, "radius": r})
		# boucle : petit cercle (seul ou dans un trait), ou cercle moyen pris entre deux longues amorces
		var small := split / r
		if r <= LOOP_R_MAX:
			small = maxf(small, tails / LOOP_TAILS)
		var l := _cand("loop", [
			[turn / LOOP_MIN_TURN, "boucle trop plate"],
			[r / CURL_MIN_R, "boucle trop petite"],
			[LOOP_ROUND / maxf(rnd, EPS), "boucle trop écrasée"],
			[small, "trop grand pour une boucle"],
			[cover, "pas un cercle"],
			[span, "pas un cercle"],
			[LOOP_CORNER / maxf(peak, EPS), "boucle anguleuse"],
		], gate, {"center": c, "radius": r})
		# un vrai cercle : cette lecture décide
		if rnd <= LOOP_ROUND and cover >= 1.0 and span >= 1.0 and turn >= 200.0:
			return [e, l]
		if float(e["score"]) > float(best_e["score"]):
			best_e = e
		if float(l["score"]) > float(best_l["score"]):
			best_l = l
	return [best_e, best_l]


## Arc seul : les points des deux bouts qui sortent de la bande ± CURL_BAND autour du cercle (c, r) sont retirés.
static func _arc_trim(sub: PackedVector3Array, c: Vector3, r: float) -> PackedVector3Array:
	var a := 0
	var b := sub.size() - 1
	var band := CURL_BAND * r
	while a < b and absf(sub[a].distance_to(c) - r) > band:
		a += 1
	while b > a and absf(sub[b].distance_to(c) - r) > band:
		b -= 1
	return sub.slice(a, b + 1)


## Étendue angulaire (degrés) des points vus du centre c : 360 moins le plus grand trou.
static func _angular_span(p: PackedVector3Array, c: Vector3) -> float:
	if p.size() < 3:
		return 0.0
	var angs := PackedFloat32Array()
	for q: Vector3 in p:
		angs.append(atan2(q.z - c.z, q.x - c.x))
	angs.sort()
	var gap := TAU - (angs[angs.size() - 1] - angs[0])
	for i in range(1, angs.size()):
		gap = maxf(gap, angs[i] - angs[i - 1])
	return rad_to_deg(TAU - gap)

static func _return(f: Dictionary) -> Dictionary:
	var p: PackedVector3Array = f["q"]
	var start := p[0]
	var k := 0
	var far := 0.0
	for i in range(p.size()):
		var d := p[i].distance_to(start)
		if d > far:
			far = d
			k = i
	# part du trait après le point le plus loin : sans retour, ce n'est pas un aller-retour
	var back := 1.0 - float(k) / float(maxi(p.size() - 1, 1))
	if back < 0.15 or far < 0.5:
		return {"shape": "return", "reason": "reviens sur tes pas", "score": 0.0}
	var gap := start.distance_to(p[p.size() - 1])
	# aller (début -> point le plus loin) vs retour retourné (fin -> point le plus loin)
	var aller := _resample_n(p.slice(0, k + 1), RET_SAMPLES)
	var back_src := p.slice(k)
	back_src.reverse()
	var retour := _resample_n(back_src, RET_SAMPLES)
	var dev := 0.0
	for s in range(RET_SAMPLES):
		dev += aller[s].distance_to(retour[s])
	dev /= float(RET_SAMPLES)
	return _cand("return", [
		[far / RET_FAR, "aller trop court"],
		[maxf(RET_GAP, far * RET_GAP_K) / maxf(gap, EPS), "reviens jusqu'au départ"],
		[maxf(RET_DEV, far * RET_DEV_K) / maxf(dev, EPS), "retour trop écarté de l'aller"],
	], back / 0.3, {"far": p[k]})


## Coins nets du trait (sur la corde `t`) : les germes de virage, dont on retire un à un le plus mou tant que
## l'angle entre les cordes qui le relient à ses voisins (ou aux bouts) n'est pas franc, ou que le virage n'est
## pas concentré au coin (un arc). [indices dans q, angles signés aux coins]
static func _sharp(q: PackedVector3Array, t: PackedFloat32Array, min_ang: float) -> Array:
	var idx: Array = []
	for c: Array in _corners(t, ZZ_SEED):
		idx.append(int(c[0]))
	var angs: Array = []
	while true:
		angs = _chord_angles(q, idx)
		var weakest := -1
		var low := 1e9
		for k in idx.size():
			var a := absf(float(angs[k]))
			var focus := absf(t[int(idx[k])]) / maxf(a, EPS)
			var v := minf(a / min_ang, focus / ZZ_FOCUS)
			if v < 1.0 and v < low:
				low = v
				weakest = k
		if weakest < 0:
			break
		idx.remove_at(weakest)
	return [idx, angs]


## Kekkai (triangle) : tracé fermé, trois sommets (les coins nets, et la fermeture quand le trait y tourne : un
## triangle commencé sur un sommet), tous du même sens, côtés droits. Info : corners (les trois sommets),
## center (leur barycentre).
static func _triangle(f: Dictionary) -> Dictionary:
	var q: PackedVector3Array = f["q"]
	var n := q.size()
	var L: float = f["L"]
	var none := {"shape": "triangle", "reason": "il faut trois coins", "score": 0.0, "corners": [], "center": q[0]}
	var wz := maxi(1, int(round(clampf(L * ZZ_WIN_K, ZZ_WIN_MIN, ZZ_WIN_MAX) / float(f["step"]))))
	if n < 2 * wz + 3:
		return none
	var gap := q[0].distance_to(q[n - 1])
	var close_r := TRI_CLOSE * L / maxf(gap, EPS)
	var sh := _sharp(q, _corner_turn(q, wz), TRI_EXT_MIN)
	var idx: Array = sh[0]
	if idx.size() < 2 or idx.size() > 4:
		if idx.size() >= 1:
			none["score"] = 0.3 * minf(close_r, 1.0)
		return none
	# sommets : les coins ; avec deux coins, la fermeture (milieu du départ et de l'arrivée) si le trait y tourne
	# (départ sur un sommet) ; trois coins : départ au milieu d'un côté, ou départ sur un sommet repassé
	var vs: Array = []
	for i: int in idx:
		vs.append(q[i])
	var p0 := (q[0] + q[n - 1]) * 0.5
	if vs.size() == 2 and absf(_turn_at(vs[1], p0, vs[0])) >= TRI_EXT_MIN * 0.8:
		vs.insert(0, p0)
	elif vs.size() == 4 and (vs[3] as Vector3).distance_to(vs[0]) < 0.12 * L:
		# quatre coins : le dernier est le premier repassé (le doigt a dépassé le départ)
		vs.remove_at(3)
	var cnt := vs.size()
	var ext_lo := 0.0
	var ext_hi := 180.0
	var same := 1.0
	var straight := 1.0
	var side_min := 0.0
	if cnt == 3:
		ext_lo = 1e9
		ext_hi = 0.0
		side_min = 1e9
		straight = 0.0
		var sgn := 0.0
		for k in 3:
			var tr := _turn_at(vs[(k + 2) % 3], vs[k], vs[(k + 1) % 3])
			if sgn == 0.0:
				sgn = signf(tr)
			elif signf(tr) != sgn:
				same = 0.0
			ext_lo = minf(ext_lo, absf(tr))
			ext_hi = maxf(ext_hi, absf(tr))
			side_min = minf(side_min, (vs[k] as Vector3).distance_to(vs[(k + 1) % 3]))
		# côtés droits : flèche du trait entre deux coins successifs (et des bouts aux coins)
		var cuts: Array = [0]
		cuts.append_array(idx)
		cuts.append(n - 1)
		for k in range(1, cuts.size()):
			var i0: int = cuts[k - 1]
			var i1: int = cuts[k]
			if i1 - i0 >= 2 and q[i0].distance_to(q[i1]) >= 0.12 * L:  # (pas les bouts qui dépassent un sommet)
				straight = maxf(straight, _sagitta(q, i0, i1) / maxf(q[i0].distance_to(q[i1]), EPS))
	var c3 := Vector3.ZERO
	for v: Vector3 in vs:
		c3 += v
	c3 /= float(maxi(cnt, 1))
	return _cand("triangle", [
		[1.0 if cnt == 3 else 0.5, "il faut trois coins"],
		[close_r, "ferme ton triangle"],
		[same, "tourne toujours du même côté"],
		[ext_lo / TRI_EXT_MIN, "angles trop ouverts"],
		[TRI_EXT_MAX / maxf(ext_hi, EPS), "angle trop aigu"],
		[TRI_STRAIGHT / maxf(straight, EPS), "côtés trop courbes"],
		[side_min / (TRI_SIDE * L), "un côté trop court"],
	], 1.0, {"corners": vs, "center": c3})


## Virage signé (degrés) en b, entre les directions a -> b et b -> c (plan XZ).
static func _turn_at(a: Vector3, b: Vector3, c: Vector3) -> float:
	var u := Vector2(b.x - a.x, b.z - a.z)
	var v := Vector2(c.x - b.x, c.z - b.z)
	if u.length_squared() < EPS or v.length_squared() < EPS:
		return 0.0
	return rad_to_deg(atan2(u.cross(v), u.dot(v)))


## Kunai (pointe) : un V, un seul coin net et aigu, deux branches droites de longueur proche.
## Info : tip (la pointe), dir (axe du V, de l'ouverture vers la pointe).
static func _point(f: Dictionary) -> Dictionary:
	var q: PackedVector3Array = f["q"]
	var n := q.size()
	var L: float = f["L"]
	var wz := maxi(1, int(round(clampf(L * ZZ_WIN_K, ZZ_WIN_MIN, ZZ_WIN_MAX) / float(f["step"]))))
	var none := {"shape": "point", "reason": "un seul coin aigu", "score": 0.0, "tip": q[n - 1], "dir": Vector3.ZERO}
	if n < 2 * wz + 3:
		return none
	var t := _corner_turn(q, wz)
	# le coin : le plus fort virage sur la corde ; aucun autre coin net hors de son arrondi
	var c := 0
	for i in n:
		if absf(t[i]) > absf(t[c]):
			c = i
	if absf(t[c]) < 45.0:
		return none
	var other := 0.0
	for i in n:
		if absi(i - c) > 2 * wz:
			other = maxf(other, absf(t[i]))
	var a_len := length(q.slice(0, c + 1))
	var b_len := length(q.slice(c))
	var ang := _angle_change(q[0] - q[c], q[n - 1] - q[c])  # angle intérieur, entre les deux branches
	var ratio := minf(a_len, b_len) / maxf(maxf(a_len, b_len), EPS)
	var straight := maxf(_sagitta(q, 0, c) / maxf(a_len, EPS), _sagitta(q, c, n - 1) / maxf(b_len, EPS))
	var mid := (q[0] + q[n - 1]) * 0.5
	return _cand("point", [
		[PT_ANGLE / maxf(ang, EPS), "pointe trop ouverte"],
		[ang / PT_ANGLE_MIN, "trop replié, presque un aller-retour"],
		[ratio / PT_RATIO, "branches de longueurs trop différentes"],
		[minf(a_len, b_len) / PT_BRANCH, "branches trop courtes"],
		[PT_STRAIGHT / maxf(straight, EPS), "branches courbes"],
		[PT_OTHER / maxf(other, EPS), "un seul coin"],
	], (absf(t[c]) - 45.0) / 30.0, {"tip": q[c], "dir": _flat_dir(q[c] - mid)})


## Ressac (vague) : un S, deux virages de sens opposés (le plus grand, puis le plus grand de l'autre sens, avant
## ou après lui), arrondis (aucun coin net), qui couvrent l'essentiel du trait. Info : center (milieu du trait).
static func _wave(f: Dictionary) -> Dictionary:
	var q: PackedVector3Array = f["q"]
	var n := q.size()
	var L: float = f["L"]
	var w: int = f["w"]
	var turn: PackedFloat32Array = f["turn"]
	var run: Array = f["run"]
	var none := {"shape": "wave", "reason": "deux courbes opposées", "score": 0.0, "center": q[n / 2]}
	var i0 := int(run[1])
	var i1 := int(run[2])
	var sg := 0.0
	for k in range(i0, i1):
		sg += turn[k]
	sg = signf(sg)
	# l'autre arc : le plus grand virage de l'autre sens, avant ou après le premier
	var best := 0.0
	var b0 := 0
	var b1 := 0
	for rg: Array in [[w, i0], [i1, n - w - 1]]:
		if int(rg[1]) - int(rg[0]) < 3:
			continue
		var r2 := _trim_run(turn, _best_run(turn, int(rg[0]), int(rg[1])))
		var s2 := 0.0
		for k in range(int(r2[1]), int(r2[2])):
			s2 += turn[k]
		if signf(s2) == -sg and absf(s2) > best:
			best = absf(s2)
			b0 = int(r2[1])
			b1 = int(r2[2])
	var a1 := float(run[0])
	if best <= 0.0:
		none["score"] = 0.2 * minf(a1 / WV_ARC, 1.0)
		return none
	var lo := minf(a1, best)
	var hi := maxf(a1, best)
	var la := length(q.slice(i0, i1 + 1))
	var lb := length(q.slice(b0, b1 + 1))
	var cover := length(q.slice(mini(i0, b0), maxi(i1, b1) + 1)) / maxf(L, EPS)
	# aucun coin net : le virage sur la corde du zigzag reste doux partout
	var wz := maxi(1, int(round(clampf(L * ZZ_WIN_K, ZZ_WIN_MIN, ZZ_WIN_MAX) / float(f["step"]))))
	var peak := 0.0
	if n >= 2 * wz + 3:
		var ct := _corner_turn(q, wz)
		for k in n:
			peak = maxf(peak, absf(ct[k]))
	return _cand("wave", [
		[lo / WV_ARC, "courbes trop plates"],
		[WV_ARC_MAX / maxf(hi, EPS), "trop enroulé, presque une boucle"],
		[WV_CORNER / maxf(peak, EPS), "trop anguleux : arrondis les courbes"],
		[cover / WV_COVER, "trop de trait droit autour du S"],
		[minf(la, lb) / maxf(maxf(la, lb), EPS) / WV_BAL, "courbes trop inégales"],
	], 1.0, {"center": q[n / 2]})


## Deux cordes de virage (courte pour un W aux branches courtes, longue pour un Z aux coins très arrondis) :
## on garde la lecture la mieux notée.
static func _zigzag(f: Dictionary) -> Dictionary:
	var best := _zigzag_w(f, ZZ_WIN_K)
	var alt := _zigzag_w(f, ZZ_WIN_K2)
	if float(alt["score"]) > float(best["score"]):
		return alt
	return best


static func _zigzag_w(f: Dictionary, win_k: float) -> Dictionary:
	var q: PackedVector3Array = f["q"]
	var n := q.size()
	var L: float = f["L"]
	var step: float = f["step"]
	var wz := maxi(1, int(round(clampf(L * win_k, ZZ_WIN_MIN, ZZ_WIN_MAX) / step)))
	if n < 2 * wz + 3:
		return {"shape": "zigzag", "reason": "il faut deux virages nets", "score": 0.0, "corners": []}
	var branch := maxf(ZZ_BRANCH_MIN, L * ZZ_BRANCH_K)
	# coins possibles (virage sur la corde) ; l'angle vrai d'un coin est celui entre les cordes qui le relient à
	# ses voisins (ou aux bouts) : l'arrondi du coin ne compte plus. Les faux coins (bosses du tremblement) sont
	# retirés un à un, le plus mou d'abord, jusqu'à ce que tous soient nets.
	var t := _corner_turn(q, wz)
	var idx: Array = []
	for c: Array in _corners(t, ZZ_SEED):
		idx.append(int(c[0]))
	var angs: Array = []
	var soft := 0
	while true:
		angs = _chord_angles(q, idx)
		var weakest := -1
		var low := 1e9
		for k in idx.size():
			var a := absf(float(angs[k]))
			# un coin net : l'angle entre les branches est franc, et il est concentré au coin (le virage sur la corde
			# en fait l'essentiel) ; sur un arc (un S), le virage se répartit et la corde n'en voit qu'une moitié
			var focus := absf(t[int(idx[k])]) / maxf(a, EPS)
			var v := minf(a / ZZ_ANGLE, focus / ZZ_FOCUS)
			if v < 1.0 and v < low:
				low = v
				weakest = k
		if weakest < 0:
			break
		if low >= 0.6:
			soft += 1
		idx.remove_at(weakest)
	# plus longue suite de coins alternés séparés de vraies branches droites
	var best: Array = []
	var run: Array = []
	var weak := ""  # la raison du dernier coin écarté
	for k in idx.size():
		var ci: int = idx[k]
		var sg := signf(float(angs[k]))
		if not run.is_empty():
			var prev: Array = run[run.size() - 1]
			var pi: int = prev[0]
			var bl := length(q.slice(pi, ci + 1))
			var why := ""
			if sg == float(prev[1]):
				why = "virages dans le même sens"
			elif bl < branch:
				why = "branches trop courtes"
			elif _sagitta(q, pi, ci) / maxf(bl, EPS) > ZZ_STRAIGHT:
				why = "branches courbes"
			if why != "":
				weak = why
				if run.size() > best.size():
					best = run.duplicate()
				run = []
		run.append([ci, sg])
	if run.size() > best.size():
		best = run
	var cnt := best.size()
	var ends := 1.0
	var pts: Array = []
	if cnt >= 1:
		var c0: int = best[0][0]
		var c1: int = best[cnt - 1][0]
		ends = minf(length(q.slice(0, c0 + 1)), length(q.slice(c1))) / (branch * ZZ_END_K)
		for c: Array in best:
			pts.append(q[int(c[0])])
	var reason := "il faut deux virages nets"
	if cnt < ZZ_COUNT:
		if weak != "":
			reason = weak
		elif soft > 0:
			reason = "angles trop doux"
	# un virage cumulé de plus d'un demi-tour dans le même sens : c'est une courbe (boucle ratée), pas un zigzag
	var gate := clampf((ZZ_CURVE + 60.0 - float(f["run"][0])) / 60.0, 0.0, 1.0)
	var count_r := float(cnt) / float(ZZ_COUNT)
	if cnt < ZZ_COUNT and cnt + soft >= ZZ_COUNT:
		count_r = maxf(count_r, 0.6)
	return _cand("zigzag", [
		[count_r, reason],
		[ends, "les deux bouts doivent être de vraies branches"],
	], gate, {"corners": pts})


## Angle signé (degrés) en chaque coin entre la corde qui vient du coin précédent (ou du départ) et celle qui
## va au coin suivant (ou à l'arrivée).
static func _chord_angles(q: PackedVector3Array, idx: Array) -> Array:
	var out: Array = []
	var n := q.size()
	for k in idx.size():
		var ci: int = idx[k]
		var pi: int = idx[k - 1] if k > 0 else 0
		var ni: int = idx[k + 1] if k + 1 < idx.size() else n - 1
		var a := Vector2(q[ci].x - q[pi].x, q[ci].z - q[pi].z)
		var b := Vector2(q[ni].x - q[ci].x, q[ni].z - q[ci].z)
		if a.length_squared() < EPS or b.length_squared() < EPS:
			out.append(0.0)
		else:
			out.append(rad_to_deg(atan2(a.cross(b), a.dot(b))))
	return out

## Flèche : plus grand écart des points de q entre les indices a et b à la corde [q[a], q[b]].
static func _sagitta(q: PackedVector3Array, a: int, b: int) -> float:
	var d := 0.0
	for k in range(a + 1, b):
		d = maxf(d, _seg_dist(q[k], q[a], q[b]))
	return d


static func _straight(f: Dictionary) -> Dictionary:
	var p: PackedVector3Array = f["q"]
	var L: float = f["L"]
	var a := p[0]
	var b := p[p.size() - 1]
	var dev := _sagitta(p, 0, p.size() - 1)
	var tol := maxf(ST_DEV, L * ST_DEV_K)
	return _cand("straight", [
		[L / ST_LEN, "trop court"],
		[tol / maxf(dev, EPS), "trop sinueux pour un trait droit"],
	], (2.5 * tol - dev) / (1.5 * tol), {"dir": _flat_dir(b - a)})  # un trait franchement courbe ou cassé n'est pas « presque droit »


static func _hook(f: Dictionary) -> Dictionary:
	var q: PackedVector3Array = f["q"]
	var n := q.size()
	var L: float = f["L"]
	var step: float = f["step"]
	var wz := maxi(1, int(round(clampf(L * ZZ_WIN_K, ZZ_WIN_MIN, ZZ_WIN_MAX) / step)))
	var none := {"shape": "hook", "reason": "", "score": 0.0, "tip": q[n - 1], "dir": _flat_dir(q[n - 1] - q[0])}
	if n < 2 * wz + 3:
		return none
	var corners := _corners(_corner_turn(q, wz), 60.0)
	if corners.is_empty():
		return none
	var c: int = corners[corners.size() - 1][0]
	var last := length(q.slice(c))
	var prev := length(q.slice(0, c + 1))
	# directions avant et après le coin, prises hors de son arrondi (un tiers de chaque côté, au plus un mètre)
	var m0 := mini(c, int(round(minf(prev * 0.35, 1.0) / step)))
	var m := maxi(1, mini(c - m0, int(round(minf(prev, 1.0) / step))))
	var before := q[c - m0] - q[c - m0 - m]
	var a0 := mini(n - 2, c + int(round(minf(last * 0.35, 1.0) / step)))
	var after := q[n - 1] - q[a0]
	var ang := _angle_change(before, after)
	# même virage lu sur les cordes entières (départ -> coin -> fin) : un L au coin très arrondi, mesuré près du
	# coin, paraît plus replié qu'il n'est ; la hampe entière dit d'où vient le trait
	var ang_c := _angle_change(q[c] - q[0], q[n - 1] - q[c])
	var straight := _sagitta(q, c, n - 1) / maxf(last, EPS)
	var shaft := _sagitta(q, 0, c) / maxf(prev, EPS)
	# un retour qui revient presque au départ est un aller-retour (inachevé, en direct) : pas un crochet
	var far := 0.0
	for pt: Vector3 in q:
		far = maxf(far, pt.distance_to(q[0]))
	var gap := q[n - 1].distance_to(q[0])
	var not_ret := 1.0 if far < RET_FAR else gap / (1.25 * maxf(RET_GAP, far * RET_GAP_K))
	return _cand("hook", [
		[last / maxf(HK_LAST, L * HK_LAST_K), "crochet trop court"],
		[L * HK_LAST_MAX_K / maxf(last, EPS), "crochet trop long : la barbe est courte"],
		[prev / HK_PREV, "premier trait trop court"],
		[HK_SHAFT / maxf(shaft, EPS), "premier trait trop courbe"],
		[(ang + ang_c) * 0.5 / HK_MIN, "repars plus en arrière"],
		[minf(ang, ang_c) / HK_MIN_ANY, "repars plus en arrière"],
		[HK_MAX / maxf(ang, EPS), "trop replié, presque un aller-retour"],
		[not_ret, "trop replié, presque un aller-retour"],
		[HK_STRAIGHT / maxf(straight, EPS), "crochet trop courbe"],
	], (ang - 60.0) / 50.0, {"tip": q[n - 1], "dir": _flat_dir(after)})


# ---------------------------------------------------------------- aides internes

## Copie à plat (y = 0) sans points confondus.
static func _clean(points: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p: Vector3 in points:
		var q := Vector3(p.x, 0.0, p.z)
		if out.is_empty() or q.distance_to(out[out.size() - 1]) >= CLEAN_DIST:
			out.append(q)
	return out


## Distance 2D (XZ) du point p au segment [a, b].
static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ap := Vector2(p.x - a.x, p.z - a.z)
	var l2 := ab.length_squared()
	if l2 < EPS:
		return ap.length()
	var t := clampf(ap.dot(ab) / l2, 0.0, 1.0)
	return (ap - ab * t).length()


## Croisement strict de [ab] et [cd] en XZ : renvoie le paramètre t sur [ab], ou -1.
static func _seg_hit(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> float:
	var r := Vector2(b.x - a.x, b.z - a.z)
	var s := Vector2(d.x - c.x, d.z - c.z)
	var den := r.cross(s)
	if absf(den) < EPS:
		return -1.0
	var q := Vector2(c.x - a.x, c.z - a.z)
	var t := q.cross(s) / den
	var u := q.cross(r) / den
	if t <= 0.0 or t >= 1.0 or u <= 0.0 or u >= 1.0:
		return -1.0
	return t


## Premier croisement du trait avec lui-même qui enferme la plus grande boucle : [i, j, point], ou [].
static func _first_cross(q: PackedVector3Array) -> Array:
	var n := q.size()
	var best: Array = []
	var best_len := 0.0
	for i in range(n - 1):
		for j in range(i + 2, n - 1):
			var t := _seg_hit(q[i], q[i + 1], q[j], q[j + 1])
			if t < 0.0:
				continue
			var l := length(q.slice(i + 1, j + 1))
			if l > best_len:
				best_len = l
				best = [i, j, q[i].lerp(q[i + 1], t)]
	return best


## Barycentre pondéré par la longueur des segments.
static func _centroid(p: PackedVector3Array) -> Vector3:
	var acc := Vector3.ZERO
	var tot := 0.0
	for i in range(1, p.size()):
		var l := p[i].distance_to(p[i - 1])
		acc += (p[i] + p[i - 1]) * (0.5 * l)
		tot += l
	if tot < EPS:
		acc = Vector3.ZERO
		for q: Vector3 in p:
			acc += q
		return acc / float(maxi(1, p.size()))
	return acc / tot


## Cercle des moindres carrés : [centre, rayon moyen, écart-type du rayon]. Ajustement algébrique (Kåsa) puis
## quelques pas d'ajustement géométrique (Landau) : l'algébrique sous-estime le rayon d'un arc bruité, et le
## barycentre seul d'un C est tiré vers l'arc (son rayon paraît irrégulier).
static func _circle_fit(p: PackedVector3Array) -> Array:
	var c0 := _kasa(p)
	var m := Vector3.ZERO
	for q: Vector3 in p:
		m += q
	m /= float(p.size())
	var c := c0
	for _it in 6:
		var r := 0.0
		var u := Vector3.ZERO
		for q: Vector3 in p:
			var d := q.distance_to(c)
			r += d
			if d > EPS:
				u += (c - q) / d
		r /= float(p.size())
		u /= float(p.size())
		var nc := m + u * r
		if nc.distance_to(c) < 0.001:
			c = nc
			break
		c = nc
	# si l'ajustement géométrique s'égare (points presque alignés), on garde le premier
	if c.distance_to(c0) > 2.0 * _radius_stats(p, c0).x:
		c = c0
	var st := _radius_stats(p, c)
	return [c, st.x, st.y]


## Ajustement algébrique (Kåsa) : le centre du cercle, ou le barycentre si les points sont presque alignés.
static func _kasa(p: PackedVector3Array) -> Vector3:
	var g := _centroid(p)
	var sxx := 0.0
	var syy := 0.0
	var sxy := 0.0
	var sxz := 0.0
	var syz := 0.0
	var n := float(p.size())
	var sx := 0.0
	var sy := 0.0
	var sz := 0.0
	for q: Vector3 in p:
		var x := q.x - g.x
		var y := q.z - g.z
		var z := x * x + y * y
		sx += x
		sy += y
		sz += z
		sxx += x * x
		syy += y * y
		sxy += x * y
		sxz += x * z
		syz += y * z
	# résout [sxx sxy sx ; sxy syy sy ; sx sy n] · [a b c] = -[sxz syz sz]
	var det := sxx * (syy * n - sy * sy) - sxy * (sxy * n - sy * sx) + sx * (sxy * sy - syy * sx)
	var c := g
	if absf(det) > EPS:
		var a := (-sxz * (syy * n - sy * sy) - sxy * (-syz * n + sy * sz) + sx * (-syz * sy + syy * sz)) / det
		var b := (sxx * (-syz * n + sy * sz) + sxz * (sxy * n - sy * sx) + sx * (-sxy * sz + syz * sx)) / det
		c = Vector3(g.x - a * 0.5, 0.0, g.z - b * 0.5)
		# un ajustement aberrant (points presque alignés) : on garde le barycentre
		if c.distance_to(g) > 4.0 * sqrt(sz / n):
			c = g
	return c


## Rayon moyen (x) et écart-type du rayon (y) autour de c.
static func _radius_stats(p: PackedVector3Array, c: Vector3) -> Vector2:
	if p.is_empty():
		return Vector2.ZERO
	var m := 0.0
	for q: Vector3 in p:
		m += q.distance_to(c)
	m /= float(p.size())
	var v := 0.0
	for q: Vector3 in p:
		var e := q.distance_to(c) - m
		v += e * e
	v /= float(p.size())
	return Vector2(m, sqrt(v))


## Rééchantillonne la polyligne en `count` points régulièrement espacés.
static func _resample_n(p: PackedVector3Array, count: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	if p.is_empty():
		return out
	var total := length(p)
	if total < EPS or count < 2 or p.size() < 2:
		for _k in range(maxi(count, 1)):
			out.append(p[0])
		return out
	var step_l := total / float(count - 1)
	var i := 1
	var acc := 0.0
	for k in range(count):
		var target := step_l * float(k)
		while i < p.size() - 1 and acc + p[i].distance_to(p[i - 1]) < target:
			acc += p[i].distance_to(p[i - 1])
			i += 1
		var sl := p[i].distance_to(p[i - 1])
		var t := 0.0
		if sl >= EPS:
			t = clampf((target - acc) / sl, 0.0, 1.0)
		out.append(p[i - 1].lerp(p[i], t))
	return out


static func _resample_step(p: PackedVector3Array, step: float) -> PackedVector3Array:
	var n := maxi(2, int(ceil(length(p) / step)) + 1)
	return _resample_n(p, n)


## Angle (0..180°) entre deux directions, en XZ.
static func _angle_change(a: Vector3, b: Vector3) -> float:
	var va := Vector2(a.x, a.z)
	var vb := Vector2(b.x, b.z)
	var la := va.length()
	var lb := vb.length()
	if la < EPS or lb < EPS:
		return 0.0
	return rad_to_deg(acos(clampf(va.dot(vb) / (la * lb), -1.0, 1.0)))


static func _flat_dir(v: Vector3) -> Vector3:
	var f := Vector3(v.x, 0.0, v.z)
	if f.length_squared() < EPS:
		return Vector3.ZERO
	return f.normalized()


# ---------------------------------------------------------------- diagnostic (dojo)
# Trait non reconnu : la figure la plus proche et la condition qui a manqué, avec les mêmes candidats que detect().

const FIG_NAMES := {"enso": "un ensō", "loop": "une boucle", "return": "un aller-retour", "zigzag": "un zigzag", "straight": "un trait droit", "hook": "un crochet",
	"wave": "une vague", "point": "une pointe", "triangle": "un triangle"}
const NEAR_MIN := 0.35  # sous ce score : trait simple, aucune figure en vue


## Phrase d'un résultat de near_miss() (vide si le trait est reconnu).
static func describe(m: Dictionary) -> String:
	if m.is_empty():
		return ""
	var sh := String(m.get("shape", ""))
	var why := String(m.get("reason", ""))
	if sh == "":
		if why == "trop court":
			return "Trait trop court"
		return "Trait simple : aucune figure"
	return "Presque %s : %s" % [String(FIG_NAMES.get(sh, sh)), why]


## Figure la plus proche d'un trait non reconnu.
## Renvoie {} si le trait est reconnu, sinon {"shape": figure ("" : aucune), "reason": String, "score": 0..1}.
static func near_miss(points: PackedVector3Array, scale: float = 0.0) -> Dictionary:
	var f := _features(points)
	if f.is_empty():
		return {"shape": "", "reason": "trop court", "score": 0.0}
	var best: Dictionary = {"shape": "", "reason": "aucune figure", "score": 0.0}
	for c: Dictionary in _candidates(f, scale):
		if String(c["shape"]) in locked:
			if float(c["score"]) >= 1.0:
				break  # la forme d'une figure pas apprise : le diagnostic ne la nomme pas, ni une autre à sa place
			continue
		if float(c["score"]) >= 1.0:
			return {}
		if float(c["score"]) > float(best["score"]):
			best = c
	if float(best["score"]) < NEAR_MIN:
		return {"shape": "", "reason": "aucune figure", "score": float(best["score"])}
	return {"shape": String(best["shape"]), "reason": String(best["reason"]), "score": float(best["score"])}


# ---------------------------------------------------------------- auto-test

static func _poly(coords: PackedVector2Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for c: Vector2 in coords:
		out.append(Vector3(c.x, 0.0, c.y))
	return out


static func _check(fails: Array, name: String, pts: PackedVector3Array, expected: String) -> void:
	var r := detect(pts)
	var got := ""
	if r.has("shape"):
		got = str(r["shape"])
	if got != expected:
		fails.append("%s : attendu '%s', obtenu '%s'" % [name, expected, got])


## Polylignes synthétiques -> liste des échecs (vide si tout passe). Le corpus complet : tools/fig_corpus.gd.
static func self_test() -> Array:
	var fails: Array = []
	var step := 0.18
	# Ensō : cercle r2.5 ouvert de 1 m, léger tremblement
	var circ := PackedVector3Array()
	var gap := 2.0 * asin(0.5 / 2.5)
	for k in range(121):
		var t := (TAU - gap) * float(k) / 120.0
		var rr := 2.5 + 0.1 * sin(5.0 * t)
		circ.append(Vector3(3.0 + rr * cos(t), 0.0, 1.0 + rr * sin(t)))
	_check(fails, "enso", _resample_step(circ, step), "enso")
	# Ensō à main levée : ovale, cabossé, ouvert d'un quart de rayon de plus
	var ov := PackedVector3Array()
	for k in range(101):
		var t2 := (TAU - 0.55) * float(k) / 100.0
		var r2 := 2.2 + 0.35 * sin(3.0 * t2 + 0.7)
		ov.append(Vector3(r2 * 1.25 * cos(t2), 0.0, r2 * 0.85 * sin(t2)))
	_check(fails, "enso main levée", _resample_step(ov, step), "enso")
	# Uzu : boucle (trochoïde) au milieu d'un trait droit
	var R := 1.4
	var sp := 0.5
	var lp := PackedVector3Array([Vector3(-sp * PI - 4.0, 0.0, 2.0 * R)])
	for k in range(81):
		var t := -PI + TAU * float(k) / 80.0
		lp.append(Vector3(sp * t - R * sin(t), 0.0, R - R * cos(t)))
	lp.append(Vector3(sp * PI + 4.0, 0.0, 2.0 * R))
	_check(fails, "loop", _resample_step(lp, step), "loop")
	# Uzu ouverte : amorce droite, 300° d'arc de rayon 1,2, sortie sans se recouper (un « ρ » tracé vite)
	var lo := PackedVector3Array([Vector3(-3.0, 0.0, 0.0), Vector3(-1.5, 0.0, 0.0)])
	for k in range(61):
		var t3 := -PI / 2.0 + deg_to_rad(300.0) * float(k) / 60.0
		lo.append(Vector3(1.2 * cos(t3), 0.0, 1.2 + 1.2 * sin(t3)))
	lo.append(Vector3(-2.4, 0.0, 3.2))
	_check(fails, "boucle ouverte", _resample_step(lo, step), "loop")
	# Ensō dépassé : grand cercle r2.2 bouclé à 400° (le doigt a continué après la fermeture) -> ensō, pas boucle
	var ov2 := PackedVector3Array()
	for k in range(111):
		var t4 := deg_to_rad(400.0) * float(k) / 110.0
		ov2.append(Vector3(2.2 * cos(t4), 0.0, 2.2 * sin(t4)))
	_check(fails, "enso dépassé", _resample_step(ov2, step), "enso")
	# Ensō ouvert d'un tiers (r2.0, 260°) -> ensō (tolérant), pas boucle
	var ov3 := PackedVector3Array()
	for k in range(81):
		var t5 := deg_to_rad(260.0) * float(k) / 80.0
		ov3.append(Vector3(2.0 * cos(t5), 0.0, 2.0 * sin(t5)))
	_check(fails, "enso ouvert", _resample_step(ov3, step), "enso")
	# Kaeshi : aller-retour légèrement décalé
	_check(fails, "return", _resample_step(_poly(PackedVector2Array([Vector2(0, 0), Vector2(5, 0), Vector2(5, 0.4), Vector2(0.3, 0.5)])), step), "return")
	# Inazuma : 3 angles vifs
	_check(fails, "zigzag", _resample_step(_poly(PackedVector2Array([Vector2(0, 0), Vector2(1, 2), Vector2(2, 0), Vector2(3, 2), Vector2(4, 0)])), step), "zigzag")
	# Ittō : droite de 8 m
	_check(fails, "straight", _resample_step(_poly(PackedVector2Array([Vector2(0, 0), Vector2(8, 0.2)])), step), "straight")
	# Z tracé au pad : 2 virages, branches longues
	_check(fails, "zigzag Z", _resample_step(_poly(PackedVector2Array([Vector2(0, 0), Vector2(6, 0), Vector2(0.5, 4), Vector2(6.5, 4)])), step), "zigzag")
	# Kagi : 5 m puis retour à 150° sur 1.8 m
	var hk := deg_to_rad(30.0)
	_check(fails, "hook", _resample_step(_poly(PackedVector2Array([Vector2(0, 0), Vector2(5, 0), Vector2(5.0 - 1.8 * cos(hk), 1.8 * sin(hk))])), step), "hook")
	# petit cercle refermé (r 1.1) sans croisement : boucle
	var sc := PackedVector3Array()
	for k in range(61):
		var t3 := (TAU - 0.3) * float(k) / 60.0
		sc.append(Vector3(1.1 * cos(t3), 0.0, 1.1 * sin(t3)))
	_check(fails, "petite boucle fermée", _resample_step(sc, step), "loop")
	# aller-retour long et approximatif (combat)
	_check(fails, "return large", _resample_step(_poly(PackedVector2Array([Vector2(0, 0), Vector2(8, 0), Vector2(8.3, 0.6), Vector2(0.6, 0.9)])), step), "return")
	# ensō tracé loin du héros : amorce droite depuis le héros, puis le cercle du doigt
	var lead := _resample_step(_poly(PackedVector2Array([Vector2(-4, -5), Vector2(5.5, 1.0)])), step)
	var nl := lead.size() - 1
	lead.append_array(_resample_step(circ.slice(0), step).slice(1))
	var rl := detect_lead(lead, nl)
	if String(rl.get("shape", "")) != "enso":
		fails.append("enso avec amorce : attendu 'enso', obtenu '%s'" % String(rl.get("shape", "")))
	# éclair tracé vite au doigt : coins arrondis (deux lissages de Chaikin), virages d'environ 120°
	var zr := _poly(PackedVector2Array([Vector2(0, 0), Vector2(3, 1.6), Vector2(0.6, 3.0), Vector2(3.6, 4.6)]))
	for _it in 2:
		var sm := PackedVector3Array([zr[0]])
		for k in range(zr.size() - 1):
			sm.append(zr[k].lerp(zr[k + 1], 0.25))
			sm.append(zr[k].lerp(zr[k + 1], 0.75))
		sm.append(zr[zr.size() - 1])
		zr = sm
	_check(fails, "zigzag arrondi", _resample_step(zr, step), "zigzag")
	# gribouillis court
	var scr := PackedVector3Array()
	for k in range(18):
		scr.append(Vector3(0.18 * float(k), 0.0, 0.25 * sin(float(k) * 1.7) + 0.1 * cos(float(k) * 3.1)))
	_check(fails, "scribble", scr, "")
	# cas dégénérés
	_check(fails, "vide", PackedVector3Array(), "")
	_check(fails, "un point", PackedVector3Array([Vector3(1, 0, 1)]), "")
	var same := PackedVector3Array()
	for _k in range(10):
		same.append(Vector3(1, 0, 1))
	_check(fails, "confondus", same, "")
	_check(fails, "courbe douce", _resample_step(_poly(PackedVector2Array([Vector2(0, 0), Vector2(2, 0.5), Vector2(4, 1.5), Vector2(5, 3)])), step), "")
	# un C (demi-tour, r 2) n'est pas un ensō ; un S (deux arcs opposés) n'est pas un zigzag
	var cc := PackedVector3Array()
	for k in range(41):
		var t6 := deg_to_rad(190.0) * float(k) / 40.0
		cc.append(Vector3(2.0 * cos(t6), 0.0, 2.0 * sin(t6)))
	_check(fails, "C", _resample_step(cc, step), "")
	var ss := PackedVector3Array()
	for k in range(41):
		var t7 := PI * float(k) / 40.0
		ss.append(Vector3(1.5 * cos(PI - t7), 0.0, 1.5 + 1.5 * sin(PI - t7)))
	for k in range(1, 41):
		var t8 := PI * float(k) / 40.0
		ss.append(Vector3(1.5 * cos(PI + t8) + 3.0, 0.0, 1.5 - 1.5 * sin(t8)))
	_check(fails, "S", _resample_step(ss, step), "wave")
	# figures de l'arbre : V aigu aux branches égales, triangle fermé ; pas apprises, elles ne sont pas lues
	var vv := _resample_step(_poly(PackedVector2Array([Vector2(0, 0), Vector2(1.2, 3.0), Vector2(2.4, 0.1)])), step)
	_check(fails, "pointe", vv, "point")
	var tr := _resample_step(_poly(PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(2, 3.4), Vector2(0.1, 0.1)])), step)
	_check(fails, "triangle", tr, "triangle")
	var was: Array = locked
	locked = LEARNED.duplicate()
	_check(fails, "S non appris", _resample_step(ss, step), "")
	_check(fails, "pointe non apprise (aucune figure, pas un crochet)", vv, "")
	locked = was
	# le diagnostic : un cercle trop petit pour un ensō mais pas assez fermé pour une boucle parle du cercle
	var m := near_miss(_resample_step(cc, step))
	if String(m.get("shape", "")) != "enso":
		fails.append("near_miss C : attendu 'enso', obtenu '%s'" % String(m.get("shape", "")))
	return fails
