//
//  UIScrollView+RGLayoutCache.m
//  CampTalk
//
//  Created by renge on 2019/8/31.
//  Copyright © 2019 yuru. All rights reserved.
//

#import "UIScrollView+RGLayoutCache.h"
#import <RGRunTime/RGRunTime.h>
#import <RGObserver/RGObserver.h>

#ifdef DEBUG
#define RGLayoutCacheLog(fmt, ...) self.rg_layoutCacheLogEnable ? NSLog((@"[RGLC] "fmt), ##__VA_ARGS__) : (fmt)
#else
#define RGLayoutCacheLog(fmt, ...)
#endif

@interface UIScrollView ()

@property (nonatomic, strong) NSCache *rg_layoutCache;

@property (nonatomic, assign) CGRect rg_previousPreheatRect;
@property (nonatomic, strong) dispatch_queue_t rg_opQueue;
@property (nonatomic, strong) NSOperationQueue *rg_layoutQueue;

@property (nonatomic, assign) CGRect rg_nowFrame;

@end

@implementation UIScrollView (RGLayoutCache)

- (void)rg_initLayoutIfNeed {
    if (!self.rg_layoutQueue) {
        self.rg_layoutQueue = [[NSOperationQueue alloc] init];
        self.rg_layoutQueue.maxConcurrentOperationCount = 10;
        self.rg_layoutQueue.name = @"rg_layoutQueue";
        self.rg_layoutQueue.qualityOfService = NSQualityOfServiceUserInteractive;
        
        self.rg_opQueue = dispatch_queue_create("rg_layoutCacheOpQueue", DISPATCH_QUEUE_SERIAL);
        
        self.rg_layoutCache = [[NSCache alloc] init];
        self.rg_layoutCache.countLimit = 1000;
        
        self.rg_previousPreheatRect = CGRectZero;
        
        [self rg_addObserver:self forKeyPath:@"frame" options:NSKeyValueObservingOptionNew context:@"RGLayoutCache"];
        
        self.rg_nowFrame = self.frame;
        
        if (self.rg_autoLayoutCache) {
            [self rg_updateCachedLayout];
        }
    }
}

#pragma mark - SetGet

- (void)setRg_autoLayoutCache:(BOOL)rg_autoCache {
    if (rg_autoCache == self.rg_autoLayoutCache) {
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

- (BOOL)rg_autoLayoutCache {
    return [[self rg_valueforConstKey:"rg_autoCache"] boolValue];
}

- (void)setRg_layoutCacheDelegate:(id<RGLayoutCacheDelegate>)rg_layoutCacheDelegate {
    [self rg_setValue:rg_layoutCacheDelegate forConstKey:"rg_layoutDelegate" retain:NO];
    if (rg_layoutCacheDelegate) {
        [self rg_initLayoutIfNeed];
    } else {
        self.rg_opQueue = nil;
        self.rg_layoutQueue = nil;
        self.rg_layoutCache = nil;
    }
}

- (id<RGLayoutCacheDelegate>)rg_layoutCacheDelegate {
    return [self rg_valueforConstKey:"rg_layoutDelegate"];
}

- (void)setRg_maxLayoutCacheConcurrentOperationCount:(NSUInteger)rg_maxCacheOperationCount {
    [self rg_initLayoutIfNeed];
    self.rg_layoutQueue.maxConcurrentOperationCount = rg_maxCacheOperationCount;
}

- (NSUInteger)rg_maxLayoutCacheConcurrentOperationCount {
    return self.rg_layoutQueue.maxConcurrentOperationCount;
}

- (void)setRg_layoutCacheLogEnable:(BOOL)rg_layoutCacheLogEnable {
    [self rg_setValue:@(rg_layoutCacheLogEnable) forConstKey:"rg_layoutCacheLogEnable" retain:YES];
}

- (BOOL)rg_layoutCacheLogEnable {
    return [[self rg_valueforConstKey:"rg_layoutCacheLogEnable"] boolValue];
}

- (void)setRg_layoutQueue:(NSOperationQueue *)rg_layoutQueue {
    [self rg_setValue:rg_layoutQueue forConstKey:"rg_layoutQueue" retain:YES];
}

- (NSOperationQueue *)rg_layoutQueue {
    return [self rg_valueforConstKey:"rg_layoutQueue"];
}

- (void)setRg_opQueue:(dispatch_queue_t)rg_opQueue {
    [self rg_setValue:rg_opQueue forConstKey:"rg_opQueue" retain:YES];
}

- (dispatch_queue_t)rg_opQueue {
    return [self rg_valueforConstKey:"rg_opQueue"];
}

- (void)setRg_layoutCache:(NSCache *)rg_layoutCache {
    [self rg_setValue:rg_layoutCache forConstKey:"rg_layoutCache" retain:YES];
}

- (NSCache *)rg_layoutCache {
    return [self rg_valueforConstKey:"rg_layoutCache"];
}

- (void)setRg_previousPreheatRect:(CGRect)rg_previousPreheatRect {
    [self rg_setValue:[NSValue valueWithCGRect:rg_previousPreheatRect] forConstKey:"rg_previousPreheatRect" retain:YES];
}

- (CGRect)rg_previousPreheatRect {
    return [[self rg_valueforConstKey:"rg_previousPreheatRect"] CGRectValue];
}

- (void)setRg_nowFrame:(CGRect)rg_nowFrame {
    [self rg_setValue:[NSValue valueWithCGRect:rg_nowFrame] forConstKey:"rg_nowFrame" retain:YES];
}

- (CGRect)rg_nowFrame {
    return [[self rg_valueforConstKey:"rg_nowFrame"] CGRectValue];
}

- (void)setRg_layoutCacheDependOn:(RGLayoutCacheDependOn)rg_layoutCacheDependOn {
    [self rg_setValue:@(rg_layoutCacheDependOn) forConstKey:"rg_layoutCacheDependOn" retain:YES];
}

- (RGLayoutCacheDependOn)rg_layoutCacheDependOn {
    return [[self rg_valueforConstKey:"rg_layoutCacheDependOn"] intValue];
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
        if (!self.rg_layoutCacheDelegate) {
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
            self.rg_nowFrame = now;
            BOOL clear = [self __shouldClearLayoutCachesForScrollView:self oldFrame:old];
            if (clear) {
                [self rg_clearlayoutCache];
                [self rg_startCachingLayoutForVisiableIndexPath];
            }
        }
    }
}

#pragma mark - method

- (NSNumber *)rg_keyWithIndexPath:(NSIndexPath *)indexPath {
#if __LP64__ || 0 || NS_BUILD_32_LIKE_64
    long long section = ((long long)indexPath.section << sizeof(indexPath.section)) | indexPath.row;
#else
    long section = ((long)indexPath.section << sizeof(indexPath.section)) | indexPath.row;
#endif
    return @(section);
}

- (NSString *)__idWithIndexPath:(NSIndexPath *)indexPath {
    __block NSString *key = nil;
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            key = [self __idWithIndexPath:indexPath];
        });
        return key;
    }
    if ([self.rg_layoutCacheDelegate respondsToSelector:@selector(scrollView:cacheSizeIdAtIndexPath:)]) {
        key = [self.rg_layoutCacheDelegate scrollView:self cacheSizeIdAtIndexPath:indexPath];
    }
    NSString *append = nil;
    switch (self.rg_layoutCacheDependOn) {
        case RGLayoutCacheDependOnWidth:
            append = @(self.frame.size.width).stringValue;
            break;
        case RGLayoutCacheDependOnHeight:
            append = @(self.frame.size.height).stringValue;
            break;
        default:
            append = NSStringFromCGSize(self.frame.size);
            break;
    }
    return [key stringByAppendingPathComponent:append];
}

- (NSArray <NSString *> *)__idsWithIndexPaths:(NSArray <NSIndexPath *> *)indexPaths {
    NSMutableArray *ids = [NSMutableArray arrayWithCapacity:indexPaths.count];
    [indexPaths enumerateObjectsUsingBlock:^(NSIndexPath * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *Id = [self __idWithIndexPath:obj];
        [ids addObject:Id];
    }];
    return ids;
}

- (BOOL)__shouldClearLayoutCachesForScrollView:(UIScrollView *)scrollView oldFrame:(CGRect)oldFrame {
    switch (self.rg_layoutCacheDependOn) {
        case RGLayoutCacheDependOnWidth:
            return scrollView.frame.size.width != oldFrame.size.width;
        case RGLayoutCacheDependOnHeight:
            return scrollView.frame.size.height != oldFrame.size.height;
        default:
            return !CGSizeEqualToSize(scrollView.frame.size, oldFrame.size);
    }
}

- (void)rg_startCachingLayoutForIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {
    if (!self.rg_layoutCacheDelegate) {
        return;
    }
    
    NSArray <NSString *> *ids = [self __idsWithIndexPaths:indexPaths];
    
    dispatch_async(self.rg_opQueue, ^{
        NSMutableArray <NSBlockOperation *> *array = [NSMutableArray arrayWithCapacity:indexPaths.count];
        [ids enumerateObjectsUsingBlock:^(NSString * _Nonnull Id, NSUInteger idx, BOOL * _Nonnull stop) {
            if (!self.rg_layoutCacheDelegate) {
                return;
            }
            NSString *sizeString = [self.rg_layoutCache objectForKey:Id];
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
                if ([self.rg_layoutCacheDelegate respondsToSelector:@selector(scrollView:scrollViewFrame:cacheSizeForRowAtIndexPath:isMainThread:)]) {
                    NSIndexPath *indexPath = indexPaths[idx];
                    CGSize size = [self.rg_layoutCacheDelegate scrollView:self scrollViewFrame:self.rg_nowFrame cacheSizeForRowAtIndexPath:indexPath isMainThread:NO];
                    [self.rg_layoutCache setObject:NSStringFromCGSize(size) forKey:Id];
                    RGLayoutCacheLog(@"load in cache queue ✌️ [%ld-%ld] [id: %@]",
                                     (long)indexPath.section,
                                     (long)indexPath.row,
                                     [Id stringByDeletingLastPathComponent]
                                     );
                }
            }];
            op.name = Id;
            [array addObject:op];
        }];
        [self.rg_layoutQueue addOperations:array waitUntilFinished:NO];
    });
}

- (void)rg_startCachingLayoutForSections:(NSIndexSet *)sections count:(NSInteger (NS_NOESCAPE^)(NSInteger))count {
    [sections enumerateIndexesUsingBlock:^(NSUInteger section, BOOL * _Nonnull stop) {
        NSUInteger rowCount = count(section);
        for (NSUInteger row = 0; row < rowCount; row++) {
            [self rg_startCachingLayoutForIndexPaths:@[[NSIndexPath indexPathForRow:row inSection:section]]];
        }
    }];
}

- (void)rg_startCachingLayoutForAllIndexPath {
    UITableView *tb = nil;
    UICollectionView *co = nil;
    if ([self isKindOfClass:UITableView.class]) {
        tb = (UITableView *)self;
        NSUInteger section = [tb numberOfSections];
        for (NSUInteger i = 0; i < section; i++) {
            NSUInteger row = [tb numberOfRowsInSection:i];
            for (NSUInteger j = 0; j < row; j++) {
                [tb rg_startCachingLayoutForIndexPaths:@[[NSIndexPath indexPathForRow:i inSection:j]]];
            }
        }
    }
    if ([self isKindOfClass:UICollectionView.class]) {
        co = (UICollectionView *)self;
        NSUInteger section = [co numberOfSections];
        for (NSUInteger i = 0; i < section; i++) {
            NSUInteger row = [co numberOfItemsInSection:i];
            for (NSUInteger j = 0; j < row; j++) {
                [co rg_startCachingLayoutForIndexPaths:@[[NSIndexPath indexPathForRow:i inSection:j]]];
            }
        }
    }
}

- (void)rg_startCachingLayoutForVisiableIndexPath {
    UITableView *tb = nil;
    UICollectionView *co = nil;
    if ([self isKindOfClass:UITableView.class]) {
        tb = (UITableView *)self;
        [tb rg_startCachingLayoutForIndexPaths:tb.indexPathsForVisibleRows];
    }
    if ([self isKindOfClass:UICollectionView.class]) {
        co = (UICollectionView *)self;
        [co rg_startCachingLayoutForIndexPaths:co.indexPathsForVisibleItems];
    }
}

- (void)rg_stopCachingLayoutForIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {
    if (!self.rg_layoutCacheDelegate) {
        return;
    }
    NSArray <NSString *> *ids = [self __idsWithIndexPaths:indexPaths];
    dispatch_async(self.rg_opQueue, ^{
        [ids enumerateObjectsUsingBlock:^(NSString * _Nonnull Id, NSUInteger idx, BOOL * _Nonnull stop) {
            [self.rg_layoutQueue.operations enumerateObjectsUsingBlock:^(__kindof NSOperation * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if ([obj.name isEqualToString:Id]) {
                    [obj cancel];
//                    *stop = YES;
                    RGLayoutCacheLog(@"cancel in cache queue 🎇");
                }
            }];
        }];
    });
}

- (void)rg_stopCachingLayoutForAllIndexPath {
    if (!self.rg_layoutCacheDelegate) {
        return;
    }
    dispatch_async(self.rg_opQueue, ^{
        [self.rg_layoutQueue cancelAllOperations];
    });
}

- (void)rg_clearlayoutCache {
    if (!self.rg_opQueue) {
        return;
    }
    dispatch_sync(self.rg_opQueue, ^{
        [self.rg_layoutQueue cancelAllOperations];
        [self.rg_layoutCache removeAllObjects];
        self.rg_previousPreheatRect = CGRectZero;
    });
}

- (void)rg_clearlayoutCacheAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {
    NSArray <NSString *> *ids = [self __idsWithIndexPaths:indexPaths];
    dispatch_sync(self.rg_opQueue, ^{
        [ids enumerateObjectsUsingBlock:^(NSString * _Nonnull Id, NSUInteger idx, BOOL * _Nonnull stop) {
            [self.rg_layoutQueue.operations enumerateObjectsUsingBlock:^(__kindof NSOperation * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if ([obj.name isEqualToString:Id]) {
                    [obj cancel];
//                    *stop = YES;
                    RGLayoutCacheLog(@"cancel in cache queue by clear cache 🎇");
                }
            }];
            [self.rg_layoutCache removeObjectForKey:Id];
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
    
    NSString *Id = [self __idWithIndexPath:indexPath];
    NSString *sizeString = [self.rg_layoutCache objectForKey:Id];
    if (sizeString) {
//        RGLayoutCacheLog(@"hit in cache");
        return CGSizeFromString(sizeString);
    }
    
    [self.rg_layoutQueue.operations enumerateObjectsUsingBlock:^(__kindof NSOperation * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.name isEqualToString:Id]) {
            if (obj.isExecuting) {
                RGLayoutCacheLog(@"hit waitUntilFinished");
                [obj waitUntilFinished];
            } else if (obj.isCancelled) {
                RGLayoutCacheLog(@"hit canceled");
            }
        }
    }];
    
    sizeString = [self.rg_layoutCache objectForKey:Id];
    if (sizeString) {
        RGLayoutCacheLog(@"hit for async ⌛️");
        return CGSizeFromString(sizeString);
    }
    
    if (!onlyCache && [self.rg_layoutCacheDelegate respondsToSelector:@selector(scrollView:scrollViewFrame:cacheSizeForRowAtIndexPath:isMainThread:)]) {
        CGSize size = [self.rg_layoutCacheDelegate scrollView:self scrollViewFrame:self.frame cacheSizeForRowAtIndexPath:indexPath isMainThread:[NSThread isMainThread]];
        [self.rg_layoutCache setObject:NSStringFromCGSize(size) forKey:Id];
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
