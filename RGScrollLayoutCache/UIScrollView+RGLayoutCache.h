//
//  UIScrollView+RGLayoutCache.h
//  CampTalk
//
//  Created by renge on 2019/8/31.
//  Copyright © 2019 yuru. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol RGLayoutCacheDelegate <NSObject>

- (NSString *)scrollView:(UIScrollView *)scrollView cacheSizeIdAtIndexPath:(NSIndexPath *)indexPath;

- (CGSize)scrollView:(UIScrollView *)scrollView scrollViewFrame:(CGRect)frame cacheSizeForRowAtIndexPath:(NSIndexPath *)indexPath isMainThread:(BOOL)isMainThread;

@end

typedef enum : int {
    RGLayoutCacheDependOnWidth,
    RGLayoutCacheDependOnHeight,
    RGLayoutCacheDependOnSize,
} RGLayoutCacheDependOn;

@interface UIScrollView (RGLayoutCache)

@property (nonatomic, weak, nullable) id <RGLayoutCacheDelegate> rg_layoutCacheDelegate;

/// default 40
@property (nonatomic, assign) NSUInteger rg_maxLayoutCacheConcurrentOperationCount;

@property (nonatomic, assign) BOOL rg_layoutCacheLogEnable;

/**
 enable auto layout cache
 this method add KVO for contentOffset and pre fetch layout
 don't need to call method like rg_startCachingLayoutForIndexPaths...
 */
@property (nonatomic, assign) BOOL rg_autoLayoutCache; // default NO

- (void)rg_startCachingLayoutForIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;
- (void)rg_startCachingLayoutForSections:(NSIndexSet *)sections count:(NSInteger(NS_NOESCAPE^)(NSInteger section))count;
- (void)rg_stopCachingLayoutForIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;
- (void)rg_stopCachingLayoutForAllIndexPath;

- (void)rg_clearlayoutCache;
- (void)rg_clearlayoutCacheAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;

@property (nonatomic, assign) RGLayoutCacheDependOn rg_layoutCacheDependOn;

/**
 get size in cache

 @param indexPath indexPath
 @param onlyCache if only cache, this may return CGSizeZero when not found, otherwise call delegate to get certain size for indexPath
 @return layout size
 */
- (CGSize)rg_layoutCacheSizeAtIndexPath:(NSIndexPath *)indexPath onlyCache:(BOOL)onlyCache;

- (CGSize)rg_layoutCacheSizeAtIndexPath:(NSIndexPath *)indexPath;

@end

NS_ASSUME_NONNULL_END
