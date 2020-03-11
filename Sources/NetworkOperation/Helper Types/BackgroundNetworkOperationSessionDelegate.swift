//
//  BackgroundNetworkOperationSessionDelegate.swift
//  NetworkOperation
//
//  Created by Damian Dudycz on 28.09.2018.
//  Copyright © 2018 Damian Dudycz. All rights reserved.
//

import Foundation
import CommonCrypto

extension BackgroundNetworkOperation {
    // MARK: - Helper types.
    
    public static func localFileURL(for url: URL) -> URL {
        let tmpFileName = url.absoluteString.sha256
        return URL(string: tmpFileName, relativeTo: BackgroundNetworkOperation.tmpDir)!
    }
    
    internal class BackgroundNetworkOperationSessionDelegate: NSObject, URLSessionDelegate, URLSessionDownloadDelegate {
        func cleanOperations(forURL url: URL) {
            registeredOperations = registeredOperations.filter { $0.url.absoluteString != url.absoluteString }
        }
        
        func cleanTasksArray(fromTask task: URLSessionDownloadTask) {
            if let index = BackgroundNetworkOperation.tasks.firstIndex(of: task) {
                BackgroundNetworkOperation.tasks.remove(at: index)
            }
        }
        
        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
            guard let requestURL = downloadTask.originalRequest?.url else { return }
            let tmpFileURL = BackgroundNetworkOperation.localFileURL(for: requestURL)
            
            // Move file to tmp directory.
            let waitingOperations = registeredOperations.filter { $0.url.absoluteString == requestURL.absoluteString }
            do {
                if FileManager.default.fileExists(atPath: tmpFileURL.path) { try FileManager.default.removeItem(at: tmpFileURL) }
                try FileManager.default.moveItem(at: location, to: tmpFileURL)
                waitingOperations.forEach {
                    $0.operation.fileURL = tmpFileURL
                    $0.operation.taskDone(withError: nil)
                }
            }
            catch {
                waitingOperations.forEach {
                    $0.operation.taskDone(withError: error)
                }
                print(error)
            }
            
            cleanTasksArray(fromTask: downloadTask)
        }
        
        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            guard let url = task.originalRequest?.url else { return }
            if let error = error {
                BackgroundNetworkOperation.queue.sync {
                    let waitingOperations = registeredOperations.filter { $0.operation.task == task }
                    waitingOperations.forEach { $0.operation.taskDone(withError: error) }
                }
            }
            cleanOperations(forURL: url)
            cleanTasksArray(fromTask: task as! URLSessionDownloadTask)
        }
        
        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
            let waitingOperations = registeredOperations.filter { $0.operation.task == downloadTask }
            if totalBytesExpectedToWrite > 0 {
                let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
                waitingOperations.forEach { $0.operation.progress = progress }
            }
        }
    }
}

extension String {
    
    fileprivate var sha256: String {
        let stringData = data(using: .utf8)!
        let digest = self.digest(input: stringData)
        let sha256String = digest.map({ String(format: "%02x", UInt8($0)) }).joined()
        return sha256String
    }

    private func digest(input : Data) -> Data {
        let digestLength = Int(CC_SHA256_DIGEST_LENGTH)
        var hash = [UInt8](repeating: 0, count: digestLength)
        CC_SHA256([UInt8](input), UInt32(input.count), &hash)
        return Data(bytes: hash, count: digestLength)
    }
    
}
