//
// Created by hydra on 2021/4/7.
//

#import <Foundation/Foundation.h>

/**
 * 这里的key，是限制了只能是 实现了NSObject协议 的对象；
 * 所以不能供core foundation里的对象使用，相比起来，YYMemoryCache是使用了CFDictionary
 * 但是如果里面保存指针的话，hash值对比就只能用指针地址了，不够灵活；
 */
@interface JCacheKey : NSObject

@property(nonatomic, readonly) NSArray<id<NSObject>> *_Nonnull keys;

@property(nonatomic, readonly) NSUInteger keyHash;

/**
 * 多主键，要按顺序
 */
+ (instancetype _Nonnull)cacheKeyMulti:(nonnull NSArray<id<NSObject>> *) keys;

/**
 * for fast operation
 */
+ (instancetype _Nonnull)cacheKeySingle:(id<NSObject> _Nonnull)key;

- (id _Nonnull)keyAt:(uint32_t)index;

@end