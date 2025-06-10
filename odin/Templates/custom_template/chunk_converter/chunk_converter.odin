package chunk_converter

import "core:bytes"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strconv"
import "core:strings"
import "core:log"

import "base:runtime"
import "core:c"

import "core:image/png"

import "core:path/slashpath"
import "core:slice"
import "core:time"
import "core:unicode/utf8"

// Import your chunk system (adjust path as needed)
// import "../game" // Assuming your chunk code is in a game package

// Redefine the types here for the tool (or import from your game package)
CHUNK_SIZE :: 32
COLLISION_CHUNK_VERSION :: 1
VISUAL_CHUNK_VERSION :: 1

ChunkCoord :: struct {
	x, y: i32,
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

Entity :: struct {
	position: [2]f32,
	velocity: [2]f32,
	sprite:   Sprite_ID,
}

Decoration :: struct {
	position: [2]f32,
	sprite:   Sprite_ID,
	layer:    i32,
}

Collision_Chunk :: struct {
	tiles:    [CHUNK_SIZE][CHUNK_SIZE]Tile_Type,
	has_data: bool,
}

Visual_Chunk :: struct {
	sprites:     [CHUNK_SIZE][CHUNK_SIZE]Sprite_ID,
	entities:    [dynamic]Entity,
	decorations: [dynamic]Decoration,
	is_dirty:    bool,
}

// Command line interface
Command :: enum {
	HELP,
	JSON_TO_BINARY,
	BINARY_TO_JSON,
	CONVERT_ALL,
	VALIDATE,
}

Config :: struct {
	command:     Command,
	input_path:  string,
	output_path: string,
	chunk_type:  string, // "collision" or "visual"
	recursive:   bool,
}

main :: proc() {

	start_time := time.now()
	config := parse_command_line()

	switch config.command {
	case .HELP:
		print_help()
	case .JSON_TO_BINARY:
		convert_single_file(config, .JSON_TO_BINARY)
	case .BINARY_TO_JSON:
		convert_single_file(config, .BINARY_TO_JSON)
	case .CONVERT_ALL:
		convert_directory(config)
	case .VALIDATE:
		validate_chunks(config)
	}

	run_time_ms := time.duration_milliseconds(time.diff(start_time, time.now()))
	fmt.printf("Conversion completed in %.2fms\n",run_time_ms)
}

parse_command_line :: proc() -> Config {
	config := Config{}
	args := os.args[1:] // Skip program name

	if len(args) == 0 {
		config.command = .HELP
		return config
	}

	i := 0
	for i < len(args) {
		arg := args[i]

		switch arg {
		case "-h", "--help":
			config.command = .HELP
			return config
		case "j2b", "json-to-binary":
			config.command = .JSON_TO_BINARY
		case "b2j", "binary-to-json":
			config.command = .BINARY_TO_JSON
		case "convert-all":
			config.command = .CONVERT_ALL
		case "validate":
			config.command = .VALIDATE
		case "-i", "--input":
			if i + 1 < len(args) {
				i += 1
				config.input_path = args[i]
			}
		case "-o", "--output":
			if i + 1 < len(args) {
				i += 1
				config.output_path = args[i]
			}
		case "-t", "--type":
			if i + 1 < len(args) {
				i += 1
				config.chunk_type = args[i]
			}
		case "-r", "--recursive":
			config.recursive = true
		}
		i += 1
	}

	// Set defaults
	if config.chunk_type == "" {
		config.chunk_type = "collision"
	}

	return config
}

print_help :: proc() {
	fmt.println("Chunk Format Converter Tool")
	fmt.println("===========================")
	fmt.println()
	fmt.println("Usage:")
	fmt.println("  chunk_converter <command> [options]")
	fmt.println()
	fmt.println("Commands:")
	fmt.println("  j2b, json-to-binary    Convert JSON chunk to binary")
	fmt.println("  b2j, binary-to-json    Convert binary chunk to JSON")
	fmt.println("  convert-all            Convert all chunks in directory")
	fmt.println("  validate               Validate chunk files")
	fmt.println()
	fmt.println("Options:")
	fmt.println("  -i, --input <path>     Input file or directory")
	fmt.println("  -o, --output <path>    Output file or directory")
	fmt.println("  -t, --type <type>      Chunk type: 'collision' or 'visual'")
	fmt.println("  -r, --recursive        Process directories recursively")
	fmt.println("  -h, --help             Show this help")
	fmt.println()
	fmt.println("Examples:")
	fmt.println("  # Convert single collision chunk from JSON to binary")
	fmt.println("  chunk_converter j2b -i chunk_0_0.json -o chunk_0_0.dat -t collision")
	fmt.println()
	fmt.println("  # Convert all JSON files in directory to binary")
	fmt.println("  chunk_converter convert-all -i data/chunks/json -o data/chunks/binary")
	fmt.println()
	fmt.println("  # Validate all chunks in directory")
	fmt.println("  chunk_converter validate -i data/chunks -r")
}

convert_single_file :: proc(config: Config, direction: Command) {
	if config.input_path == "" || config.output_path == "" {
		fmt.println("Error: Input and output paths are required")
		return
	}

	success := false

	if config.chunk_type == "collision" {
		success = convert_collision_chunk(config.input_path, config.output_path, direction)
	} else if config.chunk_type == "visual" {
		success = convert_visual_chunk(config.input_path, config.output_path, direction)
	} else {
		fmt.println("Error: Chunk type must be 'collision' or 'visual'")
		return
	}

	if success {
		fmt.printf("Successfully converted %s to %s\n", config.input_path, config.output_path)
	} else {
		fmt.printf("Failed to convert %s\n", config.input_path)
	}
}

convert_collision_chunk :: proc(input_path, output_path: string, direction: Command) -> bool {
	#partial switch direction {
	case .JSON_TO_BINARY:
		// Load from JSON
		chunk, load_ok := load_collision_chunk_json(input_path)
		if !load_ok {
			return false
		}

		// Save as binary
		return save_collision_chunk_binary(output_path, chunk)

	case .BINARY_TO_JSON:
		// Load from binary
		chunk, load_ok := load_collision_chunk_binary(input_path)
		if !load_ok {
			return false
		}

		// Save as JSON
		return save_collision_chunk_json(output_path, chunk)
	}

	return false
}

convert_visual_chunk :: proc(input_path, output_path: string, direction: Command) -> bool {
	#partial switch direction {
	case .JSON_TO_BINARY:
		// Load from JSON
		chunk, load_ok := load_visual_chunk_json(input_path)
		if !load_ok {
			return false
		}
		defer {
			delete(chunk.entities)
			delete(chunk.decorations)
		}

		// Save as binary
		return save_visual_chunk_binary(output_path, chunk)

	case .BINARY_TO_JSON:
		// Load from binary
		chunk, load_ok := load_visual_chunk_binary(input_path)
		if !load_ok {
			return false
		}
		defer {
			delete(chunk.entities)
			delete(chunk.decorations)
		}

		// Save as JSON
		return save_visual_chunk_json(output_path, chunk)
	}

	return false
}

//
convert_directory :: proc(config: Config) {
	if config.input_path == "" || config.output_path == "" {
		fmt.println("Error: Input and output directories are required")
		return
	}
	
	// Create output directory
	if !os.exists(config.output_path){
		fmt.printf("Creating dir: %s\n",config.output_path)
		os.make_directory(config.output_path, 0)
	}


	//collsion_files:=find_chunk_files(config.input_path,config.recursive)
	// Find all chunk files
	files := find_chunk_files(config.input_path, config.recursive)
	defer delete(files)

	fmt.printf("Files found: %v\n",files)

	converted := 0
	failed := 0

	for file_info in files {
		// Determine conversion direction
		is_json := strings.has_suffix(file_info.path, ".json")
		is_binary := strings.has_suffix(file_info.path, ".dat")

		if !is_json && !is_binary {
			continue
		}

		direction := Command.JSON_TO_BINARY if is_json else .BINARY_TO_JSON
		
		// Generate output path
		input_rel := strings.trim_prefix(file_info.path, config.input_path)	
		fmt.printf("input_rel %v\n",input_rel)
		input_rel = strings.trim_prefix(input_rel, "/")
		input_rel = strings.trim_prefix(input_rel, "\\")
		
		output_name := file_info.name
		if is_json {
			output_name, _ = strings.replace(output_name, ".json", ".dat", 1)
		} else {
			output_name, _ = strings.replace(output_name, ".dat", ".json", 1)
		}
		output_path := filepath.join({config.output_path, filepath.dir(input_rel), output_name})

		// Create output directory
		output_dir := filepath.dir(output_path)
		os.make_directory(output_dir, 0o755)

		// Convert file
		success := false
		if file_info.chunk_type == "collision" {
			success = convert_collision_chunk(file_info.path, output_path, direction)
		} else if file_info.chunk_type == "visual" {
			success = convert_visual_chunk(file_info.path, output_path, direction)
		}

		if success {
			converted += 1
			fmt.printf("Converted: %s -> %s\n", file_info.path, output_path)
		} else {
			failed += 1
			fmt.printf("Failed: %s\n", file_info.path)
		}
	}

	fmt.printf("\nConversion complete: %d successful, %d failed\n", converted, failed)
}

validate_chunks :: proc(config: Config) {
	if config.input_path == "" {
		fmt.println("Error: Input path is required")
		return
	}

	files := find_chunk_files(config.input_path, config.recursive)
	defer delete(files)

	valid := 0
	invalid := 0

	for file_info in files {
		is_valid := false

		if file_info.chunk_type == "collision" {
			if strings.has_suffix(file_info.path, ".json") {
				_, load_ok := load_collision_chunk_json(file_info.path)
				is_valid = load_ok
			} else if strings.has_suffix(file_info.path, ".dat") {
				_, load_ok := load_collision_chunk_binary(file_info.path)
				is_valid = load_ok
			}
		} else if file_info.chunk_type == "visual" {
			if strings.has_suffix(file_info.path, ".json") {
				chunk, load_ok := load_visual_chunk_json(file_info.path)
				if load_ok {
					delete(chunk.entities)
					delete(chunk.decorations)
				}
				is_valid = load_ok
			} else if strings.has_suffix(file_info.path, ".dat") {
				chunk, load_ok := load_visual_chunk_binary(file_info.path)
				if load_ok {
					delete(chunk.entities)
					delete(chunk.decorations)
				}
				is_valid = load_ok
			}
		}

		if is_valid {
			valid += 1
			fmt.printf("✓ Valid: %s\n", file_info.path)
		} else {
			invalid += 1
			fmt.printf("✗ Invalid: %s\n", file_info.path)
		}
	}

	fmt.printf("\nValidation complete: %d valid, %d invalid\n", valid, invalid)
}

FileInfo :: struct {
	path:       string,
	name:       string,
	chunk_type: string, // "collision" or "visual"
}

find_chunk_files :: proc(root_path: string, recursive: bool) -> [dynamic]FileInfo {
	files := make([dynamic]FileInfo)

	// Simple directory traversal
	find_chunks_in_dir(root_path, &files, recursive)
	return files
}

find_chunks_in_dir :: proc(dir_path: string, files: ^[dynamic]FileInfo, recursive: bool) {

	fmt.printf("Finding chunks in dir: %s\n",dir_path)
	handle, open_err := os.open(dir_path)
	if open_err != os.ERROR_NONE {
		return
	}
	defer os.close(handle)

	file_infos, read_err := os.read_dir(handle, -1)
	if read_err != os.ERROR_NONE {
		return
	}
	defer delete(file_infos)


	for info in file_infos {
		full_path := filepath.join({dir_path, info.name})
		fmt.printf("Fullpath: %v\n",full_path)
		if info.is_dir && recursive {
			find_chunks_in_dir(full_path, files, recursive)
		}

		// Check if it's a chunk file
		if strings.contains(info.name, "chunk_") {
			chunk_type := ""
			if strings.contains(dir_path, "collision") {
				chunk_type = "collision"
			} else if strings.contains(dir_path, "visual") {
				chunk_type = "visual"
			}

			if chunk_type != "" &&
			(strings.has_suffix(info.name, ".json") ||
					strings.has_suffix(info.name, ".dat")) {
				append(
					files,
					FileInfo{path = full_path, name = info.name, chunk_type = chunk_type},
				)
			}
		}
	}
}

// Include the loading/saving functions from your main chunk system
// (Copy the binary and JSON functions from the previous artifact)
// For brevity, I'll include simplified versions here:

load_collision_chunk_json :: proc(filepath: string) -> (Collision_Chunk, bool) {

	chunk := Collision_Chunk {
		has_data = false,
	}
	fmt.printf("Trying to load %s chunk!\n",filepath)
	data, read_ok := os.read_entire_file(filepath)
	if !read_ok {
		fmt.printf("Could not read collision chunk JSON: %s\n", filepath)
		return chunk, false
	}
	defer delete(data)
	fmt.printf("%s file loaded!!\n",filepath)
	// Parse JSON
	json_chunk: JSON_Collision_Chunk
	parse_error := json.unmarshal(data, &json_chunk)
	if parse_error != nil {
		fmt.printf("Failed to parse collision chunk JSON: %s, error: %v\n", filepath, parse_error)
		return chunk, false
	}
	fmt.printf("Successfully parsed json_chunk\n")

	// Verify coordinates
	/*if json_chunk.chunk_x != coord.x || json_chunk.chunk_y != coord.y {
		fmt.printf("Collision chunk coordinate mismatch in JSON: %s\n", filepath)
		return generate_default_collision_chunk(coord)
	}*/

	// Convert data
	for y in 0 ..< CHUNK_SIZE {
		for x in 0 ..< CHUNK_SIZE {
			chunk.tiles[y][x] = cast(Tile_Type)json_chunk.tiles[y][x]
		}
	}

	chunk.has_data = true
	//fmt.printf("Loaded collision chunk (%d, %d) from JSON\n", coord.x, coord.y)
	fmt.printf("Loaded json chunk\n")
	return chunk, true // Placeholder
}

// JSON file paths
get_collision_chunk_json_path :: proc(coord: ChunkCoord) -> string {
	return fmt.aprintf("data/chunks/collision/chunk_%d_%d.json", coord.x, coord.y)
}

get_visual_chunk_json_path :: proc(coord: ChunkCoord) -> string {
	return fmt.aprintf("data/chunks/visual/chunk_%d_%d.json", coord.x, coord.y)
}

load_collision_chunk_binary :: proc(filepath: string) -> (Collision_Chunk, bool) {
	// Implementation similar to your main code
	chunk := Collision_Chunk{}
	// ... Binary loading logic
	return chunk, true // Placeholder
}

save_collision_chunk_json :: proc(filepath: string, chunk: Collision_Chunk) -> bool {
	// Implementation similar to your main code
	return true // Placeholder
}

save_collision_chunk_binary :: proc(filepath: string, chunk: Collision_Chunk) -> bool {
	// Implementation similar to your main code
	return true // Placeholder
}

load_visual_chunk_json :: proc(filepath: string) -> (Visual_Chunk, bool) {
	chunk := Visual_Chunk {
		entities    = make([dynamic]Entity),
		decorations = make([dynamic]Decoration),
	}
	// ... JSON loading logic
	return chunk, true // Placeholder
}

load_visual_chunk_binary :: proc(filepath: string) -> (Visual_Chunk, bool) {
	chunk := Visual_Chunk {
		entities    = make([dynamic]Entity),
		decorations = make([dynamic]Decoration),
	}
	// ... Binary loading logic
	return chunk, true // Placeholder
}

save_visual_chunk_json :: proc(filepath: string, chunk: Visual_Chunk) -> bool {
	return true // Placeholder
}

save_visual_chunk_binary :: proc(filepath: string, chunk: Visual_Chunk) -> bool {
	return true // Placeholder
}


// JSON APPROACH (Alternative - easier to debug but slower)
// =======================================================

// JSON structures for serialization
JSON_Collision_Chunk :: struct {
	version: int,
	chunk_x: i32,
	chunk_y: i32,
	tiles:   [CHUNK_SIZE][CHUNK_SIZE]u8, // Store as numbers for JSON
}

JSON_Entity :: struct {
	position: [2]f32,
	velocity: [2]f32,
	sprite:   u32,
}

JSON_Decoration :: struct {
	position: [2]f32,
	sprite:   u32,
	layer:    i32,
}

JSON_Visual_Chunk :: struct {
	version:     int,
	chunk_x:     i32,
	chunk_y:     i32,
	sprites:     [CHUNK_SIZE][CHUNK_SIZE]u32,
	entities:    []JSON_Entity,
	decorations: []JSON_Decoration,
}
