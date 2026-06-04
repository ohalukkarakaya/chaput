import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
  private var contentHandler: ((UNNotificationContent) -> Void)?
  private var bestAttemptContent: UNMutableNotificationContent?
  private var downloadTask: URLSessionDownloadTask?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    self.contentHandler = contentHandler
    bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

    guard let bestAttemptContent else {
      contentHandler(request.content)
      return
    }

    guard let imageURL = imageURL(from: bestAttemptContent.userInfo) else {
      contentHandler(bestAttemptContent)
      return
    }

    downloadTask = URLSession.shared.downloadTask(with: imageURL) { [weak self] location, _, _ in
      guard let self else { return }
      defer { contentHandler(bestAttemptContent) }
      guard let location else { return }

      let temporaryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension(imageURL.pathExtension.isEmpty ? "jpg" : imageURL.pathExtension)

      do {
        try FileManager.default.moveItem(at: location, to: temporaryURL)
        let attachment = try UNNotificationAttachment(identifier: "chaput-image", url: temporaryURL)
        bestAttemptContent.attachments = [attachment]
      } catch {
        return
      }
    }
    downloadTask?.resume()
  }

  override func serviceExtensionTimeWillExpire() {
    downloadTask?.cancel()
    if let bestAttemptContent {
      contentHandler?(bestAttemptContent)
    }
  }

  private func imageURL(from userInfo: [AnyHashable: Any]) -> URL? {
    if let url = userInfo["image"] as? String {
      return URL(string: url)
    }
    if let fcmOptions = userInfo["fcm_options"] as? [String: Any],
       let url = fcmOptions["image"] as? String {
      return URL(string: url)
    }
    if let fcmOptions = userInfo["fcm_options"] as? [AnyHashable: Any],
       let url = fcmOptions["image"] as? String {
      return URL(string: url)
    }
    return nil
  }
}
