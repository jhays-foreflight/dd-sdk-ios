/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation

/// Current `RUMContext` provider.
internal class RUMCurrentContext: RUMContextProvider {
    private let applicationScope: RUMApplicationScope

    init(applicationScope: RUMApplicationScope) {
        self.applicationScope = applicationScope
    }

    // MARK: - RUMContextProvider

    var context: RUMContext {
        activeViewContext ?? sessionContext ?? applicationContext
    }

    // MARK: - Private

    private var applicationContext: RUMContext {
        applicationScope.context
    }

    private var sessionContext: RUMContext? {
        applicationScope.sessionScope?.context
    }

    private var activeViewContext: RUMContext? {
        applicationScope.sessionScope?.viewScopes.last?.context
    }
}
