#import "MPDocumentController.h"
#import "MPDocument.h"

@implementation MPDocumentController

- (void)openDocumentWithContentsOfURL:(NSURL *)url
                            display:(BOOL)display
                  completionHandler:(void (^)(NSDocument *, BOOL, NSError *))completionHandler
{
    __weak MPDocument *emptyDraft = nil;
    if (self.documents.count == 1)
    {
        id candidate = self.documents.firstObject;
        if ([candidate isKindOfClass:MPDocument.class])
        {
            MPDocument *draft = candidate;
            if (!draft.fileURL && !draft.isDocumentEdited && draft.mcpEditor
                    && draft.markdown.length == 0)
                emptyDraft = draft;
        }
    }
    [super openDocumentWithContentsOfURL:url display:display
                      completionHandler:^(NSDocument *document, BOOL wasOpen, NSError *error) {
        MPDocument *draft = emptyDraft;
        // Opening can finish later; never discard a draft edited in the meantime.
        if (document && !error && !wasOpen && draft && draft != document
                && !draft.fileURL && !draft.isDocumentEdited && draft.markdown.length == 0)
            [draft close];
        if (completionHandler)
            completionHandler(document, wasOpen, error);
    }];
}

@end
