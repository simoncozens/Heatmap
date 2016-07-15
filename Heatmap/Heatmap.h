//
//  Heatmap.h
//  Heatmap
//
//  Created by Simon Cozens on 15/07/2016.
//  Copyright © 2016 Simon Cozens. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <GlyphsCore/GlyphsReporterProtocol.h>
#import <GlyphsCore/GSGlyphViewControllerProtocol.h>

@interface Heatmap : NSObject <GlyphsReporter> {
    NSViewController <GSGlyphEditViewControllerProtocol> *editViewController;
    NSMutableDictionary *cache;
    CGFloat layerMaxDist;
}
- (void)clearCache;
- (CGFloat) fastGetDistanceForPoint:(NSPoint)point fromLayer:(GSLayer*)Layer;

@end
