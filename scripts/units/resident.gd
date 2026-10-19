class_name Resident
extends Civilian
## A campaign villager who stays in their hut and never goes out ("stays_home"
## in Config.CIVILIANS: what they do there): Wenna the guild master, Anselm the
## priest, Fiona (docs/scenarios-design.md §7.7, §7.10). Safe while the hut
## stands; they die with it. None can be recruited.


func status() -> String:
	return str(Config.CIVILIANS[role].get("stays_home", "at home"))
