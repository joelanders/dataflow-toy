import Cocoa

extension CGPoint {
    static func +=(lhs: inout CGPoint, rhs: CGPoint) {
        lhs.x += rhs.x
        lhs.y += rhs.y
    }
}

class Connector: NSView {
    weak var rectangle: Rectangle?
    var path: NSBezierPath = NSBezierPath()
    override func viewDidMoveToSuperview() {
        NSLog("connector moved to superview")
    }
    
    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        NSColor.green.set()
        path.lineWidth = 5.0
        path.appendOval(in: CGRect(x:5, y:5, width: 10, height:10))
        path.stroke()
    }
}

class DragBar: NSView {
    weak var rectangle: Rectangle?
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
    
    @objc func pan(_ gesture: NSPanGestureRecognizer) {
        rectangle?.pan(by: gesture.translation(in: self))
        gesture.setTranslation(.zero, in: self)
    }

}

class Rectangle: NSView {
    var path: NSBezierPath = NSBezierPath()
    var start: NSPoint = NSPoint()
    var dragBar: DragBar?
    var inlet: Connector?
    var outlet: Connector?

    @IBInspectable var color: NSColor = .clear {
        didSet { layer?.backgroundColor = color.cgColor }
    }
    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

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
        dragBar!.rectangle = self
        addSubview(dragBar!)

        inlet = Connector(frame: convert(CGRect(x:-10, y:-10, width:20, height:20), to: superview))
        superview?.addSubview(inlet!)
        
        outlet = Connector(frame: convert(CGRect(x:70, y:-10, width:20, height:20), to: superview))
        superview?.addSubview(outlet!)
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
    
    func pan(by point: NSPoint) {
        frame.origin += point
        inlet?.frame.origin += point
        outlet?.frame.origin += point
    }
}

class Everything: NSView {
    var rectangles: [Rectangle] = []
    override func viewDidMoveToSuperview() {
        let rectangle = Rectangle(frame: CGRect(x:100, y:100, width: 80, height: 120))
        addSubview(rectangle)
        rectangles.append(rectangle)
    }
}

class ViewController: NSViewController {

    var everything: Everything? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        everything = Everything(frame: self.view.frame)
        self.view.addSubview(everything!)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    

}

