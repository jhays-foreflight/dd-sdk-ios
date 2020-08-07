/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation
import class UIKit.UIViewController

internal class RUMSessionScope: RUMScope, RUMContextProvider {
    struct Constants {
        /// If no interaction is registered within this period, a new session is started.
        static let sessionTimeoutDuration: TimeInterval = 15 * 60 // 15 minutes
        /// Maximum duration of a session. If it gets exceeded, a new session is started.
        static let sessionMaxDuration: TimeInterval = 4 * 60 * 60 // 4 hours
    }

    // MARK: - Child Scopes

    /// Active View scopes. Scopes are added / removed when the View starts / stops displaying.
    private(set) var viewScopes: [RUMViewScope] = []

    // MARK: - Initialization

    unowned let parent: RUMContextProvider
    private let dependencies: RUMScopeDependencies

    /// This Session UUID.
    let sessionUUID: RUMUUID
    /// The start time of this Session.
    private let sessionStartTime: Date
    /// Time of the last RUM interaction noticed by this Session.
    private var lastInteractionTime: Date

    init(
        parent: RUMContextProvider,
        dependencies: RUMScopeDependencies,
        startTime: Date
    ) {
        self.parent = parent
        self.dependencies = dependencies
        self.sessionUUID = dependencies.rumUUIDGenerator.generateUnique()
        self.sessionStartTime = startTime
        self.lastInteractionTime = startTime
    }

    /// Creates a new Session upon expiration of the previous one.
    convenience init(
        from expiredSession: RUMSessionScope,
        startTime: Date
    ) {
        self.init(
            parent: expiredSession.parent,
            dependencies: expiredSession.dependencies,
            startTime: startTime
        )

        // Transfer active Views by creating new `RUMViewScopes` for their identity objects:
        self.viewScopes = expiredSession.viewScopes.compactMap { expiredView in
            guard let expiredViewIdentity = expiredView.identity else {
                return nil // if the underlying `UIVIewController` no longer exists, skip transferring its scope
            }
            guard (expiredViewIdentity as? UIViewController)?.view?.window != nil else {
                return nil // TODO: RUMM-634 Produce a RUM error when the VC is leaked
            }
            return RUMViewScope(
                parent: self,
                dependencies: dependencies,
                identity: expiredViewIdentity,
                attributes: expiredView.attributes,
                startTime: startTime
            )
        }
    }

    // MARK: - RUMContextProvider

    var context: RUMContext {
        var context = parent.context
        context.sessionID = sessionUUID
        return context
    }

    // MARK: - RUMScope

    func process(command: RUMCommand) -> Bool {
        if timedOutOrExpired(currentTime: command.time) {
            return false // no longer keep this session
        }
        lastInteractionTime = command.time

        // Apply side effects
        switch command {
        case let command as RUMStartViewCommand:
            startView(on: command)
        default:
            break
        }

        // Propagate command
        viewScopes = manage(childScopes: viewScopes, byPropagatingCommand: command)

        return true
    }

    // MARK: - RUMCommands Processing

    private func startView(on command: RUMStartViewCommand) {
        viewScopes.append(
            RUMViewScope(
                parent: self,
                dependencies: dependencies,
                identity: command.identity,
                attributes: command.attributes,
                startTime: command.time
            )
        )
    }

    // MARK: - Private

    private func timedOutOrExpired(currentTime: Date) -> Bool {
        let timeElapsedSinceLastInteraction = currentTime.timeIntervalSince(lastInteractionTime)
        let timedOut = timeElapsedSinceLastInteraction >= Constants.sessionTimeoutDuration

        let sessionDuration = currentTime.timeIntervalSince(sessionStartTime)
        let expired = sessionDuration >= Constants.sessionMaxDuration

        return timedOut || expired
    }
}
