#pragma once
#include "Common.h"
#include "State.h"

class Game;

class MenuState : public State
{
public:
	MenuState() { 
		game = nullptr; 
		graphics = nullptr; 
		resource = nullptr; 
		mouseOver = nullptr;
	};

	MenuState(Game* g
		, Graphics* gfx
		, ResourceManager* r) 
		: game(g)
		, graphics(gfx)
		, resource(r)
		, mouseOver(nullptr){};

	~MenuState() { SDL_Log("MenuState::~PlayState()"); };

	bool Init();
	void Cleanup();
	void Pause();
	void Resume();

	void LoadMedia();
	void HandleEvents(SDL_Event e);
	void KeyPress(SDL_KeyboardEvent& k);

	void AdjustElements();


	void MousePress(SDL_MouseButtonEvent& e);
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
