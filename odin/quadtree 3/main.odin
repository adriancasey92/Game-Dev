#+feature dynamic-literals
package main

import "core:fmt"
import "core:math"
import "core:mem"
import "core:slice"
import "core:sort"
import "core:strings"
import rl "vendor:raylib"

//Declare types
Vec2 :: rl.Vector2

//Constants
WIDTH :: 1280
HEIGHT :: 960
NUM_COLS: i32
NUM_ROWS: i32
CELL_SIZE :: 50
NUM_POINTS :: 150
POINT_VEL: f32
WINDOW_NAME :: "Quadtree 3"
CENTER :: Vec2{WIDTH / 2, HEIGHT / 2}

DEBUG_DRAW_QUADS: bool
DEBUG_DRAW_QUAD_POINT_NUM: bool

BACKGROUND_COL: rl.Color
PAUSE: bool
//Cameras
camera2D: rl.Camera2D

GameState :: enum {
	GAMEPLAY,
	ENDING,
}

Point :: struct {
	pos: Vec2,
	vel: Vec2,
}

QuadTree :: struct {
	boundary:  Rect,
	c_nodes:   [4]^QuadTree,
	points:    [MAX_OBJECTS]Point,
	isleaf:    bool,
	numPoints: i32,
}

Rect :: struct {
	pos_centered:   Vec2,
	half_dimension: Vec2,
	pos_true:       rl.Rectangle,
}

Player :: struct {
	rect: rl.Rectangle,
}

MAX_OBJECTS :: 2
QUAD_AREAS :: 4
MAX_DEPTH :: 5

points: [NUM_POINTS]Point

currentState: GameState
player: Player
quad_tree: QuadTree
QuadHead: ^QuadTree

//Random function 
random_uniform :: proc(min, max: f32) -> f32 {
	return min + (max - min) * f32(rl.GetRandomValue(0, 10000)) / 10000.0
}

//Random range function
randrange :: proc(max: i32) -> i32 {
	return rl.GetRandomValue(0, max - 1)
}

reset :: proc() {
	free(QuadHead)
	init_program()
}


rect_from_centered_pos :: proc(centered_pos: Vec2, halfDimension: Vec2) -> rl.Rectangle {
	posX := centered_pos.x - halfDimension.x
	posY := centered_pos.y - halfDimension.y
	width := halfDimension.x * 2
	height := halfDimension.y * 2

	return rl.Rectangle{f32(posX), f32(posY), width, height}
}


init_program :: proc() {
	fmt.printf("Init program:\n")
	BACKGROUND_COL = rl.BLACK
	currentState = .GAMEPLAY

	// DEBUG BOOLS
	if DEBUG_DRAW_QUAD_POINT_NUM == false {DEBUG_DRAW_QUAD_POINT_NUM = false}
	if DEBUG_DRAW_QUADS == false {DEBUG_DRAW_QUADS = false}

	POINT_VEL = .05
	player.rect = {CENTER.x, CENTER.y, 10, 10}
	NUM_COLS = WIDTH / CELL_SIZE
	NUM_ROWS = HEIGHT / CELL_SIZE


	for i := 0; i < NUM_POINTS; i += 1 {
		points[i] = Point {
			pos = {f32(randrange(WIDTH)), f32(randrange(HEIGHT))},
			vel = {
				random_uniform(POINT_VEL, POINT_VEL + .2),
				random_uniform(POINT_VEL, POINT_VEL + .2),
			},
		}
		insertPoint(QuadHead, points[i])
	}
}


create_quad :: proc(bound: Rect) -> ^QuadTree {
	n := new(QuadTree)
	n^ = {
		boundary = bound,
	}
	n.isleaf = false
	n.numPoints = 0
	for i := 0; i < MAX_OBJECTS; i += 1 {
		n.points[i] = Point {
			pos = {-1, -1},
		}
	}
	return n
}

containsPoint :: proc(boundary: Rect, p: Point) -> bool {
	//if point is less than boundary width, or larger than boundary width
	b_topleft_x := boundary.pos_centered.x - boundary.half_dimension.x
	b_topleft_y := boundary.pos_centered.y - boundary.half_dimension.y

	b_botright_x := boundary.pos_centered.x + boundary.half_dimension.x
	b_botright_y := boundary.pos_centered.y + boundary.half_dimension.y

	//outside our x vals
	if p.pos.x < b_topleft_x || p.pos.x > b_botright_x {
		//fmt.printf("p.x: p.%f Not inside xmin,xmax: %f,%f\n", p.pos.x, b_topleft_x, b_botright_x)
		return false
	}
	if p.pos.y < b_topleft_y || p.pos.y > b_botright_y {
		//fmt.printf("p.y: p.%f Not inside ymin,ymax: %f,%f\n", p.pos.y, b_topleft_y, b_botright_y)
		return false
	}
	return true
}

subdivide :: proc(quad: ^QuadTree) {
	//fmt.printf("subdivide!\n")
	quad.c_nodes[0] = create_quad(
		Rect {
			{
				quad.boundary.pos_centered.x - quad.boundary.half_dimension.x / 2,
				quad.boundary.pos_centered.y - quad.boundary.half_dimension.y / 2,
			},
			{quad.boundary.half_dimension.x / 2, quad.boundary.half_dimension.y / 2},
			rect_from_centered_pos(
				{
					quad.boundary.pos_centered.x - quad.boundary.half_dimension.x / 2,
					quad.boundary.pos_centered.y - quad.boundary.half_dimension.y / 2,
				},
				{quad.boundary.half_dimension.x / 2, quad.boundary.half_dimension.y / 2},
			),
		},
	)

	quad.c_nodes[1] = create_quad(
		Rect {
			{
				quad.boundary.pos_centered.x + quad.boundary.half_dimension.x / 2,
				quad.boundary.pos_centered.y - quad.boundary.half_dimension.y / 2,
			},
			{quad.boundary.half_dimension.x / 2, quad.boundary.half_dimension.y / 2},
			rect_from_centered_pos(
				{
					quad.boundary.pos_centered.x + quad.boundary.half_dimension.x / 2,
					quad.boundary.pos_centered.y - quad.boundary.half_dimension.y / 2,
				},
				{quad.boundary.half_dimension.x / 2, quad.boundary.half_dimension.y / 2},
			),
		},
	)

	quad.c_nodes[2] = create_quad(
		Rect {
			{
				quad.boundary.pos_centered.x - quad.boundary.half_dimension.x / 2,
				quad.boundary.pos_centered.y + quad.boundary.half_dimension.y / 2,
			},
			{quad.boundary.half_dimension.x / 2, quad.boundary.half_dimension.y / 2},
			rect_from_centered_pos(
				{
					quad.boundary.pos_centered.x - quad.boundary.half_dimension.x / 2,
					quad.boundary.pos_centered.y + quad.boundary.half_dimension.y / 2,
				},
				{quad.boundary.half_dimension.x / 2, quad.boundary.half_dimension.y / 2},
			),
		},
	)

	quad.c_nodes[3] = create_quad(
		Rect {
			{
				quad.boundary.pos_centered.x + quad.boundary.half_dimension.x / 2,
				quad.boundary.pos_centered.y + quad.boundary.half_dimension.y / 2,
			},
			{quad.boundary.half_dimension.x / 2, quad.boundary.half_dimension.y / 2},
			rect_from_centered_pos(
				{
					quad.boundary.pos_centered.x + quad.boundary.half_dimension.x / 2,
					quad.boundary.pos_centered.y + quad.boundary.half_dimension.y / 2,
				},
				{quad.boundary.half_dimension.x / 2, quad.boundary.half_dimension.y / 2},
			),
		},
	)

	// this should hopefully reassign points from parent quad to child nodes
	fmt.printf("quad.numPoints %i\n", quad.numPoints)
	for i := 0; i < int(quad.numPoints); i += 1 {
		for j := 0; j < QUAD_AREAS; j += 1 {
			//loop over every c_node
			if containsPoint(quad.c_nodes[j].boundary, quad.points[i]) {
				insertPoint(quad.c_nodes[j], quad.points[i])
			} else {
				fmt.printf("Couldn't reassign point!\n")
			}
		}
	}

	quad.numPoints = 0

}

insertPoint :: proc(quad: ^QuadTree, point: Point) -> bool {
	//fmt.printf("insertPoint()\n")

	if !containsPoint(quad.boundary, point) {
		//fmt.printf("Cannot insert point\n")
		return false
	}

	//if we have less than the capacity for this quad, and our northwest quad isn't created yet
	//fmt.printf("Quad points: %i\n", quad.numPoints)
	if (quad.numPoints < MAX_OBJECTS) && quad.c_nodes[0] == nil {
		//fmt.printf("We can insert point here, trying now\n")
		//hopefully iterates over the points array, and assigns to the first 
		//point with a -1 x value

		quad.points[quad.numPoints] = point
		quad.numPoints += 1
		quad.isleaf = true
		return true
	}

	quad.isleaf = false
	//fmt.printf("NumPoints: %i\n", quad.numPoints)
	//if we don't have room we subdivide
	if quad.c_nodes[0] == nil {
		fmt.printf("Subdividing now!\n")
		subdivide(quad)
	}

	//fmt.printf("QUAD POINTS SHOULD BE REASIGNED, CLEARING NOW\n")
	//quad.numPoints = 0

	//try to reassign points
	for i := 0; i < QUAD_AREAS; i += 1 {
		if insertPoint(quad.c_nodes[i], point) {return true}
	}


	return false
}

get_rand_dir :: proc() -> Vec2 {

	dir := Vec2{}
	num := randrange(4)

	switch (num) 
	{
	//left
	case 0:
		dir = {-1, 0}
	//right
	case 1:
		dir = {1, 0}
	//up
	case 2:
		dir = {0, 1}
	//down
	case 3:
		dir = {0, -1}
	}

	return dir

}

rebuild_tree :: proc() {

	for &p in points {
		dir := get_rand_dir()
		p.pos += p.vel


		//right wall
		if p.pos.x > WIDTH {
			p.pos.x = WIDTH
			p.pos += Vec2{-1, 0}
		}
		//left wall
		if p.pos.x < 0 {
			p.pos.x = 0
			p.pos += Vec2{1, 0}
		}

		//top wall
		if p.pos.y < 0 {
			p.pos.y = 0
			p.pos += Vec2{0, 1}
		}
		//bottom wall
		if p.pos.y > HEIGHT {
			p.pos.y = HEIGHT
			p.pos += Vec2{0, -1}
		}

		if !insertPoint(QuadHead, p) {
			fmt.printf("ERR: COULDN'T INSERT POINT\n")
		}
	}
}


main :: proc() {
	//MEMORY ALLOCATOR 
	default_allocator := context.allocator
	tracking_allocator: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracking_allocator, default_allocator)
	context.allocator = mem.tracking_allocator(&tracking_allocator)

	reset_tracking_allocator :: proc(a: ^mem.Tracking_Allocator) -> bool {
		err := false

		for _, value in a.allocation_map {
			fmt.printf("%v: Leaked %v bytes\n", value.location, value.size)
			err = true
		}

		mem.tracking_allocator_clear(a)
		return err
	}

	//create quadTree 
	quad_tree := QuadTree {
		boundary = Rect {
			pos_centered = {WIDTH / 2, HEIGHT / 2},
			pos_true = rl.Rectangle{0, 0, WIDTH, HEIGHT},
		},
		c_nodes = nil,
		numPoints = 0,
		isleaf = false,
		points = {},
	}
	//assign pointer
	QuadHead = &quad_tree
	defer (free(QuadHead))

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
		fmt.printf("Current state: %s\n", currentState)
		handle_input()
		update()
		draw()
		free_all(context.temp_allocator)
	}
	rl.CloseWindow()

	//to check for leaks and bad frees
	reset_tracking_allocator(&tracking_allocator)
}

update_gameplay :: proc() {
	if !PAUSE {
		rebuild_tree()
	}
}

update :: proc() {
	#partial switch (currentState) {
	case .GAMEPLAY:
		update_gameplay()
	//Make sure we can pause/unpause
	}
}

handle_input_gameplay :: proc() {


	if rl.IsKeyPressed(.P) {PAUSE = !PAUSE}
	if rl.IsKeyPressed(.F2) {
		DEBUG_DRAW_QUADS = !DEBUG_DRAW_QUADS
		DEBUG_DRAW_QUAD_POINT_NUM = !DEBUG_DRAW_QUAD_POINT_NUM
	}

	if rl.IsKeyDown(.W) {player.rect.y -= 2}
	if rl.IsKeyDown(.S) {player.rect.y += 2}
	if rl.IsKeyDown(.A) {player.rect.x -= 2}
	if rl.IsKeyDown(.D) {player.rect.x += 2}
	if rl.IsKeyPressed(.R) {reset()}
	if rl.IsMouseButtonPressed(
		.LEFT,
	) {insertPoint(QuadHead, Point{pos = {f32(randrange(WIDTH)), f32(randrange(HEIGHT))}})}
}

handle_input :: proc() {
	switch (currentState) {
	case .GAMEPLAY:
		handle_input_gameplay()
	case .ENDING:
		if rl.IsKeyPressed(.ENTER) {
			currentState = .GAMEPLAY
		}
	}
}

draw_quad_tree :: proc(quadtree: ^QuadTree) {
	//fmt.printf("drawing tree!\n")

	for i := 0; i < QUAD_AREAS; i += 1 {
		if quadtree.c_nodes[i] != nil {
			draw_quad_tree(quadtree.c_nodes[i])
		}
	}

	if DEBUG_DRAW_QUADS {
		rl.DrawRectangleLinesEx(quadtree.boundary.pos_true, .5, rl.SKYBLUE)
	}
	//finally draw points
	for p in quadtree.points {
		rl.DrawCircle(i32(p.pos.x), i32(p.pos.y), 2, rl.WHITE)
	}

	if quadtree.isleaf {
		if DEBUG_DRAW_QUAD_POINT_NUM {
			rl.DrawText(
				rl.TextFormat("%i", quadtree.numPoints),
				i32(quadtree.boundary.pos_true.x + 5),
				i32(quadtree.boundary.pos_true.y + 5),
				5,
				rl.WHITE,
			)
		}
	}
}

draw_game :: proc() {
	rl.DrawCircle(i32(player.rect.x), i32(player.rect.y), player.rect.width / 2, rl.RED)
	draw_quad_tree(QuadHead)
}

draw_credits :: proc() {

}

draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(BACKGROUND_COL)

	switch (currentState) {
	case .GAMEPLAY:
		draw_game()
	case .ENDING:
		draw_credits()
	}

	//rl.EndMode2D()
	rl.EndDrawing()
}
