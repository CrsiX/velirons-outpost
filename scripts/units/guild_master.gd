class_name GuildMaster
extends Civilian
## The guild master (Wenna, scenario 4; docs/scenarios-design.md §7.7): lives
## in her hut, the guild house, and keeps the guild's books there. She never
## goes out, so she is safe while her house stands; she dies with it.


func status() -> String:
	return "keeping the guild's books"
