import Swift

/// A consecutive run of stable slots sharing one expiry tick.
struct BirthCohort {
    var lower: UInt32
    var upper: UInt32
    let deathTick: UInt32
}
