#pragma once
#include "Common.h"

class Object;
class Button;
class Menu;

class Graphics
{
public:
	Graphics();
	~Graphics();

	bool Init();

	void HandleEvents(SDL_Event e);

	void Clear();
	void Display();
	void Draw(SDL_Texture* texture);
	SDL_Texture* GetTextFromString(std::string);
	void DrawText(std::string text, int x, int y, int padW, int padH);
	void Draw(SDL_Texture* texture, SDL_Rect dst, SDL_Rect clip);
	void Draw(SDL_Texture* texture, SDL_Rect dst);
	void Draw(SDL_Texture* texture, int x, int y, SDL_Rect clip);
	void Draw(SDL_Texture* texture, int x, int y);
	void Draw(Object* object);
	//void Draw(Button* button, int x, int y, SDL_Rect clip);
	void Draw(Button* button);

	int GetResolutionWidth() const { return resWidth; }
	int GetWidth() const { return width; }
	int GetResolutionHeight()const { return resHeight; }
	int GetHeight() const { return height; }
	float GetGuiScale() const { return guiScale; }

	void Pause();
	void Resize(SDL_Event e);
	
	SDL_Window* GetWindow() const { return window; }
	SDL_Renderer* getRenderer() const { return renderer; }

private:
	SDL_Window* window;
	SDL_Renderer* renderer;
	TTF_Font* font;

	SDL_Texture* paused;

	bool mouseFocus;
	bool keyboardFocus;
	bool minimized;

	int width{};
	int height{};
	int textSize{};
	float guiScale{};
	int resWidth{};
	int resHeight{};
};