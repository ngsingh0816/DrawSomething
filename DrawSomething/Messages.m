//
//  Messages.cpp
//  DrawSomething
//
//  Created by Neil Singh on 3/22/16.
//  Copyright © 2016 Neil Singh. All rights reserved.
//

#include "Messages.h"

NSMutableArray* players = nil;

@implementation Player

@synthesize nickname;
@synthesize score;
@synthesize drawing;
@synthesize client;

- (instancetype) init {
	if ((self = [ super init ])) {
		nickname = @"";
		score = 0;
		drawing = false;
		client = NULL;
	}
	return self;
}

- (instancetype) initWithName:(NSString*)name andScore:(int)s {
	if ((self = [ super init ])) {
		nickname = name;
		score = s;
		drawing = false;
		client = NULL;
	}
	return self;
}

@end

bool PlayerContains(WebSocketClient* client) {
	for (Player* player in players) {
		if (player.client == client)
			return true;
	}
	
	return false;
}

Player* PlayerWithClient(WebSocketClient* client) {
	for (Player* player in players) {
		if (player.client == client)
			return player;
	}
	
	return nil;
}

NSString* MembersString() {
	NSMutableArray* members = [ NSMutableArray array ];
	for (Player* player in players) {
		NSMutableDictionary* map = [ NSMutableDictionary dictionary ];
		
		map[@"nickname"] = player.nickname;
		map[@"score"] = [ NSString stringWithFormat:@"%i", player.score ];
		map[@"drawing"] = [ NSString stringWithFormat:@"%i", player.drawing ];
		[ members addObject:map ];
	}
	
	NSMutableDictionary* map = [ NSMutableDictionary dictionary ];
	map[@"type"] = @"members";
	map[@"members"] = members;
	
	return JSONSerialize(map);
}

void SendSystemMessage(WebSocket* socket, NSString* msg) {
	NSMutableDictionary* message = [ NSMutableDictionary dictionary ];
	message[@"type"] = @"message";
	message[@"nickname"] = @"System";
	
	message[@"text"] = [ NSString stringWithFormat:@"<span style='color:#FF0000'>%@</span>", msg ];
	NSString* data = JSONSerialize(message);
	WebSocketWriteWithString(socket, (__bridge CFStringRef)data);
}

unsigned int GetClientIndex(WebSocket* socket, WebSocketClient* client) {
	for (unsigned int z = 0; z < socket->clientsLength; z++) {
		if (client == socket->clients[z])
			return z;
	}
	return -1;
}

void SendSystemMessageClient(WebSocket* socket, NSString* msg, WebSocketClient* client) {
	unsigned int clientID = GetClientIndex(socket, client);
	if (clientID == -1)
		return;
	
	NSMutableDictionary* message = [ NSMutableDictionary dictionary ];
	message[@"type"] = @"message";
	message[@"nickname"] = @"System";
	message[@"text"] = [ NSString stringWithFormat:@"<span style='color:#FF0000'>%@</span>", msg ];
	NSString* data = JSONSerialize(message);
	WebSocketWriteWithStringAndClientIndex(socket, (__bridge CFStringRef)data, clientID);
}

NSString* JSONSerialize(id val) {
	NSData* data = [ NSJSONSerialization dataWithJSONObject:val options:0 error:nil ];
	return [ [ NSString alloc ] initWithData:data encoding:NSUTF8StringEncoding ];
}

/*NSString* JSONDictionary(NSDictionary* map) {
	NSMutableString* stream = [ NSMutableString stringWithString:@"{ " ];
	NSArray* keys = [ map allKeys ];
	for (unsigned long z = 0; z < [ keys count ]; z++) {
		id key = keys[z];
		
		[ stream appendFormat:@"\"%@\":", key ];
		NSString* second = map[key];
		char cmd = [ second characterAtIndex:0 ];
		bool insert = cmd != '[' && cmd != '{' && cmd != '"' &&
			(cmd < '0' || cmd > '9');
		if (insert)
			[ stream appendString:@"\"" ];
		[ stream appendString:second ];
		if (insert)
			[ stream appendString:@"\"" ];
		
		if (z != [ keys count ] - 1)
			[ stream appendString:@", " ];
		
	}
	
	[ stream appendString:@" }" ];
	
	return stream;
}

NSString* JSONArray(Array array) {
	std::stringstream stream;
	stream << "[ ";
	
	for (unsigned long z = 0; z < array.size(); z++) {
		string second = array[z];
		bool insert = second[0] != '[' && second[0] != '{' && second[0] != '"' &&
		(second[0] < '0' || second[0] > '9');
		if (insert)
			stream << "\"";
		stream << second;
		if (insert)
			stream << "\"";
		
		if (z != array.size() - 1)
			stream << ", ";
	}
	
	stream << " ]";
	
	return stream.str();
}

template <typename T> string JSONString(T obj) {
	std::stringstream stream;
	stream << obj;
	return stream.str();
}*/

unsigned long PositionAfterSpaces(NSString* message, unsigned long start) {
	char cmd = [ message characterAtIndex:start ];
	while ((cmd == ' ' || cmd == '\t' || cmd == '\n') && start + 1 < [ message length ])
		cmd = [ message characterAtIndex:++start ];
	return start;
}

unsigned long PositionBeforeSpaces(NSString* message, unsigned long start) {
	char cmd = [ message characterAtIndex:start ];
	while ((cmd == ' ' || cmd == '\t' || cmd == '\n') && start > 0)
		cmd = [ message characterAtIndex:--start ];
	return start;
}

NSDictionary* DictionaryFromJSON(NSString* message) {
	NSData* data = [ message dataUsingEncoding:NSUTF8StringEncoding ];
	return [ NSJSONSerialization JSONObjectWithData:data options:0 error:nil ];
	
	/*Dictionary map;
	
	unsigned long pos = PositionAfterSpaces(message, 0);
	char cmd = message[pos++];
	if (cmd == '{') {
		unsigned long startPtr = PositionAfterSpaces(message, pos);
		unsigned long endPtr = startPtr;
		
		std::string keyString;
		bool foundKey = false;
		bool startQuote = false;
		while (endPtr < message.length()) {
			cmd = message[endPtr++];
			if (!foundKey) {
				if (cmd == '"' && message[endPtr - 2] != '\\') {
					if (!startQuote)
						startQuote = true;
					else {
						char* key = (char*)malloc(endPtr - startPtr - 1);
						memcpy(key, &message[startPtr + 1], endPtr - startPtr - 2);
						key[endPtr - startPtr - 2] = 0;
						keyString = std::string(key);
						free(key);
						
						startPtr = PositionAfterSpaces(message, endPtr);
						cmd = message[startPtr];
						while (cmd != ':')
							cmd = message[++startPtr];
						startPtr = PositionAfterSpaces(message, startPtr + 1);
						endPtr = startPtr;
						
						startQuote = false;
						foundKey = true;
					}
				} else if (cmd == ':' && !startQuote) {
					unsigned long temp = PositionBeforeSpaces(message, endPtr - 2);
					char* key = (char*)malloc(temp - startPtr + 1);
					memcpy(key, &message[startPtr], temp - startPtr);
					key[temp - startPtr] = 0;
					keyString = std::string(key);
					free(key);
					
					startPtr = PositionAfterSpaces(message, endPtr);
					endPtr = startPtr;
					
					foundKey = true;
				}
			} else {
				if (cmd == '"' && message[endPtr - 2] != '\\') {
					if (!startQuote)
						startQuote = true;
					else {
						char* val = (char*)malloc(endPtr - startPtr - 1);
						memcpy(val, &message[startPtr + 1], endPtr - startPtr - 2);
						val[endPtr - startPtr - 2] = 0;
						map[keyString] = std::string(val);
						free(val);
						
						startPtr = PositionAfterSpaces(message, endPtr);
						cmd = message[startPtr];
						while (cmd != ',' && cmd != '}')
							cmd = message[++startPtr];
						startPtr = PositionAfterSpaces(message, startPtr + 1);
						endPtr = startPtr;
						
						startQuote = false;
						foundKey = false;
					}
				} else if ((cmd == ',' || cmd == '}') && !startQuote) {
					unsigned long temp = PositionBeforeSpaces(message, endPtr - 2);
					char* val = (char*)malloc(temp - startPtr + 1);
					memcpy(val, &message[startPtr], temp - startPtr);
					val[temp - startPtr] = 0;
					map[keyString] = std::string(val);
					free(val);
					
					startPtr = PositionAfterSpaces(message, endPtr);
					endPtr = startPtr;
					
					foundKey = false;
				}
			}
		}
	}
	
	return map;*/
}

