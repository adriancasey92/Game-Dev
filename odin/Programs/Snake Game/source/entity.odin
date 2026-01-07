package game

import hm "../handle_map"
import "core:fmt"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

MAX_ENTITIES :: 15000

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
	//action:              Entity_Action,
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

	//NPC Entity movement variables
	random_move_bool:    bool,
	random_jump_bool:    bool,
	can_fall_right:      bool,
	can_fall_left:       bool,
	move_dir:            i32,
	move_duration:       f32,
	move_duration_timer: f32,
	jump_timer:          f32,
	jump_duration:       f32,

	// debug
	debug_draw_bool:     bool,
}

//Entity Bounds/Rectangle
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

/*Entity_Action :: enum {
	nil,
	jumping,
	falling,
	climbing,
	sliding,
}*/

/*Const_Entity_Data :: struct {
	update:     proc(_: ^Entity),
	draw:       proc(_: ^Entity),
	icon_image: Texture_Name,
}*/

EntityKind :: enum {
	nil,
	player,
	bullfrog,
	goblin,
}

//creates a random entity of the given kind at the given position	
create_random_entity :: proc(kind: EntityKind, pos: Vec2) {
	fmt.printf("Creating random entity of kind %v at position %v\n", kind, pos)

	r_num := rand.int31_max(3)

	switch r_num {
	case 1:
		create_player_entity(pos)
	case 2:
		create_bullfrog(pos)
	case 3:
		create_goblin(pos)
	}
}

create_entity :: proc(kind: EntityKind, pos: Vec2) -> Entity_Handle {
	fmt.printf("Creating entity of kind %v at position %v\n", kind, pos)
	//fmt.printf("TODO - Switch for create_entity to split off entity creation\n")

	switch kind {
	case .player:
		handle := create_player_entity(pos)
	case .bullfrog:
		handle := create_bullfrog(pos)
	case .goblin:
		handle := create_goblin(pos)
	case .nil:
		fmt.printf("Entity kind %v not recognized, cannot create entity\n", kind)
	}
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
			kind = kind,
		},
	)
	return handle
}

create_bullfrog :: proc(pos: Vec2) -> Entity_Handle {
	handle := hm.add(
		&g.entities,
		Entity {
			anim = animation_create(.Bullfrog_Idle),
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
			kind = .bullfrog,
		},
	)
	return handle
}

create_goblin :: proc(pos: Vec2) -> Entity_Handle {
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
	case .bullfrog:
		update_enemy_generic(entity_handle, dt)
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

update_enemy_generic :: proc(entity_handle: Entity_Handle, dt: f32) {
	//player := get_player()
	if !hm.valid(g.entities, entity_handle) {
		fmt.printf("Entity handle %v is not valid, cannot update it\n", entity_handle)
		return
	}
	ent := hm.get(g.entities, entity_handle)
	if ent == nil {
		fmt.printf("Entity with handle %v not found\n", entity_handle)
		return
	}
	ent.is_on_ground = true
	//semi random movement
	//if we haven't chose a random direction yet, we do so
	if !ent.random_move_bool {
		ent.random_move_bool = true
		ent.move_duration_timer = rand.float32_range(1, 1.5)
		ent.move_dir = rand.int31() % 10
	} else {
		if ent.move_dir == 0 && !ent.can_fall_right {
			entity_dir_change(entity_handle, .right)
			ent.input.x += 1
			if ent.movement != .walking && ent.is_on_ground {
				ent.movement = .walking
				ent.anim = create_non_player_anim_from_kind(ent)
			}
		} else if ent.move_dir == 1 && !ent.can_fall_left {
			entity_dir_change(entity_handle, .left)
			ent.input.x -= 1
			if ent.movement != .walking && ent.is_on_ground {
				ent.movement = .walking
				ent.anim = create_non_player_anim_from_kind(ent)
			}
		} else {
			ent.input.x = 0
			if ent.movement != .idle && ent.is_on_ground {
				ent.movement = .idle
				ent.anim = create_non_player_anim_from_kind(ent)
			}
		}
		ent.move_duration += dt
		if ent.move_duration >= ent.move_duration_timer {
			ent.random_move_bool = false
			ent.move_duration = 0
			ent.move_duration_timer = 0
			ent.input.x = 0
			ent.movement = .idle
			ent.anim = create_non_player_anim_from_kind(ent)
		}
	}

	if ent.input.x == 0 && ent.is_on_ground {
		if ent.movement != .idle {
			ent.movement = .idle
			ent.anim = create_non_player_anim_from_kind(ent)

		}
	}


	//update the y velocity 
	ent.pos += (ent.vel * dt)

	//create_trail_effect(&g.particle_system, ent.pos, ent.vel)
	// Update animation based on movement
	/*if ent.movement == .walking {
		ent.anim = animation_create(.Frog_Move)
	} else if ent.movement == .idle {
		ent.anim = animation_create(.Frog_Idle)
	}*/

	ent.input = linalg.normalize0(ent.input)
	ent.pos += ent.input * dt * 75

	//has_collided := false
	update_entity_colliders(entity_handle)

	if ent.orientation != .norm {
		rotate_entity(entity_handle)
	} else {
		//facing left
		if ent.dir == .left {
			if ent.movement == .falling {
				ent.head_collider = {ent.pos.x - (ent.rect.width / 2) + 2, ent.rect.y, 4, 1}
				ent.feet_collider = {ent.pos.x, ent.pos.y, ent.rect.width / 2, 1}
				ent.face_collider = {
					ent.pos.x - (ent.rect.width / 2),
					ent.pos.y - (ent.rect.height * .75),
					1,
					4,
				}
				ent.corner_collider = {ent.pos.x + 4, ent.pos.y, 1, 1}
			} else {
				ent.head_collider = {ent.pos.x - (ent.rect.width / 2) + 2, ent.rect.y, 4, 1}
				ent.feet_collider = {ent.pos.x + 2, ent.pos.y, ent.rect.width / 2 - 2, 1}
				ent.face_collider = {
					ent.pos.x - (ent.rect.width / 2),
					ent.pos.y - (ent.rect.height * .75),
					1,
					4,
				}
				ent.corner_collider = {ent.pos.x + 4, ent.pos.y, 1, 1}
			}
			//facing right
		} else if ent.dir == .right {
			if ent.movement == .falling {
				ent.head_collider = {ent.pos.x, ent.rect.y, 4, 1}
				ent.feet_collider = {ent.rect.x + 1, ent.pos.y, ent.rect.width / 2, 1}
				ent.face_collider = {
					ent.rect.x + ent.rect.width,
					ent.pos.y - ent.rect.width / 2,
					1,
					4,
				}
				ent.corner_collider = {ent.pos.x - 4, ent.pos.y, 1, 1}
			} else {
				ent.head_collider = {ent.pos.x, ent.rect.y, 4, 1}
				ent.feet_collider = {ent.rect.x, ent.pos.y, ent.rect.width / 2 - 1, 1}
				ent.face_collider = {
					ent.rect.x + ent.rect.width,
					ent.pos.y - (ent.rect.height * .75),
					1,
					4,
				}
				ent.corner_collider = {ent.pos.x - 4, ent.pos.y, 1, 1}
			}

		}
	}

	//checking if we have collided with feet collider - if we aren't moving we are idle. 
	/*for platform in level.platforms {
		if platform.exists {
			//feet collider
			if ent.action != .jumping {
				if !ent.side_jump {
					// if we fall off the left side of a platform and we collide with our head, offset player by the platform pos - player.width
					if ent.movement == .falling {
						if ent.dir == .right {
							if rl.CheckCollisionRecs(ent.head_collider, platform.faces[3]) {
								ent.pos.x = platform.faces[3].x - ent.rect.width + 1
							}
						}
					}
					if rl.CheckCollisionRecs(ent.feet_collider, platform.pos_rect) {

						//if face collides with left side of platform then we do not set the player on top
						//set player to be offset by the platform edge
						if ent.dir == .right && ent.pos.y < platform.pos_rect.y - 1 {
							return
						}

						ent.is_on_ground = true
						ent.vel.y = 0
						ent.pos.y = platform.pos_rect.y - ent.size.y - 1
						ent.platform_index = platform.index

						if ent.movement != .idle {
							if ent.input.x == 0 {
								ent.movement = .idle
								ent.anim = animation_create(.Frog_Idle)
							}
						}
						has_collided = true
					}
				}
			}
		}
	}*/

	//if we have not collided with any platforms, we are not grounded
	/*if !has_collided && !ent.wall_climbing {
		if ent.movement != .jumping {
			ent.is_on_ground = false
			//If player walked off a platform, we want to delay the falling animation
			if ent.movement == .walking {
				ent.movement = .fall_transition
			} else {
				if ent.vel.y > 0 {
					if ent.movement != .falling {
						ent.orientation = .norm
						ent.movement = .falling
						ent.anim = animation_create(.Frog_Fall)
					}
				} else if ent.vel.y < 0 {
					if ent.movement != .jumping {
						//fmt.printf("Jumping\n")
						ent.movement = .jumping
						ent.anim = animation_create(.Frog_Jump)
					}
				}
			}
		}
	}*/

	//check corner of current platform
	/*for c in level.platforms[ent.platform_index].corners {
		if rl.CheckCollisionRecs(ent.corner_collider, c) {
			if ent.dir == .left {
				ent.can_fall_left = true
				ent.can_fall_right = false
				ent.dir = .right
			} else {
				ent.can_fall_right = true
				ent.can_fall_left = false
				ent.dir = .left
			}

			if ent.movement != .idle {
				if ent.input.x != 0 {
					ent.input = {0, 0}
					ent.random_move_bool = false
					ent.move_duration = 0
					ent.move_duration_timer = 0
					ent.movement = .idle
					ent.anim = animation_create(.Frog_Idle)
				}
			}
		}
	}*/

	//if we have not collided with any platforms, we are not grounded
	/*if !has_collided {
		//If player walked off a platform, we want to delay the falling animation
		if ent.movement == .walking {
			ent.movement = .fall_transition
		} else {
			if ent.vel.y > 0 {
				if ent.movement != .falling {
					ent.orientation = .norm
					ent.movement = .falling
					ent.anim = animation_create(.Frog_Fall)
				}
			}
		}
	}*/

	update_entity_colliders(entity_handle)

	animation_update(&ent.anim, dt)

	if ent.orientation == .upside_down {
		ent.flip_y = true
		if ent.dir == .right {
			ent.flip_x = true
		} else {
			ent.flip_x = false
		}
	} else {
		ent.flip_y = false
	}
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

//Updates collision boxes. 
//TODO - Fix this, the implementation is awful.
//Pulls the current animation texture from the atlas, and uses that rect to adjust
//the collision boxes.
update_entity_colliders :: proc(entity_handle: Entity_Handle) {
	p := hm.get(g.entities, entity_handle)
	if p == nil {
		fmt.printf("Err - Player pointer nil!\n")
		return
	}
	r := animation_atlas_texture(p.anim).rect
	p_width, p_height: f32
	p_width = r.width
	p_height = r.height
	if p.movement == .falling {
		p.rect = {p.pos.x - p_width / 2, p.pos.y - p_height, p_width, p_height}
	} else {
		p.rect = {p.pos.x - p_width / 2, p.pos.y - p_height, p_width, p_height}
	}

	//Not used currently
	/*switch (p.orientation) 
	{
	case .norm:
	case .rot_left:
		p_width = r.height
		p_height = r.width
		p.rect = {p.pos.x - p_width + 1, p.pos.y - p_height / 2, p_width, p_height}
	case .rot_right:
		p_width = r.height
		p_height = r.width
		p.rect = {p.pos.x, p.pos.y - p_height / 2 + 1.5, p_width, p_height}
	case .upside_down:
		p_width = r.width
		p_height = r.height
		p.rect = {p.pos.x - p_width / 2, p.pos.y, p_width, p_height}
	}*/
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

create_non_player_anim_from_kind :: proc(entity: ^Entity) -> Animation {
	anim_name := Animation_Name.None
	#partial switch entity.kind {
	case .goblin:
		#partial switch entity.movement {
		case .idle:
			anim_name = .Goblin_Idle
		case .walking:
			anim_name = .Goblin_Move
		case .jumping:
			anim_name = .Goblin_Jump
		case .falling:
			anim_name = .Goblin_Fall
		case .running:
			anim_name = .Goblin_Move
		case .sliding:
			anim_name = .Goblin_Slide
		}
	case .bullfrog:
		#partial switch entity.movement {
		case .idle:
			anim_name = .Bullfrog_Idle
		case .walking:
			anim_name = .Bullfrog_Move
		case .jumping:
			anim_name = .Bullfrog_Jump
		case .falling:
			anim_name = .Bullfrog_Fall
		case .running:
			anim_name = .Bullfrog_Move
		case .sliding:
			anim_name = .Bullfrog_Slide
		}
	}
	return animation_create(anim_name)
}
