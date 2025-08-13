//
// Created by hydra on 2021/4/7.
//

#import "JCacheKey.h"

@implementation JCacheKey

+ (instancetype)cacheKeyMulti:(nonnull NSArray<id <NSObject>> *)keys {
    NSMutableString *des = [[NSMutableString alloc] init];

    for (id <NSObject> key in keys) {
        [des appendFormat:@"%lu,", key.hash];
    }

    return [[self alloc] initWithKeys:keys des:des];
}

- (instancetype)initWithKeys:(NSArray<id <NSObject>> *)keys des:(NSString *)keyStr {
    self = [super init];

    if (self) {
        _keys = keys;

        _keyHash = keyStr.hash;
    }

    return self;
}

+ (instancetype)cacheKeySingle:(id)key {
    return [[self alloc] initWithKey:key];
}

- (instancetype)initWithKey:(id <NSObject>)key {
    self = [super init];

    if (self) {
        _keys = @[key];
        _keyHash = key.hash;
    }

    return self;
}

- (id _Nonnull)keyAt:(uint32_t)index {
    return _keys[index];
}

- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    }

    if (!other || ![[other class] isEqual:[self class]]) {
        return NO;
    }

    return self.keyHash == ((JCacheKey *) other).keyHash;
}

- (NSUInteger)hash {
    return _keyHash;
}

- (NSString *)description {
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", NSStringFromClass([self class])];
    [description appendFormat:@"%@", self.keys];
    [description appendFormat:@", %lu", _keyHash];
    [description appendString:@">"];
    return description;
}

@end