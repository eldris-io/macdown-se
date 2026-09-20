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

#import "../MacDown/Code/Application/MPLocalIPCServer.h"
#import "../MacDown/Code/Document/MPDocument.h"

@interface MPLocalIPCServer (Testing)
- (NSDictionary *)handle:(NSDictionary *)request;
@end

@interface MPLocalIPCServerTests : XCTestCase
@end

@implementation MPLocalIPCServerTests
- (NSDictionary *)invoke:(NSString *)method params:(NSDictionary *)params server:(MPLocalIPCServer *)server {
    return [server handle:@{@"jsonrpc":@"2.0", @"id":@1, @"method":method, @"params":params}];
}
- (void)testSelectionReplacementAndUndo {
    MPLocalIPCServer *server = [MPLocalIPCServer new];
    [self invoke:@"newDocument" params:@{@"markdown":@"Hello 🌍 world"} server:server];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    MPDocument *document = NSDocumentController.sharedDocumentController.documents.lastObject;
    NSTextView *editor = document.mcpEditor;
    [document.undoManager removeAllActions];
    [document updateChangeCount:NSChangeCleared];
    editor.selectedRange = NSMakeRange(6, 2); // UTF-16 surrogate pair.
    NSDictionary *reply = [self invoke:@"replaceSelection" params:@{@"text":@"native"} server:server];
    XCTAssertEqualObjects(reply[@"result"][@"content"], @"Hello native world");
    XCTAssertEqualObjects(reply[@"result"][@"isDirty"], @YES);
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    XCTAssertTrue(document.isDocumentEdited);
    XCTAssertEqualObjects(document.undoManager.undoActionName, @"AI Edit");
    [document.undoManager undo];
    XCTAssertEqualObjects(editor.string, @"Hello 🌍 world");
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    XCTAssertFalse(document.isDocumentEdited);
    [document.undoManager redo];
    XCTAssertEqualObjects(editor.string, @"Hello native world");
    [document close];
}
- (void)testInsertionPreservesSelectionText {
    MPLocalIPCServer *server = [MPLocalIPCServer new];
    [self invoke:@"newDocument" params:@{@"markdown":@"abc"} server:server];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    MPDocument *document = NSDocumentController.sharedDocumentController.documents.lastObject;
    document.mcpEditor.selectedRange = NSMakeRange(1, 2);
    NSDictionary *reply = [self invoke:@"insertAtCursor" params:@{@"text":@"X"} server:server];
    XCTAssertEqualObjects(reply[@"result"][@"content"], @"aXbc");
    [document close];
}
- (void)testInvalidInputDoesNotMutateDocument {
    MPLocalIPCServer *server = [MPLocalIPCServer new];
    [self invoke:@"newDocument" params:@{@"markdown":@"Keep this"} server:server];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    MPDocument *document = NSDocumentController.sharedDocumentController.documents.lastObject;
    NSDictionary *reply = [self invoke:@"replaceSelection" params:@{@"text":@42} server:server];
    XCTAssertEqualObjects(reply[@"error"][@"code"], @(-32602));
    XCTAssertEqualObjects(document.markdown, @"Keep this");
    [document close];
}
@end
