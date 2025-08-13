//
// Created by Hydra Dr on 2021/3/13.
//

#import <pthread.h>
#import "JCache.h"
#import "JCacheKey.h"
#import "HotEndLruCache.h"
#import "HGThreadBus.h"
#import "NHGGCDTimer.h"

@interface JCache<T> ()

@property(nonatomic) pthread_rwlock_t lock;

@property(nonatomic, readonly) HotEndLruCache<JCacheKey *, JCacheValue<T> *> *hardCache;
@property(nonatomic, readonly) HotEndLruCache<JCacheKey *, JCacheValue<T> *> *weakCache;

@property(nonatomic, readonly) long long expireTime;

@property(nonatomic, readonly, nonnull) CacheController *cacheController;

@property(nonatomic) NHGGCDTimer *trimHardTimer;
@property(nonatomic) NHGGCDTimer *trimWeakTimer;

@property(nonatomic, readonly) int hardInitSize;
@property(nonatomic, readonly) int weakInitSize;

@property(nonatomic) long long lastTrimWeakTime;

@property(nonatomic, readonly) NSString *tag;

@end

@implementation JCache

- (instancetype)initWith:(JCacheBuilder *)builder {
    self = [super init];

    if (self) {
        _cacheName = NSStringFromClass(builder.cacheClazz);

        _cacheController = builder.cacheController;
        _expireTime = builder.expireTime;

        _tag = [@"JCache_" stringByAppendingString:_cacheName];

        _hardInitSize = builder.minHardSize;
        _weakInitSize = builder.minHardSize * 8;    // weak的初始size == hardSize * 8

        _hardCache = [HotEndLruCache cacheWithMaxSize:_hardInitSize
                                           hotPercent:DEFAULT_HARD_HOT_PERCENT];
        _weakCache = [HotEndLruCache cacheWithMaxSize:_weakInitSize
                                           hotPercent:DEFAULT_WEAK_HOT_PERCENT];

        [self initTrimTask];
    }

    return self;
}

- (void)initTrimTask {
    __weak JCache *weakSelf = self;

    // TODO: hydra 2021/4/9 11:08 上午 select a more properly queue to do this task
    _trimHardTimer = [NHGGCDTimer timerWith:[[HGThreadBus sharedInstance] queueOf:ThreadBackground] action:^{
                                               __strong JCache *strongSelf = weakSelf;

                                               if (strongSelf) {
                                                   [strongSelf trimHard];
                                               }
                                           } interval:TRIM_HARD_INTERVAL];

    _trimWeakTimer = [NHGGCDTimer timerWith:[[HGThreadBus sharedInstance] queueOf:ThreadBackground]
                                           action:^{
                                               __strong JCache *strongSelf = weakSelf;

                                               if (strongSelf) {
                                                   [strongSelf trimWeak];
                                               }
                                           } interval:TRIM_WEAK_INTERVAL];

    [_trimHardTimer start];
    [_trimWeakTimer start];
}

- (id)get:(JCacheKey *)key {
    return [self get:key autoCreate:YES];
}

- (id)get:(JCacheKey *)key autoCreate:(BOOL)autoCreate {
    JCacheValue *cacheObject = [self cacheObjectForKey:key autoCreate:autoCreate];

    if (cacheObject) {
        if (_expireTime != -1L) {
            long long current = (long long) ([[NSDate date] timeIntervalSince1970] * 1000L);

            long long lastRefreshTime = cacheObject.lastRefreshTime;

            if (current - lastRefreshTime >= _expireTime) {
                cacheObject.lastRefreshTime = current;

                [[HGThreadBus sharedInstance] post:^{
                    [_cacheController onNeedRefresh:key value:cacheObject];
                    // TODO: hydra 2021/4/9 00:45 put it to anthoer thread
                }                               to:ThreadWorking];
            }
        }

        return cacheObject.value;
    }

    return NULL;
}

- (id)putIfAbsent:(JCacheKey *)key data:(id)data {
    pthread_rwlock_rdlock(&_lock);

    JCacheValue *cacheValue = [_hardCache get:key];

    if (cacheValue) {
        pthread_rwlock_unlock(&_lock);

        return cacheValue.value;
    }

    pthread_rwlock_unlock(&_lock);
    pthread_rwlock_wrlock(&_lock);

    cacheValue = [_hardCache get:key];

    if (cacheValue) {
        pthread_rwlock_unlock(&_lock);

        return cacheValue.value;
    }

    JCacheValue *weakCacheObject = [_weakCache remove:key];

    if (!weakCacheObject) {
        [self putToHard:key value:[JCacheValue valueWithCacheKey:key value:data]];

        pthread_rwlock_unlock(&_lock);

        return nil;
    }

    __strong id weakValue = weakCacheObject.weakValue;

    if (!weakValue) {
        [self putToHard:key value:[JCacheValue valueWithCacheKey:key value:data]];

        pthread_rwlock_unlock(&_lock);

        return nil;
    }

    [self putToHard:key value:[JCacheValue valueWithCacheKey:key value:weakValue]];

    pthread_rwlock_unlock(&_lock);

    return weakValue;
}

- (JCacheValue *_Nonnull)cacheObjectForKey:(JCacheKey *)cacheKey autoCreate:(BOOL)autoCreate {
    pthread_rwlock_rdlock(&_lock);

    JCacheValue *cacheObject;

    @try {
        cacheObject = [_hardCache get:cacheKey];

        if (cacheObject) {
            return cacheObject;
        }

        pthread_rwlock_unlock(&_lock);
        pthread_rwlock_wrlock(&_lock);

        // double check
        cacheObject = [_hardCache get:cacheKey];

        if (!cacheObject) {
            cacheObject = [self createNewValue:cacheKey autoCreate:autoCreate];
        }
    } @finally {
        pthread_rwlock_unlock(&_lock);
    }

    return cacheObject;
}

- (JCacheValue *_Nonnull)createNewValue:(JCacheKey *)cacheKey autoCreate:(BOOL)autoCreate {
    JCacheValue *cacheObject;

    JCacheValue *weakCacheObject = [_weakCache remove:cacheKey];

    if (weakCacheObject) {
        __strong id value = weakCacheObject.weakValue;

        if (value) {
            cacheObject = [JCacheValue valueWithCacheKey:cacheKey value:value];
        } else {
            if (autoCreate) {
                cacheObject = [JCacheValue valueWithCacheKey:cacheKey
                                                       value:[_cacheController createNewObject:cacheKey]];
            }
        }
    } else if (autoCreate) {
        cacheObject = [JCacheValue valueWithCacheKey:cacheKey
                                               value:[_cacheController createNewObject:cacheKey]];
    }

    if (!cacheObject) {
        return nil;
    }

    [self putToHard:cacheKey value:cacheObject];

    return cacheObject;
}

- (void)putToHard:(JCacheKey *)cacheKey value:(JCacheValue *)value {
    int hardSize = _hardCache.curSize;
    int hardMaxSize = _hardCache.maxSize;

    if (hardSize + 1 > hardMaxSize) {
        int newHardMaxSize = (int) (hardMaxSize * DEFAULT_SIZE_INCREASE_STEP);

        // TODO: hydra 2021/4/7 9:30 下午
//        MLog.info(mTag, "putToHard newHardMaxSize: " + newHardMaxSize);

        [_hardCache resize:newHardMaxSize hotPercent:DEFAULT_HARD_HOT_PERCENT];
    }

    [_hardCache put:cacheKey value:value];
}

- (void)clear {
    pthread_rwlock_wrlock(&_lock);

    [_hardCache clear];

    [_weakCache clear];

    pthread_rwlock_unlock(&_lock);
}

- (void)dealloc {
    [self releaseCache];
}

- (void)releaseCache {
    [_hardCache releaseCache];

    [_weakCache releaseCache];

    [_trimHardTimer stop];
    [_trimWeakTimer stop];

    pthread_rwlock_destroy(&_lock);
}

- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    }

    if (!other || ![[other class] isEqual:[self class]]) {
        return NO;
    }

    return [self.cacheName isEqualToString:((JCache *) other).cacheName];
}

- (NSUInteger)hash {
    return [self.cacheName hash];
}

- (void)trimHard {
    pthread_rwlock_wrlock(&_lock);

    @try {
        int maxSize = _hardCache.maxSize;

        if (maxSize <= _hardInitSize) {
            return;
        }

        int currentSize = _hardCache.curSize;
        int maxHotSize = _hardCache.maxHotSize;

        // max hot size 的 0.75
        int trimThresholdSize = (int) (maxHotSize * 0.75F);

        int maxTrimCount = MIN(currentSize - trimThresholdSize, TRIM_HARD_MAX_COUNT);

        // TODO: hydra 2021/4/7 9:47 下午 
//        MLog.info(mTag, "trimHard maxTrimCount: " + maxTrimCount + ", trimThresholdSize: " +
//                trimThresholdSize + ", curSize: " + currentSize + ", maxSize: " + maxSize);

        if (maxTrimCount <= 0) {
            return;
        }

        long long start = (long long) ([[NSDate date] timeIntervalSince1970] * 1000L);

        __block int realTrimCount = 0;

        //这个block是同步调用，不用weak self
        int traverseTrimCount = [_hardCache traverseTrim:maxTrimCount callback:(TraverseRemoveCallback) ^(JCacheKey *_Nonnull key, JCacheValue *_Nonnull cacheObject, int visitCount) {
            if (![self canValueBeTrimmed:key value:cacheObject.value]) {
                return NO;
            }

            [_hardCache remove:key];

            JCacheValue *weakObject = [JCacheValue valueWithCacheKey:key weakValue:cacheObject.value];

            weakObject.lastRefreshTime = cacheObject.lastRefreshTime;

            int weakSize = _weakCache.curSize;
            int weakMaxSize = _weakCache.maxSize;

            if (weakSize + 1 > weakMaxSize) {
                int newWeakMaxSize = (int) (weakMaxSize * DEFAULT_SIZE_INCREASE_STEP);

                // TODO: hydra 2021/4/7 10:01 下午
//                MLog.info(mTag, "trimHard weak resize: " + newWeakMaxSize);

                [_weakCache resize:newWeakMaxSize hotPercent:DEFAULT_WEAK_HOT_PERCENT];
            }

            [_weakCache put:key value:weakObject];

            realTrimCount++;

            return YES;
        }];

        currentSize = _hardCache.curSize;

        if (currentSize <= trimThresholdSize) {
            int newMaxSize = MAX(maxHotSize, _hardInitSize);

            // TODO: hydra 2021/4/7 9:50 下午
//            MLog.info(mTag, "trimHard resize: " + newMaxSize);

            [_hardCache resize:newMaxSize hotPercent:DEFAULT_HARD_HOT_PERCENT];
        }

        // TODO: hydra 2021/4/7 9:50 下午
//        MLog.info(mTag, "trimHard traverseTrimCount: " + traverseTrimCount +
//                ", realTrimCount: " + realTrimCount.count + ", trimThresholdSize: " +
//                trimThresholdSize + ", curSize: " + currentSize + ", maxSize: " +
//                mHardCache.maxSize() + ", cost: " + (System.currentTimeMillis() - start));
    } @finally {
        pthread_rwlock_unlock(&_lock);
    }
}

- (void)trimWeak {
    pthread_rwlock_wrlock(&_lock);

    @try {
        int maxSize = _weakCache.maxSize;

        if (maxSize <= _weakInitSize) {
            return;
        }

        int currentSize = _weakCache.curSize;
        int maxHotSize = _weakCache.maxHotSize;

        int trimThresholdSize = (int) (maxHotSize * 0.75F);

        int maxTrimCount = MIN(currentSize - trimThresholdSize, TRIM_WEAK_MAX_COUNT);

        // TODO: hydra 2021/4/8 00:20
//        MLog.info(mTag, "trimWeak maxTrimCount: " + maxTrimCount + ", trimThresholdSize: " +
//                trimThresholdSize + ", curSize: " + currentSize + ", maxSize: " + maxSize);

        long long current = (long long) ([[NSDate date] timeIntervalSince1970] * 1000L);

        if (maxTrimCount <= 0) {
            //因为weak里的引用是会被回收的，所以再加上一个时间间隔
            if (current - _lastTrimWeakTime < TRIM_WEAK_MAX_INTERVAL || currentSize <= 0) {
                return;
            }

            maxTrimCount = maxSize - maxHotSize;
        }

        _lastTrimWeakTime = current;

        __block int realTrimCount = 0;

        int traverseTrimCount = [_weakCache traverseTrim:maxTrimCount callback:(TraverseRemoveCallback) ^(JCacheKey *_Nonnull key, JCacheValue *_Nonnull cacheObject, int visitCount) {
            __strong id value = cacheObject.weakValue;

            if (!value) {
                [_weakCache remove:key];

                realTrimCount++;

                return YES;
            }

//                // 这里要再判断一次，从cold移到hard里
//                if (!canValueBeTrimmed(key, value)) {
//                    mWeakCache.remove(key);
//
//                    JCacheValue<T> hardValue = new JCacheValue<>(key, value);
//                    hardValue.lastRefreshTime = cacheValue.lastRefreshTime;
//
//                    putToHard(key, hardValue);
//
//                    realTrimCount.count++;
//
//                    return true;
//                }
            return NO;
        }];

        currentSize = _weakCache.curSize;

        if (currentSize <= trimThresholdSize) {
            int newMaxSize = MAX(maxHotSize, _weakInitSize);

            // TODO: hydra 2021/4/8 00:20
//            MLog.info(mTag, "trimWeak resize: " + newMaxSize);
            [_weakCache resize:newMaxSize hotPercent:DEFAULT_WEAK_HOT_PERCENT];
        }

        // TODO: hydra 2021/4/8 00:20 
//        MLog.info(mTag, "trimWeak traverseTrimCount: " + traverseTrimCount +
//                ", realTrimCount: " + realTrimCount.count + ", trimThresholdSize: " +
//                trimThresholdSize + ", curSize: " + currentSize + ", maxSize: " +
//                mWeakCache.maxSize() + ", cost: " + (System.currentTimeMillis() - mLastTrimWeakTime));
    } @finally {
        pthread_rwlock_unlock(&_lock);
    }
}

- (BOOL)canValueBeTrimmed:(JCacheKey *_Nonnull)cacheKey value:(id _Nonnull)value {
    return [_cacheController canValueBeTrimmed:cacheKey value:value];
}

@end
