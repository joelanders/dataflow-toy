import Cocoa

extension CGPoint {
    static func +=(lhs: inout CGPoint, rhs: CGPoint) {
        lhs.x += rhs.x
        lhs.y += rhs.y
    }
}

class Vertex: NSView {
    weak var rectangle: Rectangle?
    var circlePath: NSBezierPath = NSBezierPath()
    
    override func viewDidMoveToSuperview() {
        NSLog("connector moved to superview")
    }
    
    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        NSColor.lightGray.set()
        circlePath.lineWidth = 5.0
        circlePath.appendOval(in: CGRect(x:2.5, y:2.5, width: 5, height:5))
        circlePath.stroke()

        rectangle?.everything?.needsDisplay = true
    }
    
    override func mouseDown(with event: NSEvent) {
        rectangle?.everything?.unfinishedStart = convert(convert(event.locationInWindow, from: nil), to: rectangle?.everything)
        NSLog("Vertex mouseDown \(ObjectIdentifier(self))")
        rectangle?.everything?.unfinishedStartVertex = self
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        //NSLog("Vertex mouseDrageed   \(ObjectIdentifier(self))")
        rectangle?.everything?.unfinishedStop = convert(convert(event.locationInWindow, from: nil), to: rectangle?.everything)
        rectangle?.everything?.drawUnfinishedEdge()
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        NSLog("Vertex mouseUp   \(ObjectIdentifier(self))")
        return super.mouseUp(with: event)
    }
    
    func makeEdge(with event: NSEvent) {
        NSLog("Vertex makeEdge   \(ObjectIdentifier(self))")
        let start = rectangle?.everything!.unfinishedStartVertex
        if start != nil {
            let vertexPair = VertexPair(start: start!, finish: self)
            rectangle?.everything?.vertexPairs.append(vertexPair)
            rectangle?.everything?.drawFinishedEdges()
            needsDisplay = true
        }
        
        rectangle?.everything!.unfinishedStart = nil
        rectangle?.everything!.unfinishedStop = nil
        rectangle?.everything!.unfinishedStartVertex = nil
        rectangle?.everything!.drawUnfinishedEdge()
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
        NSColor.lightGray.set()
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
    var inlets: [Vertex] = []
    var outlets: [Vertex] = []
    
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

        for i in 0...3 {
            let inlet = Vertex(frame: convert(CGRect(x:-5, y:-5 + 30*i, width:10, height:10), to: superview))
            everything?.vertexes.append(inlet)
            self.inlets.append(inlet)
            inlet.rectangle = self
            superview?.addSubview(inlet)
        }
        
        for i in 0...3 {
            let outlet = Vertex(frame: convert(CGRect(x:75, y:-5 + 30*i, width:10, height:10), to: superview))
            everything?.vertexes.append(outlet)
            self.outlets.append(outlet)
            outlet.rectangle = self
            superview?.addSubview(outlet)
        }
    }


    func pan(by point: NSPoint) {
        frame.origin += point
        for inlet in inlets {
            inlet.frame.origin += point
        }
        for outlet in outlets {
            outlet.frame.origin += point
        }
        if everything?.unfinishedStart != nil {
            everything?.unfinishedStart! += point
        }
        //everything?.stop += point
        everything?.drawFinishedEdges()
    }
}

struct VertexPair: Hashable {
    let start: Vertex
    let finish: Vertex
}

class Everything: NSView {
    var rectangles: [Rectangle] = []
    var vertexes: [Vertex] = []
    let curvesLayer = CALayer()
    
    var unfinishedPath: CGMutablePath? = CGMutablePath()
    var unfinishedStart: NSPoint? = NSPoint()
    var unfinishedStop: NSPoint? = NSPoint()
    var unfinishedEdgeShapeLayer: CAShapeLayer? = CAShapeLayer()
    
    var unfinishedStartVertex: Vertex?
    
    var vertexPairs: [VertexPair] = []
    var vertexPairsToShapeLayers : [(VertexPair): CAShapeLayer] = [:]
    
    var guidePathsLayer = CALayer()
    var vertexesToGuidePathShapeLayers: [Vertex: CAShapeLayer] = [:]
    
    override func mouseDown(with event: NSEvent) {
        NSLog("Everything mouseDown \(ObjectIdentifier(self)) \(event.locationInWindow)")
    }
    
    override func mouseUp(with event: NSEvent) {
        NSLog("Everything mouseUp   \(ObjectIdentifier(self)) \(event.locationInWindow)")
        let target = hitTest(event.locationInWindow)
        NSLog("hitTest: \(target)")
        if let targetVertex = target as? Vertex {
            targetVertex.makeEdge(with: event)
        }
    }

    override func viewDidMoveToSuperview() {
        for i in 0...1 {
            let rectangle = Rectangle(frame: CGRect(x:100 + 200*i, y:100, width: 80, height: 120))
            rectangle.everything = self
            addSubview(rectangle)
            rectangles.append(rectangle)
        }
        
        curvesLayer.frame = self.frame
        curvesLayer.drawsAsynchronously = true
        curvesLayer.zPosition = 100
        layer!.addSublayer(curvesLayer)
        
        guidePathsLayer.frame = self.frame
        guidePathsLayer.drawsAsynchronously = true
        guidePathsLayer.zPosition = 99
        layer!.addSublayer(guidePathsLayer)
        // drawGuidePaths()
        needsDisplay = true
    }
    
    func drawGuidePaths() {
        NSLog("drawGuidePaths()")
        CATransaction.begin()
        CATransaction.setAnimationDuration(0)
        
        for vertex in vertexes {
            let guidePath = CGMutablePath()
            guidePath.addEllipse(in: NSRect(x: vertex.frame.minX - vertex.frame.width * 1.5, y: vertex.frame.minY + vertex.frame.height * 0.5, width: vertex.frame.width*4, height: vertex.frame.height*4))
            
            if vertexesToGuidePathShapeLayers[vertex] == nil {
                vertexesToGuidePathShapeLayers[vertex] = CAShapeLayer()
            }
            let guidePathShapeLayer = vertexesToGuidePathShapeLayers[vertex]!
            guidePathShapeLayer.frame = self.frame
            guidePathShapeLayer.strokeColor = NSColor.red.cgColor
            guidePathShapeLayer.fillRule = .evenOdd
            guidePathShapeLayer.opacity = 0.5
            guidePathShapeLayer.lineWidth = 2.0
            guidePathShapeLayer.path = guidePath
            
            guidePathsLayer.addSublayer(guidePathShapeLayer)
        }
        CATransaction.commit()
    }
    
    func drawUnfinishedEdge() {
        let context = NSGraphicsContext.current?.cgContext
        context?.setLineCap(.round)
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(0)
        
        unfinishedPath = CGMutablePath()
        if unfinishedStart != nil && unfinishedStop != nil {
            unfinishedPath!.move(to: unfinishedStart!)
            unfinishedPath!.addLine(to: unfinishedStop!)
        }
        
        unfinishedEdgeShapeLayer!.frame = self.frame
        unfinishedEdgeShapeLayer!.strokeColor = NSColor.blue.cgColor
        unfinishedEdgeShapeLayer!.lineWidth = 2.0
        unfinishedEdgeShapeLayer!.path = unfinishedPath
        
        curvesLayer.addSublayer(unfinishedEdgeShapeLayer!)
        
        CATransaction.commit()
    }
    
    func drawFinishedEdges() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0)
        
        for vertexPair in vertexPairs {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: NSMidX(vertexPair.start.frame), y: NSMidY(vertexPair.start.frame)))
            path.addLine(to: CGPoint(x: NSMidX(vertexPair.finish.frame), y: NSMidY(vertexPair.finish.frame)))
            
            if vertexPairsToShapeLayers[vertexPair] == nil {
                vertexPairsToShapeLayers[vertexPair] = CAShapeLayer()
            }
            
            let shapeLayer = vertexPairsToShapeLayers[vertexPair]!
            shapeLayer.frame = self.frame
            shapeLayer.strokeColor = NSColor.darkGray.cgColor
            shapeLayer.lineWidth = 2.0
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

