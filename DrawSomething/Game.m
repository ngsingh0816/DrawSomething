//
//  Game.cpp
//  DrawSomething
//
//  Created by Neil Singh on 3/26/16.
//  Copyright © 2016 Neil Singh. All rights reserved.
//

#include "Game.h"
#include <pthread.h>

NSString* wordPath = @"medium";
NSMutableArray* words = nil;
bool started = false;
bool playing = false;
WebSocketClient* drawer = NULL;
int timeLeft = 90;
NSString* word = @"";
bool exitTiming = false;
bool canMatch = false;

pthread_t timingThread;

bool LoadWords() {
	FILE* file = fopen([ [ NSString stringWithFormat:@"%@/Words/%@.txt", [ [ NSBundle mainBundle ] resourcePath ], wordPath ] UTF8String ], "r");
	if (!file)
		return false;
	
	words = [ NSMutableArray array ];
	char line[256];
	while (fgets(line, sizeof(line), file)) {
		NSString* str = [ NSString stringWithFormat:@"%s", line ];
		[ words addObject:[ str substringToIndex:[ str length ] - 1 ] ];
	}
	
	fclose(file);
	
	return true;
}

NSTimer* countTimer = nil;
@interface Controller : NSObject
@end

@implementation Controller

+ (void) countTime:(NSTimer*)timer {
	WebSocket* socket = (WebSocket*)[ [ timer userInfo ] pointerValue ];
	
	NSMutableDictionary* map = [ NSMutableDictionary dictionary ];
	map[@"type"] = @"time";
	timeLeft--;
	if ((timeLeft == 0 && playing) || !PlayerContains(drawer)) {
		map[@"time"] = @0;
		NSString* data = JSONSerialize(map);
		WebSocketWriteWithString(socket, (__bridge CFStringRef)data);
		
		SendSystemMessage(socket, [ NSString stringWithFormat:@"Nobody guessed the word in time. The word was <b>%@</b>.", word ]);
		
		EndTurn(socket, false);
		[ countTimer invalidate ];
	}
	
	map[@"time"] = @(timeLeft);
	
	NSString* data = JSONSerialize(map);
	WebSocketWriteWithString(socket, (__bridge CFStringRef)data);
		
	if (exitTiming) {
		[ countTimer invalidate ];
	}
}

- (void) restart:(NSValue*)socket {
	exitTiming = false;
	if (started)
		StartGame((WebSocket*)[ socket pointerValue ], false);
}

- (void) restartTurn:(NSValue*)socket {
	exitTiming = false;
	if (started)
		StartTurn((WebSocket*)[ socket pointerValue ]);
}

@end

void StartGame(WebSocket* socket, bool intial) {
	started = true;
	if (intial)
		drawer = socket->clients[0];
	
	for (Player* player in players)
		player.score = 0;
	
	SendSystemMessage(socket, @"Starting...");
	
	StartTurn(socket);
}

void StartTurn(WebSocket* socket) {
	timeLeft = 90;
	if ([ words count ] == 0)
		return;
	
	canMatch = true;
	word = words[arc4random() % [ words count ]];
	
	for (Player* player in players)
		player.drawing = false;
	Player* player = PlayerWithClient(drawer);
	player.drawing = true;
	
	SendSystemMessage(socket, [ NSString stringWithFormat:@"%@ is up to draw.", player.nickname ]);
	
	// Update the drawer
	NSString* dataString = MembersString();
	WebSocketWriteWithString(socket, (__bridge CFStringRef)dataString);
	
	NSMutableDictionary* map = [ NSMutableDictionary dictionary ];
	map[@"type"] = @"clear";
	NSString* data = JSONSerialize(map);
	WebSocketWriteWithString(socket, (__bridge CFStringRef)data);
	
	map[@"type"] = @"turn";
	map[@"word"] = word;
	map[@"drawer"] = player.nickname;
	
	data = JSONSerialize(map);
	WebSocketWriteWithString(socket, (__bridge CFStringRef)data);
	
	// Start timing thread
	playing = true;
	//pthread_create(&timingThread, NULL, CountTime, socket);
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		countTimer = [ NSTimer scheduledTimerWithTimeInterval:1 target:[ Controller class ] selector:@selector(countTime:) userInfo:[ NSValue valueWithPointer:socket ] repeats:YES ];
	});
}

void CheckMatch(WebSocket* socket, NSDictionary* map) {
	if (!canMatch)
		return;
	
	NSString* text = map[@"text"];
	// Make lowercase and get rid of spaces
	NSString* lowerText = [ [ text lowercaseString ] stringByReplacingOccurrencesOfString:@" " withString:@"" ], *lowerWord = [ [ word lowercaseString ] stringByReplacingOccurrencesOfString:@" " withString:@"" ];
	
	if ([ lowerText isEqualToString:lowerWord ]) {
		// Match found
		PlayerWithClient(drawer).score += (timeLeft / 3) / 4;
		for (Player* player in players) {
			if ([ map[@"nickname"] isEqualToString:player.nickname ]) {
				player.score += timeLeft / 3;
				break;
			}
		}
		
		// Let everybody know
		SendSystemMessage(socket, [ NSString stringWithFormat:@"%@ guessed the word correctly: <b>%@</b>.", map[@"nickname"], word ]);
		
		if (playing)
			EndTurn(socket, true);
	}
}

void EndTurn(WebSocket* socket, bool timer) {
	playing = false;
	canMatch = false;
	
	NSMutableDictionary* map = [ NSMutableDictionary dictionary ];
	map[@"type"] = @"end";
	
	NSString* data = JSONSerialize(map);
	WebSocketWriteWithString(socket, (__bridge CFStringRef)data);
	
	// Chose the next drawer
	bool found = false;
	for (unsigned long z = 0; z < [ players count ]; z++) {
		if (drawer == [ (Player*)players[z] client ]) {
			z++;
			if (z == [ players count ])
				z = 0;
			drawer = [ (Player*)players[z] client ];
			found = true;
			break;
		}
	}
	if (!found && [ players count ] != 0)
		drawer = [ (Player*)players[0] client ];
	else if (!found)
		exit(0);
	
	// Update the score
	NSString* dataString = MembersString();
	WebSocketWriteWithString(socket, (__bridge CFStringRef)dataString);
	
	for (Player* player in players) {
		if (player.score >= 100) {
			EndGame(socket);
			return;
		}
	}
	
	// Cancel the timer
	if (timer) {
		exitTiming = true;
		pthread_cancel(timingThread);
	}
	
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		Controller* control = [ [ Controller alloc ] init ];
		[ control performSelector:@selector(restartTurn:) withObject:[ NSValue valueWithPointer:socket ] afterDelay:3 ];
	});
}

void EndGame(WebSocket* socket) {
	int highestScore = 0;
	WebSocketClient* cid = NULL;
	for (Player* player in players) {
		if (player.score > highestScore) {
			highestScore = player.score;
			cid = player.client;
		}
	}
	
	// cid is the winner
	SendSystemMessage(socket, [ NSString stringWithFormat:@"<b>%@</b> is the winner!", PlayerWithClient(cid).nickname ]);
	
	// Cancel the timer
	exitTiming = true;
	pthread_cancel(timingThread);
	
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		Controller* control = [ [ Controller alloc ] init ];
		[ control performSelector:@selector(restart:) withObject:[ NSValue valueWithPointer:socket ] afterDelay:3 ];
	});
}
