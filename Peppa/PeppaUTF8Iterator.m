//
//  PeppaUTF8Iterator.m
//  TokenHybridCompiler
//
//  Created by 陈雄 on 2018/9/25.
//  Copyright © 2018年 Token. All rights reserved.
//

#import "PeppaUTF8Iterator.h"

static const char kCharEOF = '\0';

@interface PeppaUTF8Iterator()
@property (nonatomic ,readonly) const char *utf8String;
@property (nonatomic ,assign ,readonly) BOOL deatchLayoutInformation;
@end

@implementation PeppaUTF8Iterator
- (instancetype)initWithText:(NSString *)text
      deatchLayoutInfomation:(BOOL)deatchLayoutInfomation{
    if (self = [super init]) {
        _line                    = 0;
        _column                  = 0;
        _currentCharPosition     = 0;
        _currentCharacterLength  = 0;
        _currentUnitPosition     = -1;
        _currentCharacter        = kCharEOF;
        _utf8String              = [[text copy] UTF8String];
        _charLength              = strlen(_utf8String);
        _deatchLayoutInformation = deatchLayoutInfomation;
    }
    return self;
}

- (NSError *)makeIteratorErrorWithCode:(NSInteger)code {
    NSString *domain = @"com.token.UTF8Iterator";
    return [NSError errorWithDomain:domain code:code userInfo:nil];
}

- (int)getNextOneByteCharacter{
    _currentCharacter        = _utf8String[_currentCharPosition];
    _currentCharPosition    += 1;
    _currentCharacterLength  = 1;
    _currentUnitPosition    += 1;
    
    if (_deatchLayoutInformation) {
        if (_currentCharacter == '\n' || _currentCharacter == '\r') {
            _line  += 1;
            _column = 0;
        }
        else {
            _column += 1;
        }
    }
    
    if (_currentCharPosition > _charLength) {
        return kCharEOF;
    }
    return _currentCharacter;
}

- (int)getNextCharacter {
    unsigned char c = _utf8String[_currentCharPosition];
    // 初始化一个char长度
    NSInteger charLength = 0;
    unsigned char mask = '\0';
    if (c < 0x80) {
        charLength = 1; // 1字节
        mask       = 0xFF;
    } else if (c < 0xC0) {
        charLength = 1; // 1字节
    } else if (c < 0xE0) {
        charLength = 2; // 2字节
        mask       = 0x1F;
        if (c < 0xC2) {
            _error = [self makeIteratorErrorWithCode:900194];
            return kCharEOF;
        }
    } else if (c < 0xF0) {
        charLength = 3; // 3字节
        mask       = 0xF;
    } else if (c < 0xF5) {
        charLength = 4; // 4字节
        mask       = 0x7;
    } else {
        _currentCharacter = kCharEOF;
        _error            = [self makeIteratorErrorWithCode:900195];
        return kCharEOF;
    }
    
    uint64_t codePoint = c & mask;
    
    for (NSInteger i = 1; i < charLength; i++) {
        c = (unsigned char) _utf8String[_currentCharPosition + i];
        codePoint = (codePoint << 6) | (c & ~0x80);
    }
    
    if (codePoint > 0x10FFFF || _currentCharPosition > _charLength) {
        _error = [self makeIteratorErrorWithCode:900197];
        _currentCharacter = kCharEOF;
        return kCharEOF;
    };

    _currentCharPosition    += charLength;
    _currentCharacterLength  = charLength;
    _currentCharacter        = (int)codePoint;
    if (codePoint) {
       _currentUnitPosition    += 1;
    }
    
    if (_deatchLayoutInformation) {
        if (codePoint == '\n' || codePoint == '\r') {
            _line  += 1;
            _column = 0;
        }
        else {
            _column += 1;
        }
    }
    return (int)codePoint;
}
@end
