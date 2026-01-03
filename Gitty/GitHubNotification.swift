//
//  GitHubNotification.swift
//  Gitty
//
//  Created by Assistant on 03/01/2026.
//

import Foundation

struct GitHubNotification: Identifiable, Equatable, Codable {
  let id: String
  let title: String
  let repository: String
  let type: String
  let updatedAt: Date
  let number: Int?
  let reason: String?
  let unread: Bool
  let url: String?
  let repositoryUrl: String?
  let subscribed: Bool

  var icon: String {
    switch type {
    case "Issue":
      return "exclamationmark.circle.fill"
    case "PullRequest":
      return "arrow.triangle.pull"
    case "Commit":
      return "arrow.turn.up.right"
    case "Release":
      return "tag.fill"
    case "CheckSuite":
      return "checkmark.circle.fill"
    case "Discussion":
      return "bubble.left.and.bubble.right.fill"
    default:
      return "bell.fill"
    }
  }

  var shouldShowNumber: Bool {
    return type == "Issue" || type == "PullRequest"
  }

  var supportsSubscription: Bool {
    // Only Issues and PullRequests reliably support subscriptions
    return type == "Issue" || type == "PullRequest"
  }

  var timeAgo: String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: updatedAt, relativeTo: Date())
  }
}
