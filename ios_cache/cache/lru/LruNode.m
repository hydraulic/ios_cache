//
// Created by hydra on 2021/4/7.
//

#import "LruNode.h"


@implementation HotEndLruNode

- (instancetype)initWithKey:(id)key value:(id)value size:(int)size {
    self = [super init];
    if (self) {
        _key = key;
        _value = value;
        _size = size;
        _isColdNode = NO;
    }

    return self;
}

+ (instancetype)nodeWithKey:(id)key value:(id)value size:(int)size {
    return [[self alloc] initWithKey:key value:value size:size];
}

- (void)increaseVisitCount {
    atomic_fetch_add(&_visitCount, 1);
}

- (void)updateVisitCount:(int)newCount {
    atomic_store(&_visitCount, newCount);
}

- (NSString *)description {
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", NSStringFromClass([self class])];
    [description appendFormat:@"self.next=%@", self.next];
    [description appendFormat:@", self.pre=%@", self.pre];
    [description appendFormat:@", self.key=%@", self.key];
    [description appendFormat:@", self.value=%@", self.value];
    [description appendFormat:@", self.visitCount=%@", self.visitCount];
    [description appendFormat:@", self.isColdNode=%d", self.isColdNode];
    [description appendString:@">"];
    return description;
}

@end
