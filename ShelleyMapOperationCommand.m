//
//  ShelleyMapOperationCommand.m
//  Frank
//
//  Created by Pete Hodgson on 8/24/11.
//  Copyright 2011 ThoughtWorks. All rights reserved.
//

#import "ShelleyMapOperationCommand.h"

#import "UIQuery.h"
#import "Shelley.h"

#import "JSON.h"
#import "Operation.h"
#import "DumpCommand.h"


@implementation ShelleyMapOperationCommand

- (NSString *)generateErrorResponseWithReason:(NSString *)reason andDetails:(NSString *)details{
	NSDictionary *response = [NSDictionary dictionaryWithObjectsAndKeys: 
							  @"ERROR", @"outcome",
							  reason, @"reason", 
							  details, @"details",
							  nil];
	return [response JSONRepresentation];
}
- (NSString *)generateSuccessResponseWithResults:(NSArray *)results{
	NSDictionary *response = [NSDictionary dictionaryWithObjectsAndKeys: 
							  @"SUCCESS", @"outcome",
							  results, @"results",
							  nil];
	return [response JSONRepresentation];
}

- (id) performOperation:(Operation *)operation onView:(UIView *)view {
	
	if( [operation appliesToObject:view] )
		return [operation applyToObject:view];
	
	// wrapping the view in a uiquery like this lets us perform operations like touch, flash, inspect, etc
	UIQuery *wrappedView = [UIQuery withViews:[NSMutableArray arrayWithObject:view]
									className:@"UIView"];
	if( [operation appliesToObject:wrappedView] )
		return [operation applyToObject:wrappedView];
	
	return nil; 
}

- (NSString *)handleCommandWithRequestBody:(NSString *)requestBody {
	
	NSDictionary *requestCommand = [requestBody JSONValue];
	NSString *queryString = [requestCommand objectForKey:@"query"];
	NSDictionary *operationDict = [requestCommand objectForKey:@"operation"];
	Operation *operation = [[[Operation alloc] initFromJsonRepresentation:operationDict] autorelease];
	
	Shelley *shelley = [Shelley withSelectorString:queryString];
	
	NSArray *selectedViews;
	
	@try {
		selectedViews = [shelley selectFrom:[[UIApplication sharedApplication] keyWindow]];
	}
	@catch (NSException * e) {
		NSLog( @"Exception while executing selector '%@':\n%@", queryString, e );
		return [self generateErrorResponseWithReason:@"invalid selector" andDetails:[e reason]];
	}
	
	NSMutableArray *results = [NSMutableArray arrayWithCapacity:[selectedViews count]];
	for (UIView *view in selectedViews) {
		@try {
			id result = [self performOperation:operation onView:view];
			[results addObject:[DumpCommand jsonify:result]];
		}
		@catch (NSException * e) {
			NSLog( @"Exception while performing operation %@\n%@", operation, e );
			return [self generateErrorResponseWithReason: [ NSString stringWithFormat:@"encountered error while attempting to perform %@ on selected elements",operation] 
											  andDetails:[e reason]];
		}
	}
	
	return [self generateSuccessResponseWithResults: results];
}

@end
