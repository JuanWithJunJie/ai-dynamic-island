import Foundation

enum LaunchMode: Equatable {
    case bundledApp
    case directExecutable
}

enum AppLaunchSupport {
    static func detectLaunchMode(bundleURL: URL = Bundle.main.bundleURL) -> LaunchMode {
        bundleURL.pathExtension == "app" ? .bundledApp : .directExecutable
    }

    static func shouldWarnForUnsupportedLaunchMode(_ mode: LaunchMode) -> Bool {
        mode == .directExecutable
    }

    static let unsupportedLaunchMessage = """
    MacIrland 本地开发需要以打包后的 .app 形态启动，这样菜单栏入口才能稳定显示。

    请在项目目录下运行：
    ./Scripts/run-dev-app.sh
    """
}
