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
SPEED :: 3
WIDTH :: 1280
HEIGHT :: 600
MAX_GROWTH :: 10
//time in seconds
GROWTH_TIME :: 2
CENTER :: Vec2{WIDTH / 2, HEIGHT / 2}
BACKGROUND_COL: rl.Color
PAUSE: bool


//Cameras
camera2D: rl.Camera2D
camera3D: rl.Camera3D

//initial cells array
Cells: [dynamic]Cell

//Dummy struct
Cell :: struct {
	pos:             Vec2,
	//Radius?
	size:            f32,
	vel:             Vec2,
	growth:          f32,
	clicked:         bool,
	col:             rl.Color,
	timeSinceGrowth: f32,
	collision:       bool,
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
	//Default backgroundcolor
	BACKGROUND_COL = rl.VIOLET
	create_cell()
}

create_cell :: proc() {
	for i := 1; i < 3; i += 2 {
		append(
			&Cells,
			Cell {
				pos = Vec2 {
					f32(random_uniform(0, f32(WIDTH / i))),
					f32(random_uniform(0, f32(HEIGHT / i))),
				},
				size = random_uniform(40, 60),
				vel = {random_uniform(-1, 1), random_uniform(-1, 1)},
				growth = 0,
				clicked = false,
				col = rl.YELLOW,
				timeSinceGrowth = 0,
				collision = false,
			},
		)
	}

	for &cell in Cells {
		cell.pos += cell.vel * Vec2{f32(SPEED), f32(SPEED)}
	}
}

split_cell :: proc(c: ^Cell) {
	new_cell_pos := Vec2{c.pos.x - (c.size / 2), c.pos.y - (c.size / 2)}
	old_cell_pos := Vec2{c.pos.x + (c.size / 2), c.pos.y + (c.size / 2)}

	new_cell := Cell{new_cell_pos, c.size / 2, {c.vel.x, c.vel.y}, 0, false, rl.YELLOW, 0, false}
	old_cell := Cell{old_cell_pos, c.size / 2, {-c.vel.x, c.vel.y}, 0, false, rl.YELLOW, 0, false}

	pos := 0
	for &cell, idx in Cells {
		if cell.clicked {
			pos = idx
		}
	}
	unordered_remove(&Cells, pos)
	append(&Cells, old_cell)
	append(&Cells, new_cell)
}

main :: proc() {

	defer delete(Cells)
	//Set to square
	rl.InitWindow(WIDTH, HEIGHT, "Mitosis Simulation")
	if !rl.IsWindowReady() {
		fmt.printf("ERR: Window not ready?\n")
		return
	}
	//Set FPS
	rl.SetTargetFPS(60)
	//Init camera 2D/3D
	init_camera2D()
	//init_camera3D()

	//init program
	init_program()

	//Program loop
	for !rl.WindowShouldClose() {
		update()
		draw()
		free_all(context.temp_allocator)
	}
}

update :: proc() {
	if !PAUSE {
		handle_input()
		for &cell in Cells {
			cell.timeSinceGrowth += rl.GetFrameTime()
			cell.vel = Vec2{random_uniform(-1, 1), random_uniform(-1, 1)}
			cell.pos += cell.vel * Vec2{f32(SPEED), f32(SPEED)}
			fmt.printf("Time :%f\n", cell.timeSinceGrowth)
			if cell.timeSinceGrowth >= .5 {
				if cell.growth < MAX_GROWTH {
					cell.growth += 1
					cell.size = cell.size + cell.growth
					cell.timeSinceGrowth = 0
				}
			}
		}
		checkCollisions()
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
		mp := rl.GetMousePosition()
		for &cell in Cells {
			if rl.CheckCollisionPointCircle(mp, cell.pos, cell.size) {
				cell.clicked = true
				split_cell(&cell)
			}
		}
	}
	if rl.IsMouseButtonPressed(.RIGHT) {

	}
}

checkCollisions :: proc() {
	for &cell in Cells {
		if cell.pos.x > WIDTH - cell.size {
			cell.pos.x = WIDTH - cell.size
			cell.vel = Vec2{-1, cell.vel.y}
		}
		if cell.pos.x < 0 + cell.size {
			cell.pos.x = 0 + cell.size
			cell.vel = Vec2{1, cell.vel.y}
		}
		if cell.pos.y > HEIGHT - cell.size {
			cell.pos.y = HEIGHT - cell.size
			cell.vel = Vec2{cell.vel.x, -1}
		}
		if cell.pos.y < 0 + cell.size {
			cell.pos.y = 0 + cell.size
			cell.vel = Vec2{cell.vel.x, 1}
		}
	}

	for &C1 in Cells {
		for &C2 in Cells {
			if rl.CheckCollisionCircles(C1.pos, C1.size, C2.pos, C2.size) {
				C1.collision = true
				C2.collision = true
			}
		}
	}
}

draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(BACKGROUND_COL)

	for cell in Cells {

		if cell.collision {
			rl.DrawCircle(i32(cell.pos.x), i32(cell.pos.y), cell.size, rl.RED)
		} else {
			rl.DrawCircle(i32(cell.pos.x), i32(cell.pos.y), cell.size, cell.col)
		}
		rl.DrawCircle(i32(cell.pos.x), i32(cell.pos.y), cell.size, cell.col)
		rl.DrawCircleLinesV(cell.pos, cell.size, rl.BLACK)
	}
	//rl.EndMode2D()
	rl.EndDrawing()
}
