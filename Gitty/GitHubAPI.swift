//
//  GitHubAPI.swift
//  Gitty
//
//  Created by James on 02/01/2026.
//

import Foundation

class GitHubAPI {
  static let shared = GitHubAPI()

  private let baseURL = "https://api.github.com"
  private let session: URLSession
  private let persistence = PersistenceManager.shared

  private init() {
    // Configure session with no caching - we'll use PersistenceManager instead
    let config = URLSessionConfiguration.default
    config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    config.urlCache = nil
    self.session = URLSession(configuration: config)
  }

  // MARK: - Notifications

  /// Fetch notifications with smart pagination and caching
  /// - Parameters:
  ///   - token: GitHub Personal Access Token
  /// - Returns: Array of GitHubNotification objects (filtered for done notifications)
  func fetchNotifications(token: String) async throws -> [GitHubNotification] {

    // Fetch notifications
    var allNotifications: [GitHubNotification] = []
    var page = 1
    var shouldContinue = true

    while shouldContinue {
      let notifications = try await fetchNotificationsPage(token: token, page: page)

      if notifications.isEmpty {
        shouldContinue = false
        break
      }

      allNotifications.append(contentsOf: notifications)
      print(
        "📥 Fetched page \(page): \(notifications.count) notifications (total: \(allNotifications.count))"
      )

      // Check if we should continue paginating based on dates
      // Check the OLDEST notification in the current page (last item)
      if let oldestInPage = notifications.last?.updatedAt {
        // Continue if the oldest notification in this page is still newer than what we've seen before
        // AND we got a full page (50 items means there might be more)
        shouldContinue =
          persistence.shouldContinuePaginating(oldestNotificationDate: oldestInPage)
          && notifications.count == 50
      } else {
        shouldContinue = false
      }

      page += 1
    }

    // Update persistence tracking with the most recent notification date
    if let mostRecentDate = allNotifications.first?.updatedAt {
      persistence.updateLastNotificationUpdatedAt(mostRecentDate)
    }
    persistence.updateLastFetchTimestamp()

    // Cache the notifications
    persistence.cacheNotifications(allNotifications)

    return filterDoneNotifications(allNotifications)
  }

  /// Fetch a single page of notifications
  private func fetchNotificationsPage(token: String, page: Int) async throws -> [GitHubNotification]
  {
    let endpoint = "\(baseURL)/notifications?all=true&per_page=50&page=\(page)"

    guard let url = URL(string: endpoint) else {
      throw GitHubAPIError.invalidURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

    let (data, response) = try await session.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw GitHubAPIError.invalidResponse
    }

    switch httpResponse.statusCode {
    case 200:
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      decoder.keyDecodingStrategy = .convertFromSnakeCase

      let apiNotifications = try decoder.decode([GitHubAPINotification].self, from: data)
      return apiNotifications.map { $0.toNotification() }

    case 401:
      throw GitHubAPIError.unauthorized

    case 403:
      throw GitHubAPIError.forbidden

    case 404:
      throw GitHubAPIError.notFound

    default:
      throw GitHubAPIError.httpError(statusCode: httpResponse.statusCode)
    }
  }

  /// Filter out notifications that have been marked as done
  private func filterDoneNotifications(_ notifications: [GitHubNotification])
    -> [GitHubNotification]
  {
    let doneIds = persistence.getDoneNotificationIds()
    return notifications.filter { !doneIds.contains($0.id) }
  }

  /// Mark a notification as read
  /// - Parameters:
  ///   - notificationId: The ID of the notification to mark as read
  ///   - token: GitHub Personal Access Token
  func markAsRead(notificationId: String, token: String) async throws {
    let endpoint = "\(baseURL)/notifications/threads/\(notificationId)"

    guard let url = URL(string: endpoint) else {
      throw GitHubAPIError.invalidURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = "PATCH"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

    let (_, response) = try await session.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw GitHubAPIError.invalidResponse
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      throw GitHubAPIError.httpError(statusCode: httpResponse.statusCode)
    }
  }

  /// Delete/archive a notification (mark as done)
  /// - Parameters:
  ///   - notificationId: The ID of the notification to delete
  ///   - token: GitHub Personal Access Token
  func deleteNotification(notificationId: String, token: String) async throws {
    let endpoint = "\(baseURL)/notifications/threads/\(notificationId)"
    print("🗑️ DELETE request to: \(endpoint)")

    guard let url = URL(string: endpoint) else {
      throw GitHubAPIError.invalidURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = "DELETE"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

    let (data, response) = try await session.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw GitHubAPIError.invalidResponse
    }

    print("🗑️ DELETE response status: \(httpResponse.statusCode)")
    if !data.isEmpty, let responseString = String(data: data, encoding: .utf8) {
      print("🗑️ DELETE response body: \(responseString)")
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      print("❌ DELETE failed with status: \(httpResponse.statusCode)")
      throw GitHubAPIError.httpError(statusCode: httpResponse.statusCode)
    }

    print("✅ DELETE successful for notification: \(notificationId)")
  }

  /// Mark all notifications as read
  /// - Parameter token: GitHub Personal Access Token
  func markAllAsRead(token: String) async throws {
    let endpoint = "\(baseURL)/notifications"

    guard let url = URL(string: endpoint) else {
      throw GitHubAPIError.invalidURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = "PUT"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

    let (_, response) = try await session.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw GitHubAPIError.invalidResponse
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      throw GitHubAPIError.httpError(statusCode: httpResponse.statusCode)
    }
  }

  /// Set subscription for a notification thread
  /// - Parameters:
  ///   - threadId: The ID of the notification thread
  ///   - subscribed: Whether to subscribe or unsubscribe
  ///   - token: GitHub Personal Access Token
  func setThreadSubscription(threadId: String, subscribed: Bool, token: String) async throws {
    let endpoint = "\(baseURL)/notifications/threads/\(threadId)/subscription"

    guard let url = URL(string: endpoint) else {
      throw GitHubAPIError.invalidURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = "PUT"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    // Use 'ignored' field: false to subscribe, true to unsubscribe/mute
    let body: [String: Any] = ["ignored": !subscribed]
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)

    let (_, response) = try await session.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw GitHubAPIError.invalidResponse
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      throw GitHubAPIError.httpError(statusCode: httpResponse.statusCode)
    }
  }

  /// Get subscription status for a notification thread
  /// - Parameters:
  ///   - threadId: The ID of the notification thread
  ///   - token: GitHub Personal Access Token
  /// - Returns: true if subscribed, false otherwise
  func getThreadSubscription(threadId: String, token: String) async throws -> Bool {
    let endpoint = "\(baseURL)/notifications/threads/\(threadId)/subscription"

    guard let url = URL(string: endpoint) else {
      throw GitHubAPIError.invalidURL
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

    let (data, response) = try await session.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw GitHubAPIError.invalidResponse
    }

    guard httpResponse.statusCode == 200 else {
      throw GitHubAPIError.httpError(statusCode: httpResponse.statusCode)
    }

    struct SubscriptionResponse: Codable {
      let subscribed: Bool
    }

    let decoder = JSONDecoder()
    let subscription = try decoder.decode(SubscriptionResponse.self, from: data)
    return subscription.subscribed
  }

  /// Validate a GitHub token by making a test API call
  /// - Parameter token: GitHub Personal Access Token to validate
  /// - Returns: true if token is valid, false otherwise
  func validateToken(token: String) async -> Bool {
    let endpoint = "\(baseURL)/user"

    guard let url = URL(string: endpoint) else {
      return false
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

    do {
      let (_, response) = try await session.data(for: request)

      guard let httpResponse = response as? HTTPURLResponse else {
        return false
      }

      return httpResponse.statusCode == 200
    } catch {
      return false
    }
  }
}

// MARK: - API Models

/// Internal model matching GitHub API response structure
private struct GitHubAPINotification: Codable {
  let id: String
  let subject: Subject
  let repository: Repository
  let updatedAt: Date
  let reason: String
  let unread: Bool
  let lastReadAt: Date?

  struct Subject: Codable {
    let title: String
    let type: String
    let url: String?
    let latestCommentUrl: String?
  }

  struct Repository: Codable {
    let fullName: String
    let htmlUrl: String
  }

  /// Convert API URL to HTML URL (e.g., "https://api.github.com/repos/user/repo/issues/42" -> "https://github.com/user/repo/issues/42")
  private func getHtmlUrl() -> String? {
    guard let apiUrl = subject.url else { return nil }

    var htmlUrl =
      apiUrl
      .replacingOccurrences(of: "https://api.github.com/repos/", with: "https://github.com/")

    // Convert pulls to pull (singular)
    htmlUrl = htmlUrl.replacingOccurrences(of: "/pulls/", with: "/pull/")

    // Convert commits to commit (singular)
    htmlUrl = htmlUrl.replacingOccurrences(of: "/commits/", with: "/commit/")

    // For releases, convert /releases/{id} to just the releases page since we don't have tag name
    if subject.type == "Release" {
      if let range = htmlUrl.range(of: "/releases/") {
        htmlUrl = String(htmlUrl[..<range.upperBound])
      }
    }

    return htmlUrl
  }

  /// Extract number from subject URL (e.g., "https://api.github.com/repos/user/repo/issues/42")
  private func extractNumber() -> Int? {
    guard let urlString = subject.url else { return nil }
    let components = urlString.split(separator: "/")
    guard let lastComponent = components.last,
      let number = Int(lastComponent)
    else {
      return nil
    }
    return number
  }

  /// Convert API model to app model
  func toNotification() -> GitHubNotification {
    return GitHubNotification(
      id: id,
      title: subject.title,
      repository: repository.fullName,
      type: subject.type,
      updatedAt: updatedAt,
      number: extractNumber(),
      reason: reason,
      unread: unread,
      url: getHtmlUrl(),
      repositoryUrl: repository.htmlUrl,
      subscribed: true
    )
  }
}

// MARK: - Error Types

enum GitHubAPIError: Error, LocalizedError {
  case invalidURL
  case invalidResponse
  case unauthorized
  case forbidden
  case notFound
  case httpError(statusCode: Int)
  case decodingError(Error)

  var errorDescription: String? {
    switch self {
    case .invalidURL:
      return "Invalid API URL"
    case .invalidResponse:
      return "Invalid response from GitHub"
    case .unauthorized:
      return "Invalid or expired token. Please sign in again."
    case .forbidden:
      return "Access forbidden. Check token permissions."
    case .notFound:
      return "Resource not found"
    case .httpError(let statusCode):
      return "HTTP error: \(statusCode)"
    case .decodingError(let error):
      return "Failed to parse response: \(error.localizedDescription)"
    }
  }
}
