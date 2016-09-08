//
//  AppDelegate.m
//  DrawSomething
//
//  Created by Neil Singh on 5/22/16.
//  Copyright © 2016 Neil Singh. All rights reserved.
//

#import "AppDelegate.h"
#import "Game.h"
#import "Messages.h"
#include <pthread.h>
#include "CoreWebSocket/CoreWebSocket.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

WebSocket* socketGlobal = NULL;
pthread_t matchThread;

void* CheckMatchThread(void* data) {
	NSDictionary* map = (__bridge NSDictionary*)data;
	CheckMatch(socketGlobal, map);
	
	return NULL;
}

void MessageRecieved(WebSocket* socket, WebSocketClient* client, CFStringRef value) {
	NSString* data = (__bridge NSString*)value;
	NSDictionary* map = [ NSJSONSerialization JSONObjectWithData:[ data dataUsingEncoding:NSUTF8StringEncoding ] options:kNilOptions error:nil ];
	unsigned int clientID = GetClientIndex(socket, client);
	
	if ([ map[@"type"] isEqualToString:@"new" ]) {
		Player* player = [ [ Player alloc ] initWithName:map[@"nickname"] andScore:0 ];
		player.client = client;
		[ players addObject:player ];
		
		NSString* dataString = MembersString();
		WebSocketWriteWithString(socket, (__bridge CFStringRef)dataString);
		
		SendSystemMessage(socket, [ NSString stringWithFormat:@"%@ has joined the room.", map[@"nickname"] ]);
	}
	else if ([ map[@"type"] isEqualToString:@"message" ]) {
		// Check if macro from player 0
		bool isHost = [ players count ] && map[@"nickname"] == [ (Player*)players[0] nickname ];
		if (isHost && [ map[@"text"] isEqualToString:@"!start" ]) {
			if (started) {
				SendSystemMessageClient(socket, @"The game has already started!", client);
			} else {
				StartGame(socket, true);
			}
		} else if (isHost && [ map[@"text"] hasPrefix:@"!words " ]) {
			wordPath = [ map[@"text"] substringFromIndex:7 ];
			
			if (LoadWords())
				SendSystemMessage(socket, [ NSString stringWithFormat:@"Word pack set to <b>%@</b>.", wordPath ]);
		} else if ([ map[@"text"] isEqualToString:@"!list" ]) {
			const char* wordPacks[] = { "easy", "medium", "hard", "objects", "persons", "verbs" };
			int numPacks = sizeof(wordPacks) / sizeof(char*);
			NSMutableString* msg = [ NSMutableString stringWithString:@"The available packs are: " ];
			for (unsigned long z = 0; z < numPacks; z++) {
				[ msg appendFormat:@"<b>%s</b>", wordPacks[z] ];
				if (z != numPacks - 1)
					[ msg appendString:@", " ];
				if (z == numPacks - 2)
					[ msg appendString:@"and " ];
			}
			SendSystemMessageClient(socket, msg, client);
		} else if ([ map[@"text"] isEqualToString:@"!commands" ]) {
			if (isHost) {
				SendSystemMessageClient(socket, @"The available commands are: !start, !words, !list, !clear, and !nickname.", client);
			} else {
				SendSystemMessageClient(socket, @"The available commands are: !list, !clear, and !nickname.", client);
			}
		} else if ([ map[@"text"] isEqualToString:@"!clear" ]) {
			NSMutableDictionary* msg = [ NSMutableDictionary dictionary ];
			msg[@"type"] = @"clearchat";
			NSString* msgString = JSONSerialize(msg);
			WebSocketWriteWithStringAndClientIndex(socket, (__bridge CFStringRef)msgString, clientID);
		} else if ([ map[@"text"] hasPrefix:@"!nickname " ]) {
			NSString* newNickname = [ map[@"text"] substringFromIndex:10 ];
			// Check all the other nicknames
			bool alreadyHas = false;
			Player* player = nil;
			for (Player* p in players) {
				if ([ map[@"nickname"] isEqualToString:p.nickname ]) {
					player = p;
					continue;
				}
				if ([ newNickname isEqualToString:p.nickname ])
					alreadyHas = true;
			}
			if (alreadyHas) {
				SendSystemMessageClient(socket, [ NSString stringWithFormat:@"\"%@\" is already taken.", newNickname ], client);
			} else if ([ newNickname containsString:@"\"" ]) {
				SendSystemMessageClient(socket, @"Nicknames can't contain an \".", client);
			} else if (player != nil) {
				SendSystemMessage(socket, [ NSString stringWithFormat:@"\"%@\" has changed name to \"%@\".", player.nickname, newNickname ]);
				player.nickname = newNickname;
				NSString* mstring = MembersString();
				WebSocketWriteWithString(socket, (__bridge CFStringRef)mstring);
				
				NSMutableDictionary* msg = [ NSMutableDictionary dictionary ];
				msg[@"type"] = @"nickname";
				msg[@"nickname"] = newNickname;
				NSString* msgString = JSONSerialize(msg);
				WebSocketWriteWithStringAndClientIndex(socket, (__bridge CFStringRef)msgString, clientID);
			}
			
		} else {
			WebSocketWriteWithString(socket, value);
			
			if (started && ![ map[@"nickname"] isEqualToString:PlayerWithClient(drawer).nickname ]) {
				// Check to see if there's a match
				socketGlobal = socket;
				NSMutableDictionary* temp = [ map copy ];
				pthread_create(&matchThread, NULL, CheckMatchThread, (__bridge void*)temp);
			}
		}
	} else if ([ map[@"type"] isEqualToString:@"draw" ]) {
		WebSocketWriteWithString(socket, value);
	} else if ([ map[@"type"] isEqualToString:@"clear" ]) {
		WebSocketWriteWithString(socket, value);
	}
	else if ([ map[@"type"] isEqualToString:@"tool update" ]) {
		WebSocketWriteWithString(socket, value);
	}
	else if ([ map[@"type"] isEqualToString:@"tool" ]) {
		WebSocketWriteWithString(socket, value);
	}
}

void ClientConnected(WebSocket* socket, WebSocketClient* client) {
	//char* clientIP = inet_ntoa(info.sin_addr);
	//int clientPort = ntohs(info.sin_port);
	//printf("Connected to client(%i) %s:%i\n", client, clientIP, clientPort);
}

void ClientDisconnected(WebSocket* socket, WebSocketClient* client) {
	[ players removeObject:PlayerWithClient(client) ];
	
	NSString* dataString = MembersString();
	WebSocketWriteWithString(socket, (__bridge CFStringRef)dataString);
	
	if (client == drawer)
		EndTurn(socket, true);
}

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	[ [ NSProcessInfo processInfo ] beginActivityWithOptions:NSActivityUserInitiated reason:@"Timers" ];
	WebSocket* webSocket = WebSocketCreateWithHostAndPort(NULL, kWebSocketHostAny, 8888, NULL);
	webSocket->callbacks.didAddClientCallback = ClientConnected;
	webSocket->callbacks.willRemoveClientCallback = ClientDisconnected;
	webSocket->callbacks.didClientReadCallback = MessageRecieved;
	
	LoadWords();
	players = [ NSMutableArray array ];
	
	// Input commands
	/*for (;;) {
		printf("Command: ");
		char cmd[512];
		scanf("%s", cmd);
		if (strcmp(cmd, "quit") == 0)
			break;
		else if (strcmp(cmd, "send")) {
			scanf("%s", cmd);
			WebSocketWriteWithString(webSocket, (__bridge CFStringRef)[ NSString stringWithUTF8String:cmd ]);
		} else if (strcmp(cmd, "set")) {
			scanf("%s", cmd);
			if (strcmp(cmd, "words")) {
				scanf("%s", cmd);
				wordPath = [ NSString stringWithFormat:@"%s", cmd ];
				LoadWords();
			}
		}
	}*/
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
}

@end
