#+feature dynamic-literals
package main

import "core:fmt"
import "core:math"
import "core:slice"
import "core:sort"
import "core:strings"
import rl "vendor:raylib"

//Declare types
Vec3 :: rl.Vector3
Vec2 :: rl.Vector2

//Constants
WIDTH :: 1280
HEIGHT :: 960
W_COLS :: WIDTH / snakeSize
W_ROWS :: HEIGHT / snakeSize
WINDOW_NAME :: "Snek game"
CENTER :: Vec2{WIDTH / 2, HEIGHT / 2}
BACKGROUND_COL: rl.Color
PAUSE: bool
//Cameras
camera2D: rl.Camera2D
camera3D: rl.Camera3D

//Game 
snakeHead: ^Snake
snakeSize :: 40
snakeVel: Vec2
move_timer: f32
move_delay: f32

//Dummy struct
Snake :: struct {
	pos:  Vec2,
	size: Vec2,
	next: ^Snake,
}

// creates a snek segment
create_segment :: proc(pos: Vec2) -> ^Snake {
	n := new(Snake)
	n^ = {
		pos  = pos,
		size = snakeSize,
		next = nil,
	}
	return n
}

insertAtFirst :: proc(head: ^^Snake, pos: Vec2) {
	//create a new node
	newSnake := create_segment(pos)
	//assign the next node to head^ which is the dereferences head^^ (a node pointer)
	newSnake.next = head^
	//reassign head to equal newNode
	head^ = newSnake
}

print :: proc(head: ^Snake) {
	tmp := head
	for tmp != nil {
		fmt.printf("%f -> \n", tmp.pos)
		tmp = tmp.next
	}
	fmt.printf("NULL\n")
}

//Random function
random_uniform :: proc(min, max: f32) -> f32 {
	return min + (max - min) * f32(rl.GetRandomValue(0, 10000)) / 10000.0
}

//Random range function
randrange :: proc(max: i32) -> i32 {
	return rl.GetRandomValue(0, max - 1)
}

//Init camera functions
init_camera2D :: proc() {
	camera2D = {{0, 0}, {0.0, 0.0}, 0, 0}
	//rl.DisableCursor()
}
init_camera3D :: proc(cam: rl.Camera) {
	//camera3D = {{15, 15, -Z_DIST}, {0.0, 0.0, 0.0}, {0.0, 1.0, 0.0}, 60.0, .PERSPECTIVE}
	//rl.DisableCursor()
}

init_program :: proc() {
	fmt.printf("Init program:\n")
	move_timer = 0
	move_delay = 2
	snakeHead = nil
	insertAtFirst(&snakeHead, CENTER)

	print(snakeHead)
	//Default backgroundcolor
	BACKGROUND_COL = rl.BLACK
}

main :: proc() {
	//Set to square
	rl.InitWindow(WIDTH, HEIGHT, WINDOW_NAME)
	if !rl.IsWindowReady() {
		fmt.printf("ERR: Window not ready?\n")
		return
	}
	//Set FPS
	rl.SetTargetFPS(60)

	//init program
	init_program()

	//Program loop
	for !rl.WindowShouldClose() {
		move_timer += rl.GetFrameTime()
		update()
		draw()
		free_all(context.temp_allocator)
	}
}

update :: proc() {


	if !PAUSE {
		handle_input()

		if move_timer >= move_delay {
			tmp := &snakeHead

			for tmp != nil {

			}
		}
		/**/
	}

	//Make sure we can pause/unpause
	if rl.IsKeyPressed(.SPACE) {
		PAUSE = !PAUSE
	}
}

handle_input :: proc() {
	if rl.IsKeyPressed(.W) {

	}
	if rl.IsKeyPressed(.S) {

	}
	if rl.IsKeyPressed(.A) {

	}
	if rl.IsKeyPressed(.D) {

	}
	if rl.IsKeyPressed(.LEFT_SHIFT) {

	}
	if rl.IsKeyReleased(.LEFT_SHIFT) {

	}

	if rl.IsMouseButtonPressed(.LEFT) {

	}
	if rl.IsMouseButtonPressed(.RIGHT) {

	}
}

checkCollisions :: proc() {

}

draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(BACKGROUND_COL)

	tmp := snakeHead
	for tmp != nil {
		rl.DrawRectangleV(snakeHead.pos, snakeHead.size, rl.GREEN)
		tmp = tmp.next
	}

	//rl.EndMode2D()
	rl.EndDrawing()
}
