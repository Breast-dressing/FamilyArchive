import Foundation

struct AccountDraft: Equatable {
    var username: String = ""
    var encUin: String = ""
    var password: String = ""
    var platform: SocialPlatform = .weibo
    var avatarData: Data?
    var platformLogoData: Data?

    var validationIssues: [String] {
        var issues: [String] = []
        if username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("请输入账号")
        }
        if password.isEmpty {
            issues.append("请输入密码")
        }
        if avatarData == nil {
            issues.append("请选择头像")
        }
        if platformLogoData == nil {
            issues.append("请选择平台图标")
        }
        return issues
    }

    var isValid: Bool { validationIssues.isEmpty }
}
