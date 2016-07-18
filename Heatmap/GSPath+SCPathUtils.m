//
//  GSPath+SCPathUtils.m
//  SuperTool
//
//  Created by Simon Cozens on 14/07/2016.
//  Copyright © 2016 Simon Cozens. All rights reserved.
//

#import "GSPath+SCPathUtils.h"

const int slices = 25;
const float tick = 1/(float)slices;

float getClosestPointToCubicBezier(float fx, float fy, float x0, float y0, float x1, float y1, float x2, float y2, float x3, float y3)  {
	float x;
	float y;
	float t;
	float bestDistance = MAXFLOAT;
	float currentDistance = bestDistance;
	NSPoint prev = NSMakePoint(x0, y0);
	NSPoint f = NSMakePoint(fx, fy);
	for (int i = 1; i <= slices; i++) {
		t = i * tick;
		x = (1 - t) * (1 - t) * (1 - t) * x0 + 3 * (1 - t) * (1 - t) * t * x1 + 3 * (1 - t) * t * t * x2 + t * t * t * x3;
		y = (1 - t) * (1 - t) * (1 - t) * y0 + 3 * (1 - t) * (1 - t) * t * y1 + 3 * (1 - t) * t * t * y2 + t * t * t * y3;
		
		currentDistance = (((x - fx) * (x - fx)) + ((y - fy) * (y - fy)));
		NSRect rect = GSRectFromTwoPoints(NSMakePoint(x, y), prev);
		CGFloat tollerance = MAX(NSWidth(rect), NSHeight(rect)) * 0.5;
		rect = NSInsetRect(rect, -tollerance, -tollerance);
		if (NSPointInRect(NSMakePoint(fx, fy), rect)) {
			currentDistance = GSDistanceOfPointFromLineSegment(f, NSMakePoint(x, y), prev);
			currentDistance *= currentDistance; // the above calculation gives square result.
		}
		if (currentDistance < bestDistance) {
			bestDistance = currentDistance;
		}
		prev = NSMakePoint(x, y);
	}
	//return bestDistance;
	return sqrt(bestDistance);
}

@implementation GSPath (SCPathUtils)

- (CGFloat)distanceFromPoint:(NSPoint)aPoint maxDistance:(CGFloat)maxDistance {
    CGFloat d = maxDistance;
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
				// check if point is far away from the segment
				P0 = [[self nodeAtIndex:nodeIndex - 1] position];
				NSRect segmentRect = GSRectFromTwoPoints(P0, P3);
				if ((aPoint.x + maxDistance < NSMinX(segmentRect) || aPoint.y + maxDistance < NSMinY(segmentRect)) && (aPoint.x - maxDistance > NSMaxX(segmentRect) || aPoint.y - maxDistance > NSMaxX(segmentRect))) {
					continue;
				}
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

				// check if point is far away from the segment
				NSRect segmentRect = GSRectFromFourPoints(P0, P1, P2, P3);
				if ((aPoint.x + maxDistance < NSMinX(segmentRect) || aPoint.y + maxDistance < NSMinY(segmentRect)) && (aPoint.x - maxDistance > NSMaxX(segmentRect) || aPoint.y - maxDistance > NSMaxX(segmentRect))) {
					continue;
				}
				
				localD = getClosestPointToCubicBezier(aPoint.x, aPoint.y, P0.x, P0.y, P1.x, P1.y, P2.x, P2.y, P3.x, P3.y);
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
