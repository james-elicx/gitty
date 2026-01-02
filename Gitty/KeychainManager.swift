//
//  KeychainManager.swift
//  Gitty
//
//  Created by James on 02/01/2026.
//

import Foundation
import LocalAuthentication
import Security

class KeychainManager {
  static let shared = KeychainManager()

  private let service = "com.gitty.app"
  private let account = "github-pat"

  private init() {}

  // Save token to keychain
  func saveToken(_ token: String) -> Bool {
    guard let data = token.data(using: .utf8) else {
      return false
    }

    // Delete existing item if any
    deleteToken()

    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
    ]

    let status = SecItemAdd(query as CFDictionary, nil)
    if status != errSecSuccess {
      print("Keychain save failed with status: \(status)")
      if let errorMessage = SecCopyErrorMessageString(status, nil) {
        print("Error: \(errorMessage)")
      }
    }
    return status == errSecSuccess
  }

  // Retrieve token from keychain
  func getToken() -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    guard status == errSecSuccess,
      let data = result as? Data,
      let token = String(data: data, encoding: .utf8)
    else {
      return nil
    }

    return token
  }

  // Delete token from keychain
  func deleteToken() -> Bool {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]

    let status = SecItemDelete(query as CFDictionary)
    return status == errSecSuccess || status == errSecItemNotFound
  }

  // Check if token exists
  func hasToken() -> Bool {
    return getToken() != nil
  }
}
