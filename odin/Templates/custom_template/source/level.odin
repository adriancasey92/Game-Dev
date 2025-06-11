package game

import rl "vendor:raylib"
import "core:fmt"
import "core:math"
import "core:time"
import "core:bytes"
import "core:encoding/json"
import "core:os"

// Binary file format constants
COLLISION_CHUNK_VERSION :: 1
VISUAL_CHUNK_VERSION :: 1

Level :: struct {
	//always loaded
	collision_map:         map[ChunkCoord]Collision_Chunk,
	//dynamically loaded visual content
	active_chunks:         map[ChunkCoord]Visual_Chunk,
	//level metadata
	world_bounds:          struct {
		min_chunk, max_chunk: ChunkCoord,
	},

	//player tracking
	player_chunk:          ChunkCoord,
	player_pos:            Vec2,

	//performance tracking
	last_chunk_update:     f64,
	chunk_update_interval: f64,
}

//Uses json for development and binary on release
USE_BINARY_FORMAT :: #config(RELEASE, false) // Binary in release, JSON in debug

CHUNK_SIZE :: 32
TILE_SIZE :: 16
CHUNKS_ABOVE :: 2
CHUNKS_BELOW :: 3
VISUAL_UNLOAD_DISTANCE_IN_CHUNKS :: 5

ChunkCoord :: struct {
	x, y: i32,
}

Decoration :: struct {
	pos:    Vec2,
	sprite: Sprite_ID,
	layer:  i32,
}

Tile_Type :: enum u8 {
	EMPTY    = 0,
	SOLID    = 1,
	PLATFORM = 2,
	SPIKE    = 3,
	LADDER   = 4,
}

Sprite_ID :: enum u32 {
	NONE         = 0,
	GRASS_TILE   = 1,
	STONE_TILE   = 2,
	SPIKE_SPRITE = 3,
}

// Chunk structures
Collision_Chunk :: struct {
	tiles:    [CHUNK_SIZE][CHUNK_SIZE]Tile_Type,
	has_data: bool,
}

Visual_Chunk :: struct {
	coord_x: i32,
	coord_y: i32,
	sprites:          [CHUNK_SIZE][CHUNK_SIZE]Sprite_ID,
	entities:         [dynamic]Entity,
	decorations:      [dynamic]Decoration,
	last_access_time: f64,
	is_dirty:         bool, // Needs to be saved
}

//Chunks are 'stages' for each level. 
//Camera will be centered on the chunk, and the chunk will be drawn
//in the center of the screen.
Level_Chunk :: struct {
	camera_pos: Vec2,
	platforms:  []Platform,
}

// JSON structures for serialization
JSON_Collision_Chunk :: struct {
	chunk_x: i32,
	chunk_y: i32,
	tiles:   [CHUNK_SIZE][CHUNK_SIZE]u8, // Store as numbers for JSON
}

JSON_Entity :: struct {
	pos:       [2]f32,
	vel:       [2]f32,
	sprite:u32,
}

JSON_Decoration :: struct {
	pos: [2]f32,
	sprite:   u32,
	layer:    i32,
}

JSON_Visual_Chunk :: struct {
	coord_x:     i32,
	coord_y:     i32,
	sprites:     [CHUNK_SIZE][CHUNK_SIZE]u32,
	entities:    []JSON_Entity,
	decorations: []JSON_Decoration,
}


init_level :: proc(level: ^Level) {
	level.collision_map = make(map[ChunkCoord]Collision_Chunk)
	level.active_chunks = make(map[ChunkCoord]Visual_Chunk)
	level.chunk_update_interval = 0.1 // Update chunks 10 times per second

	// Set world bounds (example: 1 chunk wide, 20 chunks tall)
	level.world_bounds.min_chunk = {0, 0}
	level.world_bounds.max_chunk = {0, 19}
}

//Fade draws the level with a fade
draw_level :: proc(fade: f32) {
	/*// Draw platforms
	for p, idx in level.platforms {
		if p.exists {
			rl.DrawTextureRec(g.atlas, p.texture_rect, p.pos, rl.Fade(rl.WHITE, fade))
			if DEBUG_DRAW {
				rl.DrawRectangleLinesEx(p.pos_rect, 1, rl.Fade(rl.RED, fade))
				//text position
				text := rl.TextFormat("%.2f, %.2f", p.pos.x, p.pos.y)
				//text_size := rl.MeasureTextEx(rl.GetFontDefault(), text, 5, 2)

				draw_text_centered(
					text,
					i32(p.pos.x + p.pos_rect.width / 2),
					i32(p.pos.y + p.pos_rect.height / 2),
					5,
					rl.Fade(rl.RED, fade),
				)
				/*rl.DrawTextEx(
				rl.GetFontDefault(),
				text,
				{
					p.pos.x + (p.size_vec2.x / 2) - (text_size.x / 2),
					p.pos.y + (p.size_vec2.y / 2) - (text_size.y / 2),
				},
				5,
				2,
				rl.Fade(rl.RED, fade),
			)*/
			}
			if DEBUG_DRAW_COLLIDERS {
				for c, c_idx in p.corners {
					rl.DrawRectangleLinesEx(c, 1, rl.YELLOW)
					draw_text_centered(
						rl.TextFormat("%i,%i", idx, c_idx),
						i32(c.x),
						i32(c.y),
						4,
						rl.BLACK,
					)
				}
				for f in p.faces {
					rl.DrawRectangleLinesEx(f, 1, rl.PURPLE)
				}
			}
		}
	}*/
}

load_collision_chunk :: proc(coord: ChunkCoord) -> Collision_Chunk {
	when USE_BINARY_FORMAT {
		return load_collision_chunk_from_binary(coord)
	} else {
		return load_collision_chunk_from_json(coord)
	}
}

// Coordinate conversion utilities
world_pos_to_chunk :: proc(world_pos: [2]f32) -> ChunkCoord {
	chunk_size_world := f32(CHUNK_SIZE * TILE_SIZE)
	return {
		i32(math.floor(world_pos.x / chunk_size_world)),
		i32(math.floor(world_pos.y / chunk_size_world)),
	}
}

chunk_to_world_pos :: proc(chunk: ChunkCoord) -> [2]f32 {
	chunk_size_world := f32(CHUNK_SIZE * TILE_SIZE)
	return {f32(chunk.x) * chunk_size_world, f32(chunk.y) * chunk_size_world}
}

//for collision 
get_tile_in_world :: proc(level: ^Level, world_pos: [2]f32) -> Tile_Type {
	chunk_coord := world_pos_to_chunk(world_pos)

	// Check if collision chunk exists
	collision_chunk, chunk_exists := &level.collision_map[chunk_coord]
	if !chunk_exists || !collision_chunk.has_data {
		return .EMPTY
	}

	// Convert to local tile coordinates within chunk
	chunk_world_pos := chunk_to_world_pos(chunk_coord)
	local_pos := world_pos - chunk_world_pos

	tile_x := i32(local_pos.x / TILE_SIZE)
	tile_y := i32(local_pos.y / TILE_SIZE)

	// Bounds check
	if tile_x < 0 || tile_x >= CHUNK_SIZE || tile_y < 0 || tile_y >= CHUNK_SIZE {
		return .EMPTY
	}

	return collision_chunk.tiles[tile_y][tile_x]
}

// Collision chunk management
ensure_collision_chunk_loaded :: proc(level: ^Level, coord: ChunkCoord) {
	if coord in level.collision_map {
		return
	}

	// Check bounds
	if coord.x < level.world_bounds.min_chunk.x ||
	   coord.x > level.world_bounds.max_chunk.x ||
	   coord.y < level.world_bounds.min_chunk.y ||
	   coord.y > level.world_bounds.max_chunk.y {
		return
	}

	// Load collision data (you'd replace this with actual file loading)
	chunk := load_collision_chunk_from_disk(coord)
	level.collision_map[coord] = chunk

	fmt.printf("Loaded collision chunk (%d, %d)\n", coord.x, coord.y)
}

// Visual chunk management
load_visual_chunk :: proc(level: ^Level, coord: ChunkCoord, current_time: f64) {
	if coord in level.active_chunks {
		// Update access time
		chunk := &level.active_chunks[coord]
		chunk.last_access_time = current_time
		return
	}

	// Check bounds
	if coord.x < level.world_bounds.min_chunk.x ||
	   coord.x > level.world_bounds.max_chunk.x ||
	   coord.y < level.world_bounds.min_chunk.y ||
	   coord.y > level.world_bounds.max_chunk.y {
		return
	}

	// Load visual data
	visual_chunk := load_visual_chunk_from_disk(coord)
	visual_chunk.last_access_time = current_time
	level.active_chunks[coord] = visual_chunk

	fmt.printf("Loaded visual chunk (%d, %d)\n", coord.x, coord.y)
}

unload_distant_visual_chunks :: proc(level: ^Level, player_chunk: ChunkCoord, current_time: f64) {
	chunks_to_remove := make([dynamic]ChunkCoord, context.temp_allocator)

	for coord, chunk in level.active_chunks {
		// Calculate Manhattan distance
		distance := abs(coord.x - player_chunk.x) + abs(coord.y - player_chunk.y)

		if distance > VISUAL_UNLOAD_DISTANCE_IN_CHUNKS {
			// Save chunk if dirty before unloading
			if chunk.is_dirty {
				save_visual_chunk_to_disk(coord, chunk)
			}

			append(&chunks_to_remove, coord)
		}
	}

	// Remove distant chunks
	for coord in chunks_to_remove {
		delete_key(&level.active_chunks, coord)
		fmt.printf("Unloaded visual chunk (%d, %d)\n", coord.x, coord.y)
	}
}

// Main chunk management update
update_chunks :: proc(game_memory: ^Game_Memory) {
	level := &game_memory.level
	current_time := game_memory.current_time

	// Skip update if not enough time has passed
	if current_time - level.last_chunk_update < level.chunk_update_interval {
		return
	}
	level.last_chunk_update = current_time

	// Update player chunk
	level.player_chunk = world_pos_to_chunk(level.player_pos)

	// Ensure collision chunks are loaded in a radius around player
	for dy in -CHUNKS_BELOW ..< CHUNKS_ABOVE {
		for dx in -1 ..< 1 { 	// Assuming narrow vertical levels
			chunk_coord := ChunkCoord {
				level.player_chunk.x + i32(dx),
				level.player_chunk.y + i32(dy),
			}
			ensure_collision_chunk_loaded(level, chunk_coord)
		}
	}

	// Load visual chunks near player
	for dy in -2 ..< 2 {
		for dx in -1 ..< 1 {
			chunk_coord := ChunkCoord {
				level.player_chunk.x + i32(dx),
				level.player_chunk.y + i32(dy),
			}
			load_visual_chunk(level, chunk_coord, current_time)
		}
	}

	// Handle fast falling - predictive loading
	player := get_player()
	player_velocity_y := player.vel.y
	if player_velocity_y > 500.0 { 	// Falling fast (positive y = down)
		predicted_chunks := i32(abs(player_velocity_y) / f32(CHUNK_SIZE * TILE_SIZE))

		for i in i32(1) ..< predicted_chunks {
			chunk_coord := ChunkCoord{level.player_chunk.x, level.player_chunk.y - i}
			ensure_collision_chunk_loaded(level, chunk_coord)
			load_visual_chunk(level, chunk_coord, current_time)
		}
	}

	//Unload distant visual chunks
	unload_distant_visual_chunks(level, level.player_chunk, current_time)
}

// File paths
get_collision_chunk_path :: proc(coord: ChunkCoord) -> string {
	return fmt.aprintf("data/chunks/collision/chunk_%d_%d.dat", coord.x, coord.y)
}

get_visual_chunk_path :: proc(coord: ChunkCoord) -> string {
	return fmt.aprintf("data/chunks/visual/chunk_%d_%d.dat", coord.x, coord.y)
}

// Binary collision chunk format:
// [4 bytes: version] [4 bytes: chunk_x] [4 bytes: chunk_y] [1024 bytes: tile data]
load_collision_chunk_from_disk :: proc(coord: ChunkCoord) -> Collision_Chunk {
	chunk := Collision_Chunk {
		has_data = false,
	}

	filepath := get_collision_chunk_path(coord)
	defer delete(filepath)

	// Try to read binary file
	data, read_ok := os.read_entire_file(filepath)
	if !read_ok {
		fmt.printf("Could not read collision chunk file: %s\n", filepath)
		return generate_default_collision_chunk(coord)
	}
	defer delete(data)

	if len(data) < 12 + CHUNK_SIZE * CHUNK_SIZE {
		fmt.printf("Invalid collision chunk file size: %s\n", filepath)
		return generate_default_collision_chunk(coord)
	}

	// Read header
	reader := bytes.Reader {
		s = data,
	}

	version := (cast(^i32)&data[0])^
	chunk_x := (cast(^i32)&data[4])^
	chunk_y := (cast(^i32)&data[8])^

	// Verify chunk coordinates match
	if chunk_x != coord.x || chunk_y != coord.y {
		fmt.printf("Chunk coordinate mismatch in file: %s\n", filepath)
		return generate_default_collision_chunk(coord)
	}

	// Copy tile data directly
	tile_data_start := 12
	for y in 0 ..< CHUNK_SIZE {
		for x in 0 ..< CHUNK_SIZE {
			idx := tile_data_start + y * CHUNK_SIZE + x
			chunk.tiles[y][x] = cast(Tile_Type)data[idx]
		}
	}

	chunk.has_data = true
	fmt.printf("Loaded collision chunk (%d, %d) from binary file\n", coord.x, coord.y)
	return chunk
}

// JSON file paths
get_collision_chunk_json_path :: proc(coord: ChunkCoord) -> string {
	return fmt.aprintf("data/chunks/collision/chunk_%d_%d.json", coord.x, coord.y)
}

get_visual_chunk_json_path :: proc(coord: ChunkCoord) -> string {
	return fmt.aprintf("data/chunks/visual/chunk_%d_%d.json", coord.x, coord.y)
}

// JSON loading functions (use these instead of binary if you prefer JSON)
load_collision_chunk_from_json :: proc(coord: ChunkCoord) -> Collision_Chunk {
	chunk := Collision_Chunk {
		has_data = false,
	}

	filepath := get_collision_chunk_json_path(coord)
	defer delete(filepath)

	data, read_ok := os.read_entire_file(filepath)
	if !read_ok {
		fmt.printf("Could not read collision chunk JSON: %s\n", filepath)
		return generate_default_collision_chunk(coord)
	}
	defer delete(data)

	// Parse JSON
	json_chunk: JSON_Collision_Chunk
	parse_error := json.unmarshal(data, &json_chunk)
	if parse_error != nil {
		fmt.printf("Failed to parse collision chunk JSON: %s, error: %v\n", filepath, parse_error)
		return generate_default_collision_chunk(coord)
	}

	// Verify coordinates
	if json_chunk.chunk_x != coord.x || json_chunk.chunk_y != coord.y {
		fmt.printf("Collision chunk coordinate mismatch in JSON: %s\n", filepath)
		return generate_default_collision_chunk(coord)
	}

	// Convert data
	for y in 0 ..< CHUNK_SIZE {
		for x in 0 ..< CHUNK_SIZE {
			chunk.tiles[y][x] = cast(Tile_Type)json_chunk.tiles[y][x]
		}
	}

	chunk.has_data = true
	fmt.printf("Loaded collision chunk (%d, %d) from JSON\n", coord.x, coord.y)
	return chunk
}

load_visual_chunk_from_json :: proc(coord: ChunkCoord) -> Visual_Chunk {
	chunk := Visual_Chunk {
		entities    = make([dynamic]Entity),
		decorations = make([dynamic]Decoration),
		is_dirty    = false,
	}

	filepath := get_visual_chunk_json_path(coord)
	defer delete(filepath)

	data, read_ok := os.read_entire_file(filepath)
	if !read_ok {
		fmt.printf("Could not read visual chunk JSON: %s\n", filepath)
		return generate_default_visual_chunk(coord)
	}
	defer delete(data)

	// Parse JSON
	json_chunk: JSON_Visual_Chunk
	parse_error := json.unmarshal(data, &json_chunk)
	if parse_error != nil {
		fmt.printf("Failed to parse visual chunk JSON: %s, error: %v\n", filepath, parse_error)
		return generate_default_visual_chunk(coord)
	}
	fmt.printf("Successfully parsed json_visual_chunk: %v\n",filepath)
	
	// Verify coordinates
	if json_chunk.coord_x != coord.x || json_chunk.coord_y != coord.y {
		fmt.printf("Visual chunk coordinate mismatch in JSON: %s\n", filepath)
		return generate_default_visual_chunk(coord)
	}

	chunk.coord_x=json_chunk.coord_x
	chunk.coord_y=json_chunk.coord_y

	// Convert sprite data
	for y in 0 ..< CHUNK_SIZE {
		for x in 0 ..< CHUNK_SIZE {
			chunk.sprites[y][x] = cast(Sprite_ID)json_chunk.sprites[y][x]
		}
	}

	// Convert entities
	for json_entity in json_chunk.entities {

		//create entity based off
		entity := Entity {
			pos  = json_entity.pos,
			vel  = json_entity.vel,
			//sprite = json_entity.sprite
			//kind = cast(EntityKind)json_entity.kind,
		}
		append(&chunk.entities, entity)
	}

	// Convert decorations
	for json_decoration in json_chunk.decorations {
		decoration := Decoration {
			pos   = json_decoration.pos,
			sprite = cast(Sprite_ID)json_decoration.sprite,
			layer = json_decoration.layer,
		}
		append(&chunk.decorations, decoration)
	}

	fmt.printf("Loaded visual chunk (%d, %d) from JSON\n", coord.x, coord.y)
	return chunk
}

save_collision_chunk_to_json :: proc(coord: ChunkCoord, chunk: Collision_Chunk) {
	filepath := get_collision_chunk_json_path(coord)
	defer delete(filepath)

	// Create directory if it doesn't exist
	os.make_directory("data/chunks/collision", 0o755)

	// Convert to JSON structure
	json_chunk := JSON_Collision_Chunk {
		//version = COLLISION_CHUNK_VERSION,
		chunk_x = coord.x,
		chunk_y = coord.y,
	}

	for y in 0 ..< CHUNK_SIZE {
		for x in 0 ..< CHUNK_SIZE {
			json_chunk.tiles[y][x] = cast(u8)chunk.tiles[y][x]
		}
	}

	// Marshal to JSON
	json_data, marshal_error := json.marshal(json_chunk, {pretty = true})
	if marshal_error != nil {
		fmt.printf("Failed to marshal collision chunk to JSON: %v\n", marshal_error)
		return
	}
	defer delete(json_data)

	// Write to file
	write_ok := os.write_entire_file(filepath, json_data)
	if !write_ok {
		fmt.printf("Failed to save collision chunk JSON: %s\n", filepath)
	} else {
		fmt.printf("Saved collision chunk (%d, %d) to JSON\n", coord.x, coord.y)
	}
}

save_visual_chunk_to_json :: proc(coord: ChunkCoord, chunk: Visual_Chunk) {
	filepath := get_visual_chunk_json_path(coord)
	defer delete(filepath)

	// Create directory if it doesn't exist
	os.make_directory("data/chunks/visual", 0o755)

	// Convert to JSON structure
	json_chunk := JSON_Visual_Chunk {
		coord_x     = coord.x,
		coord_y     = coord.y,
		entities    = make([]JSON_Entity, len(chunk.entities)),
		decorations = make([]JSON_Decoration, len(chunk.decorations)),
	}
	defer delete(json_chunk.entities)
	defer delete(json_chunk.decorations)

	// Convert sprite data
	for y in 0 ..< CHUNK_SIZE {
		for x in 0 ..< CHUNK_SIZE {
			json_chunk.sprites[y][x] = cast(u32)chunk.sprites[y][x]
		}
	}

	// Convert entities
	for entity, i in chunk.entities {
		json_chunk.entities[i] = JSON_Entity {
			pos = entity.pos,
			vel = entity.vel,
			//animation_name = cast(u32)entity.sprite,
		}
	}

	// Convert decorations
	for decoration, i in chunk.decorations {
		json_chunk.decorations[i] = JSON_Decoration {
			pos = decoration.pos,
			sprite   = cast(u32)decoration.sprite,
			layer    = decoration.layer,
		}
	}

	// Marshal to JSON
	json_data, marshal_error := json.marshal(json_chunk, {pretty = true})
	if marshal_error != nil {
		fmt.printf("Failed to marshal visual chunk to JSON: %v\n", marshal_error)
		return
	}
	defer delete(json_data)

	// Write to file
	write_ok := os.write_entire_file(filepath, json_data)
	if !write_ok {
		fmt.printf("Failed to save visual chunk JSON: %s\n", filepath)
	} else {
		fmt.printf("Saved visual chunk (%d, %d) to JSON\n", coord.x, coord.y)
	}
}

// CONFIGURATION: Choose your approach
// ==================================
// To use JSON instead of binary, replace the function calls:
// load_collision_chunk_from_disk -> load_collision_chunk_from_json
// load_visual_chunk_from_disk -> load_visual_chunk_from_json
// save_collision_chunk_to_disk -> save_collision_chunk_to_json
// save_visual_chunk_to_disk -> save_visual_chunk_to_json

// Binary visual chunk format:
// [4 bytes: version] [4 bytes: chunk_x] [4 bytes: chunk_y] 
// [4096 bytes: sprite data] [4 bytes: entity_count] [entity_data...] 
// [4 bytes: decoration_count] [decoration_data...]
load_visual_chunk_from_disk :: proc(coord: ChunkCoord) -> Visual_Chunk {
	chunk := Visual_Chunk {
		entities    = make([dynamic]Entity),
		decorations = make([dynamic]Decoration),
		is_dirty    = false,
	}

	filepath := get_visual_chunk_path(coord)
	defer delete(filepath)

	data, read_ok := os.read_entire_file(filepath)
	if !read_ok {
		fmt.printf("Could not read visual chunk file: %s\n", filepath)
		return generate_default_visual_chunk(coord)
	}
	defer delete(data)

	if len(data) < 12 + CHUNK_SIZE * CHUNK_SIZE * 4 {
		fmt.printf("Invalid visual chunk file size: %s\n", filepath)
		return generate_default_visual_chunk(coord)
	}

	offset := 0

	// Read header
	//version := (cast(^i32)&data[offset])^;offset += 4
	chunk_x := (cast(^i32)&data[offset])^;offset += 4
	chunk_y := (cast(^i32)&data[offset])^;offset += 4

	// Verify coordinates
	if chunk_x != coord.x || chunk_y != coord.y {
		fmt.printf("Visual chunk coordinate mismatch in file: %s\n", filepath)
		return generate_default_visual_chunk(coord)
	}

	// Read sprite data
	for y in 0 ..< CHUNK_SIZE {
		for x in 0 ..< CHUNK_SIZE {
			chunk.sprites[y][x] = cast(Sprite_ID)(cast(^u32)&data[offset])^
			offset += 4
		}
	}

	// Read entities
	entity_count := (cast(^i32)&data[offset])^;offset += 4
	for i in 0 ..< entity_count {
		entity := Entity{}
		entity.pos.x = (cast(^f32)&data[offset])^;offset += 4
		entity.pos.y = (cast(^f32)&data[offset])^;offset += 4
		entity.vel.x = (cast(^f32)&data[offset])^;offset += 4
		entity.vel.y = (cast(^f32)&data[offset])^;offset += 4
		//entity.sprite = cast(Sprite_ID)(cast(^u32)&data[offset])^;offset += 4
		append(&chunk.entities, entity)
	}

	// Read decorations
	decoration_count := (cast(^i32)&data[offset])^;offset += 4
	for i in 0 ..< decoration_count {
		decoration := Decoration{}
		decoration.pos.x = (cast(^f32)&data[offset])^;offset += 4
		decoration.pos.y = (cast(^f32)&data[offset])^;offset += 4
		//decoration.sprite = cast(Texture_Name)(cast(^u32)&data[offset])^;offset += 4
		decoration.layer = (cast(^i32)&data[offset])^;offset += 4
		append(&chunk.decorations, decoration)
	}

	fmt.printf("Loaded visual chunk (%d, %d) from binary file\n", coord.x, coord.y)
	return chunk
}

save_collision_chunk_to_disk :: proc(coord: ChunkCoord, chunk: Collision_Chunk) {
	filepath := get_collision_chunk_path(coord)
	defer delete(filepath)

	// Create directory if it doesn't exist
	os.make_directory("data/chunks/collision", 0o755)

	// Calculate file size
	file_size := 12 + CHUNK_SIZE * CHUNK_SIZE
	data := make([]u8, file_size)
	defer delete(data)

	// Write header
	offset := 0
	//(cast(^i32)&data[0])^ = COLLISION_CHUNK_VERSION
	(cast(^i32)&data[offset])^ = coord.x;offset += 4
	(cast(^i32)&data[offset])^ = coord.y;;offset += 4

	// Write tile data
	
	for y in 0 ..< CHUNK_SIZE {
		for x in 0 ..< CHUNK_SIZE {
			data[offset] = cast(u8)chunk.tiles[y][x]
			offset += 1
		}
	}

	// Write to file
	write_ok := os.write_entire_file(filepath, data)
	if !write_ok {
		fmt.printf("Failed to save collision chunk: %s\n", filepath)
	} else {
		fmt.printf("Saved collision chunk (%d, %d) to binary file\n", coord.x, coord.y)
	}
}

save_visual_chunk_to_disk :: proc(coord: ChunkCoord, chunk: Visual_Chunk) {
	filepath := get_visual_chunk_path(coord)
	defer delete(filepath)

	// Create directory if it doesn't exist
	os.make_directory("data/chunks/visual", 0o755)

	// Calculate file size
	base_size := 12 + CHUNK_SIZE * CHUNK_SIZE * 4 + 8 // header + sprites + counts
	entity_size := len(chunk.entities) * (4 * 4 + 4) // 4 floats + 1 u32 per entity
	decoration_size := len(chunk.decorations) * (2 * 4 + 4 + 4) // 2 floats + 2 i32s per decoration

	file_size := base_size + entity_size + decoration_size
	data := make([]u8, file_size)
	defer delete(data)

	offset := 0

	// Write header
	(cast(^i32)&data[offset])^ = VISUAL_CHUNK_VERSION;offset += 4
	(cast(^i32)&data[offset])^ = coord.x;offset += 4
	(cast(^i32)&data[offset])^ = coord.y;offset += 4

	// Write sprite data
	for y in 0 ..< CHUNK_SIZE {
		for x in 0 ..< CHUNK_SIZE {
			(cast(^u32)&data[offset])^ = cast(u32)chunk.sprites[y][x]
			offset += 4
		}
	}

	// Write entities
	(cast(^i32)&data[offset])^ = i32(len(chunk.entities));offset += 4
	for entity in chunk.entities {
		(cast(^f32)&data[offset])^ = entity.pos.x;offset += 4
		(cast(^f32)&data[offset])^ = entity.pos.y;offset += 4
		(cast(^f32)&data[offset])^ = entity.vel.x;offset += 4
		(cast(^f32)&data[offset])^ = entity.vel.y;offset += 4
		//(cast(^u32)&data[offset])^ = cast(u32)entity.sprite;offset += 4
	}

	// Write decorations
	(cast(^i32)&data[offset])^ = i32(len(chunk.decorations));offset += 4
	for decoration in chunk.decorations {
		(cast(^f32)&data[offset])^ = decoration.pos.x;offset += 4
		(cast(^f32)&data[offset])^ = decoration.pos.y;offset += 4
		//(cast(^u32)&data[offset])^ = cast(u32)decoration.sprite;offset += 4
		(cast(^i32)&data[offset])^ = decoration.layer;offset += 4
	}

	// Write to file
	write_ok := os.write_entire_file(filepath, data)
	if !write_ok {
		fmt.printf("Failed to save visual chunk: %s\n", filepath)
	} else {
		fmt.printf("Saved visual chunk (%d, %d) to binary file\n", coord.x, coord.y)
	}
}

// Fallback generation for missing chunks
generate_default_collision_chunk :: proc(coord: ChunkCoord) -> Collision_Chunk {
	chunk := Collision_Chunk {
		has_data = true,
	}

	// Generate some basic terrain
	for y in 0 ..< CHUNK_SIZE {
		for x in 0 ..< CHUNK_SIZE {
			if y == CHUNK_SIZE - 1 { 	// Bottom row is solid
				chunk.tiles[y][x] = .SOLID
			} else if coord.y == 0 && y > CHUNK_SIZE - 5 { 	// Some platforms in bottom chunk
				if x % 8 == 0 {
					chunk.tiles[y][x] = .PLATFORM
				}
			} else {
				chunk.tiles[y][x] = .EMPTY
			}
		}
	}

	return chunk
}

generate_default_visual_chunk :: proc(coord: ChunkCoord) -> Visual_Chunk {
	chunk := Visual_Chunk {
		entities    = make([dynamic]Entity),
		decorations = make([dynamic]Decoration),
		is_dirty    = false,
	}

	// Generate matching visual sprites
	for y in 0 ..< CHUNK_SIZE {
		for x in 0 ..< CHUNK_SIZE {
			if y == CHUNK_SIZE - 1 {
				chunk.sprites[y][x] = .STONE_TILE
			} else if coord.y == 0 && y > CHUNK_SIZE - 5 && x % 8 == 0 {
				chunk.sprites[y][x] = .GRASS_TILE
			} else {
				chunk.sprites[y][x] = .NONE
			}
		}
	}

	return chunk
}

// Cleanup
cleanup_level :: proc(level: ^Level) {
	//Save any
	for coord, chunk in level.active_chunks {
		if chunk.is_dirty {
			save_visual_chunk_to_disk(coord, chunk)
		}
		delete(chunk.entities)
		delete(chunk.decorations)
	}

	delete(level.collision_map)
	delete(level.active_chunks)
}
