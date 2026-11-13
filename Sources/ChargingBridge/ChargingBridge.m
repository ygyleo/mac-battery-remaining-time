#import "ChargingBridge.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import <dlfcn.h>

NSErrorDomain const BTChargingErrorDomain = @"io.github.ygyleo.BatteryTime.Charging";

@implementation BTChargingState
- (instancetype)initWithSupportsOptimizedCharging:(BOOL)optimized supportsManualLimit:(BOOL)manual
                        optimizedOverrideAllowed:(BOOL)allowed manualLimitEnabled:(BOOL)enabled
                                     manualLimit:(NSUInteger)limit {
    if ((self = [super init])) {
        _supportsOptimizedCharging = optimized; _supportsManualLimit = manual;
        _optimizedOverrideAllowed = allowed; _manualLimitEnabled = enabled; _manualLimit = limit;
    }
    return self;
}
@end

static NSError *BTError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:BTChargingErrorDomain code:code
                          userInfo:@{NSLocalizedDescriptionKey: message}];
}

// Check each argument independently, rather than relying on architecture-specific
// stack offsets in a full method encoding. No unverified IMP is called.
static BOOL BTMatches(Class cls, SEL selector, const char *result, NSArray<NSString *> *arguments) {
    Method method = class_getInstanceMethod(cls, selector);
    if (!method || method_getNumberOfArguments(method) != arguments.count + 2) return NO;
    char *actualResult = method_copyReturnType(method);
    BOOL matches = actualResult && strcmp(actualResult, result) == 0;
    free(actualResult);
    NSArray *allArguments = [@[@"@", @":"] arrayByAddingObjectsFromArray:arguments];
    for (NSUInteger index = 0; matches && index < allArguments.count; index++) {
        char *actual = method_copyArgumentType(method, (unsigned int)index);
        matches = actual && strcmp(actual, [allArguments[index] UTF8String]) == 0;
        free(actual);
    }
    return matches;
}

@implementation BTChargingClient {
    NSObject *_client;
    BOOL _injected;
    void *_frameworkHandle;
}

- (instancetype)init { return [super init]; }

- (instancetype)initWithClient:(NSObject *)client {
    if ((self = [super init])) { _client = client; _injected = YES; }
    return self;
}

- (BOOL)prepareWithError:(NSError **)error {
    if (_client) return YES;
#if defined(__arm64__)
    // Retain the framework handle for process lifetime: its Objective-C classes
    // and method implementations may still be referenced by the runtime.
    if (!_frameworkHandle) _frameworkHandle = dlopen(
        "/System/Library/PrivateFrameworks/PowerUI.framework/PowerUI", RTLD_LAZY | RTLD_LOCAL);
    Class cls = _frameworkHandle ? NSClassFromString(@"PowerUISmartChargeClient") : Nil;
    SEL initializer = NSSelectorFromString(@"initWithClientName:");
    if (cls && [cls isSubclassOfClass:NSObject.class] && BTMatches(cls, initializer, "@", @[@"@"])) {
        _client = ((id (*)(id, SEL, id))objc_msgSend)([cls alloc], initializer, @"Battery Time");
        if (_client) return YES;
    }
#endif
    if (error) *error = BTError(1, @"Native charging controls are unavailable on this macOS version.");
    return NO;
}

- (BTChargingState *)readStateWithError:(NSError **)error {
    if (![self prepareWithError:error]) return nil;
    Class cls = _client.class;
    SEL ui = NSSelectorFromString(@"smartChargingUIState:chargeLimit:chargingOverrideAllowed:withError:");
    SEL legacy = NSSelectorFromString(@"isOBCEngaged:asDesktopDevice:chargingOverrideAllowed:withError:");
    SEL optimizedAction = NSSelectorFromString(@"temporarilyEnableCharging:");
    BOOL actionAvailable = BTMatches(cls, optimizedAction, "B", @[@"^@"]);
    BOOL modernQuery = BTMatches(cls, ui, "B", @[@"^Q", @"^Q", @"^B", @"^@"]);
    BOOL legacyQuery = BTMatches(cls, legacy, "B", @[@"^B", @"^B", @"^B", @"^@"]);
    BOOL optimizedSupported = actionAvailable && (modernQuery || legacyQuery);
    BOOL overrideAllowed = NO;
    NSError *queryError = nil;
    if (optimizedSupported) {
        BOOL success;
        if (modernQuery) {
            NSUInteger state = 0, limit = 0;
            success = ((BOOL (*)(id, SEL, NSUInteger *, NSUInteger *, BOOL *, NSError **))objc_msgSend)(
                _client, ui, &state, &limit, &overrideAllowed, &queryError);
        } else {
            BOOL engaged = NO, desktop = NO;
            success = ((BOOL (*)(id, SEL, BOOL *, BOOL *, BOOL *, NSError **))objc_msgSend)(
                _client, legacy, &engaged, &desktop, &overrideAllowed, &queryError);
            overrideAllowed = overrideAllowed && engaged;
        }
        if (!success || queryError) {
            if (error) *error = queryError ?: BTError(2, @"Could not read optimized charging state.");
            return nil;
        }
    }
    BOOL manualPlatform = _injected;
    if (@available(macOS 26.4, *)) manualPlatform = YES;
    SEL supported = NSSelectorFromString(@"isMCLSupported");
    SEL enabled = NSSelectorFromString(@"isMCLCurrentlyEnabled:");
    SEL limit = NSSelectorFromString(@"getMCLLimitWithError:");
    SEL manualAction = NSSelectorFromString(@"temporarilyDisableMCL:");
    BOOL manualSupported = manualPlatform && BTMatches(cls, supported, "B", @[]) &&
        BTMatches(cls, enabled, "Q", @[@"^@"]) && BTMatches(cls, limit, "C", @[@"^@"]) &&
        BTMatches(cls, manualAction, "B", @[@"^@"]);
    if (manualSupported) manualSupported = ((BOOL (*)(id, SEL))objc_msgSend)(_client, supported);
    BOOL manualEnabled = NO;
    NSUInteger manualLimit = 100;
    if (manualSupported) {
        NSUInteger raw = ((NSUInteger (*)(id, SEL, NSError **))objc_msgSend)(_client, enabled, &queryError);
        if (queryError) { if (error) *error = queryError; return nil; }
        manualLimit = ((unsigned char (*)(id, SEL, NSError **))objc_msgSend)(_client, limit, &queryError);
        if (queryError) { if (error) *error = queryError; return nil; }
        // Unknown private enum values are never interpreted as permission.
        manualEnabled = raw == 1;
    }
    if (!optimizedSupported && !manualSupported) {
        if (error) *error = BTError(1, @"Native charging controls have an unsupported interface.");
        return nil;
    }
    return [[BTChargingState alloc] initWithSupportsOptimizedCharging:optimizedSupported
        supportsManualLimit:manualSupported optimizedOverrideAllowed:overrideAllowed
        manualLimitEnabled:manualEnabled manualLimit:manualLimit];
}

- (BOOL)requestMode:(BTChargeMode)mode expectedLimit:(NSUInteger)expectedLimit error:(NSError **)error {
    BTChargingState *state = [self readStateWithError:error];
    if (!state) return NO;
    SEL action = NULL;
    if (mode == BTChargeModeOptimized && state.supportsOptimizedCharging &&
        state.optimizedOverrideAllowed && !state.manualLimitEnabled) {
        action = NSSelectorFromString(@"temporarilyEnableCharging:");
    } else if (mode == BTChargeModeLimit && state.supportsManualLimit && state.manualLimitEnabled &&
               state.manualLimit >= 80 && state.manualLimit < 100 && state.manualLimit == expectedLimit) {
        action = NSSelectorFromString(@"temporarilyDisableMCL:");
    }
    if (!action || !BTMatches(_client.class, action, "B", @[@"^@"])) {
        if (error) *error = BTError(3, @"Charging protection changed. Reopen the battery menu and try again.");
        return NO;
    }
    NSError *requestError = nil;
    BOOL success = ((BOOL (*)(id, SEL, NSError **))objc_msgSend)(_client, action, &requestError);
    if (!success || requestError) {
        if (error) *error = requestError ?: BTError(4, @"macOS did not accept the charging request.");
        return NO;
    }
    return YES;
}
@end
