// Entrada da extensão (bin/apio_voxel.gdextension -> entry_symbol = apio_voxel_init).
#include "apio_voxel.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

static void initialize_apio(ModuleInitializationLevel level) {
	if (level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	GDREGISTER_CLASS(ApioVoxel);
}

static void uninitialize_apio(ModuleInitializationLevel level) {}

extern "C" {
GDExtensionBool GDE_EXPORT apio_voxel_init(GDExtensionInterfaceGetProcAddress get_proc_address,
		const GDExtensionClassLibraryPtr library, GDExtensionInitialization *initialization) {
	GDExtensionBinding::InitObject init(get_proc_address, library, initialization);
	init.register_initializer(initialize_apio);
	init.register_terminator(uninitialize_apio);
	init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init.init();
}
}
