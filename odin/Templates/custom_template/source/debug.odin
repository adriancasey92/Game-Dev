package game

import hm "../handle_map"
import rl "vendor:raylib"

debug_title: cstring = "Debug Player Info"
debug_info_str: []cstring = {
	"Pos:",
	"Vel:",
	"Move:",
	"Grounded:",
	"Input:",
	"Dir:",
	"FlipX:",
	"FlipY:",
	"Orientation:",
	"Anim:",
	"Anim_frame:",
}

debug_player_draw :: proc() {
	//p := get_player()
	font_size := get_scaled_font_size()
	spacing := f32(1)

	ypos := f32(10)
	text_size := rl.MeasureTextEx(rl.GetFontDefault(), debug_title, font_size + 5, spacing)
	ypos += text_size.y
	debug_height := ypos + (f32(len(debug_info_str)) * font_size)
	rl.DrawRectangle(0, 0, i32(text_size.x + 20), i32(debug_height + 10), rl.Fade(rl.BLACK, 0.2))
	rl.DrawTextEx(rl.GetFontDefault(), debug_title, {10, 10}, font_size + 5, spacing, rl.BLACK)

	for i := 0; i < len(debug_info_str); i += 1 {
		info := get_entity_info(g.player_handle, debug_info_str[i])
		rl.DrawTextEx(
			rl.GetFontDefault(),
			rl.TextFormat("%s %s", debug_info_str[i], info),
			{10, ypos + f32(i) * font_size},
			font_size,
			spacing,
			rl.BLACK,
		)
	}
	//	ypos+= ypos.
}


//Draws debug infor for an entity relative to pos (top left corner of Debug box)
debug_draw_entity :: proc(entity_handle: Entity_Handle, pos: Vec2) {
	entity := hm.get(g.entities, entity_handle)
	if entity == nil {
		return
	}
	if entity.handle == g.player_handle {
		debug_player_draw()
		return
	}

	font_size := get_scaled_font_size()
	spacing := f32(1)
	pad := f32(10)
	ypos := pos.y + pad
	xpos := pos.x + pad
	text_size := rl.MeasureTextEx(
		rl.GetFontDefault(),
		rl.TextFormat("Debug %v-%i info", entity.kind, entity_handle.idx),
		font_size + 5,
		spacing,
	)
	ypos += text_size.y
	debug_height := ypos + (f32(len(debug_info_str)) * font_size)
	rl.DrawRectangle(
		i32(pos.x),
		i32(pos.y),
		i32(text_size.x + 20),
		i32(debug_height + 10),
		rl.Fade(rl.BLACK, 0.2),
	)
	rl.DrawRectangleLines(
		i32(pos.x),
		i32(pos.y),
		i32(text_size.x + 20),
		i32(debug_height + 10),
		rl.RED,
	)
	rl.DrawTextEx(
		rl.GetFontDefault(),
		rl.TextFormat("Debug %v-%i info", entity.kind, entity_handle.idx),
		{10, 10},
		font_size + 5,
		spacing,
		rl.BLACK,
	)

	for i := 0; i < len(debug_info_str); i += 1 {
		info := get_entity_info(entity_handle, debug_info_str[i])
		rl.DrawTextEx(
			rl.GetFontDefault(),
			rl.TextFormat("%s %s", debug_info_str[i], info),
			{xpos, ypos + f32(i) * font_size},
			font_size,
			spacing,
			rl.BLACK,
		)
	}
}

get_entity_info :: proc(entity_handle: Entity_Handle, info: cstring) -> cstring {
	entity := hm.get(g.entities, entity_handle)
	if entity == nil {
		return "Entity not found"
	}
	if info == "Pos:" {
		return rl.TextFormat("[%.1f, %.1f]", entity.pos.x, entity.pos.y)
	} else if info == "Vel:" {
		return rl.TextFormat("%.2f", entity.vel.y)
	} else if info == "Move:" {
		return rl.TextFormat("%v", entity.movement)
	} else if info == "Grounded:" {
		return rl.TextFormat("%t", entity.is_on_ground)
	} else if info == "Input:" {
		return rl.TextFormat("[%.f,%.f]", entity.input.x, entity.input.y)
	} else if info == "Dir:" {
		return rl.TextFormat("%v", entity.dir)
	} else if info == "FlipX:" {
		return rl.TextFormat("%t", entity.flip_x)
	} else if info == "FlipY:" {
		return rl.TextFormat("%t", entity.flip_y)
	} else if info == "Orientation:" {
		return rl.TextFormat("%v", entity.orientation)
	} else if info == "Anim:" {
		return rl.TextFormat("%v", entity.anim.atlas_anim)
	} else if info == "Anim_frame:" {
		return rl.TextFormat("%v", entity.anim.current_frame)
	} else {
		return "Unknown Info"
	}
}
