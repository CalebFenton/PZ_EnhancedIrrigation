"""The inventory icons, the counterpart of tiles.py for the items."""
from lines import lawn_sprinkler
from pamphlet import pamphlet
from pumps import appliance_pump, utility_pump
from treatment import crock_icon
from valves import sprinkler_timer, timer_valve, water_valve, wind_up_valve

# Inventory icons by item name (Item_EnhancedIrrigation_<name>), each drawn from `model` at
# `icon_elevation` degrees above the horizon, turned `icon_turn` degrees about the vertical: the
# leaflet's head turned away from the viewer, so it stands upright in the icon and fills it.
ITEMS = {
    "CisternsForKentucky": {"model": pamphlet, "icon_elevation": 65, "icon_turn": 45},
    "FilterCrock": {"model": crock_icon},
    "FilterCrockUnfired": {"model": lambda col: crock_icon(col, fired=False)},
    "AppliancePump": {"model": appliance_pump, "icon_elevation": 35, "icon_turn": 45},
    "UtilityPump": {"model": utility_pump, "icon_turn": 45},
    "LawnSprinkler": {"model": lawn_sprinkler},
    "WaterValve": {"model": water_valve},
    "WindUpValve": {"model": wind_up_valve},
    "TimerValve": {"model": timer_valve},
    "SprinklerTimer": {"model": sprinkler_timer},
}
