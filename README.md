# RGScrollLayoutCache
Pre-load layout of UITableView or UICollectionView in background thread

- RGScrollLayoutCache is a category of UIScrollview
- RGScrollLayoutCache could help UITableView or UICollectionView pre-load layout and save result in cache
- The auto cache loading mechanism refer to [Example app using Photos framework](https://developer.apple.com/library/archive/samplecode/UsingPhotosFramework/Introduction/Intro.html#//apple_ref/doc/uid/TP40014575)

## Installation
Add via [CocoaPods](http://cocoapods.org) by adding this to your Podfile:

```ruby
pod 'RGScrollLayoutCache'
```

## Usage
- Set cache delegate
```objective-c
[self.tableView rg_setLayoutCacheDelegate:self];
```

- Enable auto cache 
```objective-c
self.tableView.rg_autoCache = YES;
```
- Else use custom cache

RGScrollLayoutCache could cooperate with UITableViewDataSourcePrefetching.
However, the performance of this way is not satisfactory after testing.
```objective-c
- (void)tableView:(UITableView *)tableView prefetchRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {
    [tableView rg_startCachingLayoutForIndexPaths:indexPaths];
}

- (void)tableView:(UITableView *)tableView cancelPrefetchingForRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths {
    [tableView rg_stopCachingLayoutForIndexPaths:indexPaths];
}
```

- RGLayoutCacheDelegate
```objective-c
// Do layout at this delegate.
- (CGSize)scrollView:(UIScrollView *)scrollView sizeForRowAtIndexPath:(NSIndexPath *)indexPath isMainThread:(BOOL)isMainThread {
    // safe-get size whether in the main thread or in the background thread
    CGSize size = scrollView.rg_nowFrame.size;
    
    // get data source. ⚠️realm database need get a new instance in other thread.
    RLMRealm *realm = nil
    if (!isMainThread) {
        realm = self.caCheRealm;
        [realm refresh];
    } else {
        realm = self.realm;
    }
    
    // do layout with size and data source
    return size;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [tableView rg_layoutCacheSizeAtIndexPath:indexPath].height;
}
```

- Clear cache when data source changed or scrollView size changed

```objective-c
- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    CGRect last = self.tableView.rg_lastFrame;
    NSArray <NSIndexPath *> *visible = self.tableView.indexPathsForVisibleRows;
    
    self.tableView.frame = self.view.bounds;
    [self.tableView rg_updateLastFrame];
    
    // width is related to layout in this example.
    if (self.tableView.frame.size.width != last.size.width) {
        [self.tableView rg_clearlayoutCache];
        [self.tableView rg_startCachingLayoutForIndexPaths:visible];
    }
}
```
```objective-c
[self.tableView rg_clearlayoutCacheAtIndexPaths:indexPaths];
[self.tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
```

- Enable log
```objective-c
[UIScrollView rg_setCacheLogEnable:YES];
```

### Test Report

This demo generates 1000 rows of text randomly and sleep 0.01s in layout method

- [Demo video](https://renged.xyz/static/image/config/RGScrollLayoutCache.MP4)

- Demo GIF

  ![cache demo](https://user-images.githubusercontent.com/14158970/64743647-5eadaf00-d533-11e9-8d0f-31f4a75db1e3.gif)

- Layout code
```objective-c
#pragma mark - RGLayoutCacheDelegate

- (CGSize)scrollView:(UIScrollView *)scrollView sizeForRowAtIndexPath:(NSIndexPath *)indexPath isMainThread:(BOOL)isMainThread {
    [NSThread sleepForTimeInterval:0.01];
    CGSize size = scrollView.rg_nowFrame.size;
    size.width -= (52 + 20 + 20 + 20);
    size.height = CGFLOAT_MAX;
    NSString *string = self.fakeData[indexPath.row];
    
    size = [string
            boundingRectWithSize:size
            options:NSStringDrawingUsesFontLeading|NSStringDrawingUsesLineFragmentOrigin
            attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:13.f]}
            context:nil].size;
    size.height = MAX(60, size.height);
    
    size.height += 40;
    return size;
}
```
- 25 times layout in main thread
<img width="757" alt="load_in_main_sync" src="https://user-images.githubusercontent.com/14158970/64699646-d1893c80-d4d7-11e9-90b2-59947cb5dcee.png">

- 33 times layout wait for background thread done
<img width="753" alt="hit for async" src="https://user-images.githubusercontent.com/14158970/64699529-8707c000-d4d7-11e9-9dc5-bb5cf4038019.png">

- 551 times layout in background thread
<img width="754" alt="load in cahce queue" src="https://user-images.githubusercontent.com/14158970/64699653-d51cc380-d4d7-11e9-8ab9-7979c6199bb6.png">

- 0 times cancel layout
<img width="754" alt="cancel in cache queue" src="https://user-images.githubusercontent.com/14158970/64699534-8838ed00-d4d7-11e9-9915-ef50e6aba0ec.png">


