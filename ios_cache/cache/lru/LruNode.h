//
// Created by hydra on 2021/4/7.
//

#import <Foundation/Foundation.h>
#import <stdatomic.h>


@interface HotEndLruNode<K, V> : NSObject

#pragma mark - properties

@property(nonatomic) HotEndLruNode<K, V> *next;

@property(nonatomic) HotEndLruNode<K, V> *pre;

@property(nonatomic, readonly) K key;

@property(nonatomic, readonly) V value;

@property(nonatomic) atomic_int visitCount;

@property(nonatomic) BOOL isColdNode;

@property(nonatomic, readonly) int size;

#pragma mark - methods

- (void)increaseVisitCount;

- (void)updateVisitCount:(int)newCount;

+ (instancetype)nodeWithKey:(id)key value:(id)value size:(int)size;

@end