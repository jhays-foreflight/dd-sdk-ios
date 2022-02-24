/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation

public struct Batch {
    public let data: Data
    /// File from which `data` was read.
    let file: ReadableFile
}

/// A type, reading batched data.
public protocol Reader {
    func readNextBatch() -> Batch?
    func markBatchAsRead(_ batch: Batch)
}

/// Reader performing reads synchronously on a given queue.
public protocol SyncReader: Reader {
    /// Queue used for synchronous reads.
    var queue: DispatchQueue { get }
}
