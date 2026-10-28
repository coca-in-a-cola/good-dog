extends SceneTree
## Verifies vendored third-party files against their upstream git blob SHA-1
## (GitHub contents API `sha`) and prints SHA-256 for THIRD_PARTY.md.
##   godot4 --headless --path <project> -s res://tools/verify_vendor.gd

const FILES := {
	"res://addons/basic_fps_controller/scripts/fps_controller.gd": "fde016bbb91b25973701c5dfbbf40b5bf0fd4565",
	"res://addons/basic_fps_controller/LICENSE.txt": "21d4c5eff7a2e5b501a446f67755ddbaa3ce565d",
}


func _initialize() -> void:
	var bad := 0
	for path: String in FILES:
		var bytes := FileAccess.get_file_as_bytes(path)
		var git := HashingContext.new()
		git.start(HashingContext.HASH_SHA1)
		git.update(("blob %d" % bytes.size()).to_utf8_buffer())
		git.update(PackedByteArray([0]))
		git.update(bytes)
		var blob := git.finish().hex_encode()
		var sha := HashingContext.new()
		sha.start(HashingContext.HASH_SHA256)
		sha.update(bytes)
		var ok: bool = blob == FILES[path]
		bad += 0 if ok else 1
		print("[vendor] %s %s size=%d git_blob=%s expected=%s sha256=%s" % ["OK  " if ok else "FAIL", path,
				bytes.size(), blob, FILES[path], sha.finish().hex_encode()])
	quit(1 if bad else 0)
