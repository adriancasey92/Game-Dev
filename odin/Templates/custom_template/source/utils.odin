// Wraps os.read_entire_file and os.write_entire_file, but they also work with emscripten.

package game

//import "base:runtime"
import "core:fmt"
import "core:log"
import "core:math/rand"
import "core:os	"
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
		f32(TITLE_FONT_SIZE),
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
		} else {
			//todo: calculate the width including 
			//menu options/values
			fmt.printf("TODO - CALC MENU WIDTH WITH OPTIONS\n")
		}

	}
	return width
}

get_random_colour :: proc() -> rl.Color {
	r := rand.int31() % 256
	g := rand.int31() % 256
	b := rand.int31() % 256
	return rl.Color{u8(r), u8(g), u8(b), 255} // Full opacity
}
