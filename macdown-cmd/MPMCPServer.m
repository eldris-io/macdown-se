#import "MPMCPServer.h"
#import "../Shared/MPIPC.h"
#import <AppKit/AppKit.h>
#import <mach-o/dyld.h>
#import <signal.h>

static int MPConnect(void) {
    struct sockaddr_un address;
    if (!MPAddress(&address)) return -1;
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return -1;
    MPConfigureSocket(fd);
    if (connect(fd, (struct sockaddr *)&address, sizeof(address))) { close(fd); return -1; }
    uid_t uid; gid_t gid;
    if (getpeereid(fd, &uid, &gid) || uid != getuid()) { close(fd); return -1; }
    return fd;
}
static NSDictionary *MPDispatch(NSString *method, NSDictionary *arguments) {
    int fd = MPConnect();
    if (fd < 0) {
        NSWorkspace *workspace = NSWorkspace.sharedWorkspace;
        // Resolve the executable (including a PATH symlink) to prefer its own app build.
        char executable[PATH_MAX]; uint32_t size = sizeof(executable);
        NSURL *url;
        if (_NSGetExecutablePath(executable, &size) == 0) {
            NSString *path = [[NSString stringWithUTF8String:executable] stringByResolvingSymlinksInPath];
            for (int i = 0; i < 4; i++) path = path.stringByDeletingLastPathComponent;
            NSBundle *bundle = [NSBundle bundleWithPath:path];
            if ([bundle.bundleIdentifier isEqual:@"io.eldris.macdown-se"]) url = bundle.bundleURL;
        }
        if (!url) url = [workspace URLForApplicationWithBundleIdentifier:@"io.eldris.macdown-se"];
        if (!url) return MPError(@1, -32000, @"MacDown SE.app was not found");
        NSWorkspaceOpenConfiguration *configuration = [NSWorkspaceOpenConfiguration configuration];
        configuration.activates = NO;
        __block BOOL completed = NO;
        __block NSError *launchError;
        [workspace openApplicationAtURL:url configuration:configuration completionHandler:^(NSRunningApplication *application, NSError *error) {
            launchError = error;
            completed = YES;
        }];
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:10];
        while (!completed && deadline.timeIntervalSinceNow > 0)
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        if (launchError) return MPError(@1, -32000, launchError.localizedDescription);
        for (int attempt = 0; attempt < 100 && fd < 0; attempt++) { usleep(100000); fd = MPConnect(); }
    }
    if (fd < 0) return MPError(@1, -32000, @"MacDown SE local socket unavailable after 10 seconds");
    BOOL sent = MPWriteJSON(fd, @{@"jsonrpc":@"2.0", @"id":@1, @"method":method, @"params":arguments});
    NSData *line = sent ? MPReadLine(fd) : nil;
    close(fd);
    id response = line ? [NSJSONSerialization JSONObjectWithData:line options:0 error:NULL] : nil;
    return [response isKindOfClass:NSDictionary.class] ? response : MPError(@1, -32000, @"Local editor request failed or timed out");
}
static NSArray *MPTools(void) {
    NSArray *names = @[@"macdown_get_active_document", @"macdown_replace_selection", @"macdown_insert_at_cursor", @"macdown_new_document", @"macdown_render_preview"];
    NSArray *descriptions = @[@"Read the active document, selection and UTF-16 selectedRange.", @"Replace the selection with text; undo with AI Edit.", @"Insert text at the selection start without deleting selected text; undo with AI Edit.", @"Open a new document containing markdown.", @"Render markdown with MacDown's native parser and current preferences."];
    NSMutableArray *tools = [NSMutableArray array];
    for (NSUInteger i = 0; i < names.count; i++) {
        NSString *key = i >= 3 ? @"markdown" : @"text";
        NSDictionary *schema = @{@"type":@"object", @"properties":i == 0 ? @{} : @{key:@{@"type":@"string"}}, @"required":i == 0 ? @[] : @[key], @"additionalProperties":@NO};
        [tools addObject:@{@"name":names[i], @"description":descriptions[i], @"inputSchema":schema}];
    }
    return tools;
}
static NSDictionary *MPHandle(id request, BOOL *initialized, BOOL *ready) {
    if (![request isKindOfClass:NSDictionary.class]) return MPError(nil, -32600, @"Invalid request");
    id identifier = request[@"id"];
    if (![request[@"jsonrpc"] isEqual:@"2.0"] || ![request[@"method"] isKindOfClass:NSString.class] ||
        (identifier && ![identifier isKindOfClass:NSString.class] && ![identifier isKindOfClass:NSNumber.class] && identifier != NSNull.null))
        return MPError(nil, -32600, @"Invalid request");
    NSString *method = request[@"method"];
    if (!identifier) {
        if ([method isEqual:@"notifications/initialized"] && *initialized) *ready = YES;
        return nil;
    }
    NSDictionary *params = request[@"params"] ?: @{};
    if (![params isKindOfClass:NSDictionary.class]) return MPError(identifier, -32602, @"Invalid params");
    id result;
    if ([method isEqual:@"initialize"]) {
        if (*initialized) return MPError(identifier, -32600, @"Already initialized");
        if (![params[@"protocolVersion"] isKindOfClass:NSString.class] || ![params[@"capabilities"] isKindOfClass:NSDictionary.class] || ![params[@"clientInfo"] isKindOfClass:NSDictionary.class]) return MPError(identifier, -32602, @"Invalid initialize parameters");
        *initialized = YES;
        result = @{@"protocolVersion":@"2024-11-05", @"serverInfo":@{@"name":@"macdown-se", @"version":@"1.0.0"}, @"capabilities":@{@"tools":@{}, @"resources":@{}}};
    } else if ([method isEqual:@"ping"]) result = @{};
    else if (!*ready) return MPError(identifier, -32002, @"Initialize and send notifications/initialized first");
    else if ([method isEqual:@"tools/list"]) result = @{@"tools":MPTools()};
    else if ([method isEqual:@"resources/list"]) result = @{@"resources":@[@{@"uri":@"macdown://active", @"name":@"Active Markdown document", @"mimeType":@"text/markdown"}]};
    else if ([method isEqual:@"resources/read"]) {
        if (![params[@"uri"] isEqual:@"macdown://active"]) return MPError(identifier, -32602, @"Unknown resource URI");
        NSDictionary *reply = MPDispatch(@"getActiveDocument", @{});
        if (reply[@"error"]) return MPError(identifier, -32001, reply[@"error"][@"message"]);
        result = @{@"contents":@[@{@"uri":@"macdown://active", @"mimeType":@"text/markdown", @"text":reply[@"result"][@"content"]}]};
    } else if ([method isEqual:@"tools/call"]) {
        NSDictionary *mapping = @{@"macdown_get_active_document":@"getActiveDocument", @"macdown_replace_selection":@"replaceSelection", @"macdown_insert_at_cursor":@"insertAtCursor", @"macdown_new_document":@"newDocument", @"macdown_render_preview":@"renderHTML"};
        NSString *name = params[@"name"];
        if (![name isKindOfClass:NSString.class] || !mapping[name]) return MPError(identifier, -32602, @"Unknown tool");
        NSDictionary *arguments = params[@"arguments"] ?: @{};
        NSString *key = ([name isEqual:@"macdown_new_document"] || [name isEqual:@"macdown_render_preview"]) ? @"markdown" : @"text";
        BOOL noArguments = [name isEqual:@"macdown_get_active_document"];
        if (![arguments isKindOfClass:NSDictionary.class] || (noArguments ? arguments.count != 0 : (arguments.count != 1 || ![arguments[key] isKindOfClass:NSString.class]))) return MPError(identifier, -32602, @"Invalid tool arguments");
        NSDictionary *reply = MPDispatch(mapping[name], arguments);
        BOOL failed = reply[@"error"] != nil;
        id value = failed ? reply[@"error"][@"message"] : reply[@"result"];
        NSString *text = [value isKindOfClass:NSString.class] ? value : [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:value options:0 error:NULL] encoding:NSUTF8StringEncoding];
        result = @{@"content":@[@{@"type":@"text", @"text":text ?: @""}], @"isError":@(failed)};
    } else return MPError(identifier, -32601, @"Method not found");
    return @{@"jsonrpc":@"2.0", @"id":identifier, @"result":result};
}
int MPRunMCPServer(void) {
    signal(SIGPIPE, SIG_IGN);
    NSDictionary *startup = MPDispatch(@"ping", @{});
    if (startup[@"error"]) {
        fprintf(stderr, "macdown-se: %s\n", [startup[@"error"][@"message"] UTF8String]);
        return EXIT_FAILURE;
    }
    BOOL initialized = NO, ready = NO;
    // Bounded buffering, including malformed input. Never emit diagnostics to stdout.
    NSMutableData *line = [NSMutableData data];
    BOOL oversized = NO;
    int ch;
    while ((ch = fgetc(stdin)) != EOF) {
        if (ch != '\n') {
            if (line.length < MPMessageLimit) { unsigned char byte = ch; [line appendBytes:&byte length:1]; }
            else oversized = YES;
            continue;
        }
        @autoreleasepool {
            id request = oversized ? nil : [NSJSONSerialization JSONObjectWithData:line options:NSJSONReadingFragmentsAllowed error:NULL];
            NSDictionary *reply = request ? MPHandle(request, &initialized, &ready) : MPError(nil, -32700, @"Invalid JSON or oversized request");
            if (reply && !MPWriteJSON(STDOUT_FILENO, reply) &&
                !MPWriteJSON(STDOUT_FILENO, MPError(reply[@"id"], -32000, @"Response exceeds transport limit"))) return EXIT_FAILURE;
            [line setLength:0]; oversized = NO;
        }
    }
    return EXIT_SUCCESS;
}
