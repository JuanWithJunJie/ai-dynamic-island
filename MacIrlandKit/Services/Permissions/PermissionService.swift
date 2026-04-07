import AppKit
import Foundation

public protocol PermissionProviding: Sendable {
    func currentStatus() -> CapabilityStatus
}

public struct PlaceholderPermissionService: PermissionProviding {
    public init() {}

    public func currentStatus() -> CapabilityStatus {
        CapabilityStatus(
            accessibilityGranted: false,
            localOnlyProcessing: true,
            explanation: "MVP 骨架阶段尚未接入辅助功能权限检测，当前采用本地 mock 数据。",
            observationBlocked: false
        )
    }
}

public struct AutomationPermissionService: PermissionProviding {
    public init() {}

    public func currentStatus() -> CapabilityStatus {
        status(terminalAppsDetected: Self.areSupportedTerminalAppsRunning(), observationBlocked: false)
    }

    func status(terminalAppsDetected: Bool, observationBlocked: Bool) -> CapabilityStatus {
        let explanation: String
        if observationBlocked {
            explanation = "已检测到 Terminal / iTerm 正在运行，但当前无法可靠读取会话内容。请确认系统已允许 MacIrland 通过 Apple Events 访问终端应用，然后点击刷新重试。"
        } else if terminalAppsDetected {
            explanation = "已启用真实终端会话发现：当前会尝试通过 Apple Events 读取 Terminal / iTerm 中的 Claude Code 会话；若系统未授权自动化权限，结果会为空。"
        } else {
            explanation = "已启用真实终端会话发现：请先在 Terminal 或 iTerm 中启动 Claude Code 会话；当前仍未接入真实 reply bridge。"
        }

        return CapabilityStatus(
            accessibilityGranted: false,
            localOnlyProcessing: true,
            explanation: explanation,
            observationBlocked: observationBlocked
        )
    }

    static func areSupportedTerminalAppsRunning() -> Bool {
        let terminalRunning = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Terminal").isEmpty == false
        let iTermRunning = NSRunningApplication.runningApplications(withBundleIdentifier: "com.googlecode.iterm2").isEmpty == false
        return terminalRunning || iTermRunning
    }
}
