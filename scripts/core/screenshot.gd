class_name Screenshot
## F2: the whole window (the last frame drawn, HUD included) as a PNG
## (Config.SCREENSHOT). The web build downloads it; elsewhere it goes into the
## system's pictures folder if there is one we can write, else into
## user://screenshots.


## Saves `viewport`'s last frame. Returns where it went (an absolute path, or
## the file name of a download), or "" if it failed.
static func take(viewport: Viewport) -> String:
	if DisplayServer.get_name() == "headless":  # (nothing is drawn)
		return ""
	var tex := viewport.get_texture()
	var img: Image = tex.get_image() if tex else null
	if img == null or img.is_empty():
		return ""
	img.convert(Image.FORMAT_RGB8)  # (no alpha: never a see-through picture)
	var file := file_name()
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(img.save_png_to_buffer(), file, "image/png")
		return file
	for dir in dirs():
		var path := _free_path(dir, file)
		if img.save_png(path) == OK:
			return ProjectSettings.globalize_path(path)
	return ""


## <prefix>_YYYY-MM-DD_HH-MM-SS.png, in local time.
static func file_name() -> String:
	var t := Time.get_datetime_dict_from_system()
	return "%s_%04d-%02d-%02d_%02d-%02d-%02d.png" % [Config.SCREENSHOT["prefix"],
		t["year"], t["month"], t["day"], t["hour"], t["minute"], t["second"]]


## Where to try, in order: the pictures folder (only if it already exists: on
## Linux without one the system answers with the home folder), then ours.
static func dirs() -> Array[String]:
	var out: Array[String] = []
	var pics := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if pics != "" and pics != OS.get_environment("HOME") and DirAccess.dir_exists_absolute(pics):
		out.append(pics)
	var own: String = Config.SCREENSHOT["dir"]
	if DirAccess.make_dir_recursive_absolute(own) == OK:
		out.append(own)
	return out


## `file` in `dir`, numbered (_2, _3...) if one by that name is there already.
static func _free_path(dir: String, file: String) -> String:
	var path := dir.path_join(file)
	var n := 2
	while FileAccess.file_exists(path):
		path = dir.path_join("%s_%d.png" % [file.get_basename(), n])
		n += 1
	return path
