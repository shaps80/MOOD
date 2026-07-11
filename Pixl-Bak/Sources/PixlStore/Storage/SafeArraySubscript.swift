extension Array {
    public subscript(safe index: Int) -> Element? {
        get {
            indices.contains(index) ? self[index] : nil
        }
        set {
            guard let newValue,
                  indices.contains(index)
            else {
                return
            }

            self[index] = newValue
        }
    }
}
