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
	size:    Vec2,
	pos:     Vec2,
	pixels:  [WIDTH * HEIGHT]Pixel,
	checked: bool,
}

Pixel :: struct {
	val:     f32,
	checked: bool,
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
	//init
	for x := 0; x < int(canvas.size.x); x += 1 {
		for y := 0; y < int(canvas.size.y); y += 1 {
			pos := ((y * x) + x)
			canvas.pixels[pos].checked = false
		}
	}

	canvas.pos.x = 0 + (WIDTH - canvas.size.x) / 2
	canvas.pos.y = 0 + (HEIGHT - canvas.size.y) / 2
	randPos: Vec2
	//Make random canvas

	startTime := rl.GetTime()
	count := 0
	for y := 0; y < int(canvas.size.y); {
		for x := 0; x < int(canvas.size.x); {
			count += 1
			fmt.printf("Count: %i\n", count)
			xrand := rand_uniform(0, CANVASWIDTH)
			yrand := rand_uniform(0, CANVASHEIGHT)

			//flat array?
			pos := (yrand * xrand + xrand)
			//if not checked already
			if !canvas.pixels[int(pos)].checked {
				canvas.pixels[int(pos)].val = noise.noise_2d(i64(rand.uint64()), {f64(x), f64(y)})
				canvas.pixels[int(pos)].checked = true
			}

			//only increment if we have found a pixel that is unchecked
			if canvas.pixels[int(pos)].checked {
				fmt.printf("Pixel created!\n")
				x += 1
			}
			if x == WIDTH {
				y += 1
			}
			//canvas.pixels[idx][idx2] = 


			//Loop over each corner for every point in the grid
		}
	}
	endTime := rl.GetTime()

	totalTime := endTime - startTime
	fmt.printf("Generated in %.2f seconds!\n", totalTime)
	image = rl.GenImagePerlinNoise(CANVASWIDTH, CANVASHEIGHT, 0, 0, rand_uniform(0, 100))
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
		handle_input()
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
	if rl.IsKeyPressed(.R) {
		init_program()
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
	for y := 0; y < HEIGHT; y += 1 {
		for x := 0; x < WIDTH; x += 1 {
			pos := (y * x + x)
			rl.DrawPixel(i32(x), i32(y), rl.ColorFromHSV(0, 0, canvas.pixels[pos].val))
		}
	}
}
