// Wraps os.read_entire_file and os.write_entire_file, but they also work with emscripten.

package game

//import "base:runtime"
import hm "../handle_map"
import "core:log"
import "core:math/rand"
import "core:os	"
import "core:strings"
import rl "vendor:raylib"
//import "core:time"

@(require_results)
read_entire_file :: proc(
	name: string,
	allocator := context.allocator,
	loc := #caller_location,
) -> (
	data: []byte,
	success: bool,
) {
	return _read_entire_file(name, allocator, loc)
}

write_entire_file :: proc(name: string, data: []byte, truncate := true) -> (success: bool) {
	return _write_entire_file(name, data, truncate)
}

dir_path_to_file_infos :: proc(path: string) -> []os.File_Info {
	d, derr := os.open(path, os.O_RDONLY)
	if derr != nil {
		log.panicf("No %s folder found", path)
	}
	defer os.close(d)

	{
		file_info, ferr := os.fstat(d)
		defer os.file_info_delete(file_info)

		if ferr != nil {
			log.panic("stat failed")
		}
		if !file_info.is_dir {
			log.panic("not a directory")
		}
	}

	file_infos, _ := os.read_dir(d, -1)
	return file_infos
}

get_width_of_longest_string_in_menu :: proc(menu: ^Menu, spacing: f32) -> f32 {
	text_size_vec := rl.MeasureTextEx(
		rl.GetFontDefault(),
		menu.title,
		f32(MENU_TITLE_FONT_SIZE),
		spacing,
	)
	width := text_size_vec.x
	for i := 0; i < len(menu.options); i += 1 {
		if menu.type != .settings {
			text_size_vec = rl.MeasureTextEx(
				rl.GetFontDefault(),
				menu.options[i],
				f32(MENU_FONT_SIZE),
				spacing,
			)

			if width < text_size_vec.x {
				width = text_size_vec.x
			}
		}
	}
	return width
}

//Returns the width of the longest string for debug info of an entity
get_width_of_longest_string_in_entity_debug_info :: proc(
	cstr: []cstring,
	entity: Entity_Handle,
	spacing: f32,
) -> f32 {

	ent := hm.get(g.entities, entity)
	width := f32(0)
	for i := 0; i < len(cstr); i += 1 {
		text_size_vec := rl.MeasureTextEx(
			rl.GetFontDefault(),
			rl.TextFormat("%s: %s", cstr[i], get_entity_info(entity, cstr[i])),
			f32(get_scaled_font_size()),
			spacing,
		)

		if width < text_size_vec.x {
			width = text_size_vec.x
		}
	}
	return width
}

get_height_of_debug_info :: proc(debug_info: []cstring, font_size: f32, spacing: f32) -> f32 {
	num_lines := i32(len(debug_info))
	return f32(num_lines) * font_size + f32(num_lines - 1) * spacing + font_size + 20
}

get_random_colour :: proc() -> rl.Color {
	r := rand.int31() % 256
	g := rand.int31() % 256
	b := rand.int31() % 256
	return rl.Color{u8(r), u8(g), u8(b), 255} // Full opacity
}

// Check if file exists
file_exists :: proc(filepath: string) -> bool {
	return os.exists(filepath)
	//defer os.file_info_delete(file_info)
	//return err == nil
}

temp_cstring :: proc(s: string) -> cstring {
	return strings.clone_to_cstring(s, context.temp_allocator)
}


//gets font size based on the current zoom
get_scaled_font_size :: proc() -> f32 {
	scale_x := f32(rl.GetScreenWidth()) / f32(WIDTH)
	scale_y := f32(rl.GetScreenHeight()) / f32(HEIGHT)
	return f32(BASE_FONT_SIZE) * min(scale_x, scale_y)
}

get_random_pos_within_camera :: proc() -> Vec2 {
	// Generate a random position within the camera's viewport

	camera := game_camera()
	min_x := camera.target.x - camera.offset.x / 2
	max_x := camera.target.x + camera.offset.x / 2
	min_y := camera.target.y - camera.offset.y / 2
	max_y := camera.target.y + camera.offset.y / 2

	x := rand.float32_range(min_x, max_x)
	y := rand.float32_range(min_y, max_y)
	return Vec2{x, y}
}
