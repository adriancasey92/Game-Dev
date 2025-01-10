#pragma once
#include "Common.h"
#include "State.h"

class Game;

class PlayState : public State
{
public:
	PlayState() { 
		game = nullptr; 
		graphics = nullptr; 
		resource = nullptr; };

	PlayState(Game* g
		, Graphics* gfx
		, ResourceManager* r) 
		: game(g)
		, graphics(gfx)
		, resource(r){};

	~PlayState() { SDL_Log("PlayState::~PlayState()"); };

	bool Init();
	void Cleanup();
	void Pause();
	void Resume();

	void LoadMedia();
	void LoadObjects();

	void HandleEvents(SDL_Event e);
	void KeyPress(SDL_KeyboardEvent& k);
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
	std::unordered_map<std::string, Object*> objects;
};
