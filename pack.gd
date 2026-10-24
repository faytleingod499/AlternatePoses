# Rebuilds package/AlternatePoses/AlternatePoses.pck from source/ with the Godot 3.5 engine's own packer.
# Run from this folder with:  godot --no-window -s pack.gd
# (or give PCK_OUT and PCK_SRC_DIR as absolute paths). The FILES list is fixed: add a new file here.
extends SceneTree

const FILES = ["main.gd"]

func _init():
	var out = OS.get_environment("PCK_OUT")
	if out == "":
		out = "package/AlternatePoses/AlternatePoses.pck"
	var src = OS.get_environment("PCK_SRC_DIR")
	if src == "":
		src = "source/mods/AlternatePoses"
	var packer = PCKPacker.new()
	packer.pck_start(out, 32)
	for name in FILES:
		packer.add_file("res://mods/AlternatePoses/" + name, src.plus_file(name))
	print("pack result: ", packer.flush(true))
	quit()
