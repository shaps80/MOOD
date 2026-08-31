import PixlMemory
import Swift

@main
private enum Sandbox {
    static func main() {
        let permanentPlan = MemoryPlan("Permanent") { plan in
            plan.reserve(Float.self, count: 500_000, named: "Values")
        }
        let menuPlan = MemoryPlan("Menu") { plan in
            plan.reserve(Float.self, count: 125_000, named: "Values")
        }
        let levelOnePlan = MemoryPlan("Level 1") { plan in
            plan.reserve(Float.self, count: 2_000_000, named: "Values")
        }
        let levelTwoPlan = MemoryPlan("Level 2") { plan in
            plan.reserve(Float.self, count: 3_000_000, named: "Values")
        }
        let levelThreePlan = MemoryPlan("Level 3") { plan in
            plan.reserve(Float.self, count: 2_250_000, named: "Values")
        }
        let arena = Arena(
            permanent: permanentPlan,
            plans: [menuPlan, levelOnePlan, levelTwoPlan, levelThreePlan],
            concurrency: .upTo(2)
        )
        print(arena.startupReport)

        var scopes: [String: Scope] = [:]
        var isRunning = true
        while isRunning {
            print("""

            [1] toggle Level 1  [2] toggle Level 2  [3] toggle Level 3
            [m] toggle Menu     [u] use 250,000 values in Level 1
            [o] overflow Level 1  [p] print peak usage  [q] quit
            """)

            guard let command = readLine()?.lowercased() else { break }
            switch command {
            case "1":
                toggle(levelOnePlan, in: arena, scopes: &scopes)
            case "2":
                toggle(levelTwoPlan, in: arena, scopes: &scopes)
            case "3":
                toggle(levelThreePlan, in: arena, scopes: &scopes)
            case "m":
                toggle(menuPlan, in: arena, scopes: &scopes)
            case "u":
                tryMemory {
                    guard let scope = scopes[levelOnePlan.name] else {
                        print("Activate Level 1 first")
                        return
                    }
                    try scope.use(
                        Float.self,
                        count: 250_000,
                        from: "Values"
                    )
                    scope.printReport()
                }
            case "o":
                tryMemory {
                    guard let scope = scopes[levelOnePlan.name] else {
                        print("Activate Level 1 first")
                        return
                    }
                    try scope.use(
                        Float.self,
                        count: 2_000_001,
                        from: "Values"
                    )
                }
            case "p":
                print(arena.peakUsageReport)
            case "q":
                print(arena.peakUsageReport)
                isRunning = false
            default:
                print("Unknown command")
            }
        }
    }

    private static func toggle(
        _ plan: MemoryPlan,
        in arena: Arena,
        scopes: inout [String: Scope]
    ) {
        if let scope = scopes.removeValue(forKey: plan.name) {
            scope.release()
            print("Released \(plan.name)")
            return
        }
        tryMemory {
            scopes[plan.name] = try arena.activate(plan)
            print("Activated \(plan.name)")
        }
    }

    private static func tryMemory(_ operation: () throws -> Void) {
        do {
            try operation()
        } catch is MemoryFailure {
            // PixlMemory already printed the production diagnostic.
        } catch {
            print(error)
        }
    }
}
