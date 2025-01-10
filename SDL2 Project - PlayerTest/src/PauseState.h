#pragma once
#include "Common.h"
#include "State.h"

class Game;

class PauseState : public State
{
public:
	PauseState() {
		game = nullptr;
		graphics = nullptr;
		resource = nullptr;
		mouseOver = nullptr;
	};

	PauseState(Game* g
		, Graphics* gfx
		, ResourceManager* r)
		: game(g)
		, graphics(gfx)
		, resource(r)
		, mouseOver(nullptr) {
	};

	~PauseState() { SDL_Log("PauseState::~PlayState()"); };

	bool Init();
	void Cleanup();
	void Pause();
	void Resume();

	void LoadMedia();
	void HandleEvents(SDL_Event e);
	void KeyPress(SDL_KeyboardEvent k);
	void MousePress(SDL_MouseButtonEvent& e);

	void AdjustElements();

	void ChangeState();
	void Update();
	void Draw();
protected:

private:
	Game* game;
	Graphics* graphics;
	ResourceManager* resource;
	std::unordered_map<std::string, SDL_Texture*> textures;
	std::vector<Button*> buttons;

	Button* mouseOver;
};
