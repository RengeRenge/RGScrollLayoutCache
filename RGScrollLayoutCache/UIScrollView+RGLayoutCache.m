//
//  UIScrollView+RGLayoutCache.m
//  CampTalk
//
//  Created by renge on 2019/8/31.
//  Copyright © 2019 yuru. All rights reserved.
//

#import "UIScrollView+RGLayoutCache.h"
#import <RGUIKit/RGUIKit.h>

static BOOL RGLayoutCacheLogEnable = NO;
#ifdef DEBUG
#define RGLayoutCacheLog(...) NSLog(__VA_ARGS__)
#else
#define RGLayoutCacheLog(...)
#endif

@interface UIScrollView ()

@property (nonatomic, strong) NSCache *rg_layoutCache;

@property (nonatomic, assign) CGRect rg_previousPreheatRect;
@property (nonatomic, strong) dispatch_queue_t rg_opQueue;
@property (nonatomic, strong) NSOperationQueue *rg_layoutQueue;
@property (atomic, weak) id <RGLayoutCacheDelegate> rg_layoutDeleagte;

@end

@implementation UIScrollView (RGLayoutCache)

+ (void)rg_setCacheLogEnable:(BOOL)enable {
    RGLayoutCacheLogEnable = enable;
}

- (void)rg_setLayoutCacheDelegate:(id<RGLayoutCacheDelegate>)delegate {
    self.rg_layoutDeleagte = delegate;
    if (delegate) {
        [self rg_initLayoutIfNeed];
    } else {
        self.rg_opQueue = nil;
        self.rg_layoutQueue = nil;
        self.rg_layoutCache = nil;
    }
}

- (void)rg_setMaxCacheOperationCount:(NSUInteger)count {
    [self rg_initLayoutIfNeed];
    self.rg_layoutQueue.maxConcurrentOperationCount = count;
}

- (void)rg_initLayoutIfNeed {
    if (!self.rg_layoutQueue) {
        self.rg_layoutQueue = [[NSOperationQueue alloc] init];
        self.rg_layoutQueue.maxConcurrentOperationCount = 40;
        self.rg_layoutQueue.name = @"rg_layoutQueue";
        self.rg_layoutQueue.qualityOfService = NSQualityOfServiceUserInteractive;
        
        self.rg_opQueue = dispatch_queue_create("rg_layoutCacheOpQueue", DISPATCH_QUEUE_SERIAL);
        
        self.rg_layoutCache = [[NSCache alloc] init];
        self.rg_layoutCache.countLimit = 1000;
        
        self.rg_previousPreheatRect = CGRectZero;
        
        [self rg_addObserver:self forKeyPath:@"frame" options:NSKeyValueObservingOptionNew context:@"RGLayoutCache"];
        
        [self rg_updateLastFrame];
        
        if (self.rg_autoCache) {
            [self rg_updateCachedLayout];
        }
    }
}

#pragma mark - SetGet

- (void)setRg_autoCache:(BOOL)rg_autoCache {
    if (rg_autoCache == self.rg_autoCache) {
        return;
    }
    [self rg_setValue:@(rg_autoCache) forKey:@"rg_autoCache" retain:NO];
    if (rg_autoCache) {
        [self rg_addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:@"RGLayoutCache"];
        [self rg_updateCachedLayout];
    } else {
        [self rg_removeObserver:self forKeyPath:@"contentOffset"];
    }
}

- (BOOL)rg_autoCache {
    return [[self rg_valueForKey:@"rg_autoCache"] boolValue];
}

- (void)setRg_layoutDeleagte:(id<RGLayoutCacheDelegate>)rg_layoutDeleagte {
    [self rg_setValue:rg_layoutDeleagte forKey:@"rg_layoutDeleagte" retain:NO];
}

- (id<RGLayoutCacheDelegate>)rg_layoutDeleagte {
    return [self rg_valueForKey:@"rg_layoutDeleagte"];
}

- (void)setRg_layoutQueue:(NSOperationQueue *)rg_layoutQueue {
    [self rg_setValue:rg_layoutQueue forKey:@"rg_layoutQueue" retain:YES];
}

- (NSOperationQueue *)rg_layoutQueue {
    return [self rg_valueForKey:@"rg_layoutQueue"];
}

- (void)setRg_opQueue:(dispatch_queue_t)rg_opQueue {
    [self rg_setValue:rg_opQueue forKey:@"rg_opQueue" retain:YES];
}

- (dispatch_queue_t)rg_opQueue {
    return [self rg_valueForKey:@"rg_opQueue"];
}

- (void)setRg_layoutCache:(NSCache *)rg_layoutCache {
    [self rg_setValue:rg_layoutCache forKey:@"rg_layoutCache" retain:YES];
}

- (NSCache *)rg_layoutCache {
    return [self rg_valueForKey:@"rg_layoutCache"];
}

- (void)setRg_previousPreheatRect:(CGRect)rg_previousPreheatRect {
    [self rg_setValue:[NSValue valueWithCGRect:rg_previousPreheatRect] forKey:@"rg_previousPreheatRect" retain:YES];
}

- (CGRect)rg_previousPreheatRect {
    return [[self rg_valueForKey:@"rg_previousPreheatRect"] CGRectValue];
}

- (CGRect)rg_lastFrame {
    return [[self rg_valueForKey:@"rg_lastFrame"] CGRectValue];
}

- (void)rg_updateLastFrame {
    CGRect frame = self.frame;
    [self rg_setValue:[NSValue valueWithCGRect:frame] forKey:@"rg_lastFrame" retain:YES];
    [self rg_setValue:[NSValue valueWithCGRect:frame] forKey:@"rg_nowFrame" retain:YES];
}

- (CGRect)rg_nowFrame {
    return [[self rg_valueForKey:@"rg_nowFrame"] CGRectValue];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)contex {
    if (!contex) {
        return;
    }
    if (!self.window) {
        return;
    }
    if ([@"RGLayoutCache" isEqualToString:(__bridge NSString * _Nonnull)(contex)]) {
        if (!self.rg_layoutDeleagte) {
            return;
        }
        if ([keyPath isEqualToString:@"contentOffset"]) {
            [self rg_updateCachedLayout];
        } else if ([keyPath isEqualToString:@"frame"]) {
            CGRect now = [change[NSKeyValueChangeNewKey] CGRectValue];;
            CGRect old = self.rg_nowFrame;
            
            if (CGRectEqualToRect(now, old)) {
                return;
            }
            [self rg_setValue:[NSValue valueWithCGRect:now] forKey:@"rg_nowFrame" retain:YES];
            [self rg_setValue:[NSValue valueWithCGRect:old] forKey:@"rg_lastFrame" retain:YES];
        }
    }
}

#pragma mark - method

- (NSString *)rg_keyWithIndexPath:(NSIndexPath *)indexPath {
    return [NSString stringWithFormat:@"%ld,%ld", (long)indexPath.section, (long)indexPath.row];
}

- (void)rg_startCachingLayoutForIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {
    if (!self.rg_layoutDeleagte) {
        return;
    }
    dispatch_async(self.rg_opQueue, ^{
        NSMutableArray <NSBlockOperation *> *array = [NSMutableArray arrayWithCapacity:indexPaths.count];
        [indexPaths enumerateObjectsUsingBlock:^(NSIndexPath * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (!self.rg_layoutDeleagte) {
                return;
            }
            NSString *key = [self rg_keyWithIndexPath:obj];
            NSString *sizeString = [self.rg_layoutCache objectForKey:key];
            if (sizeString) {
                return;
            }
//            __block BOOL existed = NO;
//            [self.rg_layoutQueue.operations enumerateObjectsUsingBlock:^(__kindof NSOperation * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
//                if ([obj.name isEqualToString:key] && obj.isExecuting) {
//                    existed = YES;
//                    *stop = YES;
//                    RGLayoutCacheLog(@"indexPath is duplicate");
//                }
//            }];
//            if (existed) {
//                return;
//            }
            NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:^{
                if ([self.rg_layoutDeleagte respondsToSelector:@selector(scrollView:sizeForRowAtIndexPath:isMainThread:)]) {
                    CGSize size = [self.rg_layoutDeleagte scrollView:self sizeForRowAtIndexPath:obj isMainThread:NO];
                    [self.rg_layoutCache setObject:NSStringFromCGSize(size) forKey:key];
                    RGLayoutCacheLog(@"load in cache queue ✌️");
                }
            }];
            op.name = key;
            [array addObject:op];
        }];
        [self.rg_layoutQueue addOperations:array waitUntilFinished:NO];
    });
}

- (void)rg_stopCachingLayoutForIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {
    if (!self.rg_layoutDeleagte) {
        return;
    }
    dispatch_async(self.rg_opQueue, ^{
        [indexPaths enumerateObjectsUsingBlock:^(NSIndexPath * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (!self.rg_layoutDeleagte) {
                return;
            }
            NSString *key = [self rg_keyWithIndexPath:obj];
            [self.rg_layoutQueue.operations enumerateObjectsUsingBlock:^(__kindof NSOperation * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if ([obj.name isEqualToString:key]) {
                    [obj cancel];
//                    *stop = YES;
                    RGLayoutCacheLog(@"cancel in cache queue 🎇");
                }
            }];
        }];
    });
}

- (void)rg_stopCachingImagesForAllIndexPath {
    if (!self.rg_layoutDeleagte) {
        return;
    }
    dispatch_async(self.rg_opQueue, ^{
        [self.rg_layoutQueue cancelAllOperations];
    });
}

- (void)rg_clearlayoutCache {
    dispatch_sync(self.rg_opQueue, ^{
        [self.rg_layoutQueue cancelAllOperations];
        [self.rg_layoutCache removeAllObjects];
        self.rg_previousPreheatRect = CGRectZero;
    });
}

- (void)rg_clearlayoutCacheAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {
    dispatch_sync(self.rg_opQueue, ^{
        [indexPaths enumerateObjectsUsingBlock:^(NSIndexPath * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString *key = [self rg_keyWithIndexPath:obj];
            [self.rg_layoutQueue.operations enumerateObjectsUsingBlock:^(__kindof NSOperation * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if ([obj.name isEqualToString:key]) {
                    [obj cancel];
//                    *stop = YES;
                    RGLayoutCacheLog(@"cancel in cache queue by clear cache 🎇");
                }
            }];
            [self.rg_layoutCache removeObjectForKey:key];
        }];
    });
}

- (CGSize)rg_layoutCacheSizeAtIndexPath:(NSIndexPath *)indexPath {
    return [self rg_layoutCacheSizeAtIndexPath:indexPath onlyCache:NO];
}

- (CGSize)rg_layoutCacheSizeAtIndexPath:(NSIndexPath *)indexPath onlyCache:(BOOL)onlyCache {
    if ([self isKindOfClass:UITableView.class]) {
        UITableView *view = (UITableView *)self;
        if (view.rowHeight > 0) {
            CGSize size = view.frame.size;
            size.height = view.rowHeight;
            return size;
        }
    }
    
    NSString *key = [self rg_keyWithIndexPath:indexPath];
    NSString *sizeString = [self.rg_layoutCache objectForKey:key];
    if (sizeString) {
//        RGLayoutCacheLog(@"hit in cache");
        return CGSizeFromString(sizeString);
    }
    
    [self.rg_layoutQueue.operations enumerateObjectsUsingBlock:^(__kindof NSOperation * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.name isEqualToString:key]) {
            if (obj.isExecuting) {
                RGLayoutCacheLog(@"hit waitUntilFinished");
                [obj waitUntilFinished];
            } else if (obj.isCancelled) {
                RGLayoutCacheLog(@"hit canceled");
            }
        }
    }];
    
    sizeString = [self.rg_layoutCache objectForKey:key];
    if (sizeString) {
        RGLayoutCacheLog(@"hit for async ⌛️");
        return CGSizeFromString(sizeString);
    }
    
    if (!onlyCache && [self.rg_layoutDeleagte respondsToSelector:@selector(scrollView:sizeForRowAtIndexPath:isMainThread:)]) {
        CGSize size = [self.rg_layoutDeleagte scrollView:self sizeForRowAtIndexPath:indexPath isMainThread:[NSThread isMainThread]];
        [self.rg_layoutQueue addOperationWithBlock:^{
            [self.rg_layoutCache setObject:NSStringFromCGSize(size) forKey:[self rg_keyWithIndexPath:indexPath]];
        }];
        RGLayoutCacheLog(@"load in main sync 😭");
        return size;
    }
    return CGSizeZero;
}

- (void)rg_updateCachedLayout {
    if (!self.rg_layoutQueue) {
        return;
    }
    BOOL isViewVisible = [self window] != nil;
    if (!isViewVisible) { return; }

    // 预加载区域是可显示区域的两倍
    CGRect preheatRect = self.bounds;
    preheatRect = CGRectInset(preheatRect, 0.0f, -0.5f * CGRectGetHeight(preheatRect));

    // 比较是否显示的区域与之前预加载的区域有不同
    CGFloat delta = ABS(CGRectGetMidY(preheatRect) - CGRectGetMidY(self.rg_previousPreheatRect));
    if (delta > CGRectGetHeight(self.bounds) / 3.0f) {

        // 区分资源分别操作
        NSMutableArray *addedIndexPaths = [NSMutableArray array];
        NSMutableArray *removedIndexPaths = [NSMutableArray array];

        [self computeDifferenceBetweenRect:self.rg_previousPreheatRect andRect:preheatRect removedHandler:^(CGRect removedRect) {
            if ([self isKindOfClass:UITableView.class]) {
                [removedIndexPaths addObjectsFromArray:[(UITableView *)self indexPathsForRowsInRect:removedRect]];
            } else if ([self isKindOfClass:UICollectionView.class]) {
                UICollectionView *collection = (UICollectionView *)self;
                NSArray *indexPaths = [self indexPathsForElementsInCollectionView:collection rect:removedRect];
                [removedIndexPaths addObjectsFromArray:indexPaths];
            }
        } addedHandler:^(CGRect addedRect) {
            if ([self isKindOfClass:UITableView.class]) {
                [addedIndexPaths addObjectsFromArray:[(UITableView *)self indexPathsForRowsInRect:addedRect]];
            } else if ([self isKindOfClass:UICollectionView.class]) {
                UICollectionView *collection = (UICollectionView *)self;
                NSArray *indexPaths = [self indexPathsForElementsInCollectionView:collection rect:addedRect];
                [addedIndexPaths addObjectsFromArray:indexPaths];
            }
        }];

        // 更新缓存
        [self rg_startCachingLayoutForIndexPaths:addedIndexPaths];
        [self rg_stopCachingLayoutForIndexPaths:removedIndexPaths];

        // 存储预加载矩形已供比较
        self.rg_previousPreheatRect = preheatRect;
    }
}

- (void)computeDifferenceBetweenRect:(CGRect)oldRect andRect:(CGRect)newRect removedHandler:(void (^)(CGRect removedRect))removedHandler addedHandler:(void (^)(CGRect addedRect))addedHandler {
    if (CGRectIntersectsRect(newRect, oldRect)) {
        CGFloat oldMaxY = CGRectGetMaxY(oldRect);
        CGFloat oldMinY = CGRectGetMinY(oldRect);
        CGFloat newMaxY = CGRectGetMaxY(newRect);
        CGFloat newMinY = CGRectGetMinY(newRect);

        if (newMaxY > oldMaxY) {
            CGRect rectToAdd = CGRectMake(newRect.origin.x, oldMaxY, newRect.size.width, (newMaxY - oldMaxY));
            addedHandler(rectToAdd);
        }

        if (oldMinY > newMinY) {
            CGRect rectToAdd = CGRectMake(newRect.origin.x, newMinY, newRect.size.width, (oldMinY - newMinY));
            addedHandler(rectToAdd);
        }

        if (newMaxY < oldMaxY) {
            CGRect rectToRemove = CGRectMake(newRect.origin.x, newMaxY, newRect.size.width, (oldMaxY - newMaxY));
            removedHandler(rectToRemove);
        }

        if (oldMinY < newMinY) {
            CGRect rectToRemove = CGRectMake(newRect.origin.x, oldMinY, newRect.size.width, (newMinY - oldMinY));
            removedHandler(rectToRemove);
        }
    } else {
        addedHandler(newRect);
        removedHandler(oldRect);
    }
}

- (NSArray *)indexPathsFromIndexes:(NSIndexSet *)indexSet section:(NSUInteger)section {
    NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity:indexSet.count];
    [indexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        [indexPaths addObject:[NSIndexPath indexPathForItem:idx inSection:section]];
    }];
    return indexPaths;
}

- (NSArray *)indexPathsForElementsInCollectionView:(UICollectionView *)collection rect:(CGRect)rect {
    NSArray *allLayoutAttributes = [collection.collectionViewLayout layoutAttributesForElementsInRect:rect];
    if (allLayoutAttributes.count == 0) { return nil; }
    NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity:allLayoutAttributes.count];
    for (UICollectionViewLayoutAttributes *layoutAttributes in allLayoutAttributes) {
        NSIndexPath *indexPath = layoutAttributes.indexPath;
        [indexPaths addObject:indexPath];
    }
    return indexPaths;
}

@end
