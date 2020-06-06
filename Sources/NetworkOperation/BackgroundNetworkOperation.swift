//
//  BackgroundNetworkOperation.swift
//  NetworkOperation
//
//  Created by Damian Dudycz on 11/03/2018.
//  Copyright © 2018 Damian Dudycz. All rights reserved.
//

import Foundation
import HandyThings

/// Background download operation allows you to create download operations that will continue working when you app is in background or terminated by the system. When download finishes your app is waken or relaunched. If your app was relaunched you need to initialize BackgroundDownloadOperation again with the same URL to handle actions for downloaded file. If few operations are created with the same URL, only one actual download is performed and all operations operate on the same file. Downloaded files are stored in tmp directory. If file for given url already existed in tmp then finish block is executed right after starting operation.
///
// - important: If you use perform() then WebServiceBackgroundDownloadOperation will be keept alive by queue, so vars keeping reference to it can be weak.
public class BackgroundNetworkOperation: Operation {

    internal var task: URLSessionDownloadTask?

    private static var setupDone = false

    public private(set)  var error:   Error?
    public internal(set) var fileURL: URL? // Local file URL
    /// If file was already downloaded, then response will return nil.
    public var response: HTTPURLResponse? { task?.response as? HTTPURLResponse }

    private let request:             URLRequest
    private let finishBlock:         FinishBlock
    private let downloadObservation: ProgressObservation?

    private var url: URL {
        request.url!
    }

    public internal(set) var progress: Float = 0.0 {
        didSet { downloadObservation?(self, progress) }
    }

    internal static var registeredOperations = [(url: URL, operation: BackgroundNetworkOperation)]()
    
    internal static let queue   = DispatchQueue(label: DispatchQueueName.queue)
    private  static let session = URLSession(configuration: .background(withIdentifier: URLSessionIdentifier.session.rawValue), delegate: sessionDelegate, delegateQueue: nil)
    private static let sessionDelegate = BackgroundNetworkOperationSessionDelegate()

    internal static var tasks      = [URLSessionDownloadTask]()
    private  static var tasksReady = false {
        didSet {
            if tasksReady {
                guard tasksReady else { return }
                BackgroundNetworkOperation.queue.async {
                    operationsAwaitingTasksBeingReady.forEach { (operation) in
                        operation.beginTaskOrFinish()
                    }
                    operationsAwaitingTasksBeingReady.removeAll()
                }
            }
        }
    }
    private static var operationsAwaitingTasksBeingReady = [BackgroundNetworkOperation]()

    internal static let tmpDir = URL(filename: Directory.tmpDir, relativeTo: URL(fileURLWithPath: NSTemporaryDirectory()))!

    public init(request: URLRequest, dependencies: [Operation]? = nil, downloadObservation: ProgressObservation? = nil, finishBlock: @escaping FinishBlock) {

        BackgroundNetworkOperation.setup()

        self.request             = request
        self.finishBlock         = finishBlock
        self.downloadObservation = downloadObservation

        super.init()

        dependencies?.forEach { addDependency($0) }
    }

    /// Starts the operation without WebService.
    public static func perform(request: URLRequest, dependencies: [Operation]? = nil, downloadObservation: ProgressObservation? = nil, finishBlock: @escaping FinishBlock) -> BackgroundNetworkOperation {
        let operation = BackgroundNetworkOperation(request: request, dependencies: dependencies, downloadObservation: downloadObservation, finishBlock: finishBlock)
        defer { operation.start() }
        return operation
    }

    internal func taskDone(withError error: Error?) {
        self.error = error
        DispatchQueue.main.sync {
            if BackgroundNetworkOperation.tasks.count <= 1 {
                BackgroundNetworkOperation.session.reset { }
            }
            self.finishBlock(self)
        }
        operationExecuting = false
        operationFinished = true
    }

    // TODO: Sprawdzić poprawność tej klasy - czyszczenie cache i przywracanie operacji po ponownym uruchomieniu aplikacji.
    private static func setup() {

        guard !setupDone else { return }

        if !FileManager.default.fileExists(atPath: tmpDir.path, isDirectory: nil) {
            do { try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true, attributes: nil) }
            catch { print(error) }
        }

        clearTMPFiles()

        /// - NOTE: session.getAllTasks() causes very small leak when app launches and there are some tasks to resume.
        session.getAllTasks() { tasks in
            BackgroundNetworkOperation.queue.async {
                self.tasks = tasks.filter { $0.error == nil } as! [URLSessionDownloadTask]
                tasksReady = true
            }
        }

        let notificationCenter = NotificationCenter.default
        
        notificationCenter.addObserver(
            self,
            selector: #selector(clearTMPFiles),
            name:     .willTerminateNotification,
            object:   nil
        )

        notificationCenter.addObserver(
            self,
            selector: #selector(clearTMPFiles),
            name:     .significantTimeChangeNotification,
            object:   nil
        )

        setupDone = true
    }

    /// Removes files that are not assiociated with any tasks in progress. This function is performed automatically when app is terminating.
    @objc private static func clearTMPFiles() {
        if let files = try? FileManager.default.contentsOfDirectory(atPath: BackgroundNetworkOperation.tmpDir.path) {
            files.forEach {
                try? FileManager.default.removeItem(at: URL(string: $0, relativeTo: BackgroundNetworkOperation.tmpDir)!)
            }
        }
    }

    private func beginTaskOrFinish() {

        let localFileURL = BackgroundNetworkOperation.localFileURL(for: url)
        
        let localFilePath = localFileURL.path
        if FileManager.default.fileExists(atPath: localFilePath) {
            fileURL = localFileURL
            progress = 1.0
            taskDone(withError: nil)
            
            BackgroundNetworkOperation.registeredOperations = BackgroundNetworkOperation.registeredOperations.filter { (_, operation) in operation != self }
            
            return
        }
        
        if let task = BackgroundNetworkOperation.tasks.first(where: { $0.originalRequest?.url?.absoluteString == url.absoluteString && $0.state == .running }) {
            self.task = task
            if task.countOfBytesExpectedToReceive > 0 {
                progress = Float(task.countOfBytesReceived) / Float(task.countOfBytesExpectedToReceive)
            }
            return
        }

        let newTask = BackgroundNetworkOperation.session.downloadTask(with: request)
        self.task = newTask
        guard newTask.originalRequest != nil else {
            taskDone(withError: OperationError.failedToInitializeRequest)
            return
        }
        BackgroundNetworkOperation.tasks.append(newTask)
        newTask.resume()
    }

    // Operation subclass callers
    private var operationFinished = false {
        willSet { willChangeValue(for: \.isFinished) }
        didSet  { didChangeValue(for:  \.isFinished) }
    }
    private var operationExecuting = false {
        willSet { willChangeValue(for: \.isExecuting) }
        didSet  { didChangeValue(for:  \.isExecuting) }
    }
}

extension BackgroundNetworkOperation {
    
    // MARK: - Operation subclassing implementation.

    public override var isAsynchronous: Bool { true               }
    public override var isExecuting:    Bool { operationExecuting }
    public override var isFinished:     Bool { operationFinished  }

    public override func start() {
        operationExecuting = true

        BackgroundNetworkOperation.queue.sync {
            guard !isCancelled else { taskDone(withError: OperationError.operationWasCanceledBeforeStart); return }

            BackgroundNetworkOperation.registeredOperations.append((url: url, operation: self))
            if BackgroundNetworkOperation.tasksReady {
                beginTaskOrFinish()
            }
            else {
                BackgroundNetworkOperation.operationsAwaitingTasksBeingReady.append(self)
            }
        }
    }

    public override func cancel() {
        super.cancel()
        BackgroundNetworkOperation.queue.async {
            // Remove from registered operations.
            BackgroundNetworkOperation.registeredOperations = BackgroundNetworkOperation.registeredOperations.filter { (_, operation) in
                operation != self
            }
            // If there are no more operations with the same url, then cancel download.
            let similarOperationsExists = !BackgroundNetworkOperation.registeredOperations.filter { (url, operation) in
                url.absoluteString == self.url.absoluteString && operation != self
            }.isEmpty
            if !similarOperationsExists {
                BackgroundNetworkOperation.tasks.filter { $0.originalRequest?.url == self.url }.forEach {
                    $0.cancel()
                }
            }
        }
    }
    
}
