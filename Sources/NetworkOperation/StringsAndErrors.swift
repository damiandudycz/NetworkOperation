//
//  StringsAndErrors.swift
//  NetworkOperation
//
//  Created by Damian Dudycz on 14/08/2018.
//  Copyright © 2018 Damian Dudycz. All rights reserved.
//

import Foundation

extension BackgroundNetworkOperation {
    
    enum Directory: String {
        case tmpDir = "BackgroundNetworkOperation"
    }
    
    enum URLString: String {
        case localFilesForURLs = "BackgroundNetworkOperation.LocalFilesForURLs"
    }
    
    enum DispatchQueueName: String {
        case queue = "BackgroundNetworkOperation.Queue"
    }
    
    enum URLSessionIdentifier: String {
        case session = "BackgroundNetworkOperation.Session"
    }
    
}
