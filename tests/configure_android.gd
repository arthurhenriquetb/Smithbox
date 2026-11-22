extends SceneTree

# CI-only: configure Godot's machine-local Android paths before exporting an APK.
func _initialize() -> void:
	call_deferred("configure")


func configure() -> void:
	await process_frame
	var sdk := OS.get_environment("ANDROID_SDK_ROOT")
	if sdk == "":
		sdk = OS.get_environment("ANDROID_HOME")
	var java := OS.get_environment("JAVA_HOME")
	if sdk == "" or java == "":
		printerr("ANDROID_SDK_ROOT and JAVA_HOME are required")
		quit(1)
		return
	var editor_settings := EditorInterface.get_editor_settings()
	editor_settings.set_setting("export/android/android_sdk_path",sdk)
	editor_settings.set_setting("export/android/java_sdk_path",java)
	print("Configured Android export paths")
	quit(0)
