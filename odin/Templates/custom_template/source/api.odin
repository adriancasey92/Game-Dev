package game

import rl "vendor:raylib"

@(export)
game_init :: proc() {
	init()
}

@(export)
game_init_window :: proc() {
	init_window()
}

@(export)
game_update :: proc() {
	update()
	draw()
}

@(export)
game_should_close :: proc() -> bool {
	return game_should_run()
}

@(export)
game_shutdown :: proc() {
	shutdown()
}

@(export)
game_shutdown_window :: proc() {
	shutdown_window()
}

@(export)
game_memory :: proc() -> rawptr {
	return g
}

@(export)
game_memory_size :: proc() -> int {
	return size_of(Game_Memory)
}

@(export)
game_hot_reloaded :: proc(mem: rawptr) {
	g = (^Game_Memory)(mem)
	refresh_globals()
}

@(export)
game_force_reload :: proc() -> bool {
	return rl.IsKeyPressed(.F5)
}

@(export)
game_force_restart :: proc() -> bool {
	return rl.IsKeyPressed(.F6)
}

@(export)
parent_window_size_changed :: proc "c" (w, h: int) {
	rl.SetWindowSize(i32(w), i32(h))
}
