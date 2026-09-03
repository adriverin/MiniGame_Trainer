import CoreGraphics

struct GridGeometry: Equatable {
    let sceneSize: CGSize
    let rows: Int
    let columns: Int
    let cellSize: CGFloat
    let gap: CGFloat
    let cornerRadius: CGFloat
    let gridFrame: CGRect
    let submitButtonFrame: CGRect
    let timerBarFrame: CGRect
    let scorePosition: CGPoint
    let levelPosition: CGPoint

    init(sceneSize: CGSize, rows: Int, columns: Int, config: GridGameConfig) {
        self.sceneSize = sceneSize
        self.rows = max(1, rows)
        self.columns = max(1, columns)

        let envelopeWidth = max(80, sceneSize.width * config.gridWidthRatio)
        let envelopeHeight = max(80, sceneSize.height * config.gridHeightRatio)
        let gapRatio = max(0, config.cellGapToSizeRatio)
        let widthCell = envelopeWidth / (CGFloat(self.columns) + gapRatio * CGFloat(self.columns - 1))
        let heightCell = envelopeHeight / (CGFloat(self.rows) + gapRatio * CGFloat(self.rows - 1))
        cellSize = max(8, min(widthCell, heightCell))
        gap = cellSize * gapRatio
        cornerRadius = max(2, cellSize * config.cellCornerRadiusRatio)

        let boardWidth = CGFloat(self.columns) * cellSize + CGFloat(self.columns - 1) * gap
        let boardHeight = CGFloat(self.rows) * cellSize + CGFloat(self.rows - 1) * gap
        let center = CGPoint(x: sceneSize.width / 2, y: sceneSize.height * config.gridCenterYRatio)
        gridFrame = CGRect(
            x: center.x - boardWidth / 2,
            y: center.y - boardHeight / 2,
            width: boardWidth,
            height: boardHeight
        )

        let buttonWidth = max(120, sceneSize.width * config.submitButtonWidthRatio)
        let buttonHeight = max(44, sceneSize.height * config.submitButtonHeightRatio)
        submitButtonFrame = CGRect(
            x: sceneSize.width / 2 - buttonWidth / 2,
            y: sceneSize.height * config.submitButtonYRatio - buttonHeight / 2,
            width: buttonWidth,
            height: buttonHeight
        )

        let barWidth = max(80, sceneSize.width * config.timerBarWidthRatio)
        let barHeight = max(4, sceneSize.height * config.timerBarHeightRatio)
        timerBarFrame = CGRect(
            x: sceneSize.width / 2 - barWidth / 2,
            y: sceneSize.height * config.timerBarYRatio - barHeight / 2,
            width: barWidth,
            height: barHeight
        )

        scorePosition = CGPoint(x: sceneSize.width / 2, y: sceneSize.height * config.scoreYRatio)
        levelPosition = CGPoint(x: sceneSize.width / 2, y: sceneSize.height * config.levelYRatio)
    }

    func frame(for cell: GridCell) -> CGRect {
        let x = gridFrame.minX + CGFloat(cell.column) * (cellSize + gap)
        let topToBottomRow = cell.row
        let y = gridFrame.maxY - CGFloat(topToBottomRow + 1) * cellSize - CGFloat(topToBottomRow) * gap
        return CGRect(x: x, y: y, width: cellSize, height: cellSize)
    }

    func cell(at point: CGPoint) -> GridCell? {
        guard gridFrame.insetBy(dx: -1, dy: -1).contains(point) else { return nil }
        for row in 0..<rows {
            for column in 0..<columns {
                let candidate = GridCell(row: row, column: column)
                if frame(for: candidate).contains(point) { return candidate }
            }
        }
        return nil
    }

    var cellsOverlap: Bool {
        var frames: [CGRect] = []
        for row in 0..<rows {
            for column in 0..<columns {
                let next = frame(for: GridCell(row: row, column: column))
                if frames.contains(where: { $0.insetBy(dx: -0.5, dy: -0.5).intersects(next) }) {
                    return true
                }
                frames.append(next)
            }
        }
        return false
    }

    var overflowsViewport: Bool {
        let inset = gridFrame.insetBy(dx: -0.5, dy: -0.5)
        return inset.minX < 0 || inset.maxX > sceneSize.width || inset.minY < 0 || inset.maxY > sceneSize.height
    }
}
