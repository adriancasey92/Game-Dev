#+feature dynamic-literals
package main

import "core:fmt"
import "core:math"
import "core:slice"
import "core:sort"
import "core:strings"
import rl "vendor:raylib"

Vec2 :: rl.Vector2
Vec3 :: rl.Vector3

WINDOW_NAME :: "Quadtree"
WIDTH :: 1280
HEIGHT :: 960
BACKGROUND_COL :: rl.BLACK

PAUSE: bool
FIN: bool

QuadHead: ^Quad
nodeCapacity :: 4

Point :: struct {
	pos: Vec2,
}

Rect :: struct {
	posCentered:   Vec2,
	halfDimension: Vec2,
	posTrue:       rl.Rectangle,
}

Quad :: struct {
	boundary:  Rect,
	points:    [nodeCapacity]Point,
	numPoints: i32,
	northWest: ^Quad,
	northEast: ^Quad,
	southWest: ^Quad,
	southEast: ^Quad,
	isleaf:    bool,
}

//creates a new quad pointer, and returns it for adding a new quad to the quadtree
create_Quad :: proc(bound: Rect) -> ^Quad {
	fmt.printf("create_Quad!\n")
	n := new(Quad)
	n^ = {
		boundary  = bound,
		northWest = nil,
		northEast = nil,
		southWest = nil,
		southEast = nil,
	}
	n.isleaf = false
	n.numPoints = 0
	n.points[0] = {{-1, -1}}
	n.points[1] = {{-1, -1}}
	n.points[2] = {{-1, -1}}
	n.points[3] = {{-1, -1}}
	return n
}

//Random function
rand_uniform :: proc(min, max: f32) -> f32 {
	return min + (max - min) * f32(rl.GetRandomValue(0, 10000)) / 10000.0
}

//Random range function
randrange :: proc(max: i32) -> i32 {
	return rl.GetRandomValue(0, max - 1)
}

//head is a pointer to a pointer. This allows us to modify where head points to.
//for linked lists this is important as we need to be able to create new Quads,
//and then add them into the list, and re-address our head to the new Quad. 
init_program :: proc() {
	//fmt.printf("init_program()\n")
	QuadHead = nil
	QuadHead = create_Quad(
		Rect {
			{WIDTH / 2, HEIGHT / 2},
			{WIDTH / 2, HEIGHT / 2},
			calculate_from_centered_pos({WIDTH / 2, HEIGHT / 2}, {WIDTH / 2, HEIGHT / 2}),
		},
	)

	for i := 0; i < 1000; i += 1 {
		insertPoint(QuadHead, Point{{f32(randrange(WIDTH)), f32(randrange(HEIGHT))}})
	}
}

containsPoint :: proc(boundary: Rect, p: Point) -> bool {
	//if point is less than boundary width, or larger than boundary width
	b_topleft_x := boundary.posCentered.x - boundary.halfDimension.x
	b_topleft_y := boundary.posCentered.y - boundary.halfDimension.y

	b_botright_x := boundary.posCentered.x + boundary.halfDimension.x
	b_botright_y := boundary.posCentered.y + boundary.halfDimension.y

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

subdivide :: proc(quad: ^Quad) {
	//fmt.printf("subdivide!\n")
	quad.northWest = create_Quad(
		Rect {
			{
				quad.boundary.posCentered.x - quad.boundary.halfDimension.x / 2,
				quad.boundary.posCentered.y - quad.boundary.halfDimension.y / 2,
			},
			{quad.boundary.halfDimension.x / 2, quad.boundary.halfDimension.y / 2},
			calculate_from_centered_pos(
				{
					quad.boundary.posCentered.x - quad.boundary.halfDimension.x / 2,
					quad.boundary.posCentered.y - quad.boundary.halfDimension.y / 2,
				},
				{quad.boundary.halfDimension.x / 2, quad.boundary.halfDimension.y / 2},
			),
		},
	)

	quad.northEast = create_Quad(
		Rect {
			{
				quad.boundary.posCentered.x + quad.boundary.halfDimension.x / 2,
				quad.boundary.posCentered.y - quad.boundary.halfDimension.y / 2,
			},
			{quad.boundary.halfDimension.x / 2, quad.boundary.halfDimension.y / 2},
			calculate_from_centered_pos(
				{
					quad.boundary.posCentered.x + quad.boundary.halfDimension.x / 2,
					quad.boundary.posCentered.y - quad.boundary.halfDimension.y / 2,
				},
				{quad.boundary.halfDimension.x / 2, quad.boundary.halfDimension.y / 2},
			),
		},
	)

	quad.southWest = create_Quad(
		Rect {
			{
				quad.boundary.posCentered.x - quad.boundary.halfDimension.x / 2,
				quad.boundary.posCentered.y + quad.boundary.halfDimension.y / 2,
			},
			{quad.boundary.halfDimension.x / 2, quad.boundary.halfDimension.y / 2},
			calculate_from_centered_pos(
				{
					quad.boundary.posCentered.x - quad.boundary.halfDimension.x / 2,
					quad.boundary.posCentered.y + quad.boundary.halfDimension.y / 2,
				},
				{quad.boundary.halfDimension.x / 2, quad.boundary.halfDimension.y / 2},
			),
		},
	)
	quad.southEast = create_Quad(
		Rect {
			{
				quad.boundary.posCentered.x + quad.boundary.halfDimension.x / 2,
				quad.boundary.posCentered.y + quad.boundary.halfDimension.y / 2,
			},
			{quad.boundary.halfDimension.x / 2, quad.boundary.halfDimension.y / 2},
			calculate_from_centered_pos(
				{
					quad.boundary.posCentered.x + quad.boundary.halfDimension.x / 2,
					quad.boundary.posCentered.y + quad.boundary.halfDimension.y / 2,
				},
				{quad.boundary.halfDimension.x / 2, quad.boundary.halfDimension.y / 2},
			),
		},
	)
}

insertPoint :: proc(quad: ^Quad, point: Point) -> bool {
	//fmt.printf("insertPoint()\n")

	if !containsPoint(quad.boundary, point) {
		//fmt.printf("Cannot insert point\n")
		return false
	}

	//if we have less than the capacity for this quad, and our northwest quad isn't created yet
	if (quad.numPoints < nodeCapacity) && quad.northWest == nil {
		//fmt.printf("We can insert point here, trying now\n")
		//hopefully iterates over the points array, and assigns to the first 
		//point with a -1 x value
		quad.points[quad.numPoints] = point
		quad.numPoints += 1
		quad.isleaf = true
		return true
	}
	//fmt.printf("NumPoints: %i\n", quad.numPoints)
	//if we don't have room we subdivide
	if quad.northWest == nil {
		//fmt.printf("Subdividing now!\n")
		subdivide(quad)
		quad.isleaf = false
		for p in quad.points {
			if containsPoint(quad.northWest.boundary, p) {insertPoint(quad.northWest, p)}
			if containsPoint(quad.northEast.boundary, p) {insertPoint(quad.northEast, p)}
			if containsPoint(quad.southWest.boundary, p) {insertPoint(quad.southWest, p)}
			if containsPoint(quad.southEast.boundary, p) {insertPoint(quad.southEast, p)}
		}
	}

	//try to reassign points


	if insertPoint(quad.northWest, point) {return true}
	if insertPoint(quad.northEast, point) {return true}
	if insertPoint(quad.southWest, point) {return true}
	if insertPoint(quad.southEast, point) {return true}


	return false
}

reset :: proc() {

	free(QuadHead)
	init_program()
}

main :: proc() {
	//init program
	init_program()

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
		update()
		draw()
		free_all(context.temp_allocator)
	}
}

update :: proc() {
	if !PAUSE {
		handle_input()
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

	if rl.IsKeyPressed(.R) {
		init_program()
	}

	if rl.IsKeyPressed(.P) {
		print_points(QuadHead)
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

print_points :: proc(quadtree: ^Quad) {

	if quadtree.northWest != nil {
		print_points(quadtree.northWest)
	}
	if quadtree.northWest != nil {
		print_points(quadtree.northEast)
	}
	if quadtree.northWest != nil {
		print_points(quadtree.southWest)
	}
	if quadtree.northWest != nil {
		print_points(quadtree.southEast)
	}
	if quadtree.numPoints == 0 {
		return
	}

	for p in quadtree.points {
		//fmt.printf("Point x,y: %f,%f\n", p.pos.x, p.pos.y)
	}
	fmt.printf("\n")

}

draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(BACKGROUND_COL)

	//rl.DrawTexture(texture, i32(canvas.pos.x), i32(canvas.pos.y), rl.GRAY)
	drawQuadTree(QuadHead)
	//rl.EndMode2D()
	rl.EndDrawing()
}

calculate_from_centered_pos :: proc(centered_pos: Vec2, halfDimension: Vec2) -> rl.Rectangle {
	posX := centered_pos.x - halfDimension.x
	posY := centered_pos.y - halfDimension.y
	width := halfDimension.x * 2
	height := halfDimension.y * 2

	return rl.Rectangle{f32(posX), f32(posY), width, height}
}

drawQuadTree :: proc(quadtree: ^Quad) {
	//fmt.printf("drawing tree!\n")

	if quadtree.northWest != nil {
		drawQuadTree(quadtree.northWest)
	}
	if quadtree.northWest != nil {
		drawQuadTree(quadtree.northEast)
	}
	if quadtree.northWest != nil {
		drawQuadTree(quadtree.southWest)
	}
	if quadtree.northWest != nil {
		drawQuadTree(quadtree.southEast)
	}

	rl.DrawRectangleLinesEx(quadtree.boundary.posTrue, .5, rl.SKYBLUE)
	//finally draw points
	for p in quadtree.points {
		rl.DrawCircle(i32(p.pos.x), i32(p.pos.y), 2, rl.WHITE)
	}
	if quadtree.isleaf {
		rl.DrawText(
			rl.TextFormat("%i", quadtree.numPoints),
			i32(quadtree.boundary.posTrue.x + 5),
			i32(quadtree.boundary.posTrue.y + 5),
			5,
			rl.WHITE,
		)
	}
}
