class_name LockSystem
extends RefCounted

## LockSystem - Handles lock/unlock mechanics for doors and containers
##
## Provides static methods for checking keys, picking locks, and lock operations.
## Lock levels range from 1 (simple) to 10 (master).

const Inventory = preload("res://systems/inventory_system.gd")

## Result codes for lock operations
enum LockResult {
	SUCCESS,
	LOCKED,
	NO_KEY,
	PICK_SUCCESS,
	PICK_FAILED,
	ALREADY_UNLOCKED,
	ALREADY_LOCKED,
	NO_LOCKPICK,
	INVALID_TARGET
}

## Attempt to unlock using available keys in inventory
## Returns Dictionary with result info: {success, result, message, key_used}
static func try_unlock_with_key(lock_id: String, lock_level: int, inventory) -> Dictionary:
	var result = {
		"success": false,
		"result": LockResult.NO_KEY,
		"message": "",
		"key_used": null
	}

	if not inventory or not inventory.items:
		result.message = "You don't have any keys."
		return result

	# First check for specific key matching this lock
	for item in inventory.items:
		if item.is_key() and not item.is_skeleton_key():
			if item.key_id == lock_id:
				result.success = true
				result.result = LockResult.SUCCESS
				result.key_used = item
				result.message = "You unlock it with the %s." % item.name
				return result

	# Then check for skeleton key with sufficient level
	for item in inventory.items:
		if item.is_skeleton_key():
			if item.skeleton_key_level >= lock_level:
				result.success = true
				result.result = LockResult.SUCCESS
				result.key_used = item
				result.message = "Your %s clicks the lock open." % item.name
				return result

	result.message = "You don't have the right key."
	return result

## Attempt to pick a lock
## Returns Dictionary with result info: {success, result, message, lockpick_broken}
static func try_pick_lock(lock_level: int, player) -> Dictionary:
	var result = {
		"success": false,
		"result": LockResult.NO_LOCKPICK,
		"message": "",
		"lockpick_broken": false
	}

	# Find lockpick in inventory
	var lockpick = _find_lockpick(player.inventory)

	if not lockpick:
		result.message = "You need lockpicks to pick this lock."
		return result

	# D&D-style skill check: d20 + DEX modifier + skill vs DC (lock_level * 2 + 10)
	var dex = player.get_effective_attribute("DEX")
	var dex_modifier: int = int((dex - 10) / 2.0)  # D&D-style modifier
	var lockpicking_skill = player.skills.get("lockpicking", 0) if "skills" in player else 0
	var dc: int = lock_level * 2 + 10  # DC scales with lock level

	# Roll d20 + modifiers
	var dice_roll: int = randi_range(1, 20)
	var total_roll: int = dice_roll + dex_modifier + lockpicking_skill

	if total_roll >= dc:
		result.success = true
		result.result = LockResult.PICK_SUCCESS
		result.message = "You successfully pick the lock. (rolled %d)" % dice_roll
	else:
		result.success = false
		result.result = LockResult.PICK_FAILED
		result.lockpick_broken = true
		result.message = "The lockpick breaks! (rolled %d)" % dice_roll

		# Consume lockpick
		_consume_lockpick(lockpick, player.inventory)

	return result

## Attempt to lock an open lock using lockpicks (half difficulty)
## Returns Dictionary with result info: {success, result, message, lockpick_broken}
static func try_lock_with_pick(lock_level: int, player) -> Dictionary:
	var result = {
		"success": false,
		"result": LockResult.NO_LOCKPICK,
		"message": "",
		"lockpick_broken": false
	}

	# Find lockpick in inventory
	var lockpick = _find_lockpick(player.inventory)

	if not lockpick:
		result.message = "You need lockpicks to re-lock this."
		return result

	# D&D-style skill check (easier - DC is halved for re-locking)
	@warning_ignore("integer_division")
	var dex = player.get_effective_attribute("DEX")
	var dex_modifier: int = int((dex - 10) / 2.0)  # D&D-style modifier
	var lockpicking_skill = player.skills.get("lockpicking", 0) if "skills" in player else 0
	var dc: int = lock_level + 5  # Re-locking is easier (half the picking DC)

	# Roll d20 + modifiers
	var dice_roll: int = randi_range(1, 20)
	var total_roll: int = dice_roll + dex_modifier + lockpicking_skill

	if total_roll >= dc:
		result.success = true
		result.result = LockResult.SUCCESS
		result.message = "You re-lock the mechanism. (rolled %d)" % dice_roll
	else:
		result.success = false
		result.result = LockResult.PICK_FAILED
		result.lockpick_broken = true
		result.message = "The lockpick breaks! (rolled %d)" % dice_roll

		# Consume lockpick
		_consume_lockpick(lockpick, player.inventory)

	return result

## Check if player has any means to unlock a lock
## Returns Dictionary: {has_key, has_skeleton_key, has_lockpick}
static func can_attempt_unlock(lock_id: String, lock_level: int, inventory) -> Dictionary:
	var result = {
		"has_key": false,
		"has_skeleton_key": false,
		"has_lockpick": false
	}

	if not inventory or not inventory.items:
		return result

	for item in inventory.items:
		if item.is_key() and not item.is_skeleton_key():
			if item.key_id == lock_id:
				result.has_key = true
		elif item.is_skeleton_key():
			if item.skeleton_key_level >= lock_level:
				result.has_skeleton_key = true
		elif item.is_lockpick():
			result.has_lockpick = true

	return result

## Find a lockpick in the inventory
static func _find_lockpick(inventory) -> Variant:
	if not inventory or not inventory.items:
		return null

	for item in inventory.items:
		if item.is_lockpick():
			return item

	return null

## Consume one lockpick from the stack
static func _consume_lockpick(lockpick, inventory) -> void:
	if not lockpick or not inventory:
		return

	lockpick.remove_from_stack(1)
	if lockpick.is_empty():
		inventory.remove_item(lockpick)
