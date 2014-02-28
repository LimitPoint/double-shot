//  NSStringExtensions.h
//  Double Shot
//
//
//  Copyright (c) 2014 Limit Point LLC. All rights reserved.
//

@interface NSString (NSStringExtensions)
- (NSString*) extractBetweenPattern:(NSString*)fromPattern andPattern:(NSString*)toPattern;
- (NSString*) reverseExtractBetweenPattern:(NSString*)fromPattern andPattern:(NSString*)toPattern;
@end
