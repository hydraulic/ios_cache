//
// Created by hydra on 2021/4/7.
//

#import "JCacheValue.h"
#import "JCacheKey.h"

@implementation JCacheValue

- (instancetype)initWithCacheKey:(JCacheKey *)cacheKey value:(id)value {
    self = [super init];
    if (self) {
        _cacheKey = cacheKey;
        _value = value;
        _lastRefreshTime = 0L;
    }

    return self;
}

- (instancetype)initWithCacheKey:(JCacheKey *)cacheKey weakValue:(id)value {
    self = [super init];
    if (self) {
        _cacheKey = cacheKey;
        _weakValue = value;
        _lastRefreshTime = 0L;
    }

    return self;
}

+ (instancetype _Nonnull)valueWithCacheKey:(JCacheKey * _Nonnull)cacheKey value:(id)value {
    return [[self alloc] initWithCacheKey:cacheKey value:value];
}

+ (instancetype)valueWithCacheKey:(JCacheKey *)cacheKey weakValue:(id)value {
    return [[self alloc] initWithCacheKey:cacheKey weakValue:value];
}

- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    }

    if (!other || ![[other class] isEqual:[self class]]) {
        return NO;
    }

    return [self.cacheKey isEqual:((JCacheValue *) other).cacheKey];
}

- (NSUInteger)hash {
    return [self.cacheKey hash];
}
@end