//
//  EverythingController.swift
//  dataflow-toy
//
//  Created by Joe Landers on 25.06.21.
//

import Cocoa

class EverythingController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
}


extension CGPoint {
    static func +=(lhs: inout CGPoint, rhs: CGPoint) {
        lhs.x += rhs.x
        lhs.y += rhs.y
    }
}

extension NSView {
    var center: CGPoint { return CGPoint(x: frame.midX, y: frame.midY) }
}

class Vertex: NSView {
    weak var rectangle: Rectangle?
    var circlePath: NSBezierPath = NSBezierPath()
    
    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        NSColor.lightGray.set()
        circlePath.lineWidth = 5.0
        circlePath.appendOval(in: CGRect(x:2.5, y:2.5, width: 5, height:5))
        circlePath.stroke()

        rectangle?.everything?.needsDisplay = true
    }

}

class DragBar: NSView {
    weak var rectangle: Rectangle?
    weak var everything: Everything?

    override func mouseDown(with event: NSEvent) {
        NSLog("DragBar mouseDown \(ObjectIdentifier(self)) \(event.locationInWindow)")
    }
    
    override func mouseUp(with event: NSEvent) {
        NSLog("DragBar mouseUp   \(ObjectIdentifier(self)) \(event.locationInWindow)")
    }
    
    override func viewDidMoveToSuperview() {
        addGestureRecognizer(NSPanGestureRecognizer(target: self, action: #selector(pan)))

    }
    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)

        layer?.backgroundColor = NSColor.red.cgColor
        NSColor.lightGray.set()
        NSBezierPath(rect: dirtyRect).fill()
    }
    
    @objc func pan(_ gesture: NSPanGestureRecognizer) {
        if everything!.selectedRectangles.count > 0 {
            for rectangle in everything!.selectedRectangles {
                rectangle.pan(by: gesture.translation(in: self))
            }
        } else {
            rectangle!.pan(by: gesture.translation(in: self))
        }
        gesture.setTranslation(.zero, in: self)
    }

}

class Rectangle: NSView {
    weak var everything: Everything?
    var selected = false
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
        if selected {
            NSColor.lightGray.set()
        } else {
            NSColor.gray.set()
        }
        NSBezierPath(rect: dirtyRect).fill()

    }
    
    override func viewDidMoveToSuperview() {
        dragBar = DragBar(frame: CGRect(x:0, y: 110, width: 80, height:10))
        dragBar!.everything = everything
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
    var selectedRectangles: [Rectangle] = []
    var vertexes: [Vertex] = []
    let curvesLayer = CALayer()
    
    var unfinishedPath: CGMutablePath? = CGMutablePath()
    var unfinishedStart: NSPoint? = nil
    var unfinishedStop: NSPoint? = nil
    var unfinishedEdgeShapeLayer: CAShapeLayer? = CAShapeLayer()
    
    var selectionStart: NSPoint? = nil
    var selectionStop: NSPoint? = nil
    var selectionRect: CGRect? = nil
    var selectionShapeLayer: CAShapeLayer? = nil

    var unfinishedStartVertex: Vertex?
    
    var vertexPairs: [VertexPair] = []
    var vertexPairsToShapeLayers : [(VertexPair): CAShapeLayer] = [:]
    
    var guidePathsLayer = CALayer()
    var vertexesToGuidePathShapeLayers: [Vertex: CAShapeLayer] = [:]
    
    override func mouseDown(with event: NSEvent) {
        for rectangle in selectedRectangles {
            rectangle.selected = false
            rectangle.needsDisplay = true
        }
        selectedRectangles = []
        selectionRect = nil
        selectionStart = nil
        selectionStop = nil
        
        let target = hitTest(convert(event.locationInWindow, from: nil))
        NSLog("everything mouseDown hitTest: \(target)")
        if let targetVertex = target as? Vertex {
            unfinishedStart = convert(event.locationInWindow, from: nil)
            unfinishedStartVertex = targetVertex
            needsDisplay = true
            return
        }
        NSLog("Everything mouseDown \(ObjectIdentifier(self)) \(event.locationInWindow)")
        selectionStart = convert(event.locationInWindow, from: nil)
    }
    
    override func mouseDragged(with event: NSEvent) {
        if unfinishedStart != nil {
            unfinishedStop = convert(event.locationInWindow, from: nil)
            drawUnfinishedEdge()
            needsDisplay = true
            return
        }
        if selectionStart != nil {
            NSLog("dragging selection box")
            selectionStop = convert(event.locationInWindow, from: nil)
            drawSelectionBox()
            needsDisplay = true
            return
        }
        
    }
    
    override func mouseUp(with event: NSEvent) {
        NSLog("Everything mouseUp   \(ObjectIdentifier(self)) \(event.locationInWindow)")
        let target = hitTest(convert(event.locationInWindow, from: nil))
        NSLog("hitTest: \(target)")
        if let targetVertex = target as? Vertex {
            makeEdge(to: targetVertex)
        }
        
        if selectionRect != nil {
            for rectangle in rectangles {
                if selectionRect!.contains(rectangle.center) {
                    rectangle.selected = true
                    selectedRectangles.append(rectangle)
                    rectangle.needsDisplay = true
                }
            }
            NSLog("selectedRectangles: \(selectedRectangles)")
        }
        
        unfinishedStart = nil
        unfinishedStop = nil
        unfinishedStartVertex = nil
        drawUnfinishedEdge()
        
        selectionStart = nil
        selectionStop = nil
        drawSelectionBox()
        needsDisplay = true

    }
    
    func makeEdge(to targetVertex: Vertex) {
        NSLog("Vertex makeEdge   \(ObjectIdentifier(self))")
        let start = unfinishedStartVertex
        if start != nil {
            let vertexPair = VertexPair(start: start!, finish: targetVertex)
            vertexPairs.append(vertexPair)
            drawFinishedEdges()
        }
    }

    override func viewDidMoveToSuperview() {
        for i in 0...1 {
            let rectangle = Rectangle(frame: CGRect(x:100 + 200*i, y:100, width: 80, height: 120))
            rectangle.everything = self
            addSubview(rectangle)
            rectangles.append(rectangle)
        }
                
        self.wantsLayer = true
        
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
            guidePathShapeLayer.lineWidth = 1.0
            guidePathShapeLayer.path = guidePath
            
            guidePathsLayer.addSublayer(guidePathShapeLayer)
        }
        CATransaction.commit()
    }
    
    func drawSelectionBox() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0)
        
        NSLog("drawSelectionBox()")
        let selectionBox = CGMutablePath()
        if case let (start?, stop?) = (selectionStart, selectionStop) {
            NSLog("drawSelectionBox(): have start and stop")

            selectionRect = CGRect(x: min(start.x, stop.x), y: min(start.y, stop.y), width: abs(start.x - stop.x), height: abs(start.y - stop.y))
            selectionBox.addRect(selectionRect!)
        }
        
        if selectionShapeLayer == nil {
            selectionShapeLayer = CAShapeLayer()
        }
        selectionShapeLayer!.frame = self.frame
        selectionShapeLayer!.strokeColor = NSColor.blue.cgColor
        selectionShapeLayer!.opacity = 0.5
        selectionShapeLayer!.lineWidth = 1.0
        selectionShapeLayer!.path = selectionBox
        curvesLayer.addSublayer(selectionShapeLayer!)
        
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
            NSLog("have unfinished edge")
        }
        
        unfinishedEdgeShapeLayer!.frame = self.frame
        unfinishedEdgeShapeLayer!.strokeColor = NSColor.blue.cgColor
        unfinishedEdgeShapeLayer!.lineWidth = 1.0
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
            shapeLayer.lineWidth = 1.0
            shapeLayer.path = path
            
            curvesLayer.addSublayer(shapeLayer)
        }
        
        CATransaction.commit()
    }
}
