//
//  PeppaStateizer.m
//  TokenHybridCompiler
//
//  Created by 陈雄 on 2018/9/24.
//  Copyright © 2018年 Token. All rights reserved.
//

#import "PeppaXMLParser.h"
#import "PeppaUTF8Iterator.h"

typedef NS_ENUM(NSUInteger, PeppaTokenState) {
    PeppaTokenStateDocType,
    PeppaTokenStatePlainText,
    PeppaTokenStateOpenTag,
    PeppaTokenStateOpenTagName,
    PeppaTokenStateTagFinish,
    PeppaTokenStateSpaceAfterOpenTagName,
    PeppaTokenStateEqualSignAfterWhiteSpace,
    PeppaTokenStateWhiteSpaceAfterAttributeValue,
    PeppaTokenStateCloseTag,
    PeppaTokenStateSelfCloseTag,
    PeppaTokenStateAttributeName,
    PeppaTokenStateAttributeValue,
    PeppaTokenStateAfterExclamation,
    PeppaTokenStateComment,
    PeppaTokenStateScript
};

static const char kCharEOF               = '\0';
static const char kCharAlphaD            = 'D';
static const char kCharSlash             = '/';
static const char kCharDash              = '-';
static const char kCharEqualSign         = '=';
static const char kCharExclamation       = '!';
static const char kCharEndAngleBracket   = '>';
static const char kCharStartAngleBracket = '<';
static const char kCharSingleQuote       = '\'';
static const char kCharDoubleQuote       = '"';
static const char kCharCarriageReturn    = '\r';
static const char kCharNewLine           = '\n';
static const char kCharTab               = '\t';
static const char kCharSpace             = 0x20;

inline static bool peppa_is_alpha(unsigned char c) {
    return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z');
}

inline static bool peppa_is_number(unsigned char c){
    return c >= '0' && c <= '9';
}

inline static bool peppa_is_whiteSpace(unsigned char c) {
    switch (c) {
        case '\r':
        case '\n':
        case '\t':
        case '\f':
            return true;
        default:
            return false;
    }
}

inline static bool peppa_is_attribute_name_valid(char c){
    return peppa_is_alpha(c) ||
    peppa_is_number(c) ||
    (c >= 0x23 && c<= 0x26) || // # % & $
    c == '@' ||
    c == '_' ||
    c == '-' ||
    c == ':' ||
    c == '{' ||
    c == '}';
}

@interface PeppaXMLParser()
@property(nonatomic ,copy   ,readonly) NSString *text;
@property(nonatomic ,copy   ,readonly) PeppaUTF8Iterator *utf8Iterator;
@property(nonatomic ,assign) PeppaTokenState currentTokenState;
@property(nonatomic ,assign) BOOL stop;
@property(nonatomic ,copy  ) NSString *currentTagName;
@property(nonatomic ,copy  ) NSString *currentAttributeName;
@property(nonatomic ,assign) NSInteger textLength;
@property(nonatomic ,strong) NSMutableDictionary *attributes;
@property(nonatomic ,strong) NSMutableDictionary *mustacheAttributes;
@property(nonatomic ,assign) int currentQuote;
@end

@implementation PeppaXMLParser

- (instancetype)initWithText:(NSString *)text{
    return [self initWithText:text deatchLayoutInfomation:NO];
}

- (instancetype)initWithText:(NSString *)text
      deatchLayoutInfomation:(BOOL)deatchLayoutInfomation{
    if (self = [super init]) {
        if (text && text.length) {
            _utf8Iterator            = [[PeppaUTF8Iterator alloc] initWithText:text
                                                        deatchLayoutInfomation:deatchLayoutInfomation];
            _text                    = [text copy];
            _textLength              = _text.length;
            _detectEntireScript      = NO;
            _detectLayoutInformation = deatchLayoutInfomation;
        }
    }
    return self;
}

#pragma mark - action
- (void)stopParsing{
    _stop = YES;
}

- (void)startParse{
    if (_text == nil || _text.length == 0) return ;
    [self notifyStart];
    int c = [_utf8Iterator getNextCharacter];
    _currentTokenState = (c == kCharStartAngleBracket) ? PeppaTokenStateOpenTag : PeppaTokenStatePlainText;
    
    while (!_stop) {
        switch (_currentTokenState) {
            case PeppaTokenStatePlainText:
                [self processPlainText];
                break;
            case PeppaTokenStateOpenTag:
                [self processOpenTag];
                break;
            case PeppaTokenStateOpenTagName:
                [self processOpenTagName];
                break;
            case PeppaTokenStateSpaceAfterOpenTagName:
                [self processSpaceAfterOpenTagName];
                break;
            case PeppaTokenStateAttributeName:
                [self processAttributeName];
                break;
            case PeppaTokenStateAttributeValue:
                [self processAttributeValue];
                break;
            case PeppaTokenStateEqualSignAfterWhiteSpace:
                [self processEqualSignAfterWhiteSpace];
                break;
            case PeppaTokenStateWhiteSpaceAfterAttributeValue:
                [self processWhiteSpaceAfterAttributeValue];
                break;
            case PeppaTokenStateSelfCloseTag:
                [self processSelfCloseTag];
                break;
            case PeppaTokenStateTagFinish:
                [self processTagFinish];
                break;
            case PeppaTokenStateCloseTag:
                [self processCloseTag];
                break;
            case PeppaTokenStateAfterExclamation:
                [self processAfterExclamation];
                break;
            case PeppaTokenStateComment:
                [self processComment];
                break;
            case PeppaTokenStateDocType:
                [self processDocType];
                break;
            case PeppaTokenStateScript:
                [self processScript];
                break;
            default:
                break;
        }
    }
}

- (NSString *)extractSubStringWithStartPosition:(NSInteger)position
                                         length:(NSInteger)length{
    if (position + length <= _textLength) {
        return [_text substringWithRange:NSMakeRange(position, length)];
    }
    return @"";
}

#pragma mark - process
- (void)processPlainText{
    NSInteger plainTextStartPosition = _utf8Iterator.currentUnitPosition;
    int c = _utf8Iterator.currentCharacter;
    while (c != kCharStartAngleBracket && c) {
        c = [_utf8Iterator getNextCharacter];
    }
    
    NSInteger plainTextLength = _utf8Iterator.currentUnitPosition - plainTextStartPosition;
    NSString *plainText = [self extractSubStringWithStartPosition:plainTextStartPosition
                                                           length:plainTextLength];
    switch (c) {
        case kCharStartAngleBracket:
            _currentTokenState = PeppaTokenStateOpenTag;
            [self notifyText:plainText];
            break;
        case kCharEOF:
            _stop = YES;
            [self notifyFinish];
            break;
        default:
            _stop = YES;
            [self notifyErrorWithCode:90028];
            break;
    }
}

- (void)processOpenTag{
    // 获取当前的字符 如果不是就继续循环
    int c = _utf8Iterator.currentCharacter;
    switch (c) {
        case kCharNewLine:
        case kCharTab:
        case kCharCarriageReturn:
        case kCharSpace:
            _stop = YES;
            [self notifyErrorWithCode:90029];
            return ;
        case kCharStartAngleBracket:
            c = [_utf8Iterator getNextOneByteCharacter];
            if (peppa_is_attribute_name_valid(c)) {
                _attributes         = @{}.mutableCopy;
                _mustacheAttributes = @{}.mutableCopy;
                _currentTokenState  = PeppaTokenStateOpenTagName;
            }
            break;
        case kCharSlash:
            _currentTokenState = PeppaTokenStateCloseTag;
            break;
        case kCharExclamation:
            _currentTokenState = PeppaTokenStateAfterExclamation;
            break;
        default:
            _stop = YES;
            [self notifyErrorWithCode:90030];
            break;
    }
}

- (void)processOpenTagName{
    NSInteger tagNameLocation = _utf8Iterator.currentUnitPosition;
    int c = _utf8Iterator.currentCharacter;
    while (peppa_is_attribute_name_valid(c)) {
        c = [_utf8Iterator getNextOneByteCharacter];
    }
    
    NSInteger tagNameLength = _utf8Iterator.currentUnitPosition - tagNameLocation;
    _currentTagName = [self extractSubStringWithStartPosition:tagNameLocation
                                                       length:tagNameLength];
    switch (c) {
        case kCharSpace:
            _currentTokenState = PeppaTokenStateSpaceAfterOpenTagName;
            break;
        case kCharSlash:
            _currentTokenState = PeppaTokenStateSelfCloseTag;
            break;
        case kCharEndAngleBracket:
            _currentTokenState = PeppaTokenStateTagFinish;
            [self notifyOpenTagName:_currentTagName
                         attributes:_attributes
                 mustacheAttributes:_mustacheAttributes];
            break;
        default:
            _stop = YES;
            [self notifyErrorWithCode:90031];
            break;
    }
}

- (void)processSpaceAfterOpenTagName{
    int c = _utf8Iterator.currentCharacter;
    while (c == kCharSpace && c) {
        c = [_utf8Iterator getNextCharacter];
    }
    
    switch (c) {
        case kCharSlash:
            _currentTokenState = PeppaTokenStateSelfCloseTag;
            break;
        case kCharEndAngleBracket:
            _currentTokenState = PeppaTokenStateTagFinish;
            [self notifyOpenTagName:_currentTagName
                         attributes:_attributes
                 mustacheAttributes:_mustacheAttributes];
            break;
        default:
            if (peppa_is_attribute_name_valid(c)) {
                _currentTokenState = PeppaTokenStateAttributeName;
            }
            else {
                _stop = YES;
                [self notifyErrorWithCode:90032];
            }
            break;
    }
}

- (void)processAttributeName{
    int c = _utf8Iterator.currentCharacter;
    NSInteger attributeNameStartPosition = _utf8Iterator.currentUnitPosition;
    while (peppa_is_attribute_name_valid(c)) {
        c = [_utf8Iterator getNextOneByteCharacter];
    }
    NSInteger attributeNameLength = _utf8Iterator.currentUnitPosition - attributeNameStartPosition;
    _currentAttributeName = [self extractSubStringWithStartPosition:attributeNameStartPosition
                                                             length:attributeNameLength];
    
    switch (c) {
        case kCharTab:
        case kCharSpace:
        case kCharNewLine:
        case kCharCarriageReturn:
        case kCharEqualSign:
            _currentTokenState = PeppaTokenStateEqualSignAfterWhiteSpace;
            break;
        case kCharSlash:
            _currentTokenState = PeppaTokenStateSelfCloseTag;
            [_attributes setObject:@"" forKey:_currentAttributeName];
            break;
        case kCharEndAngleBracket:
            _currentTokenState = PeppaTokenStateTagFinish;
            [_attributes setObject:@"" forKey:_currentAttributeName];
            [self notifyOpenTagName:_currentTagName
                         attributes:_attributes
                 mustacheAttributes:_mustacheAttributes];
            break;
        default:
            _stop = YES;
            [self notifyErrorWithCode:90033];
            break;
    }
}

- (void)processEqualSignAfterWhiteSpace{
    int c = _utf8Iterator.currentCharacter;
    
    while (c != kCharDoubleQuote && c != kCharSingleQuote &&
           !peppa_is_attribute_name_valid(c) &&
           c!= kCharEndAngleBracket && c && c < 0x80) {
        c = [_utf8Iterator getNextCharacter];
    }
    
    switch (c) {
        case kCharSingleQuote:
        case kCharDoubleQuote:
            _currentQuote = c;
            _currentTokenState = PeppaTokenStateAttributeValue;
            break;
        case kCharEndAngleBracket:
            _currentTokenState = PeppaTokenStateTagFinish;
            [self notifyOpenTagName:_currentTagName
                         attributes:_attributes
                 mustacheAttributes:_mustacheAttributes];
            break;
        default:
            if (peppa_is_attribute_name_valid(c)) {
                [_attributes setObject:@"" forKey:_currentAttributeName];
                _currentTokenState = PeppaTokenStateAttributeName;
            }
            else {
                _stop = YES;
                [self notifyErrorWithCode:90034];
            }
            break;
    }
}

- (void)processAttributeValue{
    char quote = _currentQuote;
    
    int c = [_utf8Iterator getNextCharacter];
    NSInteger valueStartPosition = _utf8Iterator.currentUnitPosition;
    
    while (c && c != quote) {
        c = [_utf8Iterator getNextCharacter];
    }
    
    NSInteger valueLength = _utf8Iterator.currentUnitPosition - valueStartPosition;
    NSString *value       = [self extractSubStringWithStartPosition:valueStartPosition
                                                             length:valueLength];
    NSMutableDictionary *attributes;
    if (_detectMustacheAttribute && valueLength > 4) {
        unichar c0 = [value characterAtIndex:0];
        unichar c1 = [value characterAtIndex:1];
        unichar c2 = [value characterAtIndex:valueLength - 1];
        unichar c3 = [value characterAtIndex:valueLength - 2];
        attributes = (c0 == '{' && c1 == '{' && c2 == '}' && c3 == '}') ? _mustacheAttributes : _attributes;
    }
    else {
        attributes = _attributes;
    }
    
    [attributes setObject:value forKey:_currentAttributeName];
    
    c = [_utf8Iterator getNextCharacter];
    switch (c) {
        case kCharTab:
        case kCharSpace:
        case kCharNewLine:
        case kCharCarriageReturn:
            _currentTokenState = PeppaTokenStateWhiteSpaceAfterAttributeValue;
            break;
        case kCharEndAngleBracket:
            [self notifyOpenTagName:_currentTagName
                         attributes:_attributes
                 mustacheAttributes:_mustacheAttributes];
            _currentTokenState = PeppaTokenStateTagFinish;
            break;
        case kCharSlash:
            _currentTokenState = PeppaTokenStateSelfCloseTag;
            break;
        default:
            _stop = YES;
            [self notifyErrorWithCode:90035];
            break;
    }
}

- (void)processWhiteSpaceAfterAttributeValue{
    int c = _utf8Iterator.currentCharacter;
    while ((peppa_is_whiteSpace(c) || c == kCharSpace) && c) {
        c = [_utf8Iterator getNextCharacter];
    }
    
    switch (c) {
        case kCharEndAngleBracket:
            _currentTokenState = PeppaTokenStateTagFinish;
            [self notifyOpenTagName:_currentTagName attributes:_attributes mustacheAttributes:_mustacheAttributes];
            break;
        default:
            if (peppa_is_attribute_name_valid(c)) {
                _currentTokenState = PeppaTokenStateAttributeName;
            }
            else {
                _stop = YES;
                [self notifyErrorWithCode:90036];
            }
            break;
    }
}

- (void)processSelfCloseTag{
    int c = _utf8Iterator.currentCharacter;
    while (c != kCharEndAngleBracket && c) {
        c = [_utf8Iterator getNextOneByteCharacter];
    }
    switch (c) {
        case kCharEOF:
            _stop = YES;
            return ;
            break;
        default:
            [self notifyOpenTagName:_currentTagName
                         attributes:_attributes
                 mustacheAttributes:_mustacheAttributes];
            [self notifyCloseTagName:_currentTagName];
            [self processTagFinish];
            break;
    }
}

- (void)processCloseTag{
    int c = [_utf8Iterator getNextCharacter];
    
    if (!peppa_is_attribute_name_valid(c)) {
        _stop = YES;
        [self notifyErrorWithCode:90037];
        return ;
    }
    
    NSInteger tagNameStartPosition = _utf8Iterator.currentUnitPosition;
    while (peppa_is_attribute_name_valid(c) && c) {
        c = [_utf8Iterator getNextOneByteCharacter];
    }
    
    NSInteger tagNameLength = _utf8Iterator.currentUnitPosition - tagNameStartPosition;
    while (c!= kCharEndAngleBracket && c) {
        c = [_utf8Iterator getNextOneByteCharacter];
    }
    
    if (c != kCharEOF) {
        NSString *tagName = [self extractSubStringWithStartPosition:tagNameStartPosition
                                                             length:tagNameLength];
        [self notifyCloseTagName:tagName];
        _currentTokenState = PeppaTokenStateTagFinish;
    }
    else {
        _stop = YES;
        [self notifyErrorWithCode:90038];
    }
}

- (void)processTagFinish{
    int c = [_utf8Iterator getNextCharacter];
    while (peppa_is_whiteSpace(c) || c == kCharSpace) {
        c = [_utf8Iterator getNextCharacter];
    }
    
    switch (c) {
        case kCharStartAngleBracket:
            _currentTokenState = PeppaTokenStateOpenTag;
            break;
        case kCharEOF:
            _stop = YES;
            [self notifyFinish];
            break;
        default:
            if (_detectEntireScript && [_currentTagName isEqualToString:@"script"]) {
                _currentTokenState = PeppaTokenStateScript;
            }
            else {
                _currentTokenState = PeppaTokenStatePlainText;
            }
            break;
    }
}

- (void)processAfterExclamation{
    int c = [_utf8Iterator getNextCharacter];
    switch (c) {
        case kCharAlphaD:
            _currentTokenState = PeppaTokenStateDocType;
            break;
        case kCharDash:
            _currentTokenState = PeppaTokenStateComment;
            break;
        default:
            _stop = YES;
            [self notifyErrorWithCode:90039];
            break;
    }
}

- (void)processScript{
    NSInteger scriptContentStartPosition = _utf8Iterator.currentUnitPosition;
    int c = _utf8Iterator.currentCharacter;
    
    BOOL matched             = YES;
    int charArrayIndex       = 0;
    int checkLength          = 8;
    const char *checkString  = "</script";
    int charArray[8];
    
    while (matched && c) {
        c = [_utf8Iterator getNextCharacter];
        // 碰到'<' 开始往数组记录 或者 charArrayIndex 已经不是0
        if (c == kCharStartAngleBracket || charArrayIndex) {
            charArray[charArrayIndex] = c;
            charArrayIndex += 1;
            if (charArrayIndex > checkLength - 1) {
                charArrayIndex = 0;
            }
        }
        // 碰到 '>'开始检查
        if (c == kCharEndAngleBracket) {
            for (NSInteger i = 0; i < checkLength - 1; i++) {
                if (charArray[i] != checkString[i]) {
                    matched = NO;
                    charArrayIndex = 0;
                    break;
                }
            }
            
            if (matched) {
                break;
            }
        }
    }
    
    if (matched) {
        NSInteger scriptContentLength = _utf8Iterator.currentUnitPosition - scriptContentStartPosition - checkLength;
        NSString *scriptContent = [self extractSubStringWithStartPosition:scriptContentStartPosition
                                                                   length:scriptContentLength];
        [self notifyScript:scriptContent];
        [self processTagFinish];
    }
    
    if (c == kCharEOF) {
        _stop = YES;
        [self notifyErrorWithCode:90040];
        return ;
    }
}

- (void)processComment{
    int c = _utf8Iterator.currentCharacter;
    while (c!= kCharSpace) {
        c = [_utf8Iterator getNextCharacter];
    }
    NSInteger commentStartPosition = _utf8Iterator.currentUnitPosition + 1;
    
    // 开始查找结束的地点
    BOOL shouldStop = NO;
    int charArray[2];
    int charArrayIndex = 0;
    while (!shouldStop && c) {
        c = [_utf8Iterator getNextCharacter];
        if (c == kCharDash) {
            charArray[charArrayIndex] = c;
            charArrayIndex += 1;
        }
        else if (c == kCharEndAngleBracket) {
            shouldStop = (charArray[0] == kCharDash && charArray[1] == kCharDash);
        }
        else {
            charArrayIndex = 0;
        }
    }
    
    if (c == kCharEOF) {
        _stop = YES;
        [self notifyErrorWithCode:90041];
        return ;
    }
    
    NSInteger commentLength = _utf8Iterator.currentUnitPosition - commentStartPosition - 3;
    NSString *comment = [self extractSubStringWithStartPosition:commentStartPosition length:commentLength];
    [self notifyComment:comment];
    [self processTagFinish];
}

- (void)processDocType{
    int c = _utf8Iterator.currentCharacter;
    while (c != kCharSpace && c) {
        c = [_utf8Iterator getNextCharacter];
    }
    if (c == kCharEOF) {
        _stop = YES;
        [self notifyErrorWithCode:90042];
        return ;
    }
    while (c != kCharEndAngleBracket && c) {
        c = [_utf8Iterator getNextOneByteCharacter];
    }
    _currentTagName = @"DOCTYPE";
    [self notifyDoctype];
    [self processTagFinish];
}

#pragma mark -
#pragma mark - notify

- (void)notifyStart{
    if (_delegate && [_delegate respondsToSelector:@selector(htmlParserDidStart:)]) {
        [_delegate htmlParserDidStart:self];
    }
}

- (void)notifyOpenTagName:(NSString *)name
               attributes:(NSDictionary *)attributes
       mustacheAttributes:(NSDictionary *)mustacheAttributes{
    if (_delegate && name && [_delegate respondsToSelector:@selector(htmlParser:openTagName:attributes:mustacheAttributes:)]) {
        [_delegate htmlParser:self
                  openTagName:name
                   attributes:attributes
           mustacheAttributes:mustacheAttributes];
    }
}

- (void)notifyCloseTagName:(NSString *)name{
    if (_delegate && [_delegate respondsToSelector:@selector(htmlParser:closeTagName:)]) {
        [_delegate htmlParser:self closeTagName:name];
    }
}

- (void)notifyDoctype{
    if (_delegate && [_delegate respondsToSelector:@selector(htmlParserHandleDocType:)]) {
        [_delegate htmlParserHandleDocType:self];
    }
}

- (void)notifyComment:(NSString *)comment{
    if (_delegate && [_delegate respondsToSelector:@selector(htmlParser:comment:)]) {
        [_delegate htmlParser:self comment:comment];
    }
}

- (void)notifyText:(NSString *)text{
    if (_delegate && [_delegate respondsToSelector:@selector(htmlParser:text:)]) {
        [_delegate htmlParser:self text:text];
    }
}

- (void)notifyScript:(NSString *)scriptText{
    if (_delegate && [_delegate respondsToSelector:@selector(htmlParser:scriptText:)]) {
        [_delegate htmlParser:self scriptText:scriptText];
    }
}

- (void)notifyErrorWithCode:(NSInteger)code{
    if (!_delegate) {
        return ;
    }
    
    NSString *description = @"\n[Description]: error occured when parsing!";
    if (_detectLayoutInformation) {
        description = [NSString stringWithFormat:@"%@\n[Code]:%@\n ;[Position]: (line:%@,column:%@)",description ,@(code) ,@(_utf8Iterator.line) ,@(_utf8Iterator.column)];
    }
    
    NSDictionary *info = @{NSLocalizedDescriptionKey:description};
    if ([_delegate respondsToSelector:@selector(htmlParser:error:)]) {
        NSError *error = [NSError errorWithDomain:@"com.token.xmlparser" code:code userInfo:info];
        [self.delegate htmlParser:self error:error];
    }
}

- (void)notifyFinish{
    if (_delegate && [_delegate respondsToSelector:@selector(htmlParserDidEnd:)]) {
        [_delegate htmlParserDidEnd:self];
    }
}
@end
