extends RefCounted
static func lightweight()->bool:
	return OS.get_cmdline_user_args().has("--low-poly") or bool(ProjectSettings.get_setting("ashfall/lightweight_models",false))
