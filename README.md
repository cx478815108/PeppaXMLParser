# PeppaXMLParser
A fast and convenient xml parser

| feature | support |
| --- | --- |
| mustache attributes => id = '{{object.id}}' | YES |
| parsing full js scripts not CDATA | YES |
| CDATA | NO |


## delegate API

```
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
```


