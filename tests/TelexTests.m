#import <AppKit/AppKit.h>
#import <Carbon/Carbon.h>
#import <InputMethodKit/InputMethodKit.h>
#import "../src/Telex.h"

@interface TestTextView : NSTextView
@property(nonatomic, copy) NSAttributedString *composition;
@end

@class InPlaceTextView;

@implementation TestTextView
- (BOOL)respondsToSelector:(SEL)selector
{
    if (selector == @selector(attributedSubstringFromRange:)) {
        return [self isKindOfClass:NSClassFromString(@"InPlaceTextView")];
    }
    return [super respondsToSelector:selector];
}
- (void)setMarkedText:(id)string selectionRange:(NSRange)selection replacementRange:(NSRange)replacement
{
    self.composition = [string isKindOfClass:NSAttributedString.class] ? string : nil;
    [self setMarkedText:string selectedRange:selection replacementRange:replacement];
}
@end

@interface NoEmptyCommitTextView : TestTextView
@end

@implementation NoEmptyCommitTextView
- (void)insertText:(id)string replacementRange:(NSRange)replacement
{
    if ([string length] != 0) [super insertText:string replacementRange:replacement];
}
@end

@interface InPlaceTextView : TestTextView
@end

@implementation InPlaceTextView
- (NSAttributedString *)attributedSubstringFromRange:(NSRange)range
{
    return [self attributedSubstringForProposedRange:range actualRange:NULL];
}
@end

@interface DelayedVSCodeTextView : InPlaceTextView
@property(nonatomic, copy) NSAttributedString *previousText;
@property(nonatomic) NSRange previousRange;
@end

@implementation DelayedVSCodeTextView
- (NSString *)bundleIdentifier
{
    return @"com.microsoft.VSCode";
}
- (void)insertText:(id)string replacementRange:(NSRange)replacement
{
    if (replacement.location != NSNotFound) {
        self.previousText = [self attributedSubstringForProposedRange:replacement actualRange:NULL];
        self.previousRange = replacement;
    }
    [super insertText:string replacementRange:replacement];
}
- (NSAttributedString *)attributedSubstringFromRange:(NSRange)range
{
    if (self.previousText && NSEqualRanges(self.previousRange, range)) {
        NSAttributedString *text = self.previousText;
        self.previousText = nil;
        return text;
    }
    return [self attributedSubstringForProposedRange:range actualRange:NULL];
}
@end

@interface NoDocumentReadbackTextView : InPlaceTextView
@end

@implementation NoDocumentReadbackTextView
- (NSAttributedString *)attributedSubstringFromRange:(NSRange)range
{
    return nil;
}
@end

@interface ChromeAutocompleteTextView : InPlaceTextView
@property(nonatomic) BOOL suggestsSuffix;
@end

@implementation ChromeAutocompleteTextView
- (NSString *)bundleIdentifier
{
    return @"com.google.Chrome";
}
- (void)insertText:(id)string replacementRange:(NSRange)replacement
{
    [super insertText:string replacementRange:replacement];
    if (!self.suggestsSuffix) return;
    NSUInteger caret = self.selectedRange.location;
    NSString *suggestion = @"-suggestion";
    [super insertText:suggestion replacementRange:NSMakeRange(NSNotFound, 0)];
    self.selectedRange = NSMakeRange(caret, suggestion.length);
}
@end

static void equal(NSString *actual, NSString *expected, NSString *context)
{
    if (![actual isEqualToString:expected]) {
        fprintf(stderr, "%s: expected <%s>, got <%s>\n",
            context.UTF8String, expected.UTF8String, actual.UTF8String);
        exit(1);
    }
}

static void engine(NSString *keys, NSString *expected)
{
    TelexWord word = {0};
    for (NSUInteger i = 0; i < keys.length; i++) {
        uint16_t key = [keys characterAtIndex:i];
        if (key == '\b') TelexDelete(&word);
        else TelexAppend(&word, key);
    }
    uint16_t output[TELEX_CAPACITY];
    TelexRender(&word, output);
    equal([NSString stringWithCharacters:output length:word.length], expected, keys);
}

static BOOL press(IMKInputController *controller, TestTextView *view, NSString *character,
                  unsigned short keyCode, NSEventModifierFlags modifiers)
{
    NSEvent *event = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint
                               modifierFlags:modifiers timestamp:0 windowNumber:0
                                  context:nil characters:character
                                  charactersIgnoringModifiers:character isARepeat:NO keyCode:keyCode];
    return [controller handleEvent:event client:(id)view];
}

static void type(IMKInputController *controller, TestTextView *view, NSString *keys)
{
    for (NSUInteger i = 0; i < keys.length; i++) {
        NSString *character = [keys substringWithRange:NSMakeRange(i, 1)];
        int code = [character isEqualToString:@"\b"] ? kVK_Delete : kVK_ANSI_A;
        if (!press(controller, view, character, code, 0)) {
            if (code == kVK_Delete) {
                [view deleteBackward:nil];
            } else {
                [view insertText:character replacementRange:NSMakeRange(NSNotFound, 0)];
            }
        }
    }
}

int main(void)
{
    @autoreleasepool {
        NSArray *examples = @[
            @[@"tieengs", @"tiếng"], @[@"Vieetj", @"Việt"], @[@"TIEENGS", @"TIẾNG"],
            @[@"ngheej", @"nghệ"],
            @[@"DDAAUX", @"ĐẪU"], @[@"aw", @"ă"], @[@"asfz", @"a"], @[@"aa", @"â"],
            @[@"ow", @"ơ"], @[@"uw", @"ư"], @[@"www", @"www"], @[@"ee", @"ê"],
            @[@"oo", @"ô"], @[@"ddd", @"dd"], @[@"xooong", @"xoong"], @[@"herr", @"her"],
            @[@"gias", @"giá"], @[@"gif", @"gì"], @[@"gieengs", @"giếng"], @[@"gins", @"gín"],
            @[@"quyeenr", @"quyển"], @[@"quawr", @"quẳ"], @[@"quys", @"quý"],
            @[@"hoaf", @"hòa"], @[@"hoafng", @"hoàng"], @[@"thuyr", @"thủy"],
            @[@"khoer", @"khỏe"], @[@"khuyur", @"khuỷu"], @[@"thuaajn", @"thuận"],
            @[@"xuoongs", @"xuống"], @[@"thuoongr", @"thuổng"],
            @[@"thuowr", @"thuở"], @[@"quowr", @"quở"], @[@"nguowif", @"người"],
            @[@"thuowng", @"thương"], @[@"truowngf", @"trường"], @[@"truwofngw", @"trường"],
            @[@"nuocws", @"nước"], @[@"ddawngj", @"đặng"], @[@"muwas", @"mứa"],
            @[@"muaws", @"mứa"], @[@"trangw", @"trăng"], @[@"cana", @"cân"],
            @[@"tieengs\b\b", @"tiế"], @[@"tieengs\b\b\b", @"ti"],
            @[@"hoangf\b\b", @"hòa"], @[@"asa", @"ấ"], @[@"asfzj", @"ạ"],
            @[@"dd", @"đ"], @[@"Dd", @"Đ"], @[@"nawngjz", @"năng"],
        ];
        for (NSArray *pair in examples) engine(pair[0], pair[1]);

        NSArray *base = @[@"a", @"aw", @"aa", @"e", @"ee", @"i", @"o", @"oo", @"ow",
                          @"u", @"uw", @"y"];
        NSArray *rows = @[@"aáàảãạ", @"ăắằẳẵặ", @"âấầẩẫậ", @"eéèẻẽẹ", @"êếềểễệ", @"iíìỉĩị",
                          @"oóòỏõọ", @"ôốồổỗộ", @"ơớờởỡợ", @"uúùủũụ", @"ưứừửữự", @"yýỳỷỹỵ"];
        NSArray *tones = @[@"", @"s", @"f", @"r", @"x", @"j"];
        for (NSUInteger i = 0; i < rows.count; i++) {
            for (NSUInteger j = 0; j < tones.count; j++) {
                NSString *keys = [base[i] stringByAppendingString:tones[j]];
                NSString *expected = [rows[i] substringWithRange:NSMakeRange(j, 1)];
                engine(keys, expected);
                engine(keys.uppercaseString, expected.uppercaseString);
            }
        }

        [NSApplication sharedApplication];
        IMKInputController *controller = [NSClassFromString(@"TelexGonController") new];
        if (!controller) return 1;
        TestTextView *view = [[TestTextView alloc] initWithFrame:NSMakeRect(0, 0, 500, 200)];

        type(controller, view, @"Tieengs Vieetj");
        equal(view.string, @"Tiếng Việt", @"marked Telex phrase");
        if (!view.hasMarkedText || view.selectedRange.length != 0) return 1;
        NSDictionary *style = [view.composition attributesAtIndex:0 effectiveRange:NULL];
        if (![style[NSUnderlineStyleAttributeName] isEqual:@(NSUnderlineStyleNone)] ||
            ![style[NSBackgroundColorAttributeName] isEqual:NSColor.clearColor]) return 1;
        type(controller, view, @"\b,");
        equal(view.string, @"Tiếng Việ,", @"backspace and punctuation");
        if (view.hasMarkedText) return 1;

        view.string = @"ABC hello XYZ";
        view.selectedRange = NSMakeRange(4, 5);
        type(controller, view, @"hoaf");
        if (press(controller, view, @"\r", kVK_Return, 0)) return 1;
        equal(view.string, @"ABC hòa XYZ", @"selection replacement and Return passthrough");

        view.string = @"";
        type(controller, view, @"as\b");
        equal(view.string, @"", @"delete last marked character");
        if (view.hasMarkedText) return 1;

        NoEmptyCommitTextView *search = [[NoEmptyCommitTextView alloc] initWithFrame:view.frame];
        type(controller, search, @"as\b");
        equal(search.string, @"", @"delete last character when empty commits are ignored");
        if (search.hasMarkedText) return 1;
        type(controller, search, @"ba\b\b");
        equal(search.string, @"", @"delete through the beginning of the search");
        search.string = @"abcXYZ";
        search.selectedRange = NSMakeRange(3, 0);
        type(controller, search, @"as\b");
        equal(search.string, @"abcXYZ", @"delete marked text without changing its neighbors");
        if (search.hasMarkedText || search.selectedRange.location != 3) return 1;

        type(controller, view, @"dduowngf");
        if (press(controller, view, @"a", kVK_ANSI_A, NSEventModifierFlagCommand)) return 1;
        equal(view.string, @"đường", @"Cmd shortcut passthrough");
        if (view.hasMarkedText) return 1;

        view.string = @"";
        NSString *longText = [@"" stringByPaddingToLength:120 withString:@"b" startingAtIndex:0];
        type(controller, view, longText);
        [controller commitComposition:(id)view];
        equal(view.string, longText, @"bounded composition");

        view.string = @"";
        type(controller, view, @"tieemf");
        if (press(controller, view, @"", kVK_LeftArrow, NSEventModifierFlagFunction)) return 1;
        equal(view.string, @"tiềm", @"arrow passthrough and commit");

        InPlaceTextView *editor = [[InPlaceTextView alloc] initWithFrame:view.frame];
        type(controller, editor, @"tieengs Vieetj");
        equal(editor.string, @"tiếng Việt", @"in-place Telex phrase");
        if (editor.hasMarkedText || editor.composition) return 1;
        type(controller, editor, @"\b\b\b\b");
        equal(editor.string, @"tiếng ", @"native Delete removes the final character");

        type(controller, editor, @"hoangf\b\b,");
        equal(editor.string, @"tiếng hòa,", @"Delete moves the tone when the coda is removed");

        editor.string = @"left right";
        editor.selectedRange = NSMakeRange(5, 5);
        type(controller, editor, @"as");
        equal(editor.string, @"left á", @"in-place typing replaces selected text");
        editor.selectedRange = NSMakeRange(0, 0);
        type(controller, editor, @"as ");
        equal(editor.string, @"á left á", @"caret move abandons the previous word");

        IMKInputController *fallbackController = [controller.class new];
        NoDocumentReadbackTextView *fallback = [[NoDocumentReadbackTextView alloc] initWithFrame:view.frame];
        type(fallbackController, fallback, @"as Vieetj");
        equal(fallback.string, @"as Việt", @"unreadable replacement keeps original text and resumes Telex");
        if (!fallback.hasMarkedText) return 1;
        type(fallbackController, fallback, @"\b\b\b\b");
        equal(fallback.string, @"as ", @"fallback deletes the final marked character");
        if (fallback.hasMarkedText) return 1;

        IMKInputController *chromeController = [controller.class new];
        ChromeAutocompleteTextView *chrome = [[ChromeAutocompleteTextView alloc] initWithFrame:view.frame];
        chrome.string = @"https://example.com";
        chrome.selectedRange = NSMakeRange(0, chrome.string.length);
        chrome.suggestsSuffix = YES;
        type(chromeController, chrome, @"coongj");
        equal([chrome.string substringToIndex:chrome.selectedRange.location], @"cộng",
              @"first Chrome address word with inline autocomplete");
        if (chrome.hasMarkedText || chrome.composition) return 1;

        chrome.suggestsSuffix = NO;
        type(chromeController, chrome, @" hoaf");
        equal(chrome.string, @"cộng hòa", @"second Chrome address word after autocomplete");

        IMKInputController *vscodeController = [controller.class new];
        DelayedVSCodeTextView *vscode = [[DelayedVSCodeTextView alloc] initWithFrame:view.frame];
        type(vscodeController, vscode, @"ngheej");
        equal(vscode.string, @"nghệ", @"VS Code returns a stale snapshot after inserting the circumflex");
        if (vscode.hasMarkedText || vscode.composition) return 1;

        printf("%lu ca Telex, 19 ca tích hợp AppKit đạt.\n", examples.count + base.count * tones.count * 2);
    }
}
