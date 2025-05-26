package main

import hm "/handle_map"
import "core:time"
import rl "vendor:raylib"

Entity_Handle :: distinct hm.Handle
entities: hm.Handle_Map(Entity, Entity_Handle, 100000)
entity_add_at: time.Time

Entity :: struct {
	handle: Entity_Handle,
	pos:    Vec2,
	size:   f32,
	color:  rl.Color,
}
