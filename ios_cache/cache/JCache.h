//
// Created by Hydra Dr on 2021/3/13.
//

#import <Foundation/Foundation.h>
#import "JCacheValue.h"
#import "JCacheBuilder.h"

@class JCacheKey;

const static float DEFAULT_HARD_HOT_PERCENT = 0.75F;
const static float DEFAULT_WEAK_HOT_PERCENT = 0.6F;

// 默认的扩容倍数
const static float DEFAULT_SIZE_INCREASE_STEP = 1.5F;

const static long long TRIM_HARD_INTERVAL = 1000 * 90L;
const static long long TRIM_WEAK_INTERVAL = 1000 * 90 * 3L;
const static long long TRIM_WEAK_MAX_INTERVAL = 1000 * 60 * 6L;

const static int TRIM_HARD_MAX_COUNT = 1000;
const static int TRIM_WEAK_MAX_COUNT = 2000;

@interface JCache<T> : NSObject

@property(nonatomic, readonly, nonnull) NSString *cacheName;

- (instancetype _Nonnull)initWith:(JCacheBuilder<T> *_Nonnull)builder;

- (T _Nonnull)get:(JCacheKey *_Nonnull)key;

- (T _Nullable)get:(JCacheKey *_Nonnull)key autoCreate:(BOOL)autoCreate;

- (T _Nullable)putIfAbsent:(JCacheKey *_Nonnull)key data:(T)data;

- (void)clear;

- (void)releaseCache;

@end