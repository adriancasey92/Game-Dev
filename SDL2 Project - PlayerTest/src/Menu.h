#pragma once
#include "Common.h"
#include "Graphics.h"

class Button;

class Menu
{
public:
	Menu(Graphics* gfx) : graphics(gfx) { buttons.clear(); };
	~Menu();
	void AddButton(Button* b);
	void DisplayButtons();
	void HandleEvent(SDL_Event& e);
	

private:
	std::vector<Button*> buttons;
	Graphics* graphics;
};