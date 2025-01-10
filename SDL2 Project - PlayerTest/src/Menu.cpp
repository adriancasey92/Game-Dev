#include "Menu.h"
#include "Button.h"

Menu::~Menu()
{
	SDL_Log("Menu::~Menu() - Deconstructor called.");
}

void Menu::AddButton(Button* b)
{
	
}

void Menu::DisplayButtons()
{
	for (auto& it : buttons)
	{
		graphics->Draw(it);
	}
}

void Menu::HandleEvent(SDL_Event& e)
{
	for (auto& it : buttons)
	{
		it->HandleEvent(e);
	}
}
