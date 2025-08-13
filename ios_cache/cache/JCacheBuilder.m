//
// Created by hydra on 2021/4/8.
//

#import "JCacheBuilder.h"

@interface CacheController()

@property(nonatomic, nonnull, readonly) CreateNewObjectBlock createNewObjectBlock;

@end

@implementation CacheController

- (instancetype)initWith:(CreateNewObjectBlock)callback {
    self = [super init];

    if (self) {
        _createNewObjectBlock = callback;
    }

    return self;
}

- (BOOL)canValueBeTrimmed:(JCacheKey *)cacheKey value:(id)value {
    return _cacheTrimBlock && _cacheTrimBlock(cacheKey, value);
}

- (id)createNewObject:(JCacheKey *)cacheKey {
    return _createNewObjectBlock(cacheKey);
}

- (void)onNeedRefresh:(JCacheKey *)cacheKey value:(JCacheValue *)cacheObject {
    if (_cacheRefreshBlock) {
        _cacheRefreshBlock(cacheKey, cacheObject);
    }
}
@end

@implementation JCacheBuilder

- (instancetype)initWith:(Class)cacheClazz controller:(CacheController *)cacheController {
    self = [super init];

    if (self) {
        _cacheController = cacheController;
        _cacheClazz = cacheClazz;

        //default value
        _expireTime = -1L;
        _minHardSize = DEFAULT_HARD_MIN_SIZE;
    }

    return self;
}

@end