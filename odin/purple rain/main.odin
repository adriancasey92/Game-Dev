#+feature dynamic-literals
package main

import "core:fmt"
import "core:math"
import "core:slice"
import "core:sort"
import "core:strings"
import rl "vendor:raylib"

FLT_MAX :: 340282346638528859811704183484516925440.0

//Declare types
Vec3 :: rl.Vector3
Vec2 :: rl.Vector2

pause: bool
rand_colours: bool

width :: 900
height :: 900

snakeSize :: 50
center :: Vec2{width / 2, height / 2}

player: Snake
dot: Dot
player_col: rl.Color
background_col: rl.Color

//Cameras
camera2D: rl.Camera2D
camera3D: rl.Camera3D

Snake :: struct {
	speed: f32,
	size:  int,
	body:  [350]Rect,
}

Dot :: struct {
	pos:  Vec2,
	col:  rl.Color,
	size: Vec2,
}

Rect :: struct {
	pos:       Vec2,
	size:      Vec2,
	direction: Vec2,
}

random_uniform :: proc(min, max: f32) -> f32 {
	return min + (max - min) * f32(rl.GetRandomValue(0, 10000)) / 10000.0
}

randrange :: proc(max: i32) -> i32 {
	return rl.GetRandomValue(0, max - 1)
}

get_random_col :: proc(s: string) -> rl.Color {
	col: rl.Color
	num: i32
	if s == "player" {
		num := randrange(3)
		switch (num) 
		{
		case 1:
			col = rl.GREEN
		case 2:
			col = rl.SKYBLUE
		case 3:
			col = rl.RED
		}
	} else if s == "dot" {
		num := randrange(16)
		switch (num) 
		{
		case 1:
			col = rl.YELLOW
		case 2:
			col = rl.GOLD
		case 3:
			col = rl.ORANGE
		case 4:
			col = rl.PINK
		case 5:
			col = rl.RED
		case 6:
			col = rl.MAROON
		case 7:
			col = rl.GREEN
		case 8:
			col = rl.LIME
		case 9:
			col = rl.DARKGREEN
		case 10:
			col = rl.SKYBLUE
		case 11:
			col = rl.BLUE
		case 12:
			col = rl.DARKBLUE
		case 13:
			col = rl.PURPLE
		case 14:
			col = rl.VIOLET
		case 15:
			col = rl.DARKPURPLE
		case 16:
			col = rl.MAGENTA
		}
		col = rl.RED

	} else if s == "background" {
		num := randrange(1)
		switch (num) 
		{
		case 0:
			col = rl.DARKBLUE
		case 1:
			col = rl.DARKPURPLE
		}
	}
	return col
}

init_camera2D :: proc(cam: rl.Camera2D) {
	camera2D = {{0, 0}, {0.0, 0.0}, 0, 0}
	//rl.DisableCursor()
}

init_camera3D :: proc(cam: rl.Camera) {
	//camera3D = {{15, 15, -Z_DIST}, {0.0, 0.0, 0.0}, {0.0, 1.0, 0.0}, 60.0, .PERSPECTIVE}
	//rl.DisableCursor()
}

init_program :: proc() {

	//Color
	//background_col = get_random_col()
	//player_col = get_random_col()
	player_col = get_random_col("player")
	background_col = get_random_col("background")
	dot.col = get_random_col("dot")

	fmt.printf("Init program:\n")
	player = Snake {
		speed = 1,
	}
	player.size = 0
	player.body[player.size] = Rect{center, {snakeSize, snakeSize}, {0, 0}}
	//fmt.printf("Player speed: %f\nPlayer direction: %f\n", player.speed, player.direction)
	fmt.printf("Player.length: %i\n", len(player.body))
	spawn_dot()
}

spawn_dot :: proc() {
	// Spawn a dot randomly within the screen
	dot.size = Vec2{20, 20}
	cols := math.floor_f16(width / snakeSize)
	rows := math.floor_f16(height / snakeSize)
	offset := dot.size.x / 2
	posX := randrange(i32(cols)) * i32(snakeSize) + i32(offset) + 4
	posY := randrange(i32(rows)) * i32(snakeSize) + i32(offset) + 4
	dot.pos = Vec2{f32(posX), f32(posY)}
	dot.pos += Vec2{10, 10}
}

print_snake :: proc() {
	for s in player.body {
		fmt.printf("Snake pos %f\n", s.pos)
	}
}

main :: proc() {
	//Set to square
	rl.InitWindow(width, height, "Snake Game")
	if !rl.IsWindowReady() {
		fmt.printf("ERR: Window not ready?\n")
		return
	}
	//Init camera 2D/3D
	init_camera2D(camera2D)
	init_program()
	//init_camera3D(camera3D)
	rl.SetTargetFPS(8)
	for !rl.WindowShouldClose() {
		update()
		draw()
		free_all(context.temp_allocator)
	}
}

update :: proc() {
	if !pause {
		if player.size == len(player.body) {
			for i := 0; i < (len(player.body) - 1); i += 1 {
				player.body[i] = player.body[i + 1]
			}
		}
		if player.size > 0 {
			player.body[player.size - 1] = Rect {
				pos = {player.body[player.size].pos.x, player.body[player.size].pos.y},
			}
		}
		if rl.IsKeyPressed(.W) {
			player.body[0].direction = {0, -snakeSize}
		}
		if rl.IsKeyPressed(.S) {
			player.body[0].direction = {0, snakeSize}
		}
		if rl.IsKeyPressed(.A) {
			player.body[0].direction = {-snakeSize, 0}
		}
		if rl.IsKeyPressed(.D) {
			player.body[0].direction = {snakeSize, 0}
		}
		if rl.IsKeyPressed(.LEFT_SHIFT) {
			player.speed += 1
		}
		if rl.IsKeyReleased(.LEFT_SHIFT) {
			player.speed -= 1
		}

		player.body[player.size].pos += (player.body[player.size].direction) * player.speed
		checkCollisions(player.body[player.size].pos)


		if rl.IsMouseButtonPressed(.LEFT) {

		}
		if rl.IsMouseButtonPressed(.RIGHT) {

		}

		if !pause {

		}
	}

	if rl.IsKeyPressed(.SPACE) {
		print_snake()
		pause = !pause
	}
}

checkCollisions :: proc(v: Vec2) {

	if player.body[0].pos.x < 0 {
		player.body[0].pos.x = width - (snakeSize)
	}

	if player.body[0].pos.x + (snakeSize) > width {
		player.body[0].pos.x = 0
	}

	if player.body[0].pos.y < 0 {
		player.body[0].pos.y = height - (snakeSize)
	}

	if player.body[0].pos.y + (snakeSize) > height {
		player.body[0].pos.y = 0
	}


	//v = where player will end up

	// Collided with dot
	if rl.CheckCollisionCircleRec(
		dot.pos,
		dot.size.x / 2,
		{player.body[0].pos.x, player.body[0].pos.y, player.body[0].size.x, player.body[0].size.y},
	) {
		//fmt.printf()
		player.size += 1
		spawn_dot()
	}
}

draw :: proc() {
	rl.BeginDrawing()
	//rl.BeginBlendMode(.ADDITIVE)

	rl.ClearBackground(background_col)
	//rl.BeginMode2D(camera2D)

	for i := 0; i < (width / snakeSize); i += 1 {
		for j := 0; j < (height / snakeSize); j += 1 {
			rl.DrawRectangleLines(
				i32(i * snakeSize),
				i32(j * snakeSize),
				snakeSize,
				snakeSize,
				rl.BLACK,
			)
		}
	}
	rl.DrawCircle(i32(dot.pos.x), i32(dot.pos.y), f32(dot.size.x / 2), dot.col)
	rl.DrawCircleLines(i32(dot.pos.x), i32(dot.pos.y), f32(dot.size.x / 2), rl.BLACK)
	for i := 0; i < player.size; i += 1 {
		//fmt.printf("PRINTING SNAKE?\n")
		rl.DrawRectangleV(player.body[i].pos, player.body[i].size, rl.GREEN)
		rl.DrawRectangleLinesEx(
			{
				player.body[i].pos.x,
				player.body[i].pos.y,
				player.body[i].size.x,
				player.body[i].size.y,
			},
			2,
			rl.BLACK,
		)
	}


	//rl.BeginMode2D(camera)
	//rl.EndMode2D()
	rl.EndDrawing()
}
