extends RefCounted
class_name Difficulty
## Preset de dificuldade do encontro. Tudo que muda entre Normal/Heroico/
## Impossivel mora aqui — o Boss e os Adds leem estes campos em vez de constantes
## próprias, então balancear é mexer num lugar só.
##
## Campos tipados de propósito (em vez de Dictionary): iterar Dictionary faz `:=`
## inferir de Variant, que é uma das armadilhas de GDScript listadas no CLAUDE.md.

const NORMAL := 0
const HEROICO := 1
const IMPOSSIVEL := 2
const COUNT := 3

var label := "Normal"
var boss_hp := 420.0
var melee_damage := 22.0
var aoe_damage := 28.0
var aoe_cooldown := 3.0
var aoe_telegraph := 1.6
## Adds por onda; uma onda entra a cada mudança de fase (66% e 33% de vida).
var adds_per_wave := 1
var add_hp := 40.0
var add_damage := 8.0
## Segundos até o enrage. Depois disso o dano do boss cresce sem teto — é o
## relógio que impede a luta de se arrastar (pilar "encontros curtos").
var enrage_seconds := 120.0
var rez_charges := 2


static func preset(index: int) -> Difficulty:
	var d := Difficulty.new()
	if index == HEROICO:
		d.label = "Heroico"
		d.boss_hp = 600.0
		d.melee_damage = 28.0
		d.aoe_damage = 36.0
		d.aoe_cooldown = 2.5
		d.aoe_telegraph = 1.3
		d.adds_per_wave = 2
		d.add_hp = 55.0
		d.add_damage = 11.0
		d.enrage_seconds = 100.0
		d.rez_charges = 1
	elif index == IMPOSSIVEL:
		d.label = "Impossivel"
		d.boss_hp = 820.0
		d.melee_damage = 34.0
		d.aoe_damage = 46.0
		d.aoe_cooldown = 2.0
		d.aoe_telegraph = 1.0
		d.adds_per_wave = 3
		d.add_hp = 70.0
		d.add_damage = 14.0
		d.enrage_seconds = 80.0
		d.rez_charges = 1
	return d


static func label_for(index: int) -> String:
	return preset(index).label
