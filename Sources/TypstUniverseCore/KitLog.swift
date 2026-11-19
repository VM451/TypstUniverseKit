import Foundation
import OSLog

enum KitLog {
    static let storage = Logger(subsystem: "dev.typstuniversekit", category: "storage")
    static let registry = Logger(subsystem: "dev.typstuniversekit", category: "registry")
    static let ui = Logger(subsystem: "dev.typstuniversekit", category: "ui")
}
