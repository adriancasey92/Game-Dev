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

import "core:path/slashpath"
import "core:slice"
import "core:time"
import "core:unicode/utf8"
import "core:unicode"

// Import your chunk system (adjust path as needed)
// import "../game" // Assuming your chunk code is in a game package

// Redefine the types here for the tool (or import from your game package)
CHUNK_SIZE :: 32
COLLISION_CHUNK_VERSION :: 1
VISUAL_CHUNK_VERSION :: 1

ChunkCoord :: struct {
	x, y: i32,
}

Decoration :: struct {
	pos: [2]f32,
	sprite:   Sprite_ID,
	layer:    i32,
}

Tile_Type :: enum u8 {
	EMPTY    = 0,
	SOLID    = 1,
	PLATFORM = 2,
	SPIKE    = 3,
	TEST1    = 4,
	TEST2	 = 5,
	TEST3	 = 6,
}

Sprite_ID :: enum u32 {
	NONE         = 0,
	GRASS_TILE   = 1,
	STONE_TILE   = 2,
	SPIKE_SPRITE = 3,
	TEST1	     = 4,
	TEST2		 = 5,
	TEST3		 = 6,
}

Entity :: struct {
	pos: [2]f32,
	vel: [2]f32,
	sprite:   Sprite_ID,
}

Collision_Chunk :: struct {
	coord_x: i32,
	coord_y: i32,
	tiles:    [CHUNK_SIZE][CHUNK_SIZE]Tile_Type,
	has_data: bool,
}

Visual_Chunk :: struct {
	coord_x: i32, 
	coord_y: i32,
	sprites:     [CHUNK_SIZE][CHUNK_SIZE]Sprite_ID,
	entities:    [dynamic]Entity,
	decorations: [dynamic]Decoration,
	is_dirty: bool, //whether visual chunk needs to be saved
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

FileInfo :: struct {
	path:       string,
	name:       string,
	chunk_type: string, // "collision" or "visual"
}

// JSON structures for serialization
JSON_Collision_Chunk :: struct {
	coord_x: i32,
	coord_y: i32,
	tiles:   [CHUNK_SIZE][CHUNK_SIZE]u8, // Store as numbers for JSON
}

JSON_Entity :: struct {
	pos: [2]f32,
	vel: [2]f32,
	sprite:   u32,
}

JSON_Decoration :: struct {
	pos: [2]f32,
	sprite:   Sprite_ID,
	layer:    i32,
}

JSON_Visual_Chunk :: struct {
	coord_x:     i32,
	coord_y:     i32,
	sprites:     [CHUNK_SIZE][CHUNK_SIZE]u32,
	entity_count: i32,
	entities:    []JSON_Entity,
	decoration_count: i32,
	decorations: []JSON_Decoration,
}

main :: proc() {

	start_time := time.now()
	config := parse_command_line()
	fmt.printf("\nChunkConverter.odin - Welcome!\n")
	fmt.printf("------------------------------\n")
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
			fmt.printf("Failed to load chunk!: convert_collision_chunk :: proc (%s, %s, %s)", input_path, output_path, direction)
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

	// Find all chunk files
	files := find_chunk_files(config.input_path, config.recursive)
	defer delete(files)
	fmt.printf("Found %i files\n",len(files))
	for file in files{
		fmt.printf("File info: %s\n",file.name)
		fmt.printf("File chunk type: %s\n",file.chunk_type)
	}
	fmt.printf("------------------------------\n")

	//Metrics
	converted := 0
	skipped:= 0
	failed := 0

	//For every file found
	for file_info in files {
		// Determine conversion direction
		is_json := strings.has_suffix(file_info.path, ".json")
		is_binary := strings.has_suffix(file_info.path, ".dat")

		//we only want to check .dat and .json files
		if !is_json && !is_binary { continue }
		//determine conversion based on file type
		direction := Command.JSON_TO_BINARY if is_json else .BINARY_TO_JSON
		output_name := file_info.name
		type:=""

		//if we have a json file, do binary conversion
		if is_json {
			type="/binary"
			folder_path := filepath.join({config.output_path, type})
			if !os.exists(folder_path)
			{
				err:= os.make_directory(folder_path)
				if err!=nil{
					fmt.printf("Err: %s\n",err)
				}
			}
			output_name, _ = strings.replace(output_name, ".json", ".dat", 1)
		} else {
			type="/json"
			folder_path := filepath.join({config.output_path, type})
			if !os.exists(folder_path)
			{
				err:= os.make_directory(folder_path)
				if err!=nil{
					fmt.printf("Err: %s\n",err)
				}
			}
			output_name, _ = strings.replace(output_name, ".dat", ".json", 1)
		}

		output_path:string
		output_dir:string
		// Check to see what type of file we are converting
		if file_info.chunk_type == "collision" {
			output_dir = filepath.join({config.output_path,type,"/collision"})
			fmt.printf("Output dir: %s\n",output_dir)
			//If directory doesn't exist, create it. 
			if !os.exists(output_dir)
			{	
				fmt.printf("Creating dir: %s\n",output_dir)
				err:=os.make_directory(output_dir,0)
				if err!=nil{
					fmt.printf("Err: %s\n",err)
				}
			}
			output_path = filepath.join({config.output_path,type,"/collision/", output_name})
			exists := os.exists(output_path)
			
			//only try to convert if file doesn't exist
			if !exists{
				if convert_collision_chunk(file_info.path, output_path, direction){
					fmt.printf("Converted: %s -> %s\n", file_info.path, output_path)
					converted+=1
				}
				else{
					failed+=1
					fmt.printf("Failed: %s\n", file_info.path)
				}
			}
			else{ skipped += 1}
		} else if file_info.chunk_type == "visual" {
			
			output_dir = filepath.join({config.output_path,type,"/visual"})
			fmt.printf("Output dir: %s\n",output_dir)
			if !os.exists(output_dir)
			{
				fmt.printf("Creating dir: %s\n",output_dir)
				os.make_directory(output_dir,0)
			}
			output_path = filepath.join({config.output_path,type,"/visual/", output_name})
			exists := os.exists(output_path)
			if !exists{
				if convert_visual_chunk(file_info.path, output_path, direction){
					fmt.printf("Converted: %s -> %s\n", file_info.path, output_path)
					converted+=1
				}	
				else{
					failed+=1
					fmt.printf("Failed: %s\n", file_info.path)
				}
			}else{ skipped += 1}
		}
		fmt.printf("-----------------------------------------------------------------\n")
	}
	fmt.printf("\nConversion complete: %d successful, %d failed, %d skipped\n", converted, failed,skipped)
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

find_chunk_files :: proc(root_path: string, recursive: bool) -> [dynamic]FileInfo {
	files := make([dynamic]FileInfo)

	// Simple directory traversal
	find_chunks_in_dir(root_path, &files, recursive)
	return files
}

find_chunks_in_dir :: proc(dir_path: string, files: ^[dynamic]FileInfo, recursive: bool) {

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
	//fmt.printf("Trying to load %s chunk!\n",filepath)
	
	data, read_ok := os.read_entire_file(filepath)
	if !read_ok {
		fmt.printf("Could not read collision chunk JSON: %s\n", filepath)
		return chunk, false
	}
	defer delete(data)
	
	//fmt.printf("data: %v",data)
	// Parse JSON
	json_chunk: JSON_Collision_Chunk
	parse_error := json.unmarshal(data, &json_chunk)
	if parse_error != nil {
		fmt.printf("Failed to parse collision chunk JSON: %s, error: %v\n", filepath, parse_error)
		return chunk, false
	}
	fmt.printf("Successfully parsed json_collision_chunk: %v\n",filepath)
	
	// Verify coordinates
	/*if json_chunk.chunk_x != coord.x || json_chunk.chunk_y != coord.y {
		fmt.printf("Collision chunk coordinate mismatch in JSON: %s\n", filepath)
		return generate_default_collision_chunk(coord)
	}*/

	chunk.coord_x=json_chunk.coord_x
	chunk.coord_y=json_chunk.coord_y

	// Convert data
	for y in 0 ..< CHUNK_SIZE {
		for x in 0 ..< CHUNK_SIZE {
			chunk.tiles[y][x] = cast(Tile_Type)json_chunk.tiles[y][x]
		}
	}

	chunk.has_data = true
	//fmt.printf("Loaded collision chunk (%d, %d) from JSON\n", coord.x, coord.y)
	//fmt.printf("Loaded json chunk\n%s",chunk)
	return chunk, true // Placeholder
}

load_collision_chunk_binary :: proc(filepath: string) -> (Collision_Chunk, bool) {
	// Implementation similar to your main code
	chunk := Collision_Chunk {
		has_data = false,
	}

	// Try to read binary file
	data, read_ok := os.read_entire_file(filepath)
	if !read_ok {
		fmt.printf("Could not read collision chunk file: %s\n", filepath)
		//return generate_default_collision_chunk(coord)
	}
	defer delete(data)

	if len(data) < 8 + CHUNK_SIZE * CHUNK_SIZE {
		fmt.printf("Invalid collision chunk file size: %s\n", filepath)
		//return generate_default_collision_chunk(coord)
	}

	// Read header
	reader := bytes.Reader {
		s = data,
	}

	//version := (cast(^i32)&data[0])^
	chunk_x := (cast(^i32)&data[0])^
	chunk_y := (cast(^i32)&data[4])^

	// Verify chunk coordinates match
	/*if chunk_x != coord.x || chunk_y != coord.y {
		fmt.printf("Chunk coordinate mismatch in file: %s\n", filepath)
		return generate_default_collision_chunk(coord)
	}*/

	// Copy tile data directly
	tile_data_start := 8
	for y in 0 ..< CHUNK_SIZE {
		for x in 0 ..< CHUNK_SIZE {
			idx := tile_data_start + y * CHUNK_SIZE + x
			chunk.tiles[y][x] = cast(Tile_Type)data[idx]
		}
	}

	chunk.has_data = true
	fmt.printf("Loaded collision chunk (%d, %d) from binary file\n", chunk.coord_x, chunk.coord_y)
	return chunk, true // Placeholder
}

save_collision_chunk_json :: proc(filepath: string, chunk: Collision_Chunk) -> bool {
	// Implementation similar to your main code
	// Create directory if it doesn't exist
	
	// Convert to JSON structure
	json_chunk := JSON_Collision_Chunk {
		//version = COLLISION_CHUNK_VERSION,
		coord_x =chunk.coord_x,
		coord_y = chunk.coord_y,
	}

	for y in 0 ..< CHUNK_SIZE {
		for x in 0 ..< CHUNK_SIZE {
			json_chunk.tiles[y][x] = cast(u8)chunk.tiles[y][x]
		}
	}

	json_chunk.coord_x=chunk.coord_x
	json_chunk.coord_y=chunk.coord_y
	// Marshal to JSON
	json_data, marshal_error := json.marshal(json_chunk, {pretty=true,use_spaces = true})
	if marshal_error != nil {
		fmt.printf("Failed to marshal collision chunk to JSON: %v\n", marshal_error)
		return false
	}
	defer delete(json_data)

	

	// Write to file
	write_ok := os.write_entire_file(filepath, json_data)
	if !write_ok {
		fmt.printf("Failed to save collision chunk JSON: %s\n", filepath)
		return false
	}

	fmt.printf("Saved collision chunk (%d, %d) to JSON file\n", chunk.coord_x, chunk.coord_y)
	return true
}

save_collision_chunk_binary :: proc(filepath: string, chunk: Collision_Chunk) -> bool {
	// Implementation similar to your main code
	// Calculate file size
	file_size := 8 + CHUNK_SIZE * CHUNK_SIZE
	data := make([]u8, file_size)
	defer delete(data)

	// Write header
	(cast(^i32)&data[0])^ = chunk.coord_x
	(cast(^i32)&data[4])^ = chunk.coord_y
	
	// Write tile data
	offset := 8
	for y in 0 ..< CHUNK_SIZE {
		for x in 0 ..< CHUNK_SIZE {
			data[offset] = cast(u8)chunk.tiles[y][x]
			offset += 1
		}
	}

	// Write to file
	write_ok := os.write_entire_file(filepath, data)
	if !write_ok {
		fmt.printf("Failed to save collision chunk: %v\n", filepath)
		return false
	}

	fmt.printf("Saved collision chunk (%d, %d) to binary file\n", chunk.coord_x, chunk.coord_y)
	return true 
}

//Loads the visual chunk from filepath
//Returns the loaded visual chunk data as a Visual_Chunk
//If the loaded coord data mismatches the filepath string coord
//it will return false with an empty chunk.
load_visual_chunk_json :: proc(filepath: string) -> (Visual_Chunk, bool) {

	chunk := Visual_Chunk {
		entities    = make([dynamic]Entity),
		decorations = make([dynamic]Decoration),
		is_dirty=false,
	}

	data, read_ok := os.read_entire_file(filepath)
	if !read_ok {
		fmt.printf("Could not read visual chunk JSON: %s\n", filepath)
		return chunk, false
	}
	defer delete(data)
	
	// Parse JSON
	json_chunk: JSON_Visual_Chunk
	parse_error := json.unmarshal(data, &json_chunk)
	if parse_error != nil {
		fmt.printf("Failed to parse collision chunk JSON: %s, error: %v\n", filepath, parse_error)
		return chunk, false
	}
	fmt.printf("Successfully parsed json_visual_chunk: %v\n",filepath)

	//check that our filename coord matches the loaded coords
	json_filename_coord := get_coord_from_filepath(filepath)

	// Verify coordinates
	if json_chunk.coord_x != json_filename_coord.x|| json_chunk.coord_y != json_filename_coord.y {
		fmt.printf("Visual chunk coordinate mismatch in JSON: %s\n", filepath)
		//return generate_default_visual_chunk(coord)
	}

	chunk.coord_x=json_chunk.coord_x
	chunk.coord_y=json_chunk.coord_y

	// Convert data
	for y in 0 ..< CHUNK_SIZE {
		for x in 0 ..< CHUNK_SIZE {
			chunk.sprites[y][x] = cast(Sprite_ID)json_chunk.sprites[y][x]
		}
	}
	
	//add entities
	for json_entity in json_chunk.entities{
		entity := Entity{
			pos = json_entity.pos,
			vel = json_entity.vel,
		}
		append (&chunk.entities, entity)
	}
	
	for json_decoration in json_chunk.decorations{
		decoration := Decoration{
			pos=json_decoration.pos, 
			sprite = json_decoration.sprite,
			layer= json_decoration.layer
		}
		append(&chunk.decorations, decoration)
	}

	return chunk, true
}


//returns the coordinate in filepath string as an array [x,y]
get_coord_from_filepath::proc(filepath:string)->[2]i32{
	ret: [2]i32
	count:=0
	for i:=0; i<len(filepath); i+=1{
		if unicode.is_digit(rune(filepath[i])){
			start_idx:=i

			for ;i < len(filepath) && unicode.is_digit(rune(filepath[i]));i+=1{}
			num_string := filepath[start_idx:i]

			n,ok := strconv.parse_i64_of_base(num_string, 10, nil)
			if ok{
				ret[count]=i32(n)
				count+=1
			}
			i-=1
		}
	}
	return ret
}

//Loads visual chunk data from filestring
//Returns the data as a Visual_Chunk struct, and true/false if it loaded successfully.
load_visual_chunk_binary :: proc(filepath: string) -> (Visual_Chunk, bool) {
	chunk := Visual_Chunk {
		entities    = make([dynamic]Entity),
		decorations = make([dynamic]Decoration),
		is_dirty    = false,
	}

	data, read_ok := os.read_entire_file(filepath)
	if !read_ok {
		fmt.printf("Could not read visual chunk file: %s\n", filepath)
		//return generate_default_visual_chunk(coord)
	}
	defer delete(data)

	if len(data) < 12 + CHUNK_SIZE * CHUNK_SIZE * 4 {
		fmt.printf("Invalid visual chunk file size: %s\n", filepath)
		//return generate_default_visual_chunk(coord)
	}

	offset := 0

	// Read header
	//version := (cast(^i32)&data[offset])^;offset += 4
	chunk_x := (cast(^i32)&data[offset])^;offset += 4
	chunk_y := (cast(^i32)&data[offset])^;offset += 4

	//check that our filename coord matches the loaded coords
	bin_coord := get_coord_from_filepath(filepath)

	// Verify coordinates with filename?
	if chunk_x != bin_coord.x || chunk_y != bin_coord.y {
		fmt.printf("Visual chunk coordinate mismatch in file: %s\n", filepath)
		//return generate_default_visual_chunk(coord)
		return chunk, false
	}

	chunk.coord_x = chunk_x
	chunk.coord_y = chunk_y

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
		entity.sprite = cast(Sprite_ID)(cast(^u32)&data[offset])^;offset += 4
		append(&chunk.entities, entity)
	}

	// Read decorations
	decoration_count := (cast(^i32)&data[offset])^;offset += 4
	for i in 0 ..< decoration_count {
		decoration := Decoration{}
		decoration.pos.x = (cast(^f32)&data[offset])^;offset += 4
		decoration.pos.y = (cast(^f32)&data[offset])^;offset += 4
		decoration.sprite = cast(Sprite_ID)(cast(^u32)&data[offset])^;offset += 4
		decoration.layer = (cast(^i32)&data[offset])^;offset += 4
		append(&chunk.decorations, decoration)
	}

	return chunk, true // Placeholder
}

save_visual_chunk_json :: proc(filepath: string, chunk: Visual_Chunk) -> bool {

	// Convert to JSON structure
	json_chunk := JSON_Visual_Chunk {
		coord_x     = chunk.coord_x,
		coord_y     = chunk.coord_y,
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
	json_chunk.entity_count = i32(len(json_chunk.entities))
	for entity, i in chunk.entities {
		json_chunk.entities[i] = JSON_Entity {
			pos = entity.pos,
			vel = entity.vel,
			sprite = cast(u32)entity.sprite
			//animation_name = cast(u32)entity.sprite,
		}
	}

	
	// Convert decorations
	json_chunk.decoration_count = i32(len(json_chunk.decorations))
	for decoration, i in chunk.decorations {
		json_chunk.decorations[i] = JSON_Decoration {
			pos = decoration.pos,
			sprite   = cast(Sprite_ID)decoration.sprite,
			layer    = decoration.layer,
		}
	}

	// Marshal to JSON
	json_data, marshal_error := json.marshal(json_chunk, {pretty = true})
	if marshal_error != nil {
		fmt.printf("Failed to marshal visual chunk to JSON: %v\n", marshal_error)
		return false
	}
	defer delete(json_data)

	// Write to file
	write_ok := os.write_entire_file(filepath, json_data)
	if !write_ok {
		fmt.printf("Failed to save visual chunk JSON: %s\n", filepath)
	} else {
		fmt.printf("Saved visual chunk (%d, %d) to JSON\n", chunk.coord_x, chunk.coord_y)
	}

	return true // Placeholder
}

save_visual_chunk_binary :: proc(filepath: string, chunk: Visual_Chunk) -> bool {
	// Calculate file size
	base_size := 8 + CHUNK_SIZE * CHUNK_SIZE * 4 + 8// header + sprites + counts
	entity_size := len(chunk.entities) * (4 * 4 + 4) // 4 floats + 1 u32 per entity
	decoration_size := len(chunk.decorations) * (2 * 4 + 4 + 4) // 2 floats + 2 i32s per decoration

	file_size := base_size + entity_size + decoration_size
	data := make([]u8, file_size)
	defer delete(data)


	offset := 0
	// Write header
	(cast(^i32)&data[offset])^ = chunk.coord_x;offset += 4
	(cast(^i32)&data[offset])^ = chunk.coord_y;offset += 4

	
	// Write sprite data
	for y in 0 ..< CHUNK_SIZE {
		for x in 0 ..< CHUNK_SIZE {
			(cast(^u32)&data[offset])^ = cast(u32)chunk.sprites[y][x]
			offset += 4
		}
	}

	fmt.printf("Num entities in visual chunk: %i\n",len(chunk.entities))
	// Write entities
	length := i32(len(chunk.entities))
	(cast(^i32)&data[offset])^ = length;offset += 4
	for entity in chunk.entities {
		(cast(^f32)&data[offset])^ = entity.pos.x;offset += 4
		(cast(^f32)&data[offset])^ = entity.pos.y;offset += 4
		(cast(^f32)&data[offset])^ = entity.vel.x;offset += 4
		(cast(^f32)&data[offset])^ = entity.vel.y;offset += 4
		(cast(^u32)&data[offset])^ = cast(u32)entity.sprite;offset += 4
	}

	// Write decorations
	(cast(^i32)&data[offset])^ = i32(len(chunk.decorations));offset += 4
	for decoration in chunk.decorations {
		(cast(^f32)&data[offset])^ = decoration.pos.x;offset += 4
		(cast(^f32)&data[offset])^ = decoration.pos.y;offset += 4
		(cast(^u32)&data[offset])^ = cast(u32)decoration.sprite;offset += 4
		(cast(^i32)&data[offset])^ = decoration.layer;offset += 4
	}

	// Write to file
	write_ok := os.write_entire_file(filepath, data)
	if !write_ok {
		fmt.printf("Failed to save visual chunk: %s\n", filepath)
	} else {
		fmt.printf("Saved visual chunk (%d, %d) to binary file\n", chunk.coord_x, chunk.coord_y)
		fmt.printf("Visual chunk size: %i\n",file_size/4)
		fmt.printf("Data size : %i\n",size_of(data))
	}
	return true 
}
