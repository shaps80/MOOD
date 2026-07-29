extension SFNT {
    enum RegistrationError: Error, Equatable {
        case invalid
        case malformedTableDirectory
        case missingRequiredTable
        case malformedRequiredTable
        case unsupportedCharacterMap
    }
}
