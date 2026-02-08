class_name ConcentrationComponent
extends RefCounted

## ConcentrationComponent - Manages concentration spell mechanics
##
## Handles starting, ending, and checking concentration on maintained spells.
## State variable (concentration_spell) remains on the Player
## for backward compatibility with external callers.

var _owner = null


func _init(owner = null) -> void:
	_owner = owner


## Start concentrating on a spell
## Ends any previous concentration spell
func start_concentration(spell_id: String) -> void:
	# End previous concentration if any
	if _owner.concentration_spell != "":
		end_concentration()

	_owner.concentration_spell = spell_id
	EventBus.concentration_started.emit(_owner, spell_id)


## End concentration, removing the maintained effect
func end_concentration() -> void:
	if _owner.concentration_spell != "":
		# Remove the concentration effect from active effects
		_owner.remove_magical_effect(_owner.concentration_spell + "_effect")
		EventBus.concentration_ended.emit(_owner, _owner.concentration_spell)
		_owner.concentration_spell = ""


## Check if concentration is maintained after taking damage
## Concentration check: d20 + CON modifier vs DC 10 + damage/2 (minimum DC 10)
## Returns true if concentration maintained, false if broken
func check_concentration(damage_taken: int) -> bool:
	if _owner.concentration_spell == "":
		return true  # No concentration to break

	# Roll d20 + CON modifier
	var roll = randi_range(1, 20)
	var con_mod = (_owner.get_effective_attribute("CON") - 10) / 2
	var total = roll + con_mod

	# DC is 10 or half the damage, whichever is higher
	var dc = max(10, 10 + (damage_taken / 2))

	var success = total >= dc
	EventBus.concentration_check.emit(_owner, damage_taken, success)

	if not success:
		var spell_name = _owner.concentration_spell.replace("_", " ").capitalize()
		EventBus.message_logged.emit("Your concentration on %s is broken!" % spell_name, Color.RED)
		end_concentration()
		return false

	return true
