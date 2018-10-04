//
//  PeppaUTF8Iterator.h
//  TokenHybridCompiler
//
//  Created by 陈雄 on 2018/9/25.
//  Copyright © 2018年 Token. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PeppaUTF8Iterator : NSObject
@property(nonatomic ,strong ,readonly) NSError  *error;
@property(nonatomic ,assign ,readonly) NSInteger currentCharPosition;
@property(nonatomic ,assign ,readonly) NSInteger currentCharacterLength;
@property(nonatomic ,assign ,readonly) NSInteger charLength;
@property(nonatomic ,assign ,readonly) int       currentCharacter;
@property(nonatomic ,assign ,readonly) NSInteger currentUnitPosition;
@property(nonatomic ,assign ,readonly) NSInteger line;
@property(nonatomic ,assign ,readonly) NSInteger column;

- (instancetype)initWithText:(NSString *)text
      deatchLayoutInfomation:(BOOL)deatchLayoutInfomation;

- (int)getNextCharacter;

- (int)getNextOneByteCharacter;
@end
