//
//  TopActionGroup.swift
//  FamilyArchive
//
//  搜索 and 来源 travel together as one group; 账号 is left as its own toolbar
//  item by the page that hosts it.
//

import SwiftUI

struct TopActionGroup: View {
    let page: TopCategoryPage
    let isSearchActive: Bool
    let sources: [String]
    @Binding var selectedSource: String
    let onSearchTapped: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onSearchTapped) {
                Image(systemName: isSearchActive ? "xmark" : "magnifyingglass")
            }
            .accessibilityLabel(isSearchActive ? "关闭\(page.title)搜索" : "\(page.title)搜索")

            Menu {
                Picker("来源", selection: $selectedSource) {
                    ForEach(sources, id: \.self) { source in
                        Text(source).tag(source)
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
            .accessibilityLabel("\(page.title)来源")
            .accessibilityValue(selectedSource)
        }
    }
}
