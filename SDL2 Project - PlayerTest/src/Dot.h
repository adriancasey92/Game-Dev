#pragma once
#include "Common.h"
#include "Object.h"
#include "Graphics.h"

class Dot : public Object
{
public:
	Dot(Game* g, Graphics* gfx, SDL_Texture* tex)
		: game(g), graphics(gfx), texture(tex)
		, x(0), y(0)
		, vx(0), vy(0)
		, w(16), h(16)
		, texName("player.png") {
	};
	~Dot() {};

	void Init();

	void Update();
	int GetPosX() const { return x; };
	int GetPosY() const { return y; };
	int GetWidth() const { return w; };
	int GetHeight() const { return h; };

	void HandleEvent(SDL_Event& e);
	void Move();

	void Print() const;

	std::string GetTexName() { return texName; };
	SDL_Texture* GetTexture() { return texture; };

private:
	//Position
	const int VEL = 10;
	int x, y, vx, vy, w, h;
	std::string texName;
	SDL_Texture* texture;
	Game* game;
	Graphics* graphics;
};