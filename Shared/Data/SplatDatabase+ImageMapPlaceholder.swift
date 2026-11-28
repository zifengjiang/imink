import Foundation
import GRDB
import SplatDatabase

extension SplatDatabase {
    /// 素材表占位行 id：`getImageId(...)` 找不到素材时返回 `0`。
    static let unknownImageMapId: UInt16 = 0

    /// 保证 `imageMap` 里存在 id = 0 的占位行。
    ///
    /// 为什么需要：
    /// - `imageMap` 的 id 从 1 开始，从不包含 0；
    /// - 实际插入路径里 `weapon.imageMapId`、`coop.stageId`、`player.uniformId`
    ///   都是 `REFERENCES imageMap(id)` 的外键，而 GRDB 默认开着 `PRAGMA foreign_keys`；
    /// - 玩家打到「App 素材包里还没有的新武器 / 新场景 / 新横纲」时，`getImageId(...)`
    ///   会返回 0，于是整条（乃至整批）insert 以
    ///   `SQLite error 19: FOREIGN KEY constraint failed` 回滚。
    ///
    /// 结果就是：同步提示「加载了 N 条新记录」，但库里一行都没多。
    /// 插入前补一行占位记录，可以让未知素材退化成「显示 Unknown」，而不是丢掉整批记录。
    func ensureUnknownImageMapRow() throws {
        let nameId = Data("Unknown-0".utf8).base64EncodedString()
        try dbQueue.write { db in
            try db.execute(
                sql: """
                    INSERT OR IGNORE INTO imageMap (id, nameId, hash, name)
                    VALUES (?, ?, ?, ?)
                    """,
                arguments: [Self.unknownImageMapId, nameId, "unknown-0", "Unknown"]
            )
        }
    }
}
