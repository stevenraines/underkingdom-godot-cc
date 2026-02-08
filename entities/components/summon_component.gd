class_name SummonComponent
extends RefCounted

## SummonComponent - Manages summoned creatures for the player
##
## Handles adding, removing, commanding, and dismissing summons.
## State variables (active_summons, MAX_SUMMONS) remain on the Player
## for backward compatibility with external callers.

var _owner = null


func _init(owner = null) -> void:
	_owner = owner


## Add a summon to the player's active summons
## Enforces MAX_SUMMONS limit by dismissing the oldest summon
func add_summon(summon) -> bool:
	# Enforce limit - dismiss oldest if at max
	if _owner.active_summons.size() >= _owner.MAX_SUMMONS:
		var oldest = _owner.active_summons[0]
		oldest.dismiss()
		# Note: dismiss() calls remove_summon()

	_owner.active_summons.append(summon)
	EventBus.summon_created.emit(summon, _owner)
	return true


## Remove a summon from the active list
func remove_summon(summon) -> void:
	_owner.active_summons.erase(summon)


## Set behavior mode for a summon by index
func set_summon_behavior(index: int, mode: String) -> void:
	if index >= 0 and index < _owner.active_summons.size():
		_owner.active_summons[index].set_behavior(mode)


## Dismiss a specific summon by index
func dismiss_summon(index: int) -> void:
	if index >= 0 and index < _owner.active_summons.size():
		_owner.active_summons[index].dismiss()


## Dismiss all active summons
func dismiss_all_summons() -> void:
	# Iterate copy since dismiss modifies the array
	for summon in _owner.active_summons.duplicate():
		summon.dismiss()


## Get active summon count
func get_summon_count() -> int:
	return _owner.active_summons.size()
