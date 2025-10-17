package game
import hm "../handle_map"
import "core:fmt"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"


update_goblin :: proc(entity_handle: Entity_Handle, dt: f32) {
	player := get_player()
	if !hm.valid(g.entities, entity_handle) {
		fmt.printf("Entity handle %v is not valid, cannot update it\n", entity_handle)
		return
	}

	goblin := hm.get(g.entities, entity_handle)
	if goblin == nil {
		fmt.printf("Entity with handle %v not found\n", entity_handle)
		return
	}

	//semi random movement
	//if we haven't chose a random direction yet, we do so
	/*if !goblin.random_move_bool {
		goblin.random_move_bool = true
		goblin.move_duration_timer = rand.float32_range(1, 1.5)
		goblin.move_dir = rand.int31() % 10
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
	}*/


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

	//has_collided := false
	//update_entity_colliders(entity_handle)

	/*if goblin.orientation != .norm {
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
	}*/

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
	/*if !has_collided && !goblin.wall_climbing {
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
	}*/

	//check corner of current platform
	/*for c in level.platforms[goblin.platform_index].corners {
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
	}*/

	//if we have not collided with any platforms, we are not grounded
	/*if !has_collided {
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
	}*/

	//update_entity_colliders(entity_handle)
	animation_update(&goblin.anim, dt)

	/*if goblin.orientation == .upside_down {
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
