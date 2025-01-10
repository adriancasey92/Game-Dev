#pragma once
#include "Common.h"

class Button
{	
	public:
		Button()
			:texture(nullptr)
			,fontTexture(nullptr)
			, bPos{0,0,0,0}
			, tPos{ 0,0,0,0 }
			, clips()
			, label(""), name("")
			, mouseOver(false) {};
		Button(SDL_Texture* tx, SDL_Texture* fontTex,std::string label, int x, int y);

		void HandleEvent(SDL_Event& e);
		void OnMouseOver();
		void CheckMouseOver();

		const std::string GetLabel() const { return label; };
		void SetLabel(const std::string newLabel) { label = newLabel; };
		void DrawButtons();


		SDL_Texture* GetTexture() { return texture; };
		SDL_Texture* GetTextTexture() { return fontTexture; };
		void SetTextWidth(int width, int height) { tPos.w = width;tPos.h = height; };
		SDL_Rect GetTextRect() { return tPos; };
		int GetWidth() const { return bPos.w; };
		void SetWidth(int width) { bPos.w = width; };
		int GetHeight() const { return bPos.h; };
		void SetHeight(int height) { bPos.h = height; };

		void SetPos(int x, int y) {
			printf("Setting Pos x,y : %i,%i\n",x,y);bPos.x = x; bPos.y = y;
		};
		SDL_Rect GetPos() { return bPos; };

		bool GetMouseOver() const { return mouseOver; };
		SDL_Rect GetClips();
		void PrintPos()
		{
			printf("Pos %s:\nposX: %i\nposY: %i", label.c_str(), bPos.x, bPos.y);
		}
	private:
		SDL_Texture* texture;
		SDL_Texture* fontTexture;
		bool mouseOver;
		std::string name;
		std::string label;

		SDL_Rect bPos;
		SDL_Rect tPos;
		SDL_Rect clips[2];
};