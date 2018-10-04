//
//  PeppaTokenizer.h
//  TokenHybridCompiler
//
//  Created by 陈雄 on 2018/9/24.
//  Copyright © 2018年 Token. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PeppaXMLParser;
@protocol PeppaXMLParserDelegate <NSObject>
@optional

- (void)htmlParserDidStart:(PeppaXMLParser *)parser;

- (void)htmlParserDidEnd:(PeppaXMLParser *)parser;

- (void)htmlParserHandleDocType:(PeppaXMLParser *)parser;

- (void)htmlParser:(PeppaXMLParser *)parser
       openTagName:(NSString *)tagName
        attributes:(NSDictionary *)attributes
mustacheAttributes:(NSDictionary *)mustacheAttributes;

- (void)htmlParser:(PeppaXMLParser *)parser
              text:(NSString *)text;

- (void)htmlParser:(PeppaXMLParser *)parser
      closeTagName:(NSString *)tagName;

- (void)htmlParser:(PeppaXMLParser *)parser
        scriptText:(NSString *)scriptText;

- (void)htmlParser:(PeppaXMLParser *)parser
           comment:(NSString *)comment;

- (void)htmlParser:(PeppaXMLParser *)parser
             error:(NSError *)error;
@end

@interface PeppaXMLParser : NSObject
@property(nonatomic ,assign) BOOL detectMustacheAttribute; // <div name = "{{Bob}}"> {{Bob}} will be handled
@property(nonatomic ,assign) BOOL detectEntireScript; // do not use CDAD,you can write the script
@property(nonatomic ,assign ,readonly) BOOL detectLayoutInformation; // calculate the line & column, defalue NO
@property(nonatomic ,weak  ) id <PeppaXMLParserDelegate> delegate;

- (instancetype)initWithText:(NSString *)text;

- (instancetype)initWithText:(NSString *)text
      deatchLayoutInfomation:(BOOL)deatchLayoutInfomation;

- (void)stopParsing;
- (void)startParse;
@end
