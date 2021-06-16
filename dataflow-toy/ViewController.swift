import Cocoa

extension CGPoint {
    static func +=(lhs: inout CGPoint, rhs: CGPoint) {
        lhs.x += rhs.x
        lhs.y += rhs.y
    }
}


class Vertex: NSView, NSDraggingSource {
    
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .link
    }
    
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
        beginDraggingSession(with: [], event: event, source: self)
    }
    
    func draggingSession(_ session: NSDraggingSession, willBeginAt: NSPoint) {
        rectangle?.everything?.unfinishedStart = convert(convert(willBeginAt, from: nil), to: rectangle?.everything)
        NSLog("Vertex draggingSession willBeginAt \(ObjectIdentifier(self)) \(willBeginAt)")
        rectangle?.everything?.unfinishedStartVertex = self
        needsDisplay = true
    }
    
    func draggingSession(_ session: NSDraggingSession, endedAt: NSPoint, operation: NSDragOperation) {
        NSLog("Vertex draggingSession endedAt   \(ObjectIdentifier(self)) \(endedAt)")
    }
    
    func draggingSession(_ session: NSDraggingSession, movedTo: NSPoint) {
        NSLog("Vertex draggingSession movedTo   \(ObjectIdentifier(self)) \(movedTo)")
        rectangle?.everything?.unfinishedStop = convert(convert(movedTo, from: nil), to: rectangle?.everything)
        rectangle?.everything?.drawUnfinishedEdge()
        needsDisplay = true
    }
    
    
    
    override func draggingEntered(_ draggingInfo: NSDraggingInfo) -> NSDragOperation {
        NSLog("Vertex draggingEntered   \(ObjectIdentifier(draggingInfo.draggingSource as! Vertex)) -> \(ObjectIdentifier(self))")
        return .link
    }
    
    override func draggingEnded(_ draggingInfo: NSDraggingInfo) {
        NSLog("Vertex draggingEnded   \(ObjectIdentifier(draggingInfo.draggingSource as! Vertex)) -> \(ObjectIdentifier(self))")
        let start = rectangle?.everything!.unfinishedStartVertex
        if start != nil {
            let vertexPair = VertexPair(start: start!, finish: self)
            rectangle?.everything?.vertexPairs.append(vertexPair)
            rectangle?.everything?.drawFinishedEdges()
            needsDisplay = true
        }
        
        //rectangle?.everything!.unfinishedStart = nil
        //rectangle?.everything!.unfinishedStop = nil
        //rectangle?.everything!.unfinishedStartVertex = nil
    }
    
}

class DragBar: NSView {
    weak var rectangle: Rectangle?
    
    override func mouseDown(with event: NSEvent) {
        NSLog("DragBar mouseDown \(ObjectIdentifier(self)) \(event.locationInWindow)")
    }
    
    override func mouseUp(with event: NSEvent) {
        NSLog("DragBar mouseUp   \(ObjectIdentifier(self)) \(event.locationInWindow)")
    }
    
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
    var inlet: Vertex?
    var outlet: Vertex?
    
    override func mouseDown(with event: NSEvent) {
        NSLog("Rectangle mouseDown \(ObjectIdentifier(self)) \(event.locationInWindow)")
    }
    
    override func mouseUp(with event: NSEvent) {
        NSLog("Rectangle mouseUp   \(ObjectIdentifier(self)) \(event.locationInWindow)")
    }

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

        inlet = Vertex(frame: convert(CGRect(x:-10, y:-10, width:20, height:20), to: superview))
        inlet!.rectangle = self
        superview?.addSubview(inlet!)
        
        outlet = Vertex(frame: convert(CGRect(x:70, y:-10, width:20, height:20), to: superview))
        outlet!.rectangle = self
        superview?.addSubview(outlet!)
    }


    func pan(by point: NSPoint) {
        frame.origin += point
        inlet?.frame.origin += point
        outlet?.frame.origin += point
        if everything?.unfinishedStart != nil {
            everything?.unfinishedStart! += point
        }
        //everything?.stop += point
        //everything?.drawUnfinishedEdge()
    }
}

struct VertexPair: Hashable {
    let start: Vertex
    let finish: Vertex
}

class Everything: NSView {
    var rectangles: [Rectangle] = []
    let curvesLayer = CALayer()
    
    var unfinishedPath: CGMutablePath? = CGMutablePath()
    var unfinishedStart: NSPoint? = NSPoint()
    var unfinishedStop: NSPoint? = NSPoint()
    var unfinishedEdgeShapeLayer: CAShapeLayer? = CAShapeLayer()
    
    var unfinishedStartVertex: Vertex?
    
    var vertexPairs: [VertexPair] = []
    var vertexPairsToShapeLayers : [(VertexPair): CAShapeLayer] = [:]
    
    override func mouseDown(with event: NSEvent) {
        NSLog("Everything mouseDown \(ObjectIdentifier(self)) \(event.locationInWindow)")
    }
    
    override func mouseUp(with event: NSEvent) {
        NSLog("Everything mouseUp   \(ObjectIdentifier(self)) \(event.locationInWindow)")
    }

    override func viewDidMoveToSuperview() {
        for i in 1...2 {
            let rectangle = Rectangle(frame: CGRect(x:100*i, y:100, width: 80, height: 120))
            rectangle.everything = self
            addSubview(rectangle)
            rectangles.append(rectangle)
        }
        
        curvesLayer.frame = self.frame
        curvesLayer.drawsAsynchronously = true
        layer!.addSublayer(curvesLayer)
    }
    
    func drawUnfinishedEdge() {
        if unfinishedStart == nil || unfinishedStop == nil {
            NSLog("ONE OR OTHER IS NIL")
            return
        }
        NSLog("BOTH NOT NIL: \(unfinishedStart) \(unfinishedStop)")
        CATransaction.begin()
        CATransaction.setAnimationDuration(0)
        
        unfinishedPath = CGMutablePath()
        unfinishedPath!.move(to: unfinishedStart!)
        unfinishedPath!.addLine(to: unfinishedStop!)
        
        unfinishedEdgeShapeLayer = CAShapeLayer()
        unfinishedEdgeShapeLayer!.frame = self.frame
        unfinishedEdgeShapeLayer!.strokeColor = NSColor.blue.cgColor
        unfinishedEdgeShapeLayer!.lineWidth = 5.0
        unfinishedEdgeShapeLayer!.path = unfinishedPath
        
        curvesLayer.addSublayer(unfinishedEdgeShapeLayer!)
        
        CATransaction.commit()
    }
    
    func drawFinishedEdges() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0)
        
        for vertexPair in vertexPairs {
            let path = CGMutablePath()
            path.move(to: vertexPair.start.frame.origin)
            path.addLine(to: vertexPair.finish.frame.origin)
            
            if vertexPairsToShapeLayers[vertexPair] == nil {
                vertexPairsToShapeLayers[vertexPair] = CAShapeLayer()
            }
            
            let shapeLayer = vertexPairsToShapeLayers[vertexPair]!
            shapeLayer.frame = self.frame
            shapeLayer.strokeColor = NSColor.blue.cgColor
            shapeLayer.lineWidth = 5.0
            shapeLayer.path = path
            
            curvesLayer.addSublayer(shapeLayer)
        }
        
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

