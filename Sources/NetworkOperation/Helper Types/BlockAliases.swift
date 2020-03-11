//
//  BlockAliases.swift
//  NetworkOperation
//
//  Created by Damian Dudycz on 28.09.2018.
//  Copyright © 2018 Damian Dudycz. All rights reserved.
//

import Foundation

public extension BackgroundNetworkOperation {
    typealias ProgressObservation = (_ operation: BackgroundNetworkOperation, _ progress: Float) -> Void
    typealias FinishBlock = (_ operation: BackgroundNetworkOperation) -> Void
}
