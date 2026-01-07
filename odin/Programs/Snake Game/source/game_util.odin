package game
import "core:fmt"
import "core:math/linalg"

// Resolves a pos and size to a Rect 
pos_to_rect :: proc(pos, size: Vec2) -> Rect {
	return {pos.x, pos.y, size.x, size.y}
}

// Used to generate corners for platforms r collision
get_rect_corners :: proc(rect: Rect) -> [4]Rect {
	c: [4]Rect
	size: f32
	size = 2
	//top left, top right, bottom right, bottom left
	//y value is offeset by 1 to ensure player colliders can collide with 
	// the corners
	c[0] = {rect.x - 1, rect.y - 1, size, size}
	c[1] = {rect.x + (rect.width - size) + 1, rect.y - 1, size, size}
	c[2] = {rect.x - 1, rect.y + (rect.height - size) + 1, size, size}
	c[3] = {rect.x + rect.width - size + 1, rect.y + rect.height - size / 2, size, size}
	return c
}

get_rect_faces :: proc(rect: Rect) -> [4]Rect {
	f: [4]Rect
	size: f32
	size = 1
	//top left, top right, bottom right, bottom left
	//y value is offeset by 1 to ensure player colliders can collide with 
	// the corners
	f[0] = {rect.x, rect.y, rect.width, size}
	f[1] = {rect.x + rect.width, rect.y, size, rect.height}
	f[2] = {rect.x, rect.y + rect.height, rect.width, size}
	f[3] = {rect.x, rect.y, size, rect.height}
	return f
}

// This returns a position offset by the width of the object to center the drawing
// of the object relative to the position given.
centered_pos_from_offset :: proc(pos: Vec2, size: Vec2) -> Vec2 {
	return {pos.x - (size.x / 2), pos.y}
}

//calculates the position based on start and end point and a given length
//P = (1-t)A + tB
//P is the return point
//A and B are given points
// t is the length
calc_point :: proc(mp, origin: Vec2, length: i32) -> Vec2 {
	// Calculate direction vector between two points
	dir := Vec2{mp.x - origin.x, mp.y - origin.y}

	// Normalize the direction vector
	length_dir := linalg.length(dir)
	if length_dir == 0 {
		fmt.printf("game_util.calc_point: length_dir is 0, returning origin\n")
		return origin
	}
	dir = dir / length_dir

	// Calculate point at given length along direction
	return Vec2{origin.x + (dir.x * f32(length)), origin.y + (dir.y * f32(length))}
}
