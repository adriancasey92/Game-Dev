#include "State.h"
#include "Common.h"

State::State() {
    // Initialize state (e.g., menu, level, etc.)
}

State::~State() {
    // Cleanup state-specific resources
}

void State::Update() {
    // Update logic (e.g., game objects, physics, etc.)
    HandleStateLogic();
}

void State::Draw(Graphics& graphics) {
    // Render state-specific elements
    std::cout << "Rendering state..." << std::endl;
    graphics.Draw(); // Draw elements to the screen (graphics)
}

void State::HandleStateLogic() {
    // Handle game logic specific to this state (e.g., menus, levels, etc.)
    std::cout << "Handling state logic..." << std::endl;
}
