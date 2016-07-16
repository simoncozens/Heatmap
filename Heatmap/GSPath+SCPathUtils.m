//
//  GSPath+SCPathUtils.m
//  SuperTool
//
//  Created by Simon Cozens on 14/07/2016.
//  Copyright © 2016 Simon Cozens. All rights reserved.
//

#import "GSPath+SCPathUtils.h"

@implementation GSPath (SCPathUtils)

- (CGFloat)distanceFromPoint:(NSPoint)aPoint {
    CGFloat d = MAXFLOAT;
	CGFloat localD;
	GSNode *currNode;
	NSPoint P0, P1, P2, P3;
	for (NSInteger nodeIndex = 0; nodeIndex < [_nodes count]; nodeIndex++) {
		currNode = [self nodeAtIndex:nodeIndex];
		//UKLog(@"Node: %@", Node);
		switch (currNode.type) {
			case LINE: {
				P3 = currNode.position;
				localD = GSDistance(P3, aPoint);
				if (localD < 0.01) {
					return localD;
				}
				P0 = [[self nodeAtIndex:nodeIndex - 1] position];
				localD = GSDistanceOfPointFromLineSegment(aPoint, P0, P3);
				break;
			}
			case CURVE: {
				P3 = currNode.position;
				localD = GSDistance(P3, aPoint);
				if (localD < 0.01) {
					return localD;
				}
				P0 = [[self nodeAtIndex:nodeIndex - 3] position];
				P1 = [[self nodeAtIndex:nodeIndex - 2] position];
				P2 = [[self nodeAtIndex:nodeIndex - 1] position];
				
				localD = GSDistanceOfPointFromCurve(aPoint, P0, P1, P2, P3);
				break;
			}
			default:
				continue;
		}
		if (localD < d) d = localD;
		
		if (d < 1) {
			break;
		}
	}
    return d;
}
@end
