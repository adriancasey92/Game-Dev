package game

import "core:fmt"
import os "core:os"
import rl "vendor:raylib"

Font :: struct {
	texture: rl.Texture2D,
	glyphs:  []rl.GlyphInfo,
}
