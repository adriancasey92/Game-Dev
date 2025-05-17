#+feature dynamic-literals
package main

import "core:fmt"
import "core:math"
import "core:math/noise"
import "core:math/rand"
import "core:slice"
import "core:sort"
import "core:strings"
import rl "vendor:raylib"

//Declare types
Vec3 :: rl.Vector3
Vec2 :: rl.Vector2

//Constants
WIDTH :: 1600
HEIGHT :: 900
CANVASWIDTH :: 1280
CANVASHEIGHT :: 720

WINDOW_NAME :: "Perlin Noise"
CENTER :: Vec2{WIDTH / 2, HEIGHT / 2}

permutation: [255]i32


BACKGROUND_COL: rl.Color
PAUSE: bool
//Cameras
camera2D: rl.Camera2D
camera3D: rl.Camera3D
canvas: Canvas
image: rl.Image
texture: rl.Texture

//Dummy struct
Canvas :: struct {
	size:   Vec2,
	pos:    Vec2,
	pixels: [CANVASWIDTH][CANVASHEIGHT]f32,
}

Grid :: struct {
	size: Vec2,
	pos:  Vec2,
}

//Random function
rand_uniform :: proc(min, max: f32) -> f32 {
	return min + (max - min) * f32(rl.GetRandomValue(0, 10000)) / 10000.0
}

//Random range function
randrange :: proc(max: i32) -> i32 {
	return rl.GetRandomValue(0, max - 1)
}

shuffle :: proc(p: []i32) {
	//reverse loop
	for i := len(p); i > 0; i -= 1 {
		//idx := math.round_f16( * (i - 1))
		//f := rand.float32()
	}
}

getrandfloat :: proc(x: i32, y: i32) -> Vec2 {
	fmt.printf("x: %i\ny: %i\n", x, y)
	retX := rand_uniform(f32(x), f32(x + 1))
	retY := rand_uniform(f32(y), f32(y + 1))
	fmt.printf("retx: %f\nrety: %f\n", retX, retY)
	return {retX, retY}
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
	BACKGROUND_COL = rl.BLACK
	canvas = {
		size = {CANVASWIDTH, CANVASHEIGHT},
	}

	canvas.pos.x = 0 + (WIDTH - canvas.size.x) / 2
	canvas.pos.y = 0 + (HEIGHT - canvas.size.y) / 2
	randPos: Vec2
	//Make random canvas
	for i, idx in canvas.pixels {
		for j, idx2 in canvas.pixels[idx] {
			canvas.pixels[idx][idx2] = noise.noise_2d(0, {f64(idx), f64(idx2)})
			//randPos = getrandfloat(i32(idx), i32(idx2))

			//Loop over each corner for every point in the grid
		}
	}
	image = rl.GenImagePerlinNoise(CANVASWIDTH, CANVASHEIGHT, 0, 0, 1)
	texture = rl.LoadTextureFromImage(image)
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

	drawCanvas()
	//rl.DrawTexture(texture, i32(canvas.pos.x), i32(canvas.pos.y), rl.GRAY)

	//rl.EndMode2D()
	rl.EndDrawing()
}

drawCanvas :: proc() {
	for i, idx in canvas.pixels {
		for j, idx2 in canvas.pixels[idx] {
			rl.DrawPixel(
				i32(canvas.pos.x) + i32(idx),
				i32(canvas.pos.y) + i32(idx2),
				rl.ColorFromHSV(0, 0, canvas.pixels[idx][idx2]),
			)
		}
	}
}
