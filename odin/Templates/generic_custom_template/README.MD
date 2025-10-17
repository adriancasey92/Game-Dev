# Odin - Custom Template!

This template contains the following:
* [Hot-Reload template](https://github.com/karl-zylinski/odin-raylib-hot-reload-game-template) - Karl Z.
* [Handle-Map library](https://github.com/karl-zylinski/odin-handle-map) - Karl Z.
* [Atlas-Map library](https://github.com/karl-zylinski/atlas-builder) - Karl Z.

I have also created the following:

* Quadtree.odin - Flat array quadtree structure that is adapted to use Handles from the handle_map library
* Chunk_converter.odin - Level serialization package that loads/unloads into JSON and Binary formats. 
                  
Modifications:

- build_hot_reload.bat - Added in Atlas-Map build line to allow user to hot-reload and generate new atlas. 
                    NOTE: This can cause problems and often times requires a restart, as some textures may
                          cease to work. 
