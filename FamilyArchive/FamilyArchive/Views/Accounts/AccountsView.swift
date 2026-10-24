import Foundation
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct AccountsView: View {
    let scope: AccountScope

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.createdAt, order: .reverse) private var accounts: [Account]

    @State private var draft = AccountDraft()
    @State private var avatarItem: PhotosPickerItem?
    @State private var logoItem: PhotosPickerItem?
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var successMessage = ""

    init(scope: AccountScope) {
        self.scope = scope
    }

    private var filteredAccounts: [Account] {
        accounts.filter { $0.scope == scope.rawValue }
    }

    var body: some View {
        NavigationStack {
            Form {
                if !filteredAccounts.isEmpty {
                    Section("已添加账号") {
                        ForEach(filteredAccounts) { account in
                            accountRow(account)
                        }
                    }
                }

                Section("添加账号") {
                    TextField("账号", text: $draft.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("密码", text: $draft.password)

                    Picker("平台", selection: $draft.platform) {
                        ForEach(SocialPlatform.allCases) { platform in
                            Text(platform.title).tag(platform)
                        }
                    }

                    PhotosPicker(selection: $avatarItem, matching: .images) {
                        Label("选择头像", systemImage: "person.crop.circle")
                    }
                    if let data = draft.avatarData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 72)
                            .clipShape(Circle())
                    }

                    PhotosPicker(selection: $logoItem, matching: .images) {
                        Label("选择平台图标", systemImage: "app.badge")
                    }
                    if let data = draft.platformLogoData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    Button("保存账号") { saveAccount() }
                }

                if !successMessage.isEmpty {
                    Section {
                        Text(successMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("账号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .onChange(of: avatarItem) { _, item in
                loadImage(item) { data in
                    draft.avatarData = data
                }
            }
            .onChange(of: logoItem) { _, item in
                loadImage(item) { data in
                    draft.platformLogoData = data
                }
            }
            .alert("提示", isPresented: $showError) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .presentationDetents([.large])
    }

    private func accountRow(_ account: Account) -> some View {
        HStack(spacing: 12) {
            DataImageView(
                data: account.avatarData,
                systemImage: "person.crop.circle.fill",
                size: 42,
                cornerRadius: 21
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(account.username)
                    .font(.body)
                Text(account.platform)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            DataImageView(
                data: account.platformLogoData,
                systemImage: "app.badge",
                size: 30,
                cornerRadius: 8
            )
        }
    }

    private func loadImage(_ item: PhotosPickerItem?, assign: @escaping (Data?) -> Void) {
        guard let item else {
            assign(nil)
            return
        }
        Task { @MainActor in
            let data = try? await item.loadTransferable(type: Data.self)
            assign(data)
        }
    }

    private func saveAccount() {
        let issues = draft.validationIssues
        guard issues.isEmpty else {
            errorMessage = issues.joined(separator: "\n")
            showError = true
            return
        }

        let account = Account(
            username: draft.username.trimmingCharacters(in: .whitespacesAndNewlines),
            platform: draft.platform.rawValue,
            scope: scope.rawValue,
            avatarData: draft.avatarData,
            platformLogoData: draft.platformLogoData
        )
        modelContext.insert(account)
        do {
            try modelContext.save()
        } catch {
            modelContext.delete(account)
            errorMessage = "保存失败：\(error.localizedDescription)"
            showError = true
            return
        }

        if !KeychainStore.setPassword(draft.password, for: account.id) {
            errorMessage = "账号已保存，但密码写入钥匙串失败。"
            showError = true
        }

        successMessage = "账号已添加：\(account.username)"
        draft = AccountDraft()
        avatarItem = nil
        logoItem = nil
    }
}
