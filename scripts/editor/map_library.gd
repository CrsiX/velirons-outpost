class_name MapLibrary
extends RefCounted
## Map files (docs/map-editor-design.md §7): your maps in
## Config.EDITOR["library_dir"] (user://maps), the built-in ones in
## Config.EDITOR["builtin_dir"] (read-only), and import / export of a file
## anywhere: a file dialog on desktop and Android, the browser's file picker
## and a download on the web.

## The browser's file picker calls back through this (kept alive here).
static var _web_callback: JavaScriptObject = null


static func user_dir() -> String:
	return str(Config.EDITOR["library_dir"])


static func builtin_dir() -> String:
	return str(Config.EDITOR["builtin_dir"])


## Every map file: [{"path", "name", "size", "villages", "map_type",
## "builtin", "modified"}], yours first (newest first), then the built-in
## ones by name. A file that isn't a map at all is listed with "error".
static func list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for builtin in [false, true]:
		var dir := builtin_dir() if builtin else user_dir()
		var found: Array[Dictionary] = []
		for f in _json_files(dir):
			found.append(summary(dir.path_join(f), builtin))
		if builtin:
			found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["name"]).naturalnocasecmp_to(b["name"]) < 0)
		else:
			found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["modified"]) > int(b["modified"]))
		out.append_array(found)
	return out


static func _json_files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f in DirAccess.get_files_at(dir):
		if f.get_extension().to_lower() == "json":
			out.append(f)
	return out


## What the map list shows about a file, without checking it all.
static func summary(path: String, builtin: bool = false) -> Dictionary:
	var e := {"path": path, "name": path.get_file().get_basename(), "size": 0, "villages": 0, "map_type": "", "builtin": builtin,
		"modified": FileAccess.get_modified_time(path) if FileAccess.file_exists(path) else 0, "error": ""}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path).trim_prefix("﻿"))
	if not (d is Dictionary) or d.get("format") != MapJson.FORMAT:
		e["error"] = "not a map file"
		return e
	e["name"] = str(d.get("name", e["name"]))
	e["size"] = int(d.get("size", 0)) if (d.get("size") is float or d.get("size") is int) else 0
	e["villages"] = (d.get("villages", []) as Array).size() if d.get("villages") is Array else 0
	e["map_type"] = str(d.get("map_type", ""))
	return e


## Reads and checks a map file: {"map": MapData or null, "errors": [...]}.
static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"map": null, "errors": ["%s: no such file" % path]}
	return MapJson.read(FileAccess.get_file_as_string(path))


## Writes `m` as JSON to `path` (made under your maps if empty: from its
## name). Returns the path, or "" when it couldn't be written.
static func save(m: MapData, path: String = "") -> String:
	if path == "":
		path = free_path(MapJson.map_name(m))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(MapJson.write(m))
	f.close()
	return path


## A file name under your maps for a map called `name` that isn't taken.
static func free_path(name: String) -> String:
	var slug := ""
	for ch in name.to_lower():
		slug += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") else "-"
	while "--" in slug:
		slug = slug.replace("--", "-")
	slug = slug.strip_edges().trim_prefix("-").trim_suffix("-")
	if slug == "":
		slug = "map"
	var path := user_dir().path_join(slug + ".json")
	var k := 2
	while FileAccess.file_exists(path):
		path = user_dir().path_join("%s-%d.json" % [slug, k])
		k += 1
	return path


static func is_builtin(path: String) -> bool:
	return path.begins_with(builtin_dir())


static func delete(path: String) -> bool:
	return not is_builtin(path) and DirAccess.remove_absolute(path) == OK


# --- files anywhere (import / export) ------------------------------------------------------

## Exports `m` as a file the person chooses: a download on the web, a save
## dialog elsewhere (`host` holds the dialog). `done` gets the path or "".
static func export_map(m: MapData, host: Node, done: Callable) -> void:
	var text := MapJson.write(m)
	var file_name := free_path(MapJson.map_name(m)).get_file()
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(), file_name, "application/json")
		done.call(file_name)
		return
	var dlg := _dialog(host, FileDialog.FILE_MODE_SAVE_FILE)
	dlg.current_file = file_name
	dlg.file_selected.connect(func(p: String) -> void:
		var f := FileAccess.open(p, FileAccess.WRITE)
		if f:
			f.store_string(text)
			f.close()
		done.call(p if f else "")
		dlg.queue_free())
	dlg.canceled.connect(func() -> void:
		done.call("")
		dlg.queue_free())
	dlg.popup_centered_ratio(0.7)


## Lets the person pick a map file anywhere: `done` gets (file name, text),
## or ("", "") if cancelled.
static func import_text(host: Node, done: Callable) -> void:
	if OS.has_feature("web"):
		_web_callback = JavaScriptBridge.create_callback(func(args: Array) -> void:
			done.call(str(args[0]), str(args[1])))
		var window := JavaScriptBridge.get_interface("window")
		window.veliron_map_picked = _web_callback
		JavaScriptBridge.eval("""(function () {
			var input = document.createElement('input');
			input.type = 'file';
			input.accept = '.json,application/json';
			input.onchange = function () {
				var f = input.files[0];
				if (!f) { return; }
				var r = new FileReader();
				r.onload = function () { window.veliron_map_picked(f.name, r.result); };
				r.readAsText(f);
			};
			input.click();
		})();""", true)
		return
	var dlg := _dialog(host, FileDialog.FILE_MODE_OPEN_FILE)
	dlg.file_selected.connect(func(p: String) -> void:
		done.call(p.get_file(), FileAccess.get_file_as_string(p))
		dlg.queue_free())
	dlg.canceled.connect(func() -> void:
		done.call("", "")
		dlg.queue_free())
	dlg.popup_centered_ratio(0.7)


static func _dialog(host: Node, mode: FileDialog.FileMode) -> FileDialog:
	var dlg := FileDialog.new()
	dlg.file_mode = mode
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.filters = PackedStringArray(["*.json ; Map files"])
	dlg.use_native_dialog = true
	dlg.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(dlg)
	return dlg
