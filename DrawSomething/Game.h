//
//  Game.hpp
//  DrawSomething
//
//  Created by Neil Singh on 3/26/16.
//  Copyright © 2016 Neil Singh. All rights reserved.
//

#ifndef Game_hpp
#define Game_hpp

#import <Cocoa/Cocoa.h>
#include <stdio.h>
#include "Messages.h"
#import "CoreWebSocket/CoreWebSocket.h"

extern bool started;
extern WebSocketClient* drawer;
extern int timeLeft;
extern NSString* word;

extern NSString* wordPath;
extern NSMutableArray* words;

bool LoadWords();

void StartGame(WebSocket* socket, bool initial);
void StartTurn(WebSocket* socket);
void CheckMatch(WebSocket* socket, NSDictionary* map);
void EndTurn(WebSocket* socket, bool timer);
void EndGame(WebSocket* socket);

#endif /* Game_hpp */
