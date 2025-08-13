//
// Created by Hydra Dr on 2021/3/13.
//

#import <Foundation/Foundation.h>
#import "JCacheValue.h"
#import "JCache.h"

#pragma mark - JCacheContainer

@interface JCacheContainer<T> : NSObject

+(nullable JCache<T>*) getCacheForClazz:(nonnull Class)cacheClazz;

+(nonnull JCache<T>*) buildCache:(nonnull JCacheBuilder *)builder;

+(nonnull JCache<T>*) buildCacheForClazz:(nonnull Class)cacheClazz with:(nonnull CacheController *)controller;

+(void) removeCache:(nonnull Class)cacheClazz;

@end