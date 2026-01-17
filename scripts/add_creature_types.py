#!/usr/bin/env python3
"""
Script to add creature_type field to all enemy JSON files based on folder structure.
Also adds element_subtype for elemental creatures.
"""

import json
import os
from pathlib import Path

# Base path for enemy data
ENEMIES_PATH = Path(__file__).parent.parent / "data" / "enemies"

# Mapping from folder name to creature_type
FOLDER_TO_TYPE = {
    "aberrations": "aberration",
    "animals": "beast",
    "beasts": "beast",
    "constructs": "construct",
    "demons": "demon",
    "elementals": "elemental",
    "humanoids": "humanoid",
    "monstrosities": "monstrosity",
    "oozes": "ooze",
    "undead": "undead",
}

# Special handling for summons folder - map by ID pattern
SUMMON_TYPE_MAPPING = {
    "summoned_skeleton": "undead",
    "summoned_wolf": "beast",
}

# Elemental subtypes based on enemy ID
ELEMENTAL_SUBTYPES = {
    "fire_elemental": "fire",
    "ice_elemental": "ice",
    "air_elemental": "air",
    "earth_elemental": "earth",
    "water_elemental": "water",
}


def process_enemy_file(file_path: Path, folder_name: str) -> bool:
    """
    Process a single enemy JSON file.
    Returns True if the file was modified, False otherwise.
    """
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except (json.JSONDecodeError, IOError) as e:
        print(f"  ERROR reading {file_path}: {e}")
        return False

    modified = False
    enemy_id = data.get("id", "")

    # Determine creature_type
    if folder_name == "summons":
        creature_type = SUMMON_TYPE_MAPPING.get(enemy_id, "humanoid")
    else:
        creature_type = FOLDER_TO_TYPE.get(folder_name, "humanoid")

    # Add or update creature_type if needed
    if data.get("creature_type") != creature_type:
        data["creature_type"] = creature_type
        modified = True
        print(f"  + Set creature_type: {creature_type}")

    # Add element_subtype for elementals
    if creature_type == "elemental" and enemy_id in ELEMENTAL_SUBTYPES:
        element_subtype = ELEMENTAL_SUBTYPES[enemy_id]
        if data.get("element_subtype") != element_subtype:
            data["element_subtype"] = element_subtype
            modified = True
            print(f"  + Set element_subtype: {element_subtype}")

    # Write back if modified
    if modified:
        # Reorder keys to put creature_type and element_subtype after ascii_color
        ordered_data = reorder_keys(data)
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(ordered_data, f, indent=2)
            f.write('\n')  # Add trailing newline

    return modified


def reorder_keys(data: dict) -> dict:
    """
    Reorder dictionary keys to place creature_type and element_subtype
    in a logical position (after ascii_color, before stats).
    """
    # Define the preferred key order
    preferred_order = [
        "id",
        "name",
        "description",
        "cr",
        "ascii_char",
        "ascii_color",
        "creature_type",
        "element_subtype",
        "stats",
        "attributes",
        "base_health",
        "base_damage",
        "armor",
        "elemental_resistances",
        "yields",
        "behavior",
        "faction",
        "loot_table",
        "xp_value",
        "spawn_biomes",
        "spawn_dungeons",
        "spawn_density_overworld",
        "spawn_density_dungeon",
        "min_spawn_level",
        "max_spawn_level",
        "feared_components",
        "fear_distance",
        "summon_only",
        "abilities",
        "spellcaster",
    ]

    # Build ordered dictionary
    ordered = {}
    for key in preferred_order:
        if key in data:
            ordered[key] = data[key]

    # Add any remaining keys not in preferred order
    for key in data:
        if key not in ordered:
            ordered[key] = data[key]

    return ordered


def main():
    print(f"Processing enemy files in: {ENEMIES_PATH}")
    print("-" * 60)

    total_files = 0
    modified_files = 0

    # Process each folder
    for folder in sorted(ENEMIES_PATH.iterdir()):
        if not folder.is_dir():
            continue

        folder_name = folder.name
        print(f"\nFolder: {folder_name}")

        # Process each JSON file in the folder
        for json_file in sorted(folder.glob("*.json")):
            total_files += 1
            print(f"  Processing: {json_file.name}")

            if process_enemy_file(json_file, folder_name):
                modified_files += 1

    print("\n" + "-" * 60)
    print(f"Total files processed: {total_files}")
    print(f"Files modified: {modified_files}")


if __name__ == "__main__":
    main()
