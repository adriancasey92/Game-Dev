package main

import "core:fmt"
import rl "vendor:raylib"

W_ := rl.KeyboardKey.W
S_ := rl.KeyboardKey.S
A_ := rl.KeyboardKey.A
D_ := rl.KeyboardKey.D

Game_State :: struct {
	window_size:  rl.Vector2,
	player_:      rl.Vector2,
	player_dir:   f32,
	score_player: int,
	score_cpu:    int,
}

main :: proc() {

	gs := Game_State {
		window_size  = {1280, 720},
		player_      = {},
		score_player = 0,
		score_cpu    = 0,
	}

	using gs

	player_ = {window_size.x / 2, window_size.y / 2}

	rl.InitWindow(i32(window_size.x), i32(window_size.y), "Asteroids")

	for !rl.WindowShouldClose() {

		//User input
		if rl.IsKeyDown(W_) {
			//move forward
			fmt.println("Move forward")
		}
		if rl.IsKeyDown(S_) {
			fmt.println("Move backward")
		}
		if rl.IsKeyDown(A_) {
			fmt.println("Rotate left")
		}
		if rl.IsKeyDown(D_) {
			fmt.println("Rotate right")
		}

		rl.BeginDrawing()
		//rl.ClearBackground(rl.BLACK)

		rl.DrawTriangle({0, 2}, {2, 0}, {4, 2}, rl.WHITE)

		rl.EndDrawing()
		//free_all(context.temp_allocator)
	}
}
