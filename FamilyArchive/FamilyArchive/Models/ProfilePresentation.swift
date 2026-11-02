//
//  ProfilePresentation.swift
//  FamilyArchive
//
//  Pure rules for the 个人 page.
//

import Foundation

enum ProfileLayout {
    /// 家族卡片一行最多 4 个，宽度由 LazyVGrid 均分。
    static func familyColumns(for count: Int) -> Int {
        min(4, max(1, count))
    }
}

enum ProfileAccounts {
    /// 个人页的账号入口聚合 动态 / 影视 / 音乐 全部账号，按添加时间倒序。
    static func all(_ accounts: [Account]) -> [Account] {
        accounts.sorted { $0.createdAt > $1.createdAt }
    }
}
