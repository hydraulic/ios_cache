//
// Created by hydra on 2021/4/7.
//

#import <Foundation/Foundation.h>

@class JCacheKey;

@interface JCacheValue<T> : NSObject

#pragma mark - properties

@property(nonatomic, readonly) JCacheKey * _Nonnull cacheKey;

//TODO 提供两种引用方式，后续可以考虑用NSValue包装一层
@property(nonatomic, readonly, nonnull) T value;
@property(nonatomic, readonly, weak, nullable) T weakValue;

@property(atomic) long long lastRefreshTime;

#pragma mark - methods

+ (instancetype _Nonnull)valueWithCacheKey:(JCacheKey * _Nonnull)cacheKey value:(T _Nonnull)value;

+ (instancetype _Nonnull)valueWithCacheKey:(JCacheKey * _Nonnull)cacheKey weakValue:(T _Nonnull)value;

@end
