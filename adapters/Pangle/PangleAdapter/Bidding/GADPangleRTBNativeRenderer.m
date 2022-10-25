// Copyright 2022 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "GADPangleRTBNativeRenderer.h"
#import <PAGAdSDK/PAGAdSDK.h>
#include <stdatomic.h>
#import "GADMAdapterPangleUtils.h"
#import "GADMediationAdapterPangleConstants.h"

@interface GADPangleRTBNativeRenderer () <PAGLNativeAdDelegate> {
  /// The completion handler to call when the ad loading succeeds or fails.
  GADMediationNativeLoadCompletionHandler _loadCompletionHandler;
  /// The Pangle native ad.
  PAGLNativeAd *_nativeAd;
  /// The Pangle related view.
  PAGLNativeAdRelatedView *_relatedView;
  /// An ad event delegate to invoke when ad rendering events occur.
  __weak id<GADMediationNativeAdEventDelegate> _delegate;
}

@end

@implementation GADPangleRTBNativeRenderer
@synthesize icon = _icon;

- (void)renderNativeAdForAdConfiguration:
            (nonnull GADMediationNativeAdConfiguration *)adConfiguration
                       completionHandler:
                           (nonnull GADMediationNativeLoadCompletionHandler)completionHandler {
  __block atomic_flag completionHandlerCalled = ATOMIC_FLAG_INIT;
  __block GADMediationNativeLoadCompletionHandler originalCompletionHandler =
      [completionHandler copy];
  _loadCompletionHandler = ^id<GADMediationNativeAdEventDelegate>(
      _Nullable id<GADMediationNativeAd> ad, NSError *_Nullable error) {
    if (atomic_flag_test_and_set(&completionHandlerCalled)) {
      return nil;
    }
    id<GADMediationNativeAdEventDelegate> delegate = nil;
    if (originalCompletionHandler) {
      delegate = originalCompletionHandler(ad, error);
    }
    originalCompletionHandler = nil;
    return delegate;
  };

  NSString *placementId = adConfiguration.credentials.settings[GADMAdapterPanglePlacementID] ?: @"";
  if (!placementId.length) {
    NSError *error = GADMAdapterPangleErrorWithCodeAndDescription(
        GADPangleErrorInvalidServerParameters,
        [NSString stringWithFormat:@"%@ cannot be nil.", GADMAdapterPanglePlacementID]);
    _loadCompletionHandler(nil, error);
    return;
  }

  _relatedView = [[PAGLNativeAdRelatedView alloc] init];

  PAGNativeRequest *request = [PAGNativeRequest request];
  request.adString = adConfiguration.bidResponse;

  GADPangleRTBNativeRenderer *__weak weakSelf = self;
  [PAGLNativeAd loadAdWithSlotID:placementId
                         request:request
               completionHandler:^(PAGLNativeAd *_Nullable nativeAd, NSError *_Nullable error) {
                 GADPangleRTBNativeRenderer *strongSelf = weakSelf;
                 if (!strongSelf) {
                    return;
                 }
                 if (error) {
                   if (strongSelf->_loadCompletionHandler) {
                     strongSelf->_loadCompletionHandler(nil, error);
                   }
                   return;
                 }

                 [strongSelf->_relatedView refreshWithNativeAd:nativeAd];

                 strongSelf->_nativeAd = nativeAd;
                 strongSelf->_nativeAd.delegate = strongSelf;
                 strongSelf->_nativeAd.rootViewController = adConfiguration.topViewController;
      
                 [strongSelf loadRequireData];
               }];
}

- (void)loadRequireData {
    NSString *urlString = _nativeAd.data.icon.imageURL;
    if (!urlString.length) {
        if (_loadCompletionHandler) _delegate = _loadCompletionHandler(self,nil);
        return;
    }
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        if (_loadCompletionHandler) _delegate = _loadCompletionHandler(self,nil);
        return;
    }
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSData *data = [NSData dataWithContentsOfURL:url];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self) {
                return;
            }
            GADNativeAdImage *image = [[GADNativeAdImage alloc] initWithImage:[UIImage imageWithData:data]];
            self->_icon = image;
            if (self->_loadCompletionHandler) {
              id<GADMediationNativeAdEventDelegate> delegate =
                  self->_loadCompletionHandler(self, nil);
              self->_delegate = delegate;
            }
        });
    });
}

#pragma mark - GADMediationNativeAd
- (nullable GADNativeAdImage *)icon {
  return _icon;
}

- (nullable UIView *)mediaView {
  return _relatedView.mediaView;
}

- (nullable UIView *)adChoicesView {
  return _relatedView.logoADImageView;
}

- (nullable NSString *)headline {
  if (_nativeAd && _nativeAd.data) {
    return _nativeAd.data.AdTitle;
  }
  return nil;
}

- (nullable NSString *)body {
  if (_nativeAd && _nativeAd.data) {
    return _nativeAd.data.AdDescription;
  }
  return nil;
}

- (nullable NSString *)callToAction {
  if (_nativeAd && _nativeAd.data) {
    return _nativeAd.data.buttonText;
  }
  return nil;
}

- (nullable NSDecimalNumber *)starRating {
  return nil;
}

- (nullable NSArray<GADNativeAdImage *> *)images {
  return nil;
}

- (NSString *)store {
  return nil;
}

- (nullable NSString *)price {
  return nil;
}

- (nullable NSString *)advertiser {
  if (_nativeAd && _nativeAd.data) {
    return _nativeAd.data.AdTitle;
  }
  return nil;
}

- (nullable NSDictionary<NSString *, id> *)extraAssets {
  return nil;
}

- (void)didUntrackView:(UIView *)view {
  [_nativeAd unregisterView];
}

- (BOOL)hasVideoContent {
  return YES;
}

- (BOOL)handlesUserClicks {
  return YES;
}

- (BOOL)handlesUserImpressions {
  return YES;
}

- (void)didRenderInView:(nonnull UIView *)view
       clickableAssetViews:
           (nonnull NSDictionary<GADNativeAssetIdentifier, UIView *> *)clickableAssetViews
    nonclickableAssetViews:
        (nonnull NSDictionary<GADNativeAssetIdentifier, UIView *> *)nonclickableAssetViews
            viewController:(nonnull UIViewController *)viewController {
  [_nativeAd registerContainer:view withClickableViews:clickableAssetViews.allValues];
}

#pragma mark - PAGLNativeAdDelegate

- (void)adDidShow:(PAGLNativeAd *)ad {
  id<GADMediationNativeAdEventDelegate> delegate = _delegate;
  [delegate reportImpression];
}

- (void)adDidClick:(PAGLNativeAd *)ad {
  id<GADMediationNativeAdEventDelegate> delegate = _delegate;
  [delegate reportClick];
}

@end
