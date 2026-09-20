#import "MPLocalIPCServer.h"
#import "MPDocument.h"
#import "MPRenderer.h"
#import "MPPreferences.h"
#import "../../../../Shared/MPIPC.h"
#import <Cocoa/Cocoa.h>
#import <sys/stat.h>
#import <fcntl.h>
#import <signal.h>

@interface MPLocalIPCServer ()
@property (strong) dispatch_source_t listener;
@property BOOL ownsSocket;
@property (weak) MPDocument *lastDocument;
@end

@interface MPPreferences (MCPRendering)
- (int)rendererFlags;
@end

@implementation MPLocalIPCServer
- (NSDictionary *)documentState:(MPDocument *)document {
    NSTextView *editor = document.mcpEditor;
    NSString *text = editor.string ?: @"";
    NSRange range = editor.selectedRange;
    __block NSUInteger words = 0;
    [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
                            options:NSStringEnumerationByWords
                         usingBlock:^(NSString *s, NSRange r, NSRange e, BOOL *stop) { words++; }];
    return @{@"path":document.fileURL.path ?: NSNull.null, @"title":document.displayName ?: @"Untitled",
             @"content":text, @"selection":[text substringWithRange:range],
             @"selectedRange":@{@"location":@(range.location), @"length":@(range.length)},
             @"isDirty":@(document.mcpIsDirty), @"wordCount":@(words)};
}
- (NSDictionary *)handle:(NSDictionary *)request {
    id identifier = request[@"id"];
    if (![request[@"jsonrpc"] isEqual:@"2.0"] || ![request[@"method"] isKindOfClass:NSString.class])
        return MPError(identifier, -32600, @"Invalid request");
    NSString *method = request[@"method"];
    NSDictionary *params = request[@"params"] ?: @{};
    if (![params isKindOfClass:NSDictionary.class]) return MPError(identifier, -32602, @"Invalid params");
    NSDocumentController *controller = NSDocumentController.sharedDocumentController;
    MPDocument *document = (MPDocument *)controller.currentDocument;
    if (![document isKindOfClass:MPDocument.class]) document = nil;
    if (!document) {
        for (NSWindow *window in NSApp.orderedWindows) {
            id candidate = window.windowController.document;
            if ([candidate isKindOfClass:MPDocument.class] && window.isVisible) { document = candidate; break; }
        }
    }
    if (!document && [controller.documents containsObject:self.lastDocument]) document = self.lastDocument;
    id result;
    if ([method isEqual:@"ping"]) result = @{};
    else if ([method isEqual:@"renderHTML"]) {
        if (![params[@"markdown"] isKindOfClass:NSString.class]) return MPError(identifier, -32602, @"markdown must be a string");
        // A fresh renderer uses the same parser and preference delegate without mutating the preview.
        MPDocument *preferencesDelegate = document ?: [[MPDocument alloc] init];
        MPRenderer *renderer = [[MPRenderer alloc] init];
        renderer.delegate = (id<MPRendererDelegate>)preferencesDelegate;
        renderer.rendererFlags = [preferencesDelegate.preferences rendererFlags];
        result = [renderer renderMarkdownSynchronously:params[@"markdown"]];
    } else if ([method isEqual:@"newDocument"]) {
        if (![params[@"markdown"] isKindOfClass:NSString.class]) return MPError(identifier, -32602, @"markdown must be a string");
        NSError *error;
        document = [controller openUntitledDocumentAndDisplay:YES error:&error];
        if (!document) return MPError(identifier, -32000, error.localizedDescription ?: @"Cannot create document");
        self.lastDocument = document;
        document.markdown = params[@"markdown"];
        document.mcpEditor.selectedRange = NSMakeRange(document.markdown.length, 0);
        if (document.markdown.length) [document updateChangeCount:NSChangeDone];
        [document.mcpEditor didChangeText];
        result = [self documentState:document];
    } else if ([method isEqual:@"getActiveDocument"] || [method isEqual:@"replaceSelection"] || [method isEqual:@"insertAtCursor"]) {
        if (!document.mcpEditor) return MPError(identifier, -32001, @"No active Markdown document");
        if (![method isEqual:@"getActiveDocument"]) {
            if (![params[@"text"] isKindOfClass:NSString.class]) return MPError(identifier, -32602, @"text must be a string");
            NSTextView *editor = document.mcpEditor;
            NSRange range = editor.selectedRange;
            if ([method isEqual:@"insertAtCursor"]) range.length = 0;
            NSString *previousText = [editor.string copy];
            [editor breakUndoCoalescing];
            BOOL groupsByEvent = document.undoManager.groupsByEvent;
            document.undoManager.groupsByEvent = NO;
            [document.undoManager beginUndoGrouping];
            @try {
                [editor insertText:params[@"text"] replacementRange:range];
                [editor breakUndoCoalescing];
                [document.undoManager setActionName:@"AI Edit"];
                if (![editor.string isEqualToString:previousText]) [document mcpDidEdit];
            } @finally {
                [document.undoManager endUndoGrouping];
                document.undoManager.groupsByEvent = groupsByEvent;
            }
        }
        result = [self documentState:document];
    } else return MPError(identifier, -32601, @"Unknown method");
    return @{@"jsonrpc":@"2.0", @"id":identifier ?: NSNull.null, @"result":result ?: NSNull.null};
}
- (BOOL)start {
    signal(SIGPIPE, SIG_IGN);
    NSString *directory = MPSocketPath().stringByDeletingLastPathComponent;
    NSError *error;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&error]) return NO;
    struct stat status;
    if (lstat(directory.fileSystemRepresentation, &status) || !S_ISDIR(status.st_mode) || status.st_uid != getuid()) return NO;
    chmod(directory.fileSystemRepresentation, 0700);
    struct sockaddr_un address;
    if (!MPAddress(&address)) return NO;
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return NO;
    // Never replace another live instance's socket, or a non-socket file.
    if (!lstat(address.sun_path, &status)) {
        if (!S_ISSOCK(status.st_mode) || status.st_uid != getuid()) { close(fd); return NO; }
        if (connect(fd, (struct sockaddr *)&address, sizeof(address)) == 0) { close(fd); return NO; }
        if (errno != ECONNREFUSED && errno != ENOENT) { close(fd); return NO; }
        unlink(address.sun_path);
        close(fd);
        fd = socket(AF_UNIX, SOCK_STREAM, 0);
        if (fd < 0) return NO;
    }
    if (bind(fd, (struct sockaddr *)&address, sizeof(address)) || chmod(address.sun_path, 0600) || listen(fd, 8)) { close(fd); return NO; }
    self.ownsSocket = YES;
    fcntl(fd, F_SETFL, O_NONBLOCK);
    dispatch_queue_t queue = dispatch_queue_create("io.eldris.macdown-se.ipc", DISPATCH_QUEUE_SERIAL);
    dispatch_semaphore_t slots = dispatch_semaphore_create(8);
    self.listener = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, fd, 0, queue);
    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(self.listener, ^{
        int client = accept(fd, NULL, NULL);
        if (client < 0) return;
        uid_t uid; gid_t gid;
        if (getpeereid(client, &uid, &gid) || uid != getuid() || dispatch_semaphore_wait(slots, DISPATCH_TIME_NOW)) { close(client); return; }
        fcntl(client, F_SETFL, fcntl(client, F_GETFL) & ~O_NONBLOCK);
        MPConfigureSocket(client);
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            @autoreleasepool {
                NSData *line = MPReadLine(client);
                id request = line ? [NSJSONSerialization JSONObjectWithData:line options:0 error:NULL] : nil;
                __block NSDictionary *reply = MPError(nil, -32700, @"Invalid JSON or oversized request");
                if ([request isKindOfClass:NSDictionary.class]) dispatch_sync(dispatch_get_main_queue(), ^{
                    @try { reply = [weakSelf handle:request]; }
                    @catch (NSException *exception) { reply = MPError(request[@"id"], -32603, @"Editor operation failed"); }
                });
                if (reply && !MPWriteJSON(client, reply)) MPWriteJSON(client, MPError(reply[@"id"], -32000, @"Response exceeds transport limit or peer disconnected"));
                close(client);
                dispatch_semaphore_signal(slots);
            }
        });
    });
    dispatch_source_set_cancel_handler(self.listener, ^{ close(fd); });
    dispatch_resume(self.listener);
    return YES;
}
- (void)stop {
    if (self.listener) { dispatch_source_cancel(self.listener); self.listener = nil; }
    if (self.ownsSocket) { unlink(MPSocketPath().fileSystemRepresentation); self.ownsSocket = NO; }
}
@end
