import Foundation

/// Atomic local persistence used for diagnostics and last-known state.
///
/// The no-team edition intentionally does not use App Groups, because the
/// `group.` entitlement requires provisioning. The WidgetKit extension samples
/// the machine independently and therefore does not depend on this store.
enum SharedSnapshotStore {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()

    private static let defaults = UserDefaults.standard

    private static var payloadURL: URL? {
        guard let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return nil }

        let directory = support.appendingPathComponent("MacPulse", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            return directory.appendingPathComponent(
                AppConstants.sharedPayloadFilename,
                isDirectory: false
            )
        } catch {
            return nil
        }
    }

    @discardableResult
    static func save(_ payload: SharedPayload) -> Bool {
        guard let data = try? encoder.encode(payload) else { return false }

        if let url = payloadURL {
            do {
                try data.write(to: url, options: [.atomic])
                return true
            } catch {
                // Continue to local UserDefaults as a conservative fallback.
            }
        }

        defaults.set(data, forKey: AppConstants.sharedPayloadKey)
        return true
    }

    static func load() -> SharedPayload? {
        let candidates: [Data?] = [
            payloadURL.flatMap { try? Data(contentsOf: $0, options: [.mappedIfSafe]) },
            defaults.data(forKey: AppConstants.sharedPayloadKey)
        ]

        for data in candidates.compactMap({ $0 }) {
            guard let payload = try? decoder.decode(SharedPayload.self, from: data),
                  payload.schemaVersion == AppConstants.payloadSchemaVersion else { continue }
            return payload
        }
        return nil
    }

    static func reset() {
        if let url = payloadURL { try? FileManager.default.removeItem(at: url) }
        defaults.removeObject(forKey: AppConstants.sharedPayloadKey)
    }
}
