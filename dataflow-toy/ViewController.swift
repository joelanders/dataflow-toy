import Cocoa

extension CGPoint {
    static func +=(lhs: inout CGPoint, rhs: CGPoint) {
        lhs.x += rhs.x
        lhs.y += rhs.y
    }
}

class Connector: NSView {
    weak var rectangle: Rectangle?
    var circlePath: NSBezierPath = NSBezierPath()
    
    override func viewDidMoveToSuperview() {
        NSLog("connector moved to superview")
    }
    
    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        NSColor.green.set()
        circlePath.lineWidth = 5.0
        circlePath.appendOval(in: CGRect(x:5, y:5, width: 10, height:10))
        circlePath.stroke()

        rectangle?.everything?.needsDisplay = true
    }
    
    override func mouseDown(with event: NSEvent) {
        rectangle?.everything?.start = convert(convert(event.locationInWindow, from: nil), to: rectangle?.everything)
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        rectangle?.everything?.stop = convert(convert(event.locationInWindow, from: nil), to: rectangle?.everything)
        rectangle?.everything?.drawCords()
        needsDisplay = true
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
    weak var everything: Everything?
    var dragBar: DragBar?
    var inlet: Connector?
    var outlet: Connector?

    @IBInspectable var color: NSColor = .clear {
        didSet { layer?.backgroundColor = color.cgColor }
    }
    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        NSBezierPath(rect: dirtyRect).fill()

    }
    
    override func viewDidMoveToSuperview() {
        NSLog("rectangle moved to superview")
        dragBar = DragBar(frame: CGRect(x:0, y: 110, width: 80, height:10))
        dragBar!.rectangle = self
        addSubview(dragBar!)

        inlet = Connector(frame: convert(CGRect(x:-10, y:-10, width:20, height:20), to: superview))
        inlet!.rectangle = self
        superview?.addSubview(inlet!)
        
        outlet = Connector(frame: convert(CGRect(x:70, y:-10, width:20, height:20), to: superview))
        outlet!.rectangle = self
        superview?.addSubview(outlet!)
    }


    func pan(by point: NSPoint) {
        frame.origin += point
        inlet?.frame.origin += point
        outlet?.frame.origin += point
        everything?.start += point
        //everything?.stop += point
        everything?.drawCords()
    }
}

class Everything: NSView {
    var rectangles: [Rectangle] = []
    var path: CGMutablePath = CGMutablePath()
    var start: NSPoint = NSPoint()
    var stop: NSPoint = NSPoint()
    let curvesLayer = CALayer()
    var shapeLayer = CAShapeLayer()
    
    override func viewDidMoveToSuperview() {
        let rectangle = Rectangle(frame: CGRect(x:100, y:100, width: 80, height: 120))
        rectangle.everything = self
        addSubview(rectangle)
        rectangles.append(rectangle)
        curvesLayer.frame = self.frame
        curvesLayer.drawsAsynchronously = true
        layer!.addSublayer(curvesLayer)
    }
    
    func drawCords() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0)
        
        path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: stop)
        
        shapeLayer.frame = self.frame
        shapeLayer.strokeColor = NSColor.blue.cgColor
        shapeLayer.lineWidth = 5.0
        shapeLayer.path = path
        
        curvesLayer.addSublayer(shapeLayer)
        
        CATransaction.commit()

    }
}

class ViewController: NSViewController {

    var everything: Everything? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        everything = Everything(frame: self.view.frame)
        everything!.wantsLayer = true
        self.view.addSubview(everything!)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    

}

