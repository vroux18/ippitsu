extends RefCounted
## Score d'une partie, propre au monde joué : chaque yokai abattu rapporte des points (moitié sans figure), multipliés par la chaîne
## (ruées réussies d'affilée sans prendre de coup, main.chain) ; primes pour les figures qui tuent, les traits
## qui fauchent plusieurs ennemis, les combats nets ou rapides et les boss.
## Fin de partie : record du monde (meta), rang (梅 竹 松 極) et un peu d'encre selon le score.

const UiKit = preload("res://scripts/ui_kit.gd")

const KILL_PTS := 50  # + 50 par point d'expérience du yokai : oni 100, kappa 150, brute 200…
const ELITE_PTS := 300  # défi d'un recoin
const FIGURE_PTS := 50  # par yokai tué par une figure (pendant la ruée ou sa technique)
const PLAIN_KILL := 0.5  # yokai tué SANS figure (trait simple, pouvoir) : moitié des points de base ; les rangs se gagnent aux figures
const MULTI_PTS := 150  # par yokai au-delà du premier, fauchés d'un même trait
const CLEAN_PTS := 500  # combat sans un coup reçu
const FAST_PTS := 400  # combat bouclé avant le temps de référence
const MINI_PTS := 2000
const BOSS_PTS := 5000
const BOSS_CLEAN_PTS := 2000
const FIG_WINDOW := 1.2  # secondes (temps de jeu) où les morts comptent pour la figure qui vient de finir
const SUMI_PER := 1000  # 1 encre tous les 1000 points (prime modeste, pour donner envie de rejouer)
const SUMI_MAX := 60
# multiplicateur selon la chaîne : [chaîne minimale, multiplicateur] (paliers de main.CHAIN_TIERS)
const MULTS := [[20, 4.0], [10, 3.0], [5, 2.0], [3, 1.5]]
# rangs : seuils de base (monde 1), un peu relevés à chaque monde
const RANK_PTS := [8000, 22000, 40000, 65000]
const RANK_KANJI := ["梅", "竹", "松", "極"]
const RANK_LETTER := ["C", "B", "A", "S"]
const RANK_NAMES := ["PRUNIER", "BAMBOU", "PIN", "MAÎTRE"]
const RANK_COLORS := [Color("#B5838D"), Color("#5E8C4A"), Color("#2F6B5E"), Color("#C9302C")]

var hud: Control  # pour les petites annonces de points (hud.score_pop)
var points := 0
var best_mult := 1.0
var bonus_mult := 1.0  # Tambour des morts (pacte du sanctuaire) : tous les gains de points ×1,4 (main._take_curse)
var fig_t := 0.0  # fenêtre de la dernière figure
var room_t := 0.0  # durée du combat en cours
var room_hurt := false
var room_n := 0


func reset() -> void:
	points = 0
	best_mult = 1.0
	bonus_mult = 1.0
	fig_t = 0.0
	room_t = 0.0
	room_hurt = false
	room_n = 0


static func mult(chain: int) -> float:
	for m in MULTS:
		if chain >= int(m[0]):
			return float(m[1])
	return 1.0


## « ×1,5 » à la française (virgule), « ×2 » sans décimale.
static func mult_text(m: float) -> String:
	if is_equal_approx(m, roundf(m)):
		return "×%d" % int(roundf(m))
	return ("×%.1f" % m).replace(".", ",")


## Nombre avec une espace entre les milliers : 12 400.
static func fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## Rang d'un score dans un monde : 0 (aucun), puis 1..4 (梅, 竹, 松, 極).
## `won` : le boss du monde a été vaincu ; sans cela, le rang plafonne à 松 (pin) : 極 (maître) se gagne en finissant le monde.
static func rank_of(pts: int, world_id: int, won := true) -> int:
	var k := 1.0 + 0.12 * float(maxi(0, world_id - 1))
	var r := 0
	for i in RANK_PTS.size():
		if float(pts) >= float(RANK_PTS[i]) * k:
			r = i + 1
	if not won:
		r = mini(r, RANK_PTS.size() - 1)
	return r


## Points qu'il faut pour le rang suivant (0 : rang maximal, ou -1 : les points y sont mais il faut vaincre le boss).
static func next_rank_pts(pts: int, world_id: int, won := true) -> int:
	var r := rank_of(pts, world_id, won)
	if r >= RANK_PTS.size():
		return 0
	if not won and r == RANK_PTS.size() - 1 and rank_of(pts, world_id, true) >= RANK_PTS.size():
		return -1
	var k := 1.0 + 0.12 * float(maxi(0, world_id - 1))
	return int(ceil(float(RANK_PTS[r]) * k))


## Caractère du rang : son kanji si la police l'a (polices réduites), sinon la lettre.
static func rank_glyph(r: int) -> String:
	if r <= 0:
		return ""
	var i := clampi(r - 1, 0, RANK_KANJI.size() - 1)
	var kj := String(RANK_KANJI[i])
	if UiKit.TITLE_FONT.has_char(kj.unicode_at(0)):
		return kj
	return String(RANK_LETTER[i])


static func rank_name(r: int) -> String:
	if r <= 0:
		return ""
	return String(RANK_NAMES[clampi(r - 1, 0, RANK_NAMES.size() - 1)])


static func rank_color(r: int) -> Color:
	if r <= 0:
		return Color(0.5, 0.5, 0.5)
	var c: Color = RANK_COLORS[clampi(r - 1, 0, RANK_COLORS.size() - 1)]
	return c


# --- Pendant la partie (appelé par main) --------------------------------------

func update(dt: float) -> void:
	fig_t = maxf(0.0, fig_t - dt)
	room_t += dt


func _gain(base: int, chain: int, label: String) -> int:
	var m := mult(chain)
	best_mult = maxf(best_mult, m)
	var g := int(roundf(float(base) * m * bonus_mult / 10.0)) * 10
	points += g
	if hud != null and label != "":
		hud.score_pop(label, g)
	return g


## Yokai abattu : xp = son expérience (main.KIND_XP), figure = tué par une figure.
func on_kill(xp: int, elite: bool, figure: bool, chain: int) -> void:
	var base := KILL_PTS + KILL_PTS * maxi(1, xp)
	if not figure:
		base = int(roundf(float(base) * PLAIN_KILL))
	_gain(base, chain, "")
	if figure:
		_gain(FIGURE_PTS, chain, "FIGURE")
	if elite:
		_gain(ELITE_PTS, chain, "DÉFI")


## Une figure vient de finir : ses techniques ont un court moment pour tuer.
func figure_used() -> void:
	fig_t = FIG_WINDOW


## Fin d'un trait : prime si plusieurs yokai sont tombés d'un coup.
func on_stroke(kills: int, chain: int) -> void:
	if kills < 2:
		return
	var label := "DOUBLE" if kills == 2 else ("TRIPLE" if kills == 3 else "MULTI ×%d" % kills)
	_gain(MULTI_PTS * (kills - 1), chain, label)


func on_hurt() -> void:
	room_hurt = true


func on_room_start() -> void:
	room_t = 0.0
	room_hurt = false
	room_n += 1


## Combat nettoyé : primes de netteté et de vitesse (non multipliées : la chaîne a pu s'éteindre).
func on_room_clear(room: int) -> void:
	if room_n <= 0:
		return
	if not room_hurt:
		_gain(CLEAN_PTS, 0, "SANS DÉGÂT")
	var par := 18.0 + 2.0 * float(room)  # secondes : les combats grossissent avec les salles
	if room_t < par:
		_gain(FAST_PTS, 0, "ÉCLAIR")


func on_boss(mini: bool, clean: bool, chain: int) -> void:
	_gain(MINI_PTS if mini else BOSS_PTS, chain, "GARDIEN" if mini else "BOSS")
	if clean:
		_gain(BOSS_CLEAN_PTS, 0, "INTACT")


# --- Fin de partie -----------------------------------------------------------

## Enregistre le score du monde (meta) et crédite l'encre de la prime.
## Renvoie {"score", "best", "record", "rank", "best_rank", "sumi", "mult"}.
func finish(meta: RefCounted, world_id: int, max_chain: int, won := false) -> Dictionary:
	var old_best: int = meta.world_score_of(world_id)
	var rec: bool = meta.record_score(world_id, points, max_chain)
	var bonus := mini(SUMI_MAX, int(points / float(SUMI_PER)))
	if bonus > 0:
		meta.sumi = int(meta.sumi) + bonus
		meta.save_data()
	var best := maxi(old_best, points)
	# le monde est « vaincu » dès qu'il l'a été une fois (meta.won_top : unlocked plafonne au dernier monde)
	var cleared: bool = won or bool(meta.world_cleared(world_id))
	return {"score": points, "best": best, "record": rec and points > 0, "rank": rank_of(points, world_id, won),
		"best_rank": rank_of(best, world_id, cleared), "sumi": bonus, "mult": best_mult}
