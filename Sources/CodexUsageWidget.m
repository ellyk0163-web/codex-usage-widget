#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ApplicationServices/ApplicationServices.h>

static NSString *const CodexBundleIdentifier = @"com.openai.codex";
static NSString *const CodexExecutable = @"/Applications/ChatGPT.app/Contents/Resources/codex";

@interface UsageBarView : NSView
@property(nonatomic, assign) CGFloat value;
@end

@implementation UsageBarView
- (BOOL)isFlipped { return YES; }
- (void)setValue:(CGFloat)value {
    _value = MIN(100, MAX(0, value));
    [self setNeedsDisplay:YES];
}
- (void)drawRect:(NSRect)dirtyRect {
    NSRect track = NSInsetRect(self.bounds, 0, 1);
    NSBezierPath *trackPath = [NSBezierPath bezierPathWithRoundedRect:track xRadius:4 yRadius:4];
    [[NSColor colorWithWhite:0 alpha:0.10] setFill];
    [trackPath fill];

    CGFloat width = MAX(7, NSWidth(track) * self.value / 100.0);
    NSRect fillRect = NSMakeRect(NSMinX(track), NSMinY(track), width, NSHeight(track));
    NSBezierPath *fillPath = [NSBezierPath bezierPathWithRoundedRect:fillRect xRadius:4 yRadius:4];
    NSColor *start = self.value >= 90 ? [NSColor colorWithSRGBRed:0.94 green:0.31 blue:0.34 alpha:1]
                                      : [NSColor colorWithSRGBRed:0.38 green:0.49 blue:0.96 alpha:1];
    NSColor *end = self.value >= 90 ? [NSColor colorWithSRGBRed:1 green:0.48 blue:0.30 alpha:1]
                                    : [NSColor colorWithSRGBRed:0.35 green:0.68 blue:0.98 alpha:1];
    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:start endingColor:end];
    [gradient drawInBezierPath:fillPath angle:0];
}
@end

@interface UsagePanelController : NSObject
@property(nonatomic, strong) NSPanel *panel;
@property(nonatomic, strong) UsageBarView *progress;
@property(nonatomic, strong) NSTextField *usageLabel;
@property(nonatomic, assign) BOOL fetching;
@property(nonatomic, assign) BOOL requestedAccessibilityPermission;
- (void)start;
- (void)refresh;
@end

@implementation UsagePanelController

- (instancetype)init {
    self = [super init];
    if (!self) return nil;

    self.panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 190, 24)
                                             styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
                                               backing:NSBackingStoreBuffered
                                                 defer:NO];
    self.panel.level = NSFloatingWindowLevel;
    self.panel.opaque = NO;
    self.panel.backgroundColor = NSColor.clearColor;
    self.panel.hasShadow = NO;
    self.panel.hidesOnDeactivate = NO;
    self.panel.movableByWindowBackground = YES;
    self.panel.collectionBehavior = NSWindowCollectionBehaviorMoveToActiveSpace | NSWindowCollectionBehaviorFullScreenAuxiliary;
    self.panel.ignoresMouseEvents = YES;
    self.panel.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];

    NSView *visual = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 190, 24)];
    visual.wantsLayer = YES;
    visual.layer.backgroundColor = NSColor.clearColor.CGColor;
    self.panel.contentView = visual;

    NSImageView *icon = [[NSImageView alloc] initWithFrame:NSMakeRect(5, 5, 14, 14)];
    icon.image = [NSImage imageWithSystemSymbolName:@"sparkles" accessibilityDescription:@"Codex"];
    icon.contentTintColor = [NSColor colorWithWhite:0.48 alpha:1];
    icon.imageScaling = NSImageScaleProportionallyUpOrDown;
    [visual addSubview:icon];

    self.progress = [[UsageBarView alloc] initWithFrame:NSMakeRect(26, 7, 50, 10)];
    self.progress.value = 0;
    [visual addSubview:self.progress];

    self.usageLabel = [NSTextField labelWithString:@"불러오는 중…"];
    self.usageLabel.frame = NSMakeRect(83, 3, 102, 18);
    self.usageLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    self.usageLabel.textColor = [NSColor colorWithWhite:0.30 alpha:1];
    self.usageLabel.alignment = NSTextAlignmentRight;
    [visual addSubview:self.usageLabel];

    return self;
}

- (void)start {
    [self refresh];
    [NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(refresh) userInfo:nil repeats:YES];
    [NSTimer scheduledTimerWithTimeInterval:1.5 target:self selector:@selector(followCodexWindow) userInfo:nil repeats:YES];
    [self followCodexWindow];
}

- (void)requestAccessibilityPermissionIfNeeded {
    if (AXIsProcessTrusted() || self.requestedAccessibilityPermission) return;
    self.requestedAccessibilityPermission = YES;
    NSDictionary *options = @{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES};
    AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
}

- (void)collectTextFromElement:(AXUIElementRef)element
                         depth:(NSInteger)depth
                     remaining:(NSInteger *)remaining
                       codexUI:(BOOL *)codexUI
                         gptUI:(BOOL *)gptUI {
    if (!element || depth > 24 || *remaining <= 0 || *gptUI) return;
    (*remaining)--;

    NSString *role = nil;
    CFTypeRef roleValue = NULL;
    if (AXUIElementCopyAttributeValue(element, kAXRoleAttribute, &roleValue) == kAXErrorSuccess && roleValue) {
        if (CFGetTypeID(roleValue) == CFStringGetTypeID()) role = [(__bridge NSString *)roleValue copy];
        CFRelease(roleValue);
    }

    NSArray *attributes = @[
        (__bridge NSString *)kAXTitleAttribute,
        (__bridge NSString *)kAXValueAttribute,
        (__bridge NSString *)kAXDescriptionAttribute,
        (__bridge NSString *)kAXHelpAttribute
    ];
    for (NSString *attribute in attributes) {
        CFTypeRef value = NULL;
        AXError error = AXUIElementCopyAttributeValue(element, (__bridge CFStringRef)attribute, &value);
        if (error != kAXErrorSuccess || !value) continue;
        if (CFGetTypeID(value) == CFStringGetTypeID()) {
            NSString *text = (__bridge NSString *)value;
            if ([text containsString:@"나 대신 승인"] ||
                [text containsString:@"무엇이든 요청하세요"] ||
                [text localizedCaseInsensitiveContainsString:@"Ask Codex"]) {
                *codexUI = YES;
            }
            if ([text containsString:@"ChatGPT에 메시지 보내기"] ||
                [text localizedCaseInsensitiveContainsString:@"Message ChatGPT"] ||
                (([text containsString:@"현재 모드"] ||
                  [text localizedCaseInsensitiveContainsString:@"current mode"]) &&
                 [text localizedCaseInsensitiveContainsString:@"ChatGPT"]) ||
                ([role isEqualToString:(__bridge NSString *)kAXButtonRole] &&
                 ([text caseInsensitiveCompare:@"ChatGPT"] == NSOrderedSame ||
                  [text caseInsensitiveCompare:@"ChatGPT Work"] == NSOrderedSame))) {
                *gptUI = YES;
            }
        }
        CFRelease(value);
    }

    CFTypeRef childrenValue = NULL;
    AXError childrenError = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute, &childrenValue);
    if (childrenError != kAXErrorSuccess || !childrenValue) return;
    if (CFGetTypeID(childrenValue) == CFArrayGetTypeID()) {
        NSArray *children = (__bridge NSArray *)childrenValue;
        for (id child in children) {
            [self collectTextFromElement:(__bridge AXUIElementRef)child
                                   depth:depth + 1
                               remaining:remaining
                                 codexUI:codexUI
                                   gptUI:gptUI];
            if (*gptUI || *remaining <= 0) break;
        }
    }
    CFRelease(childrenValue);
}

- (BOOL)isCodexSurfaceForPID:(pid_t)pid {
    if (!AXIsProcessTrusted()) {
        [self requestAccessibilityPermissionIfNeeded];
        // Keep the basic widget useful even before Accessibility is granted.
        // In that state we can still reliably hide it whenever ChatGPT/Codex
        // is not the frontmost app.
        return YES;
    }
    AXUIElementRef application = AXUIElementCreateApplication(pid);
    NSInteger remaining = 12000;
    BOOL codexUI = NO;
    BOOL gptUI = NO;
    [self collectTextFromElement:application depth:0 remaining:&remaining codexUI:&codexUI gptUI:&gptUI];
    CFRelease(application);
    // Only suppress the widget when the GPT composer is positively identified.
    // Unknown/new Codex UI variants should remain visible instead of vanishing.
    return !gptUI;
}

- (void)refresh {
    if (self.fetching) return;
    self.fetching = YES;
    self.usageLabel.stringValue = @"갱신 중…";

    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:CodexExecutable];
    task.arguments = @[@"app-server"];
    NSPipe *input = [NSPipe pipe];
    NSPipe *output = [NSPipe pipe];
    task.standardInput = input;
    task.standardOutput = output;
    task.standardError = [NSPipe pipe];

    __block NSMutableData *buffer = [NSMutableData data];
    __block BOOL done = NO;
    __weak typeof(self) weakSelf = self;

    void (^send)(NSDictionary *) = ^(NSDictionary *object) {
        NSData *json = [NSJSONSerialization dataWithJSONObject:object options:0 error:nil];
        if (!json) return;
        [[input fileHandleForWriting] writeData:json];
        [[input fileHandleForWriting] writeData:[NSData dataWithBytes:"\n" length:1]];
    };

    void (^finish)(NSDictionary *, NSError *) = ^(NSDictionary *response, NSError *error) {
        if (done) return;
        done = YES;
        output.fileHandleForReading.readabilityHandler = nil;
        [input.fileHandleForWriting closeFile];
        if (task.running) [task terminate];
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) selfRef = weakSelf;
            if (!selfRef) return;
            selfRef.fetching = NO;
            if (response) [selfRef renderResponse:response];
            else [selfRef renderError];
        });
    };

    output.fileHandleForReading.readabilityHandler = ^(NSFileHandle *handle) {
        NSData *data = handle.availableData;
        if (data.length == 0) return;
        [buffer appendData:data];
        while (YES) {
            const void *bytes = buffer.bytes;
            const void *newline = memchr(bytes, '\n', buffer.length);
            if (!newline) break;
            NSUInteger lineLength = (const uint8_t *)newline - (const uint8_t *)bytes;
            NSData *line = [buffer subdataWithRange:NSMakeRange(0, lineLength)];
            [buffer replaceBytesInRange:NSMakeRange(0, lineLength + 1) withBytes:NULL length:0];
            NSDictionary *message = [NSJSONSerialization JSONObjectWithData:line options:0 error:nil];
            NSNumber *messageId = message[@"id"];
            if (messageId.integerValue == 0) {
                send(@{@"method": @"initialized", @"params": @{}});
                send(@{@"method": @"account/rateLimits/read", @"id": @1});
            } else if (messageId.integerValue == 1) {
                finish(message, nil);
            }
        }
    };

    NSError *launchError = nil;
    if (![task launchAndReturnError:&launchError]) {
        finish(nil, launchError);
        return;
    }
    send(@{
        @"method": @"initialize",
        @"id": @0,
        @"params": @{
            @"clientInfo": @{
                @"name": @"codex_usage_widget",
                @"title": @"Codex Usage Widget",
                @"version": @"1.0.0"
            }
        }
    });
}

- (void)renderResponse:(NSDictionary *)response {
    NSDictionary *result = response[@"result"];
    NSDictionary *limits = result[@"rateLimits"];
    NSDictionary *primary = limits[@"primary"];
    NSNumber *usedNumber = primary[@"usedPercent"];
    NSNumber *resetNumber = primary[@"resetsAt"];
    if (!usedNumber || !resetNumber) {
        [self renderError];
        return;
    }

    NSInteger used = lround(usedNumber.doubleValue);
    self.progress.value = used;
    NSTimeInterval remainingSeconds = MAX(0, resetNumber.doubleValue - NSDate.date.timeIntervalSince1970);
    NSInteger totalHours = (NSInteger)floor(remainingSeconds / 3600.0);
    NSInteger days = totalHours / 24;
    NSInteger hours = totalHours % 24;
    NSString *time = days > 0 ? [NSString stringWithFormat:@"%ldd %02ldh", days, hours]
                              : [NSString stringWithFormat:@"%ldh", hours];
    self.usageLabel.stringValue = [NSString stringWithFormat:@"%ld%% 사용  %@", used, time];
}

- (void)renderError {
    self.usageLabel.stringValue = @"확인 실패";
    self.progress.value = 0;
}

- (CGRect)largestWindowBoundsForPID:(pid_t)pid found:(BOOL *)found {
    CFArrayRef infoRef = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID);
    NSArray *windows = CFBridgingRelease(infoRef);
    CGRect best = CGRectZero;
    CGFloat bestArea = 0;
    for (NSDictionary *item in windows) {
        if ([item[(id)kCGWindowOwnerPID] intValue] != pid || [item[(id)kCGWindowLayer] intValue] != 0) continue;
        CGRect rect = CGRectZero;
        if (!CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)item[(id)kCGWindowBounds], &rect)) continue;
        CGFloat area = rect.size.width * rect.size.height;
        if (rect.size.width > 500 && rect.size.height > 350 && area > bestArea) {
            best = rect;
            bestArea = area;
        }
    }
    *found = bestArea > 0;
    return best;
}

- (void)followCodexWindow {
    NSRunningApplication *frontmost = NSWorkspace.sharedWorkspace.frontmostApplication;
    if (![frontmost.bundleIdentifier isEqualToString:CodexBundleIdentifier] || frontmost.hidden) {
        [self.panel orderOut:nil];
        return;
    }

    BOOL found = NO;
    CGRect bounds = [self largestWindowBoundsForPID:frontmost.processIdentifier found:&found];
    if (!found || ![self isCodexSurfaceForPID:frontmost.processIdentifier]) {
        [self.panel orderOut:nil];
        return;
    }

    CGFloat mainMaxY = NSScreen.screens.firstObject.frame.size.height;
    CGFloat cocoaBottom = mainMaxY - CGRectGetMaxY(bounds);
    // Anchor to the fixed composer toolbar row. The editor grows upward.
    [self.panel setFrameOrigin:NSMakePoint(CGRectGetMidX(bounds) + 8,
                                           cocoaBottom + 27)];
    self.panel.alphaValue = 1.0;
    [self.panel orderFrontRegardless];
}

@end

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) UsagePanelController *usagePanel;
@property(nonatomic, strong) NSStatusItem *statusItem;
@end

@implementation AppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.usagePanel = [[UsagePanelController alloc] init];
    [self.usagePanel start];
    self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSSquareStatusItemLength];
    self.statusItem.button.image = [NSImage imageWithSystemSymbolName:@"gauge.with.dots.needle.50percent" accessibilityDescription:@"Codex 사용량"];
    NSMenu *menu = [[NSMenu alloc] init];
    NSMenuItem *refresh = [[NSMenuItem alloc] initWithTitle:@"지금 새로고침" action:@selector(refreshFromMenu) keyEquivalent:@"r"];
    refresh.target = self;
    [menu addItem:refresh];
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *quit = [[NSMenuItem alloc] initWithTitle:@"종료" action:@selector(quit) keyEquivalent:@"q"];
    quit.target = self;
    [menu addItem:quit];
    self.statusItem.menu = menu;
}
- (void)refreshFromMenu { [self.usagePanel refresh]; }
- (void)quit { [NSApp terminate:nil]; }
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
        [app run];
    }
    return 0;
}
