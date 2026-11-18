#import <AppKit/AppKit.h>
#import <Carbon/Carbon.h>
#import <InputMethodKit/InputMethodKit.h>
#import "Telex.h"
#import "TelexAppExclusions.h"

static const NSRange currentInsertion = {NSNotFound, 0};

@interface TelexGonController : IMKInputController
@end

@implementation TelexGonController {
    TelexWord _word;
    BOOL _editsInPlace;
    BOOL _documentAccessUnavailable;
    NSUInteger _wordStart;
    NSString *_beforeLastReplacement;
}

- (NSString *)text
{
    uint16_t output[TELEX_CAPACITY];
    TelexRender(&_word, output);
    return [NSString stringWithCharacters:output length:_word.length];
}

- (id)composedString:(id)sender
{
    return [[NSAttributedString alloc] initWithString:[self text] attributes:@{
        NSUnderlineStyleAttributeName: @(NSUnderlineStyleNone),
        NSBackgroundColorAttributeName: NSColor.clearColor,
    }];
}

- (NSRange)selectionRange
{
    return NSMakeRange(_word.length, 0);
}

- (void)updateMarkedText:(id<IMKTextInput>)client
{
    [client setMarkedText:[self composedString:client]
           selectionRange:[self selectionRange]
         replacementRange:currentInsertion];
}

- (void)commitComposition:(id<IMKTextInput>)client
{
    _beforeLastReplacement = nil;
    if (_word.length == 0) return;
    NSString *text = _editsInPlace ? nil : [self text];
    _word = (TelexWord){0};
    if (text) [client insertText:text replacementRange:currentInsertion];
}

- (BOOL)clientSupportsInPlaceEditing:(id<IMKTextInput>)client
{
    return !_documentAccessUnavailable &&
        [(id)client respondsToSelector:@selector(selectedRange)] &&
        [(id)client respondsToSelector:@selector(attributedSubstringFromRange:)];
}

- (void)startWordWithKey:(uint16_t)key client:(id<IMKTextInput>)client
{
    _beforeLastReplacement = nil;
    _editsInPlace = NO;
    if ([self clientSupportsInPlaceEditing:client]) {
        NSRange selection = [client selectedRange];
        if (selection.location < NSNotFound - TELEX_CAPACITY && selection.length != NSNotFound) {
            _wordStart = selection.location;
            _editsInPlace = YES;
        }
    }
    TelexAppend(&_word, key);
    if (_editsInPlace) {
        [client insertText:[self text] replacementRange:currentInsertion];
    } else {
        [self updateMarkedText:client];
    }
}

// A failed check abandons the composition without modifying the document.
- (BOOL)applyInPlaceEditFrom:(NSString *)before deleting:(BOOL)deleting
                      client:(id<IMKTextInput>)client
{
    NSRange selection = [client selectedRange];
    NSString *after = [self text];
    BOOL selectedSuffix = selection.length != 0;
    if (selection.location != _wordStart + before.length ||
        (selectedSuffix && (deleting || selection.length >= NSNotFound - selection.location))) {
        _word = (TelexWord){0};
        return NO;
    }
    if (selectedSuffix) {
        NSString *identifier = [(id)client respondsToSelector:@selector(bundleIdentifier)] ?
            [client bundleIdentifier] : nil;
        if (![identifier isEqualToString:@"com.google.Chrome"] &&
            ![identifier hasPrefix:@"com.google.Chrome."]) {
            _word = (TelexWord){0};
            return NO;
        }
    }
    BOOL appending = !deleting && [after hasPrefix:before];
    if (appending && !selectedSuffix) {
        _beforeLastReplacement = nil;
        [client insertText:[after substringFromIndex:before.length] replacementRange:currentInsertion];
        return YES;
    }
    if (deleting && [before hasPrefix:after]) {
        _beforeLastReplacement = nil;
        return YES;
    }

    NSRange range = NSMakeRange(_wordStart, before.length);
    NSString *documentText = [client attributedSubstringFromRange:range].string;
    NSString *previous = _beforeLastReplacement;
    _beforeLastReplacement = nil;
    BOOL documentMatches = [documentText isEqualToString:before];
    BOOL previousSnapshotMatches = !selectedSuffix && [documentText isEqualToString:previous];
    if (!documentMatches && !previousSnapshotMatches) {
        _documentAccessUnavailable = documentText == nil;
        _word = (TelexWord){0};
        return NO;
    }
    if (appending) {
        [client insertText:[after substringFromIndex:before.length] replacementRange:currentInsertion];
    } else {
        // Chrome selects its suggested continuation. Replace it together
        // with the verified word when a Telex key changes the existing text.
        range.length += selection.length;
        if (!selectedSuffix && after.length == before.length &&
            [(id)client respondsToSelector:@selector(bundleIdentifier)] &&
            [[client bundleIdentifier] hasPrefix:@"com.microsoft.VSCode"]) {
            // VS Code can return the last verified text until the renderer sees
            // the replacement. The caret and the replacement range are unchanged.
            _beforeLastReplacement = [documentText copy];
        }
        [client insertText:after replacementRange:range];
    }
    return YES;
}

- (void)deactivateServer:(id)sender
{
    [self commitComposition:sender];
    _documentAccessUnavailable = NO;
    [super deactivateServer:sender];
}

- (NSMenu *)menu
{
    NSMenu *menu = [NSMenu new];
    [menu addItemWithTitle:NSLocalizedString(@"Ứng dụng loại trừ…", nil)
                    action:@selector(showPreferences:) keyEquivalent:@""];
    return menu;
}

- (void)showPreferences:(id)sender
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[TelexAppExclusions sharedExclusions] showSettings];
    });
}

- (BOOL)handleEvent:(NSEvent *)event client:(id<IMKTextInput>)client
{
    if (event.type != NSEventTypeKeyDown) return NO;

    TelexAppExclusions *exclusions = [TelexAppExclusions sharedExclusions];
    if ([exclusions hasExcludedApplications] &&
        [(id)client respondsToSelector:@selector(bundleIdentifier)] &&
        [exclusions containsApplication:[client bundleIdentifier]]) {
        [self commitComposition:client];
        return NO;
    }

    const NSEventModifierFlags shortcuts =
        NSEventModifierFlagCommand | NSEventModifierFlagControl | NSEventModifierFlagOption;
    if (event.modifierFlags & shortcuts) {
        [self commitComposition:client];
        return NO;
    }

    if (event.keyCode == kVK_Delete && _word.length &&
        !(event.modifierFlags & NSEventModifierFlagFunction)) {
        NSString *before = _editsInPlace ? [self text] : nil;
        TelexDelete(&_word);
        if (before) {
            BOOL nativeDelete = [before hasPrefix:[self text]];
            return [self applyInPlaceEditFrom:before deleting:YES client:client] && !nativeDelete;
        }
        // Some search fields ignore empty commits. Replace the marked text
        // itself so the final character is removed through the composition API.
        [self updateMarkedText:client];
        return YES;
    }

    NSString *characters = event.characters;
    if (characters.length == 1 &&
        !(event.modifierFlags & NSEventModifierFlagFunction)) {
        uint16_t key = [characters characterAtIndex:0];
        if (TelexIsLetter(key)) {
            if (_word.length == TELEX_CAPACITY) [self commitComposition:client];
            if (_word.length == 0) {
                [self startWordWithKey:key client:client];
            } else if (_editsInPlace) {
                NSString *before = [self text];
                TelexAppend(&_word, key);
                if (![self applyInPlaceEditFrom:before deleting:NO client:client]) {
                    [self startWordWithKey:key client:client];
                }
            } else {
                TelexAppend(&_word, key);
                [self updateMarkedText:client];
            }
            return YES;
        }
    }

    [self commitComposition:client];
    return NO;
}

@end
