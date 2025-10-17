package game

import hm "../handle_map"
import "core:fmt"
import rl "vendor:raylib"

MAX_ENTITIES :: 2500

Entity_Handle :: distinct hm.Handle

Entity :: struct {
	handle:              Entity_Handle,
	kind:                EntityKind,
	sprite:              Sprite_ID,

	// could pack these into flags if you feel like it (not really needed though)
	/*has_physics:         bool,
	damagable_by_player: bool,
	is_mob:              bool,
	blocks_mobs:         bool,*/

	// just put whatever state you need in here to make the game...
	pos:                 Vec2,
	size:                Vec2,
	dir:                 Entity_Direction,
	last_movement:       Entity_Movement,
	ent_rect:            EntityRect,
	side_jump:           bool,
	side_jump_timer:     f32,
	jumping_direction:   Entity_Direction,
	can_run:             bool,
	vel:                 Vec2,
	rect:                Rect,
	input:               Vec2,
	is_on_ground:        bool,
	action:              Entity_Action,
	movement:            Entity_Movement,
	orientation:         Entity_Orientation,
	last_orientation:    Entity_Orientation,
	wall_climbing:       bool,
	can_wall_climb:      bool,
	air_time:            f32,

	//platform index
	platform_index:      int,

	/*
	hit_cooldown_end_time: f64,
	health:                int,
	next_attack_time:      f64,*/
	anim:                Animation,
	flip_x:              bool,
	flip_y:              bool,
	corner_collider:     Rect,
	feet_collider:       Rect,
	face_collider:       Rect,
	head_collider:       Rect,


	//AI Entity
	random_move_bool:    bool,
	random_jump_bool:    bool,
	can_fall_right:      bool,
	can_fall_left:       bool,
	move_dir:            i32,
	move_duration:       f32,
	move_duration_timer: f32,
	jump_timer:          f32,
	jump_duration:       f32,
	// ...
	debug_draw_bool:     bool,

	// Constant Entity Data
	//
	// this is constant based on the kind of the entity
	// you could put this somewhere else if you want, I like having it inside the entity for easy access though.
	// the 'using' is Odin/Jai specific and just makes it so you can:
	// 'entity.max_health' instead of 'entity.const_data.max_health'
	//
	//using const_data: Const_Entity_Data,
}

//EntityRect
EntityRect :: struct {
	min, max: Vec2,
	pos:      Vec2,
}

Entity_Orientation :: enum {
	norm,
	rot_left,
	rot_right,
	upside_down,
}
Entity_Direction :: enum {
	nil,
	left,
	right,
	up,
	down,
}

Entity_Movement :: enum {
	idle,
	walking,
	climbing_side,
	climbing_upside_down,
	jumping,
	fall_transition,
	falling,
	running,
	swinging,
	sliding,
}

Entity_Action :: enum {
	nil,
	jumping,
	falling,
	climbing,
	sliding,
}

Const_Entity_Data :: struct {
	update:     proc(_: ^Entity),
	draw:       proc(_: ^Entity),
	icon_image: Texture_Name,
}

EntityKind :: enum {
	nil,
	player,
	goblin,
	ogre,
	big_boss_goblin,
	wood_spikes,
	defense_wall,
}

//creates a random entity of the given kind at the given position	
create_random_entity :: proc(kind: EntityKind, pos: Vec2) {
	fmt.printf("Creating random entity of kind %v at position %v\n", kind, pos)
	hm.add(
		&g.entities,
		Entity {
			anim = animation_create(.Goblin_Idle),
			pos = pos,
			dir = .left,
			vel = {0, 0},
			size = {},
			is_on_ground = true,
			movement = .idle,
			orientation = .norm,
			flip_x = false,
			flip_y = false,
			feet_collider = Rect{},
			face_collider = Rect{},
			head_collider = Rect{},
			corner_collider = Rect{},
			kind = .goblin,
		},
	)
}

create_entity :: proc(kind: EntityKind, pos: Vec2) -> Entity_Handle {
	fmt.printf("Creating entity of kind %v at position %v\n", kind, pos)
	fmt.printf("TODO - Switch for create_entity to split off entity creation\n")
	handle := hm.add(
		&g.entities,
		Entity {
			anim = animation_create(.Goblin_Idle),
			pos = pos,
			dir = .left,
			vel = {0, 0},
			size = {},
			is_on_ground = true,
			movement = .idle,
			orientation = .norm,
			flip_x = false,
			flip_y = false,
			feet_collider = Rect{},
			face_collider = Rect{},
			head_collider = Rect{},
			corner_collider = Rect{},
			kind = .goblin,
		},
	)
	return handle
}

create_player_entity :: proc(pos: Vec2) {
	fmt.printf("Creating player entity at position %v\n", pos)
	g.player_handle = hm.add(
		&g.entities,
		Entity {
			anim = animation_create(.Frog_Idle),
			pos = pos,
			dir = .left,
			vel = {0, 0},
			size = {},
			is_on_ground = true,
			movement = .idle,
			orientation = .norm,
			flip_x = false,
			flip_y = false,
			feet_collider = Rect{},
			face_collider = Rect{},
			head_collider = Rect{},
			corner_collider = Rect{},
			kind = .player,
		},
	)
}

draw_entities :: proc(fade: f32) {
	ENTITES_DRAWN = 0
	//iter := hm.make_iter(&g.entities)
	//     for e in hm.iter(&my_iter) {})
	for &item in g.entities.items {
		if hm.skip(item) {
			// If you want to skip drawing this entity, you can continue here
			continue
		}
		if within_camera_bounds(item.handle) == false {
			// If the entity is not within camera bounds, skip drawing it
			continue
		}

		draw_entity(item.handle, fade)
		ENTITES_DRAWN += 1
	}
	// do stuff
}

draw_entity :: proc(e: Entity_Handle, fade: f32) {
	// draw the entity
	if !hm.valid(g.entities, e) {
		fmt.printf("Entity handle %v is not valid, cannot draw it\n", e)
		return
	}
	draw_entity_generic(e, fade)
}

draw_entity_generic :: proc(entity_handle: Entity_Handle, fade: f32) {
	//fmt.printf("Drawing entity with handle %v\n", entity_handle)
	if !hm.valid(g.entities, entity_handle) {
		fmt.printf("Entity handle %v is not valid, cannot draw it\n", entity_handle)
		return
	}
	ent := hm.get(g.entities, entity_handle)

	if ent == nil {
		fmt.printf("Entity with handle %v not found\n", entity_handle)
		return
	}

	if ent.kind == .nil {
		fmt.printf("Entity with handle %v has no kind set, cannot draw it\n", entity_handle)
		return
	}

	anim_texture := animation_atlas_texture(ent.anim)
	atlas_rect := anim_texture.rect
	offset := Vec2{anim_texture.offset_left, anim_texture.offset_top}

	//flip is based on ent.direction, flipping offset accordingly
	if ent.flip_x {
		atlas_rect.width = -atlas_rect.width
		offset.x = anim_texture.offset_right
	}
	if ent.flip_y {
		atlas_rect.height = -atlas_rect.height
		offset.y = anim_texture.offset_bottom
	}

	//destination rect tells us where on screeen to draw the entity
	//adjusted by the offset
	dest := Rect {
		ent.pos.x + offset.x,
		ent.pos.y + offset.y,
		anim_texture.rect.width,
		anim_texture.rect.height,
	}

	//Handle rotation based on entity orientation
	rotation: f32
	switch (ent.orientation) 
	{
	case .norm:
		if ent.movement == .falling {
			if ent.dir == .right {
				dest.x -= 1
			} else {
				dest.x += 2
			}
		}
	case .rot_left:
		rotation = 270
		dest.x += (anim_texture.rect.width * .5) + 2
		dest.y -= (anim_texture.rect.width) + 2
	case .rot_right:
		rotation = 90
		dest.x -= (anim_texture.rect.width) + 2
		dest.y -= (anim_texture.rect.width * .5)
	case .upside_down:
		dest.y += (anim_texture.rect.height) * 2 + 3
		dest.x -= 1
	}

	//The origin is the the center of the entity
	origin := Vec2 {
		anim_texture.document_size.x / 2,
		anim_texture.document_size.y - 1, // -1 because there's an outline in the player anim that takes an extra pixel
	}

	rl.DrawTexturePro(atlas, atlas_rect, dest, origin, rotation, rl.Fade(rl.WHITE, fade))
	if DEBUG_DRAW_COLLIDERS {
		draw_entity_colliders(entity_handle)
	}
}

draw_entity_colliders :: proc(entity_handle: Entity_Handle) {
	ent := hm.get(g.entities, entity_handle)

	rl.DrawRectangleLines(
		i32(ent.rect.x),
		i32(ent.rect.y),
		i32(ent.rect.width),
		i32(ent.rect.height),
		rl.BLUE,
	)
	rl.DrawRectangleRec(ent.feet_collider, rl.YELLOW)
	rl.DrawRectangleRec(ent.face_collider, rl.ORANGE)
	rl.DrawRectangleRec(ent.head_collider, rl.RED)
	rl.DrawRectangleLinesEx(ent.corner_collider, .25, rl.PINK)
	rl.DrawPixelV(ent.pos, rl.PURPLE)
}

update_entities :: proc(dt: f32) {
	//iter := hm.make_iter(&g.entities)
	//     for e in hm.iter(&my_iter) {})
	for &item in g.entities.items {
		if hm.skip(item) {
			continue
		}

		update_entity_generic(item.handle, dt)
	}
}

update_entity_generic :: proc(entity_handle: Entity_Handle, dt: f32) {
	if !hm.valid(g.entities, entity_handle) {
		fmt.printf("Entity handle %v is not valid, cannot update it\n", entity_handle)
		return
	}

	ent := hm.get(g.entities, entity_handle)
	if ent == nil {
		fmt.printf("Entity with handle %v not found\n", entity_handle)
		return
	}

	if ent.kind == .nil {
		fmt.printf("Entity with handle %v has no kind set, cannot update it\n", entity_handle)
		return
	}

	//const_data := get_const_entity_data(ent.kind)
	//const_data.update(ent)

	#partial switch ent.kind {
	case .player:
		update_player(dt)
	case .goblin:
		update_goblin(entity_handle, dt)
	/*case .ogre:
		update_ogre(entity_handle, dt)
	case .big_boss_goblin:
		update_big_boss_goblin(entity_handle, dt)
	case .wood_spikes:
		update_wood_spikes(entity_handle, dt)
	case .defense_wall:
		update_defense_wall(entity_handle, dt)*/
	}
}

update_goblin :: proc(entity_handle: Entity_Handle, dt: f32) {
	/*player := get_player()
	if !hm.valid(g.entities, entity_handle) {
		fmt.printf("Entity handle %v is not valid, cannot update it\n", entity_handle)
		return
	}

	goblin := hm.get(g.entities, entity_handle)
	if goblin == nil {
		fmt.printf("Entity with handle %v not found\n", entity_handle)
		return
	}

	if !goblin.wall_climbing {
		//fmt.printf("Adding gravity?\n")
		goblin.vel.y += GRAVITY * dt
	} else {
		goblin.vel.y += 0 * dt
	}

	if !goblin.is_on_ground {
		goblin.air_time += dt
		if goblin.air_time > .55 {
			if goblin.movement != .falling {
				goblin.movement = .falling
				goblin.anim = animation_create(.Frog_Fall)
			}
		}
	} else {goblin.air_time = 0}

	//semi random movement
	//if we haven't chose a random direction yet, we do so
	if !goblin.random_move_bool {
		//goblin.random_move_bool = true
		//goblin.move_duration_timer = rand.float32_range(1, 1.5)
		//goblin.move_dir = rand.int31() % 10
	} else {
		if goblin.move_dir == 0 && !goblin.can_fall_right {
			entity_dir_change(entity_handle, .right)
			goblin.input.x += 1
			if goblin.movement != .walking && goblin.is_on_ground {
				goblin.movement = .walking
				goblin.anim = animation_create(.Frog_Move)
			}
		} else if goblin.move_dir == 1 && !goblin.can_fall_left {
			entity_dir_change(entity_handle, .left)
			goblin.input.x -= 1
			if goblin.movement != .walking && goblin.is_on_ground {
				goblin.movement = .walking
				goblin.anim = animation_create(.Frog_Move)
			}
		} else {
			goblin.input.x = 0
			if goblin.movement != .idle && goblin.is_on_ground {
				goblin.movement = .idle
				goblin.anim = animation_create(.Frog_Idle)
			}
		}
		goblin.move_duration += dt
		if goblin.move_duration >= goblin.move_duration_timer {
			goblin.random_move_bool = false
			goblin.move_duration = 0
			goblin.move_duration_timer = 0
			goblin.input.x = 0
			goblin.movement = .idle
			goblin.anim = animation_create(.Frog_Idle)
		}
	}


	if goblin.input.x == 0 && goblin.is_on_ground {
		if goblin.movement != .idle {
			goblin.movement = .idle
			goblin.anim = animation_create(.Frog_Idle)
		}
	}


	//update the y velocity 
	goblin.pos += (goblin.vel * dt)

	//create_trail_effect(&g.particle_system, goblin.pos, goblin.vel)
	// Update animation based on movement
	/*if goblin.movement == .walking {
		goblin.anim = animation_create(.Frog_Move)
	} else if goblin.movement == .idle {
		goblin.anim = animation_create(.Frog_Idle)
	}
	*/
	goblin.input = linalg.normalize0(goblin.input)
	goblin.pos += goblin.input * dt * 75

	has_collided := false
	update_entity_colliders(entity_handle)
	if goblin.orientation != .norm {
		rotate_entity(entity_handle)
	} else {
		//facing left
		if goblin.dir == .left {
			if goblin.movement == .falling {
				goblin.head_collider = {
					goblin.pos.x - (goblin.rect.width / 2) + 2,
					goblin.rect.y,
					4,
					1,
				}
				goblin.feet_collider = {goblin.pos.x, goblin.pos.y, goblin.rect.width / 2, 1}
				goblin.face_collider = {
					goblin.pos.x - (goblin.rect.width / 2),
					goblin.pos.y - (goblin.rect.height * .75),
					1,
					4,
				}
				goblin.corner_collider = {goblin.pos.x + 4, goblin.pos.y, 1, 1}
			} else {
				goblin.head_collider = {
					goblin.pos.x - (goblin.rect.width / 2) + 2,
					goblin.rect.y,
					4,
					1,
				}
				goblin.feet_collider = {
					goblin.pos.x + 2,
					goblin.pos.y,
					goblin.rect.width / 2 - 2,
					1,
				}
				goblin.face_collider = {
					goblin.pos.x - (goblin.rect.width / 2),
					goblin.pos.y - (goblin.rect.height * .75),
					1,
					4,
				}
				goblin.corner_collider = {goblin.pos.x + 4, goblin.pos.y, 1, 1}
			}
			//facing right
		} else if goblin.dir == .right {
			if goblin.movement == .falling {
				goblin.head_collider = {goblin.pos.x, goblin.rect.y, 4, 1}
				goblin.feet_collider = {goblin.rect.x + 1, goblin.pos.y, goblin.rect.width / 2, 1}
				goblin.face_collider = {
					goblin.rect.x + goblin.rect.width,
					goblin.pos.y - goblin.rect.width / 2,
					1,
					4,
				}
				goblin.corner_collider = {goblin.pos.x - 4, goblin.pos.y, 1, 1}
			} else {
				goblin.head_collider = {goblin.pos.x, goblin.rect.y, 4, 1}
				goblin.feet_collider = {goblin.rect.x, goblin.pos.y, goblin.rect.width / 2 - 1, 1}
				goblin.face_collider = {
					goblin.rect.x + goblin.rect.width,
					goblin.pos.y - (goblin.rect.height * .75),
					1,
					4,
				}
				goblin.corner_collider = {goblin.pos.x - 4, goblin.pos.y, 1, 1}
			}

		}
	}

	//checking if we have collided with feet collider - if we aren't moving we are idle. 
	/*for platform in level.platforms {
		if platform.exists {
			//feet collider
			if goblin.action != .jumping {
				if !goblin.side_jump {
					// if we fall off the left side of a platform and we collide with our head, offset player by the platform pos - player.width
					if goblin.movement == .falling {
						if goblin.dir == .right {
							if rl.CheckCollisionRecs(goblin.head_collider, platform.faces[3]) {
								goblin.pos.x = platform.faces[3].x - goblin.rect.width + 1
							}
						}
					}
					if rl.CheckCollisionRecs(goblin.feet_collider, platform.pos_rect) {

						//if face collides with left side of platform then we do not set the player on top
						//set player to be offset by the platform edge
						if goblin.dir == .right && goblin.pos.y < platform.pos_rect.y - 1 {
							return
						}

						goblin.is_on_ground = true
						goblin.vel.y = 0
						goblin.pos.y = platform.pos_rect.y - goblin.size.y - 1
						goblin.platform_index = platform.index

						if goblin.movement != .idle {
							if goblin.input.x == 0 {
								goblin.movement = .idle
								goblin.anim = animation_create(.Frog_Idle)
							}
						}
						has_collided = true
					}
				}
			}
		}
	}*/

	//if we have not collided with any platforms, we are not grounded
	if !has_collided && !goblin.wall_climbing {
		if goblin.movement != .jumping {
			goblin.is_on_ground = false
			//If player walked off a platform, we want to delay the falling animation
			if goblin.movement == .walking {
				goblin.movement = .fall_transition
			} else {
				if goblin.vel.y > 0 {
					if goblin.movement != .falling {
						goblin.orientation = .norm
						goblin.movement = .falling
						goblin.anim = animation_create(.Frog_Fall)
					}
				} else if goblin.vel.y < 0 {
					if goblin.movement != .jumping {
						//fmt.printf("Jumping\n")
						goblin.movement = .jumping
						goblin.anim = animation_create(.Frog_Jump)
					}
				}
			}
		}
	}

	//check corner of current platform
	for c in level.platforms[goblin.platform_index].corners {
		if rl.CheckCollisionRecs(goblin.corner_collider, c) {
			if goblin.dir == .left {
				goblin.can_fall_left = true
				goblin.can_fall_right = false
				goblin.dir = .right
			} else {
				goblin.can_fall_right = true
				goblin.can_fall_left = false
				goblin.dir = .left
			}

			if goblin.movement != .idle {
				if goblin.input.x != 0 {
					goblin.input = {0, 0}
					goblin.random_move_bool = false
					goblin.move_duration = 0
					goblin.move_duration_timer = 0
					goblin.movement = .idle
					goblin.anim = animation_create(.Frog_Idle)
				}
			}
		}
	}

	//if we have not collided with any platforms, we are not grounded
	if !has_collided {
		//If player walked off a platform, we want to delay the falling animation
		if goblin.movement == .walking {
			goblin.movement = .fall_transition
		} else {
			if goblin.vel.y > 0 {
				if goblin.movement != .falling {
					goblin.orientation = .norm
					goblin.movement = .falling
					goblin.anim = animation_create(.Frog_Fall)
				}
			}
		}
	}

	update_entity_colliders(entity_handle)
	animation_update(&goblin.anim, dt)

	if goblin.orientation == .upside_down {
		goblin.flip_y = true
		if goblin.dir == .right {
			goblin.flip_x = true
		} else {
			goblin.flip_x = false
		}
	} else {
		goblin.flip_y = false
	}*/
}

rotate_entity :: proc(entity_handle: Entity_Handle) {
	if !hm.valid(g.entities, entity_handle) {
		fmt.printf("Entity handle %v is not valid, cannot rotate it\n", entity_handle)
		return
	}

	ent := hm.get(g.entities, entity_handle)
	if ent == nil {
		fmt.printf("Entity with handle %v not found, cannot rotate it\n", entity_handle)
		return
	}

	#partial switch (ent.orientation) 
	{
	case .rot_left:
		ent.jumping_direction = .left
		if ent.dir == .left {
			//Left == facing down
			ent.corner_collider = {ent.pos.x, ent.pos.y - 3, 1, 1}
			ent.feet_collider = {ent.pos.x, ent.pos.y - ent.rect.height / 2, 1, 6}
			ent.head_collider = {ent.rect.x, ent.rect.y + (ent.rect.height * .5), 1, 4}
			ent.face_collider = {
				ent.pos.x - (ent.rect.width * .75),
				ent.pos.y + (ent.rect.height / 2),
				4,
				1,
			}
		} else if ent.dir == .right {
			//Right = facing up 
			ent.corner_collider = {ent.pos.x, ent.pos.y + 3, 1, 1}
			ent.feet_collider = {
				ent.rect.x + ent.rect.width - 1,
				ent.rect.y + ent.rect.height / 2,
				1,
				6,
			}
			ent.head_collider = {ent.rect.x, ent.rect.y + (ent.rect.height * .5), 1, 4}
			ent.face_collider = {
				ent.pos.x - (ent.rect.width * .75),
				ent.pos.y + (ent.rect.height / 2),
				4,
				1,
			}
		}

	//hanging on a wall on the left of player
	case .rot_right:
		ent.jumping_direction = .right
		if ent.dir == .right {
			//Right = facing down 
			ent.corner_collider = {ent.pos.x, ent.pos.y - 3, 1, 1}
			//ent.corner_collider = {ent.pos.x + 4, ent.pos.y - 2, 4, 4}
			ent.feet_collider = {ent.pos.x, ent.pos.y - ent.rect.height / 2, 1, 6}
		} else if ent.dir == .left {
			//Left == facing up
			ent.corner_collider = {ent.pos.x, ent.pos.y + 3, 1, 1}
			ent.feet_collider = {ent.pos.x, ent.pos.y, 1, 6}
		}
	case .upside_down:
		ent.jumping_direction = .down
		if ent.dir == .left {
			//Right = facing down 
			ent.corner_collider = {ent.pos.x - 3, ent.pos.y, 1, 1}
			//ent.corner_collider = {ent.pos.x + 4, ent.pos.y - 2, 4, 4}
			ent.feet_collider = {ent.pos.x - ent.rect.width / 2, ent.pos.y, 6, 1}
		} else if ent.dir == .right {
			//Left == facing up
			ent.corner_collider = {ent.pos.x + 3, ent.pos.y, 1, 1}
			ent.feet_collider = {ent.pos.x, ent.pos.y, 5, 1}
		}
	}
}

update_entity_colliders :: proc(entity_handle: Entity_Handle) {
	ent := hm.get(g.entities, entity_handle)
	if ent == nil {
		fmt.printf("Entity with handle %v not found, cannot update colliders\n", entity_handle)
		return
	}

	r := animation_atlas_texture(ent.anim).rect
	p_width, p_height: f32
	switch (ent.orientation) 
	{
	case .norm:
		p_width = r.width
		p_height = r.height
		if ent.movement == .falling {
			ent.rect = {ent.pos.x - p_width / 2, ent.pos.y - p_height + 1.5, p_width, p_height}
		} else {
			ent.rect = {ent.pos.x - p_width / 2, ent.pos.y - p_height + 1, p_width, p_height}
		}
	case .rot_left:
		p_width = r.height
		p_height = r.width
		ent.rect = {ent.pos.x - p_width + 1, ent.pos.y - p_height / 2, p_width, p_height}
	case .rot_right:
		p_width = r.height
		p_height = r.width
		ent.rect = {ent.pos.x, ent.pos.y - p_height / 2 + 1.5, p_width, p_height}
	case .upside_down:
		p_width = r.width
		p_height = r.height
		ent.rect = {ent.pos.x - p_width / 2, ent.pos.y, p_width, p_height}
	}

}


entity_dir_change :: proc(e: Entity_Handle, dir: Entity_Direction) {
	if !hm.valid(g.entities, e) {
		fmt.printf("Entity handle %v is not valid, cannot check direction\n", e)
		return
	}
	ent := hm.get(g.entities, e)

	#partial switch dir {
	case .left:
		ent.dir = .left
		ent.flip_x = true
	case .right:
		ent.dir = .right
		ent.flip_x = false
	}

}
