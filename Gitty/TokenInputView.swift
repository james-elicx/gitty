//
//  TokenInputView.swift
//  Gitty
//
//  Created by James on 02/01/2026.
//

import SwiftUI

struct TokenInputView: View {
  @ObservedObject var authViewModel: AuthViewModel
  @State private var tokenInput: String = ""
  @State private var isSecure: Bool = true

  var body: some View {
    VStack(spacing: 20) {
      Image(systemName: "lock.shield")
        .font(.system(size: 50))
        .foregroundColor(.blue)

      Text("GitHub Personal Access Token")
        .font(.headline)

      Text("Enter your GitHub PAT to get started")
        .font(.subheadline)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          if isSecure {
            SecureField("ghp_xxxxxxxxxxxx", text: $tokenInput)
              .textFieldStyle(.roundedBorder)
          } else {
            TextField("ghp_xxxxxxxxxxxx", text: $tokenInput)
              .textFieldStyle(.roundedBorder)
          }

          Button(action: {
            isSecure.toggle()
          }) {
            Image(systemName: isSecure ? "eye.slash" : "eye")
              .foregroundColor(.secondary)
          }
          .buttonStyle(.plain)
        }

        if let error = authViewModel.errorMessage {
          Text(error)
            .font(.caption)
            .foregroundColor(.red)
        }
      }

      Button(action: {
        authViewModel.saveToken(tokenInput)
      }) {
        Text("Save Token")
          .frame(maxWidth: .infinity)
          .padding(.vertical, 8)
      }
      .buttonStyle(.borderedProminent)
      .disabled(tokenInput.isEmpty)

      VStack(alignment: .leading, spacing: 4) {
        Text("How to create a GitHub PAT:")
          .font(.caption)
          .fontWeight(.semibold)

        Text("1. Go to GitHub Settings > Developer settings")
          .font(.caption2)
          .foregroundColor(.secondary)

        Text("2. Click Personal access tokens > Tokens (classic)")
          .font(.caption2)
          .foregroundColor(.secondary)

        Text("3. Generate new token with 'notifications' scope")
          .font(.caption2)
          .foregroundColor(.secondary)
      }
      .padding(.top, 10)
    }
    .padding()
    .frame(width: 400)
  }
}

#Preview {
  TokenInputView(authViewModel: AuthViewModel())
}
