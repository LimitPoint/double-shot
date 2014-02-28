//  NSStringExtensions.m
//  Double Shot
//
//
//  Copyright (c) 2014 Limit Point LLC. All rights reserved.
//
#import "NSStringExtensions.h"

@implementation NSString (NSStringExtensions)

- (NSString*) extractBetweenPattern:(NSString*)fromPattern andPattern:(NSString*)toPattern
{
	NSString *extraction = NULL;
	
	NSRange fromPatternLocation = [self rangeOfString:fromPattern options:NSCaseInsensitiveSearch];
	
	if (fromPatternLocation.length != 0) {
		
		NSRange toPatternLocation = [self rangeOfString:toPattern
												  options:NSCaseInsensitiveSearch 
				range:NSMakeRange(fromPatternLocation.location + fromPatternLocation.length, [self length]-(fromPatternLocation.location + fromPatternLocation.length))];
		
		if (toPatternLocation.length != 0) {
			
			unsigned int startLocation = fromPatternLocation.location+fromPatternLocation.length;
			
			extraction = [self substringWithRange:NSMakeRange(startLocation, toPatternLocation.location-startLocation)];
		}
	}
	return extraction;
}

- (NSString*) reverseExtractBetweenPattern:(NSString*)fromPattern andPattern:(NSString*)toPattern
{
	NSString *extraction = NULL;
	
	NSRange toPatternLocation = [self rangeOfString:toPattern options:NSCaseInsensitiveSearch];
	
	if (toPatternLocation.length != 0) {
		
		NSRange fromPatternLocation = [self rangeOfString:fromPattern
												  options:NSCaseInsensitiveSearch|NSBackwardsSearch 
													range:NSMakeRange(0, toPatternLocation.location)];
		
		if (fromPatternLocation.length != 0) {
			
			unsigned int startLocation = fromPatternLocation.location+fromPatternLocation.length;
			
			extraction = [self substringWithRange:NSMakeRange(startLocation, toPatternLocation.location-startLocation)];
		}
	}
	return extraction;
}
@end
