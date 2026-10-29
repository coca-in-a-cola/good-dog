extends SceneTree
## Proof driver for package_notices.gd. Runs the real helper as a child process.
##   godot4 --headless --path <project> -s res://tools/release/package_notices_proof.gd
## Staging is evidence/place_signage/tooling-check (wiped and rebuilt each run).
## Exit 0 only if every PROOF line passes.

const HELPER := "res://tools/release/package_notices.gd"
const MANIFEST := "res://tools/release/notices_manifest.json"
const STAGING := "res://evidence/place_signage/tooling-check"

var failures := 0
var staging_root: String


func _initialize() -> void:
	staging_root = ProjectSettings.globalize_path(STAGING)
	_wipe(staging_root)
	DirAccess.make_dir_recursive_absolute(staging_root)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var dests: Array[String] = []
	for entry: Dictionary in manifest.files + manifest.generated:
		dests.append(entry.dest)
	_expect("manifest lists 8 notices", dests.size() == 8, "count=%d" % dests.size())

	# 1. First copy into a dir that already holds unrelated files.
	var target := staging_root.path_join("export")
	DirAccess.make_dir_recursive_absolute(target.path_join("licenses"))
	var sentinels := {"KEEP_executable.sentinel": "unrelated top-level file\n", "licenses/KEEP_unrelated.txt": "unrelated licenses/ file\n"}
	for rel: String in sentinels:
		_write(target.path_join(rel), sentinels[rel])
	var sentinel_meta := _snapshot(target, sentinels.keys())
	var r := _run(["--copy", target])
	_expect("first copy exit 0", r.exit == 0, "exit=%d" % r.exit)
	_expect("first copy wrote 8", r.out.count("NOTICE_COPIED ") == 8, "copied=%d" % r.out.count("NOTICE_COPIED "))
	var first := _snapshot(target, dests)
	_expect("all 8 present after first copy", first.size() == 8 and not first.values().has(null), str(first.size()))

	# 2. Second copy after a >1 s gap must touch nothing (mtime has 1 s resolution).
	OS.delay_msec(2100)
	r = _run(["--copy", target])
	_expect("second copy exit 0", r.exit == 0, "exit=%d" % r.exit)
	_expect("second copy unchanged 8 copied 0", r.out.count("NOTICE_UNCHANGED ") == 8 and r.out.count("NOTICE_COPIED ") == 0, "unchanged=%d copied=%d" % [r.out.count("NOTICE_UNCHANGED "), r.out.count("NOTICE_COPIED ")])
	_expect("second copy mtime+sha256 identical", _snapshot(target, dests) == first, "")
	r = _run(["--check", target])
	_expect("check exit 0 with 8 OK", r.exit == 0 and r.out.count("NOTICE_OK ") == 8, "exit=%d ok=%d" % [r.exit, r.out.count("NOTICE_OK ")])

	# 3. A tampered notice is rewritten alone; the others keep their mtime.
	_write(target.path_join("LICENSE"), "tampered\n")
	OS.delay_msec(1100)
	r = _run(["--copy", target])
	var after := _snapshot(target, dests)
	var others_same := true
	for d in dests:
		if d != "LICENSE" and after[d] != first[d]:
			others_same = false
	_expect("tamper repair exit 0, 1 copied 7 unchanged", r.exit == 0 and r.out.count("NOTICE_COPIED ") == 1 and r.out.count("NOTICE_UNCHANGED ") == 7, "exit=%d" % r.exit)
	_expect("tamper repair restores LICENSE hash", after["LICENSE"][1] == first["LICENSE"][1], "")
	_expect("tamper repair leaves other 7 mtimes", others_same, "")
	_expect("unrelated sentinels preserved", _snapshot(target, sentinels.keys()) == sentinel_meta, "")
	_expect("no temp files left", _list(target).filter(func(p): return p.ends_with(".notices-tmp")).is_empty(), str(_list(target)))

	# 4. Invalid manifests / dirs: exit 1 and zero writes.
	var bad := staging_root.path_join("bad")
	DirAccess.make_dir_recursive_absolute(bad)
	var good_text := FileAccess.get_file_as_string(MANIFEST)
	var wrong_version := good_text.replace("\"godot_version\": \"%s\"" % manifest.godot_version, "\"godot_version\": \"0.0.0.stable\"")
	_expect("wrong-version manifest differs", wrong_version != good_text, "")
	var cases := {
		"wrong_version": wrong_version,
		"malformed_json": "{ \"godot_version\": ",
		"dest_escape": good_text.replace("\"dest\": \"LICENSE\"", "\"dest\": \"../ESCAPED\""),
		"dest_absolute": good_text.replace("\"dest\": \"LICENSE\"", "\"dest\": \"/tmp/good-dog-notices-ESCAPED\""),
		"missing_source": good_text.replace("\"src\": \"LICENSE\"", "\"src\": \"NO_SUCH_LICENSE\""),
		"duplicate_dest": good_text.replace("\"dest\": \"THIRD_PARTY.md\"", "\"dest\": \"LICENSE\""),
	}
	for case_name: String in cases:
		var mpath := staging_root.path_join("manifests").path_join(case_name + ".json")
		DirAccess.make_dir_recursive_absolute(mpath.get_base_dir())
		_write(mpath, cases[case_name])
		var case_dir := bad.path_join(case_name).path_join("export")
		DirAccess.make_dir_recursive_absolute(case_dir)
		_write(case_dir.path_join("KEEP.sentinel"), "keep\n")
		var before := _list(bad.path_join(case_name))
		r = _run(["--copy", case_dir, "--manifest=" + mpath])
		var unchanged: bool = _list(bad.path_join(case_name)) == before and not FileAccess.file_exists("/tmp/good-dog-notices-ESCAPED")
		_expect("invalid %s exit 1 and no writes" % case_name, r.exit == 1 and unchanged and r.out.count("NOTICE_COPIED ") == 0, "exit=%d files=%s" % [r.exit, _list(bad.path_join(case_name))])
	var missing_dir := bad.path_join("does_not_exist")
	r = _run(["--copy", missing_dir])
	_expect("missing export dir exit 1, not created", r.exit == 1 and not DirAccess.dir_exists_absolute(missing_dir), "exit=%d" % r.exit)
	r = _run(["--copy", "relative/export"])
	_expect("relative export dir exit 1", r.exit == 1, "exit=%d" % r.exit)
	# Destination where a notice path is a directory: fail before writing anything.
	var clash := bad.path_join("dir_clash")
	DirAccess.make_dir_recursive_absolute(clash.path_join("THIRD_PARTY.md"))
	var clash_before := _list(clash)
	r = _run(["--copy", clash])
	_expect("dest-is-directory exit 1 and no writes", r.exit == 1 and _list(clash) == clash_before, "exit=%d" % r.exit)

	print("PROOF_%s failures=%d" % ["OK" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)


func _run(args: Array) -> Dictionary:
	var out := []
	var argv := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", HELPER, "--"] + args
	var code := OS.execute(OS.get_executable_path(), PackedStringArray(argv), out, true)
	var text := "\n".join(out)
	var tail := text.strip_edges().get_slice("\n", text.strip_edges().count("\n"))
	print("PROOF_RUN exit=%d args=%s summary=%s" % [code, args, tail])
	return {"exit": code, "out": text}


func _expect(label: String, ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
	print("PROOF_%s %s %s" % ["PASS" if ok else "FAIL", label, detail])


## rel -> [mtime, sha256] (null if missing).
func _snapshot(base: String, rels: Array) -> Dictionary:
	var snap := {}
	for rel: String in rels:
		var p := base.path_join(rel)
		snap[rel] = [FileAccess.get_modified_time(p), FileAccess.get_sha256(p)] if FileAccess.file_exists(p) else null
	return snap


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


## Sorted relative paths of every file and directory under base.
func _list(base: String, prefix := "") -> Array:
	var out := []
	var da := DirAccess.open(base.path_join(prefix))
	if da == null:
		return out
	da.include_hidden = true
	for d in da.get_directories():
		out.append(prefix.path_join(d) + "/")
		out.append_array(_list(base, prefix.path_join(d)))
	for f in da.get_files():
		out.append(prefix.path_join(f))
	out.sort()
	return out


## Deletes only the proof staging tree.
func _wipe(path: String) -> void:
	if not path.ends_with("evidence/place_signage/tooling-check") and not path.begins_with(staging_root + "/"):
		return
	var da := DirAccess.open(path)
	if da == null:
		return
	da.include_hidden = true
	for d in da.get_directories():
		_wipe(path.path_join(d))
	for f in da.get_files():
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)
