extends RefCounted
## Progression permanente : monnaies (sumi, sceaux, Vues) et Pierre à encre, sauvegardées entre les parties.

const SAVE_PATH := "user://ippitsu_meta.cfg"
const MAX_PRINTS := 24
const SUMI_PER_ROOM := 0  # réglage d'équilibrage : bonus d'encre par salle franchie (0 = §5.1 strict)

## Ordre d'affichage des lignes de la Pierre à encre.
const ORDER := ["brush", "ink", "paper", "breath", "purse", "choice"]

## Données des lignes : nom affiché, idéogramme, coûts (un par rang), texte d'effet (valeur = base + step × rang).
const LINES := {
	"brush": {"name": "Pinceau long", "kanji": "筆", "costs": [40, 80, 140, 220, 320],
		"fmt": "Élan max +%d m", "base": 0, "step": 1},
	"ink": {"name": "Encre vive", "kanji": "墨", "costs": [40, 80, 140, 220, 320],
		"fmt": "Recharge +%d %%", "base": 0, "step": 6},
	"paper": {"name": "Peau de papier", "kanji": "士", "costs": [100, 200, 350],
		"fmt": "PV max +%d", "base": 0, "step": 1},
	"breath": {"name": "Second souffle", "kanji": "風", "costs": [250, 500],
		"fmt": "%d filets par salle", "base": 1, "step": 1},
	"purse": {"name": "Bourse", "kanji": "円", "costs": [30, 60, 100, 150, 210],
		"fmt": "Encre gagnée +%d %%", "base": 0, "step": 5},
	"choice": {"name": "Choix", "kanji": "道", "costs": [120, 240, 400],
		"fmt": "Relances +%d par partie", "base": 0, "step": 1},
}

var sumi := 0  # encre, permanente
var seals := 0  # sceaux (hanko)
var prints := 0  # Vues collectionnées (max 24)
var runs := 0  # parties jouées
var best_room := 0  # meilleure salle atteinte
var wins := 0  # victoires (la première rapporte +2 sceaux)
var ranks := {}  # id de ligne -> rang acheté


func _init() -> void:
	for id in ORDER:
		ranks[id] = 0


# --- Sauvegarde -------------------------------------------------------------

func load_data() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	sumi = maxi(0, int(cf.get_value("meta", "sumi", 0)))
	seals = maxi(0, int(cf.get_value("meta", "seals", 0)))
	prints = clampi(int(cf.get_value("meta", "prints", 0)), 0, MAX_PRINTS)
	runs = maxi(0, int(cf.get_value("meta", "runs", 0)))
	best_room = maxi(0, int(cf.get_value("meta", "best_room", 0)))
	wins = maxi(0, int(cf.get_value("meta", "wins", 0)))
	for id in ORDER:
		ranks[id] = clampi(int(cf.get_value("stone", id, 0)), 0, max_rank(id))


func save_data() -> void:
	var cf := ConfigFile.new()
	cf.set_value("meta", "sumi", sumi)
	cf.set_value("meta", "seals", seals)
	cf.set_value("meta", "prints", prints)
	cf.set_value("meta", "runs", runs)
	cf.set_value("meta", "best_room", best_room)
	cf.set_value("meta", "wins", wins)
	for id in ORDER:
		cf.set_value("stone", id, rank(id))
	cf.save(SAVE_PATH)


# --- Pierre à encre ---------------------------------------------------------

func rank(id: String) -> int:
	return int(ranks.get(id, 0))


func max_rank(id: String) -> int:
	if not LINES.has(id):
		return 0
	var line: Dictionary = LINES[id]
	var costs: Array = line["costs"]
	return costs.size()


## Prix du prochain rang, -1 si la ligne est au maximum (ou inconnue).
func cost(id: String) -> int:
	var r := rank(id)
	if r >= max_rank(id):
		return -1
	var line: Dictionary = LINES[id]
	var costs: Array = line["costs"]
	return int(costs[r])


func can_buy(id: String) -> bool:
	var c := cost(id)
	return c >= 0 and sumi >= c


## Débite l'encre, monte le rang et sauvegarde.
func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	sumi -= cost(id)
	ranks[id] = rank(id) + 1
	save_data()
	return true


## Texte d'effet total au rang donné (par défaut : le prochain rang, ou le rang max atteint).
func effect_text(id: String, at_rank := -1) -> String:
	if not LINES.has(id):
		return ""
	var line: Dictionary = LINES[id]
	var r := at_rank
	if r < 0:
		r = mini(rank(id) + 1, max_rank(id))
	var v := int(line["base"]) + int(line["step"]) * r
	return String(line["fmt"]) % v


# --- Effets appliqués à une partie -------------------------------------------

## Mètres d'élan max en plus.
func elan_bonus() -> float:
	return float(rank("brush"))


## Multiplicateur de recharge de l'élan.
func regen_mult() -> float:
	return 1.0 + 0.06 * rank("ink")


## PV max en plus.
func hp_bonus() -> int:
	return rank("paper")


## Filets de sécurité par salle (1 de base).
func safety_per_room() -> int:
	return 1 + rank("breath")


## Relances de rouleaux par partie.
func rerolls() -> int:
	return rank("choice")


## Multiplicateur de l'encre gagnée en fin de partie.
func sumi_mult() -> float:
	return 1.0 + 0.05 * rank("purse")


# --- Fin de partie ----------------------------------------------------------

## Calcule et crédite les gains d'une partie (§5.1), sauvegarde, renvoie {"sumi", "seals", "print"}.
func award_run(rooms_cleared: int, kills: int, boss_kills: int, curses: int, victory: bool, mini_boss_kills := 0) -> Dictionary:
	var base := float(floori(maxi(0, kills) / 5.0) + 10 * mini_boss_kills + 30 * boss_kills + SUMI_PER_ROOM * rooms_cleared)
	base *= 1.0 + 0.15 * maxi(0, curses)
	var gained := maxi(0, int(round(base * sumi_mult())))
	var new_seals := maxi(0, boss_kills)
	if victory:
		if wins == 0:
			new_seals += 2
		wins += 1
	var got_print := false
	if prints < MAX_PRINTS:
		prints += 1
		got_print = true
	sumi += gained
	seals += new_seals
	runs += 1
	best_room = maxi(best_room, rooms_cleared)
	save_data()
	return {"sumi": gained, "seals": new_seals, "print": got_print}
