//
//  BillingView.swift
//  FamilyArchive
//
//  账单页占位。数据接入前只呈现原生分组列表与空状态，不读写任何业务状态，
//  因此不会影响弹窗、实色背景与动画。
//

import SwiftUI

struct BillingView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ContentUnavailableView {
                        Label("暂无账单", systemImage: "creditcard")
                    } description: {
                        Text("账单记录会显示在这里。")
                    }
                    .listRowInsets(
                        EdgeInsets(top: 28, leading: 0, bottom: 28, trailing: 0)
                    )
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } header: {
                    Text("账单")
                } footer: {
                    Text("账单功能正在准备中。")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("账单")
        }
    }
}

#Preview {
    BillingView()
}
