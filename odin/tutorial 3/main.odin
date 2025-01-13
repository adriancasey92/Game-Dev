package main

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

ground_type :: enum {
	dirt,
	grass,
	stone,
	air,
	void,
}

Game :: struct {}

Tile :: struct {
	pos:      Vec2i,
	type:     ground_type,
	hardness: f32,
	colour:   rl.Color,
	size:     Vec2i,
}

WINDOW_SIZE :: 1280
WORLD_SIZE :: 50
TILE_SIZE :: 32 //pixels
Vec2i :: [2]int

world_map: [WORLD_SIZE][WORLD_SIZE]Tile


//Draw things
render :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.RAYWHITE)
	drawGrid()
	// Draw the texture at the center of the screen

	rl.EndDrawing()
}

handleInput :: proc() {

}

update :: proc() {

}

//Create the things
init :: proc() {
	for x := 0; x < WORLD_SIZE; x = x + 1 {
		for y := 0; y < WORLD_SIZE; y = y + 1 {
			world_map[x][y] = Tile{{x, y}, ground_type.dirt, 0, rl.BLACK, TILE_SIZE}
		}
	}
}

main :: proc() {

	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(WINDOW_SIZE, WINDOW_SIZE, "GridGame")
	defer rl.CloseWindow()

	init()


	for rl.WindowShouldClose() == false {
		handleInput()
		update()
		render()
	}
}

drawGrid :: proc() {
	for x := 0; x < WORLD_SIZE; x = x + 1 {
		for y := 0; y < WORLD_SIZE; y = y + 1 {

			drawTile(&world_map[x][y])
		}
	}
}

drawTile :: proc(t: ^Tile) {
	switch t.type {
	case ground_type.air:
	case ground_type.dirt:
	case ground_type.grass:
	case ground_type.stone:
	case ground_type.void:
	}

	rl.DrawRectangle(
		i32(t.pos.x) * i32(t.size.x),
		i32(t.pos.y) * i32(t.size.x),
		i32(t.size.x),
		i32(t.size.y),
		rl.BROWN,
	)
	rl.DrawRectangleLines(
		i32(t.pos.x) * i32(t.size.x),
		i32(t.pos.y) * i32(t.size.x),
		i32(t.size.x),
		i32(t.size.y),
		rl.BLACK,
	)
	rl.DrawText(t.pos.x, t.pos.x, t.pos.y, 12, rl.RED)

}
