// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "GADMediationAdapterPangle.h"
#import "GADMediationAdapterPangleConstants.h"
#import <BUAdSDK/BUAdSDK.h>
#import "GADPangleRTBBannerRenderer.h"
#import "GADPangleRTBInterstitialRenderer.h"
#import "GADPangleRTBRewardedRenderer.h"
#import "GADMediationAdapterPangleConstants.h"
#import "GADMAdapterPangleUtils.h"

static NSInteger _coppa = -1,_gdpr = -1, _ccpa = -1;

@implementation GADMediationAdapterPangle {
    /// Pangle banner ad wrapper.
    GADPangleRTBBannerRenderer *_bannerRenderer;
    /// Pangle interstitial ad wrapper.
    GADPangleRTBInterstitialRenderer *_interstitialRenderer;
    /// Pangle rewarded ad wrapper.
    GADPangleRTBRewardedRenderer *_rewardedRenderer;
}

- (void)collectSignalsForRequestParameters:(nonnull GADRTBRequestParameters *)params
                         completionHandler:(nonnull GADRTBSignalCompletionHandler)completionHandler {
    NSString *signals = [BUAdSDKManager getBiddingToken:nil];
    if (completionHandler) {
        completionHandler(signals,nil);
    }
}

+ (void)setUpWithConfiguration:(nonnull GADMediationServerConfiguration *)configuration
             completionHandler:(nonnull GADMediationAdapterSetUpCompletionBlock)completionHandler {
    NSMutableSet *appIds = [[NSMutableSet alloc]init];
    for (GADMediationCredentials *cred in configuration.credentials) {
        NSString *appId = cred.settings[GADMAdapterPangleAppID];
        GADMAdapterPangleMutableSetAddObject(appIds, appId);
    }
    
    if (appIds.count < 1) {
        NSError *error = GADMAdapterPangleErrorWithCodeAndDescription(GADPangleErrorInvalidServerParameters, @"Pangle mediation configurations did not contain a valid App ID.");
        completionHandler(error);
        return;
    }
    
    NSString *appID = [appIds anyObject];
    if (appIds.count > 1) {
        PangleLog(@"Found the following App IDs:%@. Please remove any app IDs which you are not using", appIds);
        PangleLog(@"Configuring Pangle SDK with the app ID:%@", appID);
    }
    
    BUAdSDKConfiguration *sdkConfiguration = [BUAdSDKConfiguration configuration];
    sdkConfiguration.territory = BUAdSDKTerritory_NO_CN;
    sdkConfiguration.appID = appID;
    sdkConfiguration.coppa = @(_coppa);
    sdkConfiguration.GDPR = @(_gdpr);
    sdkConfiguration.CCPA = @(_ccpa);
    [BUAdSDKManager startWithAsyncCompletionHandler:^(BOOL success, NSError *error) {
        completionHandler(error);
    }];
}

+ (GADVersionNumber)adSDKVersion {
    NSString *versionString = BUAdSDKManager.SDKVersion;
    NSArray *versionComponents = [versionString componentsSeparatedByString:@"."];
    GADVersionNumber version = {0};
    if (versionComponents.count == 4) {
        version.majorVersion = [versionComponents[0] integerValue];
        version.minorVersion = [versionComponents[1] integerValue];
        version.patchVersion = [versionComponents[2] integerValue] * 100 + [versionComponents[3] integerValue];
    }else {
        PangleLog(@"Unexpected version string: %@. Returning 0 for adSDKVersion.", versionString);
    }
    return version;
}

+ (GADVersionNumber)adapterVersion {
    GADVersionNumber version = {0};
    NSArray<NSString *> *components = [GADMAdapterPangleVersion componentsSeparatedByString:@"."];
    if (components.count >= 4) {
        version.majorVersion = components[0].integerValue;
        version.minorVersion = components[1].integerValue;
        version.patchVersion = components[2].integerValue * 100 + components[3].integerValue;
        if (components.count >= 5) {
            version.patchVersion = version.patchVersion * 100 + components[4].integerValue;
        }
    }
    return version;
}

+ (nullable Class<GADAdNetworkExtras>)networkExtrasClass {
  // TODO: Return the class for passng in mediation extras (if any). Else, return `Nil`.
  return Nil;
}

- (void)loadBannerForAdConfiguration:(GADMediationBannerAdConfiguration *)adConfiguration
                   completionHandler:(GADMediationBannerLoadCompletionHandler)completionHandler {
    if (adConfiguration.childDirectedTreatment) {
        [GADMediationAdapterPangle setCoppa:adConfiguration.childDirectedTreatment.integerValue];
    }
    _bannerRenderer = [[GADPangleRTBBannerRenderer alloc] init];
    [_bannerRenderer renderBannerForAdConfiguration:adConfiguration completionHandler:completionHandler];
}

- (void)loadInterstitialForAdConfiguration:(GADMediationInterstitialAdConfiguration *)adConfiguration
                         completionHandler:(GADMediationInterstitialLoadCompletionHandler)completionHandler {
    if (adConfiguration.childDirectedTreatment) {
        [GADMediationAdapterPangle setCoppa:adConfiguration.childDirectedTreatment.integerValue];
    }
    _interstitialRenderer = [[GADPangleRTBInterstitialRenderer alloc] init];
    [_interstitialRenderer renderInterstitialForAdConfiguration:adConfiguration completionHandler:completionHandler];
}

- (void)loadRewardedAdForAdConfiguration:(GADMediationRewardedAdConfiguration *)adConfiguration
                       completionHandler:(GADMediationRewardedLoadCompletionHandler)completionHandler {
    if (adConfiguration.childDirectedTreatment) {
        [GADMediationAdapterPangle setCoppa:adConfiguration.childDirectedTreatment.integerValue];
    }
    _rewardedRenderer = [[GADPangleRTBRewardedRenderer alloc] init];
    [_rewardedRenderer renderRewardedAdForAdConfiguration:adConfiguration completionHandler:completionHandler];
}

+ (void)setCoppa:(NSInteger)coppa {
    if (coppa != 0 && coppa != 1 && coppa != -1) {
        PangleLog(@"Invalid COPPA value. Pangle SDK only accepts -1, 0 or 1.");
        return;
    }
    if (BUAdSDKManager.initializationState == BUAdSDKInitializationStateReady) {
        [BUAdSDKManager setCoppa:coppa];
    }
    _coppa = coppa;
}

+ (void)setGDPR:(NSInteger)GDPR {
    if (GDPR != 0 && GDPR != 1 && GDPR != -1) {
        PangleLog(@"Invalid GDPR value. Pangle SDK only accepts -1, 0 or 1.");
        return;
    }
    if (BUAdSDKManager.initializationState == BUAdSDKInitializationStateReady) {
        [BUAdSDKManager setGDPR:GDPR];
    }
    _gdpr = GDPR;
}

+ (void)setCCPA:(NSInteger)CCPA {
    if (CCPA != 0 && CCPA != 1 && CCPA != -1) {
        PangleLog(@"Invalid CCPA value. Pangle SDK only accepts -1, 0 or 1.");
        return;
    }
    if (BUAdSDKManager.initializationState == BUAdSDKInitializationStateReady) {
        [BUAdSDKManager setCCPA:CCPA];
    }
    _ccpa = CCPA;
}

@end
