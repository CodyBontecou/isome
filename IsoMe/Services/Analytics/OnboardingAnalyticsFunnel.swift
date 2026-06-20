//
//  OnboardingAnalyticsFunnel.swift
//  IsoMe
//
//  Typed helpers for privacy-safe onboarding funnel instrumentation.
//

import Foundation

nonisolated struct OnboardingAnalyticsContext: Equatable, Sendable {
    let step: OnboardingAnalyticsStep?
    let authorizationStatus: OnboardingAnalyticsAuthorizationStatus?
    let trackingIntent: OnboardingAnalyticsTrackingIntent?

    init(
        step: OnboardingAnalyticsStep? = nil,
        authorizationStatus: OnboardingAnalyticsAuthorizationStatus? = nil,
        trackingIntent: OnboardingAnalyticsTrackingIntent? = nil
    ) {
        self.step = step
        self.authorizationStatus = authorizationStatus
        self.trackingIntent = trackingIntent
    }
}

extension OnboardingAnalyticsClient {
    func trackOnboardingStarted(
        step: OnboardingAnalyticsStep = .welcome,
        authorizationStatus: OnboardingAnalyticsAuthorizationStatus? = nil
    ) {
        track(OnboardingAnalyticsEvent(
            name: .onboardingStarted,
            properties: properties(
                step: step,
                authorizationStatus: authorizationStatus
            )
        ))
    }

    func trackOnboardingStepViewed(
        _ step: OnboardingAnalyticsStep,
        authorizationStatus: OnboardingAnalyticsAuthorizationStatus? = nil,
        trackingIntent: OnboardingAnalyticsTrackingIntent? = nil
    ) {
        track(OnboardingAnalyticsEvent(
            name: .onboardingStepViewed,
            properties: properties(
                step: step,
                authorizationStatus: authorizationStatus,
                trackingIntent: trackingIntent
            )
        ))
    }

    func trackLocationAuthorizationRequested(
        requestKind: OnboardingAnalyticsAuthorizationRequestKind,
        status: OnboardingAnalyticsAuthorizationStatus,
        step: OnboardingAnalyticsStep = .permissions
    ) {
        track(OnboardingAnalyticsEvent(
            name: .locationAuthorizationRequested,
            properties: properties(
                step: step,
                authorizationStatus: status,
                authorizationRequestKind: requestKind
            )
        ))
    }

    func trackLocationAuthorizationCompleted(
        status: OnboardingAnalyticsAuthorizationStatus,
        step: OnboardingAnalyticsStep = .permissions
    ) {
        track(OnboardingAnalyticsEvent(
            name: .locationAuthorizationCompleted,
            properties: properties(
                step: step,
                authorizationStatus: status
            )
        ))
    }

    func trackTrackingIntentChanged(
        intent: OnboardingAnalyticsTrackingIntent,
        authorizationStatus: OnboardingAnalyticsAuthorizationStatus,
        step: OnboardingAnalyticsStep = .ready
    ) {
        track(OnboardingAnalyticsEvent(
            name: .trackingIntentChanged,
            properties: properties(
                step: step,
                authorizationStatus: authorizationStatus,
                trackingIntent: intent
            )
        ))
    }

    func trackOnboardingCompleted(
        authorizationStatus: OnboardingAnalyticsAuthorizationStatus,
        trackingIntent: OnboardingAnalyticsTrackingIntent,
        step: OnboardingAnalyticsStep = .ready
    ) {
        track(OnboardingAnalyticsEvent(
            name: .onboardingCompleted,
            properties: properties(
                step: step,
                authorizationStatus: authorizationStatus,
                trackingIntent: trackingIntent
            )
        ))
    }

    func trackPaywallShown(context: OnboardingAnalyticsPaywallContext) {
        track(OnboardingAnalyticsEvent(
            name: .paywallShown,
            properties: properties(paywallContext: context)
        ))
    }

    func trackPurchaseStarted(
        context: OnboardingAnalyticsPaywallContext,
        productId: OnboardingAnalyticsProductID = .lifetimeUnlock
    ) {
        track(OnboardingAnalyticsEvent(
            name: .purchaseStarted,
            properties: properties(
                paywallContext: context,
                productId: productId,
                purchaseOutcome: .started
            )
        ))
    }

    func trackPurchaseFinished(
        outcome: OnboardingAnalyticsPurchaseOutcome,
        context: OnboardingAnalyticsPaywallContext,
        errorCategory: OnboardingAnalyticsErrorCategory? = nil,
        productId: OnboardingAnalyticsProductID = .lifetimeUnlock
    ) {
        track(OnboardingAnalyticsEvent(
            name: .purchaseFinished,
            properties: properties(
                paywallContext: context,
                productId: productId,
                purchaseOutcome: outcome,
                errorCategory: errorCategory
            )
        ))
    }

    func trackRestoreStarted(
        context: OnboardingAnalyticsPaywallContext,
        productId: OnboardingAnalyticsProductID = .lifetimeUnlock
    ) {
        track(OnboardingAnalyticsEvent(
            name: .restoreStarted,
            properties: properties(
                paywallContext: context,
                productId: productId,
                purchaseOutcome: .started
            )
        ))
    }

    func trackRestoreFinished(
        outcome: OnboardingAnalyticsPurchaseOutcome,
        context: OnboardingAnalyticsPaywallContext,
        errorCategory: OnboardingAnalyticsErrorCategory? = nil,
        productId: OnboardingAnalyticsProductID = .lifetimeUnlock
    ) {
        track(OnboardingAnalyticsEvent(
            name: .restoreFinished,
            properties: properties(
                paywallContext: context,
                productId: productId,
                purchaseOutcome: outcome,
                errorCategory: errorCategory
            )
        ))
    }

    private func properties(
        step: OnboardingAnalyticsStep? = nil,
        authorizationStatus: OnboardingAnalyticsAuthorizationStatus? = nil,
        authorizationRequestKind: OnboardingAnalyticsAuthorizationRequestKind? = nil,
        trackingIntent: OnboardingAnalyticsTrackingIntent? = nil,
        paywallContext: OnboardingAnalyticsPaywallContext? = nil,
        productId: OnboardingAnalyticsProductID? = nil,
        purchaseOutcome: OnboardingAnalyticsPurchaseOutcome? = nil,
        errorCategory: OnboardingAnalyticsErrorCategory? = nil,
        bundle: Bundle = .main
    ) -> OnboardingAnalyticsProperties {
        OnboardingAnalyticsProperties(
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            buildNumber: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
            platform: .iOS,
            onboardingStep: step,
            authorizationStatus: authorizationStatus,
            authorizationRequestKind: authorizationRequestKind,
            trackingIntent: trackingIntent,
            paywallContext: paywallContext,
            productId: productId,
            purchaseOutcome: purchaseOutcome,
            errorCategory: errorCategory
        )
    }
}
