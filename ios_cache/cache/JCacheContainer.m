//
// Created by Hydra Dr on 2021/3/13.
//

#import <pthread.h>
#import "JCacheContainer.h"
#import "JCacheKey.h"

@interface JCacheContainer ()

@property(nonatomic, readonly) NSMapTable<Class, JCache *> *allCaches;

@property(nonatomic) pthread_rwlock_t lock;

@end

@implementation JCacheContainer

- (instancetype)init {
    self = [super init];

    if (self) {
        pthread_rwlock_init(&_lock, NULL);

        _allCaches = [NSMapTable strongToStrongObjectsMapTable];
    }

    return self;
}

+ (instancetype)sharedInstance {
    static id _sharedInstance = nil;

    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });

    return _sharedInstance;
}

- (nullable JCache *)doGetCacheForClazz:(Class)cacheClazz {
    pthread_rwlock_rdlock(&_lock);

    JCache *cache = [_allCaches objectForKey:cacheClazz];

    pthread_rwlock_unlock(&_lock);

    return cache;
}

+ (nullable JCache *)getCacheForClazz:(Class)cacheClazz {
    return [[JCacheContainer sharedInstance] doGetCacheForClazz:cacheClazz];
}

- (nonnull JCache *)doBuildCache:(JCacheBuilder *)builder {
    pthread_rwlock_rdlock(&_lock);

    JCache *constCache = [_allCaches objectForKey:builder.cacheClazz];

    pthread_rwlock_unlock(&_lock);

    if (!constCache) {
        pthread_rwlock_wrlock(&_lock);

        constCache = [_allCaches objectForKey:builder.cacheClazz];

        if (!constCache) {
            constCache = [[JCache alloc] initWith:builder];

            [_allCaches setObject:constCache forKey:builder.cacheClazz];
        }

        pthread_rwlock_unlock(&_lock);
    } else {
        [NSException raise:NSInvalidArgumentException
                    format:@"class: %@ already exist in JCache, don't build it again", builder.cacheClazz];
    }

    return constCache;
}

+ (nonnull JCache *)buildCacheForClazz:(nonnull Class)cacheClazz with:(nonnull CacheController *)controller {
    return [[JCacheContainer sharedInstance] doBuildCache:[[JCacheBuilder alloc]
            initWith:cacheClazz controller:controller]];
}

+ (nonnull JCache *)buildCache:(JCacheBuilder *)builder {
    return [[JCacheContainer sharedInstance] doBuildCache:builder];
}

- (void)doRemoveCache:(Class)cacheClazz {
    pthread_rwlock_wrlock(&_lock);

    JCache *cache = [_allCaches objectForKey:cacheClazz];

    if (cache) {
        [_allCaches removeObjectForKey:cacheClazz];
    }

    pthread_rwlock_unlock(&_lock);

    [cache releaseCache];
}

+ (void)removeCache:(Class)cacheClazz {
    [[JCacheContainer sharedInstance] doRemoveCache:cacheClazz];
}
@end