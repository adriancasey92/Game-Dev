package game
import hm "../handle_map"
import "core:fmt"
import rl "vendor:raylib"

MAX_NODES :: 1024
MAX_ENTITIES_PER_QUAD :: 4
quad_size: i32
num_quads: i32

Quadtree :: struct {
	nodes:      [MAX_NODES]QuadtreeNode,
	node_count: i32,
}

QuadtreeNode :: struct {
	bounds:        EntityRect,
	entity_handle: [MAX_ENTITIES_PER_QUAD]Entity_Handle,
	entity_count:  i32,
	children:      [4]i32, // Indices into the node pool
	parent:        i32,
	has_children:  bool,
	depth:         i32,
}

//To use quadtree propery you will require the struct below to be declared in one of your files
//You will also require the handle_map package from Karl Zylinski for tracking entities,
//alternatively you can change Entity_Handle to another id-system if preferred. 
/*EntityRect :: struct {
	min, max: Vec2,
	pos:      Vec2,
}*/

// Checks if two rectangles overlap
rect_overlaps :: proc(a, b: EntityRect) -> bool {
	return a.min.x < b.max.x && a.max.x > b.min.x && a.min.y < b.max.y && a.max.y > b.min.y
}

//Initializes the root node and quadtree
init_quadtree :: proc(tree: ^Quadtree, QUAD_SIZE, NUM_QUADS: i32) {
	quad_size = QUAD_SIZE
	num_quads = NUM_QUADS
	total_level_size := QUAD_SIZE * NUM_QUADS
	root_bounds := EntityRect {
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

build_quadtree :: proc() {
	reset_quadtree()
	my_iter := hm.make_iter(&g.entities)
	for item, handle in hm.iter(&my_iter) {
		insert_entity(&quadtree, 0, handle, item.ent_rect)
	}
}

//resets the quadtree and rebuilds it
reset_quadtree :: proc() {
	//fmt.printf("Resetting quadtree\n")
	for i := 0; i < int(quadtree.node_count); i += 1 {
		//fmt.printf("Resetting node: %i\n", i)
		node := &quadtree.nodes[i]
		node.entity_count = 0
		node.has_children = false
	}
	if quad_size != 0 && num_quads != 0 {
		init_quadtree(&quadtree, quad_size, num_quads)
	} else {
		fmt.printf("ERR - quadsize and numquads not set!, Init Quadtree before calling reset!\n")
	}
}

compute_child_bounds :: proc(parent_bounds: EntityRect, index: i32) -> EntityRect {
	w := (parent_bounds.max.x - parent_bounds.min.x) / 2
	h := (parent_bounds.max.y - parent_bounds.min.y) / 2
	mid := Vec2{parent_bounds.min.x + w, parent_bounds.min.y + h}

	switch (index) 
	{
	case 0:
		return EntityRect{min = parent_bounds.min, max = mid}
	case 1:
		return EntityRect{min = {mid.x, parent_bounds.min.y}, max = {parent_bounds.max.x, mid.y}}
	case 2:
		return EntityRect{min = {parent_bounds.min.x, mid.y}, max = {mid.x, parent_bounds.max.y}}
	case 3:
		return EntityRect{min = mid, max = parent_bounds.max}
	}
	return parent_bounds
}

//Tree is the quadtree object
//node index is the current tree node we are trying to insert into
//entity id is the entity we are trying to insert
//entity bounds is the bounds of the entity we are trying to insert
//This function will insert the entity into the quadtree
insert_entity :: proc(
	tree: ^Quadtree,
	node_index: i32,
	entity_handle: Entity_Handle,
	entity_bounds: EntityRect,
) {
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
				insert_entity(tree, child_idx, entity_handle, entity_bounds)
				return
			}
		}
	}
	//fmt.printf("No children, checking if there's room\n")

	// Store entity if there's room
	if node.entity_count < MAX_ENTITIES_PER_QUAD {
		//fmt.printf("Inserting entity %i into node %i\n", entity_id, node_index)
		node.entity_handle[node.entity_count] = entity_handle
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
			if rect_overlaps(
				tree.nodes[child_idx].bounds,
				get_entity_bounds(node.entity_handle[i]),
			) {
				//fmt.printf("Child %i has entity %i\n", child_idx, node.entities_id[i])
				insert_entity(
					tree,
					child_idx,
					node.entity_handle[i],
					get_entity_bounds(entity_handle),
				)
				node.entity_handle[i] = node.entity_handle[node.entity_count - 1] // Remove entity from parent
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
	insert_entity(tree, node_index, entity_handle, entity_bounds)
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

get_entity_bounds :: proc(e: Entity_Handle) -> EntityRect {

	/*shipheight: f32

	if _, ok := e.type.(Entity_Player); ok {
		shipheight = PLAYER_SHIPHEIGHT
	} else if _, ok := e.type.(Entity_Enemy); ok {
		shipheight = ENEMY_BASIC_SHIPHEIGHT
	}
	*/
	return EntityRect{}
}

//Draw the quadtree node boundary
draw_quad_tree_node :: proc(quadTreeNode: QuadtreeNode) {
	rl.DrawText(
		rl.TextFormat("%i", quadTreeNode.entity_count),
		i32(quadTreeNode.bounds.min.x + 15),
		i32(quadTreeNode.bounds.min.y + 15),
		g.font.baseSize,
		rl.Fade(rl.WHITE, .8),
	)
	rl.DrawText(
		rl.TextFormat("%i", quadTreeNode.parent),
		i32(quadTreeNode.bounds.min.x + 15),
		i32(quadTreeNode.bounds.min.y + 45),
		g.font.baseSize,
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
draw_quad_tree :: proc(quadtree: ^Quadtree) {
	//fmt.printf("Drawing quadtree!\n")
	for i := 0; i < int(quadtree.node_count); i += 1 {
		if !quadtree.nodes[i].has_children {
			draw_quad_tree_node(quadtree.nodes[i])
		}
	}
}
