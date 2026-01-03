//
//  PersistenceManager.swift
//  Gitty
//
//  Created by Assistant on 03/01/2026.
//

import Foundation

class PersistenceManager {
  static let shared = PersistenceManager()

  private let doneNotificationsKey = "done_notification_ids"
  private let lastFetchTimestampKey = "last_fetch_timestamp"
  private let lastNotificationUpdatedAtKey = "last_notification_updated_at"
  private let cachedNotificationsKey = "cached_notifications"
  private let hiddenOrganizationsKey = "hidden_organizations"
  private let refreshIntervalKey = "refresh_interval"

  private init() {}

  // MARK: - Done Notifications

  /// Get all done notification IDs
  func getDoneNotificationIds() -> Set<String> {
    guard let array = UserDefaults.standard.array(forKey: doneNotificationsKey) as? [String] else {
      return Set()
    }
    return Set(array)
  }

  /// Mark a notification as done
  func markAsDone(notificationId: String) {
    var doneIds = getDoneNotificationIds()
    doneIds.insert(notificationId)
    UserDefaults.standard.set(Array(doneIds), forKey: doneNotificationsKey)
  }

  /// Check if a notification is marked as done
  func isDone(notificationId: String) -> Bool {
    return getDoneNotificationIds().contains(notificationId)
  }

  /// Clear all done notifications (useful for debugging or reset)
  func clearDoneNotifications() {
    UserDefaults.standard.removeObject(forKey: doneNotificationsKey)
  }

  // MARK: - Last Fetch Tracking

  /// Get the timestamp of the last successful fetch
  func getLastFetchTimestamp() -> Date? {
    guard let timestamp = UserDefaults.standard.object(forKey: lastFetchTimestampKey) as? Date
    else {
      return nil
    }
    return timestamp
  }

  /// Update the last fetch timestamp
  func updateLastFetchTimestamp() {
    UserDefaults.standard.set(Date(), forKey: lastFetchTimestampKey)
  }

  /// Get the most recent notification's updated_at timestamp from the last fetch
  func getLastNotificationUpdatedAt() -> Date? {
    guard
      let timestamp = UserDefaults.standard.object(forKey: lastNotificationUpdatedAtKey) as? Date
    else {
      return nil
    }
    return timestamp
  }

  /// Update the most recent notification's updated_at timestamp
  func updateLastNotificationUpdatedAt(_ date: Date) {
    UserDefaults.standard.set(date, forKey: lastNotificationUpdatedAtKey)
  }

  /// Check if we should continue paginating based on the oldest notification in the current page
  /// Returns true if we haven't reached notifications we've already seen
  func shouldContinuePaginating(oldestNotificationDate: Date) -> Bool {
    guard let lastDate = getLastNotificationUpdatedAt() else {
      // First time fetching, should paginate to get all
      return true
    }

    // Continue paginating if the oldest notification in this page is still newer than our last fetch
    return oldestNotificationDate > lastDate
  }

  /// Reset all persistence (useful for debugging or sign out)
  func resetAll() {
    clearDoneNotifications()
    UserDefaults.standard.removeObject(forKey: lastFetchTimestampKey)
    UserDefaults.standard.removeObject(forKey: lastNotificationUpdatedAtKey)
    UserDefaults.standard.removeObject(forKey: cachedNotificationsKey)
  }

  // MARK: - Notification Caching

  /// Get cached notifications with done notifications filtered out
  func getCachedNotificationsFiltered() -> [GitHubNotification]? {
    guard let cached = getCachedNotifications() else {
      return nil
    }
    let doneIds = getDoneNotificationIds()
    return cached.filter { !doneIds.contains($0.id) }
  }

  /// Cache notifications to disk
  func cacheNotifications(_ notifications: [GitHubNotification]) {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601

    do {
      let data = try encoder.encode(notifications)
      UserDefaults.standard.set(data, forKey: cachedNotificationsKey)
      print("💾 Cached \(notifications.count) notifications")
    } catch {
      print("❌ Failed to cache notifications: \(error)")
    }
  }

  /// Get cached notifications from disk
  func getCachedNotifications() -> [GitHubNotification]? {
    guard let data = UserDefaults.standard.data(forKey: cachedNotificationsKey) else {
      return nil
    }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    do {
      let notifications = try decoder.decode([GitHubNotification].self, from: data)
      print("💾 Loaded \(notifications.count) cached notifications")
      return notifications
    } catch {
      print("❌ Failed to decode cached notifications: \(error)")
      return nil
    }
  }

  /// Clear cached notifications
  func clearCache() {
    UserDefaults.standard.removeObject(forKey: cachedNotificationsKey)
  }

  // MARK: - Organization Filtering

  /// Get all hidden organization names
  func getHiddenOrganizations() -> Set<String> {
    guard let array = UserDefaults.standard.array(forKey: hiddenOrganizationsKey) as? [String]
    else {
      return Set()
    }
    return Set(array)
  }

  /// Hide an organization
  func hideOrganization(_ organization: String) {
    var hidden = getHiddenOrganizations()
    hidden.insert(organization)
    UserDefaults.standard.set(Array(hidden), forKey: hiddenOrganizationsKey)
  }

  /// Unhide an organization
  func unhideOrganization(_ organization: String) {
    var hidden = getHiddenOrganizations()
    hidden.remove(organization)
    UserDefaults.standard.set(Array(hidden), forKey: hiddenOrganizationsKey)
  }

  /// Check if an organization is hidden
  func isOrganizationHidden(_ organization: String) -> Bool {
    return getHiddenOrganizations().contains(organization)
  }

  /// Clear all hidden organizations
  func clearHiddenOrganizations() {
    UserDefaults.standard.removeObject(forKey: hiddenOrganizationsKey)
  }

  // MARK: - Refresh Interval

  /// Get the refresh interval in seconds (default: 60)
  func getRefreshInterval() -> TimeInterval {
    let interval = UserDefaults.standard.double(forKey: refreshIntervalKey)
    // If not set or invalid, return default of 60 seconds
    return interval > 0 ? interval : 60.0
  }

  /// Set the refresh interval in seconds
  func setRefreshInterval(_ interval: TimeInterval) {
    UserDefaults.standard.set(interval, forKey: refreshIntervalKey)
  }
}
