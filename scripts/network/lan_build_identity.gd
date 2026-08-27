class_name LanBuildIdentity
extends RefCounted

const RUNTIME_FILE_PATH := "res://.lan_build_id"
const EDITOR_BUILD_ID := "editor-dev"
const UNVERIFIABLE_PREFIX := "unverifiable:"

const _EXCLUDED_DIRECTORIES := [".git", ".godot", "build"]


static func current_id() -> String:
	if _is_editor_runtime():
		return EDITOR_BUILD_ID
	if not FileAccess.file_exists(RUNTIME_FILE_PATH):
		return UNVERIFIABLE_PREFIX + "missing-build-file"
	var value := FileAccess.get_file_as_string(RUNTIME_FILE_PATH).strip_edges()
	return value if not value.is_empty() else UNVERIFIABLE_PREFIX + "empty-build-file"


static func create_export_identity() -> Dictionary:
	var content_digest := _calculate_worktree_digest()
	var git_result := _read_git_commit()
	var git_available := bool(git_result.get("available", false))
	var commit := str(git_result.get("commit", ""))
	var build_id := ""
	if git_available and not commit.is_empty():
		build_id = "git:%s:%s" % [commit, content_digest]
	else:
		build_id = UNVERIFIABLE_PREFIX + content_digest
	return {
		"id": build_id,
		"commit": commit,
		"content_digest": content_digest,
		"git_available": git_available,
	}


static func _is_editor_runtime() -> bool:
	return Engine.is_editor_hint() or OS.has_feature("editor")


static func _read_git_commit() -> Dictionary:
	var output: Array[String] = []
	var project_path := ProjectSettings.globalize_path("res://")
	var exit_code := OS.execute(
		"git",
		["-C", project_path, "rev-parse", "--verify", "HEAD"],
		output,
		true
	)
	if exit_code != 0 or output.is_empty():
		return {"available": false, "commit": ""}
	var commit := output[0].strip_edges()
	if commit.is_empty():
		return {"available": false, "commit": ""}
	return {"available": true, "commit": commit}


static func _calculate_worktree_digest() -> String:
	# Hash the effective tree so staged/unstaged content and relevant untracked
	# files are represented exactly as they will be seen by the export.
	var files := PackedStringArray()
	_collect_files("res://", "", files)
	files.sort()
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	for relative_path in files:
		var absolute_path := ProjectSettings.globalize_path("res://" + relative_path)
		var contents := FileAccess.get_file_as_bytes(absolute_path)
		context.update(("file:%s:%d\n" % [relative_path, contents.size()]).to_utf8_buffer())
		context.update(contents)
	return context.finish().hex_encode()


static func _collect_files(base_path: String, relative_directory: String, files: PackedStringArray) -> void:
	var directory := DirAccess.open(base_path)
	if directory == null:
		return
	directory.include_hidden = true
	for file_name in directory.get_files():
		var relative_path := relative_directory + file_name
		if relative_path == ".lan_build_id":
			continue
		files.append(relative_path)
	for directory_name in directory.get_directories():
		if directory_name in _EXCLUDED_DIRECTORIES:
			continue
		_collect_files(
			base_path.path_join(directory_name),
			relative_directory + directory_name + "/",
			files
		)
