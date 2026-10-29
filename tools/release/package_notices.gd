extends SceneTree
## Places the license/notice files from notices_manifest.json beside an exported
## executable, or checks that they are there and byte-identical.
##   godot4 --headless --path <project> -s res://tools/release/package_notices.gd -- --sources
##   godot4 --headless --path <project> -s res://tools/release/package_notices.gd -- --copy <export dir>
##   godot4 --headless --path <project> -s res://tools/release/package_notices.gd -- --check <export dir>
## Optional `--manifest=<path>` replaces the default manifest (used by the proof driver).
## Run --copy then --check for BOTH builds/release/linux and builds/release/windows
## after `--export-release` and before archiving. Exit 0 = OK, 1 = problems.
## Fail-closed: the manifest, engine version, every source and every destination
## are validated before anything is written; any problem means nothing is written.
## --copy skips byte-identical files (mtime untouched), writes the rest through a
## sibling temp file renamed over the destination, and never touches other files.

const MANIFEST := "res://tools/release/notices_manifest.json"
const TEMP_SUFFIX := ".notices-tmp"
const GENERATED_KINDS := ["godot_license", "godot_copyright"]

var problems: Array[String] = []


func _initialize() -> void:
	var positional: Array[String] = []
	var manifest_path := MANIFEST
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--manifest="):
			manifest_path = arg.trim_prefix("--manifest=")
		else:
			positional.append(arg)
	var mode: String = positional[0] if positional.size() > 0 else "--sources"
	var dir: String = positional[1] if positional.size() > 1 else ""
	var expected := _load_expected(manifest_path)
	if not mode in ["--sources", "--copy", "--check"]:
		problems.append("unknown mode " + mode)
	elif mode != "--sources":
		dir = _validate_dir(mode, dir)
		if problems.is_empty():
			for dest: String in expected:
				_validate_dest(dir, dest)
	# Nothing below runs unless every check above passed.
	if problems.is_empty() and mode == "--copy":
		for dest: String in expected:
			_copy_one(dir.path_join(dest), expected[dest])
	elif problems.is_empty() and mode == "--check":
		for dest: String in expected:
			var path := dir.path_join(dest)
			if not FileAccess.file_exists(path):
				problems.append("missing beside executable: " + path)
			elif FileAccess.get_file_as_bytes(path) != expected[dest]:
				problems.append("differs from source: " + path)
			else:
				print("NOTICE_OK ", path, " sha256=", FileAccess.get_sha256(path))
	for p in problems:
		print("NOTICE_PROBLEM ", p)
	print("NOTICES_%s mode=%s files=%d problems=%d" % ["OK" if problems.is_empty() else "FAIL", mode, expected.size(), problems.size()])
	quit(0 if problems.is_empty() else 1)


## dest -> bytes for every manifest entry; records problems instead of guessing.
func _load_expected(manifest_path: String) -> Dictionary:
	var expected := {}
	if not FileAccess.file_exists(manifest_path):
		problems.append("manifest not found: " + manifest_path)
		return expected
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if typeof(manifest) != TYPE_DICTIONARY:
		problems.append("manifest is not a JSON object: " + manifest_path)
		return expected
	if typeof(manifest.get("godot_version")) != TYPE_STRING or typeof(manifest.get("files")) != TYPE_ARRAY or typeof(manifest.get("generated")) != TYPE_ARRAY:
		problems.append("manifest needs string godot_version and arrays files/generated")
		return expected
	var info := Engine.get_version_info()
	var engine := "%s.%s.%s.%s" % [info.major, info.minor, info.patch, info.status]
	if engine != manifest.godot_version:
		problems.append("engine %s != manifest godot_version %s (Godot notices must match the templates)" % [engine, manifest.godot_version])
	for entry in manifest.files + manifest.generated:
		if typeof(entry) != TYPE_DICTIONARY or not _safe_relative(entry.get("dest")):
			problems.append("unsafe or missing dest in entry %s" % [entry])
			continue
		if expected.has(entry.dest):
			problems.append("duplicate dest " + entry.dest)
			continue
		if entry.has("kind"):
			if not entry.kind in GENERATED_KINDS:
				problems.append("unknown generated kind %s" % [entry.kind])
				continue
			expected[entry.dest] = _generated(entry.kind).to_utf8_buffer()
		elif _safe_relative(entry.get("src")):
			var bytes := FileAccess.get_file_as_bytes("res://" + entry.src)
			if bytes.is_empty():
				problems.append("missing or empty source " + entry.src)
			expected[entry.dest] = bytes
		else:
			problems.append("unsafe or missing src in entry %s" % [entry])
	if expected.is_empty() and problems.is_empty():
		problems.append("manifest lists no files")
	return expected


## Non-empty relative path with plain '/'-separated components only.
func _safe_relative(p) -> bool:
	if typeof(p) != TYPE_STRING or p.is_empty() or p.begins_with("/") or "\\" in p or ":" in p:
		return false
	for part: String in p.split("/"):
		if part in ["", ".", ".."]:
			return false
	return true


## Returns the absolute export dir; it must already exist (it holds the executable).
func _validate_dir(mode: String, dir: String) -> String:
	if dir.is_empty():
		problems.append("usage: %s <export dir containing the executable>" % mode)
		return dir
	dir = ProjectSettings.globalize_path(dir).simplify_path()
	if not dir.is_absolute_path() or dir.begins_with("res://") or dir.begins_with("user://") or dir == "/":
		problems.append("export dir must be an absolute, non-root filesystem path: " + dir)
	elif not DirAccess.dir_exists_absolute(dir):
		problems.append("export dir does not exist: " + dir)
	return dir


## Rejects symlinked components, file/directory clashes and stale temp files.
func _validate_dest(dir: String, dest: String) -> void:
	var parts := dest.split("/")
	var cur := dir
	for i in parts.size():
		var da := DirAccess.open(cur)
		if da == null:
			return  # Parent not created yet, so nothing below it exists.
		var next := cur.path_join(parts[i])
		var last := i == parts.size() - 1
		if da.is_link(parts[i]):
			problems.append("symlink in destination path: " + next)
			return
		if not last and FileAccess.file_exists(next):
			problems.append("destination parent is a file: " + next)
			return
		if last and DirAccess.dir_exists_absolute(next):
			problems.append("destination is a directory: " + next)
			return
		if last and (FileAccess.file_exists(next + TEMP_SUFFIX) or DirAccess.dir_exists_absolute(next + TEMP_SUFFIX)):
			problems.append("stale temp file in the way: " + next + TEMP_SUFFIX)
			return
		cur = next


func _copy_one(path: String, bytes: PackedByteArray) -> void:
	if FileAccess.file_exists(path) and FileAccess.get_file_as_bytes(path) == bytes:
		print("NOTICE_UNCHANGED ", path)
		return
	var err := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if err != OK:
		problems.append("cannot create %s (err %d)" % [path.get_base_dir(), err])
		return
	var tmp := path + TEMP_SUFFIX
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		problems.append("cannot write " + tmp)
		return
	f.store_buffer(bytes)
	f.close()
	if FileAccess.get_file_as_bytes(tmp) != bytes:
		DirAccess.remove_absolute(tmp)
		problems.append("temp readback mismatch " + tmp)
		return
	err = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		DirAccess.remove_absolute(tmp)
		problems.append("cannot rename %s -> %s (err %d)" % [tmp, path, err])
		return
	print("NOTICE_COPIED ", path)


func _generated(kind: String) -> String:
	if kind == "godot_license":
		return Engine.get_license_text()
	# Engine-provided component notices and full license texts, unedited.
	var out := PackedStringArray(["Godot Engine third-party components (from Engine.get_copyright_info / get_license_info).", ""])
	for component: Dictionary in Engine.get_copyright_info():
		out.append("Component: " + component.name)
		for part: Dictionary in component.parts:
			out.append("  Files: " + ", ".join(part.files))
			for line: String in part.copyright:
				out.append("  Copyright: " + line)
			out.append("  License: " + part.license)
		out.append("")
	var licenses := Engine.get_license_info()
	for license_name: String in licenses:
		out.append("License: " + license_name)
		out.append(licenses[license_name])
		out.append("")
	return "\n".join(out)
