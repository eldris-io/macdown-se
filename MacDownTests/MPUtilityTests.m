//
//  MPUtilityTests.m
//  MacDown
//
//  Created by Tzu-ping Chung  on 23/8.
//  Copyright (c) 2014 Tzu-ping Chung . All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MPUtilities.h"
#import "MPToolbarController.h"

@interface MPUtilityTests : XCTestCase
@end


@implementation MPUtilityTests

- (void)testGetObjectFromJavaScript
{
    NSString *code = (
        @"var obj = { foo: 'bar', baz: 42 };"
        @"var arr = [0, null, {}];"
    );
    id obj = MPGetObjectFromJavaScript(code, @"obj");
    id objx = @{@"foo": @"bar", @"baz": @42};
    XCTAssertEqualObjects(obj, objx, @"JavaScript object to NSDictionary");

    id arr = MPGetObjectFromJavaScript(code, @"arr");
    id arrx = @[@0, [NSNull null], @{}];
    XCTAssertEqualObjects(arr, arrx, @"JavaScript object to NSDictionary");
}

@end

@interface MPToolbarController (Testing)
- (void)selectedToolbarItemGroupItem:(NSSegmentedControl *)sender;
@end

@interface MPToolbarControllerTests : XCTestCase
@end

@implementation MPToolbarControllerTests

- (void)testDefaultToolbarLayout
{
    MPToolbarController *controller = [MPToolbarController new];
    NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:@"ToolbarRegression"];
    NSArray *expected = @[
        @"indent-group", @"text-formatting-group", @"heading-group",
        NSToolbarFlexibleSpaceItemIdentifier,
        @"list-group", NSToolbarFlexibleSpaceItemIdentifier,
        @"blockquote", @"code", NSToolbarFlexibleSpaceItemIdentifier,
        @"link", @"image", NSToolbarFlexibleSpaceItemIdentifier,
        @"copy-html", NSToolbarFlexibleSpaceItemIdentifier, @"layout"
    ];
    XCTAssertEqualObjects([controller toolbarDefaultItemIdentifiers:toolbar], expected);
}

- (void)testSegmentWithoutSelectionIsIgnored
{
    MPToolbarController *controller = [MPToolbarController new];
    NSToolbarItemGroup *group = (NSToolbarItemGroup *)[controller toolbar:nil
        itemForItemIdentifier:@"indent-group" willBeInsertedIntoToolbar:YES];
    NSSegmentedControl *control = (NSSegmentedControl *)group.view;
    control.selectedSegment = -1;
    XCTAssertNoThrow([controller selectedToolbarItemGroupItem:control]);
}

@end
