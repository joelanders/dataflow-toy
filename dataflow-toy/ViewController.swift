//
//  ViewController.swift
//  dataflow-toy
//
//  Created by Joe Landers on 09.06.21.
//

import Cocoa

extension CGPoint {
    static func +=(lhs: inout CGPoint, rhs: CGPoint) {
        lhs.x += rhs.x
        lhs.y += rhs.y
    }
}

class DragBar: NSView {
    weak var parentView: Rectangle?
    override func viewDidMoveToSuperview() {
        NSLog("dragbar moved to superview")
        addGestureRecognizer(NSPanGestureRecognizer(target: self, action: #selector(pan)))

    }
    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        layer?.backgroundColor = NSColor.red.cgColor
        NSColor.red.set()
        NSBezierPath(rect: dirtyRect).fill()
    }
    
    // your gesture selector
    @objc func pan(_ gesture: NSPanGestureRecognizer) {
        //  update your view frame origin
        superview?.frame.origin += gesture.translation(in: self)
        // reset the gesture translation
        gesture.setTranslation(.zero, in: self)
    }

}

class Rectangle: NSView {
    var path: NSBezierPath = NSBezierPath()
    var start: NSPoint = NSPoint()
    var dragBar: DragBar?
    
    @IBInspectable var color: NSColor = .clear {
        didSet { layer?.backgroundColor = color.cgColor }
    }
    // draw your view using the background color
    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        //layer?.backgroundColor?.set()
        NSBezierPath(rect: dirtyRect).fill()
        NSColor.blue.set()
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        path.lineWidth = 5.0
        path.stroke()
    }
    
    override func viewDidMoveToSuperview() {
        NSLog("rectangle moved to superview")
        dragBar = DragBar(frame: CGRect(x:0, y: 110, width: 80, height:10))
        addSubview(dragBar!)
    }


    
    override func mouseDown(with event: NSEvent) {
        path.move(to: convert(event.locationInWindow, from: nil))
        start = convert(event.locationInWindow, from: nil)
        //NSLog("start: \(start)")
        // path.line(to: convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        path.removeAllPoints()
        path.move(to: convert(start, from: nil))
        //NSLog("start2: \(start)")

        path.line(to: convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }
}

class ViewController: NSViewController {

    var rectangles: [Rectangle] = []
    override func viewDidLoad() {
        super.viewDidLoad()
        let rectangle = Rectangle(frame: CGRect(x:100, y:100, width: 80, height: 120))
        self.view.addSubview(rectangle)
        rectangles.append(rectangle)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    

}

