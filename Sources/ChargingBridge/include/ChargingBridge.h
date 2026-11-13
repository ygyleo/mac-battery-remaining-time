#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, BTChargeMode) {
    BTChargeModeOptimized = 1,
    BTChargeModeLimit = 2,
};

FOUNDATION_EXPORT NSErrorDomain const BTChargingErrorDomain;

@interface BTChargingState : NSObject
@property(nonatomic, readonly) BOOL supportsOptimizedCharging;
@property(nonatomic, readonly) BOOL supportsManualLimit;
@property(nonatomic, readonly) BOOL optimizedOverrideAllowed;
@property(nonatomic, readonly) BOOL manualLimitEnabled;
@property(nonatomic, readonly) NSUInteger manualLimit;
- (instancetype)initWithSupportsOptimizedCharging:(BOOL)supportsOptimizedCharging
                             supportsManualLimit:(BOOL)supportsManualLimit
                        optimizedOverrideAllowed:(BOOL)optimizedOverrideAllowed
                              manualLimitEnabled:(BOOL)manualLimitEnabled
                                     manualLimit:(NSUInteger)manualLimit;
@end

/// Runtime-checked access to macOS's native one-time charging actions.
/// The default initializer does not load PowerUI until the first state read.
@interface BTChargingClient : NSObject
- (instancetype)init;
/// Dependency injection: this initializer never loads the system framework.
- (instancetype)initWithClient:(NSObject *)client NS_SWIFT_NAME(init(client:));
- (nullable BTChargingState *)readStateWithError:(NSError **)error NS_SWIFT_NAME(readState());
/// Rechecks system state before sending exactly one request. For manual limits,
/// expectedLimit must still match the limit the user saw when opening the menu.
- (BOOL)requestMode:(BTChargeMode)mode expectedLimit:(NSUInteger)expectedLimit
             error:(NSError **)error NS_SWIFT_NAME(request(mode:expectedLimit:));
@end

NS_ASSUME_NONNULL_END
