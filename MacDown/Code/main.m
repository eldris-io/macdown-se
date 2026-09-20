//
//  main.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 6/06/2014.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MPDocumentController.h"

int main(int argc, const char * argv[])
{
    @autoreleasepool
    {
        // Install the shared subclass before AppKit or the main nib requests it.
        __attribute__((objc_precise_lifetime)) MPDocumentController *controller =
            [[MPDocumentController alloc] init];
        NSCAssert(NSDocumentController.sharedDocumentController == controller,
                  @"The document controller must be installed before application startup.");
        return NSApplicationMain(argc, argv);
    }
}
