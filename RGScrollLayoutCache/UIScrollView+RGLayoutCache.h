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

- (CGSize)scrollView:(UIScrollView *)scrollView sizeForRowAtIndexPath:(NSIndexPath *)indexPath isMainThread:(BOOL)isMainThread;

@end

@interface UIScrollView (RGLayoutCache)

/**
 enable auto cache
 this method add KVO for contentOffset and pre fetch layout
 don't need to call method like rg_startCachingLayoutForIndexPaths...
 */
@property (nonatomic, assign) BOOL rg_autoCache; // default NO

- (void)rg_setLayoutCacheDelegate:(nullable id <RGLayoutCacheDelegate>)delegate;

- (void)rg_setMaxCacheOperationCount:(NSUInteger)count; // default 40

- (void)rg_startCachingLayoutForIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;
- (void)rg_stopCachingLayoutForIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;
- (void)rg_stopCachingImagesForAllIndexPath;

- (void)rg_clearlayoutCache;
- (void)rg_clearlayoutCacheAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;

/**
 record last frame, if frame changed, you may call rg_clearlayoutCache to use new layout
 */
- (CGRect)rg_lastFrame;
- (void)rg_updateLastFrame;

/**
 record now frame, if RGLayoutCacheDelegate called not in mainThread, you may need this frame to use do layout
 */
- (CGRect)rg_nowFrame;


/**
 get size in cache

 @param indexPath indexPath
 @param onlyCache if only cache, this may return CGSizeZero when not found, otherwise call delegate to get certain size for indexPath
 @return layout size
 */
- (CGSize)rg_layoutCacheSizeAtIndexPath:(NSIndexPath *)indexPath onlyCache:(BOOL)onlyCache;

- (CGSize)rg_layoutCacheSizeAtIndexPath:(NSIndexPath *)indexPath;


+ (void)rg_setCacheLogEnable:(BOOL)enable;

@end

NS_ASSUME_NONNULL_END
