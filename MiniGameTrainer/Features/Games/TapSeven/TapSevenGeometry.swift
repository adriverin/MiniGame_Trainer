import CoreGraphics

struct TapSevenGeometry: Equatable {
    let sceneSize: CGSize
    let ringCenter: CGPoint
    let ringRadius: CGFloat
    let strokeWidth: CGFloat
    let instructionPosition: CGPoint
    let startButtonCenter: CGPoint
    let startButtonRadius: CGFloat
    let timerFontSize: CGFloat
    let instructionFontSize: CGFloat

    init(sceneSize: CGSize, config: TapSevenGameConfig) {
        self.sceneSize = sceneSize
        ringCenter = CGPoint(
            x: sceneSize.width * config.ringCenterXRatio,
            y: sceneSize.height * config.ringCenterYRatio
        )
        let diameter = max(24, sceneSize.width * config.ringDiameterRatio)
        ringRadius = diameter / 2
        strokeWidth = max(4, sceneSize.width * config.ringStrokeRatio)
        instructionPosition = CGPoint(
            x: sceneSize.width / 2,
            y: sceneSize.height * config.instructionYRatio
        )
        startButtonCenter = CGPoint(
            x: sceneSize.width / 2,
            y: sceneSize.height * config.startButtonYRatio
        )
        startButtonRadius = max(18, sceneSize.width * config.startButtonDiameterRatio / 2)
        timerFontSize = max(28, sceneSize.width * config.timerFontSizeRatio)
        instructionFontSize = max(14, sceneSize.width * config.instructionFontSizeRatio)
    }

    var ringOuterRadius: CGFloat { ringRadius + strokeWidth / 2 }
}
