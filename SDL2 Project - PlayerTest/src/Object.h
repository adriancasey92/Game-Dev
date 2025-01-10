#pragma once
#include "Common.h"

class Game;
class Graphics;

class Object
{
	public:
		Object() {
			game = nullptr;
			graphics = nullptr;
			texture = nullptr;
			x = 0; y = 0;vx = 0;vy = 0;w = 0;h = 0;
			texName = "";
			//SDL_Log("TODO - DEFINE OBJECT CLIP RECT");
		};

		Object(Game* g, Graphics* gfx, SDL_Texture* tex) 
			: game(g), graphics(gfx), texture(tex)
			, x(0), y(0)
			, vx(0), vy(0)
			, w(0), h(0)
			, texName("") {};

		virtual ~Object() {};

		//virtual void Init() = 0;
		virtual void Update() = 0;

		virtual int GetPosX() const = 0;
		virtual int GetPosY() const = 0;
		virtual int GetWidth() const = 0;
		virtual int GetHeight() const = 0;

		virtual void HandleEvent(SDL_Event& e) = 0;
		virtual SDL_Texture* GetTexture() = 0;
		virtual std::string GetTexName() = 0;

	private:
		std::string texName;
		int x, y, vx, vy, w, h;
		
		SDL_Texture* texture;
		Game* game;
		Graphics* graphics;
};