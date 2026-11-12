class_name Armoury
extends Node
## The town hall's armoury (docs/items-design.md §4): one village's equipment
## items that the hero isn't wearing (Config.ITEMS keys, duplicates allowed),
## at most Config.ARMOURY "cap" together with the village's village-wide and map-wide
## relics (Village.relics, kept here too). Taken-off items go here; nothing is
## lost by swapping. A devastated town hall closes it: no swaps until it is
## repaired; the relics keep working.

signal changed

var village: Village
var items: Array[String] = []
## Slots kept for items bought from other players that are still on the road
## (docs/market-design.md §8.1): they count as taken until the item arrives.
var reserved := 0


func cap() -> int:
	return int(Config.ARMOURY["cap"])


## Items and relics it holds, and the slots reserved for items on the way.
func count() -> int:
	return items.size() + (village.relics.size() if village else 0) + reserved


## A reserved slot is no longer needed (the item arrived or the order was lost).
func release() -> void:
	reserved = maxi(reserved - 1, 0)
	changed.emit()


func full() -> bool:
	return count() >= cap()


func has(id: String) -> bool:
	return items.has(id)


## Swaps need it open: its town hall stands and isn't devastated.
func is_open() -> bool:
	var h := village.town_hall() if village else null
	return is_instance_valid(h) and not h.devastated


## Puts `id` in (false when full, or not an item it can hold: never a
## default or a campaign item, Config.ordinary_item).
func add(id: String) -> bool:
	if full() or not Config.ordinary_item(id):
		return false
	items.append(id)
	changed.emit()
	return true


## Takes one `id` out (false if there is none).
func take(id: String) -> bool:
	var i := items.find(id)
	if i < 0:
		return false
	items.remove_at(i)
	changed.emit()
	return true


## Its items for `slot`, in the order of Config.ITEMS, one entry per copy.
func for_slot(slot: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in Config.ITEMS:
		if str(Config.ITEMS[id]["slot"]) == slot:
			for k in items.count(id):
				out.append(id)
	return out


## Co-op client and loading: the whole list at once.
func set_items(list: Array) -> void:
	items.assign(list)
	changed.emit()
