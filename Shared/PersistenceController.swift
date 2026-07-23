import Foundation
import SwiftData

public enum TaliSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)
    public static var models: [any PersistentModel.Type] {
        [Habit.self, HabitEvent.self]
    }
}

public enum TaliMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [TaliSchemaV1.self]
    }

    public static var stages: [MigrationStage] { [] }
}

public enum PersistenceControllerError: LocalizedError {
    case appGroupUnavailable

    public var errorDescription: String? {
        switch self {
        case .appGroupUnavailable:
            return "Tali couldn't open its shared App Group storage. Check the App Group entitlement and try again."
        }
    }
}

public enum PersistenceController {
    public static let appGroupIdentifier = "group.com.kathrynswint.Tali"

    public static var isSharedContainerAvailable: Bool {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) != nil
    }

    public static func makeContainer(
        inMemory: Bool = false,
        storeURL: URL? = nil
    ) throws -> ModelContainer {
        let schema = Schema(versionedSchema: TaliSchemaV1.self)
        let configuration: ModelConfiguration

        if inMemory {
            configuration = ModelConfiguration(
                "TaliTests",
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        } else if let storeURL {
            configuration = ModelConfiguration(
                "Tali",
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
        } else {
            let groupContainer: ModelConfiguration.GroupContainer
            if isSharedContainerAvailable {
                groupContainer = .identifier(appGroupIdentifier)
            } else {
                #if targetEnvironment(simulator)
                // Unsigned simulator builds cannot resolve App Groups. Keep local development
                // usable, but surface this mode in the UI so it is never mistaken for sharing.
                groupContainer = .automatic
                #else
                throw PersistenceControllerError.appGroupUnavailable
                #endif
            }
            configuration = ModelConfiguration(
                "Tali",
                schema: schema,
                groupContainer: groupContainer,
                cloudKitDatabase: .none
            )
        }

        return try ModelContainer(
            for: schema,
            migrationPlan: TaliMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
