package game

import "base:runtime"
import "core:log"
//import "core:os"
//import "core:time"
import rl "vendor:raylib"

Graphics_Settings :: struct {
	borderless: bool,
	fullscreen: bool,
	windowed:   bool,
}

Sound_Settings :: struct {
	sfx:        f32,
	music:      f32,
	channels:   i32,
	sound_type: Sound_Type,
}

Sound_Type :: enum {
	speakers,
	headphones,
	surround,
}

Sound_name :: enum {
	menu_move,
	menu_enter,
}

Sounds :: struct {
	game_sounds: rl.Sound,
}

sound_settings: Sound_Settings


default_context: runtime.Context
SOUND_PATH :: "../assets/sounds"

load_sounds :: proc() {
	context.logger = log.create_console_logger(opt = {.Level})
	default_context = context
	//start_time := time.now()
}
