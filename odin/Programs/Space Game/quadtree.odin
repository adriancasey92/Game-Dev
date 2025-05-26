package main
import "core:fmt"
import "core:math"
import rl "vendor:raylib"

//CONSTANTS
MAX_ENTITIES_PER_QUAD :: 8
MAX_OBJECTS :: 8
MAX_NODES :: 1024
QUAD_AREAS :: 4
MAX_DEPTH :: 5
FONT_SIZE :: 20

// Global variables
size_in_pixels: int
size_in_quads: int

// Structs
Vec2 :: rl.Vector2
Rect :: struct {
	min: Vec2,
	max: Vec2,
}

Quadtree :: struct {
	nodes:      [MAX_NODES]QuadtreeNode, // Flat array of nodes
	node_count: i32, // Keeps track of the next available node index
}

QuadtreeNode :: struct {
	bounds:        Rect,
	entities_id:   [MAX_ENTITIES_PER_QUAD]i32,
	entities_rect: [MAX_ENTITIES_PER_QUAD]Rect,
	entity_count:  i32,
	children:      [4]i32, // Indices into the node pool
	parent:        i32,
	has_children:  bool,
	depth:         i32,
}

// Checks if two rectangles overlap
rect_overlaps :: proc(a, b: Rect) -> bool {
	return a.min.x < b.max.x && a.max.x > b.min.x && a.min.y < b.max.y && a.max.y > b.min.y
}

// FUNCTIONS
init_quadtree :: proc(tree: ^Quadtree, quad_pixel_size: int, num_quads: int) {

	//Store these for later
	size_in_pixels = quad_pixel_size
	size_in_quads = num_quads

	total_level_size := size_in_pixels * size_in_quads
	root_bounds := Rect {
		min = {f32(0 - (total_level_size / 2)), f32(0 - (total_level_size / 2))},
		max = {f32((total_level_size / 2)), f32((total_level_size / 2))},
	}
	//	fmt.printf("bounds pos: %v,%v\n", root_bounds.min, root_bounds.max)

	tree.node_count = 1
	tree.nodes[0].depth = 1
	tree.nodes[0] = QuadtreeNode {
		bounds       = root_bounds,
		entity_count = 0,
		has_children = false,
		parent       = -1,
	}
}

reset_quadtree :: proc(tree: ^Quadtree) {
	//fmt.printf("Resetting quadtree\n")
	for i := 0; i < int(tree.node_count); i += 1 {
		//fmt.printf("Resetting node: %i\n", i)
		node := &tree.nodes[i]
		node.entity_count = 0
		node.has_children = false
	}

	init_quadtree(tree, size_in_pixels, size_in_quads)
}

//Tree is the quadtree object
//node index is the current tree node we are trying to insert into
//entity id is the entity we are trying to insert
//entity bounds is the bounds of the entity we are trying to insert
//This function will insert the entity into the quadtree
insert_entity :: proc(tree: ^Quadtree, node_index: i32, entity_id: i32, entity_bounds: Rect) {
	//current node
	node := &tree.nodes[node_index]
	// If already subdivided, pass entity to children

	//fmt.printf("insert_entity(%i) - :%v\n", entity_id, entity_bounds)
	if node.has_children {
		//fmt.printf("Node has children, passing off!\n")
		for i := 0; i < 4; i += 1 {
			child_idx := node.children[i]
			if rect_overlaps(tree.nodes[child_idx].bounds, entity_bounds) {
				/*fmt.printf(
					"Child bound %v \noverlaps with entity %i\n",
					tree.nodes[child_idx].bounds,
					entity_bounds,
				)*/
				insert_entity(tree, child_idx, entity_id, entity_bounds)
				return
			}
		}
	}
	//fmt.printf("No children, checking if there's room\n")

	// Store entity if there's room
	if node.entity_count < MAX_ENTITIES_PER_QUAD {
		//fmt.printf("Inserting entity %i into node %i\n", entity_id, node_index)
		node.entities_id[node.entity_count] = entity_id
		node.entities_rect[node.entity_count] = entity_bounds
		node.entity_count += 1
		return
	}
	//fmt.printf("Node is full, need to subdivide\n")
	// Subdivide if needed
	if !node.has_children {
		//fmt.printf("Subdividing node: %i\n", node_index)
		subdivide(tree, node_index)
	}

	// Reassign entities to children
	i := 0
	//loop over parent entities
	//fmt.printf("Reassigning entities to children\n")
	for i < int(node.entity_count) {
		//check children of parent node for overlap with entity
		/*fmt.printf(
			"Reassigning entity %i, pos: %v:\n",
			node.entities_id[i],
			get_entity_bounds(ENTITIES[node.entities_id[i]]),
		)*/
		for j := 0; j < 4; j += 1 {
			child_idx := node.children[j]
			//fmt.printf("Checking child %i, %v:\n", child_idx, tree.nodes[child_idx].bounds)
			if rect_overlaps(tree.nodes[child_idx].bounds, node.entities_rect[i]) {
				//fmt.printf("Child %i has entity %i\n", child_idx, node.entities_id[i])
				insert_entity(tree, child_idx, node.entities_id[i], node.entities_rect[i])
				node.entities_id[i] = node.entities_id[node.entity_count - 1] // Remove entity from parent
				node.entities_rect[i] = node.entities_rect[node.entity_count - 1]
				node.entity_count -= 1
				i -= 1
				break
			} else {
				//fmt.printf("Child %i does not have entity %i\n", child_idx, node.entities_id[i])
			}
		}
		i += 1
	}
	// Insert the new entity
	insert_entity(tree, node_index, entity_id, entity_bounds)
}

subdivide :: proc(tree: ^Quadtree, node_index: i32) {
	if tree.node_count + 4 >= MAX_NODES {
		fmt.printf("Subdivide - max nodes reached\n")
		return // Prevent overflow
	}

	node := &tree.nodes[node_index]
	for i := 0; i < 4; i += 1 {
		child_idx := tree.node_count
		tree.node_count += 1
		tree.nodes[child_idx] = QuadtreeNode {
			bounds       = compute_child_bounds(node.bounds, i32(i)),
			entity_count = 0,
			has_children = false,
			parent       = node_index,
		}
		//fmt.printf("Child %i bounds: %v\n", i, tree.nodes[child_idx].bounds)

		node.children[i] = child_idx
	}

	node.has_children = true
}

// Finds the index of the node containing the entity with the given ID
find_entity_quad :: proc(tree: ^Quadtree, id: i32) -> i32 {
	for i := 0; i < int(tree.node_count); i += 1 {
		node := &tree.nodes[i]
		for j := 0; j < int(node.entity_count); j += 1 {
			if node.entities_id[j] == id {
				return i32(i)
			}
		}
	}
	return -1
}

compute_child_bounds :: proc(parent_bounds: Rect, index: i32) -> Rect {
	//if xmin =  and xmax = 1250
	//w = 1250 - (-1250) / 2 = 1250 + 1250 / 2 = 1250
	//h = 1250 - (-1250) / 2 = 1250 + 1250 / 2 = 1250
	w := (parent_bounds.max.x - parent_bounds.min.x) / 2
	//fmt.printf("W: %f\n", w)
	h := (parent_bounds.max.y - parent_bounds.min.y) / 2
	//fmt.printf("H: %f\n", h)
	mid := Vec2{parent_bounds.min.x + w, parent_bounds.min.y + h}
	//fmt.printf("Mid: %v\n", mid)

	switch (index) 
	{
	case 0:
		return Rect{min = parent_bounds.min, max = mid}
	case 1:
		return Rect{min = {mid.x, parent_bounds.min.y}, max = {parent_bounds.max.x, mid.y}}
	case 2:
		return Rect{min = {parent_bounds.min.x, mid.y}, max = {mid.x, parent_bounds.max.y}}
	case 3:
		return Rect{min = mid, max = parent_bounds.max}
	}

	fmt.printf("Returning parent bounds\n")
	return parent_bounds
}


// Queries the quadtree for entities within the given bounds
// Returns the number of entities found in the result array
query_quadtree :: proc(
	tree: ^Quadtree,
	node_index: i32,
	query_bounds: Rect,
	result: ^[MAX_ENTITIES_PER_QUAD]i32,
	result_count: ^i32,
) {
	node := &tree.nodes[node_index]

	if !rect_overlaps(node.bounds, query_bounds) {
		return
	}

	// Add entities in the current node
	for i := 0; i < int(node.entity_count); i += 1 {
		result[result_count^] = node.entities_id[i]
		result_count^ += 1
	}

	// Recursively check children
	if node.has_children {
		for i := 0; i < 4; i += 1 {
			query_quadtree(tree, node.children[i], query_bounds, result, result_count)
		}
	}
}

//Draw the quadtree node boundary
draw_quad_tree_node :: proc(quadTreeNode: QuadtreeNode) {
	rl.DrawText(
		rl.TextFormat("%i", quadTreeNode.entity_count),
		i32(quadTreeNode.bounds.min.x + 15),
		i32(quadTreeNode.bounds.min.y + 15),
		FONT_SIZE,
		rl.Fade(rl.WHITE, .8),
	)
	rl.DrawText(
		rl.TextFormat("%i", quadTreeNode.parent),
		i32(quadTreeNode.bounds.min.x + 15),
		i32(quadTreeNode.bounds.min.y + 45),
		FONT_SIZE,
		rl.Fade(rl.WHITE, .8),
	)
	rl.DrawRectangleLines(
		i32(quadTreeNode.bounds.min.x),
		i32(quadTreeNode.bounds.min.y),
		i32(quadTreeNode.bounds.max.x - quadTreeNode.bounds.min.x),
		i32(quadTreeNode.bounds.max.y - quadTreeNode.bounds.min.y),
		rl.SKYBLUE,
	)
}

//Draw the quadtree nodes boundary 
draw_quad_tree :: proc(tree: ^Quadtree) {
	for i := 0; i < int(tree.node_count); i += 1 {
		if !tree.nodes[i].has_children {
			draw_quad_tree_node(tree.nodes[i])
		}
	}
}
