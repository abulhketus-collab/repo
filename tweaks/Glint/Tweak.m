#import <UIKit/UIKit.h>
#import "GlintIslandView.h"

__attribute__((constructor)) static void initGlint() {
    @autoreleasepool {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [GlintIslandView sharedInstance];
        });
    }
}
