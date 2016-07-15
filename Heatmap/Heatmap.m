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


- (CGFloat) fastGetDistanceForPoint:(NSPoint)point fromLayer:(GSLayer*)Layer {
    NSValue* k = [NSValue valueWithPoint:point];
    NSNumber* v = [cache objectForKey:k];
    if (v) { return [v floatValue]; }
    CGFloat d = [self slowGetDistanceForPoint:point fromLayer:Layer];
    [cache setObject:[NSNumber numberWithFloat:d] forKey:k];
    return d;
}

- (CGFloat) slowGetDistanceForPoint:(NSPoint)point fromLayer:(GSLayer*)Layer {

    CGFloat d = MAX_DIST;
    for (GSPath* path in [Layer paths]) {
        CGFloat localD = [path distanceFromPoint:point];
        if (localD < d) d = localD;
    }
    return d;
}

- (void) setLayerMaxDist:(GSLayer*)Layer {
    NSBezierPath* p = [Layer bezierPath];
    NSRect bounds = [p bounds];
    CGFloat x, y;
    for (x = bounds.origin.x; x <= bounds.origin.x + bounds.size.width; x += 20) {
        for (y = bounds.origin.y; y <= bounds.origin.y + bounds.size.height; y += 20) {
            NSPoint point = NSMakePoint(x,y);
            if (![p containsPoint:point]) continue;
            CGFloat d = [self fastGetDistanceForPoint:point fromLayer:Layer];
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
    CGFloat d1 = [self fastGetDistanceForPoint:bl fromLayer:Layer];
    CGFloat d2 = [self fastGetDistanceForPoint:br fromLayer:Layer];
    CGFloat dMid = [self fastGetDistanceForPoint:midpoint fromLayer:Layer];
    CGFloat d3 = [self fastGetDistanceForPoint:tl fromLayer:Layer];
    CGFloat d4 = [self fastGetDistanceForPoint:tr fromLayer:Layer];

    NSColor *cM;
    
    if (r.size.width <= 1 || r.size.height <= 1) goto justDraw;

    if (![p containsPoint:bl] && ![p containsPoint:br] && ![p containsPoint:tl] && ![p containsPoint:tr]) {
        return;
    }

    CGFloat tolerance =  MAX(0.15 / [self getScale],0.05) * layerMaxDist;

    if (fabs(d1-d2) > tolerance && fabs(d1-d3) < tolerance) {
        [self fillInBox:NSMakeRect(bl.x, bl.y,  0.5 * r.size.width, r.size.height) forLayer:Layer andPath:p];
        [self fillInBox:NSMakeRect(bl.x + 0.5 * r.size.width, bl.y,  0.5 * r.size.width, r.size.height) forLayer:Layer andPath:p];
        return;
    }


    if (fabs(d2-d4) > tolerance && fabs(d1-d2) < tolerance) {
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
    cM = [NSColor colorWithRed:1.0 green:1.0-((dMid*dMid)/(layerMaxDist*layerMaxDist)) blue:0 alpha:0.3];
    [cM set];
    NSBezierPath* draw = [NSBezierPath alloc];
    [draw appendBezierPathWithRect:r];
    [draw fill];
}
    
- (void) drawBackgroundForLayer:(GSLayer*)Layer {
    NSBezierPath* p = [Layer bezierPath];
    NSRect bounds = [p bounds];
    CGFloat x, y;
    if (layerMaxDist == 0) [self setLayerMaxDist:Layer];
    x = bounds.origin.x;
    y = bounds.origin.y;
    [p addClip];
    CGFloat basis = 50.0;
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

@end
