package main


import "core:math"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"


Game_State :: struct {
	window_size:  rl.Vector2,
	paddle:       rl.Rectangle,
	paddle_speed: f32,
	ball:         rl.Rectangle,
	ball_dir:     rl.Vector2,
	ball_speed:   f32,
}

main :: proc() {

	gs := Game_State {
		window_size = {1280, 720},
		paddle = {width = 30, height = 80},
		paddle_speed = 10,
		ball = {width = 30, height = 30},
		ball_speed = 10,
	}
	//Initialise our Game State paddle, ball positions.
	reset(&gs)
	//using namestate gs (NOT RECOMMENDED FOR FUTURE CODE)
	using gs

	//Initialise raylib window object. We are casting to i32 type as that is 
	//the required size for creating window
	rl.InitWindow(i32(window_size.x), i32(window_size.y), "Pong")
	rl.SetTargetFPS(60)

	//Game loop
	for !rl.WindowShouldClose() {

		//User input
		if rl.IsKeyDown(.UP) {
			paddle.y -= paddle_speed
		}
		if rl.IsKeyDown(.DOWN) {
			paddle.y += paddle_speed
		}

		//Prevent moving off screen
		paddle.y = linalg.clamp(paddle.y, 0, window_size.y - paddle.height)

		//Calculate ball position and bouncing
		next_ball_rect := ball
		next_ball_rect.x += ball_speed * ball_dir.x
		next_ball_rect.y += ball_speed * ball_dir.y


		//If ball goes passed the paddle reset game
		if next_ball_rect.y >= 720 - ball.height || next_ball_rect.y <= 0 {
			ball_dir.y *= -1
		}
		if next_ball_rect.x >= window_size.x - ball.width {
			reset(&gs)
		}
		if next_ball_rect.x < 0 {
			reset(&gs)
		}


		//calculate collision
		if rl.CheckCollisionRecs(next_ball_rect, paddle) {
			ball_center := rl.Vector2 {
				next_ball_rect.x + ball.width / 2,
				next_ball_rect.y + ball.height / 2,
			}
			paddle_center := rl.Vector2{(paddle.x + paddle.width / 2), (paddle.y + paddle.height)}
			ball_dir = linalg.normalize0(ball_center - paddle_center)
		}

		ball.x += ball_speed * ball_dir.x
		ball.y += ball_speed * ball_dir.y
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		rl.DrawRectangleRec(paddle, rl.WHITE)
		rl.DrawRectangleRec(ball, rl.RED)
		rl.EndDrawing()

	}
}


reset :: proc(using gs: ^Game_State) {

	angle := rand.float32_range(-45, 46)
	r := math.to_radians(angle)

	ball_dir.x = math.cos(r)
	ball_dir.y = math.sin(r)

	ball.x = window_size.x / 2 - ball.width / 2
	ball.y = window_size.y / 2 - ball.height / 2

	paddle.x = window_size.x - 80
	paddle.y = window_size.y / 2 - paddle.height / 2

	paddle.x = window_size.x - 80
	paddle.y = window_size.y / 2 - paddle.height / 2
}
