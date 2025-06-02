package game

import rl "vendor:raylib"

Game_Shader :: struct {
	time_loc:       i32,
	resolution_loc: i32,
	shader:         rl.Shader,
}
