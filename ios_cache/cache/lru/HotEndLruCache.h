//
// Created by hydra on 2021/4/7.
//

#import <Foundation/Foundation.h>

typedef BOOL (^TraverseRemoveCallback)(id _Nonnull key, id _Nonnull value, int visitCount);

@interface HotEndLruCache<K, V> : NSObject

#pragma mark - properties

@property(nonatomic) int curSize;
@property(nonatomic) int maxSize;

@property(nonatomic) int maxHotSize;
@property(nonatomic) int hotSize;

#pragma mark - methods

+ (instancetype _Nonnull)cacheWithMaxSize:(int)maxSize hotPercent:(float)hotPercent;

- (void)resize:(int)maxSize hotPercent:(float)hotPercent;

- (V _Nullable)get:(K _Nonnull)key;

- (BOOL)put:(K _Nonnull)key value:(V _Nonnull)value;

- (V _Nullable)remove:(K _Nonnull)key;

- (int)traverseTrim:(int)maxCount callback:(TraverseRemoveCallback _Nonnull)callback;

- (void)clear;

- (void)releaseCache;

@end