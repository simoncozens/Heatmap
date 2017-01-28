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
#import <GlyphsCore/GSFilterPlugin.h>

@interface GlyphsFilterRemoveOverlap: NSObject <GlyphsFilter>
- (void)removeOverlapFromLayer:(GSLayer*)layer checkSelection:(BOOL)b error:(NSError *__autoreleasing*) error;
@end

@interface Heatmap : NSObject <GlyphsReporter> {
    NSViewController <GSGlyphEditViewControllerProtocol> *editViewController;
    NSMutableDictionary *cache;
    CGFloat layerMaxDist;
}

@end
