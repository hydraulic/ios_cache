//
// Created by hydra on 2021/4/8.
//

#import <Foundation/Foundation.h>
#import "JCacheValue.h"

@class JCacheKey;

typedef BOOL (^CacheTrimBlock)(JCacheKey *_Nonnull cacheKey, id _Nonnull value);

typedef void (^CacheRefreshBlock)(JCacheKey *_Nonnull cacheKey, JCacheValue *_Nonnull cacheObject);

typedef id _Nonnull (^CreateNewObjectBlock)(JCacheKey *_Nonnull cacheKey);

#pragma mark - CacheController

@interface CacheController<T> : NSObject

@property(nonatomic, nullable) CacheTrimBlock cacheTrimBlock;
@property(nonatomic, nullable) CacheRefreshBlock cacheRefreshBlock;

- (nonnull instancetype)initWith:(nonnull CreateNewObjectBlock)callback;

- (BOOL)canValueBeTrimmed:(JCacheKey *_Nonnull)cacheKey value:(T _Nonnull)value;

- (T _Nonnull)createNewObject:(JCacheKey *_Nonnull)cacheKey;

- (void)onNeedRefresh:(JCacheKey *_Nonnull)cacheKey value:(JCacheValue<T> *_Nonnull)cacheObject;

@end

#pragma mark - JCacheBuilder

const static int DEFAULT_HARD_MIN_SIZE = 64;

@interface JCacheBuilder<T> : NSObject

@property(nonatomic, readonly, nonnull) CacheController<T> *cacheController;
@property(nonatomic, readonly, nonnull) Class cacheClazz;
@property(nonatomic) long long expireTime;
@property(nonatomic) int minHardSize;

- (nonnull instancetype)initWith:(nonnull Class)cacheClazz
                      controller:(nonnull CacheController *)cacheController;

@end