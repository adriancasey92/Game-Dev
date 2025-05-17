package main


import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"


Game_State :: struct {
	window_size:            rl.Vector2,
	paddle:                 rl.Rectangle,
	ai_paddle:              rl.Rectangle,
	player_boost_available: bool,
	paddle_MIN:             f32,
	paddle_MAX:             f32,
	paddle_INC:             f32,
	paddle_speed:           f32,
	ball:                   rl.Rectangle,
	ball_dir:               rl.Vector2,
	ball_speed:             f32,
	ai_target_y:            f32,
	ai_reaction_delay:      f32,
	ai_reaction_timer:      f32,
	score_player:           int,
	score_cpu:              int,
	boost_timer:            f32,
	wall_bounces:           f32,
}

main :: proc() {

	gs := Game_State {
		window_size = {1280, 720},
		paddle = {width = 30, height = 75},
		paddle_MIN = 25,
		paddle_MAX = 150,
		paddle_INC = 25,
		ai_paddle = {width = 30, height = 80},
		paddle_speed = 10,
		ball = {width = 30, height = 30},
		ball_speed = 10,
		ai_reaction_delay = 0.1,
		wall_bounces = 0,
	}
	//Initialise our Game State paddle, ball positions.
	reset(&gs)
	//using namestate gs (NOT RECOMMENDED FOR FUTURE CODE)
	using gs
	rl.InitWindow(i32(window_size.x), i32(window_size.y), "Pong") //Initialise raylib window object. We are casting to i32 type as that is //the required size for creating window
	rl.SetTargetFPS(60)

	rl.InitAudioDevice()
	defer rl.CloseAudioDevice()

	sfx_hit_player := rl.LoadSound("resource/sounds/hit_player.wav")
	sfx_hit_ai := rl.LoadSound("resource/sounds/hit_ai.wav")
	sfx_win := rl.LoadSound("resource/sounds/win.wav")
	sfx_wall_hit := rl.LoadSound("resource/sounds/wall_hit.wav")
	sfx_lose := rl.LoadSound("resource/sounds/lose.wav")

	//Game loop
	for !rl.WindowShouldClose() {
		delta := rl.GetFrameTime()
		boost_timer -= delta
		//User input
		if rl.IsKeyDown(.UP) {
			paddle.y -= paddle_speed
		}
		if rl.IsKeyDown(.DOWN) {
			paddle.y += paddle_speed
		}
		// Just after other input code:
		if rl.IsKeyPressed(.SPACE) {
			if boost_timer < 0 {

				boost_timer = 0.2
			} else {
				player_boost_available = true
			}
		}


		//Prevent moving off screen
		paddle.y = linalg.clamp(paddle.y, 0, window_size.y - paddle.height)

		//Calculate ball position and bouncing
		next_ball_rect := ball
		next_ball_rect.x += ball_speed * ball_dir.x
		next_ball_rect.y += ball_speed * ball_dir.y

		//If ball goes passed the paddle reset game
		if next_ball_rect.y >= 720 - ball.height || next_ball_rect.y <= 0 {
			rl.PlaySound(sfx_wall_hit)
			wall_bounces += 1
			ball_dir.y *= -1
		}
		if (wall_bounces >= 6) {
			angle := rand.float32_range(-45, 46)
			if rand.int_max(100) % 2 == 0 do angle += 180
			r := math.to_radians(angle)

			ball_dir.x = math.cos(r)
			ball_dir.y = math.cos(r)
			wall_bounces = 0
		}
		if next_ball_rect.x >= window_size.x - ball.width {
			score_cpu += 1
			rl.PlaySound(sfx_lose)
			if paddle.height <= paddle_MAX {
				if (paddle.height + paddle_INC) > paddle_MAX {
					paddle.height = paddle_MAX
				} else {
					paddle.height += paddle_INC
				}
				paddle.height += paddle_INC
			}
			if (ai_paddle.height >= paddle_MIN) {
				if ai_paddle.height - paddle_INC < paddle_MIN {
					ai_paddle.height = paddle_MIN
				} else {
					ai_paddle.height -= paddle_INC
				}
			}
			reset(&gs)
		}
		if next_ball_rect.x < 0 {
			score_player += 1
			rl.PlaySound(sfx_win)
			if paddle.height >= paddle_MIN {
				if paddle.height - paddle_INC < paddle_MIN {
					paddle.height = paddle_MIN
				} else {
					paddle.height -= paddle_INC
				}
			}
			if (ai_paddle.height <= paddle_MAX) {
				if ai_paddle.height + paddle_INC > paddle_MAX {
					ai_paddle.height = paddle_MAX
				} else {
					ai_paddle.height += paddle_INC
				}
			}

			reset(&gs)
		}
		last_ball_dir := ball_dir
		//calc ball direction
		ball_dir = ball_dir_calculate(next_ball_rect, paddle) or_else ball_dir
		ball_dir = ball_dir_calculate(next_ball_rect, ai_paddle) or_else ball_dir

		if last_ball_dir != ball_dir {
			wall_bounces = 0
			if ball_dir.x > 0 {
				rl.PlaySound(sfx_hit_ai)
			} else {
				rl.PlaySound(sfx_hit_player)
			}

		}
		new_dir, did_hit := ball_dir_calculate(next_ball_rect, paddle)
		if did_hit {
			if boost_timer > 0 {
				d := 1 + boost_timer / 0.2
				new_dir *= d
			}
			ball_dir = new_dir
		}

		ball.x += ball_speed * ball_dir.x
		ball.y += ball_speed * ball_dir.y

		// AI movement
		// increase timer by time between last frame and this one
		ai_reaction_timer += delta
		// if the timer is done:
		if ai_reaction_timer >= ai_reaction_delay {
			// reset the timer
			ai_reaction_timer = 0
			// use ball from last frame for extra delay
			ball_mid := ball.y + ball.height / 2
			// if the ball is heading left
			if ball_dir.x < 0 {
				// set the target to the ball
				ai_target_y = ball_mid - ai_paddle.height / 2
				// add or subtract 0-20 to add inaccuracy
				ai_target_y += rand.float32_range(-20, 20)
			} else {
				// set the target to screen middle
				ai_target_y = window_size.y / 2 - ai_paddle.height / 2
			}
		}
		// calculate the distance between paddle and target
		ai_paddle_mid := ai_paddle.y + ai_paddle.height / 2
		target_diff := ai_target_y - ai_paddle.y
		// move either paddle_speed distance or less
		// won't bounce around so much
		ai_paddle.y += linalg.clamp(target_diff, -paddle_speed, paddle_speed) * 0.65
		// clamp to window_size
		ai_paddle.y = linalg.clamp(ai_paddle.y, 0, window_size.y - ai_paddle.height)

		if boost_timer > 0 {
			rl.DrawRectangleRec(paddle, {u8(255 * (0.2 / boost_timer)), 255, 255, 255})
		} else {
			rl.DrawRectangleRec(paddle, rl.WHITE)
		}

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		if player_boost_available {
			rl.DrawRectangle(i32(window_size.x) - 32, i32(window_size.y) - 32, 32, 32, rl.ORANGE)
		}
		rl.DrawRectangleRec(paddle, rl.WHITE)
		rl.DrawRectangleRec(ai_paddle, rl.YELLOW)
		rl.DrawRectangleRec(ball, {255, u8(255 - 255 / linalg.length(ball_dir)), 0, 255})
		rl.DrawText(fmt.ctprintf("{}", score_cpu), 12, 12, 32, rl.WHITE)
		rl.DrawText(fmt.ctprintf("{}", score_player), i32(window_size.x) - 28, 12, 32, rl.WHITE)
		rl.EndDrawing()
		free_all(context.temp_allocator)

	}
}


//This checks if collisions happen, then returns the new direction for the ball to travel, and true
//if not we return a zero value using {}

/*|-------------------------------------------------------------------------------------------------|*/
/*|NOTE {} returns are used for structs, for pointers return nil, numbers 0, strings "", bools false|*/
/*|-------------------------------------------------------------------------------------------------|*/

ball_dir_calculate :: proc(ball: rl.Rectangle, paddle: rl.Rectangle) -> (rl.Vector2, bool) {
	if rl.CheckCollisionRecs(ball, paddle) {
		ball_center := rl.Vector2{ball.x + ball.width / 2, ball.y + ball.height / 2}
		paddle_center := rl.Vector2{paddle.x + paddle.width / 2, paddle.y + paddle.height / 2}
		return linalg.normalize0(ball_center - paddle_center), true
	}
	return {}, false
}

//Resets the paddles and ball
reset :: proc(using gs: ^Game_State) {

	angle := rand.float32_range(-45, 46)
	//Random serving to AI and player
	if rand.int_max(100) % 2 == 0 do angle += 180
	r := math.to_radians(angle)

	boost_timer = 0

	ball_dir.x = math.cos(r)
	ball_dir.y = math.sin(r)

	ball.x = window_size.x / 2 - ball.width / 2
	ball.y = window_size.y / 2 - ball.height / 2

	paddle_margin: f32 = 50

	paddle.x = window_size.x - (paddle.width + paddle_margin)
	paddle.y = window_size.y / 2 - paddle.height / 2

	ai_paddle.x = paddle_margin
	ai_paddle.y = window_size.y / 2 - ai_paddle.height / 2

}

rand_dir :: proc() {

}
