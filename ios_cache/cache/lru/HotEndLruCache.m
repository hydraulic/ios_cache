//
// Created by hydra on 2021/4/7.
//

#import <pthread.h>
#import "HotEndLruCache.h"
#import "LruNode.h"

const static int HOT_COLD_BOUNDARY = 2;

@interface HotEndLruCache<K, V> ()

@property(nonatomic) HotEndLruNode<K, V> *coldHead;
@property(nonatomic) HotEndLruNode<K, V> *hotHead;

@property(nonatomic, readonly) NSMapTable<K, V> *locationMap;

@property(nonatomic) pthread_rwlock_t lock;

@end

@implementation HotEndLruCache

+ (instancetype)cacheWithMaxSize:(int)maxSize hotPercent:(float)hotPercent {
    return [[HotEndLruCache alloc] initWithMaxSize:maxSize hotPercent:hotPercent];
}

- (instancetype)initWithMaxSize:(int)maxSize hotPercent:(float)hotPercent {
    self = [super init];

    if (self) {
        pthread_rwlock_init(&_lock, NULL);

        _locationMap = [NSMapTable strongToStrongObjectsMapTable];

        [self resize:maxSize hotPercent:hotPercent];
    }

    return self;
}

- (void)resize:(int)maxSize hotPercent:(float)hotPercent {
    if (maxSize < HOT_COLD_BOUNDARY || hotPercent < 0.0f || hotPercent >= 1.0f) {
        [NSException raise:NSRangeException format:@"illegal params maxSize: %d, "
                                                   "hotPercent: %f", maxSize, hotPercent];
    }

    pthread_rwlock_rdlock(&_lock);

    @try {
        _maxSize = maxSize;

        // maxSize int [2, +∞]
        // maxHotSize in [1, maxSize - 1]
        _maxHotSize = MIN(maxSize - 1, MAX(1, (int) (maxSize * hotPercent)));

        if (_curSize > maxSize) {
            [self trimTo:maxSize];
        }
    } @finally {
        pthread_rwlock_unlock(&_lock);
    }
}

- (id _Nullable)get:(id _Nonnull)key {
    HotEndLruNode *node;

    pthread_rwlock_rdlock(&_lock);

    if ((node = [_locationMap objectForKey:key]) != nil) {
        [node increaseVisitCount];
    }

    pthread_rwlock_unlock(&_lock);

    return node ? node.value : nil;
}

- (BOOL)put:(id _Nonnull)key value:(id _Nonnull)value {
    HotEndLruNode *newNode = [HotEndLruNode nodeWithKey:key value:value size:1];

    if (newNode.size > _maxSize) {
        return NO;
    }

    pthread_rwlock_wrlock(&_lock);

    @try {
        HotEndLruNode *oldNode = [_locationMap objectForKey:key];

        [_locationMap setObject:newNode forKey:key];

        BOOL trimmed = false;

        if (oldNode) {
            int lastVisitCount = (int) oldNode.visitCount;

            [self removeNode:oldNode];

            [newNode updateVisitCount:lastVisitCount + 1];
        } else {
            trimmed = [self trimTo:_maxSize - newNode.size];
        }

        if (_hotHead && _coldHead && trimmed) {
            [self insert:newNode before:_coldHead];

            _coldHead = newNode;
            newNode.isColdNode = YES;

            _curSize += newNode.size;
        } else {
            if (_hotHead) {
                [self insert:newNode before:_hotHead];
            } else {
                newNode.next = newNode.pre = newNode;
            }

            BOOL isDoubleHead = _coldHead == _hotHead;

            _hotHead = newNode;

            _hotSize += newNode.size;
            _curSize += newNode.size;

            if (!_coldHead) {
                if (_curSize > _maxSize) {
                    [self setNewColdHead:_hotHead.pre];
                }
            } else {
                if (_hotSize > _maxHotSize) {
                    if (isDoubleHead && _coldHead.pre != _coldHead) {
                        _hotSize -= _coldHead.size;
                        _coldHead.isColdNode = YES;
                    }

                    [self setNewColdHead:_coldHead.pre];
                }
            }
        }
    } @finally {
        pthread_rwlock_unlock(&_lock);
    }

    return YES;
}

- (BOOL)trimTo:(int)targetSize {
    HotEndLruNode *removed = nil;

    while (_curSize > targetSize) {
        while (true) {
            HotEndLruNode *coldTail = _hotHead.pre;

            if (((int) coldTail.visitCount) >= HOT_COLD_BOUNDARY) {
                [coldTail updateVisitCount:1];

                [self setNewHotHead:coldTail];

                while (true) {
                    if (_hotSize <= _maxHotSize || ![self setNewColdHead:_coldHead.pre]) {
                        break;
                    }
                }

                continue;
            }

            removed = coldTail;

            [_locationMap removeObjectForKey:removed.key];
            [self removeNode:removed];

            break;
        }
    }

    return removed != nil;
}

- (void)insert:(HotEndLruNode *_Nonnull)newNode before:(HotEndLruNode *_Nonnull)existNode {
    newNode.next = existNode;
    newNode.pre = existNode.pre;

    existNode.pre.next = newNode;
    existNode.pre = newNode;
}

- (id _Nullable)remove:(id _Nonnull)key {
    pthread_rwlock_wrlock(&_lock);

    HotEndLruNode *node;

    @try {
        if ((node = [_locationMap objectForKey:key])) {
            [_locationMap removeObjectForKey:key];

            [node updateVisitCount:0];

            if (node.pre) {
                [self removeNode:node];
            }
        }
    } @finally {
        pthread_rwlock_unlock(&_lock);
    }

    if (!node) {
        return nil;
    }

    return node.value;
}

- (void)removeNode:(HotEndLruNode *_Nonnull)node {
    if (node.next == node) {
        [self setNewHotHead:nil];
        [self setNewColdHead:nil];
    } else {
        node.next.pre = node.pre;
        node.pre.next = node.next;

        if (_hotHead == node) {
            [self setNewHotHead:node.next];
        }

        if (_coldHead == node) {
            [self setNewColdHead:node.next];
        }
    }

    _curSize -= node.size;

    if (!node.isColdNode) {
        _hotSize -= node.size;
    }
}

- (void)setNewHotHead:(HotEndLruNode *_Nullable)node {
    if (node) {
        if (node.isColdNode) {
            _hotSize += node.size;
        }

        node.isColdNode = false;
    }

    _hotHead = node;
}

- (BOOL)setNewColdHead:(HotEndLruNode *_Nullable)node {
    _coldHead = node;

    if (!node || _coldHead == node) {
        return NO;
    }

    if (!node.isColdNode) {
        _hotSize -= node.size;
    }

    node.isColdNode = YES;

    return YES;
}

/**
 * 这里的逻辑有点绕，因为逻辑是这样的：
 * 1、因为外部缓存的两层缓存设计，我们永远也用不到LruCache自带的trim，所以我们需要自己接管trim逻辑
 * 2、在外部缓存中，等于我们对于trim的条件有两个：
 * 1) 在硬缓存中我们有依赖于每个节点自己的 canValueBeTrimmed 逻辑判断
 * 2) 在软引用中，我们有是否被GC 这个条件来判断
 * <p>
 * 所以，我们在这里替换了原有算法里对visitCount的判断来移动hot指针
 */
- (int)traverseTrim:(int)maxCount callback:(TraverseRemoveCallback _Nonnull)callback {
    pthread_rwlock_wrlock(&_lock);

    int count = 0;

    @try {
        if (!_hotHead) {
            return 0;
        }

        HotEndLruNode *node = _hotHead.pre;  // cold tail

        for (; count < maxCount; ++count) {
            if (!callback(node.key, node.value, (int) node.visitCount)) {
                [node updateVisitCount:1];

                [self setNewHotHead:node];

                while (_hotSize > _maxHotSize) {
                    if (![self setNewColdHead:_coldHead.pre]) {
                        break;
                    }
                }
            }

            HotEndLruNode *pre = node.pre;

            if (pre == node) {
                break;
            }

            node = pre;
        }
    } @finally {
        pthread_rwlock_unlock(&_lock);
    }

    return count;
}

- (void)clear {
    pthread_rwlock_wrlock(&_lock);

    [_locationMap removeAllObjects];

    [self setNewHotHead:nil];
    [self setNewColdHead:nil];

    _curSize = 0;
    _hotSize = 0;

    pthread_rwlock_unlock(&_lock);
}

- (void)releaseCache {
    [self clear];

    pthread_rwlock_destroy(&_lock);
}

- (NSString *)description {
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", NSStringFromClass([self class])];
    [description appendFormat:@"self.curSize=%u", self.curSize];
    [description appendFormat:@", self.maxSize=%u", self.maxSize];
    [description appendFormat:@", self.maxHotSize=%u", self.maxHotSize];
    [description appendFormat:@", self.hotSize=%u", self.hotSize];
    [description appendFormat:@", self.coldHead=%@", self.coldHead];
    [description appendFormat:@", self.hotHead=%@", self.hotHead];
    [description appendString:@">"];
    return description;
}

@end
