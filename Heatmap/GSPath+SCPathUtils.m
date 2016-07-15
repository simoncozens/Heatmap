//
//  GSPath+SCPathUtils.m
//  SuperTool
//
//  Created by Simon Cozens on 14/07/2016.
//  Copyright © 2016 Simon Cozens. All rights reserved.
//

#import "GSPath+SCPathUtils.h"

@implementation GSPath (SCPathUtils)

- (CGFloat)distanceFromPoint: (NSPoint)p {
    CGFloat d = MAXFLOAT;
    for (NSArray* seg in [self segments]) {
        CGFloat localD;
        if ([seg count] ==  2) {
            localD = GSDistanceOfPointFromLineSegment(p, [seg[0] pointValue], [seg[1] pointValue]);
        } else {
            localD = GSDistanceOfPointFromCurve(p, [seg[0] pointValue], [seg[1] pointValue], [seg[2] pointValue], [seg[3] pointValue]);
        }
        if (localD < d) d = localD;
    }
    return d;
}
@end
