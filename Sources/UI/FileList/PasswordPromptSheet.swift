import SwiftUI

/// Asks for an archive password when extraction reports one is required or wrong.
/// Purely a prompt: the caller owns retrying the extraction.
struct PasswordPromptSheet: View {
    let isRetry: Bool
    let onSubmit: (String) -> Void
    let onCancel: () -> Void

    @State private var password: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isRetry ? "密码不正确" : "需要密码")
                .font(.headline)
            Text(isRetry
                 ? "请重新输入该压缩包的密码。"
                 : "该压缩包已加密，请输入密码后继续解压。")
                .font(.callout)
                .foregroundStyle(.secondary)
            SecureField("密码", text: $password)
                .textFieldStyle(.roundedBorder)
                .onSubmit(submit)

            HStack {
                Spacer()
                Button("取消", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("解压", action: submit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(password.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 340)
    }

    private func submit() {
        guard !password.isEmpty else { return }
        onSubmit(password)
    }
}
