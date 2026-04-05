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
            explanation: "MVP 骨架阶段尚未接入辅助功能权限检测，当前采用本地 mock 数据。"
        )
    }
}
