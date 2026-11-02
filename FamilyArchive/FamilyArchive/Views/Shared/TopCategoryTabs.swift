//
//  TopCategoryTabs.swift
//  FamilyArchive
//
//  Shared top tabs for 动态 / 影视 / 音乐. The tag lists live on `TopCategoryPage`
//  so the order is a pure value the logic tests can pin.
//

import SwiftUI

/// One page's top tabs: 全部 first, then that page's categories.
enum TopCategoryPage: String, CaseIterable, Identifiable, Hashable {
    case feed = "动态"
    case video = "影视"

    var id: String { rawValue }
    var title: String { rawValue }

    var tags: [String] {
        switch self {
        case .feed: return FeedFilter.tags
        case .video: return VideoFilter.tags
        }
    }

    /// Every page opens on 全部.
    var defaultTag: String { FeedFilter.allTag }
}

/// Source filter options: 全部 first, then every platform, de-duplicated and in
/// the order the accounts were declared.
enum SourceOptions {
    static let all = "全部"

    static func options(from platforms: [String]) -> [String] {
        var ordered = [all]
        for platform in platforms where !ordered.contains(platform) {
            ordered.append(platform)
        }
        return ordered
    }
}

/// Segmented tabs rendered in the NavigationBar's principal slot.
struct TopCategoryTabs: View {
    let page: TopCategoryPage
    @Binding var selection: String

    var body: some View {
        Picker(page.title, selection: $selection) {
            ForEach(page.tags, id: \.self) { tag in
                // 两字标签靠内边距撑开，而不是给整条控件设死宽度。
                Text(tag)
                    .padding(.horizontal, 12)
                    .tag(tag)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("\(page.title)分类")
    }
}
