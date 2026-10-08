extends Control
## Hôte du dojo (entraînement libre, scripts/dojo.gd), dans l'état « tuto » de main.
## Le tutoriel se fait désormais en jeu, au premier monde (coach.gd).
## main appelle begin_dojo(), on_dash_end(...), on_dodge(), on_ultimate() et is_over_ui() ;
## à la fermeture du dojo, émet dojo_finished.

const Dojo = preload("res://scripts/dojo.gd")

signal dojo_finished

var main: Node
var dojo: Control  # entraînement libre


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	dojo = Dojo.new()
	add_child(dojo)
	dojo.closed.connect(_on_dojo_closed)


## Dojo : héros intouchable, encre infinie, techniques prêtées (réglages posés par main).
func begin_dojo() -> void:
	visible = true
	dojo.main = main
	dojo.begin()


func in_dojo() -> bool:
	return dojo != null and bool(dojo.active)


## Arrêt sans retour à l'accueil (reprise du robot testeur).
func abort_dojo() -> void:
	if in_dojo():
		dojo.stop(false)


func _on_dojo_closed() -> void:
	visible = false
	dojo_finished.emit()


## Ultime lancé (double tap) : seul le dojo le compte.
func on_ultimate() -> void:
	if in_dojo():
		dojo.on_ultimate()


func is_over_ui(p: Vector2) -> bool:
	if not visible or not in_dojo():
		return false
	return dojo.is_over_ui(p)


## Bond d'esquive (tap, ou petit glissé) : main l'appelle au lancement du bond.
func on_dodge() -> void:
	if in_dojo():
		dojo.on_dodge()


## Fin d'une ruée.
func on_dash_end(pos: Vector3, kills: int, shape: String) -> void:
	if in_dojo():
		dojo.on_dash_end(pos, kills, shape)


func _process(_delta: float) -> void:
	if visible:
		size = get_viewport_rect().size
