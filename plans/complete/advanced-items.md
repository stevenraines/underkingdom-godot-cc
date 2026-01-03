# Feature - Advanced Items
**Goal**: Items extended so different items may be composed from a single definition.

---
 Currently, the item definitions contain a separate definition for flint_knife, and iron_knife. Most of the properties are the same. Create a system that allows the definition of "knife" and then possible variants. The ultimate goal is for the data structure to be able to create an item factory, that can dynamically generate items for the world by taking a generic and applying variants.

The items are already grouped into categories and sub-types, so variants should be able to be layered on to subtypes with modifiers for any abilities.

For instance, both the flint_knife and iron_knife are category tool and sub-type knife. So there would be a generic definition for knife with base properties, then variants for iron and flint that modify the base configuration.

Variants should be available at the category level, the overridden by any variants at the sub-type level. And example sub-type variant might be "knife material", where the variants are "flint" and "iron", with flint reducing the standard durability down and iron increasing durability and value.

From the player's point of view, these should each be distinct items. 

Ideally, the description would be generated based on type, category, sub-type and variants, in the standard english order for adjectives:

opinion (unusual, lovely, beautiful)
size (large, small, tiny)
physical quality (thin, rough, knicked)
shape (straight, narraow, curved)
age (new, old, ancient)
color (blue, red, pink)
origin (Dwarven, Elven, Abyssyl)
material (metal, wood, crystal)





