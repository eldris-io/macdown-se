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

#import "../MacDown/Code/Document/MPDocumentController.h"
#import "../MacDown/Code/Document/MPRenderer.h"
#import "../MacDown/Code/View/MPDocumentSplitView.h"
#import "../MacDown/Code/Preferences/MPPreferences.h"
#import "../Dependency/peg-markdown-highlight/pmh_parser.h"

@interface MPDocument (WindowRegressionTesting)
- (void)toggleEditorPane:(id)sender;
- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)item;
@end

@interface MPDocumentRegressionTests : XCTestCase
@property NSURL *testURL;
@end

@implementation MPDocumentRegressionTests
- (void)setUp
{
    [super setUp];
    for (NSDocument *document in NSDocumentController.sharedDocumentController.documents.copy)
        [document close];
    self.testURL = [NSURL fileURLWithPath:[NSTemporaryDirectory()
        stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingPathExtension:@"md"]]];
    XCTAssertTrue([@"# Opened file\n" writeToURL:self.testURL atomically:YES encoding:NSUTF8StringEncoding error:NULL]);
}
- (void)tearDown
{
    for (NSDocument *document in NSDocumentController.sharedDocumentController.documents.copy)
        [document close];
    [NSFileManager.defaultManager removeItemAtURL:self.testURL error:NULL];
    [super tearDown];
}
- (MPDocument *)newDraft
{
    NSError *error;
    MPDocument *document = [NSDocumentController.sharedDocumentController openUntitledDocumentAndDisplay:YES error:&error];
    XCTAssertNotNil(document);
    XCTAssertNil(error);
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    return document;
}
- (void)openURL:(NSURL *)url expectingSuccess:(BOOL)success
{
    XCTestExpectation *opened = [self expectationWithDescription:@"Document open completion"];
    [NSDocumentController.sharedDocumentController openDocumentWithContentsOfURL:url display:YES
        completionHandler:^(NSDocument *document, BOOL wasOpen, NSError *error) {
            XCTAssertEqual(document != nil, success);
            XCTAssertEqual(error == nil, success);
            [opened fulfill];
        }];
    [self waitForExpectationsWithTimeout:10 handler:nil];
}
- (void)testOpeningFileClosesOnlyInitialEmptyDraft
{
    NSDocumentController *controller = NSDocumentController.sharedDocumentController;
    XCTAssertTrue([controller isKindOfClass:MPDocumentController.class]);
    MPDocument *draft = [self newDraft];
    [self openURL:self.testURL expectingSuccess:YES];
    XCTAssertEqual(controller.documents.count, 1u);
    XCTAssertFalse([controller.documents containsObject:draft]);
    XCTAssertEqualObjects([controller.documents.firstObject fileURL], self.testURL);
}
- (void)testFailedOpenPreservesEmptyDraft
{
    MPDocument *draft = [self newDraft];
    [self openURL:[self.testURL URLByAppendingPathExtension:@"missing"] expectingSuccess:NO];
    XCTAssertTrue([NSDocumentController.sharedDocumentController.documents containsObject:draft]);
}
- (void)testOpeningFilePreservesNonemptyOrEditedDraft
{
    MPDocument *draft = [self newDraft];
    draft.markdown = @"Keep my text"; // Preserve content even before edit notifications settle.
    [self openURL:self.testURL expectingSuccess:YES];
    XCTAssertTrue([NSDocumentController.sharedDocumentController.documents containsObject:draft]);
    XCTAssertEqualObjects(draft.markdown, @"Keep my text");
}
- (void)testEditorPaneRestoresRatioAndMenuOnBothSides
{
    MPDocument *document = [self newDraft];
    BOOL originalSide = document.preferences.editorOnRight;
    @try
    {
        for (NSNumber *side in @[@NO, @YES])
        {
            document.preferences.editorOnRight = side.boolValue;
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
            MPDocumentSplitView *split = [document valueForKey:@"splitView"];
            split.dividerLocation = 0.37;
            CGFloat originalRatio = split.dividerLocation;
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(toggleEditorPane:) keyEquivalent:@""];
            for (NSUInteger repetition = 0; repetition < 3; repetition++)
            {
                [document toggleEditorPane:nil];
                XCTAssertFalse(document.editorVisible);
                [document validateUserInterfaceItem:item];
                XCTAssertEqualObjects(item.title, NSLocalizedString(@"Restore Editor Pane", nil));
                [document toggleEditorPane:nil];
                XCTAssertTrue(document.editorVisible);
                XCTAssertTrue(document.mcpEditor.editable);
                XCTAssertEqualWithAccuracy(split.dividerLocation, originalRatio, 0.01);
                [document validateUserInterfaceItem:item];
                XCTAssertEqualObjects(item.title, NSLocalizedString(@"Hide Editor Pane", nil));
                for (NSView *view in split.subviews) XCTAssertFalse(view.hidden);
            }
        }
    }
    @finally { document.preferences.editorOnRight = originalSide; }
}
- (void)testEditorPaneRestoresWithUninitializedRatio
{
    MPDocument *document = [self newDraft];
    [document toggleEditorPane:nil];
    [document setValue:@0 forKey:@"previousSplitRatio"];
    [document toggleEditorPane:nil];
    MPDocumentSplitView *split = [document valueForKey:@"splitView"];
    XCTAssertTrue(document.editorVisible);
    XCTAssertEqualWithAccuracy(split.dividerLocation, 0.5, 0.01);
}
- (void)testImmediateListsAreHighlightedAndRendered
{
    MPDocument *document = [self newDraft];
    MPRenderer *renderer = [MPRenderer new];
    renderer.delegate = (id<MPRendererDelegate>)document;
    for (NSString *marker in @[@"*", @"-", @"+", @"1."])
    {
        for (NSString *newline in @[@"\n", @"\r\n"])
        {
            NSString *markdown = [NSString stringWithFormat:@"Paragraph%@%@ item%@", newline, marker, newline];
            pmh_element **elements = NULL;
            pmh_markdown_to_elements((char *)markdown.UTF8String, 0, &elements);
            pmh_element_type type = [marker isEqual:@"1."] ? pmh_LIST_ENUMERATOR : pmh_LIST_BULLET;
            XCTAssertNotEqual(elements[type], NULL, @"%@", markdown);
            pmh_free_elements(elements);
            NSString *html = [renderer renderMarkdownSynchronously:markdown];
            XCTAssertTrue([html containsString:[marker isEqual:@"1."] ? @"<ol>" : @"<ul>"], @"%@", html);
            XCTAssertTrue([html containsString:@"<li>item</li>"], @"%@", html);
        }
    }
}
- (void)testListRelaxationPreservesNonListSyntax
{
    for (NSString *markdown in @[@"Paragraph\n*not a list\n", @"Heading\n---\n", @"`Paragraph\n* code`\n"])
    {
        pmh_element **elements = NULL;
        pmh_markdown_to_elements((char *)markdown.UTF8String, 0, &elements);
        XCTAssertEqual(elements[pmh_LIST_BULLET], NULL, @"%@", markdown);
        pmh_free_elements(elements);
    }
}
@end
