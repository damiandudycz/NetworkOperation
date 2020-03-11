//
//  OperationError.swift
//  NetworkOperation
//
//  Created by Damian Dudycz on 28.09.2018.
//  Copyright © 2018 Damian Dudycz. All rights reserved.
//

import Foundation

public extension BackgroundNetworkOperation {
    enum OperationError: Error {
        case operationWasCanceledBeforeStart
        case startingConditionFailed
        case failedToInitializeRequest
        case noResponse
    }
}
