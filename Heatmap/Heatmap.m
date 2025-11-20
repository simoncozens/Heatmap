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
#import <GlyphsCore/GSProxyShapes.h>
// #import "GSEditViewController.h"
// #import "GSWindowController.h"
#import <GlyphsCore/GSComponent.h>
#import <GlyphsCore/NSString+BadgeDrawing.h>
#import "GSPath+SCPathUtils.h"

CGFloat MAX_DIST = 512;

long callcount = 0;

typedef struct Box {
    NSRect rect;
    float h;
    float s;
    float b;
} Box;

NSMutableArray* boxlist;
GSLayer* activeLayer;
NSDate* lastChange;
NSRect calcArea;
NSRect lastView;
float lastZoomLevel = -1;

bool isClose(CGFloat d1, CGFloat d2, CGFloat tolerance) {
    return fabs(d1-d2) < tolerance;
}

float calcTolerance(float lastZoomLevel) {
    return MAX(1.0, 3.0/lastZoomLevel);
}

@implementation Heatmap

- (id) init {
	self = [super init];
	if (self) {
		// do stuff
        cache = [[NSMutableDictionary alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(interfaceUpdated) name:@"GSUpdateInterface" object:nil];
        layerMaxDist = 0;
        boxlist = [[NSMutableArray alloc] init];
        calcArea = NSZeroRect;
    }
    return self;
}

- (void) loadPlugin {
    // Is called when the plugin is loaded.
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


- (void) drawForegroundForLayer:(GSLayer*)Layer options:(NSDictionary *)options {
}


- (CGFloat) fastGetDistanceForPoint:(NSPoint)point fromLayer:(GSLayer*)Layer cutOff:(CGFloat)cutoff {
    NSValue* k = [NSValue valueWithPoint:point];
    NSNumber* v = [cache objectForKey:k];
    callcount++;
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
    
    CGFloat step = 5.0;
    for (x = bounds.origin.x; x <= bounds.origin.x + bounds.size.width; x += step) {
        for (y = bounds.origin.y; y <= bounds.origin.y + bounds.size.height; y += step * 2.0) {
            NSPoint point = NSMakePoint(x,y);
            if (![p containsPoint:point]) continue;
            CGFloat d = [self fastGetDistanceForPoint:point fromLayer:Layer cutOff:MIN(NSWidth(bounds), NSHeight(bounds)) * 0.5];
            if (d > layerMaxDist) layerMaxDist = d;
        }
    }
}

- (void) runBoxList {
    NSRect visible = [self layerVisibleRect];
    for (NSValue *o in boxlist) {
        Box b;
        [o getValue:&b];
        if (!NSIntersectsRect(visible, b.rect)) continue;
        NSColor* cM = [NSColor colorWithCalibratedHue: b.h saturation:b.s brightness:b.b alpha:0.3];
        [cM set];
        NSBezierPath* draw = [NSBezierPath alloc];
        [draw appendBezierPathWithRect:b.rect];
        [draw fill];
    }
}

- (void) calculateBoxListForLayer:(GSLayer*)Layer {
//    NSLog(@"Heatmap: Calculating a new box list");
    GSLayer *clone = [Layer copyDecomposedLayer];
    [clone flattenOutlines];
    NSBezierPath* p = [clone bezierPath];
    NSRect bounds = [p bounds];
    CGFloat x, y;
    if (layerMaxDist == 0) [self setLayerMaxDist:clone];
    x = bounds.origin.x;
    y = bounds.origin.y;
    callcount = 0;
    if (bounds.size.width <= FLT_EPSILON || bounds.size.height <= FLT_EPSILON) return;
    CGFloat basis = MIN(layerMaxDist, bounds.size.width/2);
    while (x <= bounds.origin.x + bounds.size.width) {
        y = bounds.origin.y;
        while (y <= bounds.origin.y + bounds.size.height) {
            [self fillInBox: NSMakeRect(x,y,basis,basis) forLayer:clone andPath: p];
            y += basis;
        }
        x += basis;
    }
}

- (void) fillInBox:(NSRect)r forLayer:(GSLayer*)Layer andPath:(NSBezierPath*)p {
//    NSRect visible = [self layerVisibleRect];
//    if (!NSIntersectsRect(visible, r)) return;
//    if (!NSIsEmptyRect(calcArea) && !NSIntersectsRect(calcArea, r)) return;
    NSPoint bl = r.origin;
    NSPoint br = NSMakePoint(bl.x + r.size.width, bl.y);
    NSPoint tr = NSMakePoint(bl.x + r.size.width, bl.y + r.size.height);
    NSPoint tl = NSMakePoint(bl.x, bl.y + r.size.height);
    NSPoint midleft = NSMakePoint(bl.x,  bl.y + 0.5 * r.size.height);
    NSPoint midright = NSMakePoint(bl.x + r.size.width,  bl.y + 0.5 * r.size.height);
    NSPoint midtop = NSMakePoint(bl.x + 0.5 * r.size.width, bl.y + r.size.height);
    NSPoint midbottom = NSMakePoint(bl.x + 0.5 * r.size.width, bl.y);
    NSPoint midpoint = NSMakePoint(bl.x + 0.5 * r.size.width, bl.y + 0.5 * r.size.height);
    CGFloat midDistance = 1;
    
    if (r.size.width <= 1 && r.size.height <= 1) goto justDraw;
    
    if (![p containsPoint:bl] && ![p containsPoint:br] && ![p containsPoint:tl] && ![p containsPoint:tr]
        && ![p containsPoint:midpoint]) {
        return;
    }

                                 
    CGFloat midleftDistance = [self fastGetDistanceForPoint:midleft fromLayer:Layer cutOff:layerMaxDist];
    CGFloat midrightDistance = [self fastGetDistanceForPoint:midright fromLayer:Layer cutOff:layerMaxDist];
    midDistance = [self fastGetDistanceForPoint:midpoint fromLayer:Layer cutOff:layerMaxDist];

    CGFloat tolerance = calcTolerance(lastZoomLevel);

    if (!isClose(midleftDistance, midDistance,tolerance) || !isClose(midDistance, midrightDistance, tolerance)) {
    splitLeftRight:
        [self fillInBox:NSMakeRect(bl.x, bl.y,  0.5 * r.size.width, r.size.height) forLayer:Layer andPath:p];
        [self fillInBox:NSMakeRect(bl.x + 0.5 * r.size.width, bl.y,  0.5 * r.size.width, r.size.height) forLayer:Layer andPath:p];
        return;
    }

    CGFloat midtopDistance = [self fastGetDistanceForPoint:midtop fromLayer:Layer cutOff:layerMaxDist];
    CGFloat midbottomDistance = [self fastGetDistanceForPoint:midbottom fromLayer:Layer cutOff:layerMaxDist];

    if (!isClose(midtopDistance, midDistance,tolerance) || !isClose(midDistance, midbottomDistance, tolerance)) {
    splitTopBottom:
        [self fillInBox:NSMakeRect(bl.x, bl.y,  r.size.width, 0.5 * r.size.height) forLayer:Layer andPath:p];
        [self fillInBox:NSMakeRect(bl.x, bl.y  + 0.5 * r.size.height,  r.size.width, 0.5 * r.size.height) forLayer:Layer andPath:p];
        return;
    }

justDraw:
    {
        Box b;
        b.rect = r;
        b.h = 1-(midDistance/layerMaxDist);
        b.s = midDistance/layerMaxDist;
        b.b =(midDistance/layerMaxDist)*2;
        [boxlist addObject:[NSValue valueWithBytes:&b objCType:@encode(Box)]];
    }
}


- (void) interfaceUpdated {
    //NSLog(@"Layer last change: %@", [[activeLayer parent] lastChange]);
    if ([[activeLayer parent] lastChange] != lastChange) {
        lastChange = [[activeLayer parent] lastChange];
        [self recalculate];
    }
}

- (void) recalculate {
    //NSLog(@"Heatmap: Clearing cache");
    [cache removeAllObjects];
    layerMaxDist = 0;
    lastView = NSZeroRect;
    [boxlist removeAllObjects];
    [self calculateBoxListForLayer:activeLayer];
}

- (void) drawBackgroundForLayer:(GSLayer*)Layer options:(NSDictionary *)options {
    float currentScale = [self getScale];
    NSBezierPath* p = [Layer bezierPath];
    if ([boxlist count] < 1 || currentScale > lastZoomLevel
        || Layer != activeLayer
    ) {
        activeLayer = Layer;
        [self recalculate];
    }
    lastZoomLevel = currentScale;
    [NSGraphicsContext saveGraphicsState];
    [p addClip];
    [self runBoxList];
//    NSLog(@"Heatmap: Drawing complete");
    [NSGraphicsContext restoreGraphicsState];
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
