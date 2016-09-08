//
//  Messages.hpp
//  DrawSomething
//
//  Created by Neil Singh on 3/22/16.
//  Copyright © 2016 Neil Singh. All rights reserved.
//

#ifndef Messages_h
#define Messages_h

#import <Cocoa/Cocoa.h>
#import "CoreWebSocket/CoreWebSocket.h"
#include <stdio.h>

@interface Player : NSObject {
}

@property NSString* nickname;
@property int score;
@property bool drawing;
@property (assign) WebSocketClient* client;

- (instancetype) init;
- (instancetype) initWithName:(NSString*)name andScore:(int)s;

@end

extern NSMutableArray* players;

bool PlayerContains(WebSocketClient* client);
Player* PlayerWithClient(WebSocketClient* client);

NSString* MembersString();
void SendSystemMessage(WebSocket* socket, NSString* message);
void SendSystemMessageClient(WebSocket* socket, NSString* message, WebSocketClient* client);
unsigned int GetClientIndex(WebSocket* socket, WebSocketClient* client);

NSString* JSONSerialize(id val);
/*NSString* JSONDictionary(NSDictionary* map);
NSString* JSONArray(NSArray* map);*/

NSDictionary* DictionaryFromJSON(NSString* message);

#endif /* Messages_h */
