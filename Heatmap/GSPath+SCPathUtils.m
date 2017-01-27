//
//  GSPath+SCPathUtils.m
//  SuperTool
//
//  Created by Simon Cozens on 14/07/2016.
//  Copyright © 2016 Simon Cozens. All rights reserved.
//

#import "GSPath+SCPathUtils.h"

double _getClosestPointToCubicBezier(int iterations, double fx, double fy, double start, double end, int slices, double x0, double y0, double x1, double y1, double x2, double y2, double x3, double y3) {
    double tick = (end - start) / (double) slices;
    double x, y, dx, dy;
    double best = 0;
    double bestDistance = MAXFLOAT;
    double currentDistance;
    double t = start;
    while (t <= end) {
        //B(t) = (1-t)**3 p0 + 3(1 - t)**2 t P1 + 3(1-t)t**2 P2 + t**3 P3
        x = (1 - t) * (1 - t) * (1 - t) * x0 + 3 * (1 - t) * (1 - t) * t * x1 + 3 * (1 - t) * t * t * x2 + t * t * t * x3;
        y = (1 - t) * (1 - t) * (1 - t) * y0 + 3 * (1 - t) * (1 - t) * t * y1 + 3 * (1 - t) * t * t * y2 + t * t * t * y3;
        
        
        dx = x - fx;
        dy = y - fy;
        dx *= dx;
        dy *= dy;
        currentDistance = dx + dy;
        if (currentDistance < bestDistance) {
            bestDistance = currentDistance;
            best = t;
        }
        t += tick;
    }
    if (iterations <= 1) return sqrt(bestDistance);
    return _getClosestPointToCubicBezier(iterations - 1, fx, fy, MAX(best - tick, 0.0), MIN(best + tick, 1.0), slices, x0, y0, x1, y1, x2, y2, x3, y3);
}

double getClosestPointToCubicBezier(double fx, double fy, int slices, int iterations, double x0, double y0, double x1, double y1, double x2, double y2, double x3, double y3) {
    return _getClosestPointToCubicBezier(iterations, fx, fy, 0, 1.0, slices, x0, y0, x1, y1, x2, y2, x3, y3);
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
				if (localD < 1) {
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
				localD = getClosestPointToCubicBezier(aPoint.x, aPoint.y, 20, 3, P0.x, P0.y, P1.x, P1.y, P2.x, P2.y, P3.x, P3.y);
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
