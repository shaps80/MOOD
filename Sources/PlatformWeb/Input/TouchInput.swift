import GameCore
import JavaScriptKit
import Swift

final class TouchInput {
    private var activeTouches = [Int: Double]()
    private var pointerDownClosure: JSClosure?
    private var pointerMoveClosure: JSClosure?
    private var pointerUpClosure: JSClosure?
    private var pointerCancelClosure: JSClosure?
    private var touchStartClosure: JSClosure?
    private var touchMoveClosure: JSClosure?
    private var touchEndClosure: JSClosure?
    private var touchCancelClosure: JSClosure?

    var state: Input {
        Input(horizontal: horizontalAxis)
    }

    func startListening(on canvas: JSObject?) {
        guard let canvas else { return }

        pointerDownClosure = JSClosure { [weak self] arguments in
            self?.handleActivePointer(arguments.first)
            return .undefined
        }

        pointerMoveClosure = JSClosure { [weak self] arguments in
            self?.handleActivePointer(arguments.first)
            return .undefined
        }

        pointerUpClosure = JSClosure { [weak self] arguments in
            self?.handleEndedPointer(arguments.first)
            return .undefined
        }

        pointerCancelClosure = JSClosure { [weak self] arguments in
            self?.handleEndedPointer(arguments.first)
            return .undefined
        }

        touchStartClosure = JSClosure { [weak self] arguments in
            self?.handleActiveTouches(arguments.first)
            return .undefined
        }

        touchMoveClosure = JSClosure { [weak self] arguments in
            self?.handleActiveTouches(arguments.first)
            return .undefined
        }

        touchEndClosure = JSClosure { [weak self] arguments in
            self?.handleEndedTouches(arguments.first)
            return .undefined
        }

        touchCancelClosure = JSClosure { [weak self] arguments in
            self?.handleEndedTouches(arguments.first)
            return .undefined
        }

        _ = canvas.addEventListener!("pointerdown", pointerDownClosure)
        _ = canvas.addEventListener!("pointermove", pointerMoveClosure)
        _ = canvas.addEventListener!("pointerup", pointerUpClosure)
        _ = canvas.addEventListener!("pointercancel", pointerCancelClosure)
        _ = canvas.addEventListener!("touchstart", touchStartClosure)
        _ = canvas.addEventListener!("touchmove", touchMoveClosure)
        _ = canvas.addEventListener!("touchend", touchEndClosure)
        _ = canvas.addEventListener!("touchcancel", touchCancelClosure)
    }

    private var horizontalAxis: Double {
        let midpoint = (JSObject.global.innerWidth.number ?? 0) / 2
        let left = activeTouches.values.contains { $0 < midpoint }
        let right = activeTouches.values.contains { $0 >= midpoint }

        switch (left, right) {
        case (true, false):
            return -1
        case (false, true):
            return 1
        default:
            return 0
        }
    }

    private func handleActivePointer(_ eventValue: JSValue?) {
        guard let event = eventValue?.object,
              let pointerId = event.pointerId.number,
              let clientX = event.clientX.number,
              isTouchPointer(event)
        else {
            return
        }

        _ = event.preventDefault!()
        activeTouches[Int(pointerId)] = clientX
    }

    private func handleEndedPointer(_ eventValue: JSValue?) {
        guard let event = eventValue?.object,
              let pointerId = event.pointerId.number,
              isTouchPointer(event)
        else {
            return
        }

        _ = event.preventDefault!()
        activeTouches.removeValue(forKey: Int(pointerId))
    }

    private func handleActiveTouches(_ eventValue: JSValue?) {
        guard let event = eventValue?.object else { return }

        _ = event.preventDefault!()
        updateTouches(event.changedTouches)
    }

    private func handleEndedTouches(_ eventValue: JSValue?) {
        guard let event = eventValue?.object else { return }

        _ = event.preventDefault!()
        removeTouches(event.changedTouches)
    }

    private func updateTouches(_ touchesValue: JSValue) {
        guard let touches = touchesValue.object,
              let touchCount = touches["length"].number
        else {
            return
        }

        for index in 0..<Int(touchCount) {
            let touch = touches[index]
            guard let identifier = touch.identifier.number,
                  let clientX = touch.clientX.number
            else {
                continue
            }

            activeTouches[Int(identifier)] = clientX
        }
    }

    private func removeTouches(_ touchesValue: JSValue) {
        guard let touches = touchesValue.object,
              let touchCount = touches["length"].number
        else {
            return
        }

        for index in 0..<Int(touchCount) {
            let touch = touches[index]
            guard let identifier = touch.identifier.number else { continue }

            activeTouches.removeValue(forKey: Int(identifier))
        }
    }

    private func isTouchPointer(_ event: JSObject) -> Bool {
        event.pointerType.string == "touch"
    }
}
