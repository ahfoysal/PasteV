#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#import <Carbon/Carbon.h>

static NSString * const PasteVDefaultsKey = @"PasteV.clipboardItems.objc";

@interface ClipboardItem : NSObject <NSSecureCoding>
@property (nonatomic, strong) NSUUID *uuid;
@property (nonatomic, copy) NSString *text;
@property (nonatomic, strong) NSDate *date;
@property (nonatomic) BOOL pinned;
@end

@implementation ClipboardItem

+ (BOOL)supportsSecureCoding { return YES; }

- (instancetype)initWithText:(NSString *)text {
    self = [super init];
    if (self) {
        _uuid = [NSUUID UUID];
        _text = [text copy];
        _date = [NSDate date];
        _pinned = NO;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _uuid = [coder decodeObjectOfClass:NSUUID.class forKey:@"uuid"] ?: [NSUUID UUID];
        _text = [coder decodeObjectOfClass:NSString.class forKey:@"text"] ?: @"";
        _date = [coder decodeObjectOfClass:NSDate.class forKey:@"date"] ?: [NSDate date];
        _pinned = [coder decodeBoolForKey:@"pinned"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.uuid forKey:@"uuid"];
    [coder encodeObject:self.text forKey:@"text"];
    [coder encodeObject:self.date forKey:@"date"];
    [coder encodeBool:self.pinned forKey:@"pinned"];
}

@end

@class ClipboardStore;

@protocol ClipboardStoreObserver <NSObject>
- (void)clipboardStoreDidChange:(ClipboardStore *)store;
@end

@interface ClipboardStore : NSObject
@property (nonatomic, weak) id<ClipboardStoreObserver> observer;
@property (nonatomic, strong) NSMutableArray<ClipboardItem *> *items;
- (void)start;
- (NSArray<ClipboardItem *> *)orderedItemsMatching:(NSString *)query;
- (void)copyItemToPasteboard:(ClipboardItem *)item;
- (void)togglePin:(ClipboardItem *)item;
- (void)deleteItem:(ClipboardItem *)item;
- (void)clearUnpinned;
@end

@implementation ClipboardStore {
    NSInteger _lastChangeCount;
    NSTimer *_timer;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _items = [NSMutableArray array];
        _lastChangeCount = NSPasteboard.generalPasteboard.changeCount;
        [self load];
        [self capturePasteboardTextIfNeeded];
    }
    return self;
}

- (void)start {
    [_timer invalidate];
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.45 target:self selector:@selector(poll) userInfo:nil repeats:YES];
}

- (NSArray<ClipboardItem *> *)orderedItemsMatching:(NSString *)query {
    NSArray *sorted = [self.items sortedArrayUsingComparator:^NSComparisonResult(ClipboardItem *a, ClipboardItem *b) {
        if (a.pinned != b.pinned) {
            return a.pinned ? NSOrderedAscending : NSOrderedDescending;
        }
        return [b.date compare:a.date];
    }];

    if (query.length == 0) {
        return sorted;
    }

    NSMutableArray *filtered = [NSMutableArray array];
    for (ClipboardItem *item in sorted) {
        if ([item.text rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound) {
            [filtered addObject:item];
        }
    }
    return filtered;
}

- (void)copyItemToPasteboard:(ClipboardItem *)item {
    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    [pasteboard clearContents];
    [pasteboard setString:item.text forType:NSPasteboardTypeString];
    _lastChangeCount = pasteboard.changeCount;
}

- (void)togglePin:(ClipboardItem *)item {
    item.pinned = !item.pinned;
    [self saveAndNotify];
}

- (void)deleteItem:(ClipboardItem *)item {
    [self.items removeObject:item];
    [self saveAndNotify];
}

- (void)clearUnpinned {
    NSIndexSet *indexes = [self.items indexesOfObjectsPassingTest:^BOOL(ClipboardItem *item, NSUInteger idx, BOOL *stop) {
        return !item.pinned;
    }];
    [self.items removeObjectsAtIndexes:indexes];
    [self saveAndNotify];
}

- (void)poll {
    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    if (pasteboard.changeCount == _lastChangeCount) {
        return;
    }
    _lastChangeCount = pasteboard.changeCount;
    [self capturePasteboardTextIfNeeded];
}

- (void)capturePasteboardTextIfNeeded {
    NSString *text = [NSPasteboard.generalPasteboard stringForType:NSPasteboardTypeString];
    if (text.length == 0 || [[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] length] == 0) {
        return;
    }

    ClipboardItem *existing = nil;
    for (ClipboardItem *item in self.items) {
        if ([item.text isEqualToString:text]) {
            existing = item;
            break;
        }
    }

    if (existing && !existing.pinned) {
        [self.items removeObject:existing];
        [self.items addObject:[[ClipboardItem alloc] initWithText:text]];
    } else if (!existing) {
        [self.items addObject:[[ClipboardItem alloc] initWithText:text]];
    }

    [self trim];
    [self saveAndNotify];
}

- (void)trim {
    const NSUInteger maxItems = 60;
    NSArray *ordered = [self orderedItemsMatching:@""];
    NSMutableArray *trimmed = [NSMutableArray array];
    NSUInteger unpinnedCount = 0;

    for (ClipboardItem *item in ordered) {
        if (item.pinned || unpinnedCount < maxItems) {
            [trimmed addObject:item];
            if (!item.pinned) {
                unpinnedCount++;
            }
        }
    }
    self.items = trimmed;
}

- (void)load {
    NSData *data = [NSUserDefaults.standardUserDefaults dataForKey:PasteVDefaultsKey];
    if (!data) {
        return;
    }

    NSSet *classes = [NSSet setWithObjects:NSArray.class, NSMutableArray.class, ClipboardItem.class, NSUUID.class, NSString.class, NSDate.class, nil];
    NSArray *loaded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:data error:nil];
    if (loaded) {
        self.items = [loaded mutableCopy];
    }
}

- (void)saveAndNotify {
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.items requiringSecureCoding:YES error:nil];
    if (data) {
        [NSUserDefaults.standardUserDefaults setObject:data forKey:PasteVDefaultsKey];
    }
    [self.observer clipboardStoreDidChange:self];
}

@end

@interface PasteController : NSObject
@property (nonatomic, strong) NSRunningApplication *targetApplication;
- (void)rememberCurrentTarget;
- (BOOL)isAccessibilityTrusted;
- (void)requestAccessibilityPermission;
- (void)pasteIntoRememberedTarget;
@end

@implementation PasteController

- (void)rememberCurrentTarget {
    NSRunningApplication *current = NSWorkspace.sharedWorkspace.frontmostApplication;
    if (![current.bundleIdentifier isEqualToString:NSBundle.mainBundle.bundleIdentifier]) {
        self.targetApplication = current;
    }
}

- (BOOL)isAccessibilityTrusted {
    return AXIsProcessTrusted();
}

- (void)requestAccessibilityPermission {
    NSDictionary *options = @{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES};
    AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
}

- (void)pasteIntoRememberedTarget {
    if (![self isAccessibilityTrusted]) {
        [self requestAccessibilityPermission];
        return;
    }

    [self.targetApplication activateWithOptions:0];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
        CGEventRef keyDown = CGEventCreateKeyboardEvent(source, kVK_ANSI_V, true);
        CGEventRef keyUp = CGEventCreateKeyboardEvent(source, kVK_ANSI_V, false);
        CGEventSetFlags(keyDown, kCGEventFlagMaskCommand);
        CGEventSetFlags(keyUp, kCGEventFlagMaskCommand);
        CGEventPost(kCGHIDEventTap, keyDown);
        CGEventPost(kCGHIDEventTap, keyUp);
        if (keyDown) CFRelease(keyDown);
        if (keyUp) CFRelease(keyUp);
        if (source) CFRelease(source);
    });
}

@end

@interface FlippedView : NSView
@end

@implementation FlippedView
- (BOOL)isFlipped { return YES; }
@end

@interface ClipboardRowView : NSView
@property (nonatomic, strong) ClipboardItem *item;
@property (nonatomic, copy) void (^pickHandler)(ClipboardItem *);
@property (nonatomic, copy) void (^copyOnlyHandler)(ClipboardItem *);
@property (nonatomic, copy) void (^pinHandler)(ClipboardItem *);
@property (nonatomic, copy) void (^deleteHandler)(ClipboardItem *);
@end

@implementation ClipboardRowView {
    NSTextField *_textLabel;
    NSTextField *_metaLabel;
    NSImageView *_iconView;
}

- (instancetype)initWithItem:(ClipboardItem *)item {
    self = [super initWithFrame:NSMakeRect(0, 0, 390, 64)];
    if (self) {
        self.item = item;
        self.wantsLayer = YES;
        self.layer.cornerRadius = 8;
        self.layer.backgroundColor = [NSColor colorWithWhite:1 alpha:0.07].CGColor;

        _iconView = [[NSImageView alloc] initWithFrame:NSMakeRect(10, 40, 18, 18)];
        _iconView.image = [NSImage imageWithSystemSymbolName:item.pinned ? @"pin.fill" : @"doc.text" accessibilityDescription:nil];
        _iconView.contentTintColor = item.pinned ? NSColor.controlAccentColor : NSColor.secondaryLabelColor;
        [self addSubview:_iconView];

        _textLabel = [NSTextField wrappingLabelWithString:item.text];
        _textLabel.frame = NSMakeRect(38, 25, 335, 33);
        _textLabel.font = [NSFont systemFontOfSize:13];
        _textLabel.textColor = NSColor.labelColor;
        _textLabel.maximumNumberOfLines = 2;
        [self addSubview:_textLabel];

        _metaLabel = [NSTextField labelWithString:[self metadataTextForItem:item]];
        _metaLabel.frame = NSMakeRect(38, 8, 335, 14);
        _metaLabel.font = [NSFont systemFontOfSize:11];
        _metaLabel.textColor = NSColor.secondaryLabelColor;
        [self addSubview:_metaLabel];
    }
    return self;
}

- (NSString *)metadataTextForItem:(ClipboardItem *)item {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.timeStyle = NSDateFormatterShortStyle;
    formatter.dateStyle = NSDateFormatterNoStyle;
    NSString *time = [formatter stringFromDate:item.date];
    NSString *type = [item.text hasPrefix:@"http://"] || [item.text hasPrefix:@"https://"] ? @"Link" : @"Text";
    return item.pinned ? [NSString stringWithFormat:@"Pinned • %@ • %@", type, time] : [NSString stringWithFormat:@"%@ • %@", type, time];
}

- (void)mouseDown:(NSEvent *)event {
    if (self.pickHandler) {
        self.pickHandler(self.item);
    }
}

- (void)rightMouseDown:(NSEvent *)event {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
    NSMenuItem *pin = [[NSMenuItem alloc] initWithTitle:self.item.pinned ? @"Unpin" : @"Pin" action:@selector(pinItem:) keyEquivalent:@""];
    pin.target = self;
    [menu addItem:pin];
    NSMenuItem *copyOnly = [[NSMenuItem alloc] initWithTitle:@"Copy only" action:@selector(copyOnlyItem:) keyEquivalent:@""];
    copyOnly.target = self;
    [menu addItem:copyOnly];
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *delete = [[NSMenuItem alloc] initWithTitle:@"Delete" action:@selector(deleteItem:) keyEquivalent:@""];
    delete.target = self;
    [menu addItem:delete];
    [NSMenu popUpContextMenu:menu withEvent:event forView:self];
}

- (void)pinItem:(id)sender {
    if (self.pinHandler) {
        self.pinHandler(self.item);
    }
}

- (void)copyOnlyItem:(id)sender {
    if (self.copyOnlyHandler) {
        self.copyOnlyHandler(self.item);
    }
}

- (void)deleteItem:(id)sender {
    if (self.deleteHandler) {
        self.deleteHandler(self.item);
    }
}

@end

@interface PanelController : NSObject <ClipboardStoreObserver>
@property (nonatomic, strong) ClipboardStore *store;
@property (nonatomic, strong) PasteController *pasteController;
@end

@implementation PanelController {
    NSPanel *_panel;
    FlippedView *_listContent;
    NSVisualEffectView *_rootView;
    NSScrollView *_scrollView;
    NSTextField *_footer;
    id _outsideMonitor;
}

- (instancetype)initWithStore:(ClipboardStore *)store pasteController:(PasteController *)pasteController {
    self = [super init];
    if (self) {
        _store = store;
        _pasteController = pasteController;
        _store.observer = self;
    }
    return self;
}

- (void)toggleAtMouse {
    if (_panel.visible) {
        [self close];
    } else {
        [self showAtMouse];
    }
}

- (void)showAtMouse {
    if (_panel) {
        [self close];
    }

    [self.pasteController rememberCurrentTarget];

    NSSize panelSize = [self panelSizeForItemCount:self.store.items.count];
    NSRect frame = NSMakeRect(0, 0, panelSize.width, panelSize.height);
    _panel = [[NSPanel alloc] initWithContentRect:frame styleMask:NSWindowStyleMaskNonactivatingPanel | NSWindowStyleMaskFullSizeContentView backing:NSBackingStoreBuffered defer:NO];
    _panel.level = NSFloatingWindowLevel;
    _panel.floatingPanel = YES;
    _panel.opaque = NO;
    _panel.backgroundColor = NSColor.clearColor;
    _panel.hasShadow = YES;
    _panel.hidesOnDeactivate = NO;
    _panel.movableByWindowBackground = YES;
    _panel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorTransient | NSWindowCollectionBehaviorFullScreenAuxiliary;

    NSVisualEffectView *root = [[NSVisualEffectView alloc] initWithFrame:frame];
    root.material = NSVisualEffectMaterialHUDWindow;
    root.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    root.state = NSVisualEffectStateActive;
    root.wantsLayer = YES;
    root.layer.cornerRadius = 10;
    root.layer.masksToBounds = YES;
    _rootView = root;
    _panel.contentView = root;

    NSTextField *title = [NSTextField labelWithString:@"Clipboard"];
    title.frame = NSMakeRect(14, panelSize.height - 36, 180, 22);
    title.font = [NSFont systemFontOfSize:16 weight:NSFontWeightSemibold];
    [root addSubview:title];

    NSButton *clearButton = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"trash" accessibilityDescription:@"Clear unpinned history"] target:self action:@selector(clearUnpinned:)];
    clearButton.frame = NSMakeRect(panelSize.width - 42, panelSize.height - 40, 28, 28);
    clearButton.bezelStyle = NSBezelStyleTexturedRounded;
    clearButton.image = [NSImage imageWithSystemSymbolName:@"trash" accessibilityDescription:@"Clear unpinned history"];
    clearButton.toolTip = @"Clear unpinned history";
    [root addSubview:clearButton];

    CGFloat footerHeight = 34;
    CGFloat headerHeight = 46;
    CGFloat listHeight = panelSize.height - headerHeight - footerHeight;
    _scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(10, footerHeight, panelSize.width - 20, listHeight)];
    _scrollView.drawsBackground = NO;
    _scrollView.hasVerticalScroller = self.store.items.count > [self maxVisibleRows];
    _listContent = [[FlippedView alloc] initWithFrame:NSMakeRect(0, 0, 390, 392)];
    _scrollView.documentView = _listContent;
    [root addSubview:_scrollView];

    _footer = [NSTextField labelWithString:@""];
    _footer.frame = NSMakeRect(28, 9, panelSize.width - 42, 18);
    _footer.font = [NSFont systemFontOfSize:12];
    _footer.textColor = NSColor.secondaryLabelColor;
    [root addSubview:_footer];

    NSView *statusDot = [[NSView alloc] initWithFrame:NSMakeRect(14, 17, 8, 8)];
    statusDot.wantsLayer = YES;
    statusDot.layer.cornerRadius = 4;
    statusDot.layer.backgroundColor = ([self.pasteController isAccessibilityTrusted] ? NSColor.systemGreenColor : NSColor.systemOrangeColor).CGColor;
    [root addSubview:statusDot];

    if (![self.pasteController isAccessibilityTrusted]) {
        NSButton *allow = [NSButton buttonWithTitle:@"Allow" target:self action:@selector(requestPermission:)];
        allow.frame = NSMakeRect(348, 8, 68, 24);
        allow.bezelStyle = NSBezelStyleRounded;
        [root addSubview:allow];
    }

    [self rebuildRows];
    [self positionPanelAtMouse];
    [_panel orderFrontRegardless];

    __weak typeof(self) weakSelf = self;
    _outsideMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown | NSEventMaskRightMouseDown handler:^(NSEvent *event) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        if (strongSelf->_panel.visible && NSPointInRect(NSEvent.mouseLocation, strongSelf->_panel.frame)) {
            return;
        }
        [strongSelf close];
    }];
}

- (void)positionPanelAtMouse {
    NSSize size = _panel.frame.size;
    NSPoint mouse = NSEvent.mouseLocation;
    NSScreen *screen = NSScreen.mainScreen;
    for (NSScreen *candidate in NSScreen.screens) {
        if (NSPointInRect(mouse, candidate.frame)) {
            screen = candidate;
            break;
        }
    }
    NSRect visible = screen.visibleFrame;
    CGFloat x = mouse.x - 18;
    CGFloat y = mouse.y - size.height + 18;
    if (x + size.width > NSMaxX(visible)) x = NSMaxX(visible) - size.width - 8;
    if (x < NSMinX(visible)) x = NSMinX(visible) + 8;
    if (y < NSMinY(visible)) y = MIN(mouse.y + 18, NSMaxY(visible) - size.height - 8);
    if (y + size.height > NSMaxY(visible)) y = NSMaxY(visible) - size.height - 8;
    [_panel setFrame:NSMakeRect(x, y, size.width, size.height) display:YES];
}

- (void)rebuildRows {
    for (NSView *view in _listContent.subviews.copy) {
        [view removeFromSuperview];
    }

    NSArray *items = [self.store orderedItemsMatching:@""];
    NSString *permission = [self.pasteController isAccessibilityTrusted] ? @"Ready to paste" : @"Accessibility permission needed";
    _footer.stringValue = [NSString stringWithFormat:@"%@ • %lu items", permission, (unsigned long)self.store.items.count];

    _scrollView.hasVerticalScroller = items.count > [self maxVisibleRows];

    if (items.count == 0) {
        NSTextField *empty = [NSTextField labelWithString:@"Copy text and it appears here."];
        empty.font = [NSFont systemFontOfSize:13];
        empty.textColor = NSColor.secondaryLabelColor;
        empty.alignment = NSTextAlignmentCenter;
        empty.frame = NSMakeRect(8, 22, _scrollView.frame.size.width - 16, 24);
        [_listContent addSubview:empty];
        _listContent.frame = NSMakeRect(0, 0, _scrollView.frame.size.width - 4, _scrollView.frame.size.height);
        return;
    }

    __weak typeof(self) weakSelf = self;
    CGFloat y = 8;
    CGFloat rowWidth = _scrollView.frame.size.width - 18;
    for (ClipboardItem *item in items) {
        ClipboardRowView *row = [[ClipboardRowView alloc] initWithItem:item];
        row.frame = NSMakeRect(8, y, rowWidth, 64);
        row.pickHandler = ^(ClipboardItem *picked) {
            [weakSelf.store copyItemToPasteboard:picked];
            [weakSelf close];
            [weakSelf.pasteController pasteIntoRememberedTarget];
        };
        row.copyOnlyHandler = ^(ClipboardItem *picked) {
            [weakSelf.store copyItemToPasteboard:picked];
            [weakSelf close];
        };
        row.pinHandler = ^(ClipboardItem *picked) {
            [weakSelf.store togglePin:picked];
        };
        row.deleteHandler = ^(ClipboardItem *picked) {
            [weakSelf.store deleteItem:picked];
        };
        [_listContent addSubview:row];
        y += 70;
    }

    CGFloat height = MAX(_scrollView.frame.size.height, y + 8);
    _listContent.frame = NSMakeRect(0, 0, _scrollView.frame.size.width - 4, height);
}

- (void)clipboardStoreDidChange:(ClipboardStore *)store {
    if (_panel.visible) {
        [self rebuildRows];
    }
}

- (void)close {
    if (_outsideMonitor) {
        [NSEvent removeMonitor:_outsideMonitor];
        _outsideMonitor = nil;
    }
    [_panel close];
    _panel = nil;
}

- (void)clearUnpinned:(id)sender {
    [self.store clearUnpinned];
}

- (void)requestPermission:(id)sender {
    [self.pasteController requestAccessibilityPermission];
}

- (NSUInteger)maxVisibleRows {
    return 6;
}

- (NSSize)panelSizeForItemCount:(NSUInteger)itemCount {
    CGFloat width = 430;
    CGFloat headerHeight = 46;
    CGFloat footerHeight = 34;
    CGFloat emptyHeight = 74;
    CGFloat rowBlock = 70;
    NSUInteger visibleRows = MIN(MAX(itemCount, 1), [self maxVisibleRows]);
    CGFloat listHeight = itemCount == 0 ? emptyHeight : (visibleRows * rowBlock) + 8;
    CGFloat height = headerHeight + listHeight + footerHeight;
    return NSMakeSize(width, MIN(height, 520));
}

@end

@interface AppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation AppDelegate {
    ClipboardStore *_store;
    PasteController *_pasteController;
    PanelController *_panelController;
    NSStatusItem *_statusItem;
    EventHotKeyRef _hotKeyRef;
    EventHandlerRef _eventHandlerRef;
}

static OSStatus HotKeyHandler(EventHandlerCallRef nextHandler, EventRef event, void *userData) {
    AppDelegate *delegate = (__bridge AppDelegate *)userData;
    dispatch_async(dispatch_get_main_queue(), ^{
        [delegate showOrHideFromHotKey];
    });
    return noErr;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    _store = [[ClipboardStore alloc] init];
    [_store start];
    _pasteController = [[PasteController alloc] init];
    _panelController = [[PanelController alloc] initWithStore:_store pasteController:_pasteController];
    [self installHotKey];
    [self installStatusItem];
}

- (void)installHotKey {
    EventTypeSpec eventType;
    eventType.eventClass = kEventClassKeyboard;
    eventType.eventKind = kEventHotKeyPressed;
    InstallEventHandler(GetApplicationEventTarget(), HotKeyHandler, 1, &eventType, (__bridge void *)self, &_eventHandlerRef);

    EventHotKeyID hotKeyID;
    hotKeyID.signature = 'PSTV';
    hotKeyID.id = 1;
    RegisterEventHotKey(kVK_ANSI_V, controlKey, hotKeyID, GetApplicationEventTarget(), 0, &_hotKeyRef);
}

- (void)installStatusItem {
    _statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    NSImage *statusImage = [NSImage imageNamed:@"StatusIconTemplate"];
    statusImage.template = YES;
    _statusItem.button.image = statusImage ?: [NSImage imageWithSystemSymbolName:@"doc.on.clipboard" accessibilityDescription:@"PasteV"];

    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"PasteV"];
    [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Show Clipboard" action:@selector(showClipboard:) keyEquivalent:@""]];
    [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Request Accessibility Permission" action:@selector(requestPermission:) keyEquivalent:@""]];
    [menu addItem:NSMenuItem.separatorItem];
    [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Quit PasteV" action:@selector(quit:) keyEquivalent:@"q"]];
    _statusItem.menu = menu;
}

- (void)showOrHideFromHotKey {
    [_panelController toggleAtMouse];
}

- (void)showClipboard:(id)sender {
    [_panelController showAtMouse];
}

- (void)requestPermission:(id)sender {
    [_pasteController requestAccessibilityPermission];
}

- (void)quit:(id)sender {
    [NSApp terminate:nil];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    if (_hotKeyRef) UnregisterEventHotKey(_hotKeyRef);
    if (_eventHandlerRef) RemoveEventHandler(_eventHandlerRef);
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
