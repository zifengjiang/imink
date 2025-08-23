//
//  TaskManager.swift
//  imink
//
//  Created by zifeng on 2025/8/10.
//
import Foundation
import Combine
import UIKit

extension Duration {
    static let defaultInterval: Duration = .seconds(300)
}

@MainActor
final class TaskManager: ObservableObject {
    static let shared = TaskManager()
    private var tasks: [UUID: Task<Void, Never>] = [:]
    private var names: [String: Set<UUID>] = [:]
    private var backgroundTasks: Set<String> = [] // 记录允许后台运行的任务名称
    private var cancellables: Set<AnyCancellable> = []

    private init() {
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .merge(with: NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.cancelForegroundTasks() }
            .store(in: &cancellables)
    }

    @discardableResult
    func startLoop(name: String,
                   immediately: Bool = true,
                   interval: Duration,
                   allowBackground: Bool = false,
                   _ body: @escaping @Sendable () async -> Void) -> UUID {
        if allowBackground {
            backgroundTasks.insert(name)
        }
        return start(named: name) {
            if immediately { await body() }
            while !Task.isCancelled {
                do { try await Task.sleep(for: interval) } catch { break }
                await body()
            }
        }
    }

    @discardableResult
    func start(named name: String? = nil,
               _ op: @escaping @Sendable () async -> Void) -> UUID {
        self.cancel(name: name ?? "default")
        let id = UUID()
        let task = Task { await op() }
        tasks[id] = task
        if let name { names[name, default: []].insert(id) }
        Task { [weak self] in
            _ = await task.value
            self?.remove(id: id)
        }
        return id
    }

    func cancel(name: String) {
        guard let ids = names[name] else { return }
        ids.forEach { cancel(id: $0) }
        names[name] = nil
        backgroundTasks.remove(name)
    }
    
    func cancelAll() { 
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
        names.removeAll()
        backgroundTasks.removeAll()
    }
    
    // 只取消前台任务，保留后台任务
    private func cancelForegroundTasks() {
        let foregroundTaskNames = Set(names.keys).subtracting(backgroundTasks)
        for taskName in foregroundTaskNames {
            cancel(name: taskName)
        }
    }
    
    private func cancel(id: UUID) { tasks[id]?.cancel(); tasks[id] = nil }
    private func remove(id: UUID) { tasks[id] = nil }
}
