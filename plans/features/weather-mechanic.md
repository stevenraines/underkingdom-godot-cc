# Feature - Weather Mechanic

**Goal**: Implement a dynamic weather system that varies by season and biome altitude, affects temperature, and displays current conditions to the player.

---

## Overview

Weather adds atmospheric depth and survival challenge to the game. The system generates weather patterns based on:

1. **Season** - Different seasons have different weather probabilities
2. **Biome Altitude** - Higher elevations experience more extreme weather
3. **Day Cycle** - Weather can change at dawn of each new day

Weather directly impacts the temperature system, creating emergent survival gameplay where players must seek shelter during storms or dress appropriately for cold mountain snow.

---

## Core Mechanics

### Weather Types

| Weather | ASCII | Color | Temp Modifier | Description |
|---------|-------|-------|---------------|-------------|
| Clear | `☀` | `#FFD700` | +5°F | Sunny, no clouds |
| Partly Cloudy | `⛅` | `#D3D3D3` | +0°F | Some clouds, mild |
| Cloudy | `☁` | `#A9A9A9` | -3°F | Overcast, no precipitation |
| Fog | `≋` | `#C0C0C0` | -5°F | Reduces visibility |
| Light Rain | `░` | `#87CEEB` | -8°F | Drizzle, minor exposure |
| Rain | `▒` | `#4682B4` | -12°F | Moderate rain |
| Heavy Rain | `▓` | `#2F4F4F` | -18°F | Downpour, significant exposure |
| Thunderstorm | `⚡` | `#FFD700` | -15°F | Rain + lightning danger |
| Light Snow | `·` | `#F0F8FF` | -15°F | Light flurries |
| Snow | `*` | `#FFFFFF` | -22°F | Steady snowfall |
| Blizzard | `❄` | `#E0FFFF` | -30°F | Heavy snow, reduced visibility |
| Hail | `•` | `#B0C4DE` | -10°F | Ice pellets, minor damage risk |
| Sleet | `∵` | `#B0E0E6` | -14°F | Mixed rain and ice |
| Wind | `~` | `#D3D3D3` | -5°F | Strong winds (modifier only) |

### Weather Properties

Each weather type has additional properties beyond temperature:

```json
{
  "id": "heavy_rain",
  "name": "Heavy Rain",
  "ascii_char": "▓",
  "color": "#2F4F4F",
  "temp_modifier": -18,
  "visibility_modifier": -3,
  "stamina_drain_modifier": 1.5,
  "thirst_drain_modifier": 0.5,
  "fire_prevention": true,
  "shelter_required": true,
  "exposure_damage_interval": 100,
  "message_start": "Heavy rain begins to fall.",
  "message_ongoing": "Rain pounds down relentlessly.",
  "ambient_sounds": ["rain_heavy", "thunder_distant"]
}
```

### Property Definitions

| Property | Type | Description |
|----------|------|-------------|
| `temp_modifier` | float | Temperature change in °F |
| `visibility_modifier` | int | Tiles removed from FOV range |
| `stamina_drain_modifier` | float | Multiplier for stamina costs (1.0 = normal) |
| `thirst_drain_modifier` | float | Multiplier for thirst drain (< 1.0 = slower) |
| `fire_prevention` | bool | Prevents outdoor fire lighting |
| `shelter_required` | bool | Player takes exposure damage without shelter |
| `exposure_damage_interval` | int | Turns between damage ticks when exposed |
| `movement_cost_modifier` | float | Extra turn cost for movement (snow, mud) |

---

## Biome Altitude System

Biomes are categorized by altitude tier, which affects weather patterns and base temperature:

### Altitude Tiers

| Tier | Altitude | Temp Modifier | Example Biomes |
|------|----------|---------------|----------------|
| 0 | Sea Level | +5°F | ocean, beach, marsh |
| 1 | Lowland | +0°F | grassland, swamp, woodland |
| 2 | Midland | -5°F | forest, rocky_hills |
| 3 | Highland | -12°F | mountains, tundra |
| 4 | Alpine | -20°F | snow_mountains, snow |

### Biome Data Extension

Add altitude and weather data to biome JSON:

```json
{
  "id": "mountains",
  "name": "Mountains",
  "altitude_tier": 3,
  "base_temp_modifier": -12,
  "weather_modifiers": {
    "snow_chance_bonus": 0.3,
    "rain_to_snow_threshold": 45,
    "wind_chance_bonus": 0.2,
    "fog_chance_bonus": 0.1
  }
}
```

### Altitude Weather Effects

- **Snow Threshold**: Rain converts to snow below a temperature threshold (varies by altitude)
- **Wind Exposure**: Higher altitudes have increased wind chance
- **Fog Formation**: Valleys (low altitude + high moisture) have increased fog
- **Storm Intensity**: Storms are more severe at higher altitudes

---

## Seasonal Weather Patterns

Each season defines probability weights for weather types:

### Spring Weather

```json
{
  "season": "spring",
  "weather_weights": {
    "clear": 20,
    "partly_cloudy": 25,
    "cloudy": 20,
    "fog": 10,
    "light_rain": 15,
    "rain": 7,
    "thunderstorm": 3
  },
  "special_events": ["late_frost", "spring_flood"]
}
```

### Summer Weather

```json
{
  "season": "summer",
  "weather_weights": {
    "clear": 35,
    "partly_cloudy": 30,
    "cloudy": 10,
    "light_rain": 10,
    "rain": 5,
    "heavy_rain": 3,
    "thunderstorm": 7
  },
  "special_events": ["heat_wave", "drought"]
}
```

### Autumn Weather

```json
{
  "season": "autumn",
  "weather_weights": {
    "clear": 15,
    "partly_cloudy": 20,
    "cloudy": 25,
    "fog": 15,
    "light_rain": 12,
    "rain": 8,
    "wind": 5
  },
  "special_events": ["early_frost", "harvest_moon"]
}
```

### Winter Weather

```json
{
  "season": "winter",
  "weather_weights": {
    "clear": 15,
    "partly_cloudy": 10,
    "cloudy": 20,
    "light_snow": 20,
    "snow": 15,
    "blizzard": 5,
    "sleet": 8,
    "wind": 7
  },
  "special_events": ["cold_snap", "thaw"]
}
```

---

## Weather Generation Algorithm

### Daily Weather Roll

Weather is determined once per day at dawn:

```gdscript
func generate_daily_weather(world_seed: int, day: int, season: String, biome_id: String) -> String:
    var rng = RandomNumberGenerator.new()
    rng.seed = world_seed + day * 100

    # Get base seasonal weights
    var weights = get_seasonal_weights(season)

    # Apply biome modifiers
    var biome = BiomeManager.get_biome(biome_id)
    weights = apply_biome_modifiers(weights, biome)

    # Apply altitude-based rain-to-snow conversion
    if should_convert_to_snow(biome, get_current_temp()):
        weights = convert_rain_to_snow(weights)

    # Roll weighted random
    return weighted_random_choice(rng, weights)
```

### Weather Persistence

- Weather typically lasts 1 full day (100 turns)
- Storms may last 2-3 days (persistent flag)
- Weather transitions smoothly via "partly_cloudy" intermediary

### Regional Weather

Different map regions can have different weather:
- Overworld: Uses biome-based weather at player position
- Dungeons: Always "underground" (no weather effects)
- Towns: Same as surrounding biome

---

## Temperature Integration

Weather modifies the temperature calculation in SurvivalSystem:

### Updated Temperature Formula

```
Final Temp = Base Seasonal Temp
           + Month Modifier
           + Time of Day Modifier
           + Daily Variation
           + Biome Altitude Modifier  [NEW]
           + Weather Modifier         [NEW]
           + Interior Bonus
           + Structure Bonus
```

### Example Calculations

**Summer Day in Woodland (Clear)**:
- Base (Summer): 75°F
- Month (Highsun): +10°F
- Time (Day): +0°F
- Altitude (Lowland): +0°F
- Weather (Clear): +5°F
- **Result: 90°F (Hot)**

**Winter Night in Mountains (Snow)**:
- Base (Winter): 35°F
- Month (Deepcold): -15°F
- Time (Night): -14°F
- Altitude (Highland): -12°F
- Weather (Snow): -22°F
- **Result: -28°F (Freezing - Deadly)**

---

## Shelter System Integration

Weather creates need for shelter:

### Shelter Types

| Shelter | Protection Level | Weather Blocked |
|---------|------------------|-----------------|
| None | 0% | None |
| Tree Cover | 25% | Light rain, light snow |
| Lean-to | 50% | Rain, snow, wind |
| Tent | 75% | All except blizzard |
| Building | 100% | All weather |
| Cave/Dungeon | 100% | All weather |

### Exposure Damage

Without adequate shelter during severe weather:
- Damage interval determined by weather type
- Damage amount: 1 HP per tick
- Warning messages: "You are getting soaked!", "The cold is sapping your strength!"

---

## UI Display

### Weather Status in HUD

Display weather alongside temperature in the status area:

```
╔════════════════════════════════╗
║ ☀ Clear  72°F (Comfortable)    ║
║ Day 15 of Bloom, Year 342      ║
╚════════════════════════════════╝
```

### Weather Display Format

```
[Weather Icon] [Weather Name]  [Temp]°F ([Temp State])
```

### Color Coding

| Condition | Color |
|-----------|-------|
| Clear/Sunny | Gold (#FFD700) |
| Cloudy | Gray (#A9A9A9) |
| Rain | Blue (#4682B4) |
| Snow | White (#FFFFFF) |
| Dangerous | Red (#FF4444) |

### Weather Change Messages

Display in message log when weather changes:

```
"The sky clears and the sun emerges."
"Clouds gather overhead."
"Rain begins to fall."
"Snow starts drifting down from the sky."
"A fierce blizzard descends upon you!"
```

---

## Data Structures

### Weather Definition (`data/weather/*.json`)

```json
{
  "id": "thunderstorm",
  "name": "Thunderstorm",
  "ascii_char": "⚡",
  "color": "#FFD700",
  "category": "storm",
  "temp_modifier": -15,
  "visibility_modifier": -4,
  "stamina_drain_modifier": 1.3,
  "thirst_drain_modifier": 0.3,
  "fire_prevention": true,
  "shelter_required": true,
  "exposure_damage_interval": 50,
  "lightning_chance": 0.05,
  "min_duration_days": 1,
  "max_duration_days": 2,
  "transitions_to": ["rain", "cloudy"],
  "messages": {
    "start": "Thunder rumbles as a storm rolls in.",
    "ongoing": "Lightning flashes across the sky.",
    "end": "The storm begins to subside."
  },
  "seasonal_availability": ["spring", "summer", "autumn"]
}
```

### Seasonal Weather Config (`data/weather/seasons/*.json`)

```json
{
  "season": "winter",
  "base_weather_weights": {
    "clear": 15,
    "partly_cloudy": 10,
    "cloudy": 20,
    "fog": 5,
    "light_snow": 20,
    "snow": 15,
    "blizzard": 5,
    "sleet": 8,
    "wind": 2
  },
  "rain_to_snow_temp_threshold": 38,
  "storm_frequency_modifier": 0.8,
  "special_events": {
    "cold_snap": {
      "chance": 0.05,
      "duration_days": 3,
      "temp_modifier": -20,
      "message": "A bitter cold snap settles over the land."
    }
  }
}
```

### Updated Biome Definition

```json
{
  "id": "snow_mountains",
  "name": "Snow Mountains",
  "altitude_tier": 4,
  "base_temp_modifier": -20,
  "weather_modifiers": {
    "snow_chance_bonus": 0.4,
    "blizzard_chance_bonus": 0.15,
    "rain_to_snow_threshold": 50,
    "wind_chance_bonus": 0.25,
    "clear_chance_penalty": 0.2
  },
  "shelter_tiles": ["cave_entrance", "overhang"],
  "base_tile": "floor",
  "grass_char": "▲",
  "tree_density": 0.0,
  "rock_density": 0.4,
  "color_floor": [0.9, 0.95, 1.0],
  "color_grass": [0.85, 0.9, 0.95]
}
```

---

## Implementation Plan

### Phase 1: Data Foundation

1. **Create Weather Definitions**
   - Add `data/weather/` directory
   - Create JSON files for each weather type
   - Define all properties, modifiers, and messages

2. **Create Seasonal Weather Config**
   - Add `data/weather/seasons/` directory
   - Create config for each season's weather probabilities

3. **Update Biome Definitions**
   - Add `altitude_tier` to all biome JSON files
   - Add `base_temp_modifier` based on altitude
   - Add `weather_modifiers` for biome-specific adjustments

### Phase 2: WeatherManager Autoload

1. **Create WeatherManager**
   - Load weather and seasonal data from JSON
   - Track current weather state
   - Generate daily weather on day change

2. **Weather Generation**
   - Implement weighted random selection
   - Apply seasonal and biome modifiers
   - Handle rain-to-snow conversion

3. **Weather State**
   - Track current weather ID
   - Track weather duration remaining
   - Emit signals on weather change

### Phase 3: Temperature Integration

1. **Update SurvivalSystem**
   - Add altitude temperature modifier
   - Add weather temperature modifier
   - Update `update_temperature()` to query WeatherManager

2. **Update CalendarManager**
   - Integrate with WeatherManager for weather changes at dawn

### Phase 4: Exposure System

1. **Create ExposureSystem**
   - Track exposure state
   - Apply damage for unprotected players in severe weather
   - Check shelter status

2. **Shelter Detection**
   - Check if player is indoors (interior tile)
   - Check if player is in dungeon
   - Check nearby shelter structures

### Phase 5: UI Integration

1. **Update Character Sheet**
   - Display current weather with icon
   - Show weather-modified temperature
   - Indicate exposure danger

2. **HUD Weather Display**
   - Add weather icon and name to status bar
   - Color-code based on weather severity

3. **Message Log**
   - Display weather change messages
   - Show exposure warnings

### Phase 6: Save/Load

1. **Update SaveManager**
   - Serialize current weather state
   - Serialize weather duration
   - Restore weather on load

---

## New Files Required

### Data Files

```
data/
└── weather/
    ├── clear.json
    ├── partly_cloudy.json
    ├── cloudy.json
    ├── fog.json
    ├── light_rain.json
    ├── rain.json
    ├── heavy_rain.json
    ├── thunderstorm.json
    ├── light_snow.json
    ├── snow.json
    ├── blizzard.json
    ├── hail.json
    ├── sleet.json
    ├── wind.json
    └── seasons/
        ├── spring.json
        ├── summer.json
        ├── autumn.json
        └── winter.json
```

### Code Files

```
autoload/
└── weather_manager.gd

systems/
└── exposure_system.gd

docs/
├── systems/
│   └── weather-manager.md
└── data/
    └── weather.md
```

### Modified Files

- `data/biomes/*.json` - Add altitude_tier and weather_modifiers
- `autoload/calendar_manager.gd` - Trigger weather generation on day change
- `systems/survival_system.gd` - Include weather in temperature calculation
- `ui/character_sheet.gd` - Display weather status
- `autoload/save_manager.gd` - Save/load weather state

---

## Event Signals

Add to EventBus:

```gdscript
signal weather_changed(old_weather: String, new_weather: String)
signal exposure_warning(message: String, severity: String)
signal exposure_damage(amount: int)
signal special_weather_event(event_id: String)
```

---

## Example Gameplay Scenarios

### Caught in a Blizzard

1. Player is exploring snow mountains in winter
2. Dawn arrives, WeatherManager rolls "blizzard"
3. Message: "A fierce blizzard descends upon you!"
4. Temperature drops by 30°F to -35°F (Freezing)
5. Visibility reduced by 5 tiles
6. Player starts taking exposure damage (1 HP / 30 turns)
7. Player must find shelter (cave, tent, or descend to lower altitude)

### Rainy Spring Day

1. Player is in woodland during spring
2. Weather: Light Rain
3. Temperature drops by 8°F but remains comfortable
4. Thirst drain reduced by 50%
5. Cannot light campfire outdoors
6. No exposure damage (light rain not severe)

### Summer Heat Wave

1. Special event triggers during summer
2. Weather: Clear + Heat Wave modifier
3. Temperature rises to 95°F (Hot)
4. Thirst drain increased
5. Stamina drain increased
6. Message: "The oppressive heat wave continues."

---

## Future Enhancements

1. **Weather Forecasting**: INT-based prediction of next day's weather
2. **Weather-Specific Resources**: Rain barrels, snow collection
3. **Weather Effects on Combat**: Lightning strikes, visibility penalties
4. **Weather-Affected Enemies**: Some creatures only appear in specific weather
5. **Micro-Climates**: Town-specific weather (magical wards, etc.)
6. **Weather Events**: Hurricanes, flash floods, meteor showers
7. **Climate Zones**: Northern regions vs southern regions
8. **Weather-Based Crafting**: Ice blocks in winter, dried herbs in summer

---

## Testing Checklist

- [ ] All weather types load from JSON correctly
- [ ] Seasonal weather probabilities work correctly
- [ ] Biome altitude modifiers apply to temperature
- [ ] Weather changes at dawn
- [ ] Weather affects temperature calculation
- [ ] Exposure damage triggers in severe weather
- [ ] Shelter blocks exposure damage
- [ ] Dungeons have no weather effects
- [ ] Weather icon and name display in UI
- [ ] Weather change messages appear in log
- [ ] Weather state saves and loads correctly
- [ ] Rain converts to snow at appropriate temperatures
- [ ] Different biomes have different weather patterns
- [ ] Special weather events trigger appropriately
