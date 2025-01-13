package main

import "core:fmt"
import rl "vendor:raylib"

Game_State :: struct {
	window_size:  rl.Vector2,
	score_player: int,
	score_cpu:    int,
}

main :: proc() {

	gs := Game_State {
		window_size  = {1280, 720},
		score_player = 0,
		score_cpu    = 0,
	}

	for !rl.WindowShouldClose() {

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		rl.EndDrawing()
		free_all(context.temp_allocator)
	}
}
