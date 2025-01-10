#pragma once
#include "Common.h"
#include "State.h"

class Game;

class IntroState : public State
{
public:

	IntroState() { 
		game = nullptr; 
		graphics = nullptr; 
		resource = nullptr; };

	IntroState(Game* g
		, Graphics* gfx
		, ResourceManager* r) 
		: game(g)
		, graphics(gfx)
		, resource(r){};

	~IntroState() { SDL_Log("IntroState::~IntroState()"); };

    bool Init() override;
	void Cleanup();
	void Pause();
	void Resume();

	void ChangeState();
	
	void LoadMedia();
	void Update();
	void Draw();

	//EVENTS
	void HandleEvents(SDL_Event e);
	void KeyPress(SDL_KeyboardEvent& k);
	void MousePress(SDL_MouseButtonEvent& e);

protected:
	
private:
	Game* game;
	Graphics* graphics;
	ResourceManager* resource;
	std::unordered_map<std::string, SDL_Texture*> textures;
};
