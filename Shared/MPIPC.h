// Local-only, newline-delimited JSON transport shared by the GUI and CLI.
#import <Foundation/Foundation.h>
#import <sys/socket.h>
#import <sys/un.h>
#import <unistd.h>
#import <errno.h>

static const NSUInteger MPMessageLimit = 8 * 1024 * 1024;
static inline NSString *MPSocketPath(void) {
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/MacDown SE/macdown_se.sock"];
}
static inline BOOL MPAddress(struct sockaddr_un *address) {
    memset(address, 0, sizeof(*address));
    address->sun_family = AF_UNIX;
    const char *path = MPSocketPath().fileSystemRepresentation;
    if (strlen(path) >= sizeof(address->sun_path)) return NO;
    strlcpy(address->sun_path, path, sizeof(address->sun_path));
    return YES;
}
static inline void MPConfigureSocket(int fd) {
    int yes = 1;
    setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, sizeof(yes));
    struct timeval timeout = {15, 0};
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));
}
static inline BOOL MPWriteJSON(int fd, NSDictionary *object) {
    NSData *json = [NSJSONSerialization dataWithJSONObject:object options:0 error:NULL];
    if (!json || json.length > MPMessageLimit) return NO;
    NSMutableData *line = [json mutableCopy];
    [line appendBytes:"\n" length:1];
    NSUInteger offset = 0;
    while (offset < line.length) {
        ssize_t count = write(fd, (const char *)line.bytes + offset, line.length - offset);
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) return NO;
        offset += count;
    }
    return YES;
}
// One request per socket connection. stdio uses buffered fgets below.
static inline NSData *MPReadLine(int fd) {
    NSMutableData *data = [NSMutableData data];
    char buffer[4096];
    while (data.length <= MPMessageLimit) {
        ssize_t count = read(fd, buffer, sizeof(buffer));
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) return nil;
        char *newline = memchr(buffer, '\n', count);
        [data appendBytes:buffer length:newline ? (NSUInteger)(newline-buffer) : (NSUInteger)count];
        if (data.length > MPMessageLimit) return nil;
        if (newline) return data;
    }
    return nil;
}
static inline NSDictionary *MPError(id identifier, NSInteger code, NSString *message) {
    return @{@"jsonrpc":@"2.0", @"id":identifier ?: NSNull.null,
             @"error":@{@"code":@(code), @"message":message}};
}
