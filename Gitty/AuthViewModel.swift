//
//  AuthViewModel.swift
//  Gitty
//
//  Created by James on 02/01/2026.
//

import Combine
import SwiftUI

class AuthViewModel: ObservableObject {
  @Published var isAuthenticated: Bool = false
  @Published var isLoading: Bool = true
  @Published var errorMessage: String?

  private let keychainManager = KeychainManager.shared

  init() {
    checkAuthentication()
  }

  // Check if user has a valid token
  func checkAuthentication() {
    isLoading = true

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
      guard let self = self else { return }

      if self.keychainManager.hasToken() {
        self.isAuthenticated = true
      } else {
        self.isAuthenticated = false
      }

      self.isLoading = false
    }
  }

  // Save a new token
  func saveToken(_ token: String) {
    let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmedToken.isEmpty else {
      errorMessage = "Token cannot be empty"
      return
    }

    // Basic validation for GitHub PAT format
    guard trimmedToken.hasPrefix("ghp_") || trimmedToken.hasPrefix("github_pat_") else {
      errorMessage = "Invalid token format. GitHub tokens start with 'ghp_' or 'github_pat_'"
      return
    }

    if keychainManager.saveToken(trimmedToken) {
      isAuthenticated = true
      errorMessage = nil
    } else {
      errorMessage = "Failed to save token securely"
    }
  }

  // Sign out and remove token
  func signOut() {
    if keychainManager.deleteToken() {
      // Clear all persisted data
      PersistenceManager.shared.resetAll()
      isAuthenticated = false
      errorMessage = nil
    } else {
      errorMessage = "Failed to remove token"
    }
  }

  // Get the stored token
  func getToken() -> String? {
    return keychainManager.getToken()
  }
}
