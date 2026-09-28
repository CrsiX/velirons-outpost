class_name Workplace
extends Building
## A building one villager works at: a farm (farmer), a worker camp (forester).
## Which role works where is set per role in Config.CIVILIANS ("works_at").
## Population assigns workers automatically: a new villager of that role goes
## to a vacant workplace, and a finished workplace takes an idle one.

## The villager working here, or null.
var worker: Node = null


## The civilian role that works here ("farmer" for a farm), or "".
func worker_role() -> String:
	return Config.worker_role(kind)
