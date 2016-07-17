//
//  Heatmap.m
//  Heatmap
//
//  Created by Simon Cozens on 15/07/2016.
//  Copyright © 2016 Simon Cozens. All rights reserved.
//

#import "Heatmap.h"
#import <GlyphsCore/GlyphsFilterProtocol.h>
#import <GlyphsCore/GSFilterPlugin.h>
#import <GlyphsCore/GSGlyph.h>
#import <GlyphsCore/GSLayer.h>
#import <GlyphsCore/GSFont.h>
#import <GlyphsCore/GSFontMaster.h>
// #import "GSEditViewController.h"
// #import "GSWindowController.h"
#import <GlyphsCore/GSComponent.h>
#import "GSPath+SCPathUtils.h"

CGFloat MAX_DIST = 512;

@implementation Heatmap

- (id) init {
	self = [super init];
	if (self) {
		// do stuff
        cache = [[NSMutableDictionary alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clearCache) name:@"GSUpdateInterface" object:nil];
        layerMaxDist = 0;
    }
    return self;
}

- (void) loadPlugin {
    // Is called when the plugin is loaded.
}

- (void) clearCache {
    [cache removeAllObjects];
    layerMaxDist = 0;
}

- (NSUInteger) interfaceVersion {
	// Distinguishes the API verison the plugin was built for. Return 1.
	return 1;
}

- (NSString*) title {
	// This is the name as it appears in the menu in combination with 'Show'.
    // E.g. 'return @"Nodes";' will make the menu item read "Show Nodes".
	return @"Heatmap";
    
    // or localise it:
    // return NSLocalizedStringFromTableInBundle(@"TITLE", nil, [NSBundle bundleForClass:[self class]], @"DESCRIPTION");
}

- (NSString*) keyEquivalent {
	// The key for the keyboard shortcut. Set modifier keys in modifierMask further below.
    // Pretty tricky to find a shortcut that is not taken yet, so be careful.
    // If you are not sure, use 'return nil;'. Users can set their own shortcuts in System Prefs.
	return nil;
}

- (int) modifierMask {
    // Use any combination of these to determine the modifier keys for your default shortcut:
    // return NSShiftKeyMask | NSControlKeyMask | NSCommandKeyMask | NSAlternateKeyMask;
    // Or:
    // return 0;
    // ... if you do not want to set a shortcut.
    return 0;
}


- (void) drawForegroundForLayer:(GSLayer*)Layer {
}


- (CGFloat) fastGetDistanceForPoint:(NSPoint)point fromLayer:(GSLayer*)Layer cutOff:(CGFloat)cutoff {
    NSValue* k = [NSValue valueWithPoint:GSRoundPoint(point)];
    NSNumber* v = [cache objectForKey:k];
    if (v) {
		return [v floatValue];
	}
    CGFloat d = [self slowGetDistanceForPoint:point fromLayer:Layer cutOff:cutoff];
    [cache setObject:[NSNumber numberWithFloat:d] forKey:k];
    return d;
}

- (CGFloat) slowGetDistanceForPoint:(NSPoint)point fromLayer:(GSLayer*)Layer cutOff:(CGFloat)cutoff {

    CGFloat d = cutoff;
    for (GSPath* path in [Layer paths]) {
		CGFloat localD = [path distanceFromPoint:point maxDistance:d];
        if (localD < d) d = localD;
    }
    return d;
}

- (void) setLayerMaxDist:(GSLayer*)Layer {
    NSBezierPath* p = [Layer bezierPath];
    NSRect bounds = [p bounds];
    CGFloat x, y;
 
    // XXX If there's a stem defined, use that / 4. Else use 5.
    for (x = bounds.origin.x; x <= bounds.origin.x + bounds.size.width; x += 5) {
        for (y = bounds.origin.y; y <= bounds.origin.y + bounds.size.height; y += 10) {
            NSPoint point = NSMakePoint(x,y);
            if (![p containsPoint:point]) continue;
            CGFloat d = [self fastGetDistanceForPoint:point fromLayer:Layer cutOff:MIN(NSWidth(bounds), NSHeight(bounds)) * 0.5];
            if (d > layerMaxDist) layerMaxDist = d;
        }
    }
}

- (void) fillInBox:(NSRect)r forLayer:(GSLayer*)Layer andPath:(NSBezierPath*)p {
    NSPoint bl = r.origin;
    NSPoint br = NSMakePoint(bl.x + r.size.width, bl.y);
    NSPoint tr = NSMakePoint(bl.x + r.size.width, bl.y + r.size.height);
    NSPoint tl = NSMakePoint(bl.x, bl.y + r.size.height);
    NSPoint midpoint = NSMakePoint(bl.x + 0.5 * r.size.width, bl.y + 0.5 * r.size.height);
    CGFloat d1 = [self fastGetDistanceForPoint:bl fromLayer:Layer cutOff:layerMaxDist];
    CGFloat d2 = [self fastGetDistanceForPoint:br fromLayer:Layer cutOff:layerMaxDist];
    CGFloat dMid = [self fastGetDistanceForPoint:midpoint fromLayer:Layer cutOff:layerMaxDist];
    CGFloat d3 = [self fastGetDistanceForPoint:tl fromLayer:Layer cutOff:layerMaxDist];
    CGFloat d4 = [self fastGetDistanceForPoint:tr fromLayer:Layer cutOff:layerMaxDist];

    NSColor *cM;
    
    if (r.size.width <= 1 || r.size.height <= 1) goto justDraw;

    if (![p containsPoint:bl] && ![p containsPoint:br] && ![p containsPoint:tl] && ![p containsPoint:tr]
        && ![p containsPoint:midpoint]) {
        return;
    }
    
//    if ([p containsPoint:bl] == [p containsPoint:tl] && [p containsPoint:br] == [p containsPoint:tr] &&
//        [p containsPoint:bl] != [p containsPoint:br]) {
//        goto splitLeftRight;
//    }
//    if ([p containsPoint:bl] == [p containsPoint:br] && [p containsPoint:tl] == [p containsPoint:tr] &&
//        [p containsPoint:bl] != [p containsPoint:tl]) {
//        goto splitTopBottom;
//    }
//    
    CGFloat tolerance =  MAX(0.10 / [self getScale],0.05) * MAX(50, layerMaxDist);

    if (fabs(d1-d2) > tolerance && fabs(d1-d3) < tolerance) {
    splitLeftRight:
        [self fillInBox:NSMakeRect(bl.x, bl.y,  0.5 * r.size.width, r.size.height) forLayer:Layer andPath:p];
        [self fillInBox:NSMakeRect(bl.x + 0.5 * r.size.width, bl.y,  0.5 * r.size.width, r.size.height) forLayer:Layer andPath:p];
        return;
    }


    if (fabs(d2-d4) > tolerance && fabs(d1-d2) < tolerance) {
    splitTopBottom:
        [self fillInBox:NSMakeRect(bl.x, bl.y,  r.size.width, 0.5 * r.size.height) forLayer:Layer andPath:p];
        [self fillInBox:NSMakeRect(bl.x, bl.y  + 0.5 * r.size.height,  r.size.width, 0.5 * r.size.height) forLayer:Layer andPath:p];
        return;
    }
    
    
    if (fabs(d1-dMid) > tolerance || fabs(d2-dMid)> tolerance || fabs(d3-dMid) > tolerance || fabs(d4-dMid) > tolerance) {
        [self fillInBox:NSMakeRect(bl.x, bl.y,  0.5 * r.size.width, 0.5 * r.size.height) forLayer:Layer andPath:p];
        [self fillInBox:NSMakeRect(bl.x, bl.y  + 0.5 * r.size.height,  0.5 * r.size.width, 0.5 * r.size.height) forLayer:Layer andPath:p];
        [self fillInBox:NSMakeRect(bl.x + 0.5 * r.size.width, bl.y,  0.5 * r.size.width, 0.5 * r.size.height) forLayer:Layer andPath:p];
        [self fillInBox:NSMakeRect(bl.x + 0.5 * r.size.width, bl.y  + 0.5 * r.size.height,  0.5 * r.size.width, 0.5 * r.size.height) forLayer:Layer andPath:p];

        return;
        
    }
    
justDraw:
//    cM = [NSColor colorWithRed:1.0 green:1.0-pow(dMid/layerMaxDist,1.5) blue:0 alpha:0.3];
    cM = [NSColor colorWithCalibratedHue:1-(dMid/layerMaxDist) saturation:(dMid/layerMaxDist) brightness:(dMid/layerMaxDist)*2 alpha:0.3];
    [cM set];
    NSBezierPath* draw = [NSBezierPath alloc];
    [draw appendBezierPathWithRect:r];
    [draw fill];
}
    
- (void) drawBackgroundForLayer:(GSLayer*)Layer {
    NSBezierPath* p = [Layer bezierPath];
    NSRect bounds = CGRectIntersection([self layerVisibleRect], [p bounds]);
    CGFloat x, y;
    if (layerMaxDist == 0) [self setLayerMaxDist:Layer];
    x = bounds.origin.x;
    y = bounds.origin.y;
    if (bounds.size.width <= FLT_EPSILON || bounds.size.height <= FLT_EPSILON) return;
    [p addClip];
    CGFloat basis = layerMaxDist/2;
    while (x <= bounds.origin.x + bounds.size.width) {
        y = bounds.origin.y;
        while (y <= bounds.origin.y + bounds.size.height) {
            [self fillInBox: NSMakeRect(x,y,basis,basis) forLayer:Layer andPath: p];
            y += basis;
        }
        x += basis;
    }
}

- (float) getScale {
    // [self getScale]; returns the current scale factor of the Edit View UI.
    // Divide any scalable size by this value in order to keep the same apparent pixel size.
    
    if (editViewController) {
        return [[editViewController graphicView] scale];
    } else {
        return 1.0;
    }
}

- (void) setController:(NSViewController <GSGlyphEditViewControllerProtocol>*)Controller {
    // Use [self controller]; as object for the current view controller.
    editViewController = Controller;
}

- (void) logToConsole:(NSString*)message {
    // The NSString 'message' will be passed to Console.app.
    // Use [self logToConsole:@"bla bla"]; for debugging.
    NSLog( @"Show %@ plugin:\n%@", [self title], message );
}

- (NSRect) layerVisibleRect {
    if (!editViewController) return NSMakeRect(0,0,0,0);
    NSPoint origin = [[editViewController graphicView] activePosition];
    float scale = [[editViewController graphicView] scale];
    NSRect bounds = [[editViewController graphicView] visibleRect];
    bounds.origin.x -= origin.x;
    bounds.origin.y -= origin.y;
    bounds.origin.x /= scale;
    bounds.origin.y /= scale;
    bounds.size.width /= scale;
    bounds.size.height /= scale;
    return bounds;
}

@end
