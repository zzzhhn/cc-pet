import CoreGraphics

public struct AtlasGeometry: Equatable, Sendable {
    public let cols: Int
    public let rows: Int
    public init(cols: Int, rows: Int) { self.cols = cols; self.rows = rows }

    /// Normalized (0..1, top-left origin) rect of the cell at (row, frame).
    public func rect(row: Int, frame: Int) -> CGRect {
        let w = 1.0 / Double(cols)
        let h = 1.0 / Double(rows)
        return CGRect(x: Double(frame) * w, y: Double(row) * h, width: w, height: h)
    }
}
